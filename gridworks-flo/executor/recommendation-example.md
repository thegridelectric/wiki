# A flo.recommendation, read field by field

Status: Draft · Pass 0 · Updated 2026-11-18

> What this is: one real `flo.recommendation` as the FLO service
> published it, annotated so a reader can find the plan and its cost
> without the plot. The word is beech's for the slot starting 2026-11-18
> 19:00 ET, from the production journal, in the trace
> [`traces/2026-11-18-beech-1900et/`](traces/2026-11-18-beech-1900et/trace.yaml)
> as `beech-flo.recommendation-002.json`, beside the `flo.params` 003 it
> answers and the `flo.previous.run` the LTN published when the slot
> cleared. The schema is `sema/definitions/types/flo.recommendation/`;
> the visualizer draws this word in its FLO view (web-backend executor
> `visualizer.md` "FLO").

## One word, several paths

A recommendation is a bid and the plans behind it. The FLO does not
know the price the market will clear, so it bids a curve, `PqPairs`,
and for each pair it states the 48-step path it would follow if the
first hour clears at that pair. `OptimalPathList`, `StoreStateList`
and `PathPenaltiesList` run parallel to `PqPairs`: index i of each is
the same plan. Pairs descend from the price ceiling; the cleared price
selects the pair whose price is the first at or above it, and the house
takes that path's first step. The next slot's FLO replaces the rest.

Only the first step of one path is ever acted on. The 48 steps are the
optimizer's expectation under one price assumption, and "the total cost
of the next 48 hours" is a statement about that expectation.

## The envelope

| field | value here | meaning |
|---|---|---|
| `BidderAlias` | `hw1.isone.me.versant.keene.beech` | the house the bid is for |
| `CreatedMs` | 1795046243363 (2026-11-18 23:57:23 UTC) | bruce's clock when it answered, 2.6 min before the slot |
| `FloName` / `FloRepo` / `FloGitCommit` | `bruce` / `github.com/thdfw/optimal-flexibility` / `bccfe41…` | which optimizer code produced it |
| `PriceUnit` / `QuantityUnit` | `USDPerMWh` / `AvgkW` | units of every pair |

## The bid: `PqPairs`

Two pairs, ceiling first:

| i | `PriceX1000` | `QuantityX1000` | reads as |
|---|---|---|---|
| 0 | 2000000 | 0 | above $24/MWh up to the $2000 ceiling: draw nothing |
| 1 | 24000 | 6361 | at or below $24/MWh: run the heat pump at 6.36 kW |

The house will charge in this hour only at a price below $24/MWh. The
request explains the threshold: outdoor 45 °F, `SeasonalStorageMode`
BufferOnly, 113.6 kWh of load over the horizon starting at 2.51 kWh in
the first hour, the store at 143.8/138.7/84.3 °F against a required
supply temperature of 100 °F, and the previous slot's plan in
`PreviousOptimalPath`, which makes the stability penalty live
(`StabilityPenaltyEnabled` true at weight 0.5). The forecast price for
the first hour is $643.44/MWh (`PriceUsdMwhList[0]`, the distribution
peak) and $114.50 for the hour after, so bruce's own expectation is
pair 0, with the first charge two hours out at $113. The slot did clear
at pair 0: the LTN's `flo.previous.run` says `ClearedPairIndex` 0.

## The path: `OptimalPathList[i]`

`flo.optimal.path` 000: `StartUnixS` 1795046400 (the slot start),
`StepDurationMinutes` (48 × 60), `HpAvgWList` (the heat pump's average
electrical draw per step) and `StoreWhList` (usable energy in the store
at the end of each step).

Path 0 leaves the heat pump off in hour 0 and charges twelve times
across the two days, each in a cheap hour: 7.7 kW at step 2 (21:00 ET,
$113), 7.7 and 3.1 kW at steps 7 and 9 (02:00 and 04:00, $93 and $97),
7.7 kW at step 17 (noon, $96), 7.7 and 3.9 kW at steps 27 and 28
(22:00 and 23:00, $92 and $91), four partial hours of 1.5 to 3.0 kW
overnight, 7.7 kW at step 41 (noon) and 1.5 kW at step 43. The store
runs between 162,620 Wh and 183,490 Wh and ends at 176,805 Wh. Path 1
runs 6.36 kW in hour 0, charges in the same later hours for a little
less each time, and ends at 176,968 Wh.

