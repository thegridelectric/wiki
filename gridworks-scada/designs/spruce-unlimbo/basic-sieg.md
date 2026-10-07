# basic-sieg

Status: Accepted · Pass 1 · Updated 2026-09-28 · Linear: OPS-392

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

### 4a. scada2 re-sends its readings when its link to the scada goes active ✅ built

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

Built as `SecondaryScada.forward_synced_readings` (keeps a
`ForwardedReading` per channel: source node, value, read time) and
`SecondaryScada.recv_activated` (re-sends them, batched by source and
read time, on the local link). The test is
`tests/actors/test_secondary_scada.py`: a reading forwarded, the link
forced down and back, the scada holds both channels again with the
original read time within a second; before the fix it timed out.

### 4b. The relay actor reports its energization as a channel reading ✅ built

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

Built in `send_state` (`actors/relay.py`): the reading goes out beside
the state, same time. Tests:
`test_relay_i2c_house0.py::test_house0_relay_reports_its_energization_as_a_reading`
(a reading beside every state after each command, none while Unknown)
and `test_relay_i2c.py::test_por_boot_adopts_deenergized` (the boot
reading on a readback board). Both failed before the fix.

### 4c. TODO: two things the first maple window showed at boot

Both from the 2026-09-25 maple strip; each gets a local test that
reproduces it before its fix.

**4ci. Every node that is the direct boss of an actuator boots its actuators.** ✅ built
On a board with no readback (the Krida) a relay actor's boot adoption
stays Unknown and writes nothing to the bus; the pin holds the board's
power-on level on a cold boot and whatever it was on a service restart.
The relay asserts a posture only when its boss commands one, so the
boss's start is where boot posture is established, and the command tree
keeps the intermediate bosses in every tree (`set_command_tree`,
`actors/scada.py`: hp-boss, sieg-loop and five-v-boss sit under the
boss with their relays under them; the rest sit directly under the
boss). At maple on 2026-09-25 `hp-scada-ops-relay` and
`charge-discharge-relay` sent nothing to the bus at boot, and the tree
says why:

- `hp-boss` starts by reporting HpOff and does not command
  `hp-scada-ops-relay`; the belief is unenforced. Local control's
  `initialize_actuators` never reaches the relay (hp-boss is its boss;
  the exclusion naming it there is redundant).
- Local control is `charge-discharge-relay`'s boss and its
  `initialize_actuators` (`actors/local_control/house0/tou_base.py`)
  excludes the relay in AllTanks mode, so nobody commands it. The
  exclusion has no recorded reason and goes: local control always
  commands DischargeStore at boot. On House0 that one relay moves both
  valves, so DischargeStore is iso valve open and valved to discharge,
  the posture every fallback path commands; AllTanks re-commands
  ChargeStore when its first state decision says so.
- `sieg-loop` does boot its pair, through its strategy's
  actuators-ready hook.
- `five-v-boss` starts by reporting its state only; whether the pico
  cycler commands `vdc-relay` at boot is not yet checked.

The fix is one rule, applied per boss: at start, once the actuators are
ready, each direct boss commands every actuator it bosses to its boot
posture. hp-boss commands OpenRelay at start beside the HpOff it
already reports; local control drops the AllTanks exclusion. Test
first: one parametrized live test over every test layout and every
strategy selection the ops word allows; boot the scada, wait for local
control to initialize, and assert every relay has left Unknown within
seconds (`tests/actors/test_relays_boot.py`: three hand-picked House0
rows covering each local-control and loop strategy once, plus Nolan;
interim until the tree hierarchies are encoded as a graph the tests
walk, the plan in `command-tree-matrix.md`). The two House0 rows that failed on exactly
these two relays pass with hp-boss commanding OpenRelay at start and
the AllTanks exclusion gone. Nolan passes this criterion by readback
adoption alone; commanding a boot posture there is the Nolan
local-control rework's (`nolan-local-control.md`).

