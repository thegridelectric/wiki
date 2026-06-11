# Spoke B — persisted type-set (what JK ingests + stores)

Status: Accepted · Pass 1 · Updated 2026-06-10 · Linear: OPS-386

> What this is: spoke of `integrate-gwbase-sema-updates` (hub: `primary.md`,
> OPS-386). The mechanism and plan for **which message types JournalKeeper
> ingests off the broker and stores** — and how to add more cheaply. Immediate
> targets: `gridworks.ack` and `gridworks.ping`, with "a few more" to follow,
> discovered from live LTN+scada traffic.

## How JK decides what it ingests and stores (one source of truth)

The persistor's **`all_known_message_types()`** is the single registry that
drives *both* sides:

- **Ingest** — `JournalKeeper.local_rabbit_startup()`
  (`src/gjk/journal_keeper.py:54`) binds one routing key per type in
  `all_known_message_types()`: `#.{type_name.replace(".","-")}` on `ear_tx`.
  Add a type to the persistor and JK automatically subscribes to it; no edit in
  the keeper.
- **Store** — `SemaMessagePersistor.persist_message()`
  (`src/gjk/sema_message_persistor.py:138`) writes every accepted payload as one
  `MessageSql` row (`message_type_name` + `payload` jsonb + id + timestamp).
  Single table; no per-type schema.

`all_known_message_types()` (`sema_message_persistor.py:92`) is the union of
five class-level tables:

| Table | Purpose | Row id | created_at |
| --- | --- | --- | --- |
| `BASIC_MSG_TYPES` (`:55`) | no id / no created_at, persist anyway | deterministic `default_message_id` | `None` → falls back to `time_received` |
| `MSG_ID_FIELDS` (`:47`) | payload carries its own unique id | that field | — |
| `MSG_CREATED_AT_FIELDS_MS` (`:28`) | payload carries a ms timestamp | default | from field (ms) |
| `MSG_CREATED_AT_FIELDS_S` (`:43`) | payload carries an s timestamp | default | from field (s) |
| `custom_persistor_lookup` (`:69`) | needs extra table writes | per custom persistor | per persistor |

**Decode gate.** Ingest+store is necessary but not sufficient: a type also has
to be in JK's **restricted sema snapshot** so the codec decodes it *strict*.
`_persist_body` (`journal_keeper.py:154-167`) calls
`codec.from_dict(..., mode="degraded")`; a type absent from the snapshot decodes
**degraded** and is **dropped, not persisted** ("Got degraded SEMA type … not
persisting", `:162-167`). So every persisted type needs **two** edits:
seed + persistor.

## The add recipe (per type — cheap and repeatable)

1. **Seed** — add the type to `src/gjk/sema_seed_request.yaml`
   `initial_targets.types`, then regen: `scripts/regen_sema_snapshot.sh`
   (rebuilds `src/gjk/sema`). This makes the codec decode it strict.
2. **Persistor** — add the type name to the right table in
   `sema_message_persistor.py` (usually a **one-line** add). This wires both
   ingest (routing-key bind) and store (default persist path).
3. **Seed test** — confirm the type appears in the snapshot and decodes (the
   round-trip gate / `samples/` already shipped with the snapshot work).

## Immediate targets: `gridworks.ack` + `gridworks.ping`

Both verified against the sema registry (`sema/definitions/types/`):

- **`gridworks.ack`** — *versionless*; fields `AckMessageID` (uuid4),
  `TypeName`. `AckMessageID` is the id of the message being **acked**, not a
  unique id for the ack itself (two actors acking the same message would
  collide) → **must not** be used as the row id. → **`BASIC_MSG_TYPES`** (use
  the deterministic `default_message_id`).
- **`gridworks.ping`** — *versionless*; fields `MessageId` (uuid4),
  `TypeName`. `MessageId` *is* the ping's own unique id, so two placements are
  defensible:
  - `BASIC_MSG_TYPES` — deterministic id (consistent with `ack`, simplest), **or**
  - `MSG_ID_FIELDS = {"gridworks.ping": "MessageId"}` — natural dedup on the
    ping's own id.

  **Recommendation:** `BASIC_MSG_TYPES` for both initially (uniform, minimal);
  promote `ping` to `MSG_ID_FIELDS` only if natural-id dedup proves useful.
  **Decide at impl.**

**Versionless seeding — VERIFIED.** `ack`/`ping` are `versioning_strategy:
"none"` in `sema/definitions/registry.yaml` (`:1134`, `:1176`). The seed entry
**must** use the bare `{}` form — `build_seed_expanded.py` resolves a `none`
type's empty options to its single `None` version
(`available_versions` → `[None]` `:73-74`; empty `options` → `[latest_version]`
→ `[None]` `:116-117`):

```yaml
  types:
    gridworks.ack: {}
    gridworks.ping: {}
```

Do **not** use `include_all_versions` / `versions: [...]` for these — the
`versions` list requires 3-digit strings (`:131`) and would raise.

## The "few more" — discovery via the live rig

The full set of startup/liveness/disconnect control messages JK should journal
is not yet enumerated. **Discovery method:** a separate session stands up a real
**LTN + scada** pair; **this session operates the rig** (per instructions that
session will leave) to:

- capture **every message exchanged at startup** (the handshake/announce set),
- **stop one side** (LTN or scada) and capture **what the other emits on loss
  of contact** (the disconnect/timeout set).

Each distinct type observed becomes a candidate for the add-recipe above. Record
the captured type list here as it firms up; that list is what turns "a few more"
into a closed set.

## Acceptance / done-when

- `gridworks.ack` + `gridworks.ping` in the seed (snapshot regen'd, both decode
  strict) **and** in `BASIC_MSG_TYPES` (ingested + stored).
- A live or replayed `ack`/`ping` persists to `MessageSql` with the right
  `message_type_name`; no "degraded … not persisting" warning.
- JK suite green.
- The live-rig-discovered types are enumerated here and added via the recipe.

## Open questions

- `ping` placement: `BASIC_MSG_TYPES` vs `MSG_ID_FIELDS` (§ immediate targets).
- Final type-set from the live rig — pending the LTN+scada capture session.

_(Resolved: versionless seed syntax — bare `{}`, § immediate targets.)_
