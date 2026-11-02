# LTNs ready

Status: Accepted · Pass 1 · Updated 2026-11-02 · Linear: OPS-654

**EDD: yes** the verification is a live slot: the LTN bids at :57, the
price clears at :00, the scada takes the contract, and both boxes' logs
are clean through it; the first one ran on oak 2026-11-02 02:57 ET.

> What this is: the LTNs running against the new scada code and bidding
> through the bruce FLO. It settles what the LTN takes from the scada and
> gives back, the FLO boundary (sema words at every edge), and how a slot
> runs. It is the write-up for Thomas and Olly while the branch rolls out;
> the durable parts distill into `executor/` and the design goes when it
> closes. The LTN work that can wait goes back to spruce-settled (OPS-532).

## Before td/bruce becomes main (do this next, on a PR)

td/bruce is current main plus Thomas's FLO commits re-applied on top; it
supersedes td/generalized-flo and the paused merge worktree. The work
goes on `jm/flo-tuning-ops`, a PR against it, which squash-merges to
main when the list below is done. Each commit of ours gets its scada
changelog entry as it goes in; Thomas's existing commits get none, the
squash commit's entry covers the branch as a whole.

**Done**

- [x] The FLO boundary words are in sema and published (`03a949d`):
  `flo.params` with `Tuning` a oneOf over `flo.tuning.bruce` and
  `flo.tuning.alice`; `flo.recommendation` with `flo.optimal.path`;
  `gw.weather.forecast` 002; `gw.water.store` tank facts;
  `gw.operational.params` with `FloTuning`, `MarketMakerAlias` and
  `MarketProductName`.
- [x] The scada snapshot and twins, with an oracle test per axiom and the
  four `tests/config` pairs (`2057d6cd`); tlayouts regenerated
  (`1bc46e7`; `6de9e67` names alice at spruce and keeps bruce in the
  spruce sim).
- [x] bruce's boundary callable, on optimal-flexibility `jm/flo-as-service`
  and tagged `v0.1.0+gw1` on the GridWorks fork: `recommend`,
  `recommend_bytes` and `params_from_request` on bruce's own snapshot,
  with `tests/test_recommend.py`; `generate_bid` sweeps from the ceiling
  down and keeps every quantity change (`jm/bid-descends-from-price-max`,
  PR 1 to Thomas).
- [x] The LTN builds `flo.params` from the ops word, the layout's water
  store, the operating status and the forecast, and refuses a
  seasonal fill (`actors/ltn/flo_request.py`, `a30145f3`). The FLO child
  maps it through bruce's `params_from_request`. `LtnSettings.ha1_params`,
  `actors/ltn/flo_tuning.py` and `TANK_GALLONS` are gone; `LtnAppInterface`
  gives the actor the ops word, the clock and the weather source.
- [x] The slot name and the latest-price topic come from the ops word
  (`actors/ltn/market.py`); `LtnSettings.market_maker_alias` is gone.
- [x] The best-effort publish wrapper (`e1392b6a`) is reverted: what the
  LTN copies to the scada is a word, and a payload without a TypeName is
  refused when the message is built.
- [x] `tools/mkenv.sh` installs bruce from the fork at the tag; the
  sibling editable install is the laptop's option.

**To do**, in this order, each with its test

- [x] The clearing rule is a pure function picking the lowest-priced
  pair at or above the cleared price (`cleared_quantity_x1000` in
  `actors/ltn/market.py`), tested on each breakpoint
  (`tests/actors/test_ltn_clearing.py`, `a7bda953`). Ships with the bruce bump to
  the forked sweep, since the deployed sweep emits one pair per bid and
  the rule only bites on a curve.
- [x] The LTN takes the cleared pair's path off the recommendation
  (bruce's `path_from` walks the node chain), saves it as the
  `PreviousRun` and hands it back as `PreviousOptimalPath` with the
  price estimate; the third FLO call and `flo.next.hour.plans` are gone.
  bruce's `params_from_request` now lines the previous plan up from the
  path's step 1, since step 0 is the slot that cleared (fork
  `jm/flo-as-service`, with its test; the tag and `tools/mkenv.sh` pin
  move with the bruce bump). Outside this repo: the journalkeeper's seed
  names `flo.params.house0` but none of `flo.params`,
  `flo.recommendation` or `flo.optimal.path`, so the LTN's record words
  reach the broker and are dropped at the journal until it is reseeded.
