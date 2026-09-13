# command-surface — what a command surface is and how we build one

Status: Draft · Pass 0 · Updated 2026-09-13

> What this is: the cross-cutting pattern for a **command surface**: the
> declared set of commands one GridWorks party offers to one counterparty,
> with the authority, reply and feedback rules every surface follows.
> Canonical home for the pattern; each domain's executor states its own
> surfaces and converges here. The sibling for read surfaces is
> [`api-pattern.md`](api-pattern.md).

## What a command surface is

A command surface is offered by the party that owns the thing being
commanded, to exactly one kind of counterparty, and it is declared before
it is consumed. The counterparty renders from the declaration and never
learns the house, the plant or the fleet another way. The scada's
`scada.control.capabilities` is the first one built this way: the admin
client keys off it and never reads `layout.lite`.

Every surface has three parts, and the three are kept apart:

- **Vocabulary.** The commands, as events on a state enum, both sema
  words. A command names a target and an event; the declaration lists
  the `{Event, ToState}` pairs the target takes.
- **Authority.** Who may send which command right now. Authority is held
  and enforced by the owner (the command tree, the admin session, the
  dispatch contract), never inferred from the client's claim. A command
  from a party that does not hold authority is refused, not executed.
- **Feedback.** Two distinct things come back. The **reply** to a
  command: taken (ack) or refused (nack with a reason), one per command,
  always. And the **state report**: what the target is now doing,
  published on change, whether or not a command caused it.

A surface is a **cover, not the mechanism**. It names the (command,
target) pairs a counterparty may use; it does not expose the tree, the
relays or the loop under them. A regime may offer a subset (admin need not
grant everything the ally holds; the homeowner sees zones, not circuits).

The reply is the **contract**. Ack means the owner is now bound to do the
thing; nack says why it is not. What the owner does after ack (how fast,
within what band) is the contract term, stated in the surface's executor
section, not left to the client to guess.

## The surfaces we have

