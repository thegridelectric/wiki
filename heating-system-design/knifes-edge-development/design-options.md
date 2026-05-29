Status: Draft · Pass 1 · Updated 2026-05-29

> What this is: the canonical input list of **design options Matt is
> choosing between** for his Knifes Edge development — heat source,
> storage, envelope, and electricity product. Lives separately from
> the Monte Carlo methodology doc so it can drive both the informal
> decision-brief deliverable ([`decision-brief.md`](decision-brief.md),
> in-flight) and any future Monte Carlo techno-economic analysis
> ([`knifes-edge-mc-cost-model.md`](knifes-edge-mc-cost-model.md)).
> Companion docs: [`todd-griset.md`](todd-griset.md) (legal counsel
> brief), [`regulatory-precedent.md`](regulatory-precedent.md) (the
> §102(20-B) hook), [`local-players.md`](local-players.md) (Our
> Katahdin, Winn opt-out signal).

## Project context

Knifes Edge — Matt Polstein's development in Millinocket, Maine.
**Versant Bangor Hydro District** (Penobscot County).

Phasing:

- **Phase 1: 14 homes** — immediate capital decision.
- **Phase-1 cluster: up to ~100 homes** — the cluster as initially
  scoped.
- **Site capacity: up to ~300 homes** — Matt's parcel has enough
  room to replicate the 100-unit cluster design **two more times**
  beyond the initial 100.

The long build-out window amplifies two things. First, AWHP capital
is time-varying (R290 transition), so the heat-source choice may
differ between phase 1, the rest of the first cluster, and the
later clusters. Second, **infrastructure and regulatory choices made
now** (the second conduit, the §102(20-B) HOA structure, the
HOA–Versant covenant terms) **cast a shadow over potentially ~3× as
many homes** as the initial 100-unit framing suggested —
strengthening the case for paying small optionality-preserving
costs now.

**Hard constraint: Every home must have AC.**



## Axis 1: Heat source

Each home gets a **primary heat source** plus optionally a
**backup**. Every home must have AC; if the primary doesn't
include AC capability, a separate AC unit is added.

The heat-source set is `{resistive, propane, heat pump}` (Matt
opened propane as an acceptable *backup* on 2026-05-29; propane
remains ruled out as a *primary*).

**Primary heat choices:**

- **Resistive elements** — cheap capital, COP 1. No backup needed
  (resistive *is* the heating). Pair with a separate AC unit.
- **Minisplits sized for AC** — provide AC + shoulder-season
  heating; need a winter backup.
- **Air-to-water heat pump (AWHP) sized for AC** — provides AC +
  shoulder-season heating; needs a winter backup. Capital BOM must
  include additional emitters (fan coil units).
- **Air-to-water heat pump (AWHP) sized for heating** — covers
  most heating; optional backup on the coldest hours when economic.
  Largest AWHP capital but smallest backup demand.

**Backup choices** (paired with any non-resistive-only primary):

- **Resistive elements** — cheap capital, COP 1.
- **Propane** — Matt opened this as acceptable on 2026-05-29.
  Higher capital + fuel-storage requirements; better cold-day
  economics than resistive when LMP is high.
- **Cascaded resistive + propane** — use whichever is cheaper
  hour-by-hour given current LMP and propane price.

**Liquid propane as the *primary* heat source** is kept only as a
baseline to beat, never as a winner.

**Phase-1-vs-later note.** AWHP capital is **time-varying** — the
expected US R290 transition and broader market maturation may drop
AWHP capital significantly across the build-out. The heat-source
choice may differ between phase 1, the rest of the first
~100-home cluster, and the later clusters (up to ~300 total). See
[`initial reference materials/polstein-design.md`](initial%20reference%20materials/polstein-design.md)
§ AWHP market trajectory.

## Axis 2: Storage

- **none / radiant only** — coupled slab as buffer
- **single ~119-gal tank** 
- **store-under-floor**


Each store choice carries its own controls (flow-control manifold,
SCADA PCB) — capital BOM differs per choice.

## Axis 3: Envelope

Use the **Nolan-house analysis** (existing Millinocket Matt-style
house, ran on resistive-only this spring) as the high-R reference.
Model **2–3 graded reductions** in R-value as discrete envelope
levels. Annual heat load per level via R-C / degree-day model
parameterized off Nolan-house metered data.

Matt's stated soft preferences: cares about house healthiness,
beauty, space; likes using less electricity for its own sake; would
accept lower R-value if the economics work. Encode as a soft
penalty on the envelope-reduction axis rather than a hard floor.

## Axis 4: Electricity product

1. **Versant standard residential**

2. **HOA-as-single-customer + heat-as-service** — *Todd's
   recommended path* (2026-05-28 meeting). HOA buys bundled retail
   electricity from Versant as a single commercial customer (likely
   under a binding HOA–Versant covenant); owns the heating
   equipment + the internal "second conduit" distribution; sells
   heat-as-a-service to homeowners at flat annual or HDD-indexed
   rates. Statutory hook: **§102(20-B)** landlord-tenant /
   abutting-parcel exemption. See
   [`regulatory-precedent.md`](regulatory-precedent.md) and
   [`todd-griset.md`](todd-griset.md).

3. **Microgrid (Title 35-A §3351).** Fallback to (2), with same
  "second conduit" distribution. One big
   downside vs. (2) is the cost of adding the grid-forming inverter
   and battery. Note: "supporting the non-firm load for 4 hours
   with no downgrade to SLA" (paraphrasing) is much easier than
   serving on-demand electricity. In island mode we turn off all
   electric heat; the distribution pumps remain on the Versant lines.

**For both (2) and (3):**

- lower delivery component
- wholesale / P-Node pricing exposure
- Efficiency Maine as energy supplier — flat-to-homeowner, EM does
  green banking, avoids coincident-peak charges (annual capacity +
  monthly), our forward-looking optimizer captures wholesale spread
- **regulation-service revenue from resistive backup** — non-trivial
  in the microgrid version; pulls the resistive option's lifecycle
  cost down and may shift the R-value optimum
- tail-risk regimes — last winter's polar-vortex pricing as one
  sample regime
- §3351 has no implementing rule yet, so a stipulated minimal-island
  definition in the petition is the practical path

## Critical near-term decision (Matt, now)

**Lay a second empty conduit in the same trench during Matt's
already-planned 3,000 ft trenching.** Matt-estimated $6k. Preserves
optionality for the HOA-as-single-customer route (option (2) above)
and the §3351 microgrid fallback (option (3)) without committing to
either. Without it: any future second-distribution scheme requires
re-trenching at multiples of the original cost. **Todd took this
seriously at the 2026-05-28 meeting.** Details in
[`decision-brief.md`](decision-brief.md).

## How this doc is used

- **Informal decision support** — [`decision-brief.md`](decision-brief.md)
  reads from here to lay out what Matt is choosing between and to
  scope the Todd-engagement asks.
- **Future Monte Carlo configuration** — [`knifes-edge-mc-cost-model.md`](knifes-edge-mc-cost-model.md)
  enumerates the discrete cells the MC walks; its §3 points here as
  the canonical list. Each axis above maps to either a discrete
  scenario set (electricity product) or a continuous-CI input
  (envelope R-value, AWHP capital trajectory, capital line items,
  etc.).
