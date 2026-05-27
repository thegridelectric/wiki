# gridworks-journalkeeper — rebuild spec

Status: Draft · Pass 0 · Updated 2026-05-27

> Acceptable-minimum hub. Marks the load-bearing facts about what
> journalkeeper IS after Stages 1+2 of the 2026-05 refactor; sub-spec
> depth left "Open" for later passes.

## What gjk is (one line)

A non-GNode broker consumer that decodes a SELECT collection of Sema
messages that cross the bus and persists them to the `gw_data.messages`
table.

> **Tier:** journalkeeper belongs to the **analytics / UI part of the
> GridWorks ecosystem, NOT the production control plane.** Today it
> consumes directly from `ear_tx` on the production broker
> (`hw1__1`) — that arrangement is a transitional accident, not the
> target architecture. Once the **analytics broker** stands up
> ([`../../rmqbot/designs/analytics-broker-shovel.md`](../../rmqbot/designs/analytics-broker-shovel.md)),
> journalkeeper migrates off prod and consumes from the analytics
> broker's mirrored `ear_tx` instead. No analytics-tier service
> should hold prod-broker credentials.

## The central commitment

`ActorBase` (transport) + `SemaCodec` (decode) + `SemaMessagePersistor`
(persist) — three things, no in-tree type registry. **New Sema types
flow through with zero code edits in this repo**: the bind list is
`SemaMessagePersistor.all_known_message_types()`, which is the single
source of truth for what gets bound on the broker AND what gets
decoded + persisted.

## Invariants

1. **Not a GNode.** Inherits `gwbase.ActorBase`, not `GridworksActor` —
   no heartbeat / time-coordinator participation, no participation in
   GNode roles on the grid. The `g_node.json` that today's
   `ActorBase.__init__` still requires is a workaround; see
   gridworks-base **F-004** (`ServiceSettings` split is the proposed
   fix that lets gjk drop the file).
2. **SQLAlchemy models live in `gw_data`, not here.** The persistor
   writes via `gw_data.db.models.MessageSql` (and `ReadingChannelSql`
   / `ReadingSql` for `report.event`). Stage 2 deleted the in-tree
   `gjk.models/` precisely to enforce single-source.
3. **Sema runtime is a snapshot under `src/gjk/sema/`.** Driven by
   `src/gjk/sema_seed_request.yaml` (package-bound, snapshot-adjacent —
   see gwwf for the matching convention). No vendored `named_types`.
4. **`dispatch_message` errors are logged + swallowed.** The live
   actor MUST keep running across malformed JSON or unknown types;
   the S3 importer is the loud-fail counterpart (`scripts/`
   territory, different contract).
5. **Catch-all queue binding on the consume exchange.** Journalkeeper
   wants every message; per-type narrowing happens at the persistor,
   not at the broker. The consume exchange comes from gwbase defaults
   (`ear_tx` for the universal-tap class).

## Live path (after Stage 2)

```
broker (ear_tx, "#")
  └─ ActorBase consume → RoutingEnvelope + body bytes
       └─ JournalKeeper.dispatch_message
            └─ SemaCodec.from_dict(json.loads(body))
                 └─ SemaMessagePersistor.persist
                      ├─ LayoutLitePersistor.handle (layout.lite types)
                      ├─ ReportEventPersistor.handle (report.event)
                      └─ default: insert MessageSql(payload=jsonb)
                           └─ gw_data.messages
```

The 12 surviving modules under `src/gjk/` are exactly this path:
`journal_keeper`, `sema_message_persistor`, `layout_lite_persistor`,
`report_event_persistor`, `message_persistence_info`,
`pseudo_channels`, `config`, `sema/` (snapshot),
`sema_seed_request.yaml`, `__init__.py`, `py.typed`, `start_api.sh`.

## Glossary

- **JournalKeeper** — the live `ActorBase` subclass; one method
  (`dispatch_message`) that bridges transport to persistor.
- **SemaMessagePersistor** — the converged parse + persist entry
  point; replaces the hand-maintained `if/elif` over `gjk.named_types`
  that lived in journal_keeper before Stage 1.
- **LayoutLitePersistor** — sub-persistor for `layout.lite` family
  (versioned); maintains `reading_channels` rows derived from the
  layout.
- **ReportEventPersistor** — sub-persistor for `report.event`;
  fans the embedded telemetry events out into `readings` and
  registers `pseudo_channels` along the way.
- **MessagePersistenceInfo** — small dataclass carrying the
  per-message metadata (uuid, from_alias, type_name, persisted_at,
  timestamp) the persistors share.
- **PseudoChannel** — channels derived from telemetry rather than
  declared in the layout; registered lazily as report events arrive.
- **`messages` table** — `gw_data.public.messages`: id (uuid),
  timestamp, from_alias, persisted_at, message_type_name,
  payload (jsonb). Indexed by `(from_alias, message_type_name,
  persisted_at)`.

## What gjk stores (and doesn't)

