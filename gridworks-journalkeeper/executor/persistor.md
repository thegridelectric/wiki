# gjk persistors — what the custom persistors do

Status: Draft · Pass 0 · Updated 2026-10-26

> Sub-spec of [`primary.md`](primary.md): the persistor stack in depth, with
> emphasis on the **channel model** and the fact that the `readings` fan-out is
> a **lossy projection**. The specific shape here is implementation
> (ultimately Joe's call); the load-bearing point this doc insists on is the
> lossiness and where meaning does/doesn't stay rigorous.

## The two tables a persistor touches

- **`messages`** — the faithful record: the decoded message stored whole
  (payload jsonb). Nothing is lost here; it mirrors the immutable bus record
  (EAR/S3).
- **`readings`** / **`reading_channels`** — a **derived, flattened
  time-series projection**: rows of `(timestamp, channel_id, numeric value)`.
  This is where information is selected, scalarized, and lost.

## Default vs custom persistors

The default path stores the message in `messages` and stops. A **custom
persistor** additionally fans selected fields into `readings` (and, for
layouts, maintains `reading_channels`). The custom persistors today:
`layout.lite`, `report.event`, `flo.params.house0`, `weather.forecast`,
`gw.weather.forecast.bundle.gt`, `gw.weather.observation`, `g.node.forest`,
and the alert, house-status and snapshot projections.

## The channel model — the kind is the row's fact

`reading_channels.channel_type` holds a `gw.channel.kind` value: what kind
of thing the row records, named by the list that declared it. The
journalkeeper writes it from the vendored enum, never a literal.

| kind | declared by | row's `channel_id` | unit vocabulary |
|---|---|---|---|
| **DataChannel** | `layout.lite.DataChannels` | the channel's Id | `spaceheat.telemetry.name` |
| **DerivedChannel** | `layout.lite.DerivedChannels` (`SynthChannels` before 007) | the channel's Id | `gw1.unit` (`spaceheat.telemetry.name` before 007) |
| **StateMachine** | `layout.lite.StateMachines` (the handle map before 013) | none | the state enum; `unit` its version |
| **HeatCallSynth** | the journal, for a house whose layout declares no heat-call channel | none | `gw1.unit` |
| **WeatherForecast** | the journal, from the scada's legacy `weather.forecast` | none | `gw1.unit` |
| **WeatherObserved** | the weather GNode's `gw.weather.channel.gt` | the record's Id | `gw1.unit` |
| **FloParams** | the journal, from `flo.params.house0` | none | `gw1.unit` |

A kind the layout declares has its meaning in Sema, and the row mirrors the
word. A kind the journal declares (`HeatCallSynth`, `WeatherForecast`,
`FloParams`) has its name and unit in persistor code (`PseudoChannel(...)`
literals, registered at import), the one place the ecosystem otherwise
insists meaning be explicit (`wiki/vision/where-meaning-lives-in-gridworks.md`).
`WeatherObserved` sits between: the row is the record's index, and the
station and the rest of the record are read from the journaled record by
the row's `channel_id`, never from the name.

`LayoutLitePersistor` is the channel registry keeper: it syncs all three kinds
into `reading_channels` and writes no readings itself; it defines the
channels the others write against. A row is one (name, definition) of the
terminal asset, the definition being unit, unit type and channel type; its
primary key is a surrogate (the layout's channel Id while no row holds it,
else a uuid4; a pseudo channel, which no layout names, the uuid5 of its
definition, `message_persistence_info.pseudo_channel_id`). The row's
`channel_id` is the layout's channel Id for the pair, written on every
sync: the lineage key a renamed channel's rows share (`vdc-relay1` and
`vdc-relay` at oak), NULL on a pseudo row and on a row whose unit no
layout Id names. A layout Id names one definition, so a channel whose
telemetry changes is a different channel with a different Id, and a house
moving between two layouts reuses the two rows: the sync reactivates the
most recently retired row of the declared name and definition and retires
the other active row of that name at the layout's time
(`layout_lite_persistor.ReadingChannelSyncProcess.reconcile`).
`deactivated_date` means absent from the current layout. A state-machine channel's `unit_type` is
the enum name and its `unit` the enum version the layout declares, so an
enum version bump is a new channel; a declared version the snapshot does
not vendor gets no channel and is tallied (`unvendored_machines`).

## What each custom persistor projects (and drops)

