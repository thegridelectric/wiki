# Harmonize the visualizer with the new main

Status: Draft · Pass 0 · Updated 2026-10-25 · Linear: OPS-542

**EDD: yes** the day of fleet data from the spruce-unlimbo first data catch
is the verification; a claim reaches Verified only when that data reads the
whole way up (journal, façade, visualizer) by layout lookup alone, against
real services (`experiments/`).

> What this is: the data side of the spruce-unlimbo launch (OPS-392), in
> two stages. First, the readers (JournalKeeper, the web-backend, the
> web-frontend) work across layout eras on the data the fleet now
> produces, with the gate for merging `jm/spruce-unlimbo` into `main`: no
> errors on the visualizer page over any window, and George happy with the
> time series. Then the string cleanup: the three repos stop deciding
> meaning by channel-name strings and read it from the layout word. Kept
> out of spruce-unlimbo because it is a different set of repos with its
> own verification; the launch's deployment spoke points here by Linear id.

## Do this next

The fleet's night of 2026-10-23 is the dataset: oak on 013 from 01:42:45
to 01:57:23 and from 03:07:29 to 03:17:46 ET, maple from 03:12:00 to
03:23:10 and from 09:48:24 to 09:57:52, spruce from 00:57:45 to 03:18:52,
each house on its old line otherwise (the `layout.lite` arrivals in the
journal). Every reader fault shows against it.

1. ✅ JournalKeeper checks every report's rows against the layout in force
   and journals a daily Warning glitch on a drifted `channel_id`
   (`gridworks-journalkeeper/executor/persistor.md` "What each custom
   persistor projects"); the resolver takes the newest `layout.lite` at or
   before the report and treats the `layouts` row as a cache that must
   agree. Run 2026-10-24 as production code on `tsdb_tap`, the laptop
   database with the production channel and layout tables
   (`experiments/dev-stack-recipe.md` "A production-shaped journal DB"):
   175 reports from the cutover night replayed, then 25 minutes of the
   live stream from the tap broker; no mismatch tallied, no glitch, no
   stale row. Persist time unchanged against the parent commit (means
   within 3 ms per house); on the production DB the new lookup is 6–9 ms
   per house per boot and under a millisecond after.
2. ✅ The local reproducer (2026-10-24): the web-backend on the laptop
   against `tsdb_tap` (`experiments/dev-stack-recipe.md` "A
   production-shaped journal DB"), with oak's readings of 2026-10-23
   04:00–08:00 UTC copied in, logged in as the dev admin. A window inside
   the old era answers 200; every window touching a 013 era answers 500:
   `SyncedReadingsBundle` fails `ChannelDefinitionBijection` with
   "ChannelName values buffer-cold-pipe,buffer-hot-pipe,hp-lwt were
   repeated", because the query groups by (name, unit, unit type) and a
   changed channel has readings in two rows. A window entirely inside the
   013 era (05:43–05:56 UTC) fails too, though only the 013 row has
   readings in it: the query starts thirty minutes before the window so
   the time-weighted average has a starting value
   (`synced_readings_bundle.py` `start_buffer_s`), and that reach-back
   finds the old row's readings up to 05:37. Spruce's 013 era ran 2 h 21
   min (04:57:45–07:18:52 UTC): a window from 05:45 to 07:00 answers 200
   with one series per name in the 013 unit; a window starting twelve
   minutes into the era, or ending seven minutes after it, answers 500.
   So the fault is the thirty minutes either side of a unit change, and a
   house that stays on 013 reads fine from half an hour in. Units: the
   frontend converts each series by the bundle's `Unit`
   (`DefaultVisualizerPlot.tsx` `UNIT_CONVERSIONS`, `CelsiusTimes100`
   known), so spruce's 013 temperatures display right (hp-lwt median raw
   4398 = 44 °C, against 44 875 in `WaterTempCTimes1000` the hour
   before); oak's and maple's 013 rows hold values ten times too large
   for the label (oak hp-lwt median 33 611 under `CelsiusTimes100`) and
   display as hundreds of degrees.
3. ✅ The bundle endpoint knits the rows of one name into one series in
   the newest row's unit, as the csv does (`api/v2/readings_units.py`,
   shared by both routers): the request picks lineages by any name they
   have had, each row's values convert into the series' unit as an affine
   map inside the query, before the time-weighted average, and the rows of
   a lineage average together. Run 2026-10-24 on the laptop against
   `tsdb_tap` (`experiments/dev-stack-recipe.md` "A production-shaped
   journal DB"): all eight recipe windows answer 200 with one series per
   name. Oak's series are in WaterTempCTimes1000, since oak's rollback made
   that row active again, and its 013-era points convert into it ten times
   too large (hp-lwt median 258 130 in the 05:43–05:56 window, hundreds of
   degrees). Spruce's 013 points are right (hp-lwt 39.2 °C in the
   05:45–07:00 window, which answers in CelsiusTimes100 because the only
   row that window and its look-back reach is the retired 013 row). A
   state row is no series: the bundle word labels a series with a unit
   vocabulary (`synced.readings.bundle` axiom 5), so a requested state
   channel is left out where it answered 500. Local reproducer:
   `tests/test_synced_readings_bundle.py`.
