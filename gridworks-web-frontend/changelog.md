# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-web-frontend` code repo**. The matching git commit (in
`gridworks-web-frontend`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-11-24 — The visualizer reads flo.params 005 and re-runs with flo.rerun.request 003 (`38d2afe`, jm/flo-params-005, PR 40)

**Why:** the LTNs send `flo.params` 005, the lift COP model, since its promotion (sema `df68501`), and the zod snapshot pinned `FloParams` at 004 and `FloRerunRequest` at 002, so the FLO view could not parse a 005 hour and a re-run could not wrap one. 005 and 003 are now the latest, with 004 and 002 under `old_versions`. `heatPumpCop` reads the lift coefficient each version names. A penalty edit keeps a 005 request at 005 and lifts 002 to 004 requests to 004, as before.

## 2026-11-20 — Bruce tuning and penalties take the Experimental knob (`a1da3c5`, jm/flo-tuning-experimental, OPS-696)

**Why.** `flo.tuning.bruce` 003 and `flo.path.penalties.bruce` 002 move the two unmet-load knobs and their penalty series into an open `Experimental` dict, so a knob under tuning changes bruce and nothing else (OPS-696). The words that nest them follow: `flo.params` 004, `flo.rerun.request` 002, `flo.recommendation` 003, `gw.operational.params` 000 repointed in place. All five are staging in sema (`c8cc461`), so the snapshot is a dev-only staged one until they promote. The hand-written snapshot gains the five versions and
keeps the replaced ones under `old_versions`. The re-run panel reads the two
knobs from a 003 tuning's `Experimental` and writes an edit back into it,
sending `flo.rerun.request` 002 around a 004 params; the path view reads the
unmet-load series from a 002 penalties word's `Experimental`. The keys are
read by name, with a note naming the declared field that retires each.

## 2026-11-18 — Price panels at the off-peak delivery scale, one pink for on-peak, a zoomed plot holds auto-refresh (`350b921`, jm/flat-delivery-price, PR #32)

The on-peak delivery premium (the on-peak delivery charge over the
off-peak one, $530/MWh, one constant in `tou-tariff.ts`) comes off
every on-peak hour of the price panel's forecast and real-time traces
and of the FLO plot's price, so the off-peak variation shows at one
scale and the bands alone say which hours are on-peak. The panel is
titled "Price*" with the rule in a note under it. `gw.tou.tariff` 000
states windows and no prices; a tariff word with per-period delivery
prices retires the constant. The FLO plot's bands move from
the $400/MWh threshold to the house's tariff windows, in the price
panel's pink (`ON_PEAK_FILL`), and the re-run horizon bars mark the same
hours. Dragging a plot into a zoom sets a zoomed flag on the page (a ref,
since a re-render alone hands every plot a fresh layout and resets its
zoom), which holds the auto-refresh tick until a double-click or a new
plot query; `plot-zoom.ts` reads the relayout event.

Why: the on-peak price, $600 and more, flattened the rest of the price
trace to a line along the axis, and the viewer already had the bands to
tell on-peak from off-peak. Auto-refresh redrew every plot at the full
window, so a zoom survived at most thirty seconds.

## 2026-11-18 — The 002 test word is a typed literal, so tsc -b passes (`f0645f5`, jm/ops-683-review, OPS-683)

`npm run build` is `tsc -b && vite build`, and `tsc -b` failed on main
since PR 30: the path-view test wrote `UnmetLoadPenaltyUsdList` onto a
clone of the 001 fixture, whose imported-JSON type has no such field.
vitest and the dev server strip types without checking them, so the
tests and the page kept working. The test now builds the 002 word as
an object literal with the field present and asserts the same thing.
No runtime change.

## 2026-11-18 — The FLO view sheds what nothing draws, and the re-run panel's keys are the word's (`211c44f`, jm/ops-683-review, OPS-683)

**Why.** Review of the re-run range. Eight symbols had no caller left
once the FLO view was reorganized (the thermal-price fields and their COP
rule, the overlay scaler, a text colour, the step widths, the penalty
group list); they go, with the two test assertions that were their only
readers. The penalty component typed its field keys as strings and the
page cast them back to the word's keys at the send; the keys are now
`PenaltyKey`, so the field list and the word agree at compile time. The
bottom tank label's rule is written as bruce's plot has it (no label on a
band with no layers) and its docstring says so. A stale readings request
no longer clears the loading flag of the newer one. The forced-step
summary says steps, which is what the word names, and the seed request's
comment states what the word is for.

## 2026-11-18 — Primary-loop flow is decided by the layout, and each channel-name match says what replaces it (`850f74e`, jm/ops-683-review, OPS-683)

