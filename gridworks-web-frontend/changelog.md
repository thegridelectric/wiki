# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-web-frontend` code repo**. The matching git commit (in
`gridworks-web-frontend`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-10-29 — local names drop the gw and gw1 prefixes (OPS-622) <!-- pending commit -->

The snapshot's local names follow the scada's seed request: a leading
`gw1` or `gw` segment is dropped, so `Unit` not `Gw1Unit`, `ServiceMode`
not `Gw1ServiceMode`, `HouseSummary` not `GwHouseSummary`. Seventeen
files move and every importer follows; `sema_seed_request.yaml` declares
the rule under `local_names.strip_prefixes` so the generator emits the
same names. No existing export in the repo collides with a bare name.
Typecheck, 72 tests and lint unchanged.

## 2026-10-29 — the browser's sema snapshot: generated formats and enums, every word a zod schema (`59b2920`, OPS-622)

`src/sema/formats.ts` and `src/sema/enums/` are the files sema's
TypeScript generator emits from `sema_seed_request.yaml`, the browser's
seed request. Every enum is built on the generated `semaEnum.ts` base,
so an unknown value decodes to the enum's default as the spec requires
and as the Python runtime does; the hand tests that expected a rejection
now expect the default, and the hand `single.machine.state` axiom tests
enum membership by `.options`. The formats regain the `minLength` and
36-character bounds the hand file had dropped, and gain `pascal.case`
and the two ISO 8601 formats.

The seven hand-typed `.d.ts` interfaces in `src/sema/` and the
`index.ts` that re-exported them are gone. Six words get zod schemas in
`src/sema/types/`, in the generator's style with their axioms as named
refinements: `channel.readings.list.item`, `operating.state.sequence`,
`synced.readings.bundle` 003, `gw.house.operating.status`,
`gw.house.summary` (its `Layout` is `AnyLayoutLite`) and
`gw.stopgap.price.forecast`, with the seven enums they reference. The
three fetches that returned a cast now parse: the summaries response
through `parseHouseSummaries` in `SessionContext.ts`, which warns and
drops a house whose summary fails so one seam fault does not blank the
dashboard; the readings bundle and the price forecast through `.parse`,
whose failure reaches the page's existing error path. The real-time
page's own layout parse goes, since the summary's layout is already the
word. The `layout.lite` 011 and 012 readers gain the deployment fields
the information page shows (`Strategy`, `SeasonalStorageMode`,
`TotalStoreTanks`), and the page reads them only from those versions.
Two new test files cover the words with the registry examples and one
failing case per axiom. Typecheck green, 72 tests green, lint unchanged.

## 2026-10-28 — the real-time page converts through the layout's units (`774d6dc`, OPS-622)

**What:** `src/sema/displayReadings.ts` converts a snapshot's readings
through the unit the house's `layout.lite` declares for each channel,
via the resolver and the shared unit table; a channel the layout does
not declare, or whose unit has no table row, keeps its raw value and is
shown with a raw marker. The page parses the summary's layout with
`AnyLayoutLite` once and the system diagram, the thermostat table and
the power, resistive and pump tables all read the converted readings.
`tempValueToFahrenheit` and every hand divide on the page are gone.
`siegLoop.ts` becomes `plantLoops.ts` and gains the secondary loop,
present when the layout declares `secondary-flow`; the pump table's
Secondary row keys on it. Tests cover the conversion on elm 013 and
beech 011, the raw marker, both loop lookups and the primary-flow
decision in GPM. Checked on the page against elm's live snapshot through
the dev stack (`experiments/2026-10-28-realtime-units-elm-check/`).

**Why:** elm's 013 layout declares temperatures in CelsiusTimes100 where
the page assumed WaterTempCTimes1000, so hp-ewt displayed 37.4 F in place
of 86 F; the unit is the layout's fact, read from it. The secondary pump
row was keyed on the house being spruce, and elm has one too.

## 2026-10-28 — layout.lite words, the shared unit table and the layout unit resolver (`f21a0f2`, OPS-622)

**What:** `src/sema/` gains zod schemas for `layout.lite` 013 with its
five axioms, `data.channel.gt` 004, `derived.channel.gt` 003,
`spaceheat.node.gt` 303, `gw.state.machine` 000, the two unit-to-quantity
projection words, the enums they reference, and readers of `layout.lite`
011 and 012 over the channel words those versions name. `units.ts` is
the one table from a declared unit to a display value and hover format,
keyed by the telemetry-name and unit enums; the visualizer converts
through it. `layoutUnits.ts` resolves a channel name to its declared
unit in a house's layout. Tests parse elm's 013 and beech's 011 layouts
from the journal, exercise the axioms, and check that every temperature,
flow, power and energy value of both enums has a row.