- [x] One call and response: the LTN measures the store at the bid
  minute (:57), builds `flo.params` with the previous run attached, runs
  bruce's `recommend_bytes` in one child process and sends the bid off
  the answer; the request stays until the next slot's replaces it, so
  the clearing price finds it. The build worker, the trimmed graph, the
  copied `recommend` loop, the two-event `BidRunner`, `sent_bid`,
  `LtnSettings.create_graph_minute` and `.seasonal_storage_mode` are
  gone; `BidRunner.stop` ends the run within a second and `Ltn.stop`
  calls it. Tests: the round trip against bruce in the venv
  (`tests/actors/test_ltn.py`), the stop (`test_bid_runner.py`), the
  slot helpers. Why in "One call and response" below.
- [x] The fall-back bid slot (the daylight-saving bug): the slot start
  is `next_slot_start_s`, whole hours of the epoch, with the fall-back
  and spring-forward instants as tests. The history: at the
  2026-11-01 06:00Z change from EDT to EST, oak's 05:58Z bid named the
  07:00Z slot while the clearing price named 06:00Z; the LTN sent an
  "Invalid bid timeframe" glitch, dropped the bid, then logged "FLO state
  inconsistent (flo_params=False, bid_runner=True); waiting for next
  loop" every minute until a restart at 11:23Z, five hours without a
  bid. The 05:00Z contract also logged as "01:00 - 01:00". Slot
  arithmetic in `ltn.py` runs on local wall-clock hours somewhere
  (`datetime.now()` in `run_d` and the main loop are the first
  suspects); find it, make the slot start UTC seconds end to end, and
  add the test that reproduces the fall-back hour (and the
  spring-forward one) before the fix. The five-hour wedge was the
  two-phase state going inconsistent and went with the collapse.
