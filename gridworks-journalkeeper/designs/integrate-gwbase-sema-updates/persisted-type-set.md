# Spoke B — persisted type-set (what JK ingests + stores)

Status: Accepted · Pass 1 · Updated 2026-06-10 · Linear: OPS-386 · Reviewed 2026-06-10 (scada↔ltn live capture)

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

## The add recipe — two classes of type

**Precondition: the type must be a faithful sema word.** JK can only journal
strict what sema can decode strict. That splits the captured types in two:

- **Already-clean sema words** (`gridworks.ack`, `gridworks.ping`, and the
  already-handled `report.event` / `layout.lite` / forecasts /
  `gridworks.event.problem`) → the **cheap recipe** below applies directly.
- **Not-yet-faithful types** (the `gridworks.event.comm.*` family,
  `gridworks.event.startup/shutdown`, `send.layout`, and the new
  `ally.inactive`) → **model first** (see "Sema words this session owns"),
  *then* run the recipe.

**Cheap recipe (clean words):**

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

## The "few more" — enumerated from the live capture (2026-06-10)

A separate session stood up a real **LTN + scada** pair on `gw-dev-rabbit` and
captured the full startup + steady-state exchange (wire + both process logs).
The verified record is `wiki/gridworks-scada/executor/scada-ltn-link-state.md`
("Observed startup sequence"). Cross-referenced against what JK already handles,
the **new candidate types** for JK's set are:

| Type | Note | Likely bucket |
|---|---|---|
| `send.layout` | LTN→scada layout request | per-type (check id/ts fields) |
| `gridworks.event.startup` | process lifecycle | per-type |
| `gridworks.event.shutdown` | process lifecycle | per-type |
| `gridworks.event.comm.mqtt.connect` | link lifecycle (×3, one per link) | per-type |
| `gridworks.event.comm.mqtt.fully.subscribed` | link lifecycle (×3) | per-type |
| `gridworks.event.comm.peer.active` | peer-up | per-type |
| `gridworks.event.comm.response.timeout` | ack timeout | per-type |

Each is its own `gridworks.event.*` TypeName (distinct topic). Run each through
the add-recipe; the bucket (BASIC vs `MSG_ID_FIELDS` vs `MSG_CREATED_AT_FIELDS_*`)
depends on whether the payload carries a `MessageId` / time field — decide
per-type at impl, same as `ack`/`ping`. (Already-handled by JK and therefore
**not** new: `report.event`, `layout.lite`, `heating.forecast`,
`weather.forecast`, `gridworks.event.problem`. `snapshot.spaceheat` is emitted
but JK deliberately skips it — `sema_message_persistor.py:35` "performance"; a
decision to revisit, not a gap.)

### Two findings that shape what JK *can* journal

**1. Arrival at `ear_tx` is CONFIRMED (2026-06-10).** The capture is the
**scada↔LTN MQTT path** (`gw/<src>/to/<dst>/<type-kebab>` topics), and the
question was whether that traffic is mirrored into the AMQP `ear_tx` audit
exchange JK consumes. warm-thorn confirmed it **does** — observed directly on
`ear_tx` with a **mosquitto** subscriber (not JK). So the ear tap is fed by the
scada↔LTN traffic; the emit-list above is therefore also the *arrival* list. The
MQTT topic `gw.<src>.to.<dst>.<type-kebab>` (`/`→`.`) ends in the type token, so
JK's bind `#.{type_name.replace(".","-")}` matches the trailing token — JK will
ingest each type once it is seeded + listed in the persistor. A JK-side run
would only add end-to-end proof through JK's *own* decode/persist (trusted for
now, not gating).

