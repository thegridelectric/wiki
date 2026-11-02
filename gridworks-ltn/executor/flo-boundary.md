# The FLO boundary

Status: Draft · Pass 0 · Updated 2026-11-02

> What this is: the contract between an LTN and its FLO (Forward-Looking
> Optimizer): the one call, the two words at the seam, where every input
> comes from, and the one piece of state that survives an hour. The FLO
> side (the service, the optimizers) is the FLO executor
> (`../../flo/executor/primary.md`).

## The one call

An LTN reaches its FLO through one callable, bytes in and bytes out: a
serialized `flo.params` goes in, a serialized `flo.recommendation` comes
back. The LTN imports nothing else from the optimizer, shares no Python
types with it, holds no graph, state or settings of the FLO's between
calls, and the FLO never sees the real-time price. The reply is complete
over prices, so the LTN reads the cleared price's pair off the reply it
already holds. One request, one reply, no FLO state between them.

Today the callable is bruce's `bruce.service.recommend_bytes`, run in a
child process that exits when it answers so the OS reclaims the graph's
memory (`actors/ltn/ltn.py` `_flo_worker`). The transport of the same
bytes over the broker to the `hw1.flo` service is the FLO executor's
seam; when the LTN moves to it, this callable's transport is the only
thing that changes.

The optimizer is installed into the LTN's environment from the GridWorks
fork `thegridelectric/optimal-flexibility` at a tag named in
`tools/mkenv.sh` (`BRUCE_TAG`). A box has no checkout of the optimizer
and the optimizer reads no `.env` of its own: the environment it sees is
the LTN process's, and the only variables it reads are the transition
matrix controls (`CAN_COMPUTE_TRANSITION_MATRICES`, unset on a box, so a
plant shape with no cached matrix is refused rather than built at the
bid minute; `BRUCE_BASE_PATH`, the cache root) and its log level.
Matrices are generated as a separate step and placed on the box
(`gridworks-infra/ltn/instance-README.md`).

## Where every input comes from

`flo.params` is one word for every FLO, built by the LTN
(`actors/ltn/flo_request.py` `build_flo_params`) from:

| input | source |
|---|---|
| `Tuning` (a `oneOf` of the FLOs' tuning words; its TypeName names the FLO), `MarketMakerAlias`, `MarketProductName`, the heating curve, `HpMaxKwEl`, `HpTurnOnMinutes`, `DispatchHold` | the ops word, `operational-params.json` beside the layout in the LTN's config dir |
| `GallonsPerTank`, `TempSensorsPerTank`, `TotalStoreTanks` | the layout's `gw.water.store` |
| `SeasonalStorageMode` (the tanks modeled: the store in AllTanks, one tank in BufferOnly), whether dispatch is accepted | the scada's `gw.house.operating.status` |
| the hourly temperatures, and `WeatherForecastId` as the forecast's `ForecastUid` | the `gw.weather.forecast` the LTN pulls; a seasonal fill is refused (`SeasonalFillForecast`) |
| the heat load and RSWT per hour | the heating curve applied to the forecast |
| the measured store: three layer temperatures and two thermoclines counted in sensor layers from the top | the scada's latest readings at the bid minute |
| `PreviousOptimalPath` | the previous run, below |

A house fact one FLO reads sits in its tuning word and moves to the
shared ops fields when a second FLO reads it. Nothing the FLO is given
comes from the LTN's own settings: `LtnSettings` (`LTN_` prefix) is
plumbing, the MQTT client, the dashboard, the weather URL,
`flo_horizon_hours` and `keep_buffer_full`.

The market facts are the bidder's. The slot name and the latest-price
topic are formed from the ops word (`actors/ltn/market.py`
`market_slot_name`, `latest_price_topic`); the reply states only the
curve, its units and the paths.

## The slot

1. At the bid minute (:57) the LTN measures the store, builds
   `flo.params` with the previous run attached when it applies, and runs
   the FLO once. The slot start is the next whole hour of UTC seconds
   (`next_slot_start_s`); it does not move at a clock change.
2. The bid is the reply's price-quantity pairs. The request is kept
   until the next slot's request replaces it.
3. At the top of the hour the price clears. The pair that applies is
   the lowest-priced one at or above the cleared price
   (`cleared_pair_index`): a pair holds for every price above the next
   lower pair's price up to and including its own. A cleared quantity
   under 1000 Wh is a zero contract.
4. The LTN takes that pair's `flo.optimal.path`, the one at the same
   index, and saves it as the previous run.
5. A stop during a run ends the child within a second (`BidRunner.stop`);
   the run is the only thing in flight.

Without the optimizer installed, or when the FLO errors, the LTN's
answer is its no-FLO fallback and the slot is logged. With the
operator's hold on (`DispatchHold.OperatorHold`, reported by the scada
as `AcceptsDispatch` false), the main loop idles and the FLO does not
run.

## The last hour

The one thing that survives an hour is the previous run,
`previous_run.json` in the LTN's data dir (`PreviousRun`,
`save_previous_run`, `load_previous_run`). The next request attaches it
as `PreviousOptimalPath` only when the path's first step ends at the
request's start (`previous_run_for`); the FLO lines the previous plan up
from the path's second step, because step 0 is the slot that cleared,
and feeds it to its stability penalty. The LTN also publishes the
request, the recommendation and the kept path to the scada under its
own alias so the broker journals them; the scada ignores them.

## What the LTN copies to the scada

Every payload the LTN sends its scada is a word; the envelope takes its
MessageType from the payload, so a payload without a TypeName is refused
when the message is built, never swallowed at publish.

## Tests

| clause | test (`tests/actors/`) |
|---|---|
| one request, one reply, bytes both ways | `test_ltn.py` `test_the_flo_answers_the_request_with_a_recommendation`, `test_without_bruce_the_worker_answers_an_error` |
| the request is the house's facts; BufferOnly models one tank; a seasonal fill is refused | `test_flo_request.py` `test_the_request_is_the_houses_facts`, `test_buffer_only_models_one_tank`, `test_a_seasonal_fill_is_refused` |
| the clearing rule | `test_ltn_clearing.py`, every breakpoint |
| the previous run: handed on, only for its slot, survives disk | `test_flo_request.py` `test_a_previous_run_*` |
| the slot is the next whole hour and does not move at a clock change | `test_flo_request.py` `test_the_next_slot_*`, `test_the_slot_does_not_move_at_a_clock_change` |
| the slot name and topic come from the ops word | `test_market.py` |
| stop ends the run | `test_bid_runner.py` `test_stop_kills_the_child_and_ends_the_run` |
| no FLO while the house refuses dispatch | `test_dispatch_refusal_gate.py` `test_the_main_loop_runs_no_flo_while_the_house_refuses_dispatch` |
| a payload without a TypeName is refused | `test_ltn_scada_publish.py` |

## Open

- Whether the previous path stays the LTN's to hand back or becomes the
  FLO's own memory per house once the FLO is a service that keeps the
  graph. Decided before the FLO words leave staging.
- The store's ceiling: the FLO buys nothing while the store sits above
  the heating curve's `MaxEwtF`. Whether that ceiling is the FLO's to
  hold or the plant's to state, with the price bounds and the store's
  layer resolution (OPS-653).
- The market's price bounds are two constants in `flo_request.py`
  until the MarketMaker's product word states them.
