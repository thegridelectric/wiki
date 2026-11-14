# FLO plot from words

Status: Accepted · Pass 1 · Updated 2026-11-11 · Linear: OPS-665

**EDD: yes** a recommendation published by the FLO service at the new
versions reaches the journal and is drawn on the visualizer page from the
word alone, against the backend on `tsdb_tap`, for a house and hour the
LTN ran; the web box has no optimizer installed when it does.

> What this is: the dashboard's FLO view reads what the FLO service
> published instead of re-solving the optimization on the web box. The
> per-step facts the view draws that the recommendation does not yet
> state (store layer temperatures, thermocline positions, bruce's penalty
> breakdown) become words the FLO service publishes beside the path. Four
> repos change in dependency order: sema, the optimizer and FLO service,
> the web backend, the web frontend.

## Gate: Thomas's read of the optimal-flexibility PR

The FLO plot on `td/dev` is Thomas's development tool. In conversation on
2026-11-10 he explained that he uses it locally while he is still
changing the penalties and the rest of bruce's tuning, and that the words
this design adds fix the plot's shape earlier than he is ready for. The
four words are published on sema and the journalkeeper has them; no
instance has emitted them onto the broker.

Thomas is reading the PR on `thdfw/optimal-flexibility` and deciding
whether this multi-repo change merges. The design waits on that call.

- **If it merges:** the build continues from "Do this next" in the spokes
  section.
- **If it does not:** the `jm/flo-plot-words` branches are deleted across
  the repos (optimal-flexibility, gridworks-flo, gridworks-journalkeeper,
  gridworks-scada, gridworks-web-backend, gridworks-web-frontend), and the
  new word versions (`flo.tank.store.path` 000,
  `flo.path.penalties.bruce` 000, `flo.recommendation` 001,
  `flo.previous.run` 000) get a note that they will never be used, in the
  form `sema-CLAUDE.md` sets for a published word. Before the branches go,
  the sema-fication of the previous FLO plot path is cherry-picked from
  them: the backend reading `flo.params` through the codec instead of as
  a raw dict, and the snapshot regen that came with it. Whether
  `flo.previous.run` is among the never-used words is a question for that
  moment, since the LTN's stability penalty is its reason to exist.

## Why

The FLO view on the visualizer page shows one optimal path for one hour,
with step buttons for the hour before and after. Nothing in it is
exploratory: no parameter is edited, no first step is chosen, no two paths
are compared. It is a fleet reporting view of a run that already happened.

The implementation that exists (frontend `FloPlot.tsx` with the page's
`runFloQuery`; backend `api/v2/routers/flo_download.py` returning plot
data) gets that path by importing the bruce optimizer into the web
backend, reading the hour's `flo.params` from the journal as a raw dict,
re-solving the whole horizon on the web box, walking the solved graph, and
returning a hand-built dict of about 18 KB that the browser types by a
hand-written interface. The optimizer arrives as an editable path
dependency on a sibling checkout of `thdfw/optimal-flexibility`, so the
web box runs a second copy of the optimizer against production data, and a
plot depends on which commit that checkout is at. `main` has the same
shape one generation older: `gridworks-flo` as an editable path
dependency on `../gridworks-innovations/gridworks-flo`, imported as
`gridflo` for the legacy `POST /flo` and the xlsx, where the sibling on
web-api2 is a copied directory with no git checkout.

The FLO service already publishes the answer. A `flo.recommendation`
records the bid pairs and, per pair, a `flo.optimal.path` with the step
grid, the heat pump's average watts per step and the store's energy at the
end of each step. Measured over three days of production (2026-11-05 to
2026-11-08): 126 recommendations, 2 paths each, 48 steps, about 2.1 KB per
recommendation. What the recommendation does not state is the part of the
plot only the solver knows: the store's layer temperatures and thermocline
positions per step, and the per-step penalty terms bruce adds to the path
cost. Those exist in the FLO service's memory during the solve and are
discarded. Publishing them is a few KB per recommendation; re-deriving
them is a second optimizer.

