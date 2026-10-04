# Control hierarchy — HSMs, the command tree, and the capability cover

Status: Draft · Pass 0 · Updated 2026-10-01

> What this is: how the SCADA's hierarchical state machines (HSMs) and the command tree work **together**
> — the piece the executor lacked. The HSM decides *who is in control*; the command tree *enforces* it via
> ShNode handles. Written from a 2026-06-28 code deep-dive; file:line anchors are pointers to verify
> against, not a contract.

## The HSM stack — "who is in control"

Nested state machines, outermost first:

- **`TopState`** (`enums/top_state.py`): `Auto | Admin`. Admin override. Defined `scada.py:92`.
- **`MainAutoState`** (`enums/main_auto_state.py`, under Auto): `LocalControl | LeafTransactiveNode |
  Dormant` — which authority drives. Transitions + `auto_trigger` at `scada.py:99,979`.
- **`LocalControlTopState`** (`enums/local_control_top_state.py`, under LocalControl): `Normal |
  UsingNonElectricBackup | ScadaBlind | Monitor | Dormant`. Driven by `actors/local_control/tou_base.py`.
- **Per-actor FSMs** that are themselves control nodes: `HpBoss` (`actors/hp_boss/hp_boss.py`:
  HpOff/PreparingToTurnOn/HpOn; its states are intent, set when the command is sent, and it does not
  wait for the relay), `SiegLoop` (`actors/sieg_loop/`: a valve FSM, and a control FSM under `StratProtect`),
  `PicoCycler` (`actors/pico_cycler.py`), `LeafAlly` (`actors/leaf_ally_loader.py`, storage-mode states).

## The command tree — control state projected onto handles

Every `ShNode.Handle` is dotted (`sh_node.py` `handle`); a node's **boss** is its handle minus the last
segment (`hardware_layout.py:1057 boss_handle`, `:1062 boss_node`, `:1072 direct_reports`). Message routing
checks `FromHandle`/`ToHandle` against the node's handle — so the handle prefix **is** the authority to
command.

`set_command_tree(boss)` re-parents the actuators under whichever authority the HSM just put in charge:
- **`Scada.set_command_tree`** (`actors/scada.py:1232`) re-roots the **whole** actuator set on a
  top-level control change.
- **`CommandNode.set_command_tree`** (`actors/command_node.py:72`) re-roots a sub-actor's **own**
  sub-tree (`my_actuators()`, `:47`) on its own state change; `shape_five_v_subtree`
  (`actors/five_v_boss.py`) is the one funnel for the fixed five-v-boss sub-tree.

The published `new.command.tree` is the authority on where a node sits.
A snapshot's `LatestStateList` shows each node under the handle its last
state row carried, so after a reparent it lags the tree by up to one
report period; anything that groups rows by handle reads the published
tree (gwadmin groups off the capability cover's `CommandNodes`), never
the snapshot.

## The interaction — the crux

**The HSM *decides* control; the command tree *enforces* it.** Every `MainAutoState`/`TopState` transition
ends in a `set_command_tree(new authority)` (`scada.py auto_trigger`, ~`:979–1046`):

| transition | new boss (root) |
|---|---|
| DispatchContractLive | `leaf_ally` |
| ContractGracePeriodEnds / LtnReleasesControl / AllyGivesUp | `local_control` |
| AutoGoesDormant (admin wakes) | `admin` |
| AutoWakesUp | `local_control` |

So the command tree is the **runtime projection of the current control state onto handles**: re-root under
the in-charge authority, and the prefix routing does the rest.

## Set of command trees = control regimes; capabilities = the cover

There is a **set of command trees** — one per control *regime* (leaf_ally-rooted, local_control
{normal/backup/blind}-rooted, admin-rooted, dormant). The HSM **selects** which is live; admin may
override-select among them. **`scada.control.capabilities` is not the tree** — it is the set of
**(command, node) pairs** whose nodes **cover** the tree: the actionable surface that binds each abstract
command to the node that executes it. A regime's cover may be a *subset* (restricted authority — admin
need not grant full leaf access).

