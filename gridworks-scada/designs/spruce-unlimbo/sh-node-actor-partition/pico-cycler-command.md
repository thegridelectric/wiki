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
2. ✅ Verified (dev-broker rung run 4, `b095261c`). Pico-cycler accepts ONE command from its boss: reboot the picos.
   It rides `fsm.event` with `EventType` `reboot.picos` (new enum word,
   single value `RebootPicos`), `ToHandle` `<root>.pico-cycler`, and
   maps onto the existing `ShakeZombies` transition. The cycler adopts
   the commander's `TriggerId` instead of minting its own, as relays do,
   so the cycle's `fsm.full.report` is tied to the command by id.
   No suspend/resume pair: under admin the cycler is never dormant
   (below). Refusals mirror `relay.py`: a sender whose handle is not
   the `FromHandle` is dropped, a `ToHandle` that is not the cycler's
   live handle earns a `bad_boss` glitch, any other `EventType` is
   logged and dropped, and a command while a cycle is running is
   ignored (`tests/actors/test_pico_cycler_command.py`, both sim
   fixtures). The boot cycle enters through `Startup`.
3. ✅ Verified (same run, driven through `send_reboot_picos`). gwadmin grows a pico-cycler control alongside its relay list: a
   "Reboot picos" button (`p`) in the relays section,
   `RelayWatchClient.send_reboot_picos` publishing the `admin.dispatch`.
   `tests/actors/test_admin_reboots_picos.py` drives that client method
   through `Scada.process_admin_dispatch` into the cycler and asserts the
   relay open carries the dispatch's `TriggerId` (both sim fixtures).
4. Tree-matrix admin rows move to the `admin.pico-cycler.vdc-relay`
   shape (marked xfail until this lands).
5. Three enum words registered in sema, mirrored in gwsproto:
   ✅ `single.pico.state` (Alive / Flatlined / Zombie, default
   Flatlined so an unknown value reads as a sick pico; sema branch
   `jm/pico-cycler-words`), `reboot.picos`, and
   `pico.cycler.event` (gaining `Startup`, so the boot cycle stops
   being reported as a `PicoMissing` with no pico missing).
   **gwsproto side done, sema side deferred (2026-09-07):** `RebootPicos`
   and `Startup` exist in gwsproto only and sit on the conformance
   test's `NO_WORD_ENUMS` allowlist. `pico.cycler.event` has never been
   registered in sema (gwsproto's class names a 000 that does not
   exist), so the sema catch-up is two NEW staging words, not a version
   bump: `reboot.picos` and `pico.cycler.event` with all ten values.
   Do it as item 7, at the end, on `jm/pico-cycler-words`; when they
   land, remove both from the allowlist. ✅ The cycler
   reports each pico's state through `machine.states`
   (`MachineHandle` the pico-backed actor's handle, `StateEnum`
   `single.pico.state`, gwsproto mirror `SinglePicoState`): the roster at
   start and in the periodic report, and a row on every flip. The
   flatline row is sent before the cycle it provokes is triggered, so a
   cycle's cause is the pico whose row flipped just before it
   (`tests/actors/test_pico_roster.py`, both sim fixtures). The scada
   already folds machine states into `report`, so the roster reaches the
   journal with no new plumbing.
6. After the above lands: branch `jm/pico-state-reporting` off
   `actual-spruce` (the line running on the house) carrying only
   `single.pico.state`, the gwsproto mirror, and the per-pico
   `machine.states` reporting, so the roster is journaled on spruce
   this season. No command, no `TriggerId` adoption, no `Startup`
   there.
7. The sema catch-up in item 5 lands in krida-retirement's rung 1
   (the panel rows need the same enum words); drop the two allowlist
   rows there.
8. LAST, coverage for what the dev-broker rung exposed
   (`experiments/2026-09-07-admin-reboots-picos/`) that has only the
   broker run behind it; all in process, in
   `tests/actors/test_pico_cycler_command.py` unless noted:
   - the real overlap: cycle A closes, a command opens cycle B, A's
     reboot timer fires into B (short `RELAY_OPEN_S` / `PICO_REBOOT_S`,
     the relay's reports handed back); the two guard tests only swap
     the cycle id under one wait;
   - the full loop through the sim pico: relay confirms, cycler closes,
     the sim source loses power and posts again `SimRebootS` later, and
     that reading (not a timer) confirms the cycle;
   - the journal path: the cycler's `fsm.full.report` delivered to the
     scada lands in `report.FsmReportList` under the dispatch's id
     (pass condition (a) of the rung);
   - the GPIO relay's state committing before its pin write (the FSM
     fires, then actuates; the i2c path is command-and-confirm), in
     `tests/actors/test_relay_gpio_sim.py`;
   - the admin acknowledgement, once decided;
   - the tank actor's always-true flatline gate, with its fix.

## Cost accepted

No raw admin path to vdc-relay when the pico-cycler actor itself is
sick — `relay.py`'s handle check rightly refuses a non-boss commander.

## ▶ Do this next

**The admin TUI is BROKEN for Nolan.** `gwa watch` shows no relays and
no DACs for a Nolan scada (watched 2026-09-07 on the dev sim): the
capabilities reply is never built because the word requires the Krida
component. Item 3's Reboot picos button therefore cannot be reached
from the panel today; it is exercised only through `send_reboot_picos`.
The fix is krida-retirement's rung 1 (per-command-node capabilities,
one table with the pico-cycler as a row), which runs next; this spoke
does not wait on it for the decision below.

