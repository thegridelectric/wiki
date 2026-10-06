# Nolan local control (spoke)

Status: Accepted · Pass 1 · Updated 2026-10-06 · Linear: OPS-392

> What this is: what is left on Nolan local control, what to check as
> the code runs in the field, and the brief for the adversarial review.
> What is built is specified in `executor/local-control.md` and
> `executor/cold-house.md`; this spoke does not repeat it.

## Do this next

**▶ DO THIS NEXT: step 1,** at "Building it" step 2: the tlayouts,
closure and gwsproto wave for the new words.
With it, `LocalControlTopEvent` in gwsproto drops its sema URL, which
cites a word that does not exist.

1. **Backup and the cold override** (section below).
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
9. **`cold.py` reads `InBackup`** from the top state, a state the
   Nolan machine has no transition into.
10. **A whole-file params push** carrying a stale `AcceptsDispatch:
    true` clears a `ServiceContractBroken` latch (OPS-408).

Code: `actors/local_control_loader.py`, `local_control/standby.py`,
`local_control/nolan/buffer_only_tou.py`, `actors/hp_watch.py`,
`actors/leaf_ally_loader.py`, and in `actors/scada.py`
`resume_loaded_contract`, `enforce_auto_state_consistency`,
`process_ally_gives_up` and `report_operating_status`.

## Backup and the cold override

Not built. House0's backup state does two different things under one
name, and a Nolan house does neither:

- **The cold override** is the primary heat source with the tariff set
  aside: the heat pump runs on-peak because the house is cold. It is
  not a second source of heat. House0 does this today, inside its
  backup state, at a house with no boiler.
- **Backup** is a second source of heat: an oil boiler behind the
  aquastat switch, or electric elements on their relays.

All relays de-energized is the plant's failsafe position, where the
aquastat and the boiler hold a House0 house with no scada. It coincides
with boiler backup and is not a state of the local control.

**The words.**

- `gw2.lc.top.state` 000, staging and edited in place, has `InBackup`
  and gains `ColdOverride`.
- Both layout words gain a `cold-override` command node at
  `auto.lc.cold-override`, by the same three axioms that carry
  `standby`, so the command tree says which state holds the plant.
- `gw.hydronic` gains an optional `Backup`, beside `WaterStore`, so both
  layout words carry it. A layout with no backup has no `Backup`. The
  kind of backup is the word itself, one of two:
  - `gw.boiler.backup`, a boiler held by its aquastat, whatever its
    fuel: `FailsafeRelayName` and `AquastatCtrlRelayName` name the two
    relays by role, because `InBackup` commands each differently.
  - `gw.element.backup`: `ElementRelayNames`, one or more resistive
    elements on their relays.

  Each carries `InService`, false for a backup that is installed and
  unwired or out of service. `InService` lives in the layout only.
- Axioms: every relay a backup names is a `ShNode` of actor class
  `Relay`; the names are distinct, and the boiler's two relays are
  different nodes. The `backup` command node at `auto.lc.backup` exists
  if and only if `Hydronic.Backup` is present.
- The ops word's `UsesBackupWhenCold` replaces `OilBoilerBackup`: the
  house goes to its backup when cold.

**Entering.** Each family keeps the cold rule it has: a critical zone
cold with the stores empty for five minutes. The destination is the one
new decision. With `UsesBackupWhenCold` true the house goes straight to
`InBackup`; otherwise it goes to `ColdOverride`. A house with both a
heat pump that could run through the peak and a backup does not try the
heat pump first.

**Leaving.** Either state returns to Normal when no critical zone is
cold and it is off-peak, so an override entered on-peak holds through
the rest of the peak.

**House0.** The relay commands do not change, only the state and the
node that sends them. `InBackup` is today's boiler branch, from
`backup`: store pump off, store valved to discharge, `hp-failsafe-relay`
to the aquastat, `aquastat-ctrl-relay` to the boiler. `ColdOverride` is
today's no-boiler branch, from `cold-override`: store pump off, store
valved to discharge, heat pump on. The on-peak ScadaBlind branch reads
`UsesBackupWhenCold` where it reads `OilBoilerBackup`. The two Normal
strategy machines are not touched.

**Nolan.** In `ColdOverride` the call is closed whatever the tariff,
and the secondary pump and iso valve follow the heat-pump watch as in
Normal. Spruce's backup is a `gw.element.backup` naming the two
buffer elements (`buffer-top-elt-relay`, `buffer-bottom-elt-relay`); the store
elements are not backup. Its `InService` is false: spruce does not
use backup at all for now. In `InBackup` the named relays close. Boot, and every
way out of `InBackup`, opens them, so that elements held off is
something the machine commands and a test asserts. Spruce runs with
`UsesBackupWhenCold` false this winter: the radiant floor keeps the
house from getting too cold.

**The cold watch** raises `critical-zone-cold` at five minutes in every
top state, so a house entering either state has already paged. Its
`still-cold-in-backup` glitch reads `InBackup`.

**At boot** the scada checks its layout and its params as a pair and
does not start on a pair that fails: `UsesBackupWhenCold` true requires a
`Backup` with `InService` true. The same check runs before a scada writes
anything the LTN sends
(`../spruce-settled/layout-and-params-from-ltn.md`).

**Open.**

- Whether the sema spec lets `Backup` be one of two words; if not, a
  kind enum with axioms saying which fields each kind requires.
- Whether the heat pump call and both elements may run together at
  spruce.

**Building it,** each step with its tests first:

1. A test that drives House0's `SystemCold` on a running scada, with
   and without a boiler, against the code as it is. It pins the relay
   commands before anything moves
   (`tests/actors/test_system_cold_live.py`). ✅
2. The words: `ColdOverride`, the `cold-override` node,
   `gw.boiler.backup`, `gw.element.backup` and `Hydronic.Backup`,
   `UsesBackupWhenCold` ✅ in sema; then the tlayouts snapshot and
   gens, the closure copy and the gwsproto mirrors, in one wave: the
   scada reads `OilBoilerBackup` until its mirror moves. ◐
3. House0's two destinations. Step 1's test stays green with the state
   and the commanding node changed for the no-boiler house.
4. Nolan's `ColdOverride`, then its `InBackup`.
5. The pair check at boot.
6. The executor's account of backup, carrying the question of which
   comes first at a house with both.

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
