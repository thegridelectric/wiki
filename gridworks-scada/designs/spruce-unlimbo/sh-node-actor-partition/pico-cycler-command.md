# Pico-cycler command (spoke)

Status: Draft · Pass 0 · Updated 2026-09-10 · Linear: OPS-392

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
   ✅ Sema side: `reboot.picos` and `pico.cycler.event` registered
   2026-09-07 on `jm/pico-cycler-words` (pending commit); the
   conformance allowlist rows drop with the gwsproto mirror step in
   "Do this next". ✅ The cycler
   reports each pico's state through `machine.states`
   (`MachineHandle` the pico-backed actor's handle, `StateEnum`
   `single.pico.state`, gwsproto mirror `SinglePicoState`): the roster at
   start and in the periodic report, and a row on every flip. The
   flatline row is sent before the cycle it provokes is triggered, so a
   cycle's cause is the pico whose row flipped just before it
   (`tests/actors/test_pico_roster.py`, both sim fixtures). The scada
   already folds machine states into `report`, so the roster reaches the
   journal with no new plumbing.
6. ✅ Built (pending commit on `jm/pico-state-reporting`, worktree
   `gridworks-scada-roster`; `single.pico.state/000` published `a96abb4`).
   Branch `jm/pico-state-reporting` off
   `actual-spruce` (the line running on the house) carrying only
   `single.pico.state`, the gwsproto mirror, and the per-pico
   `machine.states` reporting, so the roster is journaled on spruce
   this season. No command, no `TriggerId` adoption, no `Startup`
   there. The journal side (journalkeeper vendoring the enums and
   tracking unknown ones, then the dev-DB query) is the hub queue's
   `journalkeeper-pico-states`, after krida-retirement.
7. ✅ The item-5 enum words are registered (2026-09-07); allowlist rows
   drop with the gwsproto mirror.
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

## Roster on actual-spruce (item 6, what it takes)

The question the roster answers for the house this season: which pico
provoked each cycle. The cycler's `fsm.full.report` never carried that;
the trigger comment (`fsm_comment`) is logged and dropped. The per-pico
`machine.states` rows of `d367ece5` on `jm/spruce-unlimbo` carry it as
typed data: the flatline row is sent before the cycle it provokes, so a
cycle's cause is the pico whose row flipped just before it, and the
periodic roster shows who was alive, flatlined or zombie at every
report. The work is to replicate that commit on a branch cut from
`actual-spruce`; the report words do not change.

Where the deployed line stands (`actual-spruce` at `30fc7f59`):

- `pico_cycler.py` defines its own two-value `SinglePicoState`
  (Alive, Flatlined) as a `GwStrEnum`; Zombie is the `zombies` set.
  Nothing per pico is sent; the cycler's own `machine.states` row is.
- gwsproto there has no `SemaEnum` base, no conformance test, no
  `sema_closure/` copy; enums are `AslEnum` with `values` / `default` /
  `enum_name` / `enum_version` classmethods.