- **`report.event`** → `readings`, three sub-paths:
  - **channel readings** — `report.channel_reading_list` → readings keyed to
    *existing* `reading_channels` through the layout in force at the
    report's time (`channel_resolver`: the newest `layout.lite` message from
    the scada at or before the report; the `layouts` row is a cache the
    resolver reads and logs once when it names another message), which
    maps each name to the row of its declared definition in the era that
    contains the report; a report with no layout in force resolves by the
    era rule alone (`reading_channel_eras`). **A name with no row is
    skipped** and tallied in `dropped_readings`. A machine state the
    channel's enum version lacks is refused and tallied in
    `refused_states`. The row a name resolves to holds the layout's Id for
    that name as its `channel_id` (none on a pseudo row); a disagreement is
    tallied in `channel_id_mismatches` by (asset, channel, declared Id, row
    Id), the readings still written, and a live report journals one
    `glitch` (Warning, node `channel-resolver`, the journalkeeper's own
    alias) per key per UTC day with the count, so the alerter's reports
    see it.
  - **zone heat-call synthesis** — for every `*-whitewire-pwr` channel whose
    layout declares no matching `*-heat-call` channel, a `heat-call` pseudo
    channel is invented and each whitewire-pwr reading derives a 0/1 heat-call
    reading (on-threshold per site: beech 100 W, elm 1 W, default 20 W). This
    exists because most of the deployed fleet does not report heat-call
    natively (spruce is the exception); the analytics crew reads these pseudo
    channels. Where a layout *does* declare heat-call channels, the synthesis
    steps aside — that interaction is what the per-site layout migration has
    to preserve.
  - **machine states** — `report.state_list` is projected onto
    `SemaEnumPseudoChannel`s. For a house whose layout is `layout.lite`
    013 or later, the channels come from the layout's `StateMachines`
    declaration: one channel per declared machine, typed by the vendored
    enum at the declared name and version (the snapshot's current and
    `old_versions` enums, keyed by both), named `<node>-state`
    (the pico channels `<node>-pico-state`; the four machines the handle
    map named before keep those names for the same node and enum, so a
    stream continues across a roll). A declared enum the snapshot lacks
    gets no channel. A `machine.states` row projects into the channel of
    its hosting node, the handle's last dotted segment, when that
    channel's `unit_type` is the row's enum. For a house on 011 or 012
    the hand-kept `STATE_CHANNELS` map by machine handle still applies
    (with `auto.h→auto.lc`, `a.aa→ltn.la` rewrites), and a row whose
    enum it lacks is logged as unexpected and dropped. Each state string
    is converted to an **integer**: its position in the value list of the
    enum version the channel row declares in `unit`. A `machine.states`
    row names its enum without a version; the version is the one the
    layout in force declares for that machine, the same lookup as the
    channel's. The value↔int contract this creates on the `readings`
    table is specified in `wiki/gridworks-data/executor/primary.md`
    "Enum channel values". A state string the declared version does not
    list, or a declared (enum, version) the snapshot does not vendor,
    writes no reading and is tallied (`refused_states`, keyed by
    terminal asset, enum and version) in the run summary and the live
    log; the string survives in `messages`, and re-vendoring the
    snapshot is the fix. The machine-state stream, which also has its
    own sema types (`machine.states` / `single.machine.state`), is thus
    re-expressed as integer readings on pseudo channels: a lossy
    projection (enum→int) beside the full record in `messages`.
- **`flo.params.house0`** → 3 pseudo channels (`buffer-available-kwh`,
  `lmp-usd-per-mwh`, `total-usd-per-mwh`), taking only the **first** element of
  the forecast arrays (`lmp_forecast[0]`, …). The flo params object is large;
  this projects a handful of first-step scalars.
- **`weather.forecast`** → 2 pseudo channels (`forecast-ws`, `forecast-oat`),
  again only the **first** array element; the rest of the forecast horizon is
  dropped from `readings`. The row is per house, since the scada fetched
  the forecast for itself; it retires with the word.
- **`gw.weather.forecast.bundle.gt`** → one `WeatherObserved` row per
  observed channel the bundle binds, `channel_id` the record's Id, unit
  the record's, create-if-absent. No readings.
- **`gw.weather.observation`** → `readings` on those rows at the
  observation's time: each reading names its channel record, resolved
  through the journaled `gw.weather.channel.gt` from the same weather
  GNode to the row with that `channel_id`. An `Interpolated` observation
  writes none; the message row keeps it. The forecast words
  (`gw.weather.forecast`) write no readings: the latest forecast per
  bundle is a query over `messages`.
- **`g.node.forest`** → `g_nodes` / `connectivity_edges`
  (`g_node_forest_persistor.py`, `project_forest`). The registry's forest
  broadcasts (deltas and gnr's periodic snapshots) upsert these two tables,
  which are a projection of the grid-node-registry: nothing else writes
  them, and gjk never reads gnr's database (grid-node-registry executor
  "Write path & egress"). Rows key on the registry's immutable GNodeIds, so
  deltas, snapshots and replays converge. Each row's `sent_at` holds the
  forest's `SendTimeMs`; an older forest never overwrites a newer row,
  equal send times pass (replays stay idempotent), and replayed history
  (`live=False`, the S3 importer) never regresses current state. Edges
  whose endpoints are not yet projected wait for a forest that carries
  them; a new edge id claiming a (from, to) pair already held is skipped as
  an anomaly. `position_point_id` is the registry's opaque id, stored
  verbatim with no FK: no position content lives in `gw_data`.
  `python -m gjk.forest_bootstrap --api-base <gnr> <roots>` fills the
  projection from gnr's read API (`g.node.forest.request`) through the
  same `project_forest`, writing no `messages` row; it is for standing up a
  journalkeeper against a fresh database. Verified on a dev universe:
  `experiments/2026-08-05-registry-projection-rig/`.