The cover word keeps rows (`CommandNodes`, the nodes an operator sees
state for) and vocabularies (`CommandInterfaces`, what an operator may
send) apart; the pattern and its current strain are in
`wiki/command-surface.md` "Rows and vocabularies".

## Fixed sub-trees vs floating actuators

Most actuators **float** — re-parented under the current authority. The layout
declares the authored tree as the plant with no one in charge: `auto` is the
root, the command nodes and every floating actuator hang directly under it,
and local control's own nodes (`n`, `backup`, `scada-blind`) hang under `lc`
(both layout words' `CommandNodeHandles` axiom). The scada's first rewrite
hands the actuators to `lc` and owns the live tree from then on; the live
tree reads `auto.lc.n.<node>` where the layout reads `auto.<node>`, and that
difference is what floating means. The axiom pins these handles; every
other actuator's is `auto.<Name>`:

| Node | Declared handle | Words |
| --- | --- | --- |
| `five-v-boss` | `auto.five-v-boss` | both |
| `pico-cycler` | `auto.five-v-boss.pico-cycler` | both |
| `vdc-relay` | `auto.five-v-boss.pico-cycler.vdc-relay` | both |
| `lc` | `auto.lc` | both |
| `n` | `auto.lc.n` | both |
| `backup` | `auto.lc.backup` | both |
| `scada-blind` | `auto.lc.scada-blind` | both |
| `hp-boss` | `auto.hp-boss` | both |
| `hp-scada-ops-relay` | `auto.hp-boss.hp-scada-ops-relay` | both |
| `sieg-loop` | `auto.sieg-loop` | House0 (sieg word) |
| `hp-loop-on-off-relay` | `auto.sieg-loop.hp-loop-on-off-relay` | House0 (sieg word) |
| `hp-loop-keep-send-relay` | `auto.sieg-loop.hp-loop-keep-send-relay` | House0 (sieg word) |

Some
sub-bosses own **fixed** relays regardless of who is on top: `pico-cycler` always owns the vdc relay (pico-reboot is cross-cutting),
`hp-boss` owns `hp-scada-ops-relay`, `sieg-loop` owns the loop relays. An interior node keeps its
subtree: a tree rewrite reparents the interior node and never reaches through it to its relays.
The pico-cycler hangs under **five-v-boss**, which hangs under the tree's root:
`<root>.five-v-boss.pico-cycler.vdc-relay`, root `admin` while admin holds the tree, `auto` under
local-control or leaf-ally (the shape both layout words declare; tlayouts `nolan_sema_gen.py`,
`house0_sema_gen.py`). Neither auto node commands the cycler, and it runs in every top state; the
Auto transitions send it no `GoDormant` or `WakeUp` (`scada.py:1004-1022`). The reason it never
sleeps under admin: on the 2026-09-06 spruce pump-speed sweep the dormant cycler could not cycle
a flatlined pico and `secondary-flow` was lost for nineteen minutes
(`experiments/2026-09-06-spruce-pump-speed-sweep/`). Rejected with it: an admin-mode toggle that
would hand the vdc relay to the operator directly. Dormant, for the cycler, keeps the one meaning
it has everywhere: the node became a leaf and commands nothing, reserved for a mode that touches
no relay at all, which is what five-v-boss's hold is (next section).

**hp-boss is the heat pump's command node in every layout.** Every layout word's core axiom requires
the `hp-boss` node with ActorClass HpBoss, the actor is constructed in every layout, and both
`set_command_tree` rewrites (`scada.py`, `actors/command_node.py`) place it under the boss with
`hp-scada-ops-relay` under it, so the relay reports to hp-boss in every state and every layout and
an operator commands the heat pump as `<boss>.hp-boss` with `TurnHpOnOff`, never the relay
directly (`tests/actors/test_hp_boss.py`, `test_hp_boss_live.py`). Having a sieg loop is topology
(the layout word); how it is driven is operational: `SiegLoopStrategy` in the operational params
selects hp-boss's **strategy**, not its existence. Under `StratProtect` TurnOn passes through
`PreparingToTurnOn` and waits on `SiegLoopReady` (or `TURN_ON_ANYWAY_S`); under `HoldFullSend`
hp-boss closes the relay at once.
"Dormant" is not used for any of this; in scada code it means one thing, an actor whose node is a
leaf of the current command tree, and hp-boss is never a leaf. A commandable heat pump hangs under
hp-boss: `Hydronic.HpCommandNodeName` names which node takes commands (`hp-odu` native modbus,
`hp-ctrl-box` via a MIM) and the conditional axiom `CommandableHeatPump` requires that node to have
a ComponentId and hp-boss as its effective handle parent.

**The heat-pump surface is the `actors/hp_boss/` package: the command node
in `hp_boss.py`, the sensing surface in `sensing.py`.** `sensing.py` holds
what the scada knows about each kind of heat pump, by the `DeviceType` the
layout binds to `hp-odu`: the draw above which the unit is running and
below which it has stopped, the lead before an on-peak window at which the
call opens (`HP_TRAITS`, read by the Nolan heating machine), and the defrost
signatures (`DEFROST_SIGNATURES`, read by House0's plant judgment). These
tables are the hand-kept copy of what the heat pump's device-type record
will carry. The sieg loop still spells its own idle-draw line and settle
time in `actors/sieg_loop/strat_protect.py`, unkeyed by device type; that is
the one piece not yet in the package. Where it converges: hp-boss runs a
sensed machine of the unit's state, Off, Charging, Defrost, and Unknown
while blind, derived in `sensing.py` from the power channels and later
confirmed by lift, and every consumer (the pump posture, the cold logic, the
sieg strategy) reads that state rather than the raw draw. The state is the
unit's, never a compressor's: some units have two compressors, and nothing
outside the package knows how many. It is a machine state, not a channel
(decided 2026-10-01): the scada reports it as a `SingleMachineState` in a
sema enum, and the data side reaches it the way it reaches every machine
state, through the journal's enum pseudo channels. That projection is a
hand-kept map in JournalKeeper today, covering eight state enums and
dropping the rest (hp-boss, the sieg valve, the Nolan buffer-only machine,
five-v-boss, the pico-cycler, the relays and zone circuits); the
layout and `layout.lite` are to declare every machine the scada reports
(node, state enum, channel name) so the journal creates the channels from
the lite with no map (`../../gridworks-journalkeeper/executor/persistor.md`
"Open"). Two known limits of the interim rules:
the running / stopped power pair does not handle defrost (the draw falls
while the unit is still in a cycle and the pump must keep running), and no
heat-pump temperature sensor is trusted yet; hp-ewt, hp-lwt, the primary and
secondary flows and the secondary ewt and lwt join the sensing surface when
their sensors, some of them picos, earn trust.

**The call contact, its interlock, and the failsafe direction.** At spruce
`hp-scada-ops-relay` drives a normally-open RIB whose contact asserts the
control box's external cool-call input, configured on the Samsung side as
the sole compressor on/off authority: closed runs the unit, open stops it,
and the unit keeps its own protections (defrost, minimum cycle times,
water limits) while called. A second relay adds the independent heat
call; the two SHALL be software-interlocked so both are never closed at
once (a manufacturer constraint). The failsafe is heat pump OFF: a dead
controller opens the contacts. That direction is forced by the iso valve,
which fails closed (energized = open), so a heat pump left running on a
controller failure would push against a closed valve. Choosing
call-closed-on-failure, so an autonomous heat pump keeps serving the
house, requires rewiring the valve normally open first; the valve's
wiring is config data on its relay component, never baked into names or
code. The plant order the takeover of `spruce_summer_hack.py`
reproduces, per state change: iso valve open, then the secondary-pump
0-10 V level, then the pump relay, then the call; failsafe-open on exit;
and a five-minute drift enforcement re-asserting every relay and DAC
level against the held command.

**Confirmation belongs to the relay actor, per board.** On both board families the relay
writes through `I2cBus`, reads the pin back, commits its state only then, reports one
`FsmFullReport` per TriggerId to its boss, and holds a failed command as the enforcement target
retried every verify pass with a Critical glitch. hp-boss does not wait on the report: it would
learn nothing about the heat pump, which answers a call minutes later. The honest on/off signal
is the power channel. Witnessed on
honeysuckle 2026-09-07 (`experiments/2026-09-07-hp-boss-admin-drive/`): the relay committed
`RelayOpen` 14 ms after `HpOff` and `RelayClosed` 12 ms after `HpOn`.

## Shared *definitions*, per-topology *binding*

The load-bearing distinction for running many layouts:

- **Shared across every layout (the "same set"):** the command-tree **definitions** and the HSM
  **definitions** — the control *architecture* (which authorities exist, who can seize control, the state
  nesting, the FSM + capability vocabulary). There should be **no per-layout command-tree code**.
- **Varies per layout (topology):** which control nodes + actuators are **present**, and how the shared
  commands **bind** onto them — the **capability cover**. A layout with no pico-cycler simply has no
  binding for the "cycle picos" capability; the shared architecture still applies, the cover is empty
  there.

Today this is fused and frozen to House0: `set_command_tree` is the shared sub-methods *and* the per-layout
assembly, hardcoded to `H0N.*`. The pass-two direction (hardware-layout-pass-one) un-fuses them — see below.

## The two `set_command_tree` locations

`Scada(PrimeActor, ScadaInterface)` and `CommandNode` (`actors/command_node.py`) have **no shared
ancestor**, yet both carry a `set_command_tree`, so the House0 special-casing is **copy-pasted** across the two. The intended
refactor: the **handle-assignment** (pure topology structure) moves onto the layout dc — `HardwareLayout`
base holds the shared sub-methods; each subclass's top-level assembly composes them over its present nodes
(the per-layout partition). Both actors **delegate** to the layout (`self.layout.assign_command_tree(boss,
actuator-scope)` — Scada passes all actuators, a sub-actor passes `my_actuators()`); the actor keeps only
*when* to re-root and the `NewCommandTree` notify to the LTN. Composition, since the two can't share a base.

## House0-specific vs generic (today)

- **Generic:** the handle→boss arithmetic (`hardware_layout.py`), the `ActorClass`→actor factory
  (`actors/__init__.py`), message routing, `my_actuators` discovery, the HSM enum definitions.
- **House0-specific:** all `H0N.*` names; the `sieg-loop` sub-tree; the pico-cycler-under-root
  re-parenting; `house_0_layout.py` requiring a pico-cycler when pico actors are present. A minimal sim layout
  (`gw1.simple.sim.layout`: no pico-cycler, no sieg, single `hp-relay`) follows the `else` branches —
  except the call to `self.layout.vdc_relay`, which must become "if this layout has a pico-cycler-owned
  relay."

## The node-actor partition

Node actors are partitioned into tiers by concern, so a change to one concern
touches one inheritance root rather than the base every actor shares (the flaw
this cured: the relay actor once carried `turn_on_HP`, the thermistor reader
`is_buffer_full`):

- **A — actor infrastructure** (`sh_node_actor.py`): the identity accessors
  (`services`, `node`, `layout`, `data`, `ops`), `await_with_watchdog`, the send
  helper, logging. Every node actor inherits A.
- **B — command-tree mechanics** (`actors/command_node.py`): inherited only by
  the **interior** nodes of the command tree — those that take commands from
  above and command reports below (Scada, LocalControl, LeafAlly, hp-boss,
  pico-cycler, five-v-boss, and the circuit FSMs as they arrive). The tree
  deepens over time, so B is written for N inheritors, not a fixed few. Leaf
  actuators only *check* handles (that stays in `relay.py`); sensors are outside
  the tree.
- **C+D — actuation choreography + plant judgment** (`actors/hydronic/<family>.py`,
  one file per layout family — `house0.py`, `nolan.py`): the two strata share
  domain, consumers and lifecycle, so they share a file until one outgrows a
  single concern. The name matches the artifact side (`Hydronic`, `gw.hydronic`,
  `HydronicLayout`). Plant judgment reads whatever temperature it can get.
  Every House0 has a buffer tank; what varies is which of its temperature
  channels report. Each buffer predicate walks a fixed preference list,
  answers from the first channel present, and returns False when nothing on
  its list reports, so a missing reading never asserts a state:
  - `is_buffer_empty`: `buffer-depth1`, then `dist-swt` (`buffer-depth3`
    first for an all-tanks leaf ally with `ShortCycleBuffer`). Also False
    with no heating forecast.
  - `is_buffer_full`: `buffer-depth3`, then `buffer-cold-pipe`, then
    `store-cold-pipe` while discharging the store, then `hp-ewt` while the
    heat pump feeds the house; a proxy sends an info glitch naming the
    channel.
  - `is_buffer_charge_limited`: `hp-ewt` while the heat pump feeds the
    house, then `buffer-cold-pipe`, then `buffer-depth3`.
  - `is_storage_colder_than_buffer`: buffer top from `buffer-depth1`,
    `depth2`, `depth3`, `buffer-cold-pipe`; storage top from
    `tank1-depth1`, `store-hot-pipe`, `buffer-hot-pipe`. An all-tanks leaf
    ally with `ShortCycleBuffer` instead compares the buffer bottom
    (`depth3`, `depth2`, `depth1`) to the storage top with no margin.
  The fall-through is deliberate: a house with a dead depth sensor keeps
  cycling on the nearest reading rather than stalling.
- **E — zone/TOU pieces** (`get_zone_setpoints`, `is_onpeak`, `is_system_cold`):
  family-neutral, reading ops words. `setpoints_at_onpeak_start` is each zone's
  setpoint as on-peak began, and `is_system_cold` judges against the lower of it
  and the current setpoint, so a thermostat raised during on-peak does not read
  as a cold house. The memory is refreshed off-peak (`is_system_cold` does that
  itself) and in the two minutes before a window opens, and held through
  on-peak; that hold is the protection. A strategy that refreshes it on every
  pass makes it the current setpoint and defeats it.

Directory shape is role first, then family:

```
actors/local_control/house0/   tou_base, all_tanks_tou, buffer_only_tou, standby
actors/local_control/nolan.py
actors/leaf_ally/house0/       all_tanks, buffer_only
actors/leaf_ally/nolan.py
actors/hydronic/               shared.py · house0.py · nolan.py
actors/                        sh_node_actor.py (A) · command_node.py (B)
                               local_control_loader.py · leaf_ally_loader.py
```

There is no cross-family sharing inside a role dir (`all_tanks` / `buffer_only`
are House0's, since Nolan homes are store-under-floor). `hydronic/shared.py`
holds zone-circuit relay helpers, the vdc pair and the onpeak/setpoint
judgment. The bar for a name or helper staying in the hydronic tier is not
"every layout has it": most layouts have store tanks and two have a buffer, and
a layout without the thing simply answers that it has none. A thing leaves the
hydronic tier when it would be confusing across families. The core cases are the
iso valve and the charge/discharge relay, which are wired differently in
`gw.house0` and `gw.house0.no.sieg`. `hubitat` serves more than one family, so it
is a hydronic-tier name.

**Each interior node owns the command tree at and under it and publishes it.**
Publication is the full-tree `new.command.tree` snapshot — the wire contract is
replace-in-entirety. The construction sites (`scada.py`, the command-node base,
`tou_base.set_limited_command_tree`) route through one B-tier
`publish_command_tree()`, so a publication-policy change is one line.

## Command interfaces and replies

Status: Accepted · Pass 0 · Updated 2026-09-25 · Reviewed 2026-09-14@293b0215

These interfaces and replies are the scada's command surface toward
admin, the first built to the cross-cutting pattern
([`../../command-surface.md`](../../command-surface.md)); the same
shape serves the surface toward the LTN.

A command interface is three parts: vocabulary (an event enum named by
`EventType` in `fsm.event`, with `EventName` constrained to it; an
analog value in `analog.dispatch`), authority (the command tree:
`FromHandle` is the immediate boss of `ToHandle`), and feedback (a
state enum reported through `single.machine.state`, plus
`fsm.full.report` per command for actuators). Both command words carry
the same authority envelope: `FromHandle`, `ToHandle`, `TriggerId`.
Relays declare their vocabulary in the layout word
(`relay.control.config`); hp-boss, five-v-boss and sieg-loop carry theirs in
`Scada.COMMAND_NODE_INTERFACES` (`gw_spaceheat/actors/scada.py:1672`).
The pico-cycler has no interface of its own: it is owned by five-v-boss,
which forwards `RebootPicos` to it. The capability cover (above) is the
set of these interfaces read off the live handles.

**One full report per command, folded at the command nodes.** The
`fsm.full.report` is the written record, not the commander's feedback:
the commander learns take or refusal from the ack pair and the outcome
from the state rows. A node sends its report under the command's
`TriggerId` to its commander when the commander is an interior command
node (`command_reply.COMMAND_NODE_CLASSES`: hp-boss, five-v-boss,
pico-cycler, sieg-loop), and otherwise to `primary_scada`
(`command_reply.report_destination`). An interior command node passes
the command's `TriggerId` to the actuators it commands, keeps its own
transitions under that id, folds the reports it receives into its own
in arrival order, and sends the one report on by the same rule. A
command the node starts itself (the cycler's boot cycle, hp-boss's
boot open, the loop's automatic move) rides a `TriggerId` the node
mints. So the scada holds exactly one report per `TriggerId`, every
atomic names the machine it happened on, and no report goes to the admin
panel, which follows state rows. The relay routes its report through the
rule (`actors/relay.py`, both the GPIO and the I2C path); the four
command nodes fold (`hp_boss.py process_fsm_full_report`,
`five_v_boss.py process_fsm_full_report`, `pico_cycler.py
process_fsm_full_report`, `sieg_loop/__init__.py move_ended`).

Open, small opportunities for improvement:

- A silent actuator leaves no trace in the folded report. The sieg-loop
  waits five seconds for each relay's report, glitches `relay_silent`
  and goes on; its report then simply lacks that relay's atomics. The
  IEC 60870 and 61850 control models end the command on a missing
  termination and re-read the state; at least the report should say a
  record is missing rather than leave it absent.
- The forwarded reboot skips the fold. five-v-boss forwards
  `RebootPicos` to the cycler under the commander's `TriggerId`, and the
  cycler reports the cycle to the scada under that id; five-v-boss adds
  no transition of its own to a reboot, so nothing is lost, but it is the
  one report under a boss-issued id that does not pass through the boss.

**Two authority checks, in order, before a command is read.** A message
names its sender twice: the transport header's source is who put it on
the wire, and the payload's `FromHandle` is who the sender claims to be
in the tree. The receiver compares them.

1. **FromHandle mismatch** (the source node's handle is not the
   payload's `FromHandle`): the message is misrouted or forged and there
   is nobody to answer. The node logs, sends a warning `Glitch`
   (`bad_sender`), and stops. The receiver reports because it is the
   only party that can.
2. **Stale ToHandle** (`ToHandle` is not the node's live handle): the
   node replies `gw.dispatch.nack` with `NotMyBoss` to the sender and
   stops, and says nothing else. Only the sender knows whether the
   refusal matters (a handover in progress, or a stale tree), so the
   sender decides whether to report it. The journal holds 2,734
   `bad_boss` glitches from 2025-01 to 2026-05, one per relay per
   attempt, nearly all the house's own boss commanding relays whose
   handles had already moved to the LTN side; the fact worth recording
   was one stale tree per incident, at the boss.

The receiver speaks only when nobody else can. Command nodes holding
both checks: relay (`actors/relay.py` `_process_event_message`),
hp-boss (`actors/hp_boss/hp_boss.py` `process_fsm_event`), five-v-boss
(`actors/five_v_boss.py` `process_fsm_event`), pico-cycler
(`actors/pico_cycler.py` `process_fsm_event`), sieg-loop
(`actors/sieg_loop/__init__.py` `process_fsm_event`), 0-10V outputer
(`actors/zero_ten_outputer.py` `process_analog_dispatch`). In each the
message handler resolves the header source to a layout node and hands
it to the command handler with the payload; a source not in the layout
is dropped before either check. Every node
that takes commands joins this list as it is built; the thermostat
state machines are next. The check reads only
the shared envelope, so it is a candidate for one shared site on the
command-node base rather than a copy per handler.

Every command node answers the boss that commanded it, through
`gw_spaceheat/actors/command_reply.py`: `gw.dispatch.ack` on take,
`gw.dispatch.nack` with a `gw.scada.cmd.refusal.reason` on refusal.
The reasons in use are NotMyBoss, Busy (the cycler mid-cycle;
five-v-boss outside PicoCycler, or with the relay not yet reported
closed), UnknownEvent and OutOfRange. Admin is a boss like any other and
gets the same replies; it shows a nack to the operator and does not
glitch. A forwarded command is answered through the forwarder:
five-v-boss sends `RebootPicos` on to the cycler under the commander's
`TriggerId`, remembers who commanded, and passes the cycler's ack or
nack back with the handles rewritten to its own and the commander's
(`actors/five_v_boss.py` `process_cycler_reply`); a reply it did not
forward is logged and dropped. Every interior command node takes its
own actuators' replies the same way: an ack is silent, since the full
report confirms the actuation, and a nack is an Error glitch
(`relay_nack`, with the relay, the `TriggerId` and the reason), because
a node's own actuator refusing it is a scada fault, never a field
condition. The sieg-loop also ends the move on a nack. The
one-glitch-per-stale-tree report at a boss whose command was refused
NotMyBoss by a node outside its tree rides with
[OPS-537](https://linear.app/gridworks/issue/OPS-537).

## five-v-boss: the 5 V hold

Status: Verified · Pass 0 · Updated 2026-09-10 · Reviewed 2026-09-09@4bb46035

five-v-boss is the command node for the 5 V bus that feeds every pico. It
sits between the root and the pico-cycler in every layout and takes two
vocabularies: `turn.5v.on.off` (TurnOff, TurnOn) and the forwarded
`reboot.picos`. Its states (`five.v.boss.state`): PicoCycler (the normal
state: the cycler owns the vdc relay and runs its liveness loop),
TurningOff, FiveVOff, TurningOn. Boot is always PicoCycler
(`scada.py:1710`); the scada reads the boss's last reported state when
it rewrites the root tree, and one `shape_five_v_subtree` writes the
subtree shape for both the scada's rewrite and the actor's own
transitions (`actors/five_v_boss.py`).

**The hold.** TurnOff is taken only in PicoCycler with the relay last
reported closed (`five_v_boss.py:174-205`); otherwise Busy. Taken, the
boss sends the cycler `GoDormant`, reparents the vdc relay under itself
and opens it; the picos go dark by design, and the roster reads Flatlined
for the hold ("The pico-cycler command"). TurnOn in FiveVOff closes the
relay; the closed confirmation reparents the relay back under the cycler,
republishes the tree and sends the cycler `WakeUp`. TurnOn at rest is
acked and does nothing; either command during Turning* is Busy. Each
hold produces two full reports, one per direction.

**Wake.** `wake.up` from the scada on AutoWakesUp (admin release and the
admin keepalive timeout alike) restores the 5 V from FiveVOff or
TurningOff (`five_v_boss.py:230`, `scada.py:1017`), so LocalControl never
inherits a dark fleet.

**Rejected** (2026-09-08): a raw admin path to the vdc relay; an
admin-mode toggle on the cycler; a hold expressed as a cycler state; and
a hands-off flag on the relay. Each either let the cycler sleep under
admin or gave the relay two commanders.

**Witnessed.** Dev sim run 4 and spruce 2026-09-09
(`experiments/2026-09-08-five-v-boss-hold/` "Found"): TurnOff to FiveVOff
in 27 ms, five picos flatlined through the hold, the cycler cycled
nothing, TurnOn in 12 ms. Tests: `tests/actors/test_five_v_boss.py` (18,
on the Nolan and House0-sim pairs).

**WORK IN PROGRESS: diagrams.** This section and the two above need
graphic command-tree diagrams: the tree under each root (admin,
local-control, leaf-ally) with the five-v-boss subtree in PicoCycler and
in FiveVOff, and the hold's two reparents drawn as before/after. Until
they exist the handle paths above are the picture.

## The pico-cycler command

Status: Verified · Pass 0 · Updated 2026-09-10 · Reviewed 2026-09-08@ea3365b5

The pico-cycler takes one command, from five-v-boss (which forwards the
operator's RebootPicos and passes the cycler's reply back):
`reboot.picos` (`RebootPicos`), entering its cycle through
`ShakeZombies` from PicosLive or AllZombies (`actors/pico_cycler.py:468`
`process_fsm_event`). A cycle is RelayOpening, RelayOpen (the vdc relay
held open 5 s), RelayClosing, PicosRebooting, PicosLive, the last on the
first pico re-POST; the cycle's `TriggerId` is the command's. A command
arriving mid-cycle is nacked Busy. The cycler also cycles on its own on
`Startup` (the boot cycle) and `PicoMissing`. Each cycle's reboot wait
(60 s) is tied to that cycle; a wait outliving its cycle is ignored as
stale.

Real timing (spruce gw108, 2026-09-08,
`experiments/2026-09-08-spruce-admin-panel/`): the BTU picos re-POST
7 to 9 s after the relay closes, so PicosLive arrives about 13 s after
the command and the 60 s wait never fires in anger. The sim rung is
`experiments/2026-09-07-admin-reboots-picos/`.

**What provoked a cycle is structured, not prose.** The provocation
kind is the cycle's entering event (`PicoMissing`, `ShakeZombies`,
`RebootPicos` through five-v-boss, `Startup`); a commanded cycle is tied
to its commander by `TriggerId`; which pico provoked it is read off the
journaled per-pico `machine.states` rows (`single.pico.state`: Alive,
Flatlined, Zombie, the roster at start and in every periodic report, and
a row on each flip). The flatline row is sent before the cycle it
provokes is triggered, so a cycle's cause is the pico whose row flipped
just before it (`tests/actors/test_pico_roster.py`).

**The roster reads Flatlined during a 5 V hold, and that is the reading
we want.** While five-v-boss holds the bus off (FiveVOff) the cycler is
Dormant and cycles nothing, but `process_pico_missing` still marks each
silent pico Flatlined, so the panel and the journal show Flatlined rows
for the hold's duration. The rows are true: the picos are dark. The
roster reports pico liveness and nothing else; that the darkness is
commanded is read off a different machine, the five-v-boss row
(`five.v.boss.state` FiveVOff) and the top state that put admin in
charge. No held-off roster reading is added to the cycler.
