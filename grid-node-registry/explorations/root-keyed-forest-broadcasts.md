# Root-keyed forest broadcasts — channels, listeners, and time-coordinator trees

Status: Draft · Pass 0 · Updated 2026-07-04

> What this is: the settled design for how topology changes propagate — the
> `radio_channel` rule, who binds what, and the adjacent canonized decisions
> (time-coordinators-as-GNodes, terminal leaves). The normative distillate lives
> in [`../executor/primary.md`](../executor/primary.md); this holds the reasoning
> and the queued follow-ups.

## The mechanism (gwbase, as-built)

A `JsonBroadcast` key is `rjb.<from-alias>.<from-class>.<type>.<radio_channel>` —
the first four positions are hyphenated to single tokens **so that** the channel
can be the dotted, multi-segment tail (`json_broadcast_routing_key` appends it
as-is; the parser rejoins `tokens[4:]`). A `LeftRightDot` **alias is therefore a
natural channel**: its dots become real routing-key segments, and topic bindings
can address the alias hierarchy.

## The channel rule (settled 2026-07-04)

> **Broadcast on the alias the audience is bound to** — the name listeners
> currently know the changed subtree by.

- **Re-parent (introduces N under E, moves children):** channel = **E's alias** —
  the deepest ancestor whose alias is *stable* across the change and a proper
  prefix of every moved node's OLD alias, so every affected listener's binding
  set includes it. Keying on N's *new* alias would reach nobody (listeners bind
  prefixes of aliases they knew). E's unaffected children also hear it and ignore
  it — bounded spillover, one message.
- **Pure rename of a subtree (future op):** channel = the top node's `prev_alias`.
- **Snapshot (periodic, designed not yet implemented):** channel = the top node's
  current `alias`.

Well-formedness invariant: **the channel always equals the `alias` or
`prev_alias` of a node the audience could resolve** — for the current re-parent
op, `parent_alias(cmd.new_node.alias)`. Listener logic is *identical* across all
three cases: every broadcast means "here is the current state of this subtree";
the listener upserts and, if its own GNodeId appears under a new alias, reacts.
No listener needs to know which kind of broadcast it received.

## Who binds what

- **Ancestor-listening (GridworksActor tier only):** a GNode binds one exact
  channel per prefix of its own alias, **self-inclusive** (a node with its own
  TC/child concern still hears its own channel), O(depth) ≈ 5–6 bindings at boot.
  Non-GNode Orchestrators (Supervisor, TimeCoordinator, GridNodeRegistry) have no
  ancestor chain — the subscribe helper belongs on `GridworksActor`.
- **Subtree monitors (FIS, analytics):** one trailing-`#` binding per authority
  root (`…g-node-forest.d1.isone.#`) hears every change in that subtree — the
  authority-scoped FIS subscription falls out of the same mechanism, one binding.
- **Rebind lifecycle:** a rename changes a node's ancestor set, so its bindings go
  stale after the very event it just heard. Resolved naturally when bindings
  derive from the alias at boot (the redeploy that adopts the new alias rebinds);
  a passively self-updating listener must explicitly rebind. The future gwbase
  `subscribe_ancestors` helper owns this.
- **MQTT-native leaves:** scadas reach the bus via `amq.topic`; gwbase **0.5.6**
  adds the `gnrmic_tx → amq.topic` bridge (`rjb.#`, broadcasts only — the
  TimeCoordinator precedent), so they can hear too. The MQTT plugin rewrites
  topic dots to slashes on that side; payloads intact. Safe to bridge: a forest
  carries aliases + immutable ids, never coordinates.

## No re-broadcast of the old — simple, with FIS as the backstop

Settled: the registry does **not** keep broadcasting on old channels for a grace
window. Convergence is by authorization, not delivery ("if it flaps, skip the
acks"): durable subscriber queues already hold a broadcast across a listener's
downtime, and a truly-missed rename surfaces as a FIS deny → redeploy. A bounded
dark window per rename, at ~yearly cadence, is the accepted trade — and it is
what makes **prioritizing FIS** the right next move. (The legacy FIS writeup
confirms the deny is *bare*: the `rabbitmq-auth-backend-http` protocol returns
only `allow`/`deny` — there is no channel to hand the client a hint, so
deny-with-hints was never on the table mechanically.)

## Time coordinators (canonized 2026-07-04)

**TCs are GNodes** (Logical, `GNodeClass: TimeCoordinator`), and **TC trees hang
off the copper**: `d1.time` is the universe-level clock (a Logical forest root);
a house clock is a **child of the LTN** (sibling of `.scada` / `.ta`). The
resolution rule for a *simulated* GNode:

> Walk **self, then ancestors, nearest first**; the first node with a
> TimeCoordinator child names your clock. If none, the universe-level
> `<uni>.time` is the default — uniformly: treat the bare universe token as the
> virtual top ancestor whose "children" are the forest roots, and `d1.time` is
> its TC child.

(Self-inclusive matters: an LTN with its own TC child marches to it, not to a
regional clock.) This is lexical scoping for time domains — a simulated house
overrides the regional clock; everything else defaults up the chain — and it is
derivable from registry state alone, no extra config. Every actor already
addresses its TC by alias (`my_time_coordinator_alias`), so registering TCs turns
those strings into verifiable map names; in the FIS era every durable bus
participant needs a GNodeId anyway (cert `CN=GNodeId`). Registry row now; the
runtime tier (Orchestrator → GridworksActor) migrates when convenient.

## Queued sema axioms (author when the sema claim frees up)

Enforcement is **sema-first** (keeps the blockchain lift light — a validator
checks the payload, not a Postgres side-table):

1. **At most one TimeCoordinator child per GNode** — as a `g.node.forest` axiom
   (checkable within any subtree-complete forest: group nodes by alias-parent).
   *Stronger alternative worth weighing at authoring time:* extend `g.node.gt`
   axiom 5's suffix semantics with **`.time` ⇔ TimeCoordinator** — then
   at-most-one-per-parent is **structural**, free from alias uniqueness itself
   (there is only one `X.time`), and survives any backend that enforces the alias
   ledger. Costs a `g.node.gt` version step.
2. **`.ta` and `.scada` are terminal** — no node's alias-parent may be a
   TerminalAsset or Scada (today only an unconstrained Logical could sneak under
   one). Terminal is in the name; the house TC deliberately hangs off the LTN,
   not the TA. Forest axiom + a mirroring check in `gnr.db.validate`.

Both queued rather than done: `sema/` + `wiki/sema/` are held by another session.