## The store along the path: `StoreStateList[i]`

`flo.tank.store.path` 000 for a 9-layer model (`StoreLayers`): per
step the top, middle and bottom temperatures (`TopFList`,
`MiddleFList`, `BottomFList`) and where the two thermoclines sit
(`Thermocline1List`, `Thermocline2List`, layer indices), with
`EmptyStoreWh` 155,446 and `FullStoreWh` 183,620 as the model's floor
and ceiling. Path 0 reads 130/110/100 °F at the end of hour 0 and
110/100/90 at the end of hour 1, then charges; path 1 reads
165/155/150 after hour 0's charge. The plot's tank blocks and
state-of-charge panel are this word.

## The cost: `PathPenaltiesList[i]`

`flo.path.penalties.bruce` 001: per step, the dollars the optimizer
added to the electricity cost for conditions its tuning tells it to
avoid (`RswtPenaltyUsdList`, `UnmetLoadPenaltyUsdList`,
`StabilityPenaltyUsdList`, `ShortCyclePenaltyUsdList`), then three
totals:

| field | path 0 | path 1 |
|---|---|---|
| `TerminalCostUsd` | 0.31 | 0.30 |
| `TerminalCostEmptyStoreUsd` | 0.88 | 0.88 |
| `PathCostUsd` | **5.62** | **9.59** |

`PathCostUsd` is the optimizer's objective for the whole path: the
electricity cost of every step at the forecast price, plus the
penalties, plus the terminal cost. The word states only the total; the
electricity term is recomputable from the path and the params (price ×
kW × hours per step), and the split for this word, to within a cent,
is:

| | path 0 | path 1 |
|---|---|---|
| electricity | 5.31 | 8.77 |
| stability penalty | 0.00 | 0.52 |
| RSWT, unmet-load, short-cycle penalties | 0.00 | 0.00 |
| terminal cost | 0.31 | 0.30 |
| `PathCostUsd` | 5.62 | 9.59 |

So on this evening the cost is mostly electricity, with one penalty
live: path 1 departs from the previous slot's plan, which did not charge
in this hour, and the stability penalty prices that departure at $0.52.
Both paths keep the store above the required supply temperature and
meet every hour's load, so the RSWT and unmet-load lists are zero. The
terminal cost is small because both paths end near full, against the
$0.88 an empty store would cost. Charging now (path 1) spends $4.09 of
electricity at $643/MWh for 6.36 kW that path 0 buys two hours later at
$113, so path 1 loses by $3.97. The on-pair sits where the hour-0 charge
becomes the cheaper edge: the bid sweep keeps a new pair where the
cheapest hour-0 edge changes. The hour it displaces costs $113, and the
stability penalty on leaving the previous plan is what pulls the
threshold down to $24.

The visualizer's FLO view opens on the path with the lowest
`PathCostUsd` and puts that value in the plot title beside the slot
(`flo-path-view.ts`); the stacked penalties panel is the four lists.

## Reading it for a question

- *What will the next 48 hours cost?* `PathCostUsd` on the pair the
  first hour clears at; before clearing, the pair with the lowest
  `PathCostUsd`, which is the forecast-price pair. It mixes money with
  tuning dollars; the electricity term alone is the sum above.
- *Which pair did the house follow?* The one `flo.previous.run` names
  in `ClearedPairIndex`, published by the LTN at the slot start. The
  recommendation itself does not state the cleared price.
- *Why is the on-pair at $24 and not at the forecast price?* Because
  the pair marks the price at which charging in this hour beats
  charging in the cheapest later hour, and with the previous plan in
  the request that comparison includes the stability penalty for
  changing course. Above $24 the plan waits; the unmet-load penalty is
  what makes waiting a plan to charge later rather than a plan never
  to charge.
