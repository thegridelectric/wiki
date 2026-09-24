# The sieg loop after launch: proposals and what exists

Status: Draft · Pass 0 · Updated 2026-09-21

> What this is: where the Siegenthaler loop could go once the launch fixes
> are in, for whoever takes the loop on next. Proposals and
> recommendations, none decided, with a reading of the two earlier bodies
> of code worth mining. What the running loop does and where it falls
> short is [`../executor/sieg-loop.md`](../executor/sieg-loop.md); read
> that first.

## The three bodies of code

| | 2025–26 loop, `c55fe9eb` | `origin/main` @ `54f74302` | `origin/td/sieg-pid` @ `eca8d565` |
| --- | --- | --- | --- |
| File | `actors/sieg_loop.py`, 1499 L | `actors/sieg_loop.py`, 620 L | `actors/sieg_loop/pid.py` 940 L, `fallback.py` 655 L, `sieg_loop_loader.py` 224 L |
| Park at a start | `StartupHover` at `t2` = 67 of 70 s | `HpStartingUp` at `t2` = 82 of 100 s | `StartupHover` at 82 of 100 s |
| Target position | `calc_eq_flow_percent(lift + 3)`, then the flow-to-time map | none | same as `c55fe9eb` |
| LWT slope | °F/s, newest reading against one at least 10 s old, 40 kept | none | same |
| When it starts to open | time to target LWT minus travel time under 3 s | `max(lwt, ewt) > MaxEwtF - 20` | under 3 s, same |
| Then | move to the computed position, wait travel + 60 s, PID | full send | same, then PID |
| Heat pump never heats | hovers without limit | parked without limit | loader demotes to fallback within 60 s |
| Target LWT | `SetTargetLwt`, else hottest tank top, else 130 F | none | `SetTargetLwt` only; local control sends a hard-coded 120 F marked as a hack |
| Start-up logic | about 295 L | about 25 L | about 207 L |

Read once, by function; confirm before building on any row.

**`c55fe9eb`** is the blend control that ran the 2025–26 season. Its
start has three ingredients: where the valve will need to be for the
wanted LWT (`calc_eq_flow_percent`, `k = 1 - lift / (target_lwt -
anticipated_sieg_cold)`, through an 11-point measured flow-against-time
table), how fast LWT is rising (`update_derivative_calcs`), and how long
the valve takes to get there. It leaves the hover when the time to target
is within the travel time plus 3 s (`time_to_leave_startup_hover`, `:264`),
so the valve arrives as LWT does, and closed-loop control starts after a
settle. Its weaknesses: no way out of the hover when the slope is flat or
negative, and `MovingToFullSend` is a sink because `ReachFullSend` is never
fired (`:1113`, commented out).

**`origin/main`** kept the park and dropped the rest. It is the loop in the
field and its shortfalls are the executor doc's list.

**`origin/td/sieg-pid`** (about 35 commits from 2026-04-28, in none of
`main`, `dev`, `jm/spruce-unlimbo`) restores the `c55fe9eb` start nearly
verbatim against the 100 s range and a three-state machine
(`StartupHover`, `Pid`, `HpOff`), and adds a loader: the actor the layout
names starts in `fallback.py` (main's loop with already-at-endpoint
guards), checks every 60 s that the required channels are present and not
flatlined and that a `SetTargetLwt` arrived within five minutes, and swaps
to `pid.py` and back, handing `keep_seconds` and the valve state across.
That loader is the only bounded exit from a hover in any of the three.
The control law: 30 s steps, output in seconds of travel clamped to ±30 s a
step, 0.5 s deadband, capped integral, Ziegler–Nichols gains as code
constants (`pid.py:151`), the same numbers `c55fe9eb` carried. Maple's
travel map is retuned there (`t1 = 26`, `t2 = 82`), and indoor-unit power
is dropped from the required channels for `MitsubishiEcodan`. Missing: any
defrost handling, and any record of tuning results; the last commits are
test hacks (buffer forced empty, 120 F target) and their reverts. It
forked from `dev` before the node-actor partition, so carrying it over is
a rebase onto the partition: `pid.py` subclasses the old `ShNodeActor`,
reads settings that have moved to ops, and `SiegLoopMode` is not in
gwsproto.

