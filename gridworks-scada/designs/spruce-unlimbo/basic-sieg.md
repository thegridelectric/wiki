# basic-sieg

Status: Accepted · Pass 1 · Updated 2026-09-25 · Linear: OPS-392

> What this is: a spoke of [`primary.md`](primary.md). The least that has
> to change in the Siegenthaler loop for maple and beech to take the
> branch. The running loop and its shortfalls are
> [`../../executor/sieg-loop.md`](../../executor/sieg-loop.md) ("the
> critique"; its defect numbers are used below). The loop runs one of
> three strategies, chosen by the ops word ("Three modes, one package"
> below): this spoke builds `HoldFullSend`, the mode with no loop control
> at all, and `StratProtect`, which is the running loop chipped, not
> rebuilt: its two state machines stay. `LwtControl` and the larger
> reshaping are
> [`../../explorations/sieg-loop-next.md`](../../explorations/sieg-loop-next.md),
> work for after launch. A launch item.

## What decides the list

The launch bar is service as good as what is in the field, in code the
next person can pick up. Three things have to be true on the branch: the
house is heated, the start-up job is done (no cold water into a hot
tank), and an operator can see and move the valve from the admin panel
without breaking the tree. Everything else in the critique waits.

## Three modes, one package

A House0 layout has a Siegenthaler loop or it is not a House0 layout
(`gw.house0.no.sieg` is the word for the others), so the `sieg-loop` node
and its actor are always present and relays 14 and 15 are always the
loop's. What varies is how the loop is driven, and that is operational:
one enum in the House0 family params replaces the `UseSiegLoop` boolean.

| `sieg.loop.strategy` | What the loop does | When |
| --- | --- | --- |
| `HoldFullSend` | Drives the valve to full send once the actuators are ready and then does nothing but answer commands. No inputs, no control state. The heat pump behaves as if there were no loop. | This spoke, first. The safe baseline, and the mode maple runs while the admin surface is tested. |
| `StratProtect` | Keeps the valve at keep while the heat pump is off or starting cold, opens it when the loop is hot, fails open. Today's two state machines, chipped by changes 6 to 8. | This spoke. What maple and beech run at launch. |
| `LwtControl` | Blend control of LWT while the heat pump runs, on top of the protection. Not a short file; the PID's home. | After launch (the explorations doc). The loader refuses it until it is built, and no deployed ops word names it before then. |

`ActuationAuthority.Standby` runs `HoldFullSend` whatever the field says,
since the power-less posture is full send; `MonitorOnly` runs the selected
strategy with actuation suppressed (change 7).

The code is one package, `actors/sieg_loop/`, in place of `sieg_loop.py`,
on the local-control loader pattern (`actors/local_control_loader.py`):

- `__init__.py`: `SiegLoop`, the actor the layout names. A facade that
  picks the strategy from the ops word once, at construction, and owns
  what every strategy shares: the command surface (change 2), the valve
  state report, the watchdog pat and the tick.
- `valve.py`: the only code that addresses relays 14 and 15. Today's valve
  state machine and its movement tasks, moved here as they are; the
  drive-to-a-stop primitive of the explorations doc replaces them after
  launch.
- `hold_full_send.py`: one call to the valve at the first tick after
  `ActuatorsReady`, then nothing.
- `strat_protect.py`: today's control state machine, `engage_brain` and
  `is_blind`, chipped as below.
- `lwt_control.py`: after launch.

`actors/__init__.py` keeps `from actors.sieg_loop import SiegLoop`, so the
layout's `ActorClass.SiegLoop` resolves as it does now. The
`use_sieg_loop` reads leave `scada.py`, `command_node.py`, `scada_data.py`,
`hydronic/house0.py` and `local_control/house0/standby.py`: the sub-tree,
the actuator-ready dependents and the state-machine subscription are
unconditional. HpBoss reads the strategy instead of the flag: `HoldFullSend`
closes relay 6 at once (today's sieg-less branch), `StratProtect` keeps
`PreparingToTurnOn` and `SiegLoopReady`. Standby's relay 14 energize goes;
the loop owns the relay in every mode.

## The changes, in build order

Each gets its test first, failing, on the simulated House0. The single
owner and the command surface come first so that an operator can hold and
move the valve; what the loop does at a start is watched by hand before
it is changed.

### 1. One owner for relays 14 and 15 (defect 5) ✅ built

`sieg-loop` is the immediate boss of relays 14 and 15 in every tree: the
two tree builders (`command_node.py:98`, `scada.py:1270`) hang the loop
under whichever node holds the tree and the relays under the loop, and
`fsm.event` axiom 2 refuses a command from any node but the relay's
immediate boss, so the ownership holds without a check in the loop. The
`sieg_valve_hold` calls at initialization in local control and both leaf
allies are gone; standby's relay 14 energize runs only when the ops word
does not use the loop and stays. Tests (`test_sieg_loop.py`): the relays
hang under the loop in the auto, admin and rebuilt trees; a boss-side
event to a loop relay fails the axiom; local control and the leaf ally
call none of the four loop methods at initialization.

### 2. The package, `HoldFullSend`, and the command surface (defect 6) ◐

In build order:

- ✅ The words (sema `5ca82f8`): `sieg.loop.strategy`, `SiegLoopStrategy`
  in place of `UseSiegLoop` on the family params, the layout word's
  `sieg-loop` parenthesis, the tlayouts snapshot and gens, the gwsproto
  twins; the loader refuses `LwtControl`.
- ✅ `clock.py` and its hook-up (scada `be2a860f`): `services.clock` on
  every actor, `ManualClock` injected through the app for tests.
- ✅ The package (scada `151bcfc0`): `actors/sieg_loop/` with the facade,
  `valve.py` holding the valve machine with its moves on the clock
  (keep-seconds settled from `now()` when the motor stops, one sleep per
  travel), `hold_full_send.py`, today's control logic moved whole into
  `strat_protect.py`, and `strategy.py` holding the selection (Standby
  runs `HoldFullSend`, `LwtControl` fails construction) and
  `SiegLoopReady`. The sieg-loop handle reports the valve state
  (`sieg.valve.state`, on change only); the control state no longer
  rides `single.machine.state`. Every `use_sieg_loop` read is gone.
  The per-model signatures module comes with change 6, not here; until
  then `strat_protect.py` keeps today's `MaxEwtF` test.
- ✅ The command surface on the facade (scada `010ec939`):
  `process_fsm_event` copied from five-v-boss, a live command remembered
  as the boss part of the handle and cleared on the 30 s tick when it
  changes, a commanded move a full run, moves ending at a stop firing
  the reset triggers, the full report under the commander's `TriggerId`,
  `ActorClass.SiegLoop` in the command-node table, the panel offering
  both moves mid-travel. Tests 6, 7, 12 and the command half of 13, on
  the clock seam. The `wallclock` marker and its `ci.sh` deselect come
  with the first travel test against the sim relays.
- A maple window on `HoldFullSend`: the valve driven to send at start,
  moved to keep and back from the panel, the heat pump starting through
  it with relay 6 closing at once. That is the admin test the hub is
  waiting on.

The package and the enum come first, with `HoldFullSend` as the first
strategy: it has no inputs, so the command surface is built and tested
against it before any control logic is touched, and the first maple
window runs it. Its whole behaviour: after `ActuatorsReady`, one move to
full send (today's `moving_to_full_send`: motor dormant, direction toward
send, motor active for the full range plus ten seconds); the valve state
reported through `single.machine.state`; then only commands.

The package also takes the clock the tests rest on, and there is one
clock in the scada: `gw_spaceheat/clock.py`, held by the scada's
services and reached by every actor through `self.services.clock`, never
as an attribute of its own, with the wall clock, the time coordinator's
timesteps and the suite's `ManualClock` as its three sources
(simulated-test-environment `sim-time.md` "The one clock"). The sieg
package is that design's migration step 2: all seventeen of the file's
clock reads and travel sleeps go through the clock, whole file, with the
valve travel computed from `now()` at relay transitions rather than
one-second sleep slices. A test moves the manual clock and a transition,
a dwell, the blind timer and a full travel each run in CI without
waiting. No other actor converts here.

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

### 3. The simulated House0 can see the heat pump (defect 13)

`hp-lwt` and `hp-ewt` go into the orange and willow layouts with the sim
plant driving them. The matching word edit is
[`layout-word-axioms.md`](layout-word-axioms.md) "The required lists",
and the sim side comes first in build order — that word edit refuses a
House0 layout without them, and changes 4 and 6 cannot be tested without
them either.

### 4. The sieg loop logs what it sees (DEBUG, out after the maple test-drives)

The loop reads `hp-lwt` and `hp-ewt` through `channel_temperature` and
the two power channels through `total_hp_pwr_w`, and is blind when the
lift or the power is `None` (`sieg_loop.py:222`, `:283`); beyond those
four it asks for nothing. When it does something surprising the log
shows the decision and not the picture it was made from. In the 2025
season temperatures were seen to come and go from the plant's
`latest_temperatures_f` with no record of which or why; the loop has the
same exposure and no record at all.

This change adds the picture, and nothing else. On every control pass,
and on every control and valve state transition, the loop logs one line
carrying every channel of the loop's neighbourhood that the layout
names, present or not: `hp-lwt`, `hp-ewt`, `sieg-hot`, `sieg-cold`,
`sieg-flow`, `sieg-send`, `primary-flow`, `hp-odu-pwr`, `hp-idu-pwr`,
`buffer-hot-pipe`, `buffer-cold-pipe`, `store-hot-pipe`, `dist-swt`,
`dist-rwt`, derived channels included: maple measures `sieg-send` and
`sieg-flow` and derives `primary-flow`, beech measures `primary-flow`
and `sieg-flow` and derives `sieg-send-flow`, so the three flows are on
the line at both houses with the derived one marked as derived. For
each: the value in the house's units, or `--` when the latest value is
`None`, and the age of the reading in seconds. The line ends with the
quantities the loop acts on, lift and total power, and with `blind` and
its reason when `is_blind` is true. A channel the layout does not name
is left off the line, not written as missing.

Once per pass is a line every few seconds while the heat pump runs,
which is the point: the record of a start is read as a strip, not
reconstructed from state changes. `ShNodeActor.log` writes at one level
(`sh_node_actor.py:289`), so the strip rides the proactor log; the line
is prefixed `sieg-view` so a grep pulls it out.

This is debug output for the spot checks, deliberately overly verbose,
and it is removed, tests included, once the maple test-drives of change
5 are done. It exists because of a memory from the first test-drives of
the loop: channel values vanished from the plant's latest values in a
way the picos did not explain, since they were plainly alive afterwards.
The strip is what catches that if it happens again; nothing is
switchable, and nothing is built on it.

Tests on the House0 sim, in `test_sieg_loop.py`: the line names every
channel the sim layout carries and no other; a channel flushed by a
`ChannelFlatlined` shows `--` on the next line and its value again once
a reading arrives; the blind reason on the line matches `is_blind`.

### 5. Watch the current loop open early, then open it by hand at maple

Before the start is changed, two looks at how the loop opens now, with
changes 1 to 4 on the branch.

- **The record of the early open.** The running loop opens at one line,
  `MaxEwtF` minus 20 against the hotter of LWT and EWT
  (`sieg_loop.py:229`), with no reference to where the water is going,
  and it also opens through `Blind` when the timer misfires (defects
  1 to 3). At maple's field `MaxEwtF` of 145 the line is 125 °F, so a
  buffer top above that gets cooler water at the open. The maple journal
  is read for starts where the open came under the destination top, and
  the destratification is measured as the buffer depth readings across
  the open. The result is a short table in `scratch/basic-sieg/`.
- **The admin experiment.** In a maple window, the loop held at keep from
  the panel through a start (change 2's `MoveToFullKeep`), the valve
  opened from the panel by hand when LWT reaches the destination top
  less 10 °F: at maple's closed-loop rise of about 7 °F a minute that is
  the 82 s of travel from park to send, the look-ahead change 6 encodes.
  LWT is not to pass 135 °F closed; the Ecodan stopped itself near
  146 °F. Read back from the `sieg-view` strip (change 4): the EWT rise
  in the first two minutes, which marks a closed loop at beech (more than
  6 °F, `startup-signatures.md` "Loop closed against loop open"); LWT at
  the open against the destination top; the dip and the lift jump as the
  cold water arrives; buffer depth readings across the open. One start
  held closed to the Ecodan's own stop, last and only if the window
  allows, gives the backup time and target cap of change 6.

The numbers of change 6 are set from this, not before it.

### 6. The start: stop opening through `Blind`, and wait to open (defects 1–3)

Before this is built: the round-1 response
(`scratch/basic-sieg/fable-r1-response.md`, each round-1 finding folded
here, moved to the explorations doc, or rejected with its reason; note the
correction that `hp-lwt` and `hp-ewt` are in maple's and beech's
`CaptureTuningList` and missing only from the simulated layouts) and
round 2 on a fresh thread. The control state's name once `is_blind` is
split (`FailedOpen` the placeholder, or `Blind` kept for launch) is
decided in that pass; nothing outside `strat_protect.py` reads it and the
control states have no sema enum.

These go in together. Fixing the blind timer alone, with `MaxEwtF` at the
170 in the branch's ops params, leaves maple's valve at keep with no heat
to the house.

- **The timer.** `hp_turned_off_time` is cleared on `HpTurnsOn`, so
  "drawing power long after an off command" means that again and an
  ordinary run no longer goes blind.
- **Waiting to open** replaces `hp_loop_is_getting_hot`. In `HpStartingUp`
  the valve parks at `t2` as it does now, and the loop opens it to full
  send when

  ```
  lwt + slope × seconds of travel left  ≥  target
  ```

  so the valve arrives at send about as LWT reaches the target. Travel
  left is the loop's own `keep_seconds`, 82 s from the park. The slope is
  the newest LWT reading against one at least 30 s old, °F/s, floored at
  zero, so a flat or falling LWT reduces the test to `lwt ≥ target`. That
  is the whole mechanism: a short history of LWT readings, a slope helper
  and one comparison. No blend position, flow table or target-LWT message
  comes with it. The look-ahead is what makes store charging safe: at
  beech's closed-loop rise of about 15 °F a minute a plain `lwt ≥ target`
  overshoots by about 20 °F across the travel, which reaches the LG's
  182 °F limit when the target is a hot store.
- **The target** is the temperature of where the water is going: the store
  top when the plant is charging the store, the buffer top otherwise.
  `House0Hydronic` answers that from its own charge/discharge state
  (`charge_discharge_relay_state`), as one accessor the loop calls, so the
  loop names no tank. `MaxEwtF` leaves the loop. The target is capped per
  heat pump model at what the heat pump can reach with slope to spare:
  140 °F for the Ecodan, whose one long closed start flattened near
  146 °F. A fact about the heat pump, in the scada's per-model
  signatures (below).
- **It fails open.** With the valve at keep the small loop heats fast, and
  a heat pump that reaches its upper limit stops itself. That is the worse
  risk, not destratifying: at beech the LG, after several quick trips to
  its limit, locked out with an error that took a visit to the basement to
  clear. So five layers stand behind one another, and every one resolves
  to full send, held for the rest of the run:

  1. The predictive open above.
  2. An input missing: power, LWT, EWT or the destination temperature has
     no value. [`sensor-freshness.md`](sensor-freshness.md) is what makes
     a sensor that stops reporting read as no value; without it a sensor
     that dies mid-start looks like a flat LWT, which the predictive test
     reads as "wait". The valve opens as soon as an
     input is missing, before the compressor starts if that is when it
     happens, with one warning glitch naming the channel.
  3. The first time the heat pump stops itself in `HpStartingUp`: full
     send at once, one warning glitch; the next compressor start sends its
     water to the tank. How fast a closed loop reaches the limit depends
     on the heat pump, which is why the trigger is the stop itself.
  4. A backup timer, per heat pump model, counted from power crossing the
     high threshold, in the per-model signatures beside the four
     thresholds below. The LG reaches its limit about six minutes into a
     loop-closed start, so about 240 s there. The Ecodan's closed-loop
     limit has not been seen; its value waits for the first maple window
     and starts cautious.
  5. `Standby`, a dead scada or lost power: the power-less posture is full
     send.

  "Stops itself" is read from power with two
  thresholds, since power wobbles as a heat pump comes on: it has been
  over a high one, where the compressor is unmistakably running, and then
  falls under a low one, where it has unmistakably stopped, while HpBoss
  still says on. Each threshold carries a dwell. The four numbers are
  characteristics of the heat pump model, not of how a house is operated,
  and a signature is behaviour more than it is numbers (the LG's
  circulator shows on `hp-idu-pwr` 70 s before its compressor; the
  Samsung pulses to 318 W idle), so they are code, not sema: a per-model
  signatures module in the scada, one typed record and its readers per
  model (`compressor_running`, `self_stopped`), written out straight,
  keyed on the `DeviceType` the layout already binds to `hp-odu`
  (maple `MitsubishiWUZSA48NMZ`, beech `LGARUM048GSS5`). Each model's
  record cites its section of
  [`startup-signatures.md`](../../executor/heat-pump-signatures/startup-signatures.md)
  "Running and stopped, from power", which stays the evidence; a test
  pins the code's values to the executor's. A `DeviceType` the module
  does not know fails `StratProtect` at construction, no default model;
  `HoldFullSend` needs no signature and still runs. No ops word and no
  sema word carries a heat pump fact. The thresholds are against
  `hp-odu-pwr`, the compressor's channel, which is what they were scored
  on; the loop stops reading the odu-plus-idu sum (`total_hp_pwr_w`),
  which at beech carries the LG's 342 W circulator and at a monobloc
  carries nothing.

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
  first trip at that rise rate; the self-stop layer is what stands
  between a missed test and the second trip.
- **`is_blind` splits into its two meanings**: `inputs_missing()`, layer 2
  above, and the heat pump over its high power threshold more than 120 s
  after an off command, which gets its own glitch. The line is the high
  threshold and not any power because a heat pump draws power while idle:
  the Samsung at spruce pulses to 318 W every five minutes with the
  compressor off (`../../executor/heat-pump-signatures/idle-signatures.md`),
  and the Ecodan and the LG have not been measured idle beyond standby.
  One control state still serves both, since both want full send.

### 7. `MonitorOnly` never actuates (defect 7)

The loop sends nothing to its relays while the authority is `MonitorOnly`,
commands included (nack). `Standby` keeps its full send.

### 8. A restart finds the valve (defects 4 and 6, the restart part)

The first act after `ActuatorsReady` is motor dormant, then a full-travel
move to the stop the control state wants, instead of assuming `FullyKeep`.
A restart with the heat pump off reaches keep within one travel; the
four-minute stall at maple (finding 15) goes with it.

## Sema work

Each new word follows the sema authoring protocol before any edit; names
are proposals until then.

- Enum `move.sieg.valve`: `MoveToFullSend`, `MoveToFullKeep`.
- Enum `sieg.valve.state` for the report: the valve machine's five names
  (`FullySend`, `FullyKeep`, `KeepingMore`, `KeepingLess`, `SteadyBlend`),
  published 2026-09-24 with `move.sieg.valve`; a reshape takes a new
  version. Every move ends in
  `SteadyBlend` today, a stop included: `ResetToFullySend` and
  `ResetToFullyKeep` are defined (`sieg_loop.py:120-121` on the branch) and
  never fired, so the stop states are reached only as the initial state.
  The panel's commands result in `FullySend` and `FullyKeep`, so a move
  that ends on a stop fires the matching reset trigger (`:450`, `:453`).
- `gw.house0.layout` 000 (staging): `hp-lwt`, `hp-ewt` required. Done.
- Enum `sieg.loop.strategy`: `HoldFullSend` (default), `StratProtect`,
  `LwtControl`. Staging, sema `5ca82f8`.
- `gw.house0.family.params` 000 (staging, in place): `SiegLoopStrategy`,
  a `$ref` to the enum, required, in place of `UseSiegLoop`. Done. The
  layout word carries the sieg-loop node unconditionally (axiom 3), so
  the loader no longer pairs a flag with the node; it refuses
  `LwtControl` until that strategy is built.
- `gw.house0.layout` 000 (staging, in place): axiom 3's parenthesis on
  `sieg-loop` no longer says "dormant when unused": the loop runs a
  strategy in every mode. Done.
- No heat pump fact enters sema: the start thresholds, dwells, backup
  time and target cap of change 6 are scada code keyed on the layout's
  heat pump `DeviceType`.
- gwsproto twins for the enum and the family params; `use_sieg_loop`
  leaves the scada as "Three modes, one package" says.

## Before a maple or beech window

- The branch's ops params give maple `HeatingCurve.MaxEwtF` 170; maple's
  running scada reports 145. That is a heating-curve change riding along
  unasked. `tlayouts` takes the field value for maple, and beech's is
  checked the same way.
- Beech gets a `sieg-hot` sensor; its layout names the channel before the
  window, so the strip and the kept-fraction `r` have it.

## Tests (`tests/actors/test_sieg_loop.py`)

Two tiers, both in the suite, neither commented out. The transition,
command and report tests run on the clock seam with readings fed in and
sends captured, no plant and no wall time, and they run in CI: they
check that the machine does what this spoke says for a given picture,
which is necessary and not sufficient. The tests whose point is real
time against the sim relays (a full travel end to end, a dwell with the
real tick) carry `@pytest.mark.wallclock`, which `ci.sh` deselects; they
are the pre-window gate, run by hand before every maple or beech window.
Nothing closed-loop is claimed by either tier: whether the valve opens
before the LG trips or the predictive open lands near the target is the
plant's and the field's to show (Verification below).

1. A second run after a stop does not go blind (the timer).
2. Power up with a cold loop: the valve stays parked. LWT rising toward
   the target: the move to send starts on the tick where
   `lwt + slope × travel left` first reaches the target, for a buffer
   target and for a store target. Flat LWT under the target: no move; flat
   LWT over it: the move.
3. Power over the high threshold, then under the low one with HpBoss
   still on: full send at once, one glitch, and the valve stays at send
   through the next rise in power. Power wobbling between the two
   thresholds on the way up: no move. Flat LWT with steady power for the
   model's backup time: full send.
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
13. `HoldFullSend`: one move to send after `ActuatorsReady` and no relay
    command after it through a start, a stop and a defrost; an admin
    `MoveToFullKeep` acked, moved and held across ticks; `Standby` with
    `StratProtect` in the params runs `HoldFullSend`; `LwtControl` in the
    params fails construction.
14. Each of power, LWT, EWT and the destination temperature in turn stops
    reporting during `HpStartingUp` (the sim driver goes silent, the last
    value stays in `latest_channel_values`): full send once the channel
    flatlines, one glitch naming it. The same with the channel absent from
    the start.
15. The signatures module: each known model's thresholds equal the values
    the executor states; a layout whose `hp-odu` carries an unknown
    `DeviceType` fails `StratProtect` at construction and runs
    `HoldFullSend`; the loop's power read is `hp-odu-pwr` with `hp-idu-pwr`
    at 342 W and steady.

## Verification (EDD)

A bounded window at maple, then beech, on the branch: a restart with the
heat pump off reaches full keep, confirmed by the flows (`sieg-send` to
zero and `sieg-flow` up, as in finding 14); admin moves the valve to send
and back from the panel; on a heat pump start the control state passes
through `HpStartingUp` to `HpHasLift`, never `Blind`, and LWT at the move
to send is near the target, not 70 F; a stop closes the loop within one
travel.

Before that, the maple window of change 5.

Two things are tracked through that window and through every maple window,
from channels maple already reports:

- `sieg-hot` minus `hp-lwt`. `sieg-hot` is the same water as LWT further
  down the pipe, with no branch between. During a fast rise the difference
  is the transit lag (at 7 °F a minute, 30 s of pipe is about 3.5 °F); in
  steady running it is pipe loss plus the offset between two measurement
  chains, the ADS for `hp-lwt` and the `sieg-btu` pico for `sieg-hot`.
- The kept fraction from temperature. `sieg-hot` and `sieg-cold` are the
  two inlets of the merging tee and `hp-ewt` is its outlet one pipe run
  later, so `r = (ewt - sieg_cold) / (sieg_hot - sieg_cold)` is the share
  of the heat pump's flow that the valve keeps. It is set beside
  `sieg-flow / primary-flow`. The flow ratio reads 0.83–0.94 at beech with
  the valve at keep, and a `sieg-flow` reading 399 s old once passed for a
  full keep at maple; `r` says whether a keep that reads under 1 is a real
  bypass or two meters disagreeing. It means something only while the
  inlets differ by more than a few degrees, which a start provides.

**The strip, at maple and at beech.** Each heat pump start in the windows
above is read back from the `sieg-view` lines, so the number of runs is
the number of starts the windows give: at least three at each house,
cold and warm. For each start the strip is checked for readings that
vanish or return mid-run, for readings whose age climbs past a capture
period while the pico or meter is otherwise alive, and for a `blind`
that has no cause on the same line. Every such event is traced in the
same log and the report events: a `PicoMissing`, a channel absent from a
live pico's posts, or a value that stopped without either. The result is
a short table per house of channel, event, cause, kept beside the
full-keep traces in `scratch/basic-sieg/`; an event with no cause is the
open question this record exists to raise.

## Left as it is for launch

Defects 8–12 of the critique: the posture split inside `HpOff`, the
every-tick resend, relay outcomes ignored, moves without an owner, the
polled handle change, the blend leftovers and the state names. HpBoss's
`PreparingToTurnOn` and `SiegLoopReady` stay for `StratProtect`: with the
valve resting at keep the loop answers at once and the start is not
delayed; `HoldFullSend` never enters `PreparingToTurnOn`. Off is still
what HpBoss reports, so a defrost does not move the valve. The power-less
posture is full send, and the buffer mixing it allows at maple is
accepted.

## Not assumed

A fall layout has a Siegenthaler loop with no buffer tank and no iso
valve. The loop reads heat pump power, LWT, EWT, its two relays and the
one destination temperature its hydronic tier hands it; it names no
buffer, iso valve or store tank. All of these are required inputs of
`StratProtect`, and any of them may stop reporting: the loop then opens
the valve (change 6, layer 2) and does not guess. `HoldFullSend` reads
none of them.

## Open

- What the Ecodan and the LG do idle beyond standby draw. The Samsung
  pulses to 318 W and runs its water pump with the compressor off; the
  "drawing power after an off command" line of change 6 and the `HpHasLift`
  entry both rest on the House0 heat pumps not doing the same at a level
  the thresholds see.
- Whether the target carries a margin, and whether the move to send is one
  travel or paced: a first part to the reckoned moment and a gradual
  finish over about 30 s more is the other sketch.

## Do this next

The maple window on `HoldFullSend` (change 2's last sub-step): maple's
ops word set to `HoldFullSend`, the valve driven to send at start, moved
to keep and back from the panel, the heat pump starting through it with
relay 6 closing at once. "Before a maple or beech window" first.
