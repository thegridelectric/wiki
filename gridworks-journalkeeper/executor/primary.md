# gridworks-journalkeeper — rebuild spec

Status: Draft · Pass 0 · Updated 2026-06-12

> Faithful-rebuild hub: enough to build journalkeeper from scratch.
> **Part I — Functional specification** is the durable contract (what gjk
> must be). **Part II — Implementation today** is the contingent snapshot
> (modules, current coverage, the in-flight transition) and will drift.
> Keep the two from bleeding into each other.

## What journalkeeper is (one line)

A non-GNode broker consumer that decodes a selected set of Sema messages
crossing the bus and persists them to the `gw_data` `messages` table, fanning
some out into `readings`.

---

# Part I — Functional specification

## Role & tier

journalkeeper is an **analytics / audit tap**, not part of the production
control plane. It is a pure consumer: it holds no authority, makes no control
decisions, and owns no meaning — it records an interpretable copy of bus
traffic for query, audit, and analytics. (Where meaning *does* live — Sema +
the authority seeds — see `wiki/sema/research/where-meaning-lives-in-gridworks.md`
and `wiki/vision/data-meaning-sovereignty.md`.) No analytics-tier service
should hold production-broker credentials.

## The central commitment

`ActorBase` (transport) + `SemaCodec` (decode) + `SemaMessagePersistor`
(persist) — three things, no in-tree type registry.
`SemaMessagePersistor.all_known_message_types()` is the **single source of
truth** for what gjk binds on the broker AND what it persists. Adding a Sema
type to that set (plus the snapshot) extends coverage with no per-type handler
code.

## The capture contract — four gates

A message reaches `gw_data.messages` iff it passes all four gates. This is the
model to reason from when deciding coverage, and it must **expand as the
ecosystem adds actors and types**.

1. **Bind** — gjk binds one routing key per type in
   `all_known_message_types()` (`#.<type-with-dashes>`) on the consume
   exchange. Only those types are delivered. (Per-type, by design — not a
   catch-all.)
2. **Deliver without routing-metadata gatekeeping** — a message that reaches
   the consumer MUST be handed to dispatch regardless of whether its routing
   key parses into structured class/alias metadata. Delivery and persistence
   depend on the *type*, never on routing-class bookkeeping. gjk pins
   `gridworks-base ≥ 0.5.2`, which **satisfies** this — the prior routing-key
   data-loss bug is fixed (`must-accept-current-ltn-messages`, distilled into
   `gridworks-base/executor/transport.md`). Legacy `broadcast.*` keys that
   predate the fix are recovered by JK's `on_routing_key_parse_error` override
   (the permanent `legacy_hack`).
3. **Decode** — `SemaCodec.from_dict(..., mode="degraded")` decodes against
   gjk's restricted Sema snapshot. A type outside the snapshot vocabulary
   decodes as degraded and is skipped (a coverage gap, never a crash).
4. **Persist** — `SemaMessagePersistor` routes by `target_message_type` to a
   custom persistor (which may fan telemetry into `readings`) else a default
   path that stores the payload as jsonb. The persist set is the same
   `all_known_message_types()`, so bind and persist stay in lockstep.

## Invariants

1. **Not a GNode.** gjk is a tap — `ActorBase`, not `GridworksActor`. No
   heartbeat, no time-coordinator role, no GNode identity on the grid. Its
   settings ride gwbase's **`ServiceSettings`** tap tier (not `GNodeSettings`):
   `service_alias` is the routable address (e.g. `d1.journal`), there is **no**
   GNode identity file (`g.node.gt.json`), and paths are plain XDG keyed on
   `service_name`.
2. **Meaning/models live upstream, not here.** Persistence targets are the
   `gw_data` SQLAlchemy models (`MessageSql`, `ReadingChannelSql`,
   `ReadingSql`); gjk defines none of its own. The Sema runtime is a
   **restricted snapshot regenerated from `sema`**, never hand-edited.