**Why.** Whether a sieg house's primary loop counts as flowing was
decided by whether a `sieg-send` reading happened to be in the snapshot,
falling back to `primary-flow` when it was not. The layout decides: a
layout that declares the sieg send channel reads that flow, any other
reads the primary flow, and the page passes the layout fact down. Every
channel-name match the range touched in the real-time diagram and the
loop helpers now has a note naming the fact it extracts and the layout
fact that replaces it, which is the input the layout word's next
version takes.

## 2026-11-17 — Passing tests (#29) (`ea7db85`, OPS-683)

**Why.** The two axiom tests of `flo.rerun.request` assigned a forced
step list onto a clone of the registry example, which the compiler
refused as a write to a readonly field; the tests spread the clone into
a new object with the bad list instead, and the suite is green.

## 2026-11-17 — Real-time animation logic works with new relays + minor visual improvements (#28) (`1b1d033`, OPS-683)

**Why.** The real-time diagram decided charge against discharge by
matching `-relay(\d+)` on channel names and reading relay numbers off
the result, a name match the house rule forbids and one the new relay
layouts broke. The diagram now reads the `store.flow.relay` state
(`ChargingStore` / `DischargingStore`) from the snapshot's state list and
takes it as a typed prop; the relay map, its regex and the energized /
deenergized strings are gone. A sieg loop counts as flowing only when a
`sieg-send` reading is in the snapshot. Small visual changes on the
visualizer page and the tool cards go with it.

## 2026-11-17 — Add FLO rerun request (`6e8a601`, OPS-683)

