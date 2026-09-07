# Pico-cycler command (spoke)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: admin keeps the pico-cycler running and asks it for vdc
> relay actions, instead of seizing the relay. Decided 2026-09-01 with
> the interior-subtree rule; executes at the end of the command_node.py
> review section (estimate on OPS-392).

## The rule this rides

**An interior node keeps its subtree; tree rewrites reparent delegates,
never reach through them.** vdc-relay reports to pico-cycler in ALL
states in ALL layouts; under admin the shape is
`admin.pico-cycler.vdc-relay`. This supersedes the hand-coded
vdc-under-pico-cycler-except-admin exemption in `Scada.set_command_tree`
(and makes `CommandNode.set_command_tree`'s flatten-everything branch
structurally safe rather than safe-by-call-site).

Rejected alternative: toggling admin between direct-vdc and hands-off
trees — doubles the special cases, needs a mode flag living outside the
trees, and its direct mode cuts the cycler out, which is the failure
mode this exists to prevent (we repeatedly wanted admin control WITH the
cycler still running).

## Field evidence (2026-09-06, spruce pump-speed sweep)

The window scada's boot power-cycles the picos through vdc-relay
(pico-cycler `TRIGGERING PICO REBOOT`), then the sweep driver takes
admin and the cycler is sent dormant. In run 2 the secondary BTU
meter's pico did not rejoin after the boot-time cycle; the cycler
logged it flatlined twelve minutes later and, dormant, could not cycle
it. Every DAC level echoed and every other channel reported, but the
run carried no `secondary-flow` at all, the one measurement the sweep
exists for. On admin release the cycler woke and cycled the picos on
its own. Nineteen minutes of window lost to the exemption this spoke
removes; the same failure would hit any long admin window.
(`experiments/2026-09-06-spruce-pump-speed-sweep/` run 2.)

## The work

1. ✅ Uniform subtree rule in `Scada.set_command_tree`: the pico-cycler is
   reparented as an interior node and keeps `vdc-relay` under it; the
   vdc exemption and `HACK_VDC_RELAY_NAME` are gone. **The cycler hangs
   under the tree's ROOT, not the boss**: `admin.pico-cycler` when admin
   holds the tree, `auto.pico-cycler` under local-control or leaf-ally.
   Neither auto node ever commands the cycler, so putting it under them
   would only make `CommandNode.set_command_tree`'s flatten branch a
   hazard for it; under the root it never enters an auto node's
   `my_actuators`, and that method needs no pico knowledge. The layout
   gens' fixed `auto.pico-cycler` handle is the auto shape, unchanged.
