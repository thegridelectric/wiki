# basic-sieg

Status: Draft · Pass 0 · Updated 2026-09-20 · Linear: OPS-392

> What this is: a spoke of [`primary.md`](primary.md). The least the
> Siegenthaler loop has to do for maple and beech to take the branch: keep
> the valve at full keep unless the heat pump is measured to be running
> with a hot loop, under state names that mean what they say, with the
> valve commandable from the admin panel. It is the
> `ProtectStratificationOnly` strategy of a three-way ops switch; the blend
> machinery leaves the branch. A launch item, ahead of [`refactor-sieg.md`](refactor-sieg.md), which
> exercises whatever this spoke leaves on the branch.

## Why

Maple's primary pump sits inside the Mitsubishi and the scada cannot switch
it; it runs whether or not the heat pump does. With the valve at full send
and the heat pump off, that pump circulates the buffer and mixes it. Measured
at maple on 2026-09-20 (`experiments/2026-09-20-maple-starts-heating/`,
findings 12 and 14): `buffer-depth1` fell from 103.2 F to 95.3 F in twelve
minutes with the valve at full send, `sieg-send` steady at 4.3 gpm and
`hp-odu-pwr` under 100 W; with the loop closed it held within 0.3 F. A house
whose primary pump never stops loses its stored hot water unless the loop
closes every time the heat pump stops.

The same window showed the loop on scada `main` doing this, and where it
falls short. The branch's `SiegLoop` carries the same logic
(`gw_spaceheat/actors/sieg_loop.py` on `jm/spruce-unlimbo` @ `8f76cf68`),
so every shortfall below is the branch's too.

## What the loop does today

