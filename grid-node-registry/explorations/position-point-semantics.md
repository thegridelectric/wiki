# Position-point semantics — does the registry enforce location?

Status: Draft · Pass 0 · Updated 2026-07-03

> What this is: the contemplation behind a deliberate **non-decision** — the Grid
> Node Registry **stores** each physical GNode's `PositionPoint` but enforces
> **nothing** about it (no distinctness, no accuracy, no premises boundary). This
> records *why*, so a future agent doesn't re-lit the question or bolt a location
> axiom onto gnr. Location *trust* lives in TaValidation, not the registry.

## The question that prompted it

Physical GNodes carry a lat/lon. A tempting invariant: the copper backbone
*above a house* should have **distinct** positions (so the lines/cables between
junctions have real length), while assets *within* a house may co-locate. It felt
right — the registry's purpose is a collaboratively-built map of the low-voltage
grid, and a zero-length conductor between two same-point junctions is meaningless.

## Why we did NOT make it a registry invariant

The clean rule dissolves under real cases, and the enforcement belongs elsewhere:

- **A house is not one point, and not one boundary.** Multiple LTNs/TAs/Scadas sit
  behind one meter; a single dwelling can have **two distinct utility PCCs** (seen
  with VCharge in England); a large residence may legitimately want multiple
  locations. So "one premises = one co-location cluster with a single boundary
  above it" is false.
- **Upstream ConnectivityNodes may share a location** too, so even "backbone
  junctions are pairwise-distinct" is not universal.
- **Residential topology is trusted-by-description, not location-validated.** The
  resident describes their own topology; the registry trusts it. Accuracy /
  plausibility of a location is a **certification** question, not a structural one.

Decisive point: location *trust* is exactly the job of **TaValidation** — the
TaDeed plane that certifies asset reality, already owning "a point SHALL fall
within the footprint of the building it locates" (see substrate-fit, OPS-391). Put
the nuanced, still-evolving location logic there, where new knowledge will surface,
and keep **gnr as simple as possible**: it stores the `PositionPoint`, enforces
nothing about it. (Per-row Sema axiom 2 still requires a physical GNode to *have* a
`position_point_id` — presence, not correctness.)

## What we borrowed, and the one divergence to remember

- GridWorks's `ConnectivityNode` / `PositionPoint` are **CIM-aligned** (IEC
  61970/61968), simplified for distribution-level modeling.
- **Divergence worth remembering:** canonical CIM attaches location to the
  *equipment* (`PowerSystemResource`) — a `ConnectivityNode` has *no* `Location` —
  and a line (`ACLineSegment`) carries a **stored `length`** plus its own polyline.
  GridWorks inverts this: **location lives on the node, edges are mere pointers**,
  so a line's length is **derived** from its two endpoint nodes, not stored. Fine
  for a node-keyed map; if we ever need an authoritative length independent of
  geometry, add a length attribute to the edge rather than trusting the derivation.

## If we ever DO want the seams as first-class (deferred, not now)

CIM already names the seams this contemplation circled, should grid-map fidelity
ever demand them as registry vertices:

- **`ServiceLocation`** = a premises / real-estate location (many assets share one).
- **`UsagePoint`** = the metering/attribution point — ≈ our **LeafTransactiveNode**.
- **`ServiceDeliveryPoint`** = the utility↔customer handoff — the **PCC** (today
  only prose in economy-panel: "master economy meter on a parallel service
  entrance"). A house with two PCCs = two `ServiceDeliveryPoint`s.

Not building these during standup. If the need surfaces (e.g. real feeder mapping,
OPF, loss modeling), borrow these names rather than inventing new ones.
