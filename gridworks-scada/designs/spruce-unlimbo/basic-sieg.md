# basic-sieg

Status: Draft · Pass 0 · Updated 2026-09-21 · Linear: OPS-392

> What this is: a spoke of [`primary.md`](primary.md). The least that has
> to change in the Siegenthaler loop for maple and beech to take the
> branch. The running loop and its shortfalls are
> [`../../executor/sieg-loop.md`](../../executor/sieg-loop.md) ("the
> critique"; its defect numbers are used below). The loop is chipped here,
> not rebuilt: its two state machines stay, and the larger reshaping is
> [`../../explorations/sieg-loop-next.md`](../../explorations/sieg-loop-next.md),
> work for after launch. A launch item.

## What decides the list

The launch bar is service as good as what is in the field, in code the
next person can pick up. Three things have to be true on the branch: the
house is heated, the start-up job is done (no cold water into a hot
tank), and an operator can see and move the valve from the admin panel
without breaking the tree. Everything else in the critique waits.

## The changes, most wanted first

Each gets its test first, failing, on the simulated House0.

### 1. The start: stop opening through `Blind`, and wait to open (defects 1–3)

These go in together. Fixing the blind timer alone, with `MaxEwtF` at the
170 in the branch's ops params, leaves maple's valve at keep with no heat
to the house.

- **The timer.** `hp_turned_off_time` is cleared on `HpTurnsOn`, so
  "drawing power long after an off command" means that again and an
  ordinary run no longer goes blind.
- **Waiting to open** replaces `hp_loop_is_getting_hot`. In `HpStartingUp`
  the valve parks at `t2` as it does now. The loop keeps recent LWT
  readings and a slope (the newest reading against one at least 10 s old,
  °F/s), and starts to open when

  ```
  (target - lwt) / slope  -  seconds of travel left to full send  <  3
  ```

  so the valve arrives at send about as LWT reaches the target. A flat or
  falling slope waits. The slope helpers and the test are lifted from the
  start-up hover on `origin/td/sieg-pid` (`sieg_loop/pid.py:263-400`), the
  2025–26 loop's logic against the 100 s range, with the computed blend
  position replaced by full send, so the flow-against-time table and
  `calc_eq_flow_percent` do not come along.
- **The target** is the temperature of where the water is going: the store
  top when the plant is charging the store, the buffer top otherwise.
  `House0Hydronic` answers that from its own charge/discharge state
  (`charge_discharge_relay_state`), as one accessor the loop calls, so the
  loop names no tank. `MaxEwtF` leaves the loop.
- **Open anyway.** With the valve at keep the small loop heats fast, and a
  heat pump that reaches its upper limit stops itself. That is the worse
  risk, not destratifying: at beech the LG, after several quick trips to
  its limit, locked out with an error that took a visit to the basement to
  clear. So the first time the heat pump stops itself in `HpStartingUp`,
  the loop goes to full send at once, with one warning glitch, and
  stays there for the run; the next compressor start sends its water to
  the tank. How fast a closed loop reaches the limit depends on the heat
  pump, which is why the trigger is the stop itself and not a time. A
  backup timer, `SIEG_OPEN_ANYWAY_S` = 900 s of drawing power without the
  test passing, does the same (the timer becomes per heat pump model; see
  "Do this next"). "Stops itself" is read from power with two
  thresholds, since power wobbles as a heat pump comes on: it has been
  over a high one, where the compressor is unmistakably running, and then
  falls under a low one, where it has unmistakably stopped, while HpBoss
  still says on. Each threshold carries a dwell. The four numbers are per
  heat pump model and sit in the House0 family params with the other
  thresholds:

  | | High | held | Low | held | Tested on |
  | --- | --- | --- | --- | --- | --- |
  | Mitsubishi Ecodan (maple) | 1500 W | 30 s | 500 W | 30 s | 291 starts, 2026-03-20 on: no false fire, closest recovering dip 1200 W; 22 of 28 self-stops caught, the misses under a minute long |
  | LG (beech) | 2000 W | 30 s | 350 W | 60 s | 1,321 commanded-on runs over two seasons: every compressor stop fell to 288 W or less, no run that kept going fell under 433 W after 2000 W; shortest stop 92 s |

  A single 500 W line is unsafe at both: a maple start crossed 1000 W and
  fell to 1 W on its way up, and four beech runs dipped under 500 W
  without stopping. A defrost fires the rule at both houses (64 of 67 at
  maple), since on power it is a self-stop; inside `HpStartingUp` that
  errs toward warmth and is accepted. Neither heat pump has been measured
  this way in a winter month with the loop held closed, and `hp-odu-pwr`
  reports on a 300 W change, so dwells under a minute rest on thin data.
  The pulls and scoring are in `scratch/basic-sieg/ecodan-start/` and
  `scratch/basic-sieg/lg-start/`.
- **Why one trip is the trigger.** At beech in spring 2025, with the loop
  closed (`sieg-flow` 3–4 gpm), LWT rose 13–18 °F a minute from the
  compressor reaching 2 kW and the LG tripped at 182–188 °F LWT about six
  minutes in, then again every ten to twelve minutes. Two evenings
  (2025-04-21 and 2025-05-01) ran seven trips each and the LG then made no
  power for 15 and 45 hours, through later on commands; read as the
  lockout, since the journal carries no LG fault code. Four other
  episodes of three to six trips recovered when the valve opened. The
  waiting-to-open test should open the valve some minutes before the
  first trip at that rise rate; the open-anyway rule is what stands
  between a missed test and the second trip.
- `Blind` otherwise stays as it is, full send.

### 2. One owner for relays 14 and 15 (defect 5)

The `sieg_valve_hold` and relay 14 sends in local control
(`local_control/house0/tou_base.py:366`), both leaf allies
(`leaf_ally/house0/all_tanks.py:509`, `buffer_only.py:397`) and standby
(`local_control/house0/standby.py:122`) go; the loop parks its own motor
relay on `ActuatorsReady`. A test runs a simulated day and asserts no
`fsm.event` to relay 14 or 15 has a `FromHandle` other than the loop's.

### 3. The command surface, so admin works (defect 6)

`sieg-loop` joins hp-boss and five-v-boss as a command node
(`../../executor/control-hierarchy.md` "Command interfaces and replies"),
copying `five_v_boss.py`, not `hp_boss.py`:

- `ActorClass.SiegLoop` in `Scada.COMMAND_NODE_CLASSES`, one vocabulary in
  `Scada.COMMAND_NODE_INTERFACES`: `MoveToFullSend` → `FullySend`,
  `MoveToFullKeep` → `FullyKeep`.
- `process_fsm_event`: the two authority checks; `EventType` and
  `EventName` both validated, else nack `UnknownEvent`; ack; the
  commander's `TriggerId` kept and the loop's `fsm.full.report` sent to the
  scada under it when the move ends.
- A command takes the loop out of automatic control until the tree changes
  hands. The loop remembers the boss part of its handle at the command and
  resumes when that changes, noticed on its 30 s tick. No release message.
- A command to the stop the valve is already on runs the full travel
  again; that is how an operator re-homes the valve.
- The valve machine's report is switched back on, on change only, through
  `single.machine.state`.
- The tree needs no change: `sieg-loop` already sits under the boss, admin
  included, with its relays beneath it. The panel commands `sieg-loop` and
  has no business addressing relays 14 and 15.
- The panel offers one command per vocabulary, the first whose resulting
  state differs from the observed one
  (`packages/gridworks-admin/src/gwadmin/watch/widgets/relay_widget_info.py:80-88`),
  so with the valve moving it offers the wrong one. For a vocabulary where
  the observed state is no command's resulting state, the panel offers
  every command.

### 4. `MonitorOnly` never actuates (defect 7)

The loop sends nothing to its relays while the authority is `MonitorOnly`,
commands included (nack). `Standby` keeps its full send.

### 5. A restart finds the valve (defects 4 and 6, the restart part)

The first act after `ActuatorsReady` is motor dormant, then a full-travel
move to the stop the control state wants, instead of assuming `FullyKeep`.
A restart with the heat pump off reaches keep within one travel; the
four-minute stall at maple (finding 15) goes with it.

### 6. The simulated House0 can see the heat pump (defect 13)

`hp-lwt` and `hp-ewt` go into the orange and willow layouts with the sim
plant driving them, and into the House0 word's required sensing
([`layout-word-axioms.md`](layout-word-axioms.md) axiom 3). This comes
first in build order, since 1 cannot be tested without it.

## Sema work

Each new word follows the sema authoring protocol before any edit; names
are proposals until then.

- Enum `move.sieg.valve`: `MoveToFullSend`, `MoveToFullKeep`.
- Enum `sieg.valve.state` for the report: the valve machine's five names
  (`FullySend`, `FullyKeep`, `KeepingMore`, `KeepingLess`, `SteadyBlend`),
  staging, so the rebuild can reshape it in place. Every move ends in
  `SteadyBlend` today, a stop included: `ResetToFullySend` and
  `ResetToFullyKeep` are defined (`sieg_loop.py:120-121` on the branch) and
  never fired, so the stop states are reached only as the initial state.
  The panel's commands result in `FullySend` and `FullyKeep`, so a move
  that ends on a stop fires the matching reset trigger (`:450`, `:453`).
- `gw.house0.layout` 000 (staging): `hp-lwt`, `hp-ewt` required.
- `UseSiegLoop` stays where it is.

## Before a maple or beech window

- The branch's ops params give maple `HeatingCurve.MaxEwtF` 170; maple's
  running scada reports 145. That is a heating-curve change riding along
  unasked. `tlayouts` takes the field value for maple, and beech's is
  checked the same way.

## Tests (`tests/actors/test_sieg_loop.py`)

1. A second run after a stop does not go blind (the timer).
2. Power up with a cold loop: the valve stays parked. LWT rising toward
   the target: the move to send starts within 3 s of the reckoned moment,
   for a buffer target and for a store target.
3. Power over the high threshold, then under the low one with HpBoss
   still on: full send at once, one glitch, and the valve stays at send through the next rise in
   power. Power wobbling between the two thresholds on the way up: no
   move. Flat LWT with steady power for `SIEG_OPEN_ANYWAY_S`: full send.
4. A stop: full keep.
5. No sender but the loop addresses relay 14 or 15.
6. Admin `MoveToFullSend` while the loop wants keep: acked, moved, held
   across ticks; after the tree returns to local control the loop goes
   back to keep. A mis-sendered and a stale-handle command move nothing. A
   wrong `EventType` is nacked.
7. The full report for a command carries the commander's `TriggerId`.
8. One valve report per state change and none between.
9. `MonitorOnly`: no relay command through a start, a stop and an admin
   command.
10. Restart with the heat pump off: motor dormant, then keep within one
    travel.
11. The House0 pairs of `tests/actors/test_hp_boss_live.py` (`PAIRS`:
    `house0-willow`, `house0-orange`) uncommented: admin's TurnOn parks
    hp-boss in `PreparingToTurnOn` until the loop on the sim plant sends
    `SiegLoopReady`. With it, gap 1 of `../spruce-settled/relay-tests.md`:
    no ready message arrives and `TURN_ON_ANYWAY_S`, shortened through
    settings, closes the relay anyway.
12. The capability cover lists `sieg-loop` with its two events; the panel
    offers both while the valve moves.

## Verification (EDD)

A bounded window at maple, then beech, on the branch: a restart with the
heat pump off reaches full keep, confirmed by the flows (`sieg-send` to
zero and `sieg-flow` up, as in finding 14); admin moves the valve to send
and back from the panel; on a heat pump start the control state passes
through `HpStartingUp` to `HpHasLift`, never `Blind`, and LWT at the move
to send is near the target, not 70 F; a stop closes the loop within one
travel.

## Left as it is for launch

Defects 8–12 of the critique: the posture split inside `HpOff`, the
every-tick resend, relay outcomes ignored, moves without an owner, the
polled handle change, the blend leftovers and the state names. HpBoss's
`PreparingToTurnOn` and `SiegLoopReady` stay: with the valve resting at
keep the loop answers at once and the start is not delayed. Off is still
what HpBoss reports, so a defrost does not move the valve. The power-less
posture is full send, and the buffer mixing it allows at maple is
accepted.

## Not assumed

A fall layout has a Siegenthaler loop with no buffer tank and no iso
valve. The loop reads heat pump power, LWT, EWT, its two relays and the
one destination temperature its hydronic tier hands it; it names no
buffer, iso valve or store tank.

## Open

- Whether the target carries a margin, and whether the move to send is one
  travel or paced: a first part to the reckoned moment and a gradual
  finish over about 30 s more is the other sketch.

## Do this next

Rewrite change 1 in one pass, then take it to review.

1. Change 1 as the lean predictive open, replacing the lifted hover block
   described above: in `HpStartingUp`, parked at `t2`, open when
   `lwt + slope × seconds of travel left ≥ target` (a slope helper and one
   comparison; no flow table, no `calc_eq_flow_percent`, no target LWT
   message). At beech's closed-loop rise of about 15 °F a minute a plain
   "LWT over target" test overshoots by about 22 °F across the 90 s of
   travel, which reaches the LG's 182 °F limit when the target is a hot
   store; the look-ahead is what makes store charging safe.
2. State the failsafe as five layers, every one resolving to full send
   until the valve has opened: the predictive open; inputs missing or
   stale (power, LWT, EWT, or the destination temperature the hydronic
   tier hands over) opens at compressor start; the first self-stop by the
   two-threshold rule; the backup timer; `Standby`, scada dead, power
   lost. The backup timer is per heat pump model, a fifth number beside
   the four thresholds in the House0 family params, counted from the
   compressor crossing the high threshold: the LG reaches its limit about
   six minutes into a loop-closed start, so about 240 s there; the
   Ecodan's closed-loop limit has not been seen, so its value waits for
   the first maple window and starts cautious.
3. Dig into one number before relying on it. The loop-closed median trace
   at beech (19 starts, spring 2025) shows the LWT rise falling to zero
   about five minutes in, at a median 164 °F, below the 182–188 °F trip.
   That may be an artifact: six of the 19 tripped inside the window and
   were censored from the median at that point, the rest may have had
   the valve nudged open, and LWT there is quantised at 0.9 °F. Plot the
   19 individually (`scratch/basic-sieg/closed-vs-open/`, `starts2_*.json`
   and `report.txt`) with `sieg-flow` and relay 14 beside LWT. It matters
   because a target above a real plateau would meet a flat slope, which
   the predictive test reads as "wait". The figure is left out of
   `executor/startup-signatures.md` until settled.
4. The destination temperatures are required inputs: say so under "Not
   assumed" and in the tests, and check that the House0 word's required
   sensing names the buffer top and store top sensors.
5. Split `is_blind` into its two meanings: `inputs_missing()`, and the
   heat pump drawing power more than 120 s after an off command, which
   gets its own glitch. One state still serves both, since both want full
   send. Its name is undecided: renamed for what the valve is doing
   (`FailedOpen` is the placeholder), or left as `Blind` for launch.
   Nothing outside `sieg_loop.py` reads it and the control states have no
   sema enum.
6. Write `scratch/basic-sieg/fable-r1-response.md` (each round-1 finding
   folded here, moved to the explorations doc, or rejected with its
   reason; note the correction that `hp-lwt` and `hp-ewt` are in maple's
   and beech's `CaptureTuningList` and missing only from the simulated
   layouts), and run round 2 on a fresh thread against this spoke, with
   the executor critique as a contract to read and the maple and beech
   journal facts in the focus. The human pass follows approval or the
   four-round cap.