Backend protocol: every structure crossing to the browser is a sema word;
a projection the browser needs that no word gives becomes a word, derived
where the facts live, and is sent as data. The facts live in the FLO
service.

## Decisions

- **The path stays generic; the store state is a word of its own.**
  `flo.optimal.path` 000 names a heat pump and a thermal store's energy
  and nothing else; it describes a sand bed as well as water tanks. The
  tank assumptions live in the request (`TanksModeled`, thermoclines by
  sensor position). So the per-step store state is a new word,
  `flo.tank.store.path` 000: the layer count, the top, middle and bottom
  band temperatures in integer degrees F, and the two thermoclines as
  layer indices counted from the top in the optimizer's own layering,
  all required, with the thermoclines ordered and within the store. A
  two-band model sets both thermoclines equal. `flo.recommendation` 001
  gets an optional `StoreStateList` parallel to `OptimalPathList`, each
  entry a oneOf over store-model words. Every path gets one: the FLO
  publishes before the market clears, so it cannot know which pair's
  path the LTN will take. About 2 KB per path.
- **The penalties are bruce's, and they hang off the recommendation.** A
  new word `flo.path.penalties.bruce` 000 states the four penalty series
  per step (RSWT, stability, short cycle, terminal cost) for one path.
  `flo.recommendation` 001 gets an optional `PathPenaltiesList` parallel
  to `OptimalPathList`, each entry a oneOf over optimizer penalty words,
  the way `flo.params` holds its `Tuning`. Not in the path, for four
  reasons. The path's readers are the FLO, the LTN, the scada's codec,
  the journalkeeper and the LTN's disk file, and only the dashboard reads
  penalties. The path is nested in `flo.recommendation`, `flo.params` and
  `flo.previous.run`, so a path version bump for a new optimizer's
  penalties bumps all three. The recommendation already pairs lists by
  index (`PqPairs` with `OptimalPathList`) and already holds the
  optimizer's provenance. And a path is a statement about the house that
  two optimizers could emit identically, while penalties are one
  optimizer's accounting of its objective and mean nothing without its
  tuning.
- **The optimizer states its own bounds and its own total.** The state
  of charge needs the store's energy when empty and when full, the
  terminal bar needs the terminal cost of a store with no usable energy,
  and the title needs the path's total cost. All four are bruce's
  numbers, so the store word states `EmptyStoreWh` and `FullStoreWh` and
  the penalties word states `TerminalCostEmptyStoreUsd` and
  `PathCostUsd`, and the browser runs none of bruce's formulas for them.
  `PathCostUsd` is each step's electricity at the request's forecast
  price, the three penalties and the terminal cost, so the path with the
  lowest one is the path the optimizer takes at its forecast price, and
  the page opens on it.
- **Only the recommendation gets a new version.** `flo.recommendation`
  001 adds the two annotation lists and refers to `flo.optimal.path` 000
  as before, so `flo.params` and the journal's paths are untouched.
  Published versions are immutable, so this is a new version under the
  sema protocol: spec read and read receipt first, samples with the
  words, timestamps from the clock.
- **The LTN records the clearing as a word.** After the slot clears, the
  LTN keeps the cleared pair's path and the price the request forecast for
  the next slot in `previous_run.json` (the path in its word form, the
  price a bare float; the typed record in `gridworks-ltn/src/gwltn/flo_request.py`
  names the missing word), and sends the bare path to the scada so the
  broker journals it (the scada ignores it; 129 such paths from oak in
  the week to 2026-11-09). A new word `flo.previous.run` 000 states the
  path, the cleared pair's index and the pair itself, and the next slot's
  forecast price, with the prices as integers times 1000 in a `PriceUnit`
  the way `price.quantity.unitless` and `latest.price` state them; the LTN
  divides by 1000 where it fills `flo.params`, whose price fields stay
  floats in USD per MWh. The LTN publishes it in place of the bare path
  and reads it back in place of the file. The dashboard then knows which path cleared, and
  draws that one.