3. **The live path is resilient.** `dispatch_message` logs and swallows
   malformed JSON, degraded types, and persist failures — the actor stays up.
   (The S3 backfill importer is the loud-fail counterpart: it halts on first
   failure, a deliberately different contract.)
4. **Binding is per-type, from the persistor** — narrowing happens at the
   broker by type, sourced from `all_known_message_types()`.
5. **Idempotent re-import.** Every message id is deterministic: a natural id
   field when present, else `uuid5` over `{from_alias}|{type_name}|{persisted_ms}`
   (the S3 filename triple). With the `(timestamp, id)` PK +
   `on_conflict_do_nothing`, re-importing a window is a true no-op. **A random
   id (`uuid4`) MUST NOT be used** — it defeats dedupe. The default path and
   every custom persistor mint ids through one shared `default_message_id(...)`;
   the same id becomes `reading.message_id`, keeping derived-reading provenance
   deterministic.
6. **Delivery is not gated on routing metadata** (the contract of Gate 2,
   restated as an invariant): gjk persists what it receives, by type.

## Data model (what it writes)

- **`messages`** — one row per persisted message: id (uuid), timestamp,
  from_alias, persisted_at, message_type_name, payload (jsonb).
- **`readings`** / **`reading_channels`** — derived rows fanned out by the
  custom persistors (telemetry reports → readings; layouts → channels), keyed
  back to the originating message id.

## Glossary

- **JournalKeeper** — the live `ActorBase` subclass; one method
  (`dispatch_message`) bridging transport to persistor.
- **SemaMessagePersistor** — the converged parse + persist entry point; owns
  `all_known_message_types()` and the custom-persistor lookup.
- **custom persistor** — a per-type handler that does more than store the
  payload (e.g. fans a report's telemetry into `readings`, or maintains
  `reading_channels` from a layout).
- **PseudoChannel** — a channel derived from telemetry rather than declared in
  a layout; registered lazily as reports arrive.
- **degraded** — a decode result for a type absent from the snapshot; carries
  type_name/version but is not a usable `SemaType`, so it is skipped.

---

# Part II — Implementation today (contingent)

> This section is a snapshot of the running code and the live fleet; it drifts
> and is expected to. Nothing here is a contract.

## Modules (`src/gjk/`)

`journal_keeper`, `sema_message_persistor`, `layout_lite_persistor`,
`report_event_persistor`, `flo_params_house0_persistor`,
`weather_forecast_persistor`, `message_persistence_info`, `pseudo_channels`,
`config`, `s3_message_importer`, `sema/` (the snapshot),
`sema_seed_request.yaml`. Custom persistors today: `layout.lite`,
`report.event`, `flo.params.house0`, `weather.forecast`.

## Live path

```
broker (consume exchange; per-type binds: #.report, #.glitch, …)
  └─ ActorBase consume → on_message: parse routing key  ── parse fails ─▶ recover* / log+drop
       └─ JournalKeeper.dispatch_message
            └─ SemaCodec.from_dict(json.loads(body))   ── degraded ─▶ skip
                 └─ SemaMessagePersistor.persist_message
                      ├─ custom persistor → MessageSql + fanned readings
                      └─ default → MessageSql(payload=jsonb)
                           └─ gw_data.messages
*Parse failures no longer drop silently: gwbase ≥ 0.5.2 fixed the routing-key
 bug, and JK's `on_routing_key_parse_error` override recovers legacy
 `broadcast.*` keys (the permanent `legacy_hack`); anything else is logged + dropped.
```

The consume exchange today is `ear_tx` (the universal audit tap); gjk consumes
directly from the **production** broker (`hw1__1`) — a transitional accident,
not the target tier.

## Verification

The live path is exercised end-to-end by `tests/test_live_amqp.py` (Layer 2 of
the layered-test-harness): a real `JournalKeeper` actor boots against an
ephemeral RabbitMQ + TimescaleDB (`testcontainers`), and a `scada.params`
message published to `amq.topic` (bridged to `ear_tx`) is consumed, decoded, and
persisted to `gridworks.messages`; both containers tear down after. It self-skips
without docker (the `integration` pytest marker). This is also the live
verification of the gwbase tap-tier migration — it runs `ActorBase.__init__` →
broker-consume, the path the unit suite skips (it builds JK via `__new__`).

