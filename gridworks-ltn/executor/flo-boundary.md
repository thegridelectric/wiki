# The FLO boundary

Status: Draft · Pass 0 · Updated 2026-11-18

> What this is: the contract between an LTN and its FLO (Forward-Looking
> Optimizer): the one exchange, the three words at the seam, where every
> input comes from, and the one piece of state that survives an hour. The
> FLO side (the service, the optimizers) is the FLO executor
> (`../../flo/executor/primary.md`).

## The one call

An LTN reaches its FLO through one exchange over the broker: a
`flo.params` goes out, and a `flo.recommendation` or a `flo.refusal`
comes back. The LTN imports nothing from any optimizer, shares no Python
types with it, holds no graph, state or settings of the FLO's between
exchanges, and the FLO never sees the real-time price. The reply is
complete over prices, so the LTN reads the cleared price's pair off the
reply it already holds. One request, one reply, no FLO state between
them.

The rule this sets for new work: a feature that seems to need the LTN
to hold state between calls puts that state in the words or in the
FLO. The field history behind the rule is in the gridworks-scada
changelog (2026-11-02, "One call and response").

The FLO is the universe's one FLO service, the GNode `<universe>.flo`
under the universe root, so the LTN finds it from its own alias
(`actors/ltn/flo_service.py` `flo_alias`). The request is a gw-wrapped
`flo.params` published on the scada broker to the `flo` class
(`gw/<ltn>/to/flo/flo-params`), which the broker bridges onto
`amq.topic` where the service's queue is bound. The answer comes back
the same way on the service's own topic to the `ltn` class: a wrapped
`flo.recommendation` (`gw/<flo>/to/ltn/flo-recommendation`) or
`flo.refusal` (`gw/<flo>/to/ltn/flo-refusal`). The LTN's codec decodes
both on those topics and nothing else from that source
(`actors/ltn/ltn.py` `LtnMQTTCodec`).

## Where every input comes from

`flo.params` is one word for every FLO, built by the LTN
(`actors/ltn/flo_request.py` `build_flo_params`) from:

| input | source |
|---|---|
| `Tuning` (a `oneOf` of the FLOs' tuning words; its TypeName names the FLO), `MarketMakerAlias`, `MarketProductName`, the heating curve, `HpMaxKwEl`, `HpTurnOnMinutes`, `DispatchHold` | the ops word, `operational-params.json` beside the layout in the LTN's config dir |
| `GallonsPerTank`, `TempSensorsPerTank`, `TotalStoreTanks` | the layout's `gw.water.store` |
| `SeasonalStorageMode` (the tanks modeled: the store in AllTanks, one tank in BufferOnly), whether dispatch is accepted | the scada's `gw.house.operating.status` |
| the hourly temperatures, and `WeatherForecastId` as the forecast's `ForecastUid` | the `gw.weather.forecast` the LTN pulls; a seasonal fill is refused (`SeasonalFillForecast`) |
| `PriceUsdMwhList`, one price per hourly step from the request's own slot, and `PriceForecastId` as the forecast's `ForecastUid` | the `gw.price.forecast` the LTN pulls from the price service's route (`actors/ltn/ltn.py` `get_price_forecast`), decoded through its snapshot and kept as bytes in its data dir, the copy it reads when the service is unreachable; a forecast with no slot starting at the request's is refused (`PriceForecastMissesSlot`) |
| the heat load and RSWT per hour | the heating curve applied to the forecast |
| the measured store: three layer temperatures and two thermoclines counted in sensor layers from the top; whether the heat pump is on | the scada's latest readings at the bid minute |
| the buffer's available energy, the average zone temperature, the last four hours of distribution energy and of outdoor temperature | the scada's latest readings, kept hour by hour in the LTN |
| `PreviousOptimalPath` | the previous run, below |

A house fact one FLO reads sits in its tuning word and moves to the
shared ops fields when a second FLO reads it. Nothing the FLO is given
comes from the LTN's own settings: `LtnSettings` (`LTN_` prefix) is
plumbing, the MQTT client, the dashboard, the clock and weather sources,
`flo_horizon_hours`, `keep_buffer_full` and `bid_lead_s`.

The market facts are the bidder's. The slot name and the latest-price
topic are formed from the ops word (`actors/ltn/market.py`
`market_slot_name`, `latest_price_topic`); the reply states only the
curve, its units and the paths.

## The slot

1. `bid_lead_s` seconds before the slot starts (180 by default, validated
   to be less than one slot so each slot gets exactly one request) the
   LTN measures the store, builds `flo.params` with the previous run
   attached when it applies, and sends it to the FLO
   (`actors/ltn/ltn.py` `ask_the_flo`). The slot is an hour starting on
   the hour (`MARKET_SLOT_S`, hard-coded in `market.py` until the market
   posts its own facts); its start is the next whole slot of UTC
   seconds (`next_slot_start_s`) and does not move at a clock change.
   The request is kept until the next slot's request replaces it, so
   the answer and the clearing price both find it.
2. A `flo.recommendation` that answers the request held becomes the
   bid: its price-quantity pairs go to the MarketMaker as a `Bid`, and
   the recommendation is kept for the price that clears
   (`process_flo_recommendation`). One for another bidder or slot, one
   with no request held, or a second answer to the same request is
   dropped with a log line.
3. A `flo.refusal` for the request held is raised as a Warning glitch
   with the service's reason (`flo.refusal.reason`: `NoTuning`,
   `NoMatrix`, `BuildFailed`, `BuildLost`, `PastDeadline`, `Unknown`) so
   the fleet sees why the slot has no FLO bid (`process_flo_refusal`).
   A refusal for another request is dropped.