- **The web backend reads the journal through the codec.** The FLO
  endpoint finds the house's recommendation for the requested hour in the
  journal, decodes it through the vendored snapshot and returns the word,
  or a small projection word of it, as data. The optimizer import, the
  `bruce-energy` dependency, the on-disk plot cache and its sweep all go.
  The xlsx download that main serves today at `flo.download` goes with
  them: on main the page's FLO button fetches the spreadsheet as a blob
  and discards it, so no reader reaches it through the site.
- **The browser renders, from the generated type.** `FloPlot.tsx` stays:
  its five panels (heat pump kW with load kW, price, store layers with
  temperature color, state of charge, stacked penalties) are the right
  view. Its input type becomes the zod schema of the word in
  `src/sema/`, and colors, bar widths, baselines and axis ranges are
  computed in the browser from the data. The request is for a
  recommendation at a time, so the hour-step buttons keep working.
- **One site, one box, both on main.** No beta deployment and no branch
  on the web box; a branch is tried on a laptop against a local backend
  (`experiments/dev-stack-recipe.md`). The Pages workflow deploys main
  only, with no hand-run from another branch.
- **Re-solving a run from its params stays a developer tool.** The bruce
  package's `flo_params.py` (re-solve from a `flo.params` payload and
  render) is the optimizer author's inspection tool and lives in
  `optimal-flexibility`. The dashboard does not call it.

## Lift from the existing branches

The frontend branch `td/dev` and the backend branch `td/bruce-flo` are the
reference. Two parts survive, each in the repo whose facts it reads:

- The plotting component `FloPlot.tsx`, retyped to the word.
- The data-extraction half of `graph_plot_data` in
  `optimal-flexibility/src/bruce/graph_optimizer/assets/heat_pump_water_tank/visualizer.py`:
  per-step band temperatures, thermocline positions and penalty terms,
  read from the solved graph. It is `path_words` in `src/bruce/service.py`,
  beside the code that builds the path. The rendering half (RGBA strings,
  labels, bar widths) is the browser's.

The backend router on `td/bruce-flo` is not lifted; the journal read
replaces it.

## Spokes, in dependency order

Build status as of 2026-11-10. No `jm/` branch below has an upstream, and
sema `dev` is ahead of `origin/dev`.

1. **sema: the four words.** ✅ `flo.tank.store.path` 000,
   `flo.path.penalties.bruce` 000, `flo.recommendation` 001 and
   `flo.previous.run` 000, published on `dev` (`58a55b4`). The store
   word states `EmptyStoreWh` and `FullStoreWh` on the path's
   `StoreWhList` reference; the penalties word states
   `TerminalCostEmptyStoreUsd` and `PathCostUsd`. Every consumer's
   snapshot is rebuilt at the published words (pending commits on each
   branch, 2026-11-10).
2. **The publishers and the readers between them.** ✅
   - optimal-flexibility (`jm/flo-plot-words`):
     `path_words` fills the store word and the penalties word from one
     walk of each pair's path.
   - gridworks-flo (`jm/flo-plot-words`): the service emits 001; its bruce
     arm calls `recommend_bytes` and decodes the reply through its own
     snapshot, so a word change reaches it as a snapshot regen.
   - gridworks-journalkeeper (`jm/flo-plot-words`): the seed has
     `flo.previous.run` and the persistor keys it on `CreatedMs`.
   - gridworks-scada (`jm/flo-plot-words`): snapshot, the hand-written
     twins and the MQTT LTN's `flo.previous.run`. A sim scada on `main`
     logs a decode failure on both words until this merges.
   - gridworks-ltn (`jm/hello-world`): publishes
     `flo.previous.run` after clearing.