**Decide the acknowledgement word, next round, before building.**
Position going in (2026-09-07): feedback has two halves and admin gets
neither. Completion already exists: `fsm.full.report` (TriggerId,
FromName, the transitions) is the record of a command that ran; the
cycler sends it to the primary scada and it is journaled. Forwarding it
on the admin link when admin was the commander is plumbing, no new
word. Acceptance does not exist: a command that is ignored (cycler
mid-cycle), refused (bad boss, wrong event type) or analog (DAC, no
FSM) produces nothing the sender can see, and that is the case an
operator most needs. Proposal: one ack/nack pair, twins discriminated
by TypeName (the shape of `g.node.cmd.ack` / `g.node.cmd.nack`),
correlated by the command's TriggerId, sent direct to the commander
for every dispatch including analog. The nack carries a reason enum
(Busy, NotMyBoss, UnknownEvent, NotAControlNode); the ack says only
"taken", and the outcome then arrives as the forwarded full report and
the state rows. No third completion word, and acceptance is not folded
into state rows. To settle in the round: (1) the correlation key,
since `AnalogDispatch` may carry no TriggerId (it gains one, or the
pair hashes content); (2) who answers, the target actor (it knows Busy)
with the scada forwarding, or the scada alone (it knows only bad boss);
lean: the actor answers, the scada forwards, the same path as the full
report. Then item 4 (tree-matrix admin rows), item 6, and the
`pico.cycler.state` / `pico.cycler.event` enum words ride
krida-retirement's rung 1.

The dev-broker rung is closed: run 4 on `b095261c`
(`experiments/2026-09-07-admin-reboots-picos/`, `run4-report-events.txt`)
had all three cycles, `Startup`, `PicoMissing` and the commanded
`ShakeZombies` under the dispatch's id, confirm 20 s after their close,
with the cycles 65 s and 57 s apart. Items 2 and 3 are Verified on it.

Landed so far: items 1, 1a, 2 (`1229636c`), 3 (`7997fc9a`), the sim-pico
source (`bb8f6478`, tlayouts `9c52bf3`), the per-pico roster
(`single.pico.state`, item 5's reporting half), item 5's gwsproto
half, and the two rung fixes (`b095261c`). Sema `fc741c2` carries the
sim word.

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

## Sim pico source (decided 2026-09-07; built)

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

## Findings while building (2026-09-07)

- `ApiTankModule.main`'s flatline gate reads `if self.last_error_report >
  FLATLINE_REPORT_S`: a timestamp against a duration, always true, so
  the report interval is the 10 s loop, not 60 s. And `electrical_channels`
  is set only when `SendMicroVolts` is true but read unconditionally on
  a flatline. Both pre-existing; the same shape sits in `api_btu_meter.py`
  and `api_flow_module.py`. Fix with a test when those actors are reviewed.
- tlayouts carries two seed files: `tlayouts_seed_request.yaml` (root,
  `build_tlayouts_snapshot.sh`) reproduces the committed snapshot;
  `src/tlayouts/sema_seed_request.yaml` (`scripts/regen_sema_snapshot.sh`,
  the one the README names) is stale and drops six words. Retire one pair.
- The sim configs set `SimLifeS` 120 / `SimRebootS` 20 so a flatline and a
  cycle land inside the five-minute rung; the real-house rhythm is a
  separate knob when one is wanted.
- The tank actor's flatline gate above also means `PicoMissing` reaches
  the cycler within ~10 s of the sim pico's silence; the dev-broker rung
  measured 2 s.

- **The gwadmin TUI cannot show a Nolan layout's relays yet.** On admin
  link-up the scada answers `send.control.capabilities`, and
  `Scada.control_capabilities` dereferences `H0N.relay_multiplexer`
  unguarded; Nolan has no such node (its relays are thin
  `gpio.relay.component.gt` / `i2c.relay.component.gt` components), so
  the message is never built and the TUI's relay and DAC tables stay
  empty. The word itself requires `I2cRelayComponent`, and gwadmin
  reads every relay's config from its `ConfigList`. Watched first-hand
  2026-09-07 (`gwa watch` on the dev sim). Every dev-broker run logged
  it (`Trouble with SendLayout: 'NoneType' object has no attribute
  'component'`, runs 1–4) and the driver never noticed because it
  reads snapshots, not capabilities. The handler's log label is wrong:
  the `SendControlCapabilities` branch in `scada.py` logs under the
  `SendLayout` name. The `krida-retirement` spoke owns the fix (drop
  the required Krida component from the word, then the admin package);
  until it lands item 3's button is reachable only through
  `send_reboot_picos`, and the pico-cycler row shows in the snapshot.

## Open

- When the terminal-asset plant exists, is `sim.pico.tank.module` still
  useful? The plant is the physics source, so tank temperatures should
  come from it; the sim pico's remaining job would be the pico's
  liveness story (posts, dies, reboots after a power cycle), which is
  device behaviour, not plant physics. Two answers: the plant posts
  microvolts over HTTP like a real pico and the word keeps only the
  liveness fields; or the plant feeds the actor's source through the sim
  seam and the source stays. Decide when the plant's tank model lands.

