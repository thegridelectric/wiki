# Control hierarchy — HSMs, the command tree, and the capability cover

Status: Draft · Pass 0 · Updated 2026-09-08

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
- **Per-actor FSMs** that are themselves control nodes: `HpBoss` (`actors/hp_boss.py`:
  HpOff/PreparingToTurnOn/HpOn; its states are intent, set when the command is sent, and it does not
  wait for the relay), `SiegLoop` (`actors/sieg_loop.py`: a control FSM + a valve FSM),
  `PicoCycler` (`actors/pico_cycler.py`), `LeafAlly` (`actors/leaf_ally_loader.py`, storage-mode states).

## The command tree — control state projected onto handles

Every `ShNode.Handle` is dotted (`sh_node.py` `handle`); a node's **boss** is its handle minus the last
segment (`hardware_layout.py:1057 boss_handle`, `:1062 boss_node`, `:1072 direct_reports`). Message routing
checks `FromHandle`/`ToHandle` against the node's handle — so the handle prefix **is** the authority to
command.

`set_command_tree(boss)` re-parents the actuators under whichever authority the HSM just put in charge:
- **`Scada.set_command_tree`** (`scada.py:1235`) re-roots the **whole** actuator set on a top-level
  control change.
- **`ShNodeActor.set_command_tree`** (`sh_node_actor.py:1220`) re-roots a sub-actor's **own** sub-tree
  (`my_actuators()`, `:245`) on its own state change; `set_hierarchical_fsm_handles` (`:1192`) wires the
  fixed FSM sub-tree.

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

## Fixed sub-trees vs floating actuators

Most actuators **float** — re-parented under the current authority. Some sub-bosses own **fixed** relays
regardless of who is on top: `pico-cycler` always owns the vdc relay (pico-reboot is cross-cutting),
`hp-boss` owns `hp-scada-ops-relay`, `sieg-loop` owns the loop relays. An interior node keeps its
subtree: a tree rewrite reparents the interior node and never reaches through it to its relays.
The pico-cycler hangs under the tree's **root**, not the boss: `admin.pico-cycler.vdc-relay` while
admin holds the tree, `auto.pico-cycler.vdc-relay` under local-control or leaf-ally (the shape the
layout words declare). Neither auto node commands the cycler, and it runs in every top state; it
is never sent `GoDormant` or `WakeUp` on the Auto transitions. Dormant, for the cycler, keeps the
one meaning it has everywhere: the node became a leaf and commands nothing, reserved for a mode
that touches no relay at all.

**hp-boss is the heat pump's command node in every layout.** Every layout word's core axiom requires
the `hp-boss` node with ActorClass HpBoss, the actor is constructed in every layout, and both
`set_command_tree` rewrites (`scada.py`, `actors/command_node.py`) place it under the boss with
`hp-scada-ops-relay` under it, so the relay reports to hp-boss in every state and every layout and
an operator commands the heat pump as `<boss>.hp-boss` with `TurnHpOnOff`, never the relay
directly (`tests/actors/test_hp_boss.py`, `test_hp_boss_live.py`). Having a sieg loop is topology
(the layout word); using it is operational: `UseSiegLoop` in the operational params selects
hp-boss's **strategy**, not its existence. With the loop, TurnOn passes through
`PreparingToTurnOn` and waits on `SiegLoopReady` (or `TURN_ON_ANYWAY_S`); without it hp-boss
closes the relay at once. The sieg-loop actor is the one that exists only when the loop is used.
"Dormant" is not used for any of this; in scada code it means one thing, an actor whose node is a
leaf of the current command tree, and hp-boss is never a leaf. A commandable heat pump hangs under
hp-boss: `Hydronic.HpCommandNodeName` names which node takes commands (`hp-odu` native modbus,
`hp-ctrl-box` via a MIM) and the conditional axiom `CommandableHeatPump` requires that node to have
a ComponentId and hp-boss as its effective handle parent.