**Why:** the real-time page needs the unit a house declares for each
channel, and the one conversion table, before it can stop deciding units
by channel name. The layout words are the next piece of the hand-written
snapshot the TypeScript emitter reproduces.


## 2026-10-28 — sema snapshot in typescript; added zod and vitest (`c3ead2e`, OPS-622)

**What:** Vitest runs under `npm test` and in the Pages workflow before
the build. `src/sema/` gains zod schemas, with their inferred types, for
`snapshot.spaceheat` 003, `single.reading` 000 and
`single.machine.state` 000, the enums `spaceheat.telemetry.name` 007,
`gw1.unit` 003 and `relay.closed.or.open` 000, and the five property
formats they use. Tests parse an elm snapshot captured off the house
broker and the registry example, round-trip them unchanged, and reject a
wrong TypeName or Version, a missing or undeclared field, a string where
an integer is required, a non-integer reading and an enum value outside
the enum, each naming the failing path.

**Why:** the real-time page converts readings by matching channel names,
which shows elm's `CelsiusTimes100` temperatures at a tenth of their
value. The fix converts through the unit the house's `layout.lite`
declares, and the words the page reads come first, typed and validated
in the browser the way the backend's snapshot classes are. These
hand-written schemas are the fixture the sema TypeScript emitter will
reproduce.


## 2026-10-26 — visualizer hooks above the guard; temperature axes autoscale (`992e798`, OPS-588)

**What:** the auto-refresh hook and the house-change effect in
`VisualizerPage.tsx` move above the session guard with the other hooks.
The heat pump and secondary loop panels' temperature axes take the
offset range form the Storage panel uses (20 °F either side of the data,
clamped to 0 to 260) in place of a fixed 0 to 260.

**Why:** the two hooks were the last below an early return, which the
rules-of-hooks lint flags and React does not define. The fixed range was
the OPS-568 and OPS-593 stopgap for data that fell off the old 30 to 70
axis; autoscaling fits whichever house is plotted.

## 2026-10-26 — front-end fixes from the OPS-588 sweep (`4038ca7`, OPS-588)

**What:** Thomas's `td/dev` branch squash-merged as PR #14 (the title is
GitHub's default, "Td/dev (#14)"); the branch keeps the fourteen commits.
Deployed to GitHub Pages by the `main` push. Per sub-issue:

- OPS-591 "Network Error": the API interceptor surfaces the server's
  `detail` string, or the HTTP status, where axios said only "Network
  Error". The request timeout goes from 5 s to 10 s so a slow login is
  not cut off.
- OPS-562 / OPS-625 auto-refresh: the button works again, keeps the
  user's start time and advances only the end time to now, every 30 s.
  The hook reads its callbacks through refs so a re-render does not
  restart the timer, which was the once-a-second refresh.
- OPS-593 secondary loop panel: the fixed temperature range widens to
  0 to 260 F so spruce's secondary temperatures are on the axis. A fixed
  range; autoscale is the open item.
- OPS-568 heat pump panel: same range change on the heat pump panel.
- OPS-604 / OPS-567 sieg flow: with a sieg loop in the layout, primary
  flow is `sieg-send` at or above 0.5 gpm, not `primary-flow`; buffer
  water no longer animates when only the sieg loop runs.
- OPS-627 maple heat pump animation: heat pump power is the sum of the
  indoor and outdoor units with a missing reading read as zero, so one
  missing channel no longer hides the animation.
- OPS-560 spruce real-time: a secondary pump row in the flow table and
  a split heat pump header whose secondary leg animates toward the store
  or the buffer by the charge relay. Keyed on the house being spruce;
  the layout-keyed version waits for elm (OPS-622 "The real-time page").
- OPS-626 gw-temp zones: thermostat names ending `-gw` are filtered in
  the browser. The gateway derives them from channel names while every
  layout since 011 has `ZoneList`; the gateway fix is the durable one.
- OPS-624 secondary EWT/LWT on the visualizer: Thomas's sub-issue closed
  with a data check and no code change here.
- Real-time header shows "Connecting..." until the first status message
  for the selected house arrives, instead of the previous house's data.
- The five `useRef` calls in `VisualizerPage.tsx` move above the session
  guard, with the other hooks; a hook below an early return trips the
  rules-of-hooks lint and is undefined behaviour in React when the guard
  flips. The auto-refresh hook and one effect below the guard predate
  this branch and wait for a change that hoists the functions they close
  over.

