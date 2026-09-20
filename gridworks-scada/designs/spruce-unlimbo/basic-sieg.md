# basic-sieg

Status: Draft · Pass 0 · Updated 2026-09-20 · Linear: OPS-392

> What this is: a spoke of [`primary.md`](primary.md). The least the
> Siegenthaler loop has to do for maple and beech to take the branch: close
> the loop whenever the heat pump is off, decided from what the heat pump is
> measured to be doing, under state names that mean what they say, with the
> valve reachable from the admin panel. No blend control while the heat pump
> runs. A launch item, ahead of [`refactor-sieg.md`](refactor-sieg.md), which
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

Two machines: valve (`FullySend`, `FullyKeep`, `KeepingMore`, `KeepingLess`,
`SteadyBlend`) and control (`Initializing`, `Blind`, `HpOff`,
`HpStartingUp`, `HpHasLift`). In `HpOff` it drives to full keep (full send
when the ops `ActuationAuthority` is `Standby`, `sieg_loop.py:342`); in
`HpHasLift` it drives to full send.
There is no PID on the branch; the blend-control loop of the 2025–26 season
is kept for reading at scada `c55fe9eb` (`gw_spaceheat/actors/sieg_loop.py`
at that commit), and its rebuilt successor is unmerged ("FYI: the unmerged
PID branch"). Valve travel is timed, never sensed: 100 s full range,
position kept as a count of keep-seconds.

Whether the loop runs at all is an ops fact (`scada.py:185`,
`self.data.use_sieg_loop`), and the command tree puts `sieg-loop` directly
under the boss with the two valve relays beneath it (`scada.py` "set command
tree" docstring).

## What has to change

Each item names the field observation behind it. Every one gets its local
test first, failing, before the fix (a field bug gets its local test first).

1. **Off is measured, not assumed.** `SiegLoop` takes the heat pump's state
   from hp-boss's report of what it commanded. The loop SHALL decide on and
   off from `hp-odu-pwr` against a threshold, so the valve follows what the
   heat pump did. Maple's timings: 4 s from relay 6 opening to under 100 W;
   3 min 45 s from relay 6 closing to drawing power again. `hp-idu-pwr`
   cannot be part of the test: at maple its CT is installed and attached to
   nothing, and reads 0 W.
2. **Blind means blind.** `is_blind()` (`sieg_loop.py:283`) returns True for
   missing lift or power, and also when the heat pump still draws over 500 W
   two minutes after a commanded off. In the second case the scada sees
   fine; the heat pump is not doing what it was told. With item 1 that case
   is simply "on". `Blind` is for missing data only. What a blind loop does
   with the valve is open: today it drives to full send, the position that
   mixes the buffer.
3. **A restart with the heat pump off reaches full keep promptly.** At
   maple the loop sat in `Blind` at full send for four minutes after a
   restart (14:58:59 → 15:02:59) with lift and power both reporting; cause
   not traced. It also starts from an assumed `FullyKeep`, so its first act
   was a 110 s drive toward a full-send stop the valve was already on.
4. **The valve state names where the valve is.** A completed full-keep move
   reports `SteadyBlend` ("Movement f73e completed: 100 seconds, state
   SteadyBlend"), not `FullyKeep`.
5. **The admin panel moves the sieg relays.** With the loop in the tree the
   relays answer to `admin.sieg-loop.relay14/15`; the panel sends to
   `admin.relay14/15` and is refused as not the immediate boss. The only way
   to move the valve by hand at maple was a layout without the loop. Either
   the panel learns the handle each relay has in the current tree, or an
   admin takeover puts the valve relays directly under admin. The same rule
   refused local control at the maple restart (`auto.lc.n` to
   `auto.lc.n.sieg-loop.relay14`): find that sender and remove it.
6. **Defrost has a decision.** Maple's Mitsubishi, 67 defrosts in spring
   2026 (`experiments/2026-09-20-maple-starts-heating/` "Defrost profile"):
   about five minutes of reverse cycle at 0.5–1.5 kW with LWT 12 C under
   EWT, then the compressor stopped for about 130 s at 45–170 W, lift back
   after 8 minutes; median outdoor air 0 C, 49 minutes between defrosts.
   A bare power threshold reads each one as off for 2–4 minutes, longer
   than the valve's 100 s travel. A real off at maple fell under 100 W in
   4 s and stayed. Off therefore needs more than the threshold: the
   command and the power agreeing closes the loop at once; low power
   against an on command waits out a defrost (p90 255 s under 500 W)
   before it counts as off. What the valve does during the defrost is
   open: at full send the 28 C water goes to the buffer, at full keep the
   heat pump takes its defrost heat from the small loop alone.

## Ops surface

Closing the loop when the heat pump is off is wanted at every house with a
sieg valve; blending while it runs is a separate choice. The ops word already
says whether the loop is used. It gains what lets the blend control be
switched on and off on top of the off-closes-the-loop behaviour without a
layout change, and the off threshold of item 1. The blend control itself is
not built here; this spoke fixes where its switch lives so that adding it
later is an ops change and a code change, never a layout change.

The threshold and the switch are ops fields, so they are sema work on
`gw.operational.params`: check its status first (staging is edited in place,
published takes a new version).

## The command surface the loop has needed from outside

Three LTN dev senders were the troubleshooting surface during the 2025–26
season. The senders are gone; the scada-side receivers remain (`scada.py`
`process_reset_hp_keep_value`,
`process_sieg_loop_endpoint_valve_adjustment`). Item 5's admin surface needs
these three moves, since timed travel loses count after any hand move:

- **Reset the keep value** (`reset.hp.keep.value`, `HpKeepSecondsTimes10`):
  tell the loop where the valve is, in seconds of keep.
- **Send harder** (`sieg.loop.endpoint.valve.adjustment`, `HpKeepPercent 0`,
  `Seconds`): drive toward full send for the given seconds.
- **Keep harder** (same word, `HpKeepPercent 100`, `Seconds`): drive toward
  full keep for the given seconds.

The endpoint word commands a duration, not a state; every other command in
the tree names a state.

## Not assumed

`SiegLoop` sits on `House0Hydronic`. A fall layout has a Siegenthaler loop
with no buffer tank and no iso valve, so nothing added here reads a buffer,
an iso valve or a store tank. The loop reads heat pump power, LWT, EWT and
its two relays. Where the valve choreography finally lives (a sieg tier
under `hydronic/`, or a helper the loop owns) is post-launch, OPS-532.

## Open

- The off threshold, and whether on and off use one threshold or two with a
  hold between them.
- What `Blind` does with the valve: hold, full keep, or full send.
- Defrost: the valve's position during one, and the wait before low power
  against an on command counts as off.
- The name and action for a heat pump that ignores its command. It may
  belong to hp-boss, which issued the command, and not to the loop.
- Admin: panel learns tree handles, or takeover flattens the valve relays.
- The loop's two state enums and their events are defined inline in
  `sieg_loop.py`; every other actor's states are sema enums. Items 2 and 4
  rename states, which is the moment to give them registry words.
- Whether beech wants the same off posture. Its LG runs the primary pump
  on a timer, so the mixing that forces full keep at maple may not occur;
  the code carries this as an OFI at `sieg_loop.py:334`.
- Season end: who returns the valve to full send (OPS-400 sets the Standby
  posture).

## Do this next

Walk the Open list with the human and settle the off rule, the `Blind`
action and the admin choice; that is this spoke's first pass. The first
build step after it is the failing tests in `tests/actors/test_sieg_loop.py`
on the simulated House0: a restart with the heat pump off and the valve at
full send reaches `FullyKeep` within one travel time (item 3), and a
completed full-keep move reports `FullyKeep` (item 4).

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