**Why.** The re-run panel could edit bruce's penalty tuning but not force
heat pump steps on or off, which bruce's optimizer already accepts. The
panel now sends `flo.rerun.request` 000, vendored from the registry with
its two axioms as zod refinements and the registry example as the
fixture: the hour's `flo.params` with the tuning edited, plus the
forced-on and forced-off step lists chosen by clicking step bars above
and below the path. The FLO view is reorganized around it: the path
drawing moves out of `FloPlot` into `flo-path-view.ts` as typed views
(bands, penalties, the path), the penalty fields get their own
component, a bid plot draws the slot's bid against the forecast and the
cleared price (fetched from the market's latest prices), and the old
`FloRerunPanel` is gone.

## 2026-11-16 — Hide re-run mode from FLO when not running locally (`a724474`, OPS-665)

**Why.** The pencil that opens the re-run editor showed on every
backend, with the Re-run button disabled and a tooltip where the route
was absent. The pencil and the editor now render only where the probe
of the route found it mounted, so a page against the web box shows no
trace of the re-run.

## 2026-11-15 — The FLO re-run panel: the hour's penalty tuning edited, bruce's answer drawn in place of the journaled plot (`c7ad3f8`, OPS-665)

**Why.** The optimizer author's inspection tool is to solve an hour again
with the penalty tuning changed and look at the plot, on a laptop whose
backend has bruce beside it. The panel shows only where a probe of the
re-run route says it is mounted (a GET of the POST-only path answers 405
there and 404 on the web box), prefills the thirteen penalty fields of
`flo.tuning.bruce` from the hour's journaled `flo.params`, and sends that
word back with the edits through the vendored types, so an edit that
breaks the word is refused before it is sent. The answer is drawn with
the same `FloPlot`; Reset or the hour arrows bring the journaled plot
back. Nothing changes on Pages against the web box, where the probe hides
the panel.

## 2026-11-15 — The price panel draws the real-time price beside the day-ahead forecast (#25) (`e876fdb`, jm/realtime-price, OPS-666)

**Why:** a house's FLO optimizes against a forecast; what the house then
paid is the market's cleared price, and the two belong on one axes. The
panel, now titled "Price", fetches the market the forecast names
(`e.<ProductName>.<MarketMakerAlias>` off the `gw.price.forecast` word)
from the backend's latest-prices route and draws a second step trace,
"Real-time", from the slot in force at the window start. A window with
no forecast knows no market and draws no real-time trace. `latest.price`
001 and `price.component` 000 get their zod schemas with the word's three
axioms as refinements, the `price.component.name` enum and the
`market.slot.name` format join the vendored set, and the series math is
pinned in vitest. Checked on the page against the backend on `tsdb_tap`
for oak, 2026-11-14 19:00 to 23:00.

## 2026-11-14 — The price panel steps over the window, reads against zero, and shows its empty state on a 404 (`e65a02f`, jm/price-panel-empty-state, OPS-666)

**Why:** the house price-forecast route answers 404 for an hour before
the service's first journaled forecast, and the panel means to show
"No price forecast in this window" for it. The app's response
interceptor rewraps any error with a string `detail` into a plain Error
before the fetch's catch sees it, so the 404 check there never matched
and the page showed "Pricing request failed: No price forecast for this
hour". The fetch now accepts the 404 as a response, the way the FLO
fetch does, and returns the empty series.
The series was the slots that start inside the window, so a window
inside one hour had one point and a step trace drew nothing, and
autorange zoomed the y axis into a band a dollar wide. The series is now
a step: the slot in force at the window start, clamped to it, the slots
starting inside the window, and a closing point where the last ends or
the window does; the y axis includes zero.

## 2026-11-14 — The FLO plot reads flo.params 002 beside 001 (`ce96904`, jm/flo-params-002, OPS-666)

**Why:** the LTNs on scada `main` send `flo.params` 002, which states the
price as one `PriceUsdMwhList` read from a named `gw.price.forecast`,
and the journal keeps the 001 rows with their LMP and distribution
lists. The browser read 001 only, so the FLO panel's parse failed for
every hour after the cutover. `AnyFloParams` is the union the backend's
params route serves, in the shape `AnyFloRecommendation` set, and
`priceUsdMwhList` gives the view the price per step at either version.
The axioms every version shares live once in `floParamsAxioms.ts`; the
step-list axiom names the price list, so each version states it beside
its schema.

## 2026-11-14 — The price panel and the FLO plot shade the house's own tariff from its layout (`21b27bb`, jm/price-forecast-word, OPS-666)

**Why:** both plots shaded the fleet's one tariff from
`GET /api/v2/tou-tariff/current`, which is right only while every house
is billed on the same rate. A `layout.lite` 014 row states the house's
`Tariff`, and the house summary brings that row to the browser, so
`tariffForHouse` in `tou-tariff.ts` reads `Layout.Tariff` when the
summary's layout is 014 and asks the fleet route only for an older
layout; that fallback retires when every house's layout is 014. The
on-peak rectangles are built once, in `onPeakShapes`, for both plots.
The price panel finds its house's summary in the session; the FLO plot
takes the tariff as a prop and shades its path's horizon behind all
three bands, which restores the on-peak signal the delivery list gave
before `flo.params` 002. Tests cover the 014 and 013 cases and the
shapes. Checked on the page against the dev backend on `tsdb_tap` with
elm's layouts row lifted to 014 under a one-window tariff: elm shaded
that window with no fleet request, oak shaded the fleet's.

## 2026-11-14 — The price panel draws the house's journaled price forecast (`91ac38e`, jm/price-forecast-word, OPS-666)

**Why:** the panel drew the stopgap service's live forecast, which has no
past, so the default window showed nothing. It now asks the backend for
the house's forecast at the window's first hour
(`GET /api/v2/installations/{alias}/price-forecast?time=`), parses the
`gw.price.forecast` word through a hand-written zod schema (axioms
SlotGrid a, b, c and OnePricePerSlot as refinements) with the
`gw.market.product.name` 001 enum, and draws the slots inside the window
at `PriceX1000List / 1000`, one trace, "Day-ahead forecast". A 404 is an
empty series and the panel says so. The stopgap word and its fetch go.
The backend's summaries route now emits `gw.house.summary` 003 and the
layout can be 014, so the browser reads both: `layout.lite` 014 is the
word (`Tariff` required), 013 moves to `old_versions`, and the five
layout axioms live once in `layoutLiteAxioms.ts` for every version read
whole; summary 002 moves to `old_versions` and 003 is the word. The
information page narrows on 013 and 014 alike. The branch is cut from
OPS-665's `jm/flo-plot-words` rebased on `main`, so it has the FLO
words and the tariff shading together. Vitest 131 passed, tsc clean,
eslint clean on the changed files. Checked against the dev backend on
`tsdb_tap` seeded with two service forecasts and an oak `flo.params`
002: oak's slot answers with the forecast its request names, beech's
with the newest published.

## 2026-11-11 — The price panel draws LMP alone on one axis, on the page's time axis, with the on-peak hours shaded (`1179322`, jm/price-panel-lmp, OPS-666)

**Why:** the panel's reader wants the wholesale price and where the
tariff's on-peak hours fall, on the same time axis as every other panel.
The Total trace (a browser sum of LMP and delivery that no word states)
and the right-hand axis go; LMP moves to the left axis as a solid line.
The x axis is the window's instead of reaching 48 hours past it, and the
fetch keeps only the hours inside the window. The on-peak hours come
from the backend's `gw.tou.tariff` word, laid over the window's range in
the tariff's zone by `onPeakSpans` in `tou-tariff.ts` (tested on a
weekday, a weekend, a clipped range and a UTC range), and drawn as light
pink rectangles behind the trace. `gw.tou.tariff`, `gw.tou.window`,
the `day.of.week` enum and the `hh.mm` and `iana.timezone.str` formats
join the snapshot under `src/sema` in its hand-written generated style,
with the words' axioms as refinements, and the seed request names the
tariff word.

