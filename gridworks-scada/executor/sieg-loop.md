# The Siegenthaler loop actor, as it runs

Status: Draft · Pass 0 · Updated 2026-11-22

> What this is: what `sieg-loop` does on scada `main` and where it falls
> short, read from the code. The actor is the package
> `gw_spaceheat/actors/sieg_loop/`: the facade `SiegLoop` (`__init__.py`),
> the valve (`valve.py`), the strategy interface and its selection
> (`strategy.py`), and the two built strategies (`hold_full_send.py`,
> `strat_protect.py`). Line numbers are scada `main` @ `45cd599d`; the
> package there is the code of `341090c1`, which maple runs.

## What the loop is for

A three-way valve on the heat pump's primary loop. At full keep the heat
pump's water recirculates in the small loop; at full send it goes on to the
buffer or the store. Two jobs follow from that. At a start, keep the water
in the small loop until it is worth sending, so a start does not push cold
water into a hot tank. At an off, close the loop where the primary pump
keeps running: maple's pump sits inside the Mitsubishi, the scada cannot
switch it, and with the valve at send and the heat pump off it mixes the
buffer (`buffer-depth1` 103.2 F to 95.3 F in twelve minutes, against 0.3 F
with the loop closed;
`experiments/archive/2026-09-20-maple-starts-heating/README.md` findings 12
and 14).

## The actor

The facade owns what every strategy shares: the valve and its state
report, the command surface, the 30 s tick (`CONTROL_INTERVAL_S`,
`__init__.py:113`), the watchdog pat, and the subscription to hp-boss's
state, asked of the scada at start (`__init__.py:419-421`). It hands each
event (actuators ready, an hp-boss state, a tick, a return to automatic
control) to one strategy, which decides what the valve does
(`strategy.py:38-66`).

**Tree.** `sieg-loop` is a fixed subtree: it sits directly under whichever
boss holds the tree, admin included, with `hp-loop-on-off` (relay 14) and
`hp-loop-keep-send` (relay 15) beneath it, and a tree rewrite reparents it
with its relays (`hydronic_layout.py:1558-1575`, `scada.py:1424`). The
relays refuse any other commander by the immediate-boss axiom; the leaf
allies and local control act only on relays they boss.

## The valve

- **The two relays differ.** Relay 15 selects direction and speaks
  `change.keep.send`; its de-energizing event is `ChangeToKeepLess`, toward
  send. Relay 14 runs the motor and its de-energizing event is
  `CloseRelay`: `CloseRelay` runs the motor, `OpenRelay` energizes the
  relay and the motor rests (`relay.py:827-837`, `:876-880`). The actuator
  has end switches, so driving into a stop does no harm. With the scada
  dead or power lost both relays de-energize and the valve travels to full
  send, which keeps the house warm.
- **Travel is timed; no sensor reads position.** Position is `keep_seconds`, motor
  seconds from the send stop: `FULL_RANGE_S = 94` is the keep stop,
  `t1 = 26` keep onset, `t2 = 56` keep complete, measured on maple's valve
  from the flow meters (`valve.py:63-70`, `:105-106`). A run to a stop
  overshoots by `OVERSHOOT_S = 10`, so a move to the stop the valve rests
  on still runs the motor ten seconds into the end switch. A run is one
  motor time on the scada's clock; a new run cancels the one in flight,
  which settles `keep_seconds` from the clock first (`valve.py:176-254`).
- **Homing.** The valve boots as `FullyKeep` at the keep stop with
  `homed` false. Until one run of at least `FULL_RANGE_S + OVERSHOOT_S` in
  one direction has finished, every automatic move is a full run to the
  stop on its posture's side (`valve.py:114-124`,
  `strat_protect.py:220-230`).
- **States.** `FullySend`, `FullyKeep`, `KeepingMore`, `KeepingLess`,
  `SteadyBlend`. A run that ends on a stop ends in `FullySend` or
  `FullyKeep`; any other end is `SteadyBlend` (`valve.py:72-90`). Each
  change goes to the scada as `single.machine.state` with
  `sieg.valve.state`, on change only (`__init__.py:326-336`).