**Recommendation.** The hover block of `td/sieg-pid`'s `pid.py`
(`enter_startup_hover` `:263`, `_monitor_startup_hover` `:282`,
`time_to_leave_startup_hover` `:300`, `update_lwt_readings` `:375`,
`lwt_reference_reading` `:392`) is the best starting text for any timed
start, and its loader's health check is the best starting text for a
bounded fall-back. The PID itself wants field tuning results before it is
trusted; gains belong in ops with the other thresholds
(`../executor/magic-thresholds.md`).

## Proposals

### A small valve primitive

One class that alone touches relays 14 and 15, stop to stop, so the loop
asks for a stop and nothing else keeps a position count.

```
state: PositionUnknown | FullySend | MovingToFullKeep | FullyKeep
       | MovingToFullSend
FULL_RANGE_S = 100; OVERSHOOT_S = 10; REPORT_WAIT_S = 10

drive_to(stop, cause):
    if target == stop and (state is Fully* or the drive task is live):
        return
    cancel the drive task and await its end
    target = stop; drive task = run(stop, cause)

run(stop, cause):
    try:
        motor dormant, confirmed         # relay 14 OpenRelay
        direction for stop, confirmed    # relay 15 ChangeToKeepMore | ...Less
        state = MovingTo...; report(cause)
        motor active, confirmed          # relay 14 CloseRelay
        sleep FULL_RANGE_S + OVERSHOOT_S
        motor dormant, confirmed
        state = Fully...; report(cause)
    except a refusal, a missing report, or cancellation:
        state = PositionUnknown; target = None; report(cause)
        refusal or missing report: critical glitch naming the relay
    finally:
        if the motor is not confirmed dormant: send motor dormant
```

Every drive is the full range plus overshoot, so a completed drive ends on
the stop whatever came before; the end switches make that harmless.
"Confirmed" is the relay's `fsm.full.report` for the trigger within
`REPORT_WAIT_S`; the loop is the relays' boss, so the reports already come
to it, while state rows go to the scada (`relay.py:919` on the branch). An
I2C relay re-commanded to its current state actuates and reports again
(`relay.py:375`); the non-I2C path acks and sends nothing (`relay.py:362`),
which matters only for a GPIO relay: every relay in the simulated House0
is an `i2c.relay.component.gt`.
`PositionUnknown` is entered at start, on a cancelled drive, and on a
refused or unconfirmed step, and left only by a completed drive. Whether
confirmation earns its keep is open: the relay actor already retries a
failed write and raises a critical glitch, so the simpler loop that sends
and sleeps is not blind to failure, only slower to say where the valve is.

### Strategies behind a facade

Modelled on local control's loader: `SiegLoop` is a facade owning the
valve, the command surface and the reporting, and asks a strategy one
question each tick, which stop (or position) is wanted. Candidate
strategies under one ops enum: `HoldFullSend`; `ProtectStratificationOnly`
(keep unless the heat pump is measured running with a loop worth sending);
`LwtControl` (blend control on top of the protection, the PID's home).
Blind then stops being a state: a strategy that cannot see returns what
`HoldFullSend` returns. Timed travel drifts under many small moves, since
the valve sticks for a short unknown time before it moves, so `LwtControl`
owes an occasional drive to a stop to re-zero. `td/sieg-pid`'s loader is
the same idea with the swap made at run time on channel health; whether
the pick is made once from ops or continuously from health is the question
to settle between them.

### Off, on and defrost from measurement

HpBoss's state says what was commanded. Power says what is happening:
at maple, 4 s from relay 6 opening to under 100 W, and 3 min 45 s from
relay 6 closing to drawing power (finding 12). Proposed: on is
`hp-odu-pwr >= HpOnPowerW` (per house, in the House0 family params; 300 W
proposed for maple, which idles under 100 W and dips to 45–170 W in a
defrost); off is low power with an off command at once, or low power
against an on command for 300 s. Of maple's 67 spring defrosts, 3 ran
under 500 W for longer than 300 s (p90 255 s, longest 950 s), and 5 of 37
other low-power stretches did; the cost of the tail is one trip to keep
and back. `hp-idu-pwr` is not usable at maple (its CT is attached to
nothing, finding 13). Staleness: every channel the loop reads is
`AsyncCapture` with `CapturePeriodS` 300, so a reading older than two
capture periods is missing, from `ScadaData.latest_channel_unix_ms`.

A defrost and a heat pump stopping itself look the same on power: both
fall to standby within seconds (maple 34–449 W for a self-stop, a median
73 W for a defrost; beech 20–74 W for both) and hold there for minutes. A
rule that reads "ran, then stopped while commanded on" from power
therefore fires on a defrost too: 64 of 67 at maple. At launch that rule
only acts during a start and only sends the valve to send, so the
confusion costs nothing. Anything that acts differently on the two needs
temperature to tell them apart: in a defrost the heat pump takes heat
from the water, so lift (LWT − EWT) goes negative, by about 4 °F or more
at beech. What lift does after a limit trip has not been measured; the
expectation is that it decays toward zero from above. Duration does not separate them (a dwell
long enough to exclude defrosts, over 250 s, loses most real stops).

Defrost proper: the valve wants to be at keep for as much of a defrost as
the 100 s travel allows. Noticing one is HpBoss's job or the heat pump
twin's, reported as a state in a new `hp.boss.state` version (000 is
published); `../executor/heat-pump-signatures/defrost-signatures.md` is the data. While
confidence builds, a glitch says whether the heat pump still completes its
defrost with the loop closed.

