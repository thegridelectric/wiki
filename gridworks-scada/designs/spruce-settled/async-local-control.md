# Async local control (spoke)

Status: Draft · Pass 0 · Updated 2026-10-07 · Linear: OPS-532

**TO DO.** Not started; nothing here is built.

> What this is: the local control's top-state machine and call machine
> evaluate on events, at the moment an input changes, not on a 60 s
> pass that notices the change late. The launch keeps the pass; this
> spoke is the redesign that retires it.

## The problem

Both families evaluate their top state on a tick: House0's main loop
(`actors/local_control/house0/tou_base.py`, `MAIN_LOOP_SLEEP_SECONDS`)
and Nolan's `check` (`actors/local_control/nolan/buffer_only_tou.py`,
`TOU_CHECK_S`). A message from the cold watch moves the machine at
receipt, but every input with no message behind it waits for the next
pass, up to a minute late:

- a blind band is noticed by the pass, and a fresh reading in
  `ScadaBlind` returns to `Normal` only at the next pass;
- `HouseWarm` on-peak is noted, and the return to `Normal` waits for
  the first pass after the peak ends;
- the call in `ScadaBlind` follows the schedule at pass resolution;
- the band and the call in `Normal` are evaluated by the pass, from
  readings that arrived at their own moments.

The latency is small against a heating system, and the launch runs
with it. The structural cost is the one that matters: a tick-driven
machine lets a message be a hint the pass may or may not act on, and
the cold path grew exactly that shape (a machine that takes `HouseCold`
only from `Normal`, a watch that sends it once per spell). The
nolan-local-control spoke closes those two under OPS-392 with the
machines still ticking; this spoke is what removes the tick.

## The shape

Every input is an event, and the machine's transition table decides
what each means in each state.

- **Sensor inputs are messages, evaluated at receipt.** `HouseCold`,
  `HouseWarm`, the hp-watch's state, and the band readings themselves:
  a buffer reading triggers the band evaluation and, in `ScadaBlind`,
  `DataAvailable`.
- **Time inputs are timers armed at the moment the input is known.**
  Staleness: a timer armed at each band reading, `BLIND_S` out, fires
  `MissingData`. The tariff: a timer at each on-peak and off-peak
  boundary (the Nolan call machine already arms one, 120 s before each
  on-peak window). A warm pass on-peak arms the peak's end.
- **The pass goes.** What is left on it in House0 (the pump doctors,
  the forecast and temperature reads, `engage_brain`) moves to its own
  schedule or to the readings that feed it; that inventory is the first
  step of the work.
- **Repeats are no-ops.** A sensor that says the same thing twice moves
  nothing, so no sender needs a once-per-spell memory.

## Open

- Whether the Normal strategy machines (House0's two, Nolan's
  BufferOnly) are evaluated at each reading or on a slower timer of
  their own; a strategy that integrates over minutes may want the
  latter.
- Which timers survive a `Dormant` stay and which are re-armed at
  `WakeUp`.

## Order

After both simulated houses run in dev and the beta windows have
verified the launch behavior, so the redesign is measured against a
machine known to work.