## 2026-11-10 — The FLO client reads a 404 as no FLO in the slot, and the notice names the slot (`f6885b7`, jm/flo-plot-words, OPS-665)

**Why:** the first page check on the dev stack pressed the FLO button on
an hour with no run and got "FLO request failed: No FLO was run in this
hour" instead of the page's notice. The app's axios response interceptor
replaces an error that has a `detail` string with a plain `Error`, so the
client's `isAxiosError` branch for 404 never matched. The client now asks
axios to resolve a 404 as a response (`validateStatus`) and returns null
on it, so the interceptor sees no error. A test fixes both paths: the 404
resolves to null, and any other failure keeps the interceptor's message.
The notice names the slot it asked for ("No FLO was run for the slot
starting 2026-11-10 07:00 ET"), since the hour the page looks in is the
end time's hour and the reader cannot see that from the picker.

## 2026-11-10 — Snapshot at the flo plot words with the store's bounds and the path cost (`445ee91`, jm/flo-plot-words, OPS-665)

The commit is the whole FLO view under a snapshot title: the page draws the recommendation word.

**What:** zod schemas in `src/sema/types/` for `flo.recommendation` 001
and 000 (`AnyFloRecommendation` is their union: the journal's 000 rows
have no store state and no penalties and the backend serves each row at
its own version), `flo.optimal.path`, `flo.tank.store.path`,
`flo.path.penalties.bruce` and `price.quantity.unitless`, each axiom a
named refinement, the five recommendation axioms shared between the two
versions in `floRecommendationAxioms.ts`; `enums/` gains the two market
unit enums; the seed names the word at both versions and the enums.
`flo-api.ts` fetches the house's recommendation for the End time's slot
from the backend's FLO route and parses it, null on the route's 404.
`flo-path-view.ts` lays one pair's path out for drawing: step starts on
the path's own step grid, the heat pump's kW, the store's kWh, each store
layer's temperature from the band its two thermoclines put it in, and the
three penalty series stacked. `FloPlot.tsx` draws that in three bands on
one time axis: heat pump kW; the store's layers colored by temperature
over the path's own range with the store's kWh beside them; the penalties
with the terminal cost in the title. A 000 recommendation draws the first
two bands. The page's FLO button fetches instead of downloading, the hour
buttons step the End time by one hour and refetch, and a button per bid
pair picks which path is drawn, opening on the lowest-priced pair.

`FloParams.ts`, `FloTuningAlice.ts` and `FloTuningBruce.ts` type the
LTN's request with their axioms as refinements; `fetchParams` reads it
for the same slot, null on the route's 404; `paramsView` lays it out on
the request's step grid as the price the optimizer saw (LMP plus
distribution, USD/MWh) and the load it forecast (kWh over the step
hours, kW); the top band draws both beside the heat pump, load on the
left axis and price on the right, as bruce's own visualizer does. A slot
with a recommendation and no request draws the heat pump alone. The plot
follows bruce's visualizer, which the `td/dev` page reproduces: the
title is the slot start and the path's cost to the cent, the pair whose
path has the lowest `PathCostUsd` is drawn with no pair buttons (the path
the optimizer takes at its forecast price, which is the one bruce's
visualizer walks; a recommendation with no path costs opens on the
lowest-priced pair), the right axis of the top band is the thermal price (the
electricity price over the step's COP, with the price over the mean COP
hidden behind the legend), the store band is "Storage state" in Reds
over 60 to 180 F as three blocks per step (top, middle, bottom) with one
temperature each and the state of charge on the right, and the penalties take bruce's names and colors
with the terminal cost as a green bar on the last step labelled by its
share of an empty store's cost. The state of charge, that share and the
path cost in the title (`plotTitle`) come from the words:
`flo.tank.store.path` states `EmptyStoreWh` and `FullStoreWh`, and
`flo.path.penalties.bruce` states `TerminalCostEmptyStoreUsd` and
`PathCostUsd` (sema `20e46b9`), so `pathView` computes all three from
the recommendation alone and `paramsView` reads only the request. The
COP per step is the one optimizer rule the browser applies, from the
coefficients `flo.params` states. Tests: the schemas parse orange1's
001 recommendation and the registry's 000 example and refuse the axiom
breaks, the two new axioms among them; the view's step grid, band
lookup, stacking, state of charge, terminal share, title and 000
fallback. The 001 fixture is the recommendation journaled in the dev run
of 2026-11-09 with the four new fields as bruce computes them for the
same journaled request; bruce reproduces every other field of the
journaled row exactly. vitest 114 passed, `tsc -b` clean.

