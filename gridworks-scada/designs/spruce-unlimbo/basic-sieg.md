# basic-sieg

Status: Accepted · Pass 1 · Updated 2026-09-25 · Linear: OPS-392

> What this is: a spoke of [`primary.md`](primary.md). The least that has
> to change in the Siegenthaler loop for maple and beech to take the
> branch. The running loop and its shortfalls are
> [`../../executor/sieg-loop.md`](../../executor/sieg-loop.md) ("the
> critique"; its defect numbers are used below). The loop runs one of
> three strategies, chosen by the ops word (the executor's "The package
> on the branch"): this spoke builds `HoldFullSend`, the mode with no loop control
> at all, and `StratProtect`, which is the running loop chipped, not
> rebuilt: its two state machines stay. `LwtControl` and the larger
> reshaping are
> [`../../explorations/sieg-loop-next.md`](../../explorations/sieg-loop-next.md),
> work for after launch. A launch item.

## The changes, in build order

Each gets its test first, failing, on the simulated House0. What the loop
does at a start is watched by hand before it is changed.

### 4. The sieg loop logs what it sees (DEBUG, out after the maple test-drives) ✅ built

On every control pass and every control or valve transition the loop
logs one `sieg-view` line: the valve state, each channel of its
neighbourhood the layout names (`VIEW_CHANNELS` in
`actors/sieg_loop/__init__.py`, derived ones marked `*`) with its value
or `--` and its age, then lift, total power and any blind reason. Read
as a strip, it catches readings that vanish while their picos are
alive. Debug output, removed with its tests in `test_sieg_loop.py` once
the maple test-drives of change 5 are done.

### 4a. scada2 re-sends its readings when its link to the scada goes active

The loop reads `hp-lwt` and `hp-ewt` from the second pi. scada2's
analog-temp actor reports a channel once at its first reading, then on a
change past the channel's async delta or at its capture period, 300 s
(`actors/multipurpose_sensor.py` `should_report_telemetry_reading`). The
readings travel as `SyncedReadings` at QoS 0 with no ack
(`actors/secondary_scada.py` `_publish_to_local`), so a report the scada
is not ready for is gone. When the scada restarts while scada2 keeps
running, or the link between them bounces, the scada has no LWT or EWT
until the water moves past the delta or the next capture: up to five
minutes, and a heat pump start in those minutes runs `StratProtect`
blind. At maple on 2026-09-25 both booted within 300 ms, the scada's
link went active 0.7 s after boot and bounced once 5 s later, and the
first `hp-lwt` arrived exactly 300 s after boot: scada2's first report
went out and the scada did not take it in.
Production meets the same gap each time the scada's restart timer fires.

The fix is on scada2: `SecondaryScada` keeps the latest reading of each
channel it has forwarded, and every time its local link to the scada
goes active, the first time and after each bounce, it publishes them
again with their original read times, so the scada sees their true age.
No ack is added: this path flaps, and a re-send on each activation
covers what an ack would.

Test first (`tests/`, the scada2 suite): scada2 running with readings
forwarded, the scada's link dropped and re-established, the scada holds
every scada2 channel within a second of the link going active, with the
original read times; without the fix the test waits a capture period
and fails.

### 4b. The relay actor reports its energization as a channel reading

On `dev` the Krida multiplexer sent each relay's `RelayState` channel, 1
energized and 0 de-energized: a `SingleReading` on every actuation and a
`SyncedReadings` of all relays each loop
(`actors/i2c_relay_multiplexer.py` on `origin/dev`,
`_dispatch_relay_pin` and `maintain_relay_states`), beside the relay
actor's `SingleMachineState` carrying what the state means. When the
multiplexer went (`1a7a41d1`) the per-relay actor took the state machine
and not the reading: `send_state` (`actors/relay.py`) sends only
`SingleMachineState`, and `my_channel()` is unused. The layouts still
declare the channels, so every relay reads no value on the strip and in
the journal's readings tables, the loop's `hp-loop-on-off-relay` and
`hp-loop-keep-send-relay` included (the 2026-09-25 maple window).

The fix is in the relay actor: wherever it sends `SingleMachineState`
it also sends a `SingleReading` on `my_channel()` from the confirmed pin
level, 1 energized and 0 de-energized: the boot report after adoption,
each confirmed command, each 5-minute verify pass. An Unknown state
sends neither.

Test first (`tests/actors/test_relay_i2c_house0.py`): the primary scada
receives the `RelayState` reading at boot and after a command, with the
value matching the pin; it fails on the branch today.

### 4c. TODO: `sieg-send-flow` never reports at maple

In the 2026-09-25 maple window `sieg-send-flow` had no value for the
whole run, so `primary-flow`, which maple derives from it and
`sieg-flow`, was never derived either. Without them the flows cannot
confirm the valve at keep (`sieg-send-flow` to zero, `sieg-flow` up) or at
send. Find where the reading stops: the pico or meter that captures it,
its channel in the window layout, or the derivation.

### 4d. Minor sema and admin change

- `gw.command.interface` 001 (000 is published): a per-vocabulary flag
  saying the node takes a command while its observed state is no
  command's result, set for the sieg loop's `move.sieg.valve` and false
  elsewhere. Retires the panel's `MID_TRANSITION_VOCABULARIES` constant.

### 5. Watch the current loop open early, then open it by hand at maple

Before the start is changed, two looks at how the loop opens now, with
the package, its command surface and the `sieg-view` strip on the
branch.

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
  the panel through a start (`MoveToFullKeep`), the valve
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

Tests (`tests/actors/test_sieg_loop.py`, on the clock seam; a full travel
against the sim relays carries `@pytest.mark.wallclock`, which `ci.sh`
deselects):

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
5. The House0 pairs of `tests/actors/test_hp_boss_live.py` (`PAIRS`:
   `house0-willow`, `house0-orange`) uncommented: admin's TurnOn parks
   hp-boss in `PreparingToTurnOn` until the loop on the sim plant sends
   `SiegLoopReady`. With it, gap 1 of `../spruce-settled/relay-tests.md`:
   no ready message arrives and `TURN_ON_ANYWAY_S`, shortened through
   settings, closes the relay anyway.
6. Each of power, LWT, EWT and the destination temperature in turn stops
   reporting during `HpStartingUp` (the sim driver goes silent, the last
   value stays in `latest_channel_values`): full send once the channel
   flatlines, one glitch naming it. The same with the channel absent from
   the start.
7. The signatures module: each known model's thresholds equal the values
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

First, finish cutting this spoke to what change 6 needs: drop change 4
once the strip has served the maple test-drives, drop "Not assumed" and
most of this section, and state Verification as: `StratProtect` runs
correctly, without destratifying the tanks, as the maple and beech heat
pumps come on.

The first maple window ran 2026-09-25 (seven minutes, HoldFullSend, the
strip writing, the valve re-homed to send in 110 s). The second-pi swap
is built for maple and beech: `house_window.sh` moves the second pi with
the first, its restart timer included, and ends the window on both when
it ends on either. A 30-minute maple window on both pis followed at
16:32, before the timer was in the list; the timer restarted production
scada2 at 16:45, so the analog temps after that are mixed-encoding and
not evidence. The tie was witnessed at 17:21 (a killed scada2 ended both
windows within 10 s), and a 15-minute window from 17:22 gave the first
clean strip: the heat pump stayed at standby (54 W), the analog temps
read true (LWT 96.0 °F, buffer 95.8 / 95.9 °F), and the valve re-homed
keep to send. Three things it showed: every relay channel, the loop's
two included, had no value for the whole window; `sieg-send-flow` never
reported, so `primary-flow` never derived; and maple2's first `hp-lwt`
arrived five minutes after boot, then one per 300 s while steady.

Next, changes 4a and 4b, each test first: scada2 re-sends its readings
when its link to the scada goes active, and the relay actor reports its
energization as a channel reading. Then the two left from the first
window, each with a local test first: why `hp-scada-ops-relay` and
`charge-discharge-relay` sent nothing to the i2c bus at boot; and the
loop logging its own relays' dispatch acks and full reports as
unexpected messages. Then the
window again, this time with the panel driven to keep and back, and the
heat pump starting through it; `hp-lwt` should be on the strip within
seconds of boot.