3. **gridworks-web-backend: read, do not solve.** ✅ built on
   `jm/flo-plot-words`, pytest 50 passed.
   `api/v2/routers/flo_recommendation.py` serves the recommendation at
   000 or 001 by bidder and slot, and `/flo.params?time=` serves the
   LTN's request for the slot by the same lookup. `flo_download.py`, the
   legacy `POST /flo`, the plot cache and the `gridworks-flo` path
   dependency are gone. The `api` snapshot is at sema `dev` at the
   published words, built published-only by
   `scripts/regen_sema_snapshot.sh`; the published-only snapshot test
   passes. This spoke owns the FLO endpoint; OPS-611, which ports
   the v1 visualizer routes to v2, leaves `get_flo` to it.
4. **gridworks-web-frontend: draw the word.** ✅ built on
   `jm/flo-plot-words`, vitest 114 passed, `tsc -b` clean.
   Zod schemas for the recommendation at both versions, the path, the
   store and penalties words, the request and its two tunings;
   `flo-api.ts`; `flo-path-view.ts`; `FloPlot.tsx` in three bands (heat
   pump kW with load and thermal price; storage state in Reds over 60 to
   180 F with the state of charge; penalties with the terminal cost on
   the last step). The page opens on the pair whose path has the lowest
   `PathCostUsd` and titles the plot with the slot start and that cost
   to the cent. The state of charge and the terminal share come from the
   words; the COP per step is the one optimizer rule the browser applies,
   from the coefficients `flo.params` states.