**Why:** the first pass over the operations issues George filed against
the web app since September, taken as one hot fix so the fleet has it for
the elm bring-up. The per-house and name-matching patterns it adds are
recorded in OPS-622 for the comb-through rather than cleaned here.

## 2026-10-25 — price plot axis reaches the forecast (`0af0813`, OPS-623)

**What:** the price plot's x-axis range ends 48 hours past the window end,
where the forecast hours are.

**Why:** the default plot layout fixes the x range to the window, so the
forecast hours kept past the window end drew outside the visible axis and
the plot came up empty.

## 2026-10-25 — price panel draws 48 hours past the window (`86d29f0`, OPS-623)

**What:** the panel keeps the forecast hours from the window start to 48
hours past its end, as the v1 panel did, and the empty note says "near this
window".

**Why:** the stopgap's forecast begins at the next full hour, so a window
ending at now, the page default, had no forecast hour in it and the panel
showed only the note. Drawing the forecast ahead of the window is what the
panel is for until a price series over the window exists.

## 2026-10-25 — price panel reads the backend's forecast (`866d79f`, OPS-623)

**What:** `src/sema/StopgapPriceForecast.d.ts` types `gw.stopgap.price.forecast`
000; `pricing-api.ts` fetches `/api/v2/price-forecast/latest` through the
session client, keeps the forecast hours inside the chosen window and adds
Total as a browser-side sum of LMP and delivery. The panel says "No price
forecast for this window" when no forecast hour falls in it. The direct
POST to the retired price service path is gone, and the panel no longer
takes an installation.

**Why:** the price service's visualizer path went with the PriceDb box, so
every plot showed "Pricing request failed: NetworkError". The browser reads
a sema word the backend serves, per the seam rule; the forecast covers the
next 48 hours, so a window in the past gets the note rather than an error.

## 2026-10-25 — the bundle types are the words (`fbb6794`, OPS-542)

**What:** `src/sema/SyncedReadingsBundle.d.ts`, `ChannelReadingsListItem.d.ts`
and `OperatingStateSequence.d.ts` match `synced.readings.bundle` 003 and its
items field for field (TypeName, Version, AboutGNodeAlias, UnitType, null
grid points in a ValueList), named by the word; the visualizer imports them
under those names.

**Why:** the hand-kept types had drifted from the words the backend serves
(fields missing, nulls typed away), and a type named for an API response
hides that it is a word. Checked on the page against `tsdb_tap` for the
013 cutover windows (OPS-542).

## 2026-10-22 — houses keyed by TaGNodeId; summaries as gw.house.summary; layouts 011 through 013 (`3d514bb`, PR #8, OPS-473)

`src/sema/` mirrors `gw.house.summary` and `gw.house.operating.status`
by hand until the sema TypeScript target exists; the summary type is
`HouseSummary`, with the word's `TypeName`, `Version` and `SendTimeMs`,
and a field the word allows to be null is optional, since the dict form
omits it. The Houses table's Mode column becomes Status, read from the
operating status as Standby or the service mode, then the top state;
the Information page's Status section shows Standby (with the posture),
service mode, top state and the status's own time. The role checks
compare against the enum's `Admin` and `Owner`. The layout field is
`Layout`. Verified by the dev run,
`experiments/2026-10-21-disentangle-dev-run/`.

## 2026-10-21 — retire installations: the summary as the API returns it; Address and Contact not shown; Hardware and the sieg default from the layout (folded into `3d514bb`, PR #8, OPS-473)

The dashboard follows the web-backend summaries once the `installations`,
`customers` and `installers` tables leave journaldb. The summary type is
retyped to the fields the API returns: `TaGNodeId` joins, `DisplayName`,
`SystemMode`, `MainAutoState`, the snapshot facts and `LayoutLite` are
nullable, and the `HardwareLayout`, `InstallationContact` and
`SpaceheatParameters` types go, since no endpoint returns them. The
Installations table drops its Location column, filter and sort. The
Information page keeps its four sections: Address and Contact read "Not
shown here" until the customer store has a read path (OPS-600), Status
comes from the snapshot facts, Hardware from `LayoutLite`. The real-time
page's default sieg loop is on when the layout has a `sieg-flow` data
channel, and its gateway key is the last segment of `GNodeAlias`, so the
registry's display names can read however gnr likes. The Parameters page
starts from its defaults, since operational params are not on the bus.
`LayoutLite` and the sieg check are typed in `src/sema/` by hand, to the
fields read; a generated snapshot is the open gap at this boundary.