> Inventory from a 10-minute observation run against the prod broker
> on 2026-05-27 (`scripts/point_at_prod_observe.py 600`, catch-all on
> `ear_tx`, fleet = 5 `keene.*.scada` instances). Counts are a
> snapshot — types and rates drift as the fleet grows. The
> **structural** distinction below (stored vs degraded vs
> routing-rejected) is stable.

### Stored — 5 types persisted to `gw_data.messages`

| `message_type_name` | Count (10 min) | Notes |
|---|---|---|
| `snapshot.spaceheat` | 95 | ~19 per scada — the high-volume real-time-state stream |
| `gridworks.event.problem` | 10 | Operational forensics — error / glitch reports |
| `report.event` | 10 | Telemetry batch; the persistor fans embedded events out into `readings` |
| `heating.forecast` | 5 | LTN forward-looking forecast |
| `weather.forecast` | 5 | LTN weather forecast (the eventual `weather` v000 replacement) |

These are the types `SemaMessagePersistor.all_known_message_types()`
both **binds** on the broker AND knows how to **decode + persist**.
The list grows when new types land in gjk's sema snapshot.

### Received but DEGRADED — never persisted

| Type (version) | Count | Why degraded |
|---|---|---|
| `gridworks.ack` (no version) | 39 | Type not in gjk's sema snapshot at all; degraded SEMA at codec level |
| `slow.contract.heartbeat` (v001) | 23 | Version drift — gjk's snapshot likely has an older or differently-versioned variant |

The persistor's behaviour is **received → decoded as degraded →
logged as warning → skipped**. The actor stays up; no row in
`messages`. These are candidates for inclusion in a future sema-snapshot
regen if we decide we want them.

### Routing-key REJECTED at ActorBase — never reached dispatch

| Routing class | Types observed | Count | Reason |
|---|---|---|---|
| `s` | `s.gridworks-ping` (48), `s.slow-contract-heartbeat` (34), `s.gridworks-ack` (20) | 102 | Legacy short form for `scada`. The gwbase enum is `['ta','cn','ltn','mm','scada','price','weather','time','super']`; `s` isn't in it. Same F-007 family as the `ws`-instead-of-`weather` drift. |
| `broadcast` | `broadcast.glitch` (3), `broadcast.flo-next-hour-plans` (2) | 5 | `broadcast` is not a routing class in the gwbase enum at all — this is a new routing pattern the prod fabric has invented without a matching gwbase declaration. |
| `ws` | `ws.weather` (1) | 1 | Legacy short for `weather` (F-007). |

These messages get parsed by ActorBase, the routing-class lookup
fails, and they're rejected before reaching `dispatch_message`.
**They're real traffic gjk could be persisting but isn't, because
the framework can't even look at them.** Fixing requires either:
- adding `s`, `broadcast`, `ws` to the gwbase `RoutingClass` enum
  (matches the prod fabric, perpetuates the drift), OR
- migrating producers to emit canonical long-form routing classes
  (matches gwbase, requires a coordinated rollout across the fleet).

### Traffic mix at a glance (10 min, 5-scada fleet)

```
~295 msgs total on ear_tx
├─ 125  stored      (42%) — 5 known types, decoded and persisted
├─  62  degraded    (21%) — 2 known type-names but unusable versions, skipped
└─ 108  rejected    (37%) — 3 routing classes the framework doesn't speak
```

That 37% routing-rejected slice is the load-bearing observation: gjk
today sees less than half of the addressable bus traffic *as decoded
messages*. Closing that gap is a gwbase / rollout question, not a gjk
question — gjk's job is to persist what reaches it.

## Sub-specs (Open)

- **`persistor.md`** (Open) — the persistor stack in depth: how the
  three persistors compose, idempotency model, error semantics,
  pseudo_channel registration.
- **`retention.md`** (Open) — see `concerns/scale-strategy-starter.md`
  for the seed insights; the question is mostly a `gridworks-data`
  schema decision, so the proper spec home is likely there.
- **`operational.md`** (Open) — start/stop, supervisor wiring, log
  destinations, restart semantics.

## Cross-refs

- `wiki/gridworks-base/executor/primary.md` — the framework. Note
  F-004 (non-GNode service settings), F-005 (XDG paths), F-007
  (routing-class long-form discipline).
- `wiki/gridworks-base/research/findings.md` — same F-numbers.
- `wiki/gridworks-data/` — sibling models + the retention question
  proper home.
- `wiki/sema/primary.md` — type runtime; the snapshot under
  `src/gjk/sema/` is the consumer slice.
- `research/findings.md` — F-001…F-007 from the 2026-05-26 gwwf→gjk
  dev-rabbit integration test (live-path verification, hack pattern
  fragility, broker fabric notes, harness shape, XDG gap).
- `research/refactor-to-base-0.4.2.md` — the planning doc behind
  Stages 0–3 of the refactor.
- `changelog.md` — the WHY of each landed commit.
