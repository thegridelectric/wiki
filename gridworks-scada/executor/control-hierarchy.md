# Control hierarchy — HSMs, the command tree, and the capability cover

Status: Draft · Pass 0 · Updated 2026-06-28

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
  HpOff/PreparingToTurnOn/HpOn), `SiegLoop` (`actors/sieg_loop.py`: a control FSM + a valve FSM),
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
`hp-boss` owns `hp_scada_ops_relay`, `sieg-loop` owns the loop relays. These fixed sub-trees are the
`use_sieg_loop` / pico-presence conditionals in `set_command_tree` (`scada.py:1252–1274`).

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
- **House0-specific:** all `H0N.*` names; the `use_sieg_loop` sub-tree; the unconditional vdc→`auto.pico-cycler`
  re-parenting; the `required_actuators = {relay_multiplexer, zero_ten_out_multiplexer}` assumption;
  `house_0_layout.py` requiring a pico-cycler when pico actors are present. A minimal sim layout
  (`gw1.simple.sim.layout`: no pico-cycler, no sieg, single `hp-relay`) follows the `else` branches —
  except the call to `self.layout.vdc_relay`, which must become "if this layout has a pico-cycler-owned
  relay."