1a. ✅ `AutoGoesDormant` / `AutoWakesUp` send the cycler nothing; it runs
   in every top state. Its `Dormant` FSM state stays for a future
   no-relay mode.
   Tests (`tests/actors/test_command_tree_prefix_closed.py`, all three
   fixtures): the shape under every boss, no `GoDormant` to the cycler,
   and a flatlined pico cycled while admin holds the tree (the cycler's
   `FsmEvent` to `admin.pico-cycler.vdc-relay` constructs and matches
   the relay's live handle). Writing the last one found that the
   cycler's pico discovery skipped `SimPicoTankModuleComponent`, so on
   every sim layout it held no picos and could cycle nothing; it now
   accepts the sim class as `api_tank_module.py` already did.
2. Pico-cycler accepts ONE command from its boss: reboot the picos.
   It rides `fsm.event` with `EventType` `reboot.picos` (new enum word,
   single value `RebootPicos`), `ToHandle` `<root>.pico-cycler`, and
   maps onto the existing `ShakeZombies` transition. The cycler adopts
   the commander's `TriggerId` instead of minting its own, as relays do,
   so the cycle's `fsm.full.report` is tied to the command by id.
   No suspend/resume pair: under admin the cycler is never dormant
   (below).
3. gwadmin grows a pico-cycler control alongside its relay list.
4. Tree-matrix admin rows move to the `admin.pico-cycler.vdc-relay`
   shape (marked xfail until this lands).
5. Three enum words registered in sema, mirrored in gwsproto:
   ✅ `single.pico.state` (Alive / Flatlined / Zombie, default
   Flatlined so an unknown value reads as a sick pico; sema branch
   `jm/pico-cycler-words`), `reboot.picos`, and
   `pico.cycler.event` (gaining `Startup`, so the boot cycle stops
   being reported as a `PicoMissing` with no pico missing). The cycler
   reports each pico's state through `machine.states`
   (`MachineHandle` the pico node, `StateEnum` `single.pico.state`);
   the scada already folds machine states into `report`, so the roster
   reaches the journal with no new plumbing.
6. LAST, after the above lands: branch `jm/pico-state-reporting` off
   `actual-spruce` (the line running on the house) carrying only
   `single.pico.state`, the gwsproto mirror, and the per-pico
   `machine.states` reporting, so the roster is journaled on spruce
   this season. No command, no `TriggerId` adoption, no `Startup`
   there.

## Cost accepted

No raw admin path to vdc-relay when the pico-cycler actor itself is
sick — `relay.py`'s handle check rightly refuses a non-boss commander.

## ▶ Do this next

Fresh session. First the sim-pico cluster, in this order: (1) pending
changelog entry; (2) sema `jm/pico-cycler-words`: `SimLifeS` +
`SimRebootS` on `sim.pico.tank.module.component.gt/001` in place (the
type-kind gate summary was posted and confirmed 2026-09-07; re-read
`authoring/types.md` "Property Definitions" before editing); (3) gwsproto
mirror + `ApiTankModule` sim source with the re-evaluate docstring;
(4) tlayouts gens emit the fields for sim tanks, run both gens, regenerate
the pytest fixtures (the gens' constant swap for the cycler handles is
also uncommitted there and has NOT been run yet: run the gens and diff
`output/` against `gridworks-scada/tests/config` before committing it);
(5) the source pytest; suite; commit. Then the other two words
(`reboot.picos`, `pico.cycler.event` + `Startup`), item 2 with `TriggerId`
adoption, item 3 in gwadmin, item 6 last.

## Decisions (2026-09-07)

- **Dormant means "this node became a leaf and commands nothing."**
  The cycler goes dormant only in a future mode that touches no relay
  at all (monitor-only); never under admin. `GoDormant` / `WakeUp`
  are therefore not part of the boss surface, and `change.relay.state`
  addressed to the cycler is the wrong word (it would be admin reaching
  through the cycler to its relay).
- **What provoked a cycle is structured, not prose.** The provocation
  kind is the entering event (`PicoMissing`, `ShakeZombies`,
  `RebootPicos` via the boss, `Startup`); a boss-provoked cycle is
  additionally tied to its commander by `TriggerId`; which pico
  provoked it, and the roster (alive / flatlined / zombie), is read off
  the journaled per-pico `machine.states`. This replaces a free-text
  `Cause` string on `fsm.atomic.report` (branch `td/pico-cycler-logging`,
  `2134429b`, not merged: it edited a published word in place without a
  version, and packed the trigger and a roster snapshot into one string
  that analysis would have to parse back apart). The `alive` property
  from that branch is kept.

## Sim pico source (decided 2026-09-07)

Every sim layout declares a `sim.pico.tank.module.component.gt` per tank
and nothing feeds it: the plant emits no microvolts and the raw depth
channels are captured by the tank-module actor alone. So sim tank actors
go silent after the 60 s capture period and send `pico.missing` every
minute; before the cycler saw sim picos it ignored them, and sim houses
have had no tank temperatures at all. The gen's `tank_kind` comment says
a sim tank is a SimSensor while its code emits a sim pico.

The fix is a simulated pico behind the real actor: when `ApiTankModule`'s
component is the sim word it runs its own reading source, posting
`microvolts` to itself at the channel's capture period (the same tuning
its flatline timer reads). The source lives inside the actor rather than
as its own node or in the plant; the actor docstring names that as a
choice to re-evaluate (a plant-side pico posting over HTTP would test the
real ingress path). Two fields on the sim word (001 is staging, edited in
place), both optional, absence meaning absence: `SimLifeS` (seconds the
pico posts after each boot before going silent; absent = no scripted
death) and `SimRebootS` (seconds after the vdc relay closes following an
open before the pico boots and posts again, read from the scada's recent
machine states; absent = a dead pico stays dead, the zombie path). Readings are a fixed microvolt profile per depth (a tank at
rest) until the plant drives tank temperatures. Later: reboot success
becomes probabilistic per cycle, which is what produces zombies; no
field for that now. tlayouts: both gens emit the two fields for sim
tanks; the pytest fixtures regenerate from them. Proof in two layers: a
pytest that drives the source directly with no clock tricks (emits at
the capture period, stops after `SimLifeS`, resumes `SimRebootS` after
seeing the relay close following an open); the full loop with the
cycler is the next rung, a sim Nolan scada on the dev broker for five
minutes with the journaled `single.pico.state` roster as evidence.

## Open

- When the terminal-asset plant exists, is `sim.pico.tank.module` still
  useful? The plant is the physics source, so tank temperatures should
  come from it; the sim pico's remaining job would be the pico's
  liveness story (posts, dies, reboots after a power cycle), which is
  device behaviour, not plant physics. Two answers: the plant posts
  microvolts over HTTP like a real pico and the word keeps only the
  liveness fields; or the plant feeds the actor's source through the sim
  seam and the source stays. Decide when the plant's tank model lands.

- `MachineHandle` for a pico's `machine.states`: the pico node's handle
  (pico actors are sensors, outside the command tree). Confirm the
  scada's `process_machine_states` keys by trailing name and tolerates
  many machines.
