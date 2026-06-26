# Launch a new simple MarketMaker

Status: Draft · Pass 0 · Updated 2026-06-10 · Linear: OPS-431

> What this is: the **hub** of the design to launch a new, simple MarketMaker —
> the locked decisions, scope, and open questions, as a tight seed for a fresh
> session to turn into a task list / Linear issues from a clean slate.
> **Spoke** (the background evaluation + vision notes this plan rests on):
> [`evaluate-existing-repo.md`](evaluate-existing-repo.md). Prior-art survey to
> run alongside: [`../../research/market-structure-survey.md`](../../research/market-structure-survey.md).
> GNode model reference: [`../../research/gnode-taxonomy.md`](../../research/gnode-taxonomy.md).
> Full architecture: [`../../../economy-energy-markets/executor/primary.md`](../../../economy-energy-markets/executor/primary.md).

## Locked decisions (2026-06-09)

1. **Build fresh, don't tweak.** The existing code never ran, the clearing is
   stubbed, and every layer is being replaced — the old repo is *reference, not
   base*. (Vision, not how.)
2. **Reuse the repo identity; gut + rebuild in place.** Keep the
   `gridworks-marketmaker` name / remote / PyPI / wiki-domain wiring; delete
   `src/gwmm/`, `CodeGenerationTools/`, and stale config; scaffold the package
   from the current gwbase service template. **Blocker:** disposition the
   uncommitted `asl/` working-tree WIP first (clean-tree rule) — it is legacy
   (asl → Sema), almost certainly discard, but confirm it is nobody's live work.
3. **Branch hygiene.** Drop the 15 stale `dependabot/*` remote branches; audit
   `origin/main` (6 commits ahead of `dev`) to choose the rebuild base. *User
   runs all git; remote deletion is irreversible.*
4. **Stack + tooling.** **gwbase** (current `ActorBase`, real wall-clock — not
   the `SimTimestep` / `TimeCoordinator` simulation harness) + **Sema** types.
   **Move to `uv`** for packaging/deps (drop poetry/pip + the old lockfile).
5. **Two surfaces, asymmetric roles.**
   - **Message bus (Rabbit/AMQP) = the spine.** bid in → the maker's queue
     orders it (**queue = ordering authority**) → **`market.maker.ack`** (the
     binding contract) → `latest.price` / dispatch out. Bids are fast +
     cumulative, so arrival mis-ordering is harmless.
   - **The stored timestamped ack IS the contract** (decided 2026-06-10).
     The maker sends the ack AND stores it timestamped; **storage is the
     constitutive act** — the sent message is notice of the contract, not
     the contract. The maker side is the sole source of truth for
     obligations; nothing persisted on a device (scada/LTN) ever
     constitutes one. (Consequence already cashed in elsewhere:
     scadas wipe device event stores on version mismatch, provably
     harmless to obligations.)
   - **REST = the storefront.** Advertise market products + rulebook + slot
     schedule + latest cleared prices ("here is the market and here are the
     rules — go").
6. **Greenfield to design (Sema).** `market.maker.ack` does **not** exist —
   Sema has only `gridworks.ack` (a transport-level receipt, *not* this).
   Maker-side types also needed: an **offer/supply curve**, and a **market
   result/book** report (re-express the legacy `bidoffercurves` shape).
   Already exist: `bid/000`, `latest.price`, `market.product`,
   `price.quantity.unitless`, the `market.slot.name` format.
7. **Target the live counterparty.** The bidder side is real in `gridworks-scada`
   (FLO/Dijkstra → `bid.recommendation` → `bid`, awaiting `market.maker.ack`).
   Build the maker to that contract.
8. **Walking skeleton first.** Thinnest end-to-end slice on the *real* seams with
   trivial clearing: keep `clear_market(book) → price` as an explicit seam with a
   dumb implementation; prove bid-in → queue → ack → price-out + REST advertise.
   **Then** survey prior art (market-structure-survey) and slot a real engine in
   behind the stable seam.

## Open for the task-list session

- Exact **cumulative-bid / queue-ordering / ack** semantics (sequence,
  supersession, per-bid vs amortized admission). Partially settled
  2026-06-10: the ack's *constitutive* nature is decided (stored
  timestamped ack = the contract, above); what remains open is what the
  ack *asserts* about quantity/price/slot and how supersession reads.
  Bid-shape axioms for self-scaling (anchor / ticks / aggregation semantics):
  [`../../explorations/bid-axioms-and-self-scaling.md`](../../explorations/bid-axioms-and-self-scaling.md).
- **Trust + market substrate** — signed, distributed, non-hijackable (a chain's
  real draw is *anti-capture*, not throughput); framework-agnostic (econ-markets
  inv. 14), **not** committed. Two roles, likely different answers: credentials /
  rights are **NFT-like** (TaDeeds, TaTradingRights); the market machinery could
  be a *distributed web of interactive smart contracts* (the *Redefining Demand
  Response* vision). Open question is **layering** — what goes on-chain (binding
  ack / settlement / deeds / rights) vs off-chain (the fast cumulative bid
  stream, which fees/latency make a poor on-chain fit). See the evaluate spoke.
- **5-min slot** binding: maker-agnostic format axiom vs maker-side check.
- Whether the maker needs a real **offer/supply curve** at launch or sets price
  from an external signal.
- **REST storefront process model.** gwbase is deliberately silent on serving
  HTTP — the spine is its whole job; a storefront is service-level
  composition, not a base-class capability. Rule to hold: **nothing binding
  crosses REST** (the ack lives on the bus) and **the maker actor is the
  single writer of the market book**; REST serves derived, read-only
  projections. Named anti-pattern from the legacy repo: FastAPI + Redis as
  shared *authoritative* state — slot books (and even sim time) fetched from
  an `aiocache` Redis by a separate process, with TODOs admitting the books
  had no single home. State of record must not live in a cache; under the
  single-writer rule a cache becomes unnecessary rather than replaced.

## Enables next: the hybrid simulated fleet

Once the maker is real it **unlocks** reworking the Algorand-era simulation into
a more powerful **hybrid real+simulated fleet** of hundreds of GNode actors — the
maker is the market they bid into. No dedicated design exists yet; it is vision
plus scattered building blocks, and is a natural follow-on (not part of this
rebuild):

- **Prior art to rework:** the legacy `gridworks-world` repo (the Algorand-era
  "World" sim orchestrator).
- **Orchestration roles:** World / TimeCoordinator / NetworkModeler — see
  [`../../research/gnode-taxonomy.md`](../../research/gnode-taxonomy.md) (currently
  Logical).
- **Per-node unit (already designed):** compose
  `../../../gridworks-scada/designs/simulated-test-environment.md`
  (a single simulated house on gwbase) up to fleet scale.
- **gwbase primitives:** `GridworksActor`, `GNodeStubRecorder`,
  `TimeCoordinatorStubRecorder`.
- **Fleet identity at scale:** FIS —
  [`../../../gridworks-fleet-index-service/executor/primary.md`](../../../gridworks-fleet-index-service/executor/primary.md).
- **Vision:** [`../../../vision/primary.md`](../../../vision/primary.md) "The hybrid
  game — one world, real + simulated" (spoke:
  [`../../../vision/hybrid-game.md`](../../../vision/hybrid-game.md));
  [`../../../vision/transactive-grid.md`](../../../vision/transactive-grid.md)
  "One fabric, real and simulated."