- **`layout.lite`** → `layouts` (`layouts_projection.py`, `project`),
  beside its channel sync. One row per terminal asset, keyed on the
  TerminalAsset GNodeId looked up in `g_nodes` by the scada's alias with
  `.scada` replaced by `.ta`; a scada whose terminal asset has no
  `g_nodes` row is logged and not projected. The row holds the word
  verbatim with its name and version, the sender, the journaled message
  id and `sent_at` from the sender's clock (`CreatedMs` from 013,
  `MessageCreatedMs` before). The guard compares send times
  only: an older send is skipped, and a lower word version with a later
  send overwrites a higher one, so the row follows a house that moves
  between scada branches. The projection runs through
  `MessagePersistenceInfo.live_only_db_operations`, which the dispatch
  seam calls for broker messages only, so the persistor's history fan-out
  (`fanout_on_import = True`, the channel eras) still runs on replays
  while the projection never does. A row whose `from_alias` is the
  registry (`registry_alias`, unset until the terminalasset registry
  sends layouts) is kept against any scada message, and a differing
  scada payload is logged as a mismatch. `python -m gjk.rebuild_layouts`
  projects each sender's newest journaled `layout.lite`, decoded at the
  version it was sent, through the same `project`; run it after the
  migration that adds the table and whenever the table is suspect.
  Verified on the dev run, with the replay guard and the derived
  operating status: `experiments/2026-10-21-disentangle-dev-run/`.
- **`gw.house.operating.status`** → `house_operating_status`
  (`house_operating_status_persistor.py`, `house_status_projection.py`).
  One row per terminal asset keyed on the TerminalAsset GNodeId, the
  word verbatim with `created_at` from its `CreatedMs` and a `source`
  column for operators: `scada` when the house sent the word, `derived`
  when the row is deduced from the house's `layouts` row and its newest
  `snapshot.spaceheat` (Standby and its posture from the layout's system
  mode, the storage mode from the layout, ServiceMode Heating, TopState
  and LtnDispatching from the snapshot's state channels, AcceptsDispatch
  true in Auto and not Standby, ScadaBlind false, ValidationState
  UnValidated), built through the word's own class so a derived row is a
  valid instance. A scada row is guarded on `CreatedMs`; a derived row
  never overwrites a scada row. The deduction serves a scada that does
  not send the word and is deleted when every scada does. Live messages
  only, the same seam as `layouts`; `python -m gjk.rebuild_house_status`
  derives every house from its layout and snapshot, then projects each
  sender's newest journaled word over it, writing no `messages` row.

## The point: `readings` is a lossy projection

`readings` deliberately keeps a small, query-friendly numeric slice. It drops
structure, drops all but the first element of forecast arrays, scalarizes
enums, and encodes pseudo-channel meaning in code rather than Sema. **That is
acceptable only because the full record is preserved upstream** — the whole
message sits in `messages` (jsonb) and in the EAR/S3 history — so the
projection can always be re-derived or extended without data loss
(`wiki/vision/data-meaning-sovereignty.md`: complete record underneath,
opinionated projections on top).

Worth flagging for the owner (Joe's call):
- pseudo channels carry meaning that is **not rigorous in Sema** — a candidate
  for promotion to real channel types where it matters (esp. machine states,
  which already have Sema types);
- the `report.event` state handling **smushes** a typed stream into integer
  readings with a hand-maintained map + hash fallback;
- first-element-only projection of forecast arrays is a silent horizon loss.

None of these are bugs — they are projection choices. The job of this doc is to
make the lossiness explicit so it's a *decision*, not an accident.

## Open

- **The `readings` fan-out is the keeper's clock, and it does not scale
  to the hundred homes.** The keeper consumes one message at a time and
  persists each before taking the next. A `report.event` costs the
  keeper 1 to 3 ms per reading row it writes (one insert of every
  reading, conflicts ignored, into the hypertable), and a house's
  five-minute report holds 300 to 900 readings, so each report takes
  about 1 to 3 s. Every other journaled type persists in about 10 ms.
  Measured on hw1 at the 2026-10-22 20:00Z mark with five reporting
  houses: 32 messages, the last persisted 8.5 s after it was sent, the
  same spike at every five-minute mark and the same shape a week
  earlier. At a hundred houses the five-minute burst is 100 to 300 s of
  keeper time, which is the whole reporting period: the queue never
  drains and every other journaled fact, the MarketMaker's price among
  them, is persisted minutes late. The requirement: a report's cost to
  the keeper must not scale with its reading count in the message loop.
  Either the readings write is a bulk load whose cost is per report, not
  per row, or `readings` is projected off the message loop (the
  `messages` row first, the fan-out from it afterwards), so that a
  message's persist time is bounded by its own row. Reader-side cost is
  a separate fact: `readings` has no index on `message_id`, so a
  per-message count of readings is a full scan and times out.
  The change is OPS-616.

- **Pseudo channels from the layout, programmatically.** Done for the
  machine states of a house on `layout.lite` 013 (above). Still by hand:
  the `STATE_CHANNELS` map for houses on 011 and 012, which goes when
  the last house rolls, and the integer pseudo channels (price, weather,
  flo params).