One 638-line actor (`gw_spaceheat/actors/sieg_loop.py` @ `8f76cf68`) with
two machines: valve (`FullySend`, `FullyKeep`, `KeepingMore`, `KeepingLess`,
`SteadyBlend`) and control (`Initializing`, `Blind`, `HpOff`,
`HpStartingUp`, `HpHasLift`). In `HpOff` it drives to full keep (full send
when the ops `ActuationAuthority` is `Standby`, `sieg_loop.py:342`); in
`HpHasLift` it drives to full send. Valve travel is timed, never sensed:
100 s full range, position kept as a count of keep-seconds. The command
tree puts `sieg-loop` directly under whichever boss holds the tree, admin
included, with relays 14 and 15 beneath it (`scada.py:1259`). The
blend-control loop of the 2025–26 season is kept for reading at scada
`c55fe9eb`; its rebuilt successor is unmerged ("FYI: the unmerged PID
branch").

Five things in it are not sensible, each answered under "The design":

1. `Blind` is a peer of the working states, with six transitions to leave
   it, and it mixes missing data with a heat pump that ignores its command
   (`is_blind`, `sieg_loop.py:283`).
2. A control state does not fix the valve's posture: `HpOff` means full
   keep or full send depending on `ActuationAuthority`.
3. The control state is re-sent every control tick, changed or not
   (`main`, `sieg_loop.py:194`).
4. The valve machine is not reported (the send in `trigger_valve_event` is
   commented out), starts from an assumed `FullyKeep`, and reports
   `SteadyBlend` when the valve sits on a stop.
5. About 250 lines are blend machinery (`t1`, `t2`, fractional moves,
   keep-seconds arithmetic, `moving_to_just_keep`) that a stop-to-stop
   strategy never uses.

`HpHasLift` is also misnamed: its entry test is
`max(lwt, ewt) > MaxEwtF - 20` (`hp_loop_is_getting_hot`), a hot loop, not
lift.

## The design

This was never mature production code, so it is rebuilt small, not
chipped. Every piece below gets its test first, failing, on the simulated
House0.

### Shape

Modelled on local control (`actors/local_control_loader.py`): a facade
picks an implementation from the ops params, and each implementation is
its own short file.

- `actors/sieg_loop.py`: the `SiegLoop` facade, the actor the layout names.
  It owns the valve, the command surface and the reporting, and asks its
  strategy one question each tick: which stop is wanted.
- `actors/sieg/valve.py`: `SiegValve`, the only code that touches relays
  14 and 15. One primitive, `drive_to(stop)`.
- `actors/sieg/hold_full_send.py`: `HoldFullSend`. `wanted_stop()` returns
  send, always.
- `actors/sieg/protect_stratification.py`: `ProtectStratificationOnly`.
  When it cannot see what it needs it returns what its own `HoldFullSend`
  instance returns: the fall-back is that code, not a copy of it.

The facade picks `HoldFullSend` when `ActuationAuthority` is `Standby`
(the OPS-400 posture), whatever the strategy field says; otherwise the
strategy field decides. `LwtControl` raises at construction until it is
built. The pick is made once, at construction, as local control's is.
This answers 1 and 2: `Blind` is one code path with one posture, and the
`Standby` branch inside `HpOff` goes.

### The valve

```
class SiegStop: Send | Keep
FULL_RANGE_S = 100; OVERSHOOT_S = 10

state: PositionUnknown | FullySend | MovingToFullKeep | FullyKeep
       | MovingToFullSend
target: SiegStop | None        # None only in PositionUnknown

drive_to(stop, cause):
    if target == stop: return            # there, or already on the way
    cancel any drive in flight; open both relays
    target = stop
    state = MovingToFullKeep | MovingToFullSend; report(cause)
    energize the relay for that direction for FULL_RANGE_S + OVERSHOOT_S
    open it; state = FullyKeep | FullySend; report(cause)

redrive(stop, cause): target = None; drive_to(stop, cause)
```

Every drive is the full range plus overshoot, whatever the valve's
position, so a completed drive always ends on the stop and the valve
needs no position count. A drive cancelled part way costs nothing: the
next one is again a full drive. The state starts `PositionUnknown` and the
first `drive_to` comes from the facade's first tick after the actuators are
ready, so a restart with the heat pump off reaches `FullyKeep` within one
drive (110 s); the four-minute stall at maple (finding 15) came through
`Blind`, which no longer exists as a place to wait. This answers 4 and 5:
the stops are named, and `keep_seconds`, `t1`, `t2`, the fractional moves,
`moving_to_just_keep`, the `hp_keep_seconds_x_10` TODO and the two scada
receivers under "Retired with the blend machinery" all go. The relay
direction and the relay command events are today's
(`_keep_more` / `_keep_less`).

### Reporting

The valve state is what the `sieg-loop` handle reports, through
`single.machine.state`, on change only (answers 3). No new layout node.
`Cause` carries why: `HpOff`, `HpStartingUp`, `HpLoopHot`, `Blind`,
`HoldFullSend`, `Commanded`, `Startup`. The strategy's own state is
logged, not reported: each of its states fixes one stop, so the reported
stop with its cause loses nothing. A blind episode also sends one warning
`glitch` naming the missing channel, at its start.

### ProtectStratificationOnly

Three states, decided from measurement:

```
HP_LOW_POWER_OFF_WAIT_S = 300      # maple defrost: p90 255 s under 500 W

on_now   = hp-odu-pwr >= HpOnPowerW
low_for  = seconds hp-odu-pwr has been continuously < HpOnPowerW
commanded_on = hp-boss last reported HpOn

tick():
    if blind(): return hold_full_send.wanted_stop()      # cause Blind
    match state:
      HpOff:        if on_now: state = HpStartingUp
      HpStartingUp: if is_off(): state = HpOff
                    elif loop_hot(): state = HpLoopHot
      HpLoopHot:    if is_off(): state = HpOff
    return Send if state == HpLoopHot else Keep

is_off():   not on_now and (not commanded_on
                            or low_for >= HP_LOW_POWER_OFF_WAIT_S)
loop_hot(): max(lwt, ewt) > MaxEwtF - 20        # today's test, kept
blind():    hp-odu-pwr missing
            or (state != HpOff and (lwt missing or ewt missing))
```

- Off is measured (finding 12: 4 s from relay 6 opening to under 100 W;
  3 min 45 s from relay 6 closing to drawing power). Command and power
  agreeing is off at once. Low power against an on command is a defrost
  or the heat pump stopping its own compressor, and counts as off only
  after the wait, so a defrost (finding 17) leaves the valve where it is.
- `HpLoopHot` latches until off, as `HpHasLift` does today.
- The initial state is `HpOff`; with the heat pump already running the
  first ticks walk it forward.
- `hp-idu-pwr` is not read: at maple its CT is attached to nothing
  (finding 13).
- Blind is narrow on purpose. With the heat pump measured off, missing
  temperatures change nothing and the valve stays at keep; a dead
  temperature sensor SHALL NOT mix maple's buffer overnight. A running
  heat pump is never left in a closed loop the scada cannot see into.
- A heat pump that ignores its command is simply on or off here. Naming
  and reporting it is not the loop's job ("After launch", HpTwin).

### Command surface

`sieg-loop` joins hp-boss and five-v-boss as a command node
(`executor/control-hierarchy.md` "Command interfaces and replies"): the
two authority checks in order, `gw.dispatch.ack` / `nack` through
`command_reply.py`, `ActorClass.SiegLoop` added to
`Scada.COMMAND_NODE_CLASSES`, and one vocabulary in
`Scada.COMMAND_NODE_INTERFACES`:

| Event | Resulting state |
| --- | --- |
| `MoveToFullSend` | `FullySend` |
| `MoveToFullKeep` | `FullyKeep` |

```
process_fsm_event(from_node, payload):
    the two authority checks (bad_sender glitch; NotMyBoss nack)
    unknown EventName -> nack UnknownEvent
    ack
    commanded_by = boss part of my handle
    valve.redrive(stop, cause=Commanded)

tick():
    if commanded_by is not None:
        if boss part of my handle == commanded_by: return
        commanded_by = None                  # the tree changed hands
    valve.drive_to(strategy.wanted_stop(), cause)
```

- A command takes the loop out of automatic control until the tree changes
  hands. Admin's release rewrites the handles (`set_command_tree`), which
  is that change; no release message is needed. Without this the loop
  would drive back within one tick of the operator's move.
- `redrive` makes a command to the stop the valve is already on a fresh
  full drive. That is how an operator re-homes the valve by hand, and it
  replaces the three dev senders of the 2025–26 season.
- A command during a drive cancels it and starts the commanded one; there
  is no `Busy`.
- The tree needs no change: `sieg-loop` already sits directly under the
  boss, admin included, with its relays beneath it, in both copies of the
  rewrite (`scada.py:1259`, `command_node.py`). The panel commands
  `admin.sieg-loop`; relays 14 and 15 are the loop's and the panel has no
  business addressing them (finding 4 goes away by design, not by a
  takeover that flattens the tree).
- Nothing but `SiegValve` addresses relays 14 and 15. At the maple restart
  on `main`, `auto.lc.n` sent to `auto.lc.n.sieg-loop.relay14` and was
  refused; no such sender is visible in `local_control/` or `hydronic/` on
  the branch. A test asserts it: through a simulated day no `fsm.event`
  to relay 14 or 15 has a `FromHandle` other than the loop's.

### HpBoss

**A turn-on closes relay 6 at once.** With both houses resting at full
keep and a start never waiting on valve travel, `SiegLoopReady` decides
nothing, and the one thing the handshake can still do is open relay 6 and
alert when the message is late (`hp_boss.py` `_waiting_to_turn_on`,
120 s). HpBoss's turn-on becomes one path: close relay 6, `HpOn`, report.
`SiegLoopReady`, `_waiting_to_turn_on` and the `use_sieg_loop` branch in
HpBoss go. `hp.boss.state` 000 is published and stays as it is;
`PreparingToTurnOn` is simply not entered. A turn-on that arrives while
the valve is still travelling to keep sends startup water toward the
buffer for up to one travel time; accepted.

### Sema work

All in the ops params and new enums; no layout word changes. Each new word
follows the sema authoring protocol (spec spokes read, summary posted,
confirmation) before any edit; the names below are proposals until then.

- `gw.house0.family.params` 000 (staging, edited in place; referenced only
  by `gw.operational.params`): `UseSiegLoop` is replaced by
  `SiegLoopStrategy`, and `HpOnPowerW` is added, both required.
- Enum `sieg.loop.strategy`: `HoldFullSend`, `ProtectStratificationOnly`,
  `LwtControl`. `LwtControl` is blend control of LWT while the heat pump
  runs, on top of the stratification protection. Timed travel drifts under
  many small moves, because the valve sticks for a short unknown time
  before it starts to move, so that strategy owes an occasional drive to a
  stop to re-zero.
- Enum `sieg.valve.state`: `PositionUnknown`, `FullySend`,
  `MovingToFullKeep`, `FullyKeep`, `MovingToFullSend`.
- Enum `move.sieg.valve`: `MoveToFullSend`, `MoveToFullKeep`.
- gwsproto mirrors for each; `use_sieg_loop` leaves `scada.py`
  (`:185`, `:208`, `:1259`, `:1686`) and the `command_node.py` copy. A
  `gw.house0.layout` house always has the loop; a house without the valve
  is the `gw.house0.no.sieg` word.

### Retired with the blend machinery

`scada.py` `process_reset_hp_keep_value` and
`process_sieg_loop_endpoint_valve_adjustment`, with their gwsproto types
if nothing else reads them (`reset.hp.keep.value`,
`sieg.loop.endpoint.valve.adjustment`; the registry words stay). Their
senders are already gone. `SiegValveState`, `SiegValveEvent`,
`SiegControlState` and `SiegControlEvent`, inline in `sieg_loop.py`, go
with the file's rewrite. The blend control is kept for reading at
`c55fe9eb` and on the unmerged PID branch, and returns as `LwtControl`.

### Tests, on the simulated House0 (`tests/actors/test_sieg_loop.py`)

1. Restart with the heat pump off: `PositionUnknown` → `MovingToFullKeep`
   → `FullyKeep` within 110 s of actuators ready; the keep relay is
   energized for 110 s and both relays end open.
2. Power rises over `HpOnPowerW` with a cold loop: the valve stays at
   keep. The loop passes `MaxEwtF - 20`: drive to send, `FullySend`.
3. Commanded off and power under the threshold: drive to keep at once.
4. Commanded on, power under the threshold for 299 s, then back: no move.
   For 300 s: drive to keep.
5. No `hp-odu-pwr`: full send, one glitch. Temperatures missing with the
   heat pump off: stays at keep, no glitch. Temperatures missing with it
   on: full send.
6. `Standby` authority with `ProtectStratificationOnly` in the params: the
   facade runs `HoldFullSend`.
7. Admin `MoveToFullSend` while the strategy wants keep: acked, driven, and
   the valve stays at send across ticks; after the tree returns to local
   control the loop drives back to keep. A mis-sendered and a stale-handle
   command move nothing (the impostor and stale cases of
   `test_dispatch_replies.py`).
8. A command to the stop the valve is on runs a fresh full drive.
9. One report per valve state change and none between.
10. HpBoss: a turn-on from `HpOff` closes relay 6 and reports `HpOn` with
    no wait.
11. No sender but the loop addresses relay 14 or 15.
12. The capability cover lists `sieg-loop` with its two events.

### Verification (EDD)

A bounded window at maple, then beech, on the branch: a restart with the
heat pump off reaches full keep, confirmed by the flows (`sieg-send` to
zero and `sieg-flow` up, as in finding 14); admin moves the valve to send
and back from the panel; a heat pump start leaves the valve at keep until
the loop is hot, then sends; a stop closes the loop within one drive.

## Launch posture, and what waits

The launch bar is service as good as what is in the field, in code that is
simple to understand. At launch both houses rest at full keep whenever the
heat pump is off, one code path. A valve resting at full keep needs no move
before a start, so `SiegLoopReady` is immediate and the heat pump's ramp is
not delayed. That matters beyond launch: heat pumps are meant to provide
fast balancing, and a start SHALL NOT wait on valve travel (a 110 s drive
before closing relay 6 was considered and rejected).

Beech rested at full send through the 2025–26 season to lower the chance
of the valve sticking at full keep. The LG takes about two minutes from
relay 6 to pump on and about 2.5 more to a small lift
(`7dffe040:gw_spaceheat/actors/sieg_loop.py:140`), so the loop answered
`SiegLoopReady` at once and moved to keep inside that gap; HpBoss and its
`PreparingToTurnOn` state exist for this sequence. Resting at full keep at
beech is a launch simplification, accepted for now.

After launch:

- **Per-heat-pump startup, steady-off and shutdown sequences.** Mitsubishi
  has been asked to stop its primary pump when the heat pump stops; once it
  does, maple also rests at full send and needs the move to keep ahead of a
  start. The heat pump device-type record carries the facts
  (`PrimaryPumpAlwaysOn`, `PrimaryPumpOverridable`). The code shape wanted:
  one file, each sequence written out straight, replication preferred over
  if/then parameterization. On the branch today `SiegLoopReady` goes out on
  the `PreparingToTurnOn` transition, before the move to keep starts
  (`sieg_loop.py:421`); harmless while the valve rests at keep, wrong for a
  house resting at send. "HpBoss" above removes that handshake for launch;
  the in-between state returns here with real content, in one new
  `hp.boss.state` version alongside the defrost state.
- **HpTwin.** Modbus dispatch for the various heat pumps brings a digital
  twin of the heat pump. What a given heat pump needs around a start, a
  stop and a defrost, and what it is measured to be doing, are facts about
  the heat pump, so the twin is their likely home; nothing built for launch
  should make HpBoss or the loop a second home for them.
- **Arrival at a stop can be sensed.** In finding 14 `sieg-send` fell
  4.28 → 0.02 gpm and `sieg-flow` rose 0 → 5.11 gpm across the move.
  While the primary pump runs, the flows confirm a stop; `LwtControl`,
  which needs a position, starts from that. A stopped hall flow channel
  reads its last small value, not zero (finding 16), which is fixed first.
- **Defrost.** The valve goes to full keep for as much of a defrost as
  possible. HpBoss is responsible for noticing a defrost and saying so: a
  state in a new `hp.boss.state` version (published, so 001) reaches
  reports through HpBoss's existing state report, and a derived channel
  follows if the data services want one. While confidence is being built,
  a glitch reports whether the heat pump still completes its defrost with
  the loop closed. How early a defrost can be recognised decides how much
  of it the 100 s travel can cover; the 67 spring signatures
  (`experiments/2026-09-20-maple-starts-heating/defrost_hunt.py`) are the
  data for that.

## Not assumed

`SiegLoop` sits on `House0Hydronic`. A fall layout has a Siegenthaler loop
with no buffer tank and no iso valve, so nothing added here reads a buffer,
an iso valve or a store tank. The loop reads heat pump power, LWT, EWT and
its two relays. Where the valve choreography finally lives (a sieg tier
under `hydronic/`, or a helper the loop owns) is post-launch, OPS-532.

## Open

Desk checks, each before the slice that depends on it, none a design
decision:

- `HpOnPowerW` per house. Maple idles under 100 W and dips to 45–170 W
  inside a defrost; 300 W is the proposal there. Beech's idle draw is read
  from the journal before its params are written.
- How the loop knows a reading is stale, not only absent. Today "missing"
  means never received, so a sensor that dies keeps its last value. Read
  what timestamps the actor's channel data carries; if it has them, blind
  takes an age bound, and the slice says which.
- The type of `single.machine.state` `Cause`, and whether the causes above
  fit it as written.
- That the admin panel renders any command node in
  `scada.control.capabilities` without a panel change, as it does hp-boss
  and five-v-boss.
- Season end: who sets `Standby`, which is what returns the valve to full
  send (OPS-400).
- After launch, whether HpTwin replaces HpBoss or sits beside it.

## Do this next

Fold the opening adversarial round into this spoke. The round returned
sixteen blocking findings and no approval; the review, and the check of
each finding's evidence against the branch, are in
`scratch/basic-sieg/` (`sol-r1.md`, `fable-r1-verification.md`). Take the
findings that hold in this order, since the early ones reshape the rest:

1. The valve's real drive sequence and its failure posture, as one
   problem. Relay 15 selects the direction and relay 14 runs the motor, and
   relay 14 is wired normally closed: de-energized, the valve is being
   driven. "Open both relays" in "The valve" has the polarity inverted, and
   a scada crash or power loss part way through a drive leaves the valve
   travelling to a stop, not held. So: what `SiegValve` does with relay
   acks, nacks and full reports; one owner for a drive; what a cancelled,
   failed or interrupted drive leaves behind; what startup does on finding
   relay 14 de-energized.
2. The strategy's ordering (measured off is decided before blind), a
   bounded way out of `HpStartingUp`, the freshness bound, and the
   low-power wait against the defrost data at the chosen threshold. The
   send condition is replaced: `MaxEwtF` is the `heating.curve` field for
   what the distribution system tolerates (170 at maple and beech), not a
   heat pump fact, and `MaxEwtF - 20` is 150 F where maple's Ecodan has
   never been seen above about 145 F LWT, so on the branch the valve never
   leaves keep there. Chosen: the relative test. The loop sends once LWT
   is above the temperature where the water is going by a margin, so it
   only ever sends water that adds heat; "Not assumed" is relaxed to let
   the loop read that one destination temperature, named by the layout and
   never assumed to be a buffer. The heat pump's maximum useful LWT (about
   140 F at maple, where average COP falls below 1) is a separate fact that
   belongs with the heat pump. When the heat pump cannot reach the
   destination's temperature (a store its elements have heated to 180 F,
   say), holding keep is no answer: the loop tells HpBoss, HpBoss turns
   the heat pump off and sends a critical glitch. It should not happen,
   since local control should not ask the heat pump for what it cannot do,
   which is why it is critical. This is also the bounded way out of
   `HpStartingUp`. To settle in the fold: the rule for "cannot reach" (LWT
   at the heat pump's maximum, or no progress for a time), the message
   from the loop up to its boss (a report, not a command; `SiegLoopReady`
   was the last one and was ad hoc), the state HpBoss reports after
   turning off against an on command, and how its boss learns of it.
3. `MonitorOnly` never actuates; layout presence, not ops, is the
   predicate at every site `use_sieg_loop` gates today; the local control
   and leaf ally senders to the valve relays go.
4. The command surface: `EventType` with `EventName`, the trigger kept
   through the drive, the full report to the journal, release on the tree
   change itself, and what the panel offers in the unknown and moving
   states.
5. The sema items the round added: the House0 layout word's prose about
   the loop, and `HpOnPowerW`'s type, range and per-house values.

Then write `fable-r1-response.md` (folded, rejected with reason) and run
round 2 on a fresh thread. The human pass follows approval or the
four-round cap.

## FYI: the unmerged PID branch

Not acted on by this spoke; recorded so the next pass can decide what to do
with it.

Checked directly: the branch and its tip, the files named, that it is
unmerged, and that `pid.py` never mentions defrost. The rest is from one
read-through of the branch and wants confirming before anything is built
on it.

A rebuilt blend control exists, unmerged, on scada `origin/td/sieg-pid`
(@ `eca8d565`, 2026-06-16; in none of `main`, `dev`, `jm/spruce-unlimbo`;
about 35 commits from 2026-04-28).

- **Shape.** `gw_spaceheat/actors/sieg_loop_loader.py` is a `SiegLoop`
  façade that runs either `sieg_loop/fallback.py` (today's simple loop,
  with already-at-endpoint guards added) or `sieg_loop/pid.py`, chosen by a
  `SiegLoopMode` setting that defaults to the fallback. It promotes to PID
  only when a required-channels health check passes, and hands
  `keep_seconds`, valve state and hp-boss state across on a swap so the
  valve does not jump. `sieg_loop/pid_old.py` is the 2025–26 loop.
- **Control law.** Holds LWT at the `SetTargetLwt` local control sends.
  30 s steps; output in seconds of valve travel, clamped to ±30 s a step
  and to the 0–100 s range; 0.5 s deadband; integral capped. Gains are
  Ziegler–Nichols values as code constants (`pid.py:151`), the same
  numbers the 2025–26 loop carried. A startup hover parks the valve just
  inside keep, watches the LWT slope, and opens so the valve arrives as
  LWT reaches target; closed loop starts after a settle.
- **Maple.** Valve travel map retuned (`t1 = 26`, `t2 = 82` against 7 and
  67). Indoor-unit power dropped from the required channels for
  `MitsubishiEcodan`.
- **Missing.** No defrost handling (`executor/defrost-signatures.md` is
  what it would need). No recorded tuning results: no commit message or
  comment says what oscillated or held, and the last commits are test
  hacks (buffer forced empty, 120 F target) and their reverts.
- **Cost to carry over.** It forked from `dev` on 2026-06-12, before the
  node-actor partition: `pid.py` subclasses the old `ShNodeActor` and reads
  settings that have since moved to ops, and `SiegLoopMode` is not in
  gwsproto. The work is a rebase onto the partition, and the gains belong
  in ops with the rest.
