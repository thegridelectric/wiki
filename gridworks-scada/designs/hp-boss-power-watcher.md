# hp-boss power watcher

Status: Draft · Pass 0 · Updated 2026-11-12 · Linear: OPS-673
**EDD: yes** — verified by a scada restart into a running heat pump at
maple, reproduced locally against a real broker, that raises the critical
glitch and keeps the sieg loop open until the unit stops.

> What this is: the heat pump boss watches the unit's measured draw
> against the state of its call, per heat pump model, and raises a
> critical glitch when the unit draws running power when the boss
> believes it should not. The per-model knowledge (stop lag, minimum run
> after a start, on and off lines) lives in one device-type record, and
> the boss, the sieg loop and the watcher all read the one sensed state.

## The incident

2026-11-11 15:14 ET, maple. The old scada called the heat pump on at
15:10:13. The restart at 15:14:40 found the Ecodan 4.5 minutes into its
start at 1.7 kW. The new hp-boss booted in HpOff and opened the call; the
sieg loop read HpOff and homed to full keep for 104 s against a running
compressor. The unit kept drawing (an off in the first minutes of a run
is honored up to about five minutes late; `executor/heat-pump-signatures/startup-signatures.md`
"Mitsubishi Ecodan (maple)"). LocalControl called it on again 87 s later;
LWT reached 58.4 C and the unit stopped itself at 15:20. No glitch, no
Blind, no log line said the unit was running against an open call.

Why nothing noticed: hp-boss does not read power; hp-watch reads it but
exists on Nolan layouts only and reports state, not a fault; the sieg
loop's blind rule arms on a transition into HpOff that a boot never
makes, and its 120 s settle is shorter than the Ecodan's late honor.

## Decisions so far

- **hp-boss opens the call on every off.** It never refuses an off. What
  the Ecodan finding changes is the state it reports: HpOff is a claim
  about the unit, and the boss reports the truth (call open, unit still
  running) until the sensed draw says the compressor has stopped. An off
  commanded inside the model's minimum run is a Warning glitch.
- **The sieg loop holds the loop open until the unit has stopped**, read
  from the sensed state, not from the relay command. Today it goes to
  full keep the instant hp-boss says HpOff.
- **One sensed state per unit, running or stopped**, read from hp-odu
  power with the model's on and off lines, on every layout. hp-watch
  does this on Nolan layouts today; it becomes the heat pump's state
  everywhere, and hp-boss and the sieg loop read it.
- **The watcher is armed from the sensed draw at boot**, not from a
  transition it waits to see. The boot case is the first thing it
  catches.
- **Two graces per model, from the device record:** the stop lag after
  an off on a steady run (Ecodan 5 s; Samsung unmeasured, up to four
  minutes on a young run) and the minimum run after a start (Ecodan
  about five minutes). Running power against an open call beyond the
  applicable grace is a Critical glitch. `HP_TRAITS` in
  `actors/hp_boss/sensing.py` is the placeholder the record retires.

## Open

- Where the record lives: `hp.device.type.gt` in sema, or the layout's
  component attributes, and what the Ecodan row says for a call that
  opens under 60 s into a start (unseen).
- Modbus: when a unit reports its own state, the watcher reads that and
  the power lines become the cross-check.
- The sieg control state refactor runs alongside this; the sensed state
  is what both read.

## Do this next

Write the local test: boot a House0 sim with the sim heat pump drawing
running power and the call open, assert the Critical glitch and that the
sieg loop does not leave full send until the draw falls under the off
line. It fails today.