**Confirmation belongs to the relay actor, per board.** On a readback board (gw108) the relay
writes, reads the pin back, commits its state only then, reports one `FsmFullReport` per TriggerId
to its boss, and holds a failed command as the enforcement target retried every verify pass with a
Critical glitch; on Krida it is commanded belief with no report. hp-boss does not wait on the
report: a boss that did would hang on Krida and would still learn nothing about the heat pump,
which answers a call minutes later. The honest on/off signal is the power channel. Witnessed on
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

`Scada(PrimeActor, ScadaInterface)` and `ShNodeActor(Actor, ABC)` have **no shared ancestor**, yet both
carry a `set_command_tree`, so the House0 special-casing is **copy-pasted** across the two. The intended
refactor: the **handle-assignment** (pure topology structure) moves onto the layout dc — `HardwareLayout`
base holds the shared sub-methods; each subclass's top-level assembly composes them over its present nodes
(the per-layout partition). Both actors **delegate** to the layout (`self.layout.assign_command_tree(boss,
actuator-scope)` — Scada passes all actuators, a sub-actor passes `my_actuators()`); the actor keeps only
*when* to re-root and the `NewCommandTree` notify to the LTN. Composition, since the two can't share a base.

## House0-specific vs generic (today)

- **Generic:** the handle→boss arithmetic (`hardware_layout.py`), the `ActorClass`→actor factory
  (`actors/__init__.py`), message routing, `my_actuators` discovery, the HSM enum definitions.
- **House0-specific:** all `H0N.*` names; the `use_sieg_loop` sub-tree; the pico-cycler-under-root
  re-parenting; the `required_actuators = {relay_multiplexer, zero_ten_out_multiplexer}` assumption;
  `house_0_layout.py` requiring a pico-cycler when pico actors are present. A minimal sim layout
  (`gw1.simple.sim.layout`: no pico-cycler, no sieg, single `hp-relay`) follows the `else` branches —
  except the call to `self.layout.vdc_relay`, which must become "if this layout has a pico-cycler-owned
  relay."

## Command interfaces and replies

Status: Verified · Pass 0 · Updated 2026-09-08 · Reviewed 2026-09-08@ea3365b5

These interfaces and replies are the scada's command surface toward
admin, the first built to the cross-cutting pattern
([`../../command-surface.md`](../../command-surface.md)); the same
shape serves the surface toward the LTN.

A command interface is three parts: vocabulary (an event enum named by
`EventType` in `fsm.event`, with `EventName` constrained to it),
authority (the command tree: `FromHandle` is the immediate boss of
`ToHandle`), and feedback (a state enum reported through
`single.machine.state`, plus `fsm.full.report` per command for
actuators). Relays declare theirs in the layout word
(`relay.control.config`); hp-boss and the pico-cycler carry theirs in
`Scada.COMMAND_NODE_INTERFACES` (`gw_spaceheat/actors/scada.py:1653`).
The capability cover (above) is the set of these interfaces read off
the live handles.

Every command node answers the boss that commanded it, through
`gw_spaceheat/actors/command_reply.py`: `gw.dispatch.ack` on take,
`gw.dispatch.nack` with a `gw.scada.cmd.refusal.reason` on refusal.
Relays (`actors/relay.py:305`), hp-boss (`actors/hp_boss.py:106`), the
0-10V outputer (`actors/zero_ten_outputer.py:185`) and the pico-cycler
(`actors/pico_cycler.py:498`) all reply; the reasons in use are Busy
(the cycler mid-cycle), UnknownEvent and OutOfRange. Admin is a boss
like any other and gets the same replies. Interior bosses do not yet
consume the acks their own relays send (an Open item on the
krida-retirement work, OPS-392).

## The pico-cycler command

Status: Verified · Pass 0 · Updated 2026-09-08 · Reviewed 2026-09-08@ea3365b5

The pico-cycler takes one command from whichever boss holds the root:
`reboot.picos` (`RebootPicos`), entering its cycle through
`ShakeZombies` from PicosLive or AllZombies (`actors/pico_cycler.py:466`
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