4. ✅ The bundle's `OperatingStateSequenceList` reads every state row,
   whatever its stamp (before, `query_operating_state_sequences` took rows
   stamped `Enum` only, so the 013 era's versioned state rows, unit `000`
   and `001`, never reached the browser's state strip). It picks state
   rows by a unit type outside the unit vocabularies, resolves each
   position through the row's (enum, version) with `Enum` resolving
   through the newest vendored version, detects a change on the symbol
   rather than the position, since positions renumber across versions,
   and sends times to the millisecond, since a machine changes state
   twice in one second at boot (spruce `hp-watch-state` at 04:59:37.332
   and .518) and the word's times are strictly increasing. It keeps the
   channel-name key the browser matches on: the spruce page works on
   strings first, and the comb-through of the browser's patterns ("The
   state seam") decides what the layout and the words declare in place of
   them. Run 2026-10-24 against `tsdb_tap`: oak's 013 era (05:42–07:17
   UTC) answers 32 machines where it answered one, spruce 04:30–07:30
   answers 38, and the eight numeric windows still answer 200. Local
   reproducer in `tests/test_synced_readings_bundle.py`.
5. ✅ The row's kind (2026-10-25): `gw.channel.kind` staged with one
   DerivedChannel value for both declaring lists, WeatherObserved added;
   the journalkeeper on `jm/synth-rows-as-derived` writes every row's
   `channel_type` from the enum through a staging snapshot and writes
   observed weather readings; the rename script
   (`gridworks-data` `channel_type_to_kind.sql`) ran on `tsdb_tap`:
   1279 DataChannel, 236 DerivedChannel, 273 StateMachine, 39 FloParams,
   37 HeatCallSynth, 26 WeatherForecast, 3 WeatherObserved, no row
   uncovered, the three observed rows with the record's Id as
   `channel_id`.
6. **▶ Do this next.** The journalkeeper branch `jm/synth-rows-as-derived`
   as production code against `tsdb_tap` (already renamed) on the tap
   broker (`experiments/dev-stack-recipe.md` "Feed it"): the EDD run that
   watches an observation arrive as readings on the three observed rows
   and a report resolve through the renamed rows with no duplicate row
   opened. That run is the gate for promoting `gw.channel.kind` and
   rebuilding the snapshot without `ALLOW_STAGED`. Then the rename and
   the deploy in one window, as the channel_id step went on 2026-10-23:
   the script on production, both of us consenting, and the journalkeeper
   deployed in the same window, since today's `main` on the gjk box
   writes the old strings and compares `channel_type` when it matches a
   declared channel to its rows, so a renamed table with the old code
   would open duplicate rows at the next layout. The production dry pass
   is done (2026-10-25, `DB_GW_ADMIN_URL`): the same 1279 / 236 / 273 /
   39 / 37 / 26 / 3, no row uncovered, rolled back. The run goes in
   gridworks-infra `databases/journaldb.md` afterwards. The web-backend
   and the hourly function still select nothing by `channel_type`; the
   readers' move to selecting state rows and heat-call rows by kind is
   the next item after.