- `Scada.process_machine_states` keys rows by the handle's last segment
  (the tank actor's name), so pico rows sit beside the cycler's own row,
  and `report/003` already folds `StateList` into the journal-bound
  report. No scada change.
- No test exercises the cycler on that line. The sim pico component
  (`sim_pico_tank_module_component.py`) does exist there.

The branch, `jm/pico-state-reporting` off `actual-spruce` (a worktree,
the way `gridworks-scada-cycler` holds the panel work):

1. gwsproto: `enums/single_pico_state.py` in the line's `AslEnum` style
   (Alive, Flatlined, Zombie; default Flatlined; docstring
   `Sema: https://schemas.electricity.works/enums/single.pico.state/000`),
   exported from `enums/__init__.py`. `sema validate` a `machine.states`
   payload carrying it.
2. `pico_cycler.py`: drop the local enum, import the gwsproto one, port
   the four hooks of `d367ece5` (`pico_state`, `report_pico_state`,
   `report_pico_roster`, and the calls at flatline, zombie threshold,
   recovery, `start`, and the periodic loop). About forty-five lines;
   nothing else on the actor moves. No command, no `TriggerId`
   adoption, no `Startup`.
3. Test: `tests/actors/test_pico_roster.py` ported; its assertions are
   fixture-independent (every pico reported alive at start, the flatline
   row precedes the cycle, a second missing report adds no row, readings
   bring the row back, zombie at the threshold, rows validate on the
   wire) but its `PAIRS` fixture is the branch's sim layouts, so the
   fixture is rewritten against `tests/config/nolan-layout.json` with
   the line's sim pico component.
4. Sema gate before the box speaks it: `single.pico.state/000` is
   `staging`; a word that crosses the wire to the production broker is
   published first (`executor/running.md` "Experiment window on a
   deployed box", status tier). A promotion-only sema turn, `sema
   promote`, then the gwsproto docstring pin is already the published
   URL.
5. Deploy: merge to `actual-spruce`, push, pull on the box, restart the
   service. Nothing hand-placed.

Journal side, day one: journalkeeper's `machine.states` axiom 2 checks
only `relay.closed.or.open`, so the rows validate; `STATE_CHANNELS` has
no entry for a tank actor's handle, so they project to no reading
channel (one "no channel" warn per row per report) and stay in the
journaled `report` payload, where a JSON query over `StateList` reads
them against the cycler's cycles by time. The projected channels per
pico actor, with the enum vendored, are the hub queue's
`journalkeeper-pico-states`.

Built 2026-09-09: steps 1 to 5 done (enum, the four hooks, the roster
test green on both test layouts, the word published, merged to
`actual-spruce` as `69d5d6ec`); the pull on the box and the service
restart remain. Journal side built 2026-09-10 (journalkeeper branch
`jm/single-pico-state-snapshot`, pending commit): the snapshot vendors
the enum and every pico-backed node gets a `<node>-pico-state` channel,
so the hub queue's `journalkeeper-pico-states` is done with it.

TODO, in order:

1. Dev rung: journalkeeper reads `single.pico.state`. Sim scada on the
   dev broker (the 09-07 setup) with a journalkeeper on the same broker
   against a fresh local DB; persist its `layout.lite`, let a pico
   flatline and cycle, then query `reading_channels` for the
   `<node>-pico-state` rows and `readings` for the Flatlined (1) and
   Alive (0) values in time order, the flatline row before the cycler's
   own state row. Pass condition: the roster and the flip are readable
   as channel readings, no dropped-reading tally for those channels.
2. Spruce: pull `actual-spruce` at `69d5d6ec` or later onto the box,
   restart the service, and repeat the query against the production
   journal after the next report. Journalkeeper must be running the
   per-pico channel code by then; a report that arrives before the
   box's `layout.lite` is re-persisted only tallies dropped rows. The cycler's pico discovery on this
line also had to accept `SimPicoTankModuleComponent` (the branch's
finding, again) or the test layouts give it no picos; the house layout
has only real pico components. Carried caveat: on this line the comm
tests under `tests/actors` (`test_scada.py`, `test_auto_state.py`,
`test_power_meter.py`) time out waiting for the scada-to-LTN link
against the shared test mosquitto, with or without the change; the
suite gate for the merge is the roster test plus the in-process actor
tests until that rig is looked at.

## ▶ Do this next

**Dev rung for the roster on the journal side** (the TODO under
"Roster on actual-spruce", item 1): sim scada on the dev broker with a
journalkeeper against a fresh local DB, a flatline and a cycle, then
the `<node>-pico-state` rows read back in time order. Item 2 (the
spruce pull and the production query) follows it.

Built 2026-09-10 (pending commit on `jm/spruce-unlimbo`), from the
spruce window (`experiments/2026-09-08-five-v-boss-hold/`, window
section, scada `4bb46035`), where TurnOff from the row cut the 5 V,
five picos flatlined under a dormant cycler, TurnOn woke it, and the
five-v-boss row offered only TurnOff:

1. The row offers per vocabulary: `RelayWidgetConfig.offered_commands`
   gives a two-command vocabulary's command that leads elsewhere and a
   one-command vocabulary when the state equals its target, so
   `PicoCycler` offers `TurnOff` and `RebootPicos`, `FiveVOff` offers
   `TurnOn`. Two buttons, `n` and `p`, bound on the `Relays` widget;
   the second is hidden on a one-offer row, which keeps its single
   full-width button.
2. The Name cell of an owned node indents one step, whatever its
   depth, so pico-cycler and vdc-relay line up under five-v-boss. A
   headless Textual pilot run rendered the table to check it; the
   unit tests are `tests/test_misc/test_admin_five_v_boss_row.py`
   and the indent case in `test_admin_row_order.py`.

Carried from the window: fancoil, floor1 and pipes1 never posted
(no channel readings in either report) and the cycler cycled the live
picos for them twice after TurnOn. Whether they exist on the wall is a
site question before the deployed scada runs the three-tank layout.

## five-v-boss (decided 2026-09-08)

**Why.** On site the 5 V supply had to be pulled by hand for a pico
swap: the panel can reboot the picos but cannot hold them powered down
while someone works on the board, nor bring them back except through
the reboot cycle. The pico-cycler is field-tested code that stays as it
is; the hold lives in a node above it.

**Shape.** `five-v-boss` is a command node under the tree's root, in
every layout. In its resting state the pico-cycler owns `vdc-relay`
under it; while it holds the 5 V off it owns the relay directly and the
cycler is a dormant leaf, the way the scada's auto machine makes one
child the boss and the other dormant.

```
root (admin | auto)
└── five-v-boss              state PicoCycler          state FiveVOff
    ├── pico-cycler ── vdc-relay   |   pico-cycler  (dormant leaf)
    └──                            |   vdc-relay    (owned directly)
```

**Command surface.** Two vocabularies on one node, each a
`gw.command.interface` entry in `scada.control.capabilities`:

- `turn.5v.on.off` (`TurnOn`, `TurnOff`; default `TurnOn`): the hold.
- `reboot.picos` (`RebootPicos`): forwarded to the cycler.

Admin never addresses the cycler or the relay; it commands
`five-v-boss`, which answers with `gw.dispatch.ack` / `gw.dispatch.nack`
like every command node.

**Machine** (`five.v.boss.state`: `PicoCycler`, `TurningOff`,
`FiveVOff`, `TurningOn`; default `PicoCycler`):

- `PicoCycler`. `RebootPicos` is forwarded to the cycler as its boss
  with the command's `TriggerId`; the cycler's ack or nack is passed
  back to the commander. `TurnOff` takes only when `vdc-relay`'s last
  reported state (the scada's latest machine states) is closed, which
  also means the cycler is not mid-cycle; otherwise nack `Busy`. On
  take: `GoDormant` to the cycler, reparent the relay under
  `five-v-boss`, publish the tree, open the relay, enter `TurningOff`.
  `TurnOn` is acked and does nothing.
- `TurningOff` → `FiveVOff` on the relay's open confirmation
  (`fsm.full.report` from the relay). Commands nack `Busy`.
- `FiveVOff`. `TurnOn` closes the relay and enters `TurningOn`.
  `RebootPicos` and `TurnOff` nack `Busy`. A `PicoMissing` from a tank
  or meter actor reaches the dormant cycler and is dropped there; the
  picos are dark by design and the roster is silent.
- `TurningOn` → `PicoCycler` on the relay's closed confirmation:
  reparent the relay under the cycler, publish the tree, `WakeUp` to
  the cycler. The cycler's `WakeUp` closes the relay again, idempotent,
  and the picos re-POST as after any cycle. Commands nack `Busy`.
- Every transition is an `fsm.atomic.report` under the command's
  `TriggerId`; the hold's two halves are two `fsm.full.report`s (off:
  `PicoCycler` → `FiveVOff`; on: `FiveVOff` → `PicoCycler`), each sent
  to `primary_scada` for the journal. State rows through
  `machine.states` on every transition and in the periodic report.
- Boot: `PicoCycler`, no persistence. A restarted scada never comes up
  with the picos dark.
- Admin release and admin timeout: the scada's `AutoWakesUp` sends
  `five-v-boss` the `wake.up` message local-control gets. In `FiveVOff`
  or `TurningOff` it runs the turn-on path with a self-minted
  `TriggerId`; in `PicoCycler` or `TurningOn` it is ignored.
  LocalControl never inherits a dark fleet. (Open: whether a keepalive
  timeout, as opposed to an explicit release, should restore 5 V to a
  board someone may be touching; decided as yes for now.)

**Rejected.** A held-off state inside the cycler's own FSM (six
transient states and every timer guard would reason about it; the
cycler is field-tested and stays untouched). A separate `pico-power`
node under a selector (its whole job is what `vdc-relay`'s own FSM
already does). A peer "cycle please" request from the cycler to a
power node (a non-boss triggering a relay defeats the command tree). A
`pick` command on the selector (the tree flip is a consequence of the
hold, not something admin asks for).

**Sema cascade** (`gw1.actor.class` 013 and `spaceheat.node.gt` 302 are
published; the 2026-08-12 `HpTwin` bump is the precedent):

1. New enums, staging: `turn.5v.on.off`, `five.v.boss.state`.
2. `gw1.actor.class` 014 adds `FiveVBoss`, staging.
3. `spaceheat.node.gt` 303 pins `gw1.actor.class/014`, staging.
4. Staging words edited in place to `spaceheat.node.gt/303`:
   `gw.nolan.layout`, `gw.house0.layout`, `gw1.simple.sim.layout`,
   `layout.lite`. The two layout words' axiom 4 gains
   `"five-v-boss" → ActorClass "FiveVBoss"` and the fixed handles become
   `auto.five-v-boss.pico-cycler.vdc-relay` (axioms 11 and 12 hold as
   written).
5. Published referrers get new versions pinned to 303, staging:
   `new.command.tree` 003, `scada.control.capabilities` 002. Every
   new version in this wave stays staging until the spruce witness.
6. gwsproto mirrors for all of the above; `sema_closure/registry.yaml`
   refreshed with the tlayouts snapshot in the same wave; conformance
   allowlist rows dropped as the mirrors land.

**Scada code** (small):

- `actors/five_v_boss.py`, a `CommandNode`; `ActorClass.FiveVBoss`
  wired in the actor registry.
- `Scada.set_command_tree`: reparent `five-v-boss` under the root and
  ask it to rewrite its own subtree (its state decides the shape),
  replacing the hard-coded vdc-under-cycler lines.
- `COMMAND_NODE_INTERFACES`: `FiveVBoss` with two interfaces; the
  `PicoCycler` entry is dropped (the cycler is no longer commanded from
  outside its subtree).
- `auto_trigger` `AutoWakesUp`: `wake.up` to `five-v-boss`.
- The cycler's `RebootPicos` handling is unchanged; its boss is now
  `five-v-boss` instead of the root, which its handle checks already
  accept.
- tlayouts: both gens emit the node and the new fixed handles; the
  pytest fixtures regenerate.
- gwadmin: one row per node, so the two interfaces on `five-v-boss`
  merge into one row offering `TurnOff` in `PicoCycler`, `TurnOn` in
  `FiveVOff`, and `RebootPicos` (`p`) in `PicoCycler`; the vdc-relay
  row groups under whoever owns it; the cycler row shows state only.

**Tests** (`tests/actors/test_five_v_boss.py`, both sim fixtures):
`TurnOff` sends the cycler dormant, reparents the relay and opens it;
`TurnOff` with the relay open nacks `Busy`; a `PicoMissing` during
`FiveVOff` cycles nothing; `TurnOn` closes the relay and the closed
confirmation hands the relay back and wakes the cycler; `RebootPicos`
in `PicoCycler` reaches the cycler with the adopted `TriggerId` and in
`FiveVOff` nacks; `wake.up` in `FiveVOff` restores; the tree-prefix
tests carry the new shape under every boss.

**Verification.** Dev-broker sim rung: hold off through a would-be
flatline, restore, journal shows both full reports under the dispatch
ids. Then spruce from the panel with the 5 V measured at the board.

**The panel drives the cycler on the real house (2026-09-08).**
krida-retirement rung 1 (`ea3365b5`) made `gwa watch` render a Nolan
scada with the pico-cycler as a row, and the spruce window
(`experiments/2026-09-08-spruce-admin-panel/`) witnessed Reboot picos
from that row twice on the real gw108: the row walked its states and
the real picos re-POSTed 7 to 9 s after the relay closed. What the
Verified claims below rest on is now in the scada executor
(`control-hierarchy.md` "The pico-cycler command", "Command interfaces
and replies").

**Acknowledgement decided (2026-09-07); built in `ea3365b5` except the NotMyBoss nack, which waits on the word edit (krida-retirement step 1).** Sema words
registered on `jm/pico-cycler-words` (pending commit): `gw.dispatch.ack`
/ `gw.dispatch.nack`, `gw.scada.cmd.refusal.reason`, `analog.dispatch`,
`reboot.picos`, `pico.cycler.event`. The build, in order, each with a
test:

1. ✅ gwsproto mirrors, local class names `DispatchAck` / `DispatchNack`
   (`AnalogDispatch` already matched its word); `analog.dispatch`,
   `reboot.picos`, `pico.cycler.event` off the conformance allowlists
   (pending commit on `jm/spruce-unlimbo`).
2. ✅ (`ea3365b5`, all but NotMyBoss) Every command node answers its boss: relay, DAC output, pico-cycler,
   hp-boss send `DispatchAck` on take and `DispatchNack` with the reason
   on every refusal path that today only logs. The reply goes through
   `_send_to(from_node, …)`, which already publishes on the admin link
   when the sender is admin. Read 2026-09-07, per file:
   - `relay.py` `_process_event_message`: the two handle mismatches are
     NotMyBoss; a wrong `EventType` only prints today and falls
     through to the i2c "not the pair" ignore, so it becomes
     UnknownEvent and returns; an unknown event name is UnknownEvent;
     ack once the event is taken (before the actuation task). No Busy:
     a re-command re-actuates.
   - `zero_ten_outputer.py` `process_analog_dispatch`: NotMyBoss for a
     sender not in the layout or a stale `ToHandle`, OutOfRange, ack on
     take; `process_message` has `Header.Src` for the reply address.
   - `pico_cycler.py` `process_fsm_event`: NotMyBoss twice, UnknownEvent,
     Busy when the state is not PicosLive / AllZombies, ack when the
     ShakeZombies transition fires.
   - `hp_boss.py` `process_fsm_event`: NotMyBoss for the `ToHandle`
     mismatch; the `FromHandle` mismatch only logs today (a TODO asks for
     more), decide whether it refuses; UnknownEvent; ack on take,
     including the idempotent TurnOn while already HpOn.
   - Not sent yet: NotAControlNode. Only the scada's routing knows the
     target is not a command node (`process_admin_dispatch` finds no
     communicator, silently). Decide who speaks for a node that cannot.
   - **`gw.dispatch.nack` axiom 1 cannot hold.** A NotMyBoss nack goes
     to the sender, and the sender is by definition not the boss of the
     node's live handle (admin sending to `admin.relay` while the relay
     lives at `auto.relay`). The nack's `ToHandle` is the command's
     `FromHandle`, whoever that was; the ack keeps its axiom. Staging
     word, edited in place: drop axiom 1, reword `ToHandle`; then the
     gwsproto mirror drops `check_axiom_1` and its test.
   - Adjacent flaw, not this step's: `Scada.process_admin_dispatch`
     logs "Expected admin!" for a non-admin sender and then routes the
     dispatch anyway (no return).
   - Tests: the `capture(actor)` pattern in
     `tests/actors/test_pico_cycler_command.py` (both fixtures) sees the
     reply as a `(dst, payload)` pair; one refusal test per reason per
     actor, one ack test each.
3. Dropped 2026-09-07: the pico-cycler's `fsm.full.report` stays
   addressed to `primary_scada`. That is the journal path run 4 proved
   (the report lands in `report.FsmReportList` under the dispatch's id),
   and admin's need is met by the pair plus the journaled state rows.
   The relay does the opposite (`boss_by_trigger`), so under admin its
   full reports go to the panel and never reach the journal; an open
   item for the relay review, not a reason to move the cycler.
4. ✅ gwadmin: the relay and DAC clients remember each dispatch by
   `TriggerId` (`clients/dispatch_replies.py`), decode the pair off the
   admin link, and the panel notifies taken / refused with the reason
   against the command it sent (`tests/test_misc/
   test_admin_dispatch_replies.py`). Until step 2 lands the scada sends
   nothing, so the panel stays silent on the wire; the dev-broker rung
   that witnesses a nack on screen belongs to step 2.

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

- **The node answers its boss, directly.** Acceptance is one pair,
  `gw.dispatch.ack` / `gw.dispatch.nack`, discriminated by TypeName,
  correlated by the command's `TriggerId`, sent by the target node to
  the boss that commanded it, for every dispatch including analog. The
  ack says only "taken"; the outcome is `fsm.full.report` and the state
  rows, to the same boss. The nack carries
  `gw.scada.cmd.refusal.reason` (Unknown default, Busy, NotMyBoss,
  UnknownEvent, OutOfRange, NotAControlNode). The target node answers
  because it alone knows busy, wrong boss, and out-of-vocabulary; the
  scada knows only "not admin". The pair is scada-shaped on purpose
  (tree handles as addresses); the LTN and market boundaries coin their
  own twins with their own address fields and reason vocabulary, the
  pattern `g.node.cmd.ack` and `gw.weather.cmd.ack` already follow, and
  a market acceptance is a contract (`market.maker.ack`), not a "taken".
  `analog.dispatch` already carried `TriggerId` in gwsproto; the sema
  word matches it, so one correlation key covers every dispatch.

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

## Findings while building five-v-boss (2026-09-08)

- The dev-broker rung's first command was refused by the admin client
  itself: gwadmin's `_get_relay_configs` keyed the command interfaces by
  node name, so five-v-boss's row kept only `reboot.picos`, and the row
  carried one `event_type` in any case. Fixed in the run: each command
  carries its event type, a row's commands are the union over its node's
  interfaces, and the in-process test checks the three commands under
  two types (`tests/actors/test_five_v_boss.py`). The in-process tests
  had covered the scada's capabilities word, not the panel's reading of
  it; the rung is where that seam shows.
- The rung's persisted `report.event`s showed the off path's second
  atomic labelled `TurnOn:TurningOff->FiveVOff`. Fixed in the run: both
  halves of a path carry the command that caused them. Open underneath:
  `turn.5v.on.off` has no confirmation event, so the relay-confirmed
  half has no name of its own; the cycler's enum names each step. Leave
  the two-value vocabulary unless the journal reader needs the halves
  told apart by event rather than by state.
- On TurnOn the woken cycler goes PicosLive and, 1.6 s later, a
  `PicoMissing` from a still-dark pico sends it through a full reboot
  cycle (open 5 s, close, live 20 s after) before the picos' first
  posts. Harmless in the sim; on the real board it is one extra 5 V
  cycle per turn-on. Same root as the held-off roster: the tank actors'
  liveness clock runs through the hold.
- The cycler's Dormant row lagged the command by up to a report period:
  `GoDormant` called the raw transition, and only `WakeUp` went through
  `trigger_event` (row + atomic at the transition). Fixed in the run, the
  one edit to the cycler this spoke makes; the panel's cycler row now
  flips with the boss's.
- After a reparent the snapshot's `LatestStateList` shows a node under
  the handle its last state row carried, until it reports again (the
  relay sat under `auto.five-v-boss` in the snapshot after the release
  restore while the published tree had it under the cycler). The
  published `new.command.tree` is the authority; anything grouping rows
  off snapshot handles is a report period behind. Check on the spruce
  witness how the panel groups the relay row across a hold.
- The cycler's roster still flips during the hold: `process_pico_missing`
  marks a pico Flatlined before its state guard, and its 60 s
  `last_open_time` grace is the cycler's own open, not the boss's. The
  dormant cycler cycles nothing (tested), but the panel and the journal
  will show Flatlined rows while the 5 V is held off. Left as is: the
  picos are dark, and the cycler stays untouched. Decide on the spruce
  witness whether a held-off roster reading is worth a cycler edit.
- The scada reads five-v-boss's subtree shape off its last reported
  state (`Scada.five_v_boss_state`, PicoCycler until the first report);
  the scada's tree rewrite and the actor's own transitions call one
  `shape_five_v_subtree`, so the shape is written in one place.
  `COMMAND_NODE_CLASSES` (the rows: five-v-boss, pico-cycler, hp-boss)
  is now separate from `COMMAND_NODE_INTERFACES` (the vocabularies;
  the cycler has none), so the cycler's state still reaches the panel.
- gwadmin's row order key was one level (owner, then name); a
  three-deep chain would not have grouped. It is now the owner chain
  from the top.
- Every in-process `ScadaApp.instantiate()` starts the sim-time paho
  thread (`Scada._sim_time_listener`, `loop_start` against the test
  broker) and no fixture stopped it; 36 more instantiations and the
  five live tests later in the run (`test_scada.py`, `test_power_meter.py`)
  time out waiting for their links (one of them already fails at
  baseline in `tests/actors`). The new file's fixture stops the listener
  on teardown and the whole directory goes green, including the
  baseline miss. The other in-process fixtures still leak; a shared
  conftest fixture with the teardown is the fix, its own small commit.
- The beech fixture `gw.house0.layout.json` is hand-kept; it gained the
  node and the new handles by hand (the layout word's axiom 4 requires
  it). `HydronicLayout`'s essential-nodes check still lists neither
  five-v-boss nor the cycler; the layout words carry the requirement.

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

