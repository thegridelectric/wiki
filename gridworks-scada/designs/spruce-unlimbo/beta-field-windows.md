# Beta field windows

Status: Draft · Pass 0 · Updated 2026-09-19 · Linear: OPS-392

> What this is: the recurring field test of the `jm/spruce-unlimbo` code.
> After roughly each spoke the branch runs in a bounded window on one house
> of each layout family. This spoke says how a round runs, how its record
> is kept, and what the rounds have taught about running them. It is not a
> workstream in the hub's ordered list; it runs between them.

## Why rounds, and why now

The suite, the sim driver and the tlayouts twins agree with a layout by
construction. None of them says a real house boots on the generated pair,
that the actors needing hardware start, or that the relays end up where
the log says they did. A window on the box does. Running one after each
spoke keeps the distance between a change and its first contact with a
house to one spoke, so a field failure points at a small diff.

## Houses

One house per layout family per round:

- **spruce** for `gw.nolan.layout`, `ActuationAuthority` Active. In the
  heating season the winter hack is the plant controller and
  `NolanLocalControl` holds zones off and turns the heat pump off, so a
  spruce window is short and always bounded.
- **beech** for `gw.house0.layout`, `ActuationAuthority` Standby. Beech
  carries the siegenthaler loop; a loop left fully closed while the heat
  pump runs trips the heat pump, so relay positions are checked against
  the bus, not only against the log.
- **one of fir / elm / oak** for `gw.house0.no.sieg`, from the round after
  `house0-no-sieg-layout.md` ships its word and gens.

A round MAY skip a family the spoke could not have touched; the round's
logbook line says which families ran.

## A round

1. **Read the folder README's "Process" section** and the mysteries it
   lists. Pick the ones this round can shed light on and decide what
   evidence would do it, before anything is switched on.
2. **Pre-flight.** `./<house>_window.sh status` on each house. Push the
   scada head and pull it on the box; regenerate the window pair if the
   spoke changed a gen and place it with `put_layout.sh <house> <change>`.
   `on` refuses when the box checkout or the window pair is behind, so a
   refusal is the pre-flight doing its job.
3. **Start the captures first**, then `./<house>_window.sh on <minutes>`.
   Watch with `gwa watch <house>`.
4. **Close** with `off` if the bound has not already closed it, and check
   `status` shows the recorded plant services running again.
5. **Record in the same sitting**, per the `experiments/README.md`
   conventions: evidence with provenance headers, a `gw.experiment.run`
   instance per house, a logbook line, and the README brought current.
6. **Route what the round found.** A defect goes to the spoke that owns the
   code, or to `odds-and-ends.md` when none does. An executor claim the
   round verifies gets its `Reviewed` pointer at the folder.

## The record

Every round adds to one folder,
`experiments/2026-09-18-beta-field-windows/`. Evidence files and instances
accumulate, named by house and window stamp. The README does not
accumulate: it states what is known now and what is still a mystery, and
each round rewrites it. A mystery a round resolves leaves the list and
its answer joins what is known; how the understanding got there is in git
history and the logbook.

While the branch is off `main` the README carries a temporary **Process**
section: the round steps above in runnable form, the distillation rule,
and the current mystery list. A PreToolUse hook on Bash commands matching
`_window.sh on` prints that section into the session before the window
opens, so a round cannot start without it. The section and the hook are
removed when `deployment.md` completes.

## What the rounds have taught

- **Bracket the actuation with the bus capture.** In round one the beech
  port samples started after the sieg move and nothing sampled spruce's
  gw108 register, so neither relay transition was witnessed on the bus.
  The capture starts before `on` and runs past the last expected
  actuation.
- **Prove the broker-side subscriber connects before `on`.** Round one's
  `mosquitto_sub` on `localhost:1885` was refused for a bad user, and the
  upstream link never found a peer, so the window's events exist only on
  the boxes and in the folder.
- **Two clocks.** The box clocks run about 70 s behind the laptop. Event
  filenames are UTC, log lines are box-local ET, and a timeline written on
  the laptop is laptop time. State which clock every stamp is on.
- **Relay state is not a reading.** Relay-state channels are absent from
  `ChannelReadingList` because a report carries them in `StateList`; the
  absence is not missing data.
- **Count channels against both lists.** A layout's `DataChannels` and
  `DerivedChannels` together are the names a report can carry.

## Do this next

1. Clean up the experiment folder: the README onto
   `experiment-README-template.md`, the scripts speaking sema through the
   `gwexp` snapshot, the Process section written, and the first
   distillation of round one into known and mystery.
2. Build the window-open hook.
3. Run round two when `cold-house-derived-setpoint.md` wraps.

## Open

- How rounds are told apart in instance filenames. The window stamp as the
  condition field (`spruce-20260918.192107-gw.experiment.run-000.json`) is
  the candidate; round one's two files carry no condition.
- Whether a round that finds nothing still rewrites the README or leaves
  only a logbook line.