- **Every move is confirmed and reported.** A move, commanded or the
  strategy's own, is a `Move` (`valve.py:29-48`) with one `TriggerId`: the
  commander's, or one the loop mints. Both relay commands are sent under
  it (`House0Hydronic` takes the id as a required argument,
  `house0.py:360-452`). The start transition sends the commands; the motor
  clock starts only when both relays' `fsm.full.report`s have arrived, or
  after `RELAY_REPORT_WAIT_S` (5 s on the scada's clock) with a warning
  glitch `relay_silent`, since the relay's enforcement keeps retrying a
  failed write below the loop (`__init__.py:247-266`). A `dispatch.nack`
  from a loop relay is an error glitch `relay_nack` and ends the move
  without motor time; a `dispatch.ack` is taken silently
  (`__init__.py:185-208`). When the motor stops the loop sends one
  `fsm.full.report` to the scada under the move's id: the relays' atomics
  in arrival order, then its own (`sieg.valve.state` from and to, with the
  `move.sieg.valve` event, or for an automatic move the direction as the
  boss would have commanded it; `__init__.py:389-413`). The rule this
  follows is `control-hierarchy.md` "One full report per command, folded
  at the command nodes".

## Choosing the strategy

Once, at construction, from the ops word (`selected_strategy`,
`strategy.py:23-35`): the House0 family params' `SiegLoopStrategy` (enum
`sieg.loop.strategy`), except that `Standby` runs `HoldFullSend` whatever
the params say, since the power-less posture is full send (sema
`gw.operational.params` axiom 5). This holds for both standby postures,
`MonitorOnly` included. `HoldFullSend` and `StratProtect` are built; the
ops-word loader refuses `LwtControl` (`sema_to_dc.py:125-136`) and any
other value fails construction (`__init__.py:131-141`).

hp-boss reads the same selection (`hp_boss.py:216-228`). Under
`StratProtect` on a layout with the loop, a TurnOn moves hp-boss to
`PreparingToTurnOn` and it closes the call relay when `SiegLoopReady`
arrives (`:294-300`); with no ready in 120 s it opens the call relay,
returns to `HpOff` and raises an alert (`:302-313`). Under `HoldFullSend`
hp-boss closes the call relay at once and never enters
`PreparingToTurnOn`.

## HoldFullSend

`hold_full_send.py:10-22`. No inputs and no control state. When the
actuators are ready it moves the valve to full send, and when the loop
comes back under automatic control after a command it moves it to full
send again. Otherwise it does nothing: the heat pump behaves as if there
were no loop. It reads no temperature, no power and no tank, buffer, iso
valve or store channel.

## StratProtect

**Inputs.** hp-boss's reported state; LWT and EWT (`hp-lwt`, `hp-ewt`),
read as lift; indoor and outdoor unit power (`hp-idu-pwr`, `hp-odu-pwr`).
A channel that has flatlined reads as missing (`sh_node_actor.py:363-375`,
`house0.py:751-772`; [`sensor-freshness.md`](sensor-freshness.md)).

**Running** means `hp-odu-pwr` is live and over `IDLE_POWER_W = 500`
(`strat_protect.py:53-58`, `:126-131`).

**Blind** (`blind_reason`, `strat_protect.py:136-148`):

| hp-boss state | Blind when |
| --- | --- |
| `HpOff` | the outdoor unit is running ("outdoor unit at … over 500W after off"); a missing reading changes nothing |
| any other | lift missing (LWT or EWT not live), or total power missing (either unit not live) |

**Control states and postures.** The control machine runs on every
actuators-ready, every hp-boss report and every tick (`engage_brain`,
`strat_protect.py:154-208`). It leaves `Initializing` only once the
actuators are ready and hp-boss has reported. Each change of control
state moves the valve, under automatic control, to the state's posture
(`move_for`, `:220-242`):

| Control state | Entered when | Valve |
| --- | --- | --- |
| `HpOff` | hp-boss reports `HpOff` and the loop is not blind | full keep |
| `HpStartingUp` | hp-boss reports `PreparingToTurnOn`, or `HpOn` with the outdoor unit not running | parked at `t2`, keep complete |
| `HpHasLift` | in `HpStartingUp`, the outdoor unit is running (`HpStartUpDone`); or hp-boss reports `HpOn` with it running at boot or on leaving `Blind` | full send |
| `Blind` | the blind test answers true, from any state | full send |

**The start.** On the first `PreparingToTurnOn` report the loop sends
`SiegLoopReady` to hp-boss at once (`strat_protect.py:106-114`) and enters
`HpStartingUp`, which parks the valve at `t2`: from the keep stop a run of
38 s toward send, after which the first second of an open sends water.
hp-boss closes the call relay on the ready, so the park runs during the
heat pump's own pump pre-run. On the first pass after the outdoor unit
crosses 500 W, `HpStartUpDone` moves the valve to full send. A heat pump
whose outdoor unit never crosses 500 W leaves the valve parked; there is
no other way out of `HpStartingUp` but an off or `Blind`.

**The off.** hp-boss reports `HpOff` → `HpOff` → full keep, the posture
for a plant whose primary pump runs through every off. A heat pump honours
an off on its own clock (the Ecodan runs on for minutes when the off comes
soon after a compressor start), so while the outdoor unit still draws over
500 W the loop is `Blind` at full send, and it returns to `HpOff` and full
keep on the pass after the draw falls under the line. An off while parked
returns the valve to the keep stop, and a compressor that starts anyway
opens it the same way. A TurnOn while the unit is still running out an off
passes from `Blind` through `HpStartingUp` to `HpHasLift` in one pass and
the valve stays at send. Off is what hp-boss reports, so a defrost does
not move the valve.

