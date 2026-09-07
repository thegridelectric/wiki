# Command interface (unsorted)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: how actors share what commands they take, surfaced
> 2026-09-07 while hp-boss became the heat pump's command node in every
> layout. Not yet thought through; candidate for its own flat issue and
> design, since pico-cycler-command, krida-retirement, admin-for-nolan and
> hp-twin all depend on it.

## What a command interface is today

Three parts. Vocabulary: an event enum, named by `EventType` in
`fsm.event`, with `EventName` constrained to it. Authority: the command
tree (`FromHandle` is the immediate boss of `ToHandle`). Feedback: a state
enum reported through `single.machine.state`, plus `fsm.full.report` per
command for actuators.

## How it is declared, three ways

- Relays: in the layout word, per node. `relay.control.config` carries
  `EventType` + the two events and `StateType` + the two states.
- hp-boss, pico-cycler, LocalControl, LeafAlly: hard-coded in Python.
  `CommandNode.send_state_command` maps `ActorClass.HpBoss` to
  `TurnHpOnOff` by hand; the admin client addresses hp-boss because it was
  written knowing to.
- Admin's `scada.control.capabilities` is actuator-shaped (relay nodes,
  DAC nodes, control channels, a Krida component); it cannot say "hp-boss
  takes turn.hp.on.off".

## Sema coverage is split

State enums mostly have words (`gw1.main.auto.state`, the local-control
and leaf-ally states, `zone.call.circuit.state`). Command enums mostly do
not: `turn.hp.on.off`, `pico.cycler.event`, every local-control and
leaf-ally `*.event`, `top.event`, `change.heat.pump.control`, the aquastat
and store-flow vocabularies. The gwsproto docstrings cite sema URLs that
resolve to nothing; `gw1.hp.boss.state` still carries the gw1 prefix.
States crossed a wire so they got words; commands stayed in-process until
admin started sending them. The `fsm.event` axiom EventNameBelongsToEventType
cannot be checked for an enum the registry does not hold.

## Proposal

Static capability in the layout, dynamic authority in the tree, both in
sema.

1. A per-node command interface in the layout word: `EventType` and
   `StateType` as enum references on every node that takes commands
   (`relay.control.config`'s vocabulary fields generalized to interior
   nodes; actuator configs keep their wiring facts).
2. `send_state_command` looks the vocabulary up on the node; the
   ActorClass switch goes (it is the hand-map the sema maxim names as the
   tell).
3. The admin capabilities projection becomes "every node with a command
   interface, with its vocabulary"; the Krida component field retires with
   it (krida-retirement).
4. The missing command enums become registered sema words, staging; the
   gw1 prefix rides snapshot-drop-gw1.

hp-boss's own interface (`turn.hp.on.off` in, `hp.boss.state` out) stays
fixed across strategies; the channel axis in `hp-twin.md` "Strategies" is the interface of the node hp-boss commands
(`change.relay.state` today, a heat-pump command enum for the twin).

## Open

- Does the interface live on the ShNode word or in a sibling list keyed by
  node name? The node word is shared with every consumer; a sibling list
  is a layout-word-only change.
- Whether `new.command.tree` should carry the interface (it already
  carries the nodes) or stay authority-only.
