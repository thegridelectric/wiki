# Control hierarchy — HSMs, the command tree, and the capability cover

Status: Draft · Pass 0 · Updated 2026-09-10

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

Most actuators **float** — re-parented under the current authority. Some sub-bosses own **fixed** relays
regardless of who is on top: `pico-cycler` always owns the vdc relay (pico-reboot is cross-cutting),
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