## Commands from the boss

`sieg-loop` is a command node with vocabulary `move.sieg.valve`
(`scada.py:2131-2139`): `MoveToFullSend` → `FullySend`, `MoveToFullKeep` →
`FullyKeep`, `StopValve` → `SteadyBlend`. The admin panel offers them,
including while the valve is moving
(`packages/gridworks-admin/src/gwadmin/watch/widgets/relay_widget_info.py:18-34`).
`process_fsm_event` (`__init__.py:282-314`) applies the two authority
checks of `control-hierarchy.md` "Command interfaces and replies": a
`FromHandle` that is not the sender's handle is a warning glitch
`bad_sender` and no reply; a `ToHandle` that is not the loop's is nacked
`NotMyBoss`; any other vocabulary or event is nacked `UnknownEvent`. An
accepted command is acked and takes the loop out of automatic control: the
loop keeps the boss part of its handle, withholds the strategy's moves,
and on the first tick after the tree changes hands resumes the strategy,
which re-asserts its posture (`__init__.py:156-166`). `MoveToFullSend`
and `MoveToFullKeep` are full runs to the stop, taken mid-travel as well,
so a command to the stop the valve rests on re-homes it. `StopValve`
cancels the run in flight and holds relay 14 under the stop's id; the
run's move reports without the hold, then the stop's move reports with
it. With the motor at rest it moves nothing and reports the valve's state
as it stands (`valve.py:150-162`).

## What can be seen

- **Journal.** The valve state (`sieg.valve.state`), each move's full
  report, and each relay's energization. A relay actor sends, beside every
  `SingleMachineState`, a `SingleReading` on its `RelayState` channel from
  the confirmed pin level, 1 energized and 0 de-energized: at boot
  adoption, on each confirmed command and on each verify pass; an Unknown
  relay sends neither (`relay.py:730-756`). For the loop these are
  `hp-loop-on-off-relay` and `hp-loop-keep-send-relay`.
- **Box log.** The control state and the blind reason reach only the box
  log. Every actor log line is `[<node>] <note>`, written at the scada
  logger's error level so it appears whatever level is set
  (`sh_node_actor.py:311-313`). The control and valve transitions are
  `<Event>: <From> -> <To>` and each entry into `Blind` is preceded by
  `Blind: <reason>` (`strat_protect.py:168`, `:182`, `:213`;
  `valve.py:266`). The loop's control history on a box:

  ```
  journalctl -u gwspaceheat | grep -E "\[sieg-loop\] (Blind:|[A-Za-z]+: [A-Za-z]+ -> [A-Za-z]+)"
  ```

- **The `sieg-view` strip** is debug output for test-drives, off on
  `main`: its two calls are commented out (`__init__.py:162`, `:337`).
  Switched on, it logs one line per tick and per valve transition: the
  valve state and `keep_seconds`, each channel of `VIEW_CHANNELS` the
  layout names with its value or `--` and its age, derived channels marked
  `*`, then lift, total power and any blind reason (`__init__.py:64-82`,
  `:352-387`). Read as a strip it catches readings that vanish while their
  picos are alive.

## Inputs from elsewhere

- **scada2 re-sends its readings when its link to the scada goes
  active.** The loop reads `hp-lwt` and `hp-ewt` from the second pi.
  scada2 forwards readings at QoS 0 with no ack, and its analog-temp actor
  reports a channel only on a change past its delta or at its capture
  period, so a report the scada was not ready for would leave it without
  LWT or EWT for up to a capture period. `SecondaryScada` keeps the latest
  forwarded reading of each channel (`ForwardedReading`: source, value,
  read time; `secondary_scada.py:29`, `:155`) and every time its link to
  the scada goes active, the first time and after each bounce, re-sends
  them batched by source and read time with their original read times
  (`recv_activated`, `:176-197`), so the scada sees their true age. No ack
  is added: this path flaps.
- **`sieg-send-flow` reports.** The flows confirm the valve's posture
  (`sieg-send-flow` to zero and `sieg-flow` up at keep). The House0 layout
  requires `sieg-send-flow` as a data or derived channel
  (`gw.house0.layout` axiom "SiegManifoldChannels"). Where the send-line
  pico posts under another node name, the layout derives `sieg-send-flow`
  from it by `identity`, which feeds the `sum` deriving `primary-flow`.
  The derived generator passes a reading through unchanged when its
  encoding is the channel's output unit (`derived_generator.py:313-330`),
  and every derived reading goes to the scada and then to each derived
  channel that takes it as input (`emit_derived`, `:873-886`).