### Where the water is going

A send test relative to the destination (send once LWT is above where the
water is going, by a margin) only ever sends water that adds heat, and is
independent of `MaxEwtF`. The destination moves: the store top when the
plant is charging the store, the buffer top otherwise, and something else
again on a layout with no buffer or no water store. So the loop should ask
its hydronic tier for "the temperature of where heat pump water is going
now" and never name a tank; each layout family answers from its own flow
state. Open under this: whether the valve latches at send until the heat
pump stops or returns to keep when the destination changes to a hotter
one; and what to do when the heat pump cannot reach the destination (a
store its elements heated to 180 F). A heat pump held at keep reaches its
upper limit and stops itself, and repeated quick trips locked the LG out
at beech, so whatever the answer it acts on the first such stop, not after
several. Two candidates: fail open to send, which keeps the house warm and
is the launch behaviour; or tell HpBoss,
which turns the heat pump off with a critical glitch, on the view that
local control should never have asked. The second needs a report from the
loop to a peer (`SiegLoopReady` was the last such message and was ad hoc),
a state for HpBoss to report after turning off against an on command, and
a way for its boss to learn of it. The heat pump's maximum useful LWT
(about 140 F at maple, where average COP falls below 1) is a heat pump
fact and belongs with the heat pump.

### Per-heat-pump sequences and the twin

Beech rested at full send through 2025–26 to lower the chance of the valve
sticking at keep; the LG takes about two minutes from relay 6 to pump on
and 2.5 more to a small lift, so the loop moved to keep inside that gap,
and HpBoss's `PreparingToTurnOn` with `SiegLoopReady` exists for that
sequence. Mitsubishi has been asked to stop its primary pump with the heat
pump; once it does, maple can rest at send too. What a given heat pump
needs around a start, a stop and a defrost are facts about the heat pump
(`PrimaryPumpAlwaysOn`, `PrimaryPumpOverridable` on the device-type
record), and Modbus dispatch brings a digital twin that is their likely
home. Code shape wanted: one file, each sequence written out straight,
replication preferred over if/then parameterization. A heat pump start
SHALL NOT wait on valve travel: heat pumps are meant to provide fast
balancing.

### Sensing arrival

While the primary pump runs the flows confirm a stop: in finding 14
`sieg-send` fell 4.28 → 0.02 gpm and `sieg-flow` rose 0 → 5.11 gpm across
a move. A position estimate for blend control can start there. A stopped
hall flow channel reads its last small value, not zero (finding 16), which
is fixed first.

### Smaller things

- Where the valve choreography lives (a sieg tier under `hydronic/`, or a
  helper the loop owns): OPS-532.
- Season end: who sets `Standby`, which returns the valve to full send
  (OPS-400).
- Actors learning of a handle change when the tree is rewritten, not on
  their next tick.
- Removing the blend leftovers once it is settled what `LwtControl` reuses:
  `t1`, the fractional moves, `process_reset_hp_keep_value`,
  `process_sieg_loop_endpoint_valve_adjustment` and their gwsproto types.