**2. On link-down, nothing is emitted live — and the fix is deliberately NOT an
event.** The proactor's `CommEvent`s (`MQTTDisconnectEvent`,
`ResponseTimeoutEvent`, …) ride the **stored-until-acked** event path, so they
reach the wire **only after the link is already back** (capture, "Link-down
behavior — the gap"). So the captured `gridworks.event.comm.*` types JK
journals are an **after-the-fact record**, not a live outage signal — JK
receives them post-recovery (stale, duplicated under the flap pathology).

The scada-side game plan ("Change now") adds a **`ally.inactive`** signal that
**will NOT be a `gridworks.event.*` / will NOT be an Event** — that is the
point. Being an Event is exactly what makes the comm types ride the persist-
then-upload path and arrive too late. `ally.inactive` is instead
**fire-and-forget, unpersisted, semantically-named** (covers MQTT drop AND
response-timeout AND any future way a peer vanishes), **published the moment a
peer goes dark, straight out the announcer's own broker connection** — which is
independent of the (now-dead) path to that peer, so any third party hears it
immediately. (Frame this as plain broker reachability, **not** in terms of
proactor "links" — the 1:1 link FSM is the very abstraction under critique, and
the announcer's ability to publish depends only on its broker connection, not on
any "link" to the vanished peer.) It is therefore the **only** signal that lets
a tap learn of an outage *while it is happening*.

**This is squarely JK's job.** The capture calls `peer.inactive` "the single
most important thing a **third-party referee** could hear" — and JK *is* that
referee/journal. So when its TypeName is coined, JK should both **ingest and
persist** it (it is unpersisted *at the emitter*; JK is the durable "who went
dark, when" record). Add it via the recipe then — note it will land in a
`MSG_*`/`BASIC` bucket like any other type, **not** alongside the event family,
and it is the one outage type JK can stamp with a real (live) `time_received`.

## Sema words this session owns

This session holds the **sema** claim, so the modeling work for JK's not-yet-
faithful types is in-scope here (not punted upstream). Two kinds:

**A. `ally.inactive` — a NEW word, bequeathed to this session (2026-06-10).**
The fire-and-forget live outage signal (finding 2) does not exist yet; coining
it is mine. Intended shape (to be fixed via the ritual, not pre-frozen here): a
**versioned** type (per the house preference for versioned over versionless),
serialized **CamelCase** fields, `TypeName` `ally.inactive`, carrying at least
the announcer's alias, the ally that went dark, the cause (covers MQTT-drop AND
response-timeout AND any future vanishing), and an emit timestamp. JK then
**ingests + persists** it (the durable "who went dark, when" record).
*Emit-side wiring (scada/LTN actually publishing it) stays with warm-thorn;*
*this session owns only the sema type.* When picked up, likely its own Ops issue.

**B. Faithful modeling of the captured `gridworks.event.*` / `send.layout`
types.** For each not-yet-clean type: **capture** the wire instance → **inspect**
its form → **trace** its source in `gridworks-proactor` / `gridworks-protocol`
→ **author or verify** a sema word that faithfully captures it → then run the
cheap recipe. (Some may already be sema words; some are proactor-internal
pydantic and need a faithful sema type coined.)

**Sema protocol (MUST, for both A and B):** before any sema edit, read
`sema/CLAUDE.md` + `spec/primary.md` and use `/make-sema-word` (the per-word
ritual + a Task Prompt). Universal MUSTs apply: CamelCase serialized fields,
`TypeName` left.right.dot, formats immutable, enums additive, correct dependency
declarations, `pytest` + registry validation green.

> Out of scope here: hardening the `gw` envelope / its `Header` to be versioned
> and to enforce `LeftRightDot` on alias fields. That is a **separate
> gridworks-proactor design** (the relaxed link-local short names — `ltn`, `s`
> — are proactor-internal addressing, so enforcement can't sit naively "at the
> bottom"). Not a dependency of this spoke; noted only so it isn't re-derived.

## Acceptance / done-when

- `gridworks.ack` + `gridworks.ping` in the seed (snapshot regen'd, both decode
  strict) **and** in `BASIC_MSG_TYPES` (ingested + stored).
- A live or replayed `ack`/`ping` persists to `MessageSql` with the right
  `message_type_name`; no "degraded … not persisting" warning.
- JK suite green.
- The captured types are modeled (clean word verified, or coined per "Sema
  words this session owns") and added via the recipe.
- `ally.inactive` sema word coined (versioned, via `/make-sema-word`) and JK
  ingests + persists it.