7. The dataset folder `experiments/013-cutover-windows/`: the era table,
   a harness that runs the bundle, csv and hourly readers per era and per
   spanning window, one verdict per claim. Suspected and unverified: the
   bundle's LOCF fill copies a retired row's last value forward across
   the rest of the window; three spruce rows went stale at its rollback
   (forecast-oat, forecast-ws, vdc-relay). A harness item for the house0
   renames: whether the journalkeeper, the hourly calculation
   (`cached_hourly_data`, filled by a gridworks-data job not yet read) and
   the downloads still read right at spruce, whose 013 rows are retired
   under names the browser does not know (`n-state`, `s-state`,
   `*-relay-state`). The 013-era temperatures oak and maple journaled ten
   times too large are explained: those boxes ran 013 without the scaling
   code spruce had, and spruce's 013 points read right, so the readers are
   right going forward. What remains for those hours is a one-off
   correction of the journaled points, or leaving them.
8. The gate, then the merge (the launch's deployment spoke).

## Sequence

1. **The first data catch** (OPS-392, `deployment.md` "The first data
   catch"): `layout.lite/013` published, gjk creating its channels, the
   heat-call guard on gjk, three boxes on `jm/spruce-unlimbo` on the
   production broker for a day, readings landing.
2. **Boxes to `main`, maybe.** After that day the launch decides whether the
   boxes move to `main`. This design does not wait on that call; it needs
   the caught data, not the swap.
3. **This design: the string cleanup**, against the caught data.

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
side: `jm/spruce` imports `gwsproto.names` from gridworks-scada to spell
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

## The experiment (the EDD bar)

Read the caught day through the whole pipeline, asserting:

1. **Channels arrive.** Every channel each box's layout declares is in the
   journal DB, none dropped and none silently renamed, with no gjk code
   naming a channel.
2. **Hourly data parses.** The hourly rollup the web-backend serves parses
   for each family, with no decode error on a family-specific channel.
3. **The visualizer works.** The web-frontend renders each house's page from
   its layout: the channels present, nothing assuming a tank or valve the
   family lacks.

The harness is a re-runnable reproducer; findings distill into scoped
Verified claims once it is green.

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
name, the symbols, the times. Lost between them:

- The machine's identity. The journalkeeper derives the channel name
  from the node name and a suffix (`report_event_persistor.py`
  `declared_state_channel_name`), and the browser selects a strip by
  regex on that name (`DefaultVisualizerPlot.tsx` `matchChannelName`).
  Neither side can recover the node or the enum from the name.
- The enum and its version. The row records both (`unit_type`, `unit`);
  the backend reads neither (step 4 above).
- Which rows are state machines. The journalkeeper knows at write time
  (`SemaEnumPseudoChannel`) and writes `channel_type = "gjk.pseudo"`, the
  label it gives every row it invents; a reader tells a state row by
  exclusion (`unit_type` outside the unit vocabularies).

### `channel_type` becomes an enum

`reading_channels.channel_type` holds three sema TypeNames
(`data.channel.gt`, `derived.channel.gt`, `synth.channel.gt`) and one
marker, `gjk.pseudo`, that covers four different inventions: state
machines, zone heat-calls synthesized from whitewire power, weather
forecast channels and FLO-params channels. It becomes a sema enum,
`gw.channel.kind` (staging at `000`): Unknown (the default), DataChannel,
DerivedChannel, StateMachine, HeatCallSynth, WeatherForecast,
WeatherObserved, FloParams.
A synth channel is a derived channel declared by a layout before 007
(the list was of `synth.channel.gt` and is of `derived.channel.gt` from
007), so the kind has one value for both: the journalkeeper files a
synth-era row (`required-energy`, `usable-energy`, the only two that
ever reported) under the derived TypeName, and the gridworks-data
migration `a9e2c4d6f8b1` renames the rows already written under the
synth one. The row's `unit_type` keeps the vocabulary difference
(`spaceheat.telemetry.name` before 007, `gw1.unit` from it). The rename
of the live rows is one hand-run SQL script in gridworks-data
(`src/gw_data/db/scripts/misc/channel_type_to_kind.sql`): the two
TypeNames one to one, and `gjk.pseudo` split by `unit_type` (outside
`gw1.unit` is StateMachine) and by name under it (`-heat-call` is
HeatCallSynth, `forecast-oat` and `forecast-ws` WeatherForecast, the
three FLO names FloParams, the weather GNode's observed rows
WeatherObserved, which also take the record's Id as `channel_id`). It
runs on `tsdb_tap` first with the before and after distributions
compared, then once on production, both of us consenting; alembic is
for schema changes. The journalkeeper writes the kind from the enum, and
the readers select state rows and heat-call rows by it. The enum is
promoted only after the local dev EDD run against the analytics tap
dressed as a dev production broker; until then the journalkeeper's
snapshot is a staging snapshot (`ALLOW_STAGED=1` on its regen script),
which is why the branch is not for production.

Observed weather readings: the weather GNode's observations
(`gw.weather.observation`) were message rows only. The journalkeeper now
writes their values to the observed rows at ObservationTime, each reading
resolved through the journaled `gw.weather.channel.gt` to the row with
that `channel_id`; interpolated observations write none. The forecast
words stay message-only: the latest forecast per bundle is a query over
`messages`, and gwwf's read API is the recovery path, not an analytics
source.

A layout fact for the finalize work: in the spruce 013 layout every relay
appears twice, as a RelayState data channel and as a
`relay.closed.or.open` machine. One fact, two rows.

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

### The house's control mode

The top strip shows LocalControl, LeafTransactiveNode and Admin, a
projection across two machines (Admin is in `gw.top.state`, the other two
in `gw1.main.auto.state`). A useful projection, so it becomes a sema enum,
`gw.house.control.mode` (staging at `000`): Unknown (the default),
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

Taken up after step 5, as one spoke, with `wiki/tools/backend.sh` for the
sessions that touch the backend or the browser:

1. gridworks-data: `channel_type` takes `gw.channel.kind` values; the
   migration relabels by the rules above. The journalkeeper writes the
   kind from then on and the readers select by it.
2. web-backend: the control mode derived from the
   `gw.house.operating.status` stream (013) and from the two machines
   (before), sent as its own sequence; the state part names the machine.
   Built on dev against `tsdb_tap` with the two words vendored at staging.
3. Promotion of `gw.channel.kind` and `gw.house.control.mode` to published
   (its own gated turn under `sema-CLAUDE.md`), then the production
   snapshots of the backend and the frontend regenerated together. A
   staging word never reaches a production snapshot.
4. web-frontend: strips by (node, enum) and the control-mode sequence; the
   regex notes from the comb-through become the layout and
   operational-parameter asks.

## Open

- The dashboard's Parameters page opens on hard-coded defaults in the
  frontend model (DD power 12 kW, DD RSWT 180 F, intermediate RSWT
  130 F) while the house's `layout.lite` row has the scada's own
  `Ha1Params` (cedar in the dev run: 9 kW, 160 F, 100 F). The page has
  the layout since OPS-473 and could read them from it; Ha1Params is
  itself on its way out, so the fix waits for whatever replaces it.
- Which families the three catch boxes cover; a family not among them needs
  a simulated asset (or a later box) to meet the bar.
- Whether the stage 1 additions to `layout.lite` 013 belong in its
  finalize spoke under OPS-392 or here.
- Whether the simulated fourth fall layout (OPS-532) is exercised here too.
- The state enums the journal fans out versus the registry. Sema deleted
  `gw1.local.control.standby.top.state` on 2026-10-06 (`f234cfd`,
  `replaced_by: gw2.lc.top.state`) while the enum was still vendored in
  JournalKeeper's snapshot and bound to the `local-control-standby-state`
  pseudo channel; the 2026-10-15 gjk regen had to drop both to build.
  Deleting a published enum a consumer vendors is the pattern to look at
  here: which `gw1.*` state enums the gjk pseudo channels still name,
  which the scada on `jm/spruce-unlimbo` reports, and how a replaced enum
  reaches the journal without a hole (readings for that machine stop at
  the deletion; none in the 60 days before it).
