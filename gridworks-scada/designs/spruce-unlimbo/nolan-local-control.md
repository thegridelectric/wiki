# Nolan local control (spoke)

Status: Accepted · Pass 1 · Updated 2026-10-06 · Linear: OPS-392

> What this is: what is left on Nolan local control, what to check as
> the code runs in the field, and the brief for the adversarial review.
> What is built is specified in `executor/local-control.md` and
> `executor/cold-house.md`; this spoke does not repeat it.

## Do this next

**▶ DO THIS NEXT: step 1.** With it, `LocalControlTopEvent` in gwsproto
drops its sema URL, which cites a word that does not exist.

1. **Backup** ("Backup" below).
2. **Code review from sol** ("For the review" below).
3. **Run in the beta windows for maple and spruce** ("What to check in
   the field" below).

Each step goes in with its tests first.

## What to check in the field

None of this has been witnessed on a box; the tests in
`executor/local-control.md` "Tests" are in-process or against the sim.
Each row is a claim to confirm in a window, read from the journal's
`report.event` state lists and the scada log
(`experiments/spot-check-recipe.md`).

| Claim | What to see |
| --- | --- |
| A Nolan scada boots with the call open | `gw1.nolan.lc.buffer.only.state` goes `Initializing` then `HpCallOff`; zones on their thermostats, charge valve closed, store pump off |
| The call follows the schedule and the band | `HpCallOn` only off-peak with the band wanting charge; `HpCallOff` at buffer-depth3 ≥ `BufferFullF`, and 120 s before each on-peak window |
| The pump follows the heat pump, not the call | `spruce.hack.hp.state` goes `HpDetectedOn` above 500 W and `HpDetectedOff` below 80 W; secondary pump and iso valve move with it, and run in `Unknown` |
| A blind band is a state | Either buffer channel stale 5 minutes: `gw2.lc.top.state` `ScadaBlind`, commands from `scada-blind`, call on the schedule alone; back to `Normal` through a boot |
| Standby reads from the tree | A standby scada's command tree hangs under `auto.lc.standby` and its commands come from `standby`; an admin session reports `Dormant`, its release reports `Standby`, and the posture is restored |
| The operating status is quiet | One `gw.house.operating.status` after startup, then one per changed field; an admin session moves `TopState` alone |
| A refusing scada ends a stored contract | Restarted refusing dispatch with a live contract in the store: one `TerminatedByScada` heartbeat to the LTN carrying the reason, the leaf ally never in charge |
| A cold Nolan house needs a person | `critical-zone-cold` glitch; the machine stays in `Normal` |

Spruce's window runs `jm/spruce-unlimbo` against the `jm/spruce` layout
and displaces the winter hack, so an experiment window there is short
(`experiments/field-window-recipe.md`).

## For the review

The reviewer reads `executor/local-control.md` against the code and
tries to break it. The places most likely to give:

5. **The refusing restart ends its contract through
   `process_ally_gives_up`**, though the ally did nothing: the cause
   reads "Ally Gives up", and the auto-state trigger is ignored when
   the scada is already in `LocalControl`.
6. **The four seconds before `resume_loaded_contract`.** An offer in
   that window, a contract that expires in it, and a store written by
   another status are the cases to walk.
7. **The watch's defaults.** `Unknown` runs the pump; a first read
   between the lines is `HpDetectedOff`. Either could be wrong for a
   heat pump other than spruce's Samsung, and the lines are hard-coded
   per device type.
9. **`cold.py` reads `UsingNonElectricBackup`** from the top state, a
   state the Nolan machine has no transition into.
10. **A whole-file params push** carrying a stale `AcceptsDispatch:
    true` clears a `ServiceContractBroken` latch (OPS-408).

Code: `actors/local_control_loader.py`, `local_control/standby.py`,
`local_control/nolan/buffer_only_tou.py`, `actors/hp_watch.py`,
`actors/leaf_ally_loader.py`, and in `actors/scada.py`
`resume_loaded_contract`, `enforce_auto_state_consistency`,
`process_ally_gives_up` and `report_operating_status`.

## Backup

Not built. Today `UsingNonElectricBackup` bakes one house's answer (an
oil boiler behind the aquastat switch) into the shared enum, and
`OilBoilerBackup` on the ops word is a plant fact in the wrong word:
every House0 gen sets it true, including a house whose boiler is
missing a part. Both layout words require the `backup` node
unconditionally.

The shape to converge on: backup is a layout structure plus an ops
availability, not a state name.

- The layout word carries a `Backup` chunk: a kind and the actuator
  nodes it drives (oil boiler via the aquastat switch; electric elements
  with their relay nodes; none). Installed-but-unwired elements are not
  in the layout, since the scada has no node to command.
- The ops word says whether the wired backup may be used now
  (`BackupAvailable` or a per-backup enable). An out-of-service boiler
  is an ops fact; the layout does not change to record it.
- `SystemCold` moves to `UsingBackup` only when the layout has a backup
  and ops says it is available. Otherwise a cold house is a Critical
  glitch: the house needs a person, not a state.
- `backup` is a required node only where the layout has a backup kind.
- Spruce: electric elements, availability false this winter, since the
  radiant floor keeps the house from getting too cold. The ops flag is
  the whole mechanism. With it on, `UsingBackup` energizes the buffer
  elements off-peak only; the call, the pump and the iso valve keep
  their Normal rules, and the elements' own cutout turns them off.
- Elm: oil boiler, availability true. Its installed but unwired
  elements stay out of the layout until wired.

Building it: a new version of the published enum that appends
`UsingBackup` (the old value stays), its gwsproto mirror, the `Backup`
chunk on both layout words, the ops field replacing `OilBoilerBackup`,
and House0's on-peak ScadaBlind branch reading the layout kind.

A Nolan layout's `backup` node stays for three uses: a winter local
control that adds the elements, admin when someone is cold, and a Nolan
FLO telling the scada to use them.

## Cooling

Not built; the loader raises on a Nolan layout authoring `Cooling`.
The loop spruce ran through the summer of 2026 is
`spruce_summer_hack.py` in `starter-scripts` at `2c31bc1`: radiant
circuits held, iso valve open, secondary pump on, the cool call closed
off-peak and open on-peak. What a cooling machine starts from:

- The scada cannot put the heat pump into cooling. A person changes the
  unit's mode, and the call contact is inert while FSV 2091 is 0.
- Which circuits cool is a layout fact: `gw1.zone.call.circuit` carries
  `EmitterType` and `CanCool`, with axiom 1 "OnlyFanCoilsCool".
- BufferOnly is the one storage mode a Nolan layout has a machine for.

## Neighbors

- The heating machine is the winter hack
  (`starter-scripts/spruce_winter_hack.py`) as scada behavior. Later
  pump-speed work adds setpoints and 0-10V commands, not states.
- The heat-pump watch stands in for the heat-pump state machine
  (`../spruce-settled/hp-unit-sensor.md`).
- The zone slice of the OPS-394 capability surface is drafted in
  `../spruce-settled/thermostat-and-zone-control.md`.
- Live params updates without a restart are open in
  `control-strategy-selection.md`.
- Executor text still to correct: `executor/sieg-loop.md`'s opening
  note describes a branch diff that names the actuation authority, and
  `executor/primary.md` "Sieg loop posture" predates the loop becoming
  a package.