**4cii. The loop confirms its relay moves and reports every move in full.** ✅ built
The loop's two relays answered it with a dispatch ack and a full report
and the loop logged both as unexpected; a nack was invisible, and an
automatic move wrote no full report. Now every move, commanded or
automatic, is one `Move` with one TriggerId (the commander's, or one the
loop mints); the two relay commands ride under it; the motor clock
starts when both relays have reported, or after five seconds on the
scada's clock with a warning glitch (`relay_silent`), since enforcement
below the loop keeps retrying a failed write; a nack skips the motor
time and glitches an error (`relay_nack`); and when the motor stops one
`fsm.full.report` goes to the scada with the relays' atomics and the
loop's own under that id. Tests: the capture helper answers relay
commands as a relay does, and one test each for the shared id, the
folded report of an automatic and a commanded move, the clock starting
on the reports, a silent relay, and a nack.

Two things this leaves for the executor. The control-hierarchy's
"written record" rule wants every actuator's full report addressed to
the scada; the scada keys its recent reports by TriggerId alone, so a
relay reporting straight to the scada under its boss's id would collide
with the boss's own report. Folding at the boss is the shape that fits:
the loop does it; the pico-cycler and five-v-boss read their relay's
report only to confirm and report their own transitions alone. Nothing
in relay.py or the scada changed here; write the rule up when the relay
addressing item closes. And the choreography's relay commands from the
strategy's own tick used to mint an id each; the four loop methods on
House0Hydronic now take the id as a required argument.

### 4d. `sieg-send-flow` never reports at maple ✅ built

In the 2026-09-25 maple window `sieg-send-flow` had no value for the
whole run, so `primary-flow`, which maple derives from it and
`sieg-flow`, was never derived either. Without them the flows cannot
confirm the valve at keep (`sieg-send-flow` to zero, `sieg-flow` up) or at
send.

Cause (confirmed with the starter-scripts API): the Hall pico on the
send line (`pico_481731`) identifies itself as `sieg-send`, the name
the `main` layout gives its actor (`gen_maple.py`,
`ActorNodeName='sieg-send'`); production journals a sensible `sieg-send`
flow from it. The window layout named the node and channel
`sieg-send-flow` through the FlowSpec grammar (`<position>-flow`), so no
node answered to `sieg-send` and its posts went nowhere. Renaming on the
pico means the old flow firmware, version unknown, so the fix is in the
layout and the derived generator:

- **Layout (tlayouts `jm/spruce`, `maple_gen.py`).** The pico keeps its
  node and DataChannels as `sieg-send` / `sieg-send-hz`, with their
  deployed ids, through `FlowSpec.node_name`, a per-meter string for a
  pico that posts outside the grammar; `emit_flow` then emits an
  `identity` DerivedChannel `sieg-send-flow` = [`sieg-send`], GpmX100 in
  and out, created by `derived-generator`, which feeds the `sum` that
  derives `primary-flow`. The `RENAMED` table is gone; renames are per
  house. Maple is the one case: every new sieg house names its meter
  `sieg-send-flow` through the grammar, and the House0 generation assumes
  nothing of maple's shape. No sema change: `gw.house0.layout` axiom 8
  "SiegManifoldChannels" takes the channel as Data or Derived and requires
  no flow-meter node by name.
- **Identity passes a flow through.** `handle_identity`
  (`actors/derived_generator.py`) passes a reading through unchanged when
  its encoding is the channel's `OutputUnit` (GpmTimes100 and GpmX100
  count as one encoding) and converts temperatures as before.