- [x] The LTN does not stop on SIGTERM while a FLO is in flight (done
  with the collapse: the run polls its child every second and `stop`
  ends it; `test_bid_runner.py`). The history: four
  restarts on 2026-10-31 and 11-01 hit systemd's `stop-sigterm timed
  out. Killing.`, and the two that were code pulls each cost that hour's
  bid. `BidRunner.stop` only sets `stop_event`; the run loop is blocked
  in `get_bid_event.wait()` or a child `join`, so the event is never
  checked. The waits go with the collapse; what remains is one child
  to terminate on stop, with the test that it stops within the systemd
  timeout.
- [x] First live run on oak (2026-11-02): the roll missed the 01:57 bid
  because the scada re-reported `ScadaBlind` only on the 300 s report
  tick; the reading path now re-reports when the buffer's freshness
  flips (`eb251bcc`). The 02:28 run failed on the missing 3-layer
  transition matrix, generated and placed (see "Open"). `LtnSettings.monitor_only`
  is gone: the operating status is the LTN's only word on whether to
  run its FLO, and `DispatchHold.OperatorHold` in the ops word says what
  the five `LTN_MONITOR_ONLY=True` lines in the box `.env` files said
  (every LTN but oak; the lines come out of the `.env` files on the next
  roll). Beech ran the branch with the hold on; the hold reached its LTN
  and the main loop's hold path is tested
  (`test_the_main_loop_runs_no_flo_while_the_house_refuses_dispatch`).
  Oak's first bid on the line went out at 02:57:57 (FLO answered in
  2.95 s, two pairs: 0.014 kW at the 2000 USD/MWh ceiling, 3.04 kW at
  82 USD/MWh); the 03:00 price cleared at 90.42 USD/MWh, the LTN kept
  the cleared path and created a 0 Wh contract (a cleared quantity under
  1000 Wh is a zero contract), the scada took it and went to the leaf
  ally with the heat pump off. No error, glitch or warning on either
  box's proactor log through the slot. Beech's LTN idles with the hold.
  **Do this next:** squash to main with the open items below still
  open.
- [x] Retire the `MarketTypeName` twin and the unread `market.maker.ack`
  twin (`213ac3a0`): the twin's slot-name check is already the
  maker-agnostic sema pattern and reads no enum; the only reader of
  `MarketTypeName` was the `MarketName` format the ack twin alone used.
  Both twins, the format and the seed's `market.type.name` are gone and
  the snapshot regenerated.
- [x] Axiom 7 on `gw.operational.params`, `FloTuningAdmitsFamily`
  (sema `fe60b58`, twin `213ac3a0`): a FLO is a model of a plant as
  operated, so the ops instance's FloTuning must be admissible for its
  FamilyParams. Clause a: `flo.tuning.bruce` (one heat pump charging one
  stratified store) on a House0 family excludes `SiegLoopStrategy`
  LwtControl. The Nolan row (alice only until the Nolan scada has a
  working leaf ally) is not written: the simulated spruce and the
  scada's Nolan test fixture run bruce with the hold off so a simulated
  Nolan can bid in tests. The table grows a row per FLO; the LTN's
  selector stays a plain TypeName dispatch.
- [ ] roll.sh moves the triple, code SHA, layout and operational params,
  to both boxes and verifies it on both. The ops instance names the
  FLO (its `FloTuning` TypeName), the LTN must read it, and a staging
  word never crosses the production broker, so the LTN box gets its
  own `operational-params.json` beside its layout from the same roll
  that places the pi's. `check` reports the triple on the pi and the
  LTN; the weekly drift check reads the ops hash as it reads the
  branch. The need is already visible: oak's scada sat six commits
  behind its LTN on td/bruce after nine hand pulls on the ltn box
  since 2026-10-31, and the heartbeat-001 crash stretch was that split
  in action. How-to home: executor `running.md` "Rolling a house
  between lines".
- [ ] On the weather service: a GET /forecasts/{ForecastUid} route, so a
  `WeatherForecastId` resolves to the values behind a run.

Live finding (2026-11-01): oak's day on the first field LTN is read
off the box log and the journal in `experiments/oaks-first-ltn/`: every
bid is one pair at the floor because the deployed sweep drops every
quantity decrease (fixed on the fork, not deployed), and the FLO would
not buy at any price while the store sat above its ceiling, which is
the heating curve's `MaxEwtF` (161 °F at oak), a boundary question in
its own right. The open analysis stays in that folder.

Live finding (2026-11-01): since the forecast box moved to
`gw.weather.forecast` 002, every deployed scada on 001 code rejects the
hourly pull on `Version` (spruce and oak journals checked) and runs on
the seasonal fill, so the FLOs plan against template temperatures until
the branch rolls; left as is, the scadas are monitored. The
fill-as-event backlog item is OPS-652.

`wiki/flo/designs/flo-as-a-service.md` (OPS-514) owns the service side:
gridworks-flo (`hw1.flo`), its topics, and the swap of the LTN's seam
from the local call to the broker.

### Note to Thomas: the FLO boundary on td/bruce

What works: the bruce optimizer builds, bids and plans on oak, and the
three-child-process split from main (build, bid, plans, each in its own
forked process with the trimmed graph pickled between them) came through
the port intact. That was the hard part.

What the branch crossed is the FLO boundary ("The FLO boundary" below):
the LTN hands the FLO one serialized sema message and gets one back, so
the FLO can run as a service for many LTNs with nothing shared but the
words. On td/bruce the bytes handed to the build child were bruce's own
`HeatPumpWaterTankParams` JSON, with no TypeName, and the bid child
returned a bare list of price-quantity dicts, so the FLO's answer had no
name and the market facts moved into LTN code.

The two words that fix it are in sema (`flo.params`, `flo.recommendation`
with `flo.optimal.path`), and the two PRs against optimal-flexibility
are: PR 1, `generate_bid` sweeps from the price ceiling down and keeps
every quantity change (`jm/bid-descends-from-price-max`,
`tests/test_generate_bid.py`); PR 2, the vendored sema snapshot and
`bruce.service.recommend(request: FloParams) -> FloRecommendation` with
its bytes-in bytes-out twin `recommend_bytes`, which derives layers and
gallons from the tank facts, takes the bid bounds from the price bounds
and feeds `PreviousOptimalPath` into the stability penalty
(`jm/flo-as-service`, OPS-514). The pickle between the LTN's own phases
is unchanged and stays: it is one process's memory handed to its child.

### For the LTN executor (draft, moves there when this design closes)

The LTN reaches the FLO in two steps. Step one: bruce is installed into
the LTN's venv from the GridWorks fork at a tag and the FLO child calls
it. Step two (OPS-514): the same bytes go to `hw1.flo` over the broker
and the LTN drops the import. Three bright lines keep step two a
one-seam change:

- The LTN imports nothing from the FLO repo except the one callable it
  invokes: bytes in, bytes out, no shared objects, no reaching into the
  FLO's graph, state or settings from the LTN side.
- The bytes in each direction are a sema word, serialized `by_alias`: a
  request the LTN builds from its own snapshot and a reply the FLO
  builds from its own. The two repos share no Python types; they share
  the vocabulary.
- The market facts (slot name, sign convention, the bid's units) are
  the bidder's: the LTN forms them from its ops word
  (`MarketMakerAlias`, `MarketProductName`) and the reply states only
  the curve, its units and the paths.
- The FLO never sees the real-time price. The reply is complete over
  prices, so the LTN reads the cleared price's pair off the reply it
  already holds. One request, one reply, no FLO state between them.
- The LTN never runs the FLO on a seasonal-fill forecast; a fill is the
  scada's fallback for its own derived channels.

The words at the boundary:

- The request is `flo.params`, one word for every FLO, built by the LTN
  from house facts: the curves, `HpMaxKwEl`, `HpTurnOnMinutes` and
  `FloTuning` from the ops word; `GallonsPerTank`, `TempSensorsPerTank`
  and `TotalStoreTanks` from the layout's `gw.water.store`;
  `SeasonalStorageMode` from the operating status, which sets the tanks
  modeled (the store in AllTanks, one tank in BufferOnly); the heat
  load and RSWT per hour from the heating curve; the measured store as
  three layer temperatures and two thermoclines counted in sensor
  layers from the top, which is the FLO's layer unit. `Tuning` is a
  oneOf over the FLOs' tuning words whose TypeName names the FLO. A
  FLO's tag is its author's chosen name (bruce; sally and ella to
  come), the first place a human name is a tag, and never for a home. A
  house fact one FLO reads sits in its tuning word and moves to the
  shared ops fields when a second FLO reads it.
- `WeatherForecastId` is the `ForecastUid` of the `gw.weather.forecast`
  the run's weather came from, so the run is reproducible. A `*Uid` is
  an identity a word mints for itself, a `*Id` a reference into another
  service's archive. The price forecast gets the same treatment when
  the price service has an Id to point at.
- The reply is `flo.recommendation` with one `flo.optimal.path` per PQ
  pair, complete over prices, so the LTN reads the cleared price's pair
  and takes the path at the same index. The LTN matches a reply to its
  request on `BidderAlias` and the first path's `StartUnixS`.
- `flo.tuning.bruce` is one branch of `FloTuning` on
  `gw.operational.params`, selecting the FLO by TypeName as
  `FamilyParams` does. `flo.tuning.alice` is the stub FLO, TypeName and
  Version only: alice answers every request with one pair at
  `PriceMaxUsdMwh` with zero quantity and a path whose first step is 0
  W, so the LTN's one rule (a bid is made from the pairs) yields a bid
  of nothing with no alice case in the code. Axiom 6 on the ops word
  makes alice require the operator hold. Alice exists so the selector
  has two branches from day one and FLO-as-a-service has its
  hello-world.
- What the LTN copies to the scada over MQTT is a word; the gw envelope
  takes its MessageType from the payload, so a payload without a
  TypeName is refused when the message is built, never swallowed at
  publish.

## One call and response

The LTN runs its FLO in two phases: it builds and solves the graph at
`create_graph_minute` (about :05), pickles the trimmed graph, and at
:57 measures the store, updates the graph's initial state and
generates the bid. The split exists for one reason: a build took
minutes, and the LTNs for the fleet were spread across the hour so they
did not run at once on one box. Nothing in the market or the plant
asks for it. The bid is due at the top of the hour and the store should
be measured as late as possible before it.

The split costs more than it looks:

- **The stability gates read the wrong "now".** bruce evaluates the
  store-difference and price-difference gates when the asset is built
  and adds the stability penalty into every edge cost then. At :57 the
  store update recomputes the gates, but `generate_bid` reads the costs
  already on the edges. So the gate compares the store at :05 with what
  the previous plan expected at the top of the hour, 55 minutes apart,
  and a heat pump moves more than the 10 kWh threshold in that time.
- **The previous run can be lost at minute 0.** The main loop sleeps
  61 s and drops `flo_params` on any tick before `create_graph_minute`.
  The price arrives in the first seconds of the hour. When the tick
  comes first, the LTN has no request to pair with the cleared path and
  the next run gets no previous plan, roughly one hour in twelve.
- **Held state goes inconsistent.** The fall-back hour of 2026-11-01
  left oak with a `BidRunner` and no `flo_params` for five hours, one
  log line a minute, no bid.
- **Stop cannot reach the waits.** `BidRunner.stop` sets an event the
  run loop never checks while blocked in `get_bid_event.wait()`, so
  systemd kills the unit after its timeout and the hour's bid is lost.
- **The LTN repeats bruce.** bruce's `recommend` builds, solves and
  answers in one call. Because the LTN cannot call it across two
  phases, it copies the loop (`_recommendation_on`) and bruce keeps an
  allow-list of the six fields that may change between phases.

With one call at the bid minute all five go, and the LTN's seam with
the FLO becomes the one the service wants: a `flo.params` out, a
`flo.recommendation` back, nothing of bruce's held in between. The
only state that survives an hour is the previous run, already a file.

The five-minute cadence points the same way. A run every five minutes
means the previous plan is five minutes old and nearly always lines up,
so the drift gates matter little. Running that often means caching the
back half of the graph and refreshing only the front with new forecasts,
and that cache is the FLO's to keep, inside the service, keyed however
bruce chooses. The LTN never sees a pickled graph again. Open: whether
the previous path stays the LTN's to hand back or becomes the FLO's own
memory per house, since the FLO is the one remembering the graph. That
question is decided before the FLO words leave staging.

Measured on the ltn box (c5.large, two CPUs) from oak's journal over
2026-10-31 to 11-02, 48-hour horizon, every hour within a second of
the same: the build is 14.2 s (8.7 s of that is child start-up before
the transition matrix loads; edges 4.0 s), bid generation 11.2 s, the
clearing-price plan 2.0 s, peak memory 498 MB. One call at the bid
minute is about 25 s, so :57 holds and the store is measured 3 minutes
before the slot. Prices arrived at :00:00.1 to :00:01.0 throughout and
bids finished by :58:10, so the minute-0 race did not fire in those 48
hours; it is a margin, not an observed loss. Two side findings from
the same read, neither an item: `LtnSettings.seasonal_storage_mode` is
read only by the log line at the store measurement and goes with the
collapse (the mode comes from the operating status); and the main loop
crashed once (2026-10-31 13:57) on a `Header` with `Dst: 's'`, on code
before the publish wrapper was reverted, a watch for the first deploy.

## Launch note

The LTNs need to run before we are on the production broker. The first
job is to test locally, and use that test to find the minimal updates
to the LTN that get it working. The design text is worked in-process
with the work itself: the local run says what the LTN needs, and that
is what gets written here.

The split is roughly: what do we need so that the reports are acked
and the LTNs do not crash. The LTNs do not have to work well with their
FLOs yet. Once the launch part is done, this file moves back over to
spruce-settled with whatever LTN work can wait until after launch.

The LTN and the scada always run from the same code at launch. When the
fleet starts publishing to the rabbit broker, the cloud-box LTN gets the
cert and the matching code. So a heartbeat version change on the scada
branch is not a wire break to build around: the LTN runs on the laptop
from the same branch against the dev rabbit broker, and there is nothing
to build now.

The cloud LTN will decode several versions of a word one day, the scada
never will. That decoder arrives when the LTN moves out of scada into
gridworks-base, not before.

## The two FLOs

- **bruce** (optimal-flexibility): one heat pump charging one
  stratified store, tuned by `flo.tuning.bruce`. Every House0 LTN house
  runs it with the fleet's knob values.
- **alice**: the stub, `flo.tuning.alice`, for a house held out of
  dispatch; answers with a bid of nothing. Spruce names alice with the
  operator hold until the Nolan scada has a working leaf ally.

A FLO for maple's resistive elements and wider COP range, and a FLO
that knows the Nolan plant's time-of-use windows, are future tunings or
future FLOs; each arrives as a tuning word and a `FloTuning` branch.

## What the LTN takes from the scada

Owned here once the two LTNs run, not before, because each question is
answered by what the running LTN actually reads:

- What each LTN needs that the layout and ops words do not state.
  `flo.params` is one word for every house; `flo.params.house0` and its
  twin retire with the LTN commit.
- The strategy selector and sieg-loop facts the LTN reads
  (`../spruce-unlimbo/control-strategy-selection.md` decision 4).
- Whether `layout.lite` is reshaped once more or replaced by the raw
  layout + ops words (`publish-layouts-and-operational-params.md`).
  The LTN reads `BufferShortCycling`, `TotalStoreTanks` and `Ha1Params`
  off it today; `AcceptsDispatch`, `ServiceMode` and
  `SeasonalStorageMode` come from `gw.house.operating.status`
  (`ltn/ltn.py:767-776`). After the LTN commit the curves, `HpMaxKwEl`
  and `HpTurnOnMinutes` come from the ops word on the LTN box and
  `Ha1Params` is read by nothing on the LTN.

**State machines are keyed by ShNode `Name`, not handle** (2026-10-22).
`layout.lite/013` lists the machines a running scada hosts in
`StateMachines`, one entry per hosting node, each with the node's `Name`
(`spaceheat.name`), its state enum and that enum's version. The report
side still names a machine by `MachineHandle`, the boss chain, which moves
when the tree changes (hp-boss went under the local control). A reader
resolves a handle to its declaration by the handle's last dotted segment,
which is the node's `Name`. A GNodeAlias plays no part: a scada's ShNodes
have none of their own.

## What the scada takes from the LTN

- **The weather forecast.** The LTN relays gwwf's `gw.weather.forecast`
  to its scada over the existing LTN→scada pipe, and the scada stops
  pulling weather itself (gwwf `executor/delivery.md` "LTN relay is
  primary"; the scada keeps the last-received forecast on disk as the
  same word and falls back to the gwwf API only when the relay goes
  quiet). Until the LTNs run, the scada's interim pull from gwwf is
  `executor/weather-forecast.md`.

## The FLO boundary

The direction is FLO as a service: the LTN hands the FLO its parameters
as one serialized sema message and gets a sema message back, so the FLO
can run in another process or on another machine with nothing shared
but the words. Work on the LTN is judged by whether it moves toward
that boundary.

td/bruce superseded `td/generalized-flo`; the boundary review of it is
the note to Thomas above, and the words close it.

## The heat pump's electrical bounds

Two FLO inputs describe the heat pump's electrical envelope.
`HpMaxKwEl`, the maximum electrical draw in kW, is a house fact: the ops
word states it once (9.66 at most houses, 10.0 at beech and maple), the
scada copies it into `ha1.params` for its own controllers, and the LTN
copies it into `flo.params`. Before 2026-10-14 the gwsproto default of
9.66 filled the FLO's copy at every house, so the FLO planned against
9.66 at beech and maple while the controllers used 10.0. `HpMinKwEl`,
the minimum draw while running (negative for metered offsets at the
lower bound), is a FLO tuning choice and lives in `flo.tuning.bruce`
with the storage-loss percent, the thermal caps, the penalty families
and the constant lift. That split, house fact in the ops word and
tuning knob in the tuning word, one name per fact, is what retires
`actors/ltn/flo_tuning.py` in the LTN commit.

## LTN code that scrapes where the layout answers

The LTN holds the full layout (`ltn_app.py:79`), so each of these is a
lookup:

- **House-available energy by channel-name scraping.**
  `get_house_available_kwh` (`ltn/ltn.py:1480-1512`) picks setpoint
  channels with `'zone' in x and 'set' in x`, derives the temperature
  channel by replacing `-set` with `-temp`, strips a six-character
  prefix, decodes every value with a fixed `/1000`, and skips `zone4` /
  `upstairs` by name. On a Nolan layout the replaced name matches no
  channel, so spruce contributes nothing; a temperature channel in
  another encoding is read wrong; and the skip is one house's special
  held in code. The lookup: each zone's primary circuit by
  `PrimaryCircuitPosition`, its `TempChannelName` and
  `SetpointChannelName` read through the channel registry, weighted by
  the zone's `KwhPerDegF`, with a zone that contributes nothing
  authored as `KwhPerDegF` 0. Test first: a Nolan layout with readings
  in their own encodings gives the right non-zero energy. The value
  feeds the FLO as `house_available_kwh`.
- **The dashboard's zone pattern.** `ltn/config.py:28-37` matches
  `^zone(\d)-(.*)-(temp|set|state)$` and
  `dashboard/channels/containers.py:107`, `:202` rebuild names from list
  order; the circuit's channel names give the same thing. Display only.
- **An orphaned setting.** `LtnSettings.seasonal_storage_mode`
  (`ltn/config.py:53`) is read only by a log line (`ltn.py:993`) that
  prints it in place of the value from the operating status.
- Nothing reads `Thermostat.ComponentId` or `ThermostatKind`
  (`thermostat-and-zone-control.md` "Thermostat chunk").
- **The fuel-substitution hard-code.** `LtnSettings.fuel_sub_usd_per_mwh`
  (`ltn/config.py:46`, default 490, "hack until we account for COP
  etc") is a tariff figure held in a setting: it was chosen to sit just
  above the on-peak delivery price the old hand-built forecast served,
  487.63 USD/MWh. The price forecast now serves the current Versant
  Rate A-1 total-delivery table (`wiki/regulatory/versant/tariffs.md`
  "Rate A-1": winter on-peak 612.10, shoulder 70.34, off-peak 64.26
  USD/MWh), so the threshold no longer means what it meant.
  `fuel_substitution` is off on every LTN, so nothing reads it today.
  Remove both settings and `use_oil_as_fuel_substitute`
  (`ltn/contract_handler.py:281`) rather than retune them; when fuel
  substitution returns it takes the tariff from the served forecast's
  `TariffAlias` and a COP-aware comparison, not a constant.


## Open

- A `slow.contract.heartbeat` persisted at version 001 fails to load
  under the 002 twin at every boot (beech's LTN and pi, oak's pi on
  2026-11-02): the load is skipped with a traceback and the box runs
  on. Delete the stale file at the roll, or let the loader drop a
  heartbeat it cannot read without the traceback.
- `gw.house.operating.status` always has a `StandbyPosture`, so a house
  with `Standby` false reports `NoHeatingOrCooling` and the reader has to
  know to ignore it. Consider making the posture optional, or an axiom
  that it is absent when `Standby` is false, so the status says only what
  is in force.
- The price bounds and the store's layer resolution are OPS-653.

Otherwise nothing. The FLO words (`flo.params`, `flo.recommendation`,
`flo.optimal.path`, the tunings) are published at 000 and own their
fields; the ops word stays staging and the LTN copies its `FloTuning`
into each request, so neither word waits on the other.
