# Command-node vocabulary — inconsistent uses (HOLD spoke)

Status: Draft · Pass 0 · Updated 2026-09-14 · Linear: OPS-392

**EDD: no** a vocabulary-coherence spoke; verification is the sema word-gate
plus the conformance suite once the terms settle.

> What this is: a HOLD spoke capturing that "command node" is used with
> several mutually inconsistent meanings across the sema words and the scada
> code. Resolution is POSTPONED — it edits change-controlled command-tree
> vocabulary, a deliberate sema sitting of its own. This spoke only exposes
> the inconsistency and sketches a taxonomy to decide against later. Surfaced
> 2026-09-14 while correcting a `command_reply.py` docstring (OPS-539).

## The sema definition (the anchor)

`new.command.tree/002,/003` axiom 2 `ActuatorLeaves` defines, wire-checkably:

- an **actuator** is an ShNode whose ActorClass is `Relay`, `ZeroTenOutputer`
  or `HpTwin`;
- a **command node** is an ShNode whose ActorClass is `LocalControl`,
  `LeafAlly`, `PicoCycler`, `HpBoss` or `SiegLoop`, or a `NoActor` whose
  handle-parent is a `LocalControl` node;
- every actuator is a leaf; every leaf is an actuator or a command node.

Its prose is explicit: "the interior of every published tree is command
nodes and its leaves are the things they command." So a command node
**gives** commands; an actuator is **commanded** and is NOT a command node.
The layout words carry the same definition (`gw.house0.layout/000`,
`gw.nolan.layout/000` `ActuatorLeaves`).

## The inconsistent uses

1. **Commanders (interior)** — the definition above. Command node = LocalControl,
   LeafAlly, PicoCycler, HpBoss, SiegLoop, + LC-child state waypoints.
2. **Operator-addressable interior, excluding actuators** —
   `scada.control.capabilities/002` `CommandNodes` field; its axiom (clause c)
   FORBIDS a `Relay` or `ZeroTenOutputer` in the set (relays and DACs are the
   separate `RelayNodes` / `DacNodes` fields). A third, narrower set again.
3. **DispatchAck/Nack repliers, INCLUDING actuators** —
   `gw_spaceheat/actors/command_reply.py` docstring called relay, 0-10V
   outputer, pico-cycler, hp-boss (and now five-v-boss) "command nodes". This
   CONTRADICTS use 1: it labels actuator leaves — the things that are
   commanded — as command nodes.

Two loose ends the anchor also exposes:

- **`FiveVBoss` is in none of the sets.** It commands (pico-cycler, the vdc
  relay), but ActorClass `FiveVBoss` is absent from the `ActuatorLeaves`
  command-node list. It is interior (not a leaf), so axiom b does not catch
  it — but it is a commander the vocabulary does not name.
- Use 3's set (relay, outputer, pico-cycler, hp-boss, five-v-boss) and use
  1's set (lc, la, pico-cycler, hp-boss, sieg-loop, waypoints) overlap only
  on pico-cycler and hp-boss.

## A taxonomy to decide against (Jessica, 2026-09-14)

Perhaps `CommandNode` is the UMBRELLA for every participant in a command
tree, with overlapping role sub-kinds:

- **CommandingNodes** — give commands (have children they command): the
  interior — auto, lc, hp-boss, five-v-boss, sieg-loop, la…
- **CommandableNodes** — can be commanded (have a commanding parent): every
  non-root node — the LeafAlly (commanded by the LTN on the dispatch
  contract) and every actuator included.
- **ActuatorNodes** — leaves that act on hardware: Relay, ZeroTenOutputer,
  HpTwin.

A node holds several roles at once (hp-boss is commanding AND commandable; a
relay is commandable AND an actuator; the root is commanding only; a leaf
actuator is commandable + actuator, never commanding). Under this reading the
`command_reply` set is "the CommandableNodes that ack/nack", and the sema
`ActuatorLeaves` "command node" is really CommandingNodes.

## Why postponed

Settling this edits change-controlled vocabulary (`new.command.tree`,
`scada.control.capabilities`, the layout words' axiom names) plus their
gwsproto mirrors and every doc and docstring that uses the term — a
deliberate sema word-gate sitting, its own flat Linear issue (shared
vocabulary, per the designs-process convention). Not folded into any current
build. The `command_reply.py` docstring keeps "command nodes" for now (only
the stale count was generalized); it is corrected when the taxonomy lands.

## Do this next

Open the flat Linear issue. Take the taxonomy through the sema word-gate —
decide which of Commanding / Commandable / Actuator become vocabulary and
whether `CommandNode` is retired or made the umbrella — then sweep the
docstring, the `scada.control.capabilities` field, and the axiom prose to
the settled terms in one wave. Note `FiveVBoss` in the command-node set while
there.
