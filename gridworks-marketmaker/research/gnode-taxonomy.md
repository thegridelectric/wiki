# GNode taxonomy — working reference

Status: Draft · Pass 0 · Updated 2026-06-09

> What this is: the GNode classification + copper-topology model as it stands
> today. **Working reference, not a polished spec and not a mirror of code** — it
> lives here because the MarketMaker rebuild is where this taxonomy firms up. The
> class *values* still move; treat the prose here as the concept, not the
> authority. (Vision-grade pieces went to
> [`../../vision/transactive-grid.md`](../../vision/transactive-grid.md).)

## What a GNode is

A **GNode** (Grid Node) is a node in the GridWorks model of the electric grid.
Each GNode has a **GNodeAlias** — a structured, **mutable** `LeftRightDot`
identifier (e.g. `w.isone.me.versant.keene`). Unlike the usual developer sense of
"alias," a GNodeAlias is **not** ephemeral. Taken together the aliases form a
**tree** that (1) encodes the topology of the electric grid and (2) gives
organizational structure to actor communication and to the time-series state
data the actors generate. `LeftRightDot` transforms to `LeftRightHyphen` in
message routing keys, so the dot can stay a routing-key separator carrying extra
addressing.

## Two classifications: structural vs functional

A GNode carries two independent classifications:

- **Structural ontology — `base.g.node.class`.** *What a node structurally is on
  the grid.* Every GNode declares exactly one. **Cross-organization
  interoperability is governed here** — this is the shared vocabulary other orgs
  must agree on. Values: `TerminalAsset`, `LeafTransactiveNode`,
  `ConnectivityNode`, `MarketMaker`, `Logical`.
- **GridWorks function — `gw.g.node.class`.** *What service/role a node plays for
  GridWorks.* Org-specific — another org may define its own `<ns>.g.node.class`.
  Adds operational roles: `Scada`, `PriceForecastService`,
  `WeatherForecastService` (alongside the physical classes).

So a node's *structure* (interoperable) and its *function* (org-local) are named
separately.

## The structural classes

- **TerminalAsset (TA)** — a physical transactive device behind an atomic metered
  point (heat pump, water heater, battery, EV…). A GridWorks avatar for a real
  Transactive Device; the bijection is established by a **TaDeed**. A TA also
  pins a lat/lon known to be on grid copper, and a meter that measures *exactly*
  the TA at the required accuracy.
- **LeafTransactiveNode (LTN)** — the **atomic metered unit**: the smallest
  indivisible metering boundary that can participate in markets / enter Dispatch
  Contracts on behalf of a TA. **Every TA ↔ exactly one LTN.** It sits at an
  infinitesimal slice above the metering point, so it too is copper-anchored. It
  is the structural unit of market participation (cf.
  [`../../economy-energy-markets/executor/primary.md`](../../economy-energy-markets/executor/primary.md)
  invariant 9).
- **ConnectivityNode** — a physical topological node where conductors join,
  split, or change configuration. Aligned with the **ConnectivityNode** of the
  IEC 61970/61968 **CIM**, simplified for distribution-level modeling and OPF.
- **MarketMaker** — a **physical constraint point in the conductor topology** that
  requires localized market coordination (a feeder constraint, a transformer
  limit), where a MarketMaker actor computes local prices for balancing and
  constraint compliance. This is the rebuild's anchor: each MarketMaker is
  fractal, anchored at a copper-sub-tree constraint point (cf. economy-energy-
  markets).
- **Logical** — a non-physical GNode with no inherent conductor-topology or
  metering semantics. Used for services (SCADA, forecasting) and for simulation
  roles.

## Vertices are GNodes; edges are pointers

The grid's topological **vertices** are GNodes — `ConnectivityNode`s where
conductors meet, with `TerminalAsset` / `LeafTransactiveNode` at the metered
leaves. The **edges** between them (lines, cables) are **not** GNodes: connectivity
is represented by **pointers into GNodes**. Only nodes are first-class; the wiring
is references.

## "Copper" vs Logical

The physical (non-`Logical`) classes are the **copper** — each tied to a geopoint
known to be on the grid. The `Logical` class is everything off-copper. The
exciting hard problem this models: most distribution utilities lack a real-time
(often even a static) picture of their low-voltage network, and even when they
have it, it is hard to share — so the shared GNodeAlias tree is a way to build
that map *collaboratively*.

## A different grain: SCADA actors (`gw1.actor.class`)

Separately from GNode class, **`gw1.actor.class`** classifies the **actors inside
a SCADA** — `PrimaryScada`, `SecondaryScada`, `LocalControl`, `LeafAlly`,
`PowerMeter`, `Relay`, `HpBoss`, and the various sensor/relay modules. This is a
*finer grain* than GNode class: a single `Scada` GNode contains many such actors.

## Trust / validation

GNode credentials — **TaDeeds** (asset reality) and **TaTradingRights** (market
participation) — anchor trust in who a node is and what it may do. The
**substrate is an open choice** (framework-agnostic — economy-energy-markets
invariant 14; see
[`../designs/launch-new-simple-marketmaker/evaluate-existing-repo.md`](../designs/launch-new-simple-marketmaker/evaluate-existing-repo.md)).
The *principle* (signed, distributed, non-hijackable credentials) is kept; the
vendor binding is not.

## Still open / mutating

- The canonical class **values** currently live in Sema
  (`base.g.node.class`, `gw.g.node.class`, `gw1.actor.class`) but are expected to
  keep moving as the rebuild proceeds — **do not treat the lists above as
  authoritative**; reconcile at firm-up. This doc is the *concept*, deliberately
  not wired to the code.
- Simulation roles (World, TimeCoordinator, NetworkModeler) are currently
  `Logical`; whether they earn first-class classification is open.
