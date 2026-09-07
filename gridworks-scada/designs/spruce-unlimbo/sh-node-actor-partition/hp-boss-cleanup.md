# hp-boss-cleanup (rope chunk)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: a chunk of the `sh_node_actor` partition rope, unestimated;
> hub [`primary.md`](primary.md). hp-boss becomes a first-class permanent
> system delegate, present in every layout, tested for the first time.
> Decisions 2026-09-01. **Done when** admin turns the heat pump on and off
> through hp-boss on spruce (below).

## Decisions

- **hp-boss always exists** — every layout family, ActorClass HpBoss,
  enforced by each word's core axiom
  (`CoreShNodesExistenceAndActorClass`). Chosen over
  conditional-on-commandability because the confirmed reporting rule
  requires it: **hp-scada-ops-relay reports to hp-boss in ALL states in
  ALL layouts** (the pico-cycler/vdc pattern; admin commands through
  it: `admin.hp-boss.hp-scada-ops-relay`).
- **HAS vs USING.** Having a sieg loop is topology (the layout word —
  `gw.house0.layout` MEANS has-sieg; sieg-less homes are
  `gw.house0.no.sieg`, see the layouts spoke). USING the loop is
  operational: `UseSiegLoop` migrates from `Hydronic` to
  `gw.house0.operational.params`. hp-boss and sieg-loop are **dormant**
  when unused — the MonitorOnly pattern: the node exists, the actor
  learns engagement at boot; the command tree reflects it.
- **Commandable heat pumps hang under hp-boss.**
  `Hydronic.HpCommandNodeName` (optional, both words) names WHICH node
  takes commands — `hp-odu` (native modbus, e.g. elm's Arctic arriving
  this week) or `hp-ctrl-box` (Samsung via MIM). Conditional axiom
  `CommandableHeatPump`: present ⇒ the named node exists with a
  ComponentId and its effective handle parent is hp-boss.

## The work

1. Sema core-axiom edits + Nolan regen (hp-boss node returns to the
   Nolan fixture NOW, not when the MIM arrives).
2. Code: hp-boss family-selected like LC/LA; the interior-subtree rule
   covers its tree placement (with the pico-cycler work); dormancy
   gates on ops.
3. **First-ever hp-boss tests**: tree placement on both fixtures,
   dormant-vs-engaged behavior, sieg vs non-sieg command shapes,
   commandable-node dispatch when HpCommandNodeName lands.

## The twin architecture (contemplated 2026-09-01)

- **hp-boss stays sema-native**; the commandable device gets a **digital
  twin actor** — sema command events in, hardware protocol (modbus)
  out — exactly the relay-actor pattern (sema in, i2c out). One
  coordination brain for every heat pump; only the twin differs,
  selected by the component's DeviceType (axis 3). The sim story falls
  out: a sim hp twin on the same command surface lets sim-spruce
  exercise heat-pump control with no modbus wire.
- **Taxonomy settled:** interior tree nodes = command nodes; tree
  leaves = actuators (the existing code word — every actuator actor is
  some device's twin, but "twin" is implementation nature, not a tree
  role). Axiom families per layout word: Core / CommandNodes /
  RequiredActuators (relays + DACs — Nolan's RequiredRelays
  generalizes; the Nolan secondary-pump DAC belongs here) /
  RequiredEquipment (physical inventory, NoActor — hp-odu and
  hp-ctrl-box move here out of RequiredCommandNodes) / RequiredSensing
  + conditional CommandableHeatPump.
- **Actuator-hood of hp-odu vs hp-ctrl-box is per-instance data, never
  vocabulary**: `HpCommandNodeName` declares it at authoring time
  (spruce → hp-ctrl-box when the MIM is wired — NOT before, so it is
  not required today; elm → hp-odu for the native Arctic); undeclared =
  both NoActor, hp-boss dormant, safe degrade. RequiredActuators lists
  only unconditionally-certain actuators.
- **ActorClass: ONE new value, `HpTwin`** (settled 2026-09-01 after
  weighing HpOduTwin/HpCtrlBoxTwin — two classes would re-introduce at
  the heat pump the family-in-the-actor-class coupling the krida
  retirement removes at the relays). Joins gw1.actor.class/013 in
  place (staging). The pairing is the layout's declaration, not a
  derivation: the CommandableHeatPump axiom is a biconditional —
  HpCommandNodeName present ⇒ the named node is hp-odu or hp-ctrl-box
  with a ComponentId, ActorClass HpTwin, effective handle under
  hp-boss; AND any HpTwin-classed node SHALL be the declared node. So
  at most one HpTwin per layout, only on those two names, zero when
  undeclared. NO sim actor classes: sim twins ride sim device-type
  records (the GridworksSimGw108 move; SimRelayActor is the old
  pattern, not the template). Mirror-before-artifact: sema + gwsproto
  enum first; a fixture speaks HpTwin only when at least a stub actor
  exists (unknown ActorClass coerces to default at decode).
  `layout.actuators` (relays + zero_tens) additionally returns the
  declared node.
- **Command-forest invariant (settled):** the layout's authored handles
  are the INITIAL command tree; the invariant governs EVERY tree the
  scada publishes. Enforcement splits by checkability:
  (a) every actuator SHALL be a leaf and SHALL have a boss (dotted
  handle), and (b) every dotted-handle leaf SHALL be an actuator or a
  command node → sema axiom 2 on new.command.tree/002 (in place;
  validated at construction on every publish, boot included).
  (c) every non-actuator leaf SHALL be a command node in a Dormant
  state → NOT expressible on the wire (the tree carries no state);
  enforced in scada code and asserted by the tree matrix against the
  state machines, with a NoActor waypoint's dormancy inherited from
  its owning actor (a leaf `n` is dormant iff LocalControl is not
  occupying it).
- **Dormant gets one canonical meaning** (work item): a Dormant actor
  performs no physical actuation and issues no commands to its
  subtree; its handles stay in the published tree, inert; watchdog
  pats, state reports and telemetry continue. Distinct axis from
  MonitorOnly (ops-declared authority posture for the whole scada).
  Code: one `dormant` predicate on the actor base tier, each actor
  deriving it from its own enum — no per-enum string matching; clause
  (c) consumes it.

## ▶ Do this next: admin turns the heat pump on and off through hp-boss

The experimental test of success for this chunk: admin turns the heat pump
on and off through hp-boss, the heat pump's command node, not by
dispatching `hp-scada-ops-relay` directly; witnessed on spruce. Needed
before anything else that touches the heat pump.

## Sieg loop needs its tires kicked

The sieg-loop control has never run unsupervised in the field for a
long stretch. Treat it as unverified: the hp-boss/sieg test work here
is also the sieg loop's first real exercise, and field confidence
comes only through this design's EDD bar (bench/box runs), not the
suite.

## Open

- hp-boss modbus driver selection (keys on the commanded node's
  component DeviceType) — prep decisions of 2026-08-31 fold in here.
- What "dormant" concretely refuses (mirror the MonitorOnly list).