**Do this next, once the PR merges.** Rebase optimal-flexibility `jm/flo-plot-words` onto
thdfw `main` (`1c5d60b`, two-head edges: `Node.next_node` and
`Edge.head` are gone, replaced by `best_edge`, `Edge.heads` with weights,
and `Graph.rollout`). Rewrite `path_words` in `src/bruce/service.py`
over `graph.rollout(first, max_steps=len(hours))`, as `path_from` on
main already is. Two choices, neither a word change: `PathCostUsd` is
the sum of each step's cost at the head the rollout takes plus the
terminal cost (the word's prose), which differs from the weighted
`initial_node.pathcost` in bruce's title; `RswtPenaltyUsdList` is the
penalty at that head. Then `test_recommend.py`, and rebuild the
`268a5f12` matrix in its new `.successors.matrix.npz` form for the
laptop and the flo box before the box pulls main (bruce refuses a
request whose shape has no file). Main's `flo_params.py` hand-twins
three words instead of parsing through `bruce.sema`; raise with Thomas,
not ours to fix. After that: the page check for orange1's 08:00 ET slot
of 2026-11-10 passed on the laptop (vite 5173, backend 8000, local
`tsdb`); the `tsdb_tap` check waits on a fleet LTN running at 001.

## Verification

A recommendation at 001 from a house's LTN run, journaled, read by the
backend on `tsdb_tap` and drawn on the page, with the web box's
environment showing no `bruce-energy`. Local tests first in each repo:
sema round-trips over the samples, a FLO-service test that the emitted
recommendation validates at 001, a backend test that the endpoint returns
the word for a seeded journal row, a frontend test that the schema parses
the sample and the component renders it.

bruce run on orange1's journaled request for the 14:00 slot reproduces
the journaled recommendation on every field that row has, and adds
`EmptyStoreWh` 155446, `FullStoreWh` 184794 and path costs of $7.97 and
$7.98. The frontend's 001 fixture is that journaled row with the four
fields added, until the round trip above supplies a journaled one.

## Open

- Which path the dashboard draws once a slot has a `flo.previous.run`:
  the cleared pair's. Today the page does not read `flo.previous.run` and
  opens on the forecast-cheapest path.
- A recommendation with no penalties word (a 000 row, or one from alice)
  has no `PathCostUsd`, so the page opens on its lowest-priced pair. The
  forecast-cheapest pair for such a row is the last pair priced at or
  above the forecast price, which `flo.params` states and the
  recommendation does not.
- bruce merges first-step quantities within 0.01 kWh into one pair
  (`generate_bid`), so in that corner the stored path could differ from
  the forecast-cheapest one. Not seen; orange1's slot matches to four
  decimals.
- Prices in the flo words come in two conventions: integer times 1000
  with a unit enum (`flo.recommendation`, `flo.previous.run`, the market
  words) and float USD per MWh with the unit in the field name
  (`flo.params`, `gw.stopgap.price.forecast`). The market maker and the
  price forecast words settle which one the request takes; `flo.params`
  is left as is until then.
- `flo.optimal.path` 000 does not say what zero `StoreWhList` is measured
  from. bruce sends energy from absolute temperature, about 1.7 million Wh
  for a three-tank store. The page draws the state of charge from
  `EmptyStoreWh` and `FullStoreWh`, which share that reference, so the
  zero does not matter to it; a reader that wants absolute store energy
  needs the reference stated, which is a `flo.optimal.path` 001.
- `EmptyStoreWh` is the store at 70 F, a constant in bruce
  (`EMPTY_STORE_TEMP_F` in `service.py`, and the literal 70 in
  `asset.py`'s state space). The word's prose names 70 F; another
  tank-store optimizer could mean a different floor.
- The FLO dev harness runs orange1 (`d1.isone.ct.newhaven.orange1`), a
  house no registry source knows: `gnr seed-dev` loads only the Keene
  `d1` houses, so the dashboard's house list cannot show it. The
  2026-11-09 page check inserted one `…orange1.ta` TerminalAsset row into
  the local journal DB by hand. Either the harness registers orange1
  (`gnr create` for the chain, then the forest bootstrap) or it runs a
  seeded house.
- The "normalized" electricity price on `td/dev` is read here as the
  price over the horizon's mean COP, drawn hidden behind the legend. It
  and the thermal price are computed by `bruce.flo_params.flo_plot_data`
  on `thdfw/optimal-flexibility` `main` (`170f22f`), which is ahead of
  the local `main`. Whether the two are a word's fields or stay a browser
  projection from `flo.params` is undecided.
- The x axis shows hours only across a two-day horizon; whether the
  ticks should show the date at midnight is open.
- The 2-path, 48-step figures are bruce's current tuning; a 5-minute FLO
  (OPS-491) multiplies the count, not the size per recommendation.

## For Thomas


**New view**  Keeping the `FloPlot.tsx` view from `td/dev` with the heat pump and load, the thermal price, the storage state in Reds with the state of charge, and the stacked penalties with the terminal cost. I attempted to match this as best I could.

I tracked the extraction half of `graph_plot_data` (band temperatures, thermoclines, penalty terms read off the solved graph) to create the new words: it is now `path_words` in your own repo, `optimal-flexibility/src/bruce/service.py`, on the branch `jm/flo-plot-words`, and it fills two words bruce publishes beside each path.

Where each piece is:

- **Where bruce fills the words:** `optimal-flexibility`, branch
  `jm/flo-plot-words`,
  `src/bruce/service.py`: `path_words` at line 198 walks the path,
  builds the `FloTankStorePath` at line 251 and the
  `FloPathPenaltiesBruce` at line 261; `store_wh_at` at line 182 is the
  empty and full store energy.
- **The classes bruce builds them with:** the vendored snapshot in the
  same repo, `src/bruce/sema/types/flo_tank_store_path.py` and
  `flo_path_penalties_bruce.py`. Generated; regenerated by
  `scripts/regen_sema_snapshot.sh`.
- **Where the words are defined:** the `sema` repo,
  `definitions/types/flo.tank.store.path/000.yaml`,
  `definitions/types/flo.path.penalties.bruce/000.yaml` and
  `definitions/types/flo.recommendation/001.yaml`. Fields, units and
  axioms are there and nowhere else.

**What was there.** To get one path for one hour, the `td/bruce-flo`
backend:

- imported bruce through an editable path dependency on a sibling
  checkout of `optimal-flexibility`;
- read the hour's `flo.params` out of the journal as a raw dict;
- re-solved the whole horizon on the web box and walked the graph;
- returned a hand-built dict of about 18 KB, with RGBA strings, labels
  and bar widths in it, and kept recent results in a cache on disk;
- and the browser typed that dict with a hand-written interface.

Under it, and older than your branch, the backend on `main` already
depended on a second optimizer the same way: `gridworks-flo` as an
editable path dependency on `../gridworks-innovations/gridworks-flo`,
imported as `gridflo` (`Flo`, `DGraphVisualizer`, `FloParamsHouse0`) by
`api/backend_api.py` for the legacy `POST /flo`, by `flo_download.py` for
the xlsx, and by `side_quests/flo_reports/`. On web-api2 that sibling is
a copied directory with no git checkout behind it, so the optimizer code
the site ran there had no commit anyone could name. Your branch added
`bruce-energy` beside it in the pattern the repo already had.

**Why I changed it.** None of this is about the plot. It is about where
the facts live and what crosses between programs.

- *The FLO service had already answered.* The LTN's FLO run publishes a
  `flo.recommendation` for that hour, and it is in the journal. A second
  solve on the web box can disagree with it: the plot then depends on
  which commit the web box's bruce checkout is at, and the web box needs
  numpy, the graph and the transition matrices to draw a picture.
- *Everything that crosses between two GridWorks programs is a sema
  word.* The dict from the backend to the browser was a private format
  only those two files knew. The `flo.params` read as a raw dict skipped
  the codec that checks the word's version and axioms.
- *A fact the browser needs that no word states becomes a word, filled
  where the fact lives.* Layer temperatures, thermoclines and penalties
  live in the solved graph, so bruce states them. The web backend should
  not derive them, and the browser should not guess them.
- *The browser renders.* Colors, labels and bar widths are drawing
  decisions, so they belong in the component and not in the data.
- *Deployed boxes run committed, pushed code.* An editable sibling
  checkout on the web box has no pinned version, and the copied
  `gridworks-innovations` directory on web-api2 has no version at all.

**What it is now.**

- Two words bruce fills per path: `flo.tank.store.path` (layer count,
  the three band temperatures, the two thermoclines, and the store's
  energy when empty at 70 F and when full) and `flo.path.penalties.bruce`
  (the three penalty series, the terminal cost, the terminal cost of an
  empty store, and the path's total cost). `flo.recommendation` 001 has
  one of each beside every path.
- The FLO service publishes the 001 recommendation; the journalkeeper
  journals it.
- The web backend finds the house's recommendation for the slot in the
  journal, decodes it through its snapshot and serves the word. It
  serves the slot's `flo.params` the same way. It has no optimizer.
- The browser parses both words with zod schemas and draws them. The
  only optimizer rule left in the browser is the COP per step, from the
  coefficients `flo.params` states.
- Gone from the backend: the bruce import and dependency, the `gridflo`
  imports with the `gridworks-flo` path dependency and
  `side_quests/flo_reports/`, the plot cache, the legacy `POST /flo`, and
  the xlsx download, which the page fetched and discarded. The backend
  needs no sibling checkout, so `gridworks-innovations` can come off the
  web boxes when this deploys.
- `flo_params.py` in your repo stays as your tool for re-solving a run
  from its request. The dashboard does not call it.

**Three things for you to check.**

1. The number in your title is `initial_node.pathcost` after
   `find_shortest_path`: the total cost of the forecast-cheapest path,
   electricity at forecast prices plus penalties plus terminal cost.
   `PathCostUsd` is that sum per path, and the page opens on the path
   with the lowest one. For orange1's 14:00 slot of 2026-11-09 both give
   $7.97. Tell me if you mean something else by it.
2. I interpretted "normalized" electricity price as the price over the
   horizon's mean COP. Confirm or correct.
3. `path_words` adds four fields from your asset: `compute_energy` for
   the whole store at 70 F and at `max_tank_temp_f`, `terminal_cost_full()`,
   and the sum of the walked edges' costs plus the terminal cost. Please
   read those four lines in `service.py` on `jm/flo-plot-words`.