## Not assumed

A fall layout has a Siegenthaler loop with no buffer tank and no iso
valve. `StratProtect` decides from hp-boss's state, heat pump power, LWT,
EWT and its two relays; it names no buffer, iso valve or store tank. Any
of these inputs may stop reporting: with the heat pump on the loop then
opens the valve and does not guess, and with it off the valve stays at
keep. `HoldFullSend` reads none of them. The base class is
`House0Hydronic`, whose relay choreography the valve drives, so a layout
without the House0 hydronic set needs that choreography in a base class
of its own.

## Where it falls short

Most consequential first. This is the critique of the current state
machine and its names.

1. **The start opens on outdoor-unit power.** `HpStartUpDone` fires
   on the first pass after the outdoor unit crosses 500 W, within about
   30 s of the compressor starting, with no reference to LWT or to the
   temperature of where the water is going. The park keeps the pre-run's
   cold water home; the first compressor water still goes to the tank
   barely warmer than it left.
2. **The off opens on power alone.** While the unit runs out an off the
   valve is at full send whatever LWT is. At maple an off 65 s into a run
   left the Ecodan drawing about 1.2 kW for over nine minutes with
   1.3 °C of lift, LWT near 35 °C into a buffer top of 55 to 64 °C, and
   `buffer-depth1` fell to 109 F. The loop was protected and the buffer
   was mixed.
3. **`HpStartingUp` has no bounded way out but power.** A compressor that
   runs under 500 W on `hp-odu-pwr` keeps the loop shut, with no backup
   timer and no read of the heat pump stopping itself at its upper limit.
   At beech the LG reaches its limit about six minutes into a loop-closed
   start, and repeated limit trips have ended in a lockout cleared by hand
   ([`startup-signatures.md`](heat-pump-signatures/startup-signatures.md)
   "The LG at its upper limit"). `IDLE_POWER_W` is one number for every
   model, kept apart from hp-boss's per-device-type sensing
   (`strat_protect.py:53-58`).
4. **`Blind` mixes three meanings and fails open for all:** no lift, no
   power, and an outdoor unit running after an off. It is a peer state
   entered from every state with three exits.
5. **Ready goes before the park.** `SiegLoopReady` goes at the
   `PreparingToTurnOn` report, so the call relay closes while the valve is
   still moving and the park finishes inside the heat pump's pump pre-run
   only because that pre-run is long. hp-boss's 120 s wait is on the wall
   clock and the ready does not cancel it.
6. **The control state is not reported.** Only the box log shows it, and
   its names mislead: `HpHasLift` means the outdoor unit is over the idle
   line.
7. **Under `MonitorOnly` the loop energizes relay 14.** Standby runs
   `HoldFullSend`, whose run to send ends with the hold, `OpenRelay`,
   which energizes relay 14; `MonitorOnly` means the scada energizes
   nothing.
8. **A change of boss is noticed on the 30 s tick,** when the tree is
   rewritten; nothing tells an actor its handle changed.
9. **Leftovers from blend control.** `t1` is defined and read nowhere.
   The scada still routes `SetLwtControlParams`, `SetTargetLwt` and
   `SiegLoopEndpointValveAdjustment` to the loop, which drops them as
   unexpected, and handles `ResetHpKeepValue` with a body that forwards
   nothing (`scada.py:433-470`, `:817-935`).
10. **The valve's travel constants are maple's.** `FULL_RANGE_S`, `t1` and
    `t2` are code constants measured on one valve; they belong in the
    layout.
11. **A hand-kept fact in the admin panel.** That the loop takes a command
    while its valve is moving is `MID_TRANSITION_VOCABULARIES`
    (`relay_widget_info.py:24`), since `gw.command.interface` 001 has no
    field for it.
12. **No live test drives a start through the loop.** The House0 pairs of
    `tests/actors/test_hp_boss_live.py` are commented out, so admin's
    TurnOn through `PreparingToTurnOn` and `SiegLoopReady` on the
    simulated plant runs only in the loop's unit tests.

## Related

- A start, as the heat pump shows it, loop open and closed:
  [`startup-signatures.md`](heat-pump-signatures/startup-signatures.md).
- Idle draw by heat pump: [`idle-signatures.md`](heat-pump-signatures/idle-signatures.md).
- Defrost, as the heat pump shows it: [`defrost-signatures.md`](heat-pump-signatures/defrost-signatures.md).
- Command nodes and replies: [`control-hierarchy.md`](control-hierarchy.md)
  "Command interfaces and replies".
- What comes after the launch fixes:
  [`../explorations/sieg-loop-next.md`](../explorations/sieg-loop-next.md).