- **A derived reading feeds the derived channels that take it.** Every
  handler emits through `emit_derived`, which sends to the scada and then
  runs `_dispatch_derived_input`, the same per-channel lookup device
  readings take. The layout validators reject cycles
  (`check_derived_channel_inputs_acyclic`), so the generator adds no
  guard. `layout.feeds_derived` turns on the flow module's forwarding
  once `sieg-send` is an input, and the generator takes the
  `channel.readings` list a hall pico posts, reading by reading; before
  4d it matched only single and synced readings, so no hall flow post
  reached a derived channel on any house (at beech the difference fired
  only on the BTU meter's posts).

Tests: identity passing a GpmTimes100 reading through; one reading firing
an identity and a sum over that identity; a flow pico's channel-readings
list firing the difference once per reading; maple's generated layout
keeping the deployed ids under `sieg-send`, emitting the identity and
summing the grammar name (`tlayouts/tests/test_flow_meter_legacy_name.py`).
Verified at maple 2026-09-27 (round five, `experiments/beta-field-windows/`):
`sieg-send-flow` and `primary-flow` reported through an 11-minute window
with a 110 s move to full send, the sum holding within 0.01 gpm on every
strip line and every report reading.

### 4e. Minor sema and admin change

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
  after an off command, which gets its own critical glitch. The line is the high
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

## Do this next

The valve's positions are measured (Open, "The valve's positions"): keep
complete at about 56 s and the keep stop at about 94 s, so the two admin
stops of 2026-09-28 at 81.5 and 81.1 s sat in the fully kept span short
of the stop. Before the start algorithm (change 6) is rewritten, the loop
gets a model that the day's data supports:
`experiments/2026-09-28-maple-ecodan-start-in-full-keep/` finding 6 fits
the kept loop at about 0.8 gal of water from nine closed-start chunks
(V x rise = integral of flow x lift), with the fitted volume drifting up
with temperature. The next move is the model's second term: separate the
heat pump's own warming from room loss and from the 0.65 F same-water
sensor offset, using the hold periods (only two exist, 55 W each at 64 F
and at 105 F, which no loss-to-a-fixed-room line fits, so the next window
holds the closed loop at three temperatures for ten minutes each with the
heat pump off). Change 6's "park then one reckoned move" is not the plan
until that model says what the valve should do; the two-stage sketch in
Open stays open. Keep the admin lease alive through any start.

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
- Primary flow depends on the valve posture, not only on the pump. At
  full keep the pump drives the Siegenthaler loop alone, eight feet of
  pipe from the heat pump's leaving line back to its entering line, with
  almost no head; at full send it pushes through the buffer and
  distribution. Maple 2026-09-27: 4.85 gpm at full keep, 4.13 gpm at
  full send, same pump command. A flow reading is compared across
  postures only with this in mind.

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

- Executor text to correct when the package settles:
  `executor/sieg-loop.md`'s opening note describes a branch diff that
  names the actuation authority, and `executor/primary.md` "Sieg loop
  posture" predates the loop becoming a package.
- Valve position and how certain the loop is of it. `keep_seconds` is one
  float assumed 100 (full keep) at boot with no record of how it was
  obtained; a commanded move re-homes by running the whole range, a
  strategy move trusts the number plus the 10 s overshoot. At the
  2026-09-28 13:31 boot the valve stood at send, the model said FullyKeep,
  and the state was wrong for 108 s of motor. Two facts shape the fix.
  Homing means a run to FULL send, which is 25 to 30 s of motor beyond the
  point where the flow stops changing. And the number is reliable only
  after one continuous move from a hard end stop; once a strategy adjusts
  in small increments (the PID to come) the reckoned position drifts and
  must not be trusted as if it were measured. So: two data channels
  captured by the loop, both integer and written at each motor start and
  stop. One is the homed position, reported only while the valve has made
  at most one continuous move since it last ended on a stop, and silent
  (no value) after the second move until the next stop. The other is the
  reckoned position, always reported, the strategy's own estimate. The
  channels are derived (`derived.channel.gt`): their inputs are the two
  relay energization channels and the loop is the creator, and the unit
  comes from `gw1.unit` 001, which already has `SecondsX10` and
  `Milliseconds` under the Time quantity, so no vocabulary changes beyond
  the two channel words in the layout.
- The valve's positions, in motor seconds from the send stop, and the
  names the code uses for them. The motor runs at one speed both ways;
  the flow split changes only in the middle of the travel.

  | Position | Name in code | Maple, measured 2026-09-28 |
  | --- | --- | --- |
  | Send stop | `keep_seconds = 0` | 0 s |
  | Keep onset: the keep opening appears | `t1` | about 26 s |
  | Half point: sieg-send-flow is half the total | | about 36 s |
  | Keep complete: all flow kept from here on | `t2` | about 56 s |
  | Keep stop: the mechanical end | `FULL_RANGE_S` | about 94 s |

  Between onset and complete the split is a steep, non-linear function
  of seconds, a ball valve's; the map of it is the queued
  `experiments/future/sieg-keep-ratio-map/`. The numbers come from the
  full travels of the four 2026-09-28 windows
  (`experiments/2026-09-28-maple-ecodan-start-in-full-keep/`, read by
  `experiments/future/sieg-keep-ratio-map/half_point.py`): toward keep
  the half crossing came 40 s after every motor start; toward send it
  came 61.5 s after a start from the keep stop and 48.5 s after a start
  from the 81 s admin stop, which fixes the keep stop at 94 s. The
  onsets of change and the settling of the other meter place `t1` and
  `t2` the same way. They are facts about one valve, tunable by hand on
  it, so they belong in the layout as parameters of the loop, not in
  code; the code carries maple's values until the word exists.

  The six crossings agree only if every flow reading answers about 4 s
  after the motor: without that lag the half point sits at 40 s going
  toward keep and 32.5 s going toward send, which a valve with no
  memory of direction cannot do. A 4 s lag between the water and its
  reading is a concern in its own right, whatever its source (the
  meter's pulse period, the pico's posting, the scada's stamping), and
  it is not yet explained; the crossing rows of `half_point.py` are the
  data. It is dug into with the pico firmware work.

- `sieg-flow` and `sieg-send` post-on-change behaviour against the layout's
  deltas (sieg-btu `AsyncCaptureDeltaGpmX100` 10, sieg-send
  `AsyncCaptureThresholdGpmTimes100` 4): whether the picos run the layout's
  values or their flash defaults, given the BTU picos answer the params
  exchange with version 000 against the scada's 100. Being read from the
  2026-09-28 run.
- What the Ecodan and the LG do idle beyond standby draw. The Samsung
  pulses to 318 W and runs its water pump with the compressor off; the
  "drawing power after an off command" line of change 6 and the `HpHasLift`
  entry both rest on the House0 heat pumps not doing the same at a level
  the thresholds see.
- Whether the target carries a margin, and whether the move to send is one
  travel or paced: a first part to the reckoned moment and a gradual
  finish over about 30 s more is the other sketch.
- The 2026-09-27 maple strip showed the zone heat-call periodic emission
  running 176 s late, which reads as the derived generator's periodic
  emission firing only when an input reading arrives. Not sieg-loop; a
  home outside this spoke once traced. (The strip's other gap,
  `transactive-power` with no value, is closed: the power meter creates
  it and boot holds every creator to its claim, "Do this next".)
- A calibration and heat-loss window, 2026-09-28 from 14:37:10 ET. The
  third maple window of the day (boot 14:33, `1287911f`) ran hp-lwt and
  hp-ewt at a 0.05 C async delta for the first time, and after a warm
  start the valve was stopped at keep_seconds 81.1 (full keep for the
  flow: sieg-flow 5.0 gpm, sieg-send-flow 0.02 gpm) with the heat pump
  idle at 54 W. From then on the loop recirculated the same water with
  no heat added, so the period is two things at once: the loop's heat
  loss at 0.05 C resolution (lwt 105.0 F and ewt 105.7 F at 14:40,
  falling together), and a same-water comparison of the two thermistors
  for calibrating hp-ewt against hp-lwt, since with the heat pump off
  the two should read the same. The data is the box's persisted reports
  for the day (`~/.local/share/gridworks/scada-experiment/event/`, the
  14:35 slot onward) and the laptop capture
  `scratch/broker-capture-20260928-134934.jsonl`; it earns an experiment
  folder when the offset and the loss slope are read off it.