## Current coverage and gaps

> Full per-type capture matrix (handlers, versions, id/created_at sources):
> [`captured-types.md`](captured-types.md).

From a 10-min catch-all (`#`) survey on `ear_tx` (2026-05-27, 5
`keene.*.scada`): the catch-all sees more than the live (narrow-bound) JK
receives — it's a bus survey.

- **Stored** (passes all gates): `snapshot.spaceheat`,
  `gridworks.event.problem`, `report.event`, `heating.forecast`,
  `weather.forecast`.
- **Degraded — absent from the snapshot:** e.g. `gridworks.ack`,
  `slow.contract.heartbeat`. Real Sema types; candidates for a snapshot regen
  if we decide to capture them.
- **Previously route-rejected at gwbase (now fixed):** short-form class tokens
  the old gwbase `RoutingClass` enum rejected — `s.*` (scada), `ws.weather`,
  `broadcast.*` (incl. `glitch`). Two of these — `glitch` and the weather
  broadcast — are types gjk *wants*. The gwbase ≥ 0.5.2 fix
  (`must-accept-current-ltn-messages`, distilled into
  `gridworks-base/executor/transport.md`) accepts them; legacy `broadcast.*`
  (incl. `glitch`) are additionally recovered by JK's `legacy_hack` override.
  (~37% of the surveyed traffic was in this class.)

The current persist set omits `atn.bid` (commented "until bid works in SEMA")
while keeping `latest.price`, `power.watts`, and the telemetry/forecast types.

## db_v2 transition (legacy, time-boxed)

Two journalkeepers run in parallel, persisting to **separate databases**:
**`main`** (the converged `SemaCodec + SemaMessagePersistor` line, cut from
`jds/db_v2`) and **`legacy`** (the prior journalkeeper, kept live as fallback
of record until `main` + the new DB are trusted). Do not assume a single
deployment while this window is open.

---

## Open questions

- **Scope.** Today's set already spans more than scada state (forecasts,
  `latest.price`, `energy.instruction`). Is gjk the journal for **all**
  archival-worthy bus traffic (LTN ↔ MarketMaker bids/acks/instructions, all
  forecasts, contract heartbeats), or scoped to scada telemetry? It is a
  *projection*, not an authority, which argues for journaling broadly. This
  decides how `all_known_message_types()` and the snapshot grow.
- **`broadcast.*` (incl. `glitch`).** `glitch` is wanted but arrives under a
  `broadcast` routing pattern gwbase can't parse — fix in gwbase
  (`must-accept-current-ltn-messages`) and/or clean up how scada emits it.
- **Which degraded types to capture** — follows from the scope decision and
  drives the next snapshot regen.

## Sub-specs

- [`persistor.md`](persistor.md) — the persistor stack in depth: the channel
  model (rigorous data/derived vs. pseudo) and the lossy `readings` projection.
- [`captured-types.md`](captured-types.md) — the per-type capture matrix.
- **`retention.md`** (Open) — largely a `gridworks-data` schema decision; see
  `explorations/scale-strategy-starter.md`.
- **`operational.md`** (Open) — start/stop, supervisor wiring, restart.

## Cross-refs

- `wiki/gridworks-base/executor/primary.md` — the framework; three-tier actor
  model in [`../../gridworks-base/executor/actors.md`](../../gridworks-base/executor/actors.md).
- `wiki/gridworks-data/` — the schema gjk writes into.
- `wiki/sema/primary.md` — the type runtime; `src/gjk/sema/` is the consumer
  slice.
- `wiki/world/` — standing up a GridWorks World (real / simulated / hybrid) to
  run gjk against.
- `changelog.md` — the WHY of each landed commit.