| Owner → counterparty | Declaration | Commands | Reply | Authority | Spec |
| --- | --- | --- | --- | --- | --- |
| scada → admin | `scada.control.capabilities` (`gw.command.interface` per node) | relay and command-node events, DAC values | `gw.dispatch.ack` / `gw.dispatch.nack` | admin session + command tree | `gridworks-admin/executor/primary.md` "The capabilities contract", `gridworks-scada/executor/control-hierarchy.md` "Command interfaces and replies" |
| scada → LTN | the leaf-ally cover (today implicit in the ally's states; declaration Open) | `FsmEvent` / `AnalogDispatch` under the dispatch contract; zone governance to come | ack / nack | dispatch contract + command tree | `gridworks-scada/executor/primary.md` "What the SCADA is"; declaration Open |
| LTN → homeowner | Open (a per-zone declaration: setpoint, band, allowed values) | setpoint, band | contractual ack (setpoint held, by when, within what band) / nack with reason | homeowner identity; impact-scaled step-up | `gridworks-ltn/executor/primary.md` "Homeowner command surface" |
| gnr → registrants | the registry's create/reparent command words (`g.node.create.cmd`, `g.node.reparent.cmd`) | create, reparent | `g.node.cmd.ack` / `g.node.cmd.nack`, refusals captured too | FIS single writer + per-row sema axioms | `grid-node-registry/executor/primary.md` "Write path & egress" |
| interior node → its boss (hp-boss, pico-cycler, circuit FSMs) | `gw.command.interface` on the node (in-process today; layout declaration proposed under [OPS-392](https://linear.app/gridworks/issue/OPS-392)) | the node's event enum | ack / nack | command tree | `gridworks-scada/executor/control-hierarchy.md` |

The same shapes serve in-process and on the wire. Sema's jurisdiction is
the wire; an in-process surface uses the same enums so the two never
drift ([OPS-394](https://linear.app/gridworks/issue/OPS-394), capability principles).

## Rows and vocabularies

A declaration keeps two lists apart. The **rows** are the nodes the
counterparty sees state for; the **vocabularies** are the commands it may
send, one entry per node and event type. The two do not coincide: a node
under an interior command node is a row with no vocabulary (its owner's
row carries the command), and an interior node may have several
vocabularies. In `scada.control.capabilities` the rows are
`CommandNodes`, the vocabularies `CommandInterfaces`.

The strain in the current shape is that a row's state enum rides on its
vocabulary, so a row with no vocabulary declares no state type; the admin
client takes a row's state type from its first interface and matches an
interface-less row's `single.machine.state` against an empty string,
special-casing `relay.pin` (`gwadmin/watch/clients/relay_client.py`). It
renders, not by contract. The fix is a state type on every row, with
vocabularies kept as the sendable set; it rides with the layout-word
declaration for interior nodes (Open below). Until then the scada holds
the split by hand, `Scada.COMMAND_NODE_CLASSES` (rows) and
`Scada.COMMAND_NODE_INTERFACES` (vocabularies).

## Rules

Candidates while this doc is Draft; each becomes binding when a second
surface is built against it.

1. **Declare before consume.** A surface is one sema word the owner
   publishes; the counterparty builds its view from that word alone.
2. **Commands are events on a state enum.** Both are sema words; a
   command enum with no word is the defect (states crossed a wire and got
   words, commands stayed in-process and did not).
3. **Every command gets a reply.** Ack or nack with a reason; a refusal
   that is only logged is a swallowed order, the maple failure.
4. **The owner enforces authority.** The tree, the session or the
   contract decides; the client's identity is checked at the envelope and
   the FIS rule, never trusted from the payload.
5. **Ack is a promise.** The executor section for the surface states what
   ack binds the owner to, including timing. That statement is the
   contract the counterparty holds.
6. **Reply and state report are different messages.** The counterparty
   can tell "your command was taken" from "the target changed", because
   the second may lag the first or never come.
7. **One writer per target.** A surface never creates a second party that
   can command the same target behind the holder's back. A second
   counterparty gets its own surface, one tier up, that the holder
   translates.
8. **Authority scales with impact.** Low-impact commands ride a normal
   session; high-impact ones need a fresh, hardware-bound assertion
   (mtls-fis-auth, [OPS-420](https://linear.app/gridworks/issue/OPS-420)).
9. **Say what happens when the counterparty is gone.** Every surface
   names its absent-counterparty behavior: admin session death returns the
   scada to Auto; contract loss returns it to LocalControl; the homeowner
   surface degrades to the last accepted setpoint.
10. **Mechanism and meaning stay apart.** Typed command, typed reply,
    one audit event per command, whatever the carrier. A surface moves
    carriers without changing a word.

## Open

- The scada → LTN declaration word: whether the ally's cover is published
  like the admin cover or fixed by the contract word.
- Whether a surface's declaration and its contract terms (rule 5) are one
  word or two.
- Where the in-process command interface for interior nodes is declared
  ([OPS-392](https://linear.app/gridworks/issue/OPS-392) proposes the layout word).
  Deferred, not decided against: hp-boss and the pico-cycler declare their
  vocabulary in `Scada.COMMAND_NODE_INTERFACES` and
  `CommandNode.send_state_command` maps the HpBoss actor class to
  `TurnHpOnOff` by hand; relays declare theirs in the layout word
  (`relay.control.config`). Whether the layout word carries an interface
  per node, so capabilities become a pure projection of the tree and the
  hand-map goes, waits for a second consumer of the surface. Sub-questions:
  whether the interface lives on the ShNode word (shared with every
  consumer) or in a sibling list keyed by node name (a layout-word-only
  change); whether `new.command.tree` carries it or stays authority-only.
- One refusal with no speaker. NotAControlNode: only the scada's routing
  knows a dispatch target is not a command node (`process_admin_dispatch`
  finds no communicator and drops it silently). Decide who speaks and
  whether the admin sees it, with the command-interface work. (The
  `FromHandle` mismatch is settled: the receiver logs, glitches, and
  stops; scada executor `control-hierarchy.md` "Command interfaces and
  replies".)
- Command enums still without sema words: `top.event`,
  `change.heat.pump.control`, every LocalControl and LeafAlly event enum;
  the LC and ally state words still carry the `gw1` prefix.
