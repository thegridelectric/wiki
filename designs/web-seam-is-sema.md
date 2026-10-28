# The web seam is sema

Status: Draft · Pass 0 · Updated 2026-10-26 · Linear: [OPS-622](https://linear.app/gridworks/issue/OPS-622)

**EDD: no** build-out across the journalkeeper, the web-backend, the
web-frontend and sema, verified by each repo's suite and a page check
against `tsdb_tap`.

> What this is: the second stage of OPS-542's work, split out once the
> readers worked across layout eras and were published. The three data
> repos stop deciding meaning by channel-name strings and read it from
> the layout word; every structure the backend serves to the browser is a
> word on both sides, typed in the browser by a generated snapshot. It
> waits on the TypeScript emitter in sema (its own design) and on the
> functional-name vocabulary below.

## Do this next

**▶ Do this next.** The TypeScript emitter design in sema, then the
build order at the end of "The state seam".

## Open now: spruce pump power

Spruce's `dist-pump-pwr` has readings to 2026-10-25 21:00 UTC and none
since, averaging 15 W over the week before; `primary-pump-pwr` and
`store-pump-pwr` have no readings in the same week (OPS-594, checked
2026-10-26 on the journal). The channel rows are one lineage across the
layout change, so this is the scada or a pico not reporting, a spruce
question for OPS-392, and only a seam question if the readers turn out
to drop a row of the lineage. Resolve it before the comb-through
treats the real-time page's flow table as a reader fault.

## The three repos

The fleet emits, JournalKeeper writes the journal DB, the web-backend reads a
façade over it, the web-frontend visualizes. The cleanup is on:

- **gridworks-journalkeeper** — every place a persistor decides what a
  channel is from its name: the hand-kept `STATE_CHANNELS` map, the
  heat-call synthesis keyed on `*-whitewire-pwr`, and the rest of the
  string matching in the persistors
  (`gridworks-journalkeeper/executor/persistor.md` "Open"). Pseudo-channels
  stay; what changes is that gjk derives them from the layout it receives
  rather than from literals in code. One goes away outright: the
  `buffer-available-kwh` pseudo channel in `flo_params_house0_persistor.py`
  stores the LTN's `BufferAvailableKwh`, which the LTN computes from a
  hard-coded four-layer buffer and returns as 0 whenever `KeepBufferFull`
  is true (every deployed House0 house). No layout has that buffer any
  more, so the channel is removed rather than re-derived; the journal's
  existing rows stay, a rebuild from scratch will not have them. It is the
  only live emitter of the `KilowattHoursX1000` unit value, which stays in
  `gw1.unit` because 002 is published.
- **gridworks-web-backend** — the public read-only façade: the API returns
  the channels and layout/params shape for every family from the layout
  word, with no per-house channel-name table.
- **gridworks-web-frontend** — the visualizer: it renders each family from
  the layout, including the families with no buffer tank or iso valve and
  the one with no water store tanks at all.

## Functional names

The data services decide what a channel is from its name because the
layout gives them nothing else to look up: the functional names
(`hp-lwt`, `dist-swt`, `primary-flow`, the zone whitewire and heat-call
channels, the state-machine handles) live in python in
`gwsproto.names`, and in sema only as literals inside the axioms of the
staging full-layout words. tlayouts has the same problem from the other
side: tlayouts `main` imports `gwsproto.names` from gridworks-scada to spell
the names it writes. One fix serves both: the names become sema.

The cleanup goes in two stages:

1. **Staging `layout.lite` 013 states what the database needs.** Edited
   in place while it is staging: the state machines (handle, state enum
   word, version), the zone-call circuits (whitewire channel, heat-call
   channel, threshold), the heat-call DerivedChannels so gjk stops
   synthesizing them, and the store and buffer depth channel lists. This
   retires `STATE_CHANNELS`, the handle remaps, the heat-call synthesis
   and the per-house thresholds.
2. **Role bindings wait for the full layouts.** Picking a channel by
   role (the heat-pump and distribution plot lists, zone grouping by
   name prefix) needs a sema vocabulary of functional roles, which the
   staging `gw.house0.layout`, `gw.nolan.layout` and `gw.hydronic` words
   point toward. It is published with them.

The vocabulary comes before the bindings: tlayouts writes the bindings,
so it needs the role names first. Its full exit from `gwsproto.names`
also needs what is not a channel role:

- **Core actor node names** (`s`, `lc`, `auto`, `derived-generator`,
  `power-meter`), which also build hierarchy names
  (`f"{Core.primary_scada}.{name}"`, tlayouts `layout_gen.py:705`). A
  node-role vocabulary sits beside the channel-role one. The web-frontend
  needs it too: it parses the command trees and state machines in full
  only when it knows which core actor each node is.
- **Per-family name sets** (House0, Nolan, Hydronic), which suggests the
  vocabulary belongs with each full-layout word rather than in one flat
  enum.
- **`DeviceType`** (tlayouts `device_types/__init__.py:15`, already "the
  local name for gw1.device.type") moves to the vendored sema enum now;
  it does not wait.

tlayouts drops its gridworks-scada import once the node and channel role
vocabulary is published.

## No per-house specials

The three layout families (`gw.nolan.layout`, `gw.house0.layout` with the
sieg loop, `gw.house0.no.sieg`) must ingest and display by their
layout-sema declaration, not by hand-mapped channel names (the standing
team rule: data analysis never slows the production system, and hard-coded
channel-name strings in data services are the named enemy). The tell that
vocabulary is missing or unused is code that scrapes instead of looking up.

## Rename `reading_channels.terminal_asset_alias` here

`reading_channels.terminal_asset_alias` becomes `about_g_node_alias`,
nullable: a channel is about a GNode, and a channel of aggregated power
across every terminal asset in Millinocket is about none in particular
(decided 2026-10-15 under OPS-473, deferred here because every consumer
binds the column by name and this design is where they are all rewritten).
What the rename touches, from a read of the live journaldb and the
repos on 2026-10-15:

- **gridworks-data:** `ReadingChannelSql.terminal_asset_alias` and the
  unique constraint on (alias, name, deactivated_date), which stays with
  `NULLS NOT DISTINCT`. The index named `terminal_asset_alias` is on
  `name`, a misnomer to fix in the same migration. The three SQL
  functions under `scripts/misc` (`retrieve_readings_1s`,
  `calc_energy_1hr`, `calc_hourly_data`) read the column by name in text
  bodies and must be recreated; the `readings_1hr` continuous aggregate
  and `cached_hourly_data` carry an output column of the old name, which
  is dropped and recreated if the name is to go through. The aggregate
  follows a rename of the underlying column by attribute number, but
  prove that on a local timescaledb-ha container before journaldb.
- **gridworks-journalkeeper:** creates channel rows through the gw_data
  model and loads them by alias (`reading_channel_eras.load_channel_rows`,
  the report-event, layout-lite and weather-bundle persistors). Breaks on
  the first insert after the rename unless deployed in the same window.
- **gridworks-web-backend:** raw SQL naming the column in
  `hourly_data_download`, `installation_summaries`, `readings_csv`,
  `hourly_electricity`; model references in `readings_csv` and
  `synced_readings_bundle`. The `terminal_asset_alias` strings in its
  sema types are the sema word's field, untouched.
- **gridworks-alerts:** reads the column through the model in
  `alert_generator.py` and derives the house alias from it.

One window: gw_data release, then journalkeeper, web-backend and alerts
deployed with the migration.

A `WeatherObserved` row is about a station, and a station is not a GNode,
so the renamed column is NULL on those rows; the station is the record's
`StationAlias`, reached by the row's `channel_id` (the record Id is the
record message's id, a primary-key hit, about a millisecond warm across
the hypertable's chunks). Until the rename the NOT NULL column holds the
weather GNode's alias as a placeholder.

## The state seam

Canonized 2026-10-24. The rule GridWorks already holds applies to every
change at the backend-to-browser seam: the seam is sema (a word on both
sides, no string conventions), and nothing the scada reported cleanly is
lost on the way to the browser. The order of work: the spruce page works
on the strings it has today; the comb-through of the browser's patterns,
each one annotated with the fact it extracts and the declared fact that
replaces it, decides what the layout and the operational parameters
declare; the words follow.

### What the scada reports and what the browser receives

A state machine arrives as `machine.states`: the machine's handle, its
state enum, the state symbols and millisecond times; the 013 layout
declares the machine (`gw.state.machine`: node name, state enum, state
enum version). The browser receives `operating.state.sequence`: a channel
name, the symbols, the times. Lost between them is the machine's
identity: the journalkeeper derives the channel name from the node name
and a suffix (`report_event_persistor.py` `declared_state_channel_name`),
and the browser selects a strip by regex on that name
(`DefaultVisualizerPlot.tsx` `matchChannelName`). Neither side can recover
the node or the enum from the name. The row's kind, enum and version are
read (gridworks-web-backend executor `primary.md` "The readings csv and
bundle").

### `channel_type` is `gw.channel.kind`

The row's kind, who declares each kind and what its `channel_id` and unit
vocabulary are: gridworks-journalkeeper executor `persistor.md` "The
channel model — the kind is the row's fact". How the readers use it: the
web-backend executor `primary.md` "The readings csv and bundle". The
production relabel of 2026-10-25: gridworks-infra `databases/journaldb.md`
"Data changes run by hand".

A layout fact for the finalize work: in the spruce 013 layout every relay
appears twice, as a RelayState data channel and as a
`relay.closed.or.open` machine. One fact, two rows.

### The seam audit

Read 2026-10-25 across both repos, one row per route and websocket
message. The frontend's `src/sema/*.d.ts` are written by hand; no emitter
exists in the sema repo or either web repo, so each is typed to the fields
a page reads and drifts from the word.

- Sema on both sides: `summaries` (`gw.house.summary` through
  `to_dict()`, `HouseSummary.d.ts`).
- Sema on the backend and in wire form, hand-typed in the browser:
  `synced.readings.bundle` (its three `.d.ts` match the words, kept by
  hand) and `messages` (`glitch`, `gridworks.event.problem`,
  `weather.forecast`; the morning report and the weather plot type them
  by hand without TypeName).
- No word at all: `alerts` (alert-manager's snake_case rows proxied
  through a pydantic model), `hourly.electricity` without `dl` (positional
  `[ts, kwh, usd_per_mwh]` arrays), the gateway's websocket (`status`,
  `mqtt_message`, `zone_whitewire_series` are hand envelopes; the
  `mqtt_message` payload is a `snapshot.spaceheat` dict; the browser
  reads `status` and `mqtt_message` by hand types, drops
  `zone_whitewire_series`, and has a dead `error` branch), and the price
  forecast, which `pricing-api.ts` fetches from the price service
  directly, bypassing the backend.
- Files, out of the word layer: the csv downloads (`readings.download`,
  `hourly.data`, `hourly.electricity?dl`, the bundle's `dl`) and
  `flo.download` (xlsx). `sessions` is an OAuth2 token on purpose.
- The legacy `backend_api.py` routes have no caller in the frontend.

The structural fix is a TypeScript emitter in sema, so the browser vendors
its snapshot the way the backend does; until then the `.d.ts` are
reconciled by hand against the backend's generated classes.

### The exception table and the handle map are one relic

Before 013 the scada did not declare its machines, so the journalkeeper
kept `STATE_CHANNELS`, keyed by actor handle (`auto`, `auto.lc`,
`auto.lc.n`, `ltn.la`), naming each machine's channel by hand. With 013
the general rule became `<node>-state`, and `CONTINUED_STATE_CHANNEL_NAMES`
keeps the seven hand-named streams under their old names across the roll.
The general rule collides (a node hosting two machines, as `n` did before
013, gets one name for both) and names badly (`s-state`, `n-state`).

The table goes when a state row records what identifies the machine, node
name plus enum plus version, and readers select by that. Pre-013 rows have
the node in the handle's last segment and the enum in `unit_type`, so the
migration backfills them, and the name column stops being an identity.
The handle map stays as data for replaying pre-013 reports from S3, a
recorded mapping and not live naming. Until the identity columns exist the
continued names are what keeps the state lineages whole across the roll:
state pseudo rows have no `channel_id`, so the csv and bundle knit them by
name alone.

### The heat-call synthesis

The journalkeeper makes a heat-call pseudo channel only when the layout
declares no DataChannel or DerivedChannel of that name, and synthesizes
nothing from a report that has heat-call readings of its own. The fleet's
013 layouts declare heat-call as derived channels (oak four, maple two,
spruce five), so a 013 house gets no synthesis; in oak's 013 era all 17
reports with whitewire readings had heat-call readings, and the derived
rows have their own (three per zone, a derived channel reporting on
change, where the synth wrote one reading per whitewire sample). The guard
is keyed on declaration and content, which is the right key; it decides by
substring (`"heat-call" in channel_name`, `"whitewire-pwr" in name`) and
routes by name, so a 013 report with whitewire readings and no heat-call
readings would write synthesized values into the derived channel's row.
With `gw.channel.kind`, synthesis targets HeatCallSynth rows only.

Two lives to retire separately. The live path goes once no house runs
pre-013 code and the toggle is over (beech and fir are on 011). The replay
path matters only for re-importing pre-013 reports from S3; those readings
are journaled, so the rule and its per-site thresholds (beech 100 W, elm
1 W, default 20 W) move to the journalkeeper executor as the record of how
the historical pseudo rows were made.

### The browser's patterns

The visualizer's regexes encode five structural facts the layout knows:
zone ordinal and zone name (temps, setpoints, floor temps, heat-calls,
whitewire power), tank and depth ordinal (buffer and tank1 to tank3),
machine grouping for the LTN and local-control strips, and the user-typed
`^...$` selectors (`plot-configs.ts`, `HeatCallsPlot.tsx`,
`DefaultVisualizerPlot.tsx`). Each gets a note when touched: the fact it
extracts and the layout or sema fact that replaces it. The zone ordinal
has to be declared, not spelled into a name. Getting gwsproto's `names`
(the house0 node and channel vocabulary) into sema gives both sides that
vocabulary as a checked fact, which is the fix for the user-typed selectors
and the depth patterns. The state identity above, the depth ordinal and
the heat-call naming are separate gaps from the regexes themselves.

### The real-time page

The real-time page (`RealTimeStatusPage.tsx` and the diagram under it)
decides three different things from one test, whether the house alias
contains "spruce". Each is a fact the layout word states, and the page
reads each from the layout once the plant families are settled:

- **The plant family drawn.** The two-tank diagram with the exchanger
  column is the Nolan plant. `layout.lite` 013 has
  `HardwareLayoutTypeName`; spruce's is `gw.nolan.layout`, and elm's
  becomes `gw.house0.no.sieg` (OPS-628). The families share some of the
  picture: elm has the exchanger and the secondary loop; it has no fan
  coils and no radiant floor. The diagram therefore keys its parts on
  layout facts rather than on a family switch, and the family name is
  only the default geometry. This waits until elm is integrated and the
  no-sieg family is real in the fleet; a cleanup made against spruce alone
  would bake in a two-way switch that the third family breaks.
- **The secondary loop.** Present when the layout has a `secondary-flow`
  channel, read the way `layoutHasSiegLoop` reads `sieg-flow`. The
  secondary pump row, the secondary animation input and the flow table
  key on it. The six-segment heat-pump header (secondary leg to the store
  or to the buffer) is positioned around the exchanger column, so it
  follows the exchanger, which the diagram draws from the family's
  geometry.
- **The zone table.** The gateway's `thermostat_names_from_layout` runs a
  regex over channel names and turns `zone1-bedrooms-gw-temp` into a
  thermostat named `bedrooms-gw`; the browser then filters names ending in
  `-gw`. Every stored layout since 011 has `ZoneList` with the zone names,
  so the gateway reads `ZoneList` and the browser's filter goes. The
  spruce branch of the table also reads zone temperature and heat-call by
  name match; it goes with the family cleanup above.

The realtime seam itself is unit-less: `single.reading` 000 sends
ChannelName and Value, and the browser divides flows by 100 and converts
temperatures by hand. The word that fixes it names the channel by Id and
the reader looks the unit up in the layout, the same lineage-by-Id rule the
bundle readers follow; which word is a sema question with the spec first.

The hourly functions in the journal DB have the same gap one layer down,
unit literals per channel (`unit='GpmTimes100'`), which a derived channel
in the `gw1.unit` enum (`GpmX100`) slips past; that is OPS-630, not this
design.

### The house's control mode

The top strip shows LocalControl, LeafTransactiveNode and Admin, a
projection across two machines (Admin is in `gw.top.state`, the other two
in `gw1.main.auto.state`). A useful projection, so it becomes a sema enum,
`gw.house.control.mode` (published at `000`): Unknown (the default),
LocalControl, Ltn, Admin.
The backend derives it from the `gw.house.operating.status` stream
(`top_state`, `ltn_dispatching`) for a 013 house and from the two machines
before, and sends it as its own sequence. The LTN and local-control strips
become the declared machines by (node, enum), with the browser's symbol
table keyed by the enum version; whether the strips still want the full
machine hierarchy is a browser question for the comb-through.

### The bundle's state part

Names the machine as the scada does: node name (or handle), state enum,
state enum version, symbols in that version, millisecond times. Whether
that is `operating.state.sequence` at a new version or `machine.states`
with the version added is a sema question, decided under `sema-CLAUDE.md`
with the spec first. The browser selects a strip by (node, enum), and the
regex table goes.

### Order of the build

One spoke, with `wiki/tools/backend.sh` for the sessions that touch the
backend or the browser:

1. web-backend: the control mode derived from the
   `gw.house.operating.status` stream (013) and from the two machines
   (before), sent as its own sequence; the state part names the machine.
   Built on dev against `tsdb_tap`.
2. web-frontend: strips by (node, enum) and the control-mode sequence; the
   regex notes from the comb-through become the layout and
   operational-parameter asks. The types come from the TypeScript emitter
   (its own sema design) once it exists; until then they are kept by hand
   to the words.

## Open

- The dashboard's Parameters page opens on hard-coded defaults in the
  frontend model (DD power 12 kW, DD RSWT 180 F, intermediate RSWT
  130 F) while the house's `layout.lite` row has the scada's own
  `Ha1Params` (cedar in the dev run: 9 kW, 160 F, 100 F). The page has
  the layout since OPS-473 and could read them from it; Ha1Params is
  itself on its way out, so the fix waits for whatever replaces it.- Settled 2026-10-26: this design states what `layout.lite` 013 must
  declare (stage 1 under "Functional names"); OPS-392 ships those edits
  before 013 publishes, since that work owns the staging-to-published
  move. Seam findings from OPS-392 and OPS-542 sweep into this design's
  comb-through ("The browser's patterns") and nowhere else.
- The functional-name vocabulary is shared by tlayouts, the
  journalkeeper and the browser, so it gets its own flat issue and
  design; this design names it in prose when that issue exists.
- Where the name-reuse rule (a channel name is reused only for the same
  quantity) is checked: in tlayouts, or stated as an axiom of the layout
  word. The web-backend's lineage-by-name rests on it and nothing
  enforces it today. From OPS-618.
- On the replaced-enum item above: the journalkeeper's refusal tally
  (`refused_states`, keyed by asset, enum and version) already answers
  how a replaced enum reaches the journal; what stays open is the hole
  in the readings for that machine. From OPS-618.- Whether the simulated fourth fall layout (OPS-532) is exercised here too.- The state enums the journal fans out versus the registry. Sema deleted
  `gw1.local.control.standby.top.state` on 2026-10-06 (`f234cfd`,
  `replaced_by: gw2.lc.top.state`) while the enum was still vendored in
  JournalKeeper's snapshot and bound to the `local-control-standby-state`
  pseudo channel; the 2026-10-15 gjk regen had to drop both to build.
  Deleting a published enum a consumer vendors is the pattern to look at
  here: which `gw1.*` state enums the gjk pseudo channels still name,
  which the scada on `main` reports, and how a replaced enum
  reaches the journal without a hole (readings for that machine stop at
  the deletion; none in the 60 days before it).