## 2026-11-01 — the weather plot draws a house's bundle forecasts from the weather words (`7e3ac74`, OPS-622)

**What:** seven zod schemas in `src/sema/types/` for `gw.weather.forecast`
002 and 001 (`AnyWeatherForecast` is their union: the journal holds the
service's 001 emissions, which have no ForecastUid and no upgrade path,
so the backend serves each at its own version) and
`gw.weather.forecast.bundle.gt` 002 with the series, binding and channel
records they embed, each axiom a named refinement; the seed pins the
two forecast versions and names the bundle word and the fidelity enum, `formats.ts` gains the
three formats the closure brings (`LowercaseToken`, `NonEmptyString`,
`NonNegativeInt`, as sema's TypeScript generator emits them) and
`enums/WeatherForecastFidelity.ts` the enum. `weather-api.ts` fetches a
bundle's record and its emissions over the window from the backend's
weather routes, parses both, and lays the runs of one quantity on the
bound forecast channel's slice grid in the bound observation channel's
unit, which the plot converts through the shared unit table.
`house-weather-bundles.ts` is the hand-kept table from a house's alias
to the bundle its scada reads (every house on `us.me.millinocket.moose`),
with the note naming the `gw.operational.params` field that retires it.
`WeatherForecastPlot.tsx` draws the temperature runs, the newest in red.
Tests: the registry 002 example and the journaled bobcat 001 emission
and record parse, singly and through the union, one failing case per
axiom, the run builder on 001 and 002 rows together.

**Why:** the plot read the per-house `weather.forecast` message the
`legacy` scada emitted and typed it by hand; no scada on `main` emits
it, so the plot went blank as the fleet rolled on 2026-10-29. The
weather service's word is about a bundle, so the house-to-bundle fact
is what the browser needs, and until the scada's operational params are
journaled it is a table in the browser. The journal holds every
bundle's record and its hourly emissions (moose, bobcat and raccoon;
the service's 002 emissions from 2026-11-01 17:01Z), so each house's
plot has data. The fixtures are moose's journaled record and one
emission at each version. Seen on the page: the oak visualizer against
the backend on `tsdb_tap`, a window spanning the version switch, 44
runs drawn and no console error.

## 2026-10-29 — the Houses card shows each scada's commit, a check when it is main's head (`fec2bab`, OPS-622)

**What:** `gw.house.summary` 002 as a zod schema with `ScadaCommit` on the
`git.commit` format and `ScadaCommitStanding` on the new `CommitStanding`
enum (`gw.commit.standing`), axiom 2 as a refinement; 000 and 001 kept
whole under `old_versions`; `AnyHouseSummary` is the union the session
parses, so either deploy order of backend and browser parses, with
`scadaCommit` and `scadaCommitStanding` accessors over the union. The
Houses card's last column shows a green check for OnMainHead (the full
hash as the tooltip), else the short hash with any `-dirty` suffix, tinted
red for Dirty; sortable and filterable by hash; an empty cell for a house
whose summary names no commit. The Status column reads `<control mode> /
<SeasonalStorageMode>`: Admin, Ltn or LocalControl in the words of
`gw.house.control.mode`, derived in the browser from TopState and
LtnDispatching until the operating status carries the enum, then
BufferOnly or AllTanks.

**Why:** the fleet's running code is read off the dashboard rather than
off each box, and a glance separates the houses on main's head from the
rest. The browser renders the standing the backend sends and does not
compare hashes itself.

## 2026-10-29 — local names drop the gw and gw1 prefixes (`20494c4`, OPS-622)

The snapshot's local names follow the scada's seed request: a leading
`gw1` or `gw` segment is dropped, so `Unit` not `Gw1Unit`, `ServiceMode`
not `Gw1ServiceMode`, `HouseSummary` not `GwHouseSummary`. Seventeen
files move and every importer follows; `sema_seed_request.yaml` declares
the rule under `local_names.strip_prefixes` so the generator emits the
same names. No existing export in the repo collides with a bare name.
Typecheck, 72 tests and lint unchanged.

## 2026-10-29 — the browser's sema snapshot: generated formats and enums, every word a zod schema (`20494c4`, OPS-622)

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
