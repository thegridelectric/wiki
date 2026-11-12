# LTNs ready

Status: Accepted · Pass 1 · Updated 2026-11-11 · Linear: OPS-654

**▶ Close-out (do this next).** The work shipped: the LTNs run on `main`
and bid through `hw1.flo`. The two open checklist items are done: the
ops-word drift check is in `wiki/tools/check-drift.sh` "House lines",
and the weather `GET /forecasts/{ForecastUid}` route is live. What is
left before the design is deleted and OPS-654 goes to Done (12.0 h):

1. Rewrite `../executor/flo-boundary.md` to `main`. Lines 21–37 still
   describe the in-process child, `_flo_worker`, `BRUCE_TAG` and the
   no-checkout box. On `main` the LTN asks `hw1.flo` over the broker
   (`actors/ltn/flo_service.py`, #605). Lines 83–87 (`BidRunner.stop`,
   the fallback when the optimizer is missing) are stale too, and
   `flo.refusal` handling is not described. No fallback-bid code turned
   up in `actors/ltn` on `main`, although the FLO glossary relies on one,
   so check it. The Tests table names `test_ltn.py` and
   `test_bid_runner.py`, which are gone; `main` has
   `test_ltn_flo_exchange.py`, `test_ltn_flo_recommendation.py`,
   `test_ltn_flo_refusal*.py` and `test_ltn_bid_lead.py`. Add the rule
   from "Why the FLO is one call": a feature that seems to need LTN state
   between calls puts it in the words or in the FLO.
2. `../executor/primary.md` lines 115–117 (bruce as a tagged dependency)
   and the cleanup item at 223–225 (OPS-514, done) are stale.
3. `../../flo/executor/bruce-flo.md`: under "The store", add that bruce
   maps each sensor-position thermocline onto the tuning's `NumLayers`
   as the same fraction of the modeled store, rounded to a layer
   (`optimal-flexibility` `src/bruce/service.py` `thermocline_layer`).
   Fix "Admissibility": axiom 7 has only clause a (bruce excludes
   `LwtControl` on House0), and no Nolan row exists.
4. In "LTN code that scrapes where the layout answers": delete the dead
   `get_house_available_kwh` (`ltn.py`, unused on `main`), and put the
   remaining `fuel_sub_usd_per_mwh` / `use_oil_as_fuel_substitute` /
   zone-name regex cleanup on the executor's "Cleanup epic" or a Linear
   issue. Raise the `StandbyPosture` item from "Open" as a sema Open.