4. At the top of the hour the price clears. The pair that applies is
   the lowest-priced one at or above the cleared price
   (`cleared_pair_index`): a pair holds for every price above the next
   lower pair's price up to and including its own. A cleared quantity
   under 1000 Wh is a zero contract.
5. The LTN takes that pair's `flo.optimal.path`, the one at the same
   index, and saves it as the previous run.

A slot with no answer gets no bid: when the price arrives and no bid is
held, the LTN logs it and no contract forms. The LTN has no bid of its
own to make without the FLO. With the operator's hold on
(`DispatchHold.OperatorHold`, reported by the scada as `AcceptsDispatch`
false) or the scada out of Heating mode, the main loop idles and no
request is sent. A stop ends the actor at once (`stop`); the only thing
in flight is a request on the broker, and its answer, arriving after a
restart, finds no request held and is dropped.

## The last hour

The one thing that survives an hour is the previous run,
`previous_run.json` in the LTN's data dir, a `flo.previous.run`: the
cleared path, the cleared pair and its index, the units, and the price
the request forecast for the slot after it (`keep_cleared_path`,
`save_previous_run`, `load_previous_run`). The next request attaches
its path as `PreviousOptimalPath` only when the path's first step ends
at the request's start (`previous_run_for`); the FLO lines the previous
plan up from the path's second step, because step 0 is the slot that
cleared, and feeds it to its stability penalty. A saved run the loader
cannot read is logged and dropped.

## What the LTN copies to the scada

The LTN publishes the request, the recommendation or refusal, and the
kept previous run to the scada under its own alias so the broker
journals them; the scada ignores them. Every payload the LTN sends its
scada is a word; the envelope takes its MessageType from the payload,
so a payload without a TypeName is refused when the message is built,
never swallowed at publish.

## Tests

| clause | test (`tests/actors/`) |
|---|---|
| the FLO is the universe's; the request goes to the FLO and the scada; the answer becomes the bid; an answer for another request, with no request held, or a second answer is dropped | `test_ltn_flo_exchange.py` |
| the recommendation and the refusal arrive on the FLO's topics (live broker) | `test_ltn_flo_recommendation.py`, `test_ltn_flo_refusal_live.py` |
| a refusal of the request held is recorded and raised; a refusal of another request, or with no request held, is dropped | `test_ltn_flo_refusal.py` |
| the request is the house's facts; BufferOnly models one tank; a seasonal fill is refused; the prices start at the request's slot; the buffer's energy comes off the first hours | `test_flo_request.py`, `test_ltn_price_forecast.py` |
| the clearing rule | `test_ltn_clearing.py`, every breakpoint |
| the previous run: handed on in the request's units, only for its slot, survives disk as its word, an unreadable one is dropped | `test_flo_request.py` `test_a_previous_run_*` |
| the slot is the next whole hour and does not move at a clock change | `test_flo_request.py` `test_the_next_slot_*`, `test_the_slot_does_not_move_at_a_clock_change` |
| `bid_lead_s`: the default, the env, outside one slot refused | `test_ltn_bid_lead.py` |
| the slot name and topic come from the ops word | `test_market.py` |
| no FLO while the house refuses dispatch | `test_dispatch_refusal_gate.py` `test_the_main_loop_runs_no_flo_while_the_house_refuses_dispatch` |
| a payload without a TypeName is refused; the cleared run wraps as `flo.previous.run` | `test_ltn_scada_publish.py` |

## Open

- Whether the previous path stays the LTN's to hand back or becomes the
  FLO's own memory per house once the FLO keeps the graph between
  requests. Decided before the FLO words leave staging.
- The store's ceiling: the FLO buys nothing while the store sits above
  the heating curve's `MaxEwtF`. Whether that ceiling is the FLO's to
  hold or the plant's to state, with the price bounds and the store's
  layer resolution (OPS-653).
- The market's price bounds are two constants in `flo_request.py`
  until the MarketMaker's product word states them.
- The request does not check that the forecast's `MarketMakerAlias` and
  `ProductName` are the LTN's own market. The LTN has one market today;
  the check belongs with the word that names it.