5. Rewrite the references to this file before deleting it:
   `DESIGN_INDEX.md`, `gridworks-scada/changelog.md` ("One call and
   response"), and the spruce-unlimbo spokes `finalize-layout-lite-13`,
   `main-changes`, `first-data-catch` and `primary`, and
   `spruce-settled/primary.md`.

**EDD: yes** the verification is a live slot: the LTN bids at :57, the
price clears at :00, the scada takes the contract, and both boxes' logs
are clean through it; the first one ran on oak 2026-11-02 02:57 ET.

> What this is: the LTNs running against the new scada code and bidding
> through the bruce FLO, on `main` since PR #600 (2026-11-02). Written
> for Thomas and Olly: how the pieces fit, the recommended next step,
> the checklist of what changed, and what the LTN's seam with the FLO
> had to become to pass the bar for an application seam, sema words at
> every edge. The durable parts are in the LTN executor
> (`flo-boundary.md`) and this design goes when it closes.

## How to keep working on it

Everything below is as of `c7f893b9` on scada `main` and `v0.1.0+gw2` on
the bruce fork. Thomas wrote the optimizer and the transition-matrix
caching that makes a 48-hour graph solve in seconds on a two-CPU box;
the LTN side wraps it in one call. Read this section first, then "One
call and response" and "The FLO boundary" below.

The next step is FLO-as-a-service ([OPS-514](https://linear.app/gridworks/issue/OPS-514/flo-as-a-service)): the same `flo.params` goes to the `hw1.flo` service over the
broker and the same `flo.recommendation` comes back, and the LTN drops
the import. It is the natural step now for three reasons. The seam is
already the service's seam: one word out, one word back, no FLO state
held in the LTN between them, so the only thing that changes is the
transport of one callable. The service already exists: `gridworks-flo`
runs on the flo box, bound to the hw1 broker as its own principal. And
the measurement behind that design settled the
hosting questions: a build does not need to stay resident between runs,
and the matrix cache is the only thing a box keeps. The cutover is oak
on the service beside in-process for a day with the bids compared, then
the rest.

### The four facts

The contract itself is the LTN executor's `flo-boundary.md`. The four
things to hold onto while working:

1. **bruce runs editable from the sibling checkout**
   `../optimal-flexibility`, on the laptop as on a box (`tools/mkenv.sh`
   installs it by default). The one repo is `thdfw/optimal-flexibility`,
   MIT-licensed; a house's sibling on the ltn box tracks its `main` with
   no pin, `scripts/roll.sh` brings it to the pushed tip before the LTN
   restarts, and every recommendation records the commit that answered
   (`FloGitCommit`). The GridWorks fork is an archive of the two tags.
2. **bruce reads nothing from a `.env`.** The installed package has no
   repo root for its loader to find one in; the only environment it
   sees is the LTN process's, and the only variables it reads are the
   matrix controls and its log level.
3. **The LTN's FLO facts come from the layout pair** on the ltn box,
   the ops word and the layout, and the hold from the scada's operating
   status. What the LTN's own `.env` still supplies is plumbing, and a
   `LTN_MONITOR_ONLY` line there is dead.
4. **The boundary is one call**, `_flo_worker` in `actors/ltn/ltn.py`:
   `flo.params` bytes in, `bruce.service.recommend_bytes`,
   `flo.recommendation` bytes out, exit.

### Why the FLO is one call

td/bruce ran the FLO as three calls across the hour: build and solve at
about :05, pickle the trimmed graph, re-measure the store and bid at
:57, then a third call for the next hour's plans after the price. Each
piece of state held between the calls went wrong in the field on oak or
beech between 2026-10-31 and 11-02:

- The stability gates compared the store at :05 with what the previous
  plan expected at :00, 55 minutes apart, so the penalty read the wrong
  "now".
- The previous run was lost whenever the main loop's tick beat the
  price to the top of the hour, about one hour in twelve.
- The fall-back hour of 2026-11-01 left a `BidRunner` with no
  `flo_params` for five hours: slot arithmetic on local wall-clock
  hours, and a two-phase state that could not recover. The slot start
  is now whole hours of UTC seconds, with the fall-back and
  spring-forward instants as tests.
- `stop` could not reach a run blocked in a wait, so four restarts hit
  systemd's kill and two of them cost the hour's bid.
- The LTN copied bruce's own loop to drive the phases, and bruce kept an
  allow-list of which fields may change between them.

With one call at the bid minute all five went in one change, and the
LTN's seam became the one a FLO service wants: a word out, a word
back, nothing of bruce's held in between. The lesson for new work: when
a feature seems to need state held in the LTN between calls, put it in
the words or in the FLO instead. The timings and the full argument are
in "One call and response".

### The last hour

The one thing that does survive an hour is the previous run. After the
price clears, the LTN picks the cleared pair off the recommendation it
already holds, takes that pair's `flo.optimal.path` and saves it as
`previous_run.json` in the LTN's data dir. The next request attaches it as
`PreviousOptimalPath` when the path's first step ends at the request's
start; bruce lines the previous plan up from the path's second step,
because step 0 is the slot that cleared, and feeds it to the stability
penalty. The open question, decided before the FLO words leave staging:
whether the previous path stays the LTN's to hand back or becomes the
FLO's own memory per house once the FLO is a service that keeps the
graph.

### Running and testing

- Scada: `tools/mkenv.sh` builds the venv with bruce from the tag. From
  `gw_spaceheat/`, `pytest tests/actors/test_ltn.py` runs a round trip
  against bruce in the venv and skips when bruce is absent;
  `test_flo_request.py`, `test_ltn_clearing.py`, `test_bid_runner.py`
  and `test_market.py` cover the request, the clearing rule, the stop
  and the slot. `tests/named_types/test_flo_*.py` are the oracle tests
  for the words.
- bruce: in `optimal-flexibility`, `uv run pytest`;
  `tests/test_recommend.py` is the boundary, `tests/test_generate_bid.py`
  the sweep. The tests cache the nine-sensor, 120-gallon matrix on first
  run.
- The LTN on a box is the systemd unit `gwltn@<house>` on the `ltn` box;
  `ltn-logs <house>` tails it. Idle on a hold reads "Main loop idle:
  accepts_dispatch=False"; a run reads the FLO answer time and the pairs.
- A useful next piece of test infrastructure: the LTN, its scada and
  the FLO against a simulated plant in dev, where a slot runs in
  sped-up time and the contract's effect on the plant is measured. The
  simulated terminal assets in `gridworks-terminalasset` are the
  starting point; the live oak slot is the only end-to-end run so far.

### Where to take it next

**Do this next:** merge bruce's `jm/knit` onto `thdfw` main, then scada
`jm/bruce-sibling` onto `main`; rebuild oak's LTN venv once by hand
(`tools/mkenv.sh`, bruce editable from the sibling); `scripts/roll.sh
oak to main`; watch one slot: a `flo.params` 001 out at :57, the
`flo.recommendation` back on the scada broker beside it, the bid, the
clearing, both logs clean. Then OPS-657 journals both words.

The FLO box is yours to work on: the `flo-thomas` and `flo-olly` keys
open the `flo` login (`gridworks-infra/flo/instance-README.md` is the
box; `authority/ssh-access.md` the roster). The next steps are one
piece of work with two halves that fit together, and they are a good
thing to do as a pair:

1. **Launch FLO-as-a-service** ([OPS-514](https://linear.app/gridworks/issue/OPS-514/flo-as-a-service)). The service `gridworks-flo` already runs on the box, bound
   to the hw1 broker, answering `flo.params` with `flo.recommendation`.
   What remains is the LTN edge: the one callable's transport changes
   from the child process to a broker round trip, same timeout, same
   no-FLO fallback, and nothing else in the LTN moves. Then the cutover:
   oak on the service beside in-process for a day with the bids
   compared, then the rest. The one-call seam
   above is what makes this a one-seam change.
2. **Shrink the graph in memory** ([OPS-655](https://linear.app/gridworks/issue/OPS-655/graph-as-arrays)). bruce holds its graph as
   Python `Node` and `Edge` objects, about a kilobyte each: a three-tank
   house builds 1.56 M nodes and 2.96 M edges, 1.85 GB at peak and 43 s,
   to reach a sub-second solve. The graph is a dynamic program over a
   fixed state space, so the same answer comes from two arrays,
   `pathcost[t, state]` and `best_action[t, state]`, filled by a backward
   pass over the transition matrix and a per-step cost array: tens of
   megabytes, no node or edge objects, no pickled trimmed graph. That is
   the first and big win, roughly a 95 percent cut in peak memory. What
   is there today, what replaces it and the plan are on the issue and
   its design.

3. **Journal the LTN's words** (gridworks-journalkeeper). The ear
   writes every word the LTN speaks to the S3 eventstore, but the
   journal DB holds none of them: in the 30 hours to 2026-11-02 05:00 ET
   the messages table has `latest.price` from the market maker and five
   glitches from the LTN, and no `bid`, `flo.params`,
   `flo.optimal.path`, `flo.recommendation`, `slow.contract.heartbeat`
   or `slow.contract.rejection`. The journalkeeper persists a type only
   when it is in both its sema snapshot and one of the persistor's
   tables; `bid` is in the snapshot and in no table, the other five are
   in neither, and a type outside the set is skipped without a log
   line. The recipe is the journalkeeper executor's `captured-types.md`
   "Adding a type": seed the words in `src/gjk/sema_seed_request.yaml`,
   run `scripts/regen_sema_snapshot.sh`, add each type name to the right
   table in `sema_message_persistor.py`, and extend the seed test. The
   words with `CreatedMs` or `MessageCreatedMs` take the default path;
   `bid` has neither a created time nor an id, so it joins
   `BASIC_MSG_TYPES` and `RECEIPT_TIME_KEYED_TYPES` beside `atn.bid`
   until the word gets one, and `flo.optimal.path` has only
   `StartUnixS`. `flo.recommendation` is not on the wire today: the LTN
   holds it for the seconds between the FLO's answer and the bid. It
   reaches the bus as the service's reply once the FLO is `hw1.flo`, so
   seed it with the others now and the journal is ready for the first
   reply. A merged change reaches the gjk box by pull and restart
   (`gridworks-infra/gjk/instance-README.md`). The eventstore has the
   objects since the first slot, so the journal can be backfilled
   through the importer once the words are in.

### Changing bruce and shipping it

1. Branch on `thdfw/optimal-flexibility`, PR, merge to its `main`. bruce's
   own suite runs there; a change to the store shape rebuilds the
   transition matrix (minutes), and the box's bruce cache keeps one per
   shape.
2. `scripts/roll.sh <house> to main` fast-forwards the house's sibling to
   `origin/main` and restarts the LTN; `check` reports the sibling's
   commit beside the LTN's. A house whose venv still installs bruce from
   the retired tag gets one `tools/mkenv.sh` rebuild by hand first, and
   `roll_bruce` says so.
3. A scada change that bruce needs goes on a scada `jm/<topic>` branch as
   usual; the two repos share no pin, so merge the bruce side first when
   the LTN's request changes shape.

The store is modeled at the tuning's `NumLayers` (`flo.tuning.bruce`
001, fleet value 9), and `bruce.service` maps the sensor-position
thermoclines of `flo.params` onto those layers: the same fraction of the
whole modeled store, rounded to a layer. The layer count is the
optimizer's choice; the sensor count stays a house fact and the unit of
the thermoclines.

A change to a word at the boundary starts in sema, then the snapshots
regenerate: the scada's `scripts/regen_sema_snapshot.sh`, bruce's and
tlayouts'. The FLO words are published at 001 (`flo.params`,
`flo.tuning.bruce`) and 000 (the rest); the ops word is staging and
never crosses the production broker.

### Layouts and the roll

A house's layout and ops word are the committed JSON under
`tlayouts/output/<house>/` on the tlayouts branch named like the scada
branch; `main` scada reads tlayouts `main`, and any other branch off
`main` reads tlayouts `main` too. A box takes the pair from a pushed
tlayouts SHA and from nowhere else: no hand edits on a box, no scp of a
local file. To change a house's ops word, edit its gen
(`tlayouts/<house>_gen.py`), run it
(`../gridworks-scada/gw_spaceheat/venv/bin/python oak_gen.py` from
`tlayouts/`), commit the regenerated `output/<house>/` JSON to tlayouts
`main`, push, then roll. A gen run from a clean checkout emits the
committed file byte for byte; a difference is a defect.

`scripts/roll.sh` in the scada repo, run from the laptop, is the one way
code or a pair reaches a house. It moves the pi (and the second pi) and
the house's LTN together to a pushed SHA, verifies the layout and ops
word on every box against the committed tlayouts JSON, offers to
install the committed file where a box differs, and restarts the LTN,
then the scada. Trying a branch off `main` on oak, which keeps the
tlayouts `main` pair:

```
# on the laptop, from gridworks-scada/
git push origin jm/my-topic                  # a box moves only to a pushed SHA
scripts/roll.sh oak check                    # what oak, oak2 and the LTN run now
scripts/roll.sh oak to jm/my-topic           # both pis + LTN to the branch tip,
                                             #   pair verified (y installs), restart
scripts/roll.sh oak check                    # all three on jm/my-topic @ same SHA,
                                             #   pair matches tlayouts main
scripts/roll.sh oak forward                  # back to main when the trial is done
```

The weekly drift report shows the trial branch on oak until `forward`.
Never pull or restart on a box by hand: a pi that moves without its LTN
has every Report un-acked and its link flaps until they match again.
The how-to with the roll-back lines is scada executor `running.md`
"Rolling a house between lines".

## The checklist that went to main (PR #600, kept as the record)

td/bruce was current main plus Thomas's FLO commits re-applied on top;
it superseded td/generalized-flo and the paused merge worktree. The work
went on `jm/flo-tuning-ops`, a PR against it, squash-merged to main as
`c7f893b9` on 2026-11-02 with the two unchecked items below still open.
Each commit of ours has its scada changelog entry; Thomas's commits have
none, and the squash commit's entry is the branch as a whole.

**Completed**, each with its test

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
  PR 1 to Thomas). What the sweep fixed in the field: every bid of oak's
  first day on td/bruce (2026-10-31 to 11-01, read off the box log and
  the journal in `experiments/oaks-first-ltn/`) was one pair at the
  floor, because the deployed sweep dropped every quantity decrease.
  The forked sweep has run on oak since the roll.
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
  Squashed to main as `c7f893b9` (#600) with the two items below open.
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
**Still open**

- [ ] The weekly drift check reads the ops word's hash on the pi and the
  LTN as it reads the branch. roll.sh already moves the triple, code
  SHA, layout and operational params, to both boxes and verifies it on
  both (the 2026-11-02 rolls were checked that way); what the drift
  report lacks is the ops word. The need: oak's scada sat six commits
  behind its LTN on td/bruce after nine hand pulls on the ltn box
  since 2026-10-31, and the heartbeat-001 crash stretch was that split
  in action.
- [ ] On the weather service: a GET /forecasts/{ForecastUid} route, so a
  `WeatherForecastId` resolves to the values behind a run.

[OPS-514](https://linear.app/gridworks/issue/OPS-514/flo-as-a-service) owns the service side:
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
words. The LTN on td/bruce handed the build child bruce's own
`HeatPumpWaterTankParams` JSON, with no TypeName, and the bid child
returned a bare list of price-quantity dicts, so the FLO's answer had no
name and the market facts moved into LTN code. No machine runs that
path now; `main` runs the one call described above.

The two words that fix it are in sema (`flo.params`, `flo.recommendation`
with `flo.optimal.path`), and the two PRs against optimal-flexibility
are: PR 1, `generate_bid` sweeps from the price ceiling down and keeps
every quantity change (`jm/bid-descends-from-price-max`,
`tests/test_generate_bid.py`); PR 2, the vendored sema snapshot and
`bruce.service.recommend(request: FloParams) -> FloRecommendation` with
its bytes-in bytes-out twin `recommend_bytes`, which derives layers and
gallons from the tank facts, takes the bid bounds from the price bounds
and feeds `PreviousOptimalPath` into the stability penalty
(`jm/flo-as-service`, [OPS-514](https://linear.app/gridworks/issue/OPS-514/flo-as-a-service)). The pickle between the LTN's own phases
is unchanged and stays: it is one process's memory handed to its child.

### The contract, in the executor

The bright lines at the seam, the words at the boundary and where every
input comes from are now the LTN executor's `flo-boundary.md`; this
design keeps the history and the next steps.

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
  under the 002 twin at every boot (every LTN and pi rolled on
  2026-11-02): the load is skipped with a traceback and the box runs
  on. Delete the stale file at the roll, or let the loader drop a
  heartbeat it cannot read without the traceback.
- `gw.house.operating.status` always has a `StandbyPosture`, so a house
  with `Standby` false reports `NoHeatingOrCooling` and the reader has to
  know to ignore it. Consider making the posture optional, or an axiom
  that it is absent when `Standby` is false, so the status says only what
  is in force.
- The store's ceiling. On oak's first day the FLO would not buy at any
  price while the store sat above the heating curve's `MaxEwtF`
  (161 °F at oak); the analysis is in `experiments/oaks-first-ltn/`.
  Whether that ceiling is the FLO's to hold or the plant's to state is
  a boundary question, with the price bounds and the store's layer
  resolution in [OPS-653](https://linear.app/gridworks/issue/OPS-653/flo-request-bounds).

