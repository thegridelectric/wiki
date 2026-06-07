Status: Draft · Pass 0 · Updated 2026-06-06

> What this is: the canonical glossary for the Economy Energy Market
> System architecture. Terms are partitioned by **ownership** —
> GridWorks-coined vocabulary we define and refine vs industry-given
> vocabulary we work within vs cited precedent. Within each section,
> terms are alphabetical.

## Section 1: GridWorks vocabulary (active)

Terms GridWorks coins and controls.

- **Appliance Profile** — the exogenous reference load shape used
  in the Cleared Market. Heat-pump-without-storage typical-day
  shape for the customer's county and month, sourced from a public
  dataset (e.g., NREL ResStock), scaled to the customer's actual
  monthly total consumption.
  - Sema: TBD (county × month × hour load shape data structure).
- **the Cleared Market** — the GridWorks-operated multi-participant
  market that clears every settlement period. CEPs bring bulk
  profile-shape positions; LTNs bring per-asset actual-delivery
  positions; the Market Maker clears.
  - Sema: TBD (market-clearing data structures will need types —
    likely `cleared.market.book`, `cleared.market.position`,
    `cleared.market.result`, etc.).
- **the cohort** — informal language for the set of customers
  enrolled in a given TaAggregator or in a given deployment phase
  (e.g., "the Knifes Edge cohort"). Not structurally meaningful at
  the architectural level — what matters structurally is the
  TaAggregator, the DERA registration, and which LTNs are bidding.
- **Customer Rebate** — the monthly payment from the TaAggregator
  to the customer, as a defined share of the TaAggregator's share
  of the Cleared Market receipts attributable to that customer's
  LTN.
  - Sema: TBD.
- **Economy Energy** — electric energy delivered at times of
  renewable abundance, when wholesale LMPs are low or negative. The
  product the architecture exists to deliver. The term has older
  industry lineage — historically used by Midwest electric
  cooperatives — and was brought back into current discussion by
  Matt White (ISO-NE), who pointed us to it as the right framing for
  what we are delivering. GridWorks has adopted it as the canonical
  customer-facing product term.
  - Sema: TBD (product / market-output concept; may not need a
    boundary type at all).
- **[GNode (Grid Node)](../../glossary.md#gridworks-concepts)** —
  in the EEM context: **primarily about the copper sub-tree** —
  GridWorks's hierarchical map of the physical electric grid, with
  an addressing sub-space layered on top. Specific GNodes the EEM
  architecture cares about, all anchored to copper:
  - **TerminalAssets** — physical end-use devices (heat pump +
    thermal storage), located at the customer's premises.
  - **LTNs** — typically assigned to the location of the
    customer's meter. Each LTN represents exactly one TerminalAsset
    and sits at the leaf of the copper sub-tree.
  - **MarketMakers** — always assigned to a physical constraint
    point on the copper (feeder constraint, transformer limit,
    distribution substation, transmission constraint, etc.). The
    initial GridWorks Market Maker for our Maine launch sits at
    the cohort-level grid constraint; future MarketMakers will
    sprout up at other constraints as the architecture grows.
  - **TaReader and TaAggregator** — also hold GNode identities for
    cross-system addressing.

  **The vision.** As entities who want to do business or live within
  the GridWorks Economy Energy Market System join the architecture,
  they end up **co-creating a collaborative map of the low-voltage
  electric grid** by agreeing to share GNode aliases. This first
  implementation is about getting the business relationships right
  for the sample cohort; the bigger goal is to enable new
  MarketMaker GNodes to sprout up at grid constraints over time,
  building out the collaborative low-voltage grid map as a
  byproduct of EEM growth.
- **the GridWorks Economy Energy Market System** — the full
  architecture: TaReader + Market Maker + the set of TaAggregators,
  LTNs, CEPs, and TaValidators that meet the Participation
  Requirements.
  - Sema: TBD.
- **[LTN (LeafTransactiveNode)](../../glossary.md#gridworks-concepts)**
  — in the EEM context: the per-asset market-participating entity
  that bids in the Cleared Market on behalf of its TerminalAsset.
  Holds TaTradingRights delegated by the TaOwner via the SLA.
  Presents credentials to the TaReader for SCADA-honored dispatch
  and for Market Maker participation. Operated by a TaAggregator
  (default in our deployment) or by the TaOwner directly. The
  structural unit of market participation; multiple LTNs roll up to
  a TaAggregator's financial book. **An LTN is a GNode anchored to
  a leaf of the copper sub-tree — typically the location of the
  TerminalAsset's meter.**
- **[MarketMaker](../../glossary.md#gridworks-concepts)** — in the
  EEM context: the GridWorks-built clearing-house infrastructure
  that operates the Cleared Market. Computes CEP bulk profile-shape
  positions and LTN actual-delivery positions; clears every
  settlement period; routes net flows. One of the three separately-
  incorporated GridWorks-affiliated entities (alongside TaAggregator
  and TaReader). **Every MarketMaker is a GNode anchored to a
  physical constraint point on the copper sub-tree** — a feeder
  constraint, transformer limit, substation, transmission
  constraint, or eventually even a panel-level constraint inside
  a single home. The initial GridWorks Market Maker for our Maine
  launch sits at the cohort-level grid constraint behind Keene
  Road. As the architecture grows, additional MarketMaker GNodes
  sprout up at other constraints, building out the collaborative
  low-voltage grid map. **Forward-looking example:** a panel-level
  MarketMaker inside a single home — clearing local price signals
  among multiple TerminalAssets behind one residential panel — is
  a structurally clean way to avoid panel upgrades when a home's
  flexible-load count exceeds nameplate ampacity. The same
  constraint-point pattern, just at the smallest grid scale. The
  proposed open-source architecture for this scale lives at
  [`../../economy-panel/executor/primary.md`](../../economy-panel/executor/primary.md)
  (the "Economy Panel"). (The `base.g.node.class` value `MarketMaker`
  names this physical-constraint-point identity in the conductor
  topology.)
- **Mission-Aligned Supply Partner** — the role of the wholesale
  supply / hedging partner contracted by a CEP. MUST be a
  nonprofit, mission-aligned entity (joint-action agency,
  member-owned coop, or purpose-built nonprofit). Structural
  exemplar: MMWEC. Profit-maximizing corporate supply partners
  (Engie, Constellation, Shell, BP, NRG, Tenaska) are EXCLUDED
  regardless of operational fit.
- **Participation Requirements** — the defined criteria that an
  asset, LTN, TaAggregator, or CEP must meet to join the GridWorks
  Economy Energy Market System. The TaReader validates these at
  participation time. Framework-agnostic — currently evidenced by
  cryptographic primitives (TaDeeds, TaTradingRights), but the
  requirements are the architectural concept; the evidence
  mechanism is an implementation choice. See
  [`participation-requirements.md`](participation-requirements.md).
  - Sema: TBD (requirements as a structured artifact will need
    types; evidence-mechanism-agnostic).
- **TaAggregator** — GridWorks-defined entity that holds Service
  Level Agreements for a population of customers, operates LTNs on
  their behalf, aggregates LTN financials, and routes Customer
  Rebates. The TaAggregator's relationship to its customers is
  fiduciary by architectural commitment. May ALSO hold the III.6.4
  DERA registration for its customers' Aggregation — the two
  concepts are separable, but for our initial Maine launch the
  GridWorks TaAggregator is also the GridWorks Versant DERA.
  - Sema: TBD.
- **TaDeed** — independent cryptographically signed record from
  the TaValidator attesting to the physical reality of an asset
  (existence, location, system type, meter make/model and serial,
  installer identity, timestamp). **Owned by the TaOwner — always
  and intrinsically to physical asset ownership.** Transfers with
  the asset on sale or transfer. One of two current evidence
  mechanisms for Participation Requirements (the other is
  TaTradingRights).
  - Sema: TBD (boundary type; will likely be `ta.deed.gt` with an
    `inspector.identity` enum).
- **TaOwner** — the entity that owns a TerminalAsset. **The TaOwner
  ALWAYS owns the TaDeed** — TaDeed ownership is intrinsic to
  physical ownership of the asset; the TaDeed transfers with the
  asset on sale or transfer. The TaOwner separately holds the
  TaTradingRights, which they can **exchange for an SLA contract**
  with a chosen TaAggregator (or run their LTN themselves); the SLA
  is the exchange instrument, and it includes **clawback**: the
  TaOwner can claw back their TaTradingRights at any time per SLA
  terms (move to a different TaAggregator, take them back to
  themselves, or park them). For our residential deployments, the
  TaOwner is the homeowner (also the Customer of the CEP and of the
  TaAggregator). The TaOwner's pool defines the CEP's eligible
  customer base per ISO-NE territory — the CEP serves only TaOwners
  (per the CEP exclusivity invariants).
  - Sema: TBD.
- **TaReader** — GridWorks-defined entity that reads the meters of
  enrolled assets every interval, validates Participation
  Requirements at participation time, and acts as agent-AMR (per
  III.6.4(f)) for one or more DERAs. NEPOOL-wide. Validates TaDeeds
  and TaTradingRights presented by participants; submits
  authoritative interval data to ISO-NE and to the Market Maker;
  integrates with SCADA for honored dispatch. **The TaReader must
  satisfy two distinct sets of rules jointly:** (1) the FERC /
  ISO-NE rules for being an Assigned Meter Reader (industry rules
  — given to us; we comply); (2) the GridWorks rules for being a
  TaReader (our open-standard rules — we define these). The
  TaReader does NOT audit itself; the TaValidator performs
  independent audits of the TaReader's data integrity.
  Architectural precedent for the role separation from the
  customer-facing Supplier: UK Elexon BSC's combination of MOP +
  HHDC + HHDA. Single entity at launch; the role is an open
  standard for future interoperable implementations.
  - Sema: TBD (the AMR submission protocol will be a Sema type;
    likely `ta.reader.amr.submission` or similar).
- **TaTradingRights** — a delegated credential that authorizes a
  named LTN to act for a named TerminalAsset in the Cleared
  Market. Owned by the TaOwner. The TaOwner exchanges them for an
  SLA contract with a chosen TaAggregator (or holds them and runs
  their own LTN). **The SLA includes a clawback right:** the
  TaOwner can claw back their TaTradingRights at any time per SLA
  terms — revoke, reassign to a different LTN, reassign to a
  different TaAggregator, or take them back to themselves. Clawback
  is immediate and unilateral.
  - Sema: TBD (likely `ta.trading.rights.gt` with delegation
    chain + clawback-event types).
- **TaValidator** — independent third-party entity. Performs three
  related audit functions: (1) on-site physical verification at
  each install, signing the TaDeed that attests to asset reality;
  (2) randomized periodic re-verification of installed assets;
  (3) **independent audit of the TaReader's data integrity** —
  randomized spot checks of physical meter reads vs the TaReader's
  reported submissions, with discrepancy reporting. Fully
  independent of GridWorks. **It is essential that the TaValidator
  is not the same party as the TaReader** — the TaReader cannot
  mark its own homework, and the TaValidator's independent random
  audits of the TaReader are what makes the data path trustworthy
  at scale. Working candidate: Ridgeline Energy / Dave Korn.
  - Sema: TBD (signed-attestation type for TaDeed signatures;
    audit-event types for discrepancy reports).
- **[TerminalAsset](../../glossary.md#gridworks-concepts)** — in the
  EEM context: the physical asset that an LTN represents in the
  Cleared Market. For our Maine launch, TerminalAssets are
  heat-pump thermal storage systems behind Versant Rate A-1 bonus
  meters. Each TerminalAsset is associated with exactly one LTN.

## Section 2: GridWorks heritage vocabulary

Earlier GridWorks work. Preserved for provenance and conceptual
continuity.

- **AMM-OPF (Automated Market Maker Optimal Power Flow)** — the
  2022 Algorand-grant vision for decentralized grid-balancing
  markets respecting Optimal Power Flow constraints. Long-term
  technical direction; not in the current architecture.
- **[AtomicTNode](../../glossary.md#legacy--current-naming)** —
  2022-era name for the per-asset agent that has been replaced by
  LTN (LeafTransactiveNode).
- **Representation Contract** — 2022-era name for the long-lasting
  agreement between an AtomicTNode and its TerminalAsset
  specifying response speed, accuracy, and edge-case handling.
  Direct ancestor of the customer SLA + the TaTradingRights
  delegation in the current architecture.
- **TEM (Transactive Energy Management)** — the 2021 paper's
  definition of a technology platform with market-based principles,
  24/7 interaction, asynchronous and flexible real-time
  participation. The architectural specification of what a
  MarketMaker must do.
- **TER (Transactive Energy Resource)** — defined in the 2021 TER
  Initiative paper as a Physical Resource capable of 24/7,
  real-time, geographically localized response to grid conditions.
  The heat-pump thermal storage system is our canonical TER.
  Heritage term; superseded operationally by the TerminalAsset /
  LTN distinction.
- **the TER Participation Model** — the 2021 paper's proposed
  market-clearing model where the CEP brings the TER Position and
  the aggregator brings Incs & Decs. Direct ancestor of the
  Cleared Market.
- **VCharge** — GridWorks principals' prior venture (2009–2016)
  that demonstrated commercial viability of TER aggregation in
  Pennsylvania, Massachusetts, Maine, the UK, Ireland, and
  Germany.

## Section 3: ISO-NE / NEPOOL / FERC industry vocabulary

Terms given to us by ISO-NE, NEPOOL, FERC, and industry standards.
NOT GridWorks-controlled. We use them as given. The ultimate
authority for each is the cited industry source (ISO-NE Tariff,
FERC Order, etc.); the entries here are EEM-context summaries.

- **ADCR (Active Demand Capacity Resource)** — ISO-NE
  capacity-market participation pathway for demand-side resources.
- **Aggregation** — when capitalized, the ISO-NE term for the
  III.6.4-registered entity. Used informally lowercased ("an
  aggregation") for general aggregator services.
- **AMR (Assigned Meter Reader)** — III.6.4(f). The role the DERA
  designates: itself, an agent acting on its behalf, or the Host
  Utility. In our architecture: the DERA designates the GridWorks
  TaReader as its agent-AMR.
- **ATRR (Alternative Technology Regulation Resource)** — ISO-NE
  regulation-service pathway for storage and demand-side
  resources.
- **CP (Coincident Peak)** — ISO-NE / Versant. Demand charge
  allocation based on contribution to monthly or annual system
  peak intervals.
- **DER (Distributed Energy Resource)** — FERC definition: any
  resource on the distribution system or behind a customer meter
  capable of energy injection, withdrawal, regulation, or demand
  reduction.
- **DERA (Distributed Energy Resource Aggregation)** — ISO-NE
  Tariff Section III.6.4. The ISO-NE-registered grouping that
  participates in NEPOOL markets as an aggregation of distributed
  resources. Effective Nov 1, 2026. In our deployment, the
  GridWorks TaAggregator for Versant territory holds the DERA
  registration.
- **DRR (Demand Response Resource)** — FERC framing.
- **FCM (Forward Capacity Market)** — ISO-NE. The capacity-market
  mechanism through which Capacity Supply Obligations are procured.
- **FERC Order 745** — 2011 demand-response compensation rule.
  Predecessor framework; not architecturally relevant for current
  deployment.
- **FERC Order 2222** — 2020 order requiring RTO/ISO market access
  for DER aggregations. III.6.4 is ISO-NE's compliance.
- **Host Participant Assigned Meter Reader** — under M-28 and
  III.6.4, the AMR designation typically held by the Host Utility
  for residential meters in its territory.
- **III.6.4(d), III.6.4(e), III.6.4(f), III.6.7(c)(i)2** — specific
  subsections of ISO-NE Tariff Section III.6.4 governing metering
  configurations, written confirmation, AMR designation, and
  attestation respectively.
- **LMP (Locational Marginal Price)** — ISO-NE. The settled
  wholesale energy price at a specific Price Node and interval.
- **M-28 (Manual M-28)** — ISO-NE Market Rule 1 Accounting.
- **Metering Domain** — ISO-NE settlement structure. The TaReader's
  AMR submissions and Versant's profiled allocations both feed
  Metering Domain reconciliation.
- **Metering Domain residual** — the loss / unmetered-load
  allocation Host Participants compute under M-28. Profile/Actual
  delta on the dedicated CEP absorbs into this mechanism.
- **MRSP (Meter Service Provider)** — ISO-NE-recognized entity
  qualified to read meters and submit settlement-quality interval
  data. The TaReader is a non-host MRSP.
- **NEPOOL (New England Power Pool)** — ISO-NE participating
  transmission owners and stakeholders.
- **OP-18 (Operating Procedure No. 18)** — ISO-NE Metering and
  Telemetering Criteria.
- **Retail Delivery Point** — III.6.4(e) reference; the
  Host-Utility-customer interconnection.

## Section 4: Maine-specific industry vocabulary

Terms from Maine MPUC, Maine statute, Versant. NOT
GridWorks-controlled. Used as given.

- **bonus meter** — the second meter Versant installs under
  Rate A-1.
- **CEP (Competitive Electricity Provider)** — Maine MPUC Chapter
  305 licensed retail electricity supplier. The Maine-specific
  name for the Retail Supplier of Record role.
- **Chapter 305** — MPUC rule on CEP licensure.
- **Chapter 322** — MPUC rule on CEP / Host Utility coordination
  contracts.
- **Efficiency Maine Trust** — quasi-public Maine entity under
  35-A MRS Chapter 97. Candidate CEP if it takes the role.
- **Keene Road constraint** — transmission constraint in northern
  Maine behind which significant wind generation gets curtailed.
- **Knifes Edge deployment** — the 100-home Millinocket development
  (developer: Matt Polstein) that is the first deployment of the
  architecture.
- **MPUC (Maine Public Utilities Commission)** — Maine's state
  utility regulator.
- **Rate A-1** — Versant's residential TOU storage-controlled
  tariff. Provides the existing parallel-metering configuration
  our architecture uses.
- **Standard Offer** — Maine's default residential electricity
  supply.
- **Versant Bangor Hydro District (BHD)** — Versant's eastern Maine
  service territory.
- **Versant Power** — investor-owned EDC serving northern and
  eastern Maine. The Host Utility for the Knifes Edge deployment.

## Section 5: UK Elexon precedent

Cited as the architectural precedent for role separation in the
TaReader's design. NOT part of US operations.

- **BSC (Balancing and Settlement Code)** — UK regulatory framework
  for electricity market settlement.
- **HHDA (Half-Hourly Data Aggregator)** — aggregates data and
  submits for settlement.
- **HHDC (Half-Hourly Data Collector)** — retrieves data from the
  meter.
- **MOP (Meter Operator)** — owns and maintains the physical meter.
- **MPAN (Meter Point Administration Number)** — per-meter
  identifier in UK BSC.
- **Supplier** — the licensed retail electricity supplier in UK
  terminology. Functionally equivalent to a US CEP / CES / ESCo.

The Elexon framework separates MOP, HHDC, HHDA, and Supplier as
distinct commercial entities by structural design. Our TaReader
combines the BSC roles of HHDC + HHDA, with TaValidator providing
the physical-asset verification function. Our CEP corresponds to
the UK Supplier.

## Further reading

- [`primary.md`](primary.md) — architecture hub
- [`actors.md`](actors.md) — full role definitions
- [`value-flow.md`](value-flow.md) — money flow + worked example
- [`cleared-market.md`](cleared-market.md) (Open) — Cleared Market
  clearing mechanics
- [`ta-reader.md`](ta-reader.md) (Open) — TaReader as trust anchor;
  Elexon precedent
- [`ta-aggregator.md`](ta-aggregator.md) (Open) — TaAggregator as
  fiduciary aggregator
- [`leaf-transactive-node.md`](leaf-transactive-node.md) (Open) —
  LTN as per-asset agent
- [`participation-requirements.md`](participation-requirements.md)
  (Open) — per-role requirements + evidence mechanisms
- [`heritage.md`](heritage.md) (Open) — TER Initiative, Redefining
  DR, VCharge lineage
- [`wiki/glossary.md`](../../glossary.md) — top-level GridWorks
  cross-repo glossary; primary canonical home for GNode, LTN,
  MarketMaker, TerminalAsset, SCADA, ShNode, and other foundational
  concepts.

## Conventions

- A bold term that is itself a hyperlink (like
  **[GNode](../../glossary.md#gridworks-concepts)**) is a
  **cross-reference**: the primary canonical home is the link
  target; the entry here is an EEM-context-tailored summary.
- A plain bold term (no link on the term itself) is **primary
  canonical here**: this glossary is the source of truth.
- For primary entries that have or should have a Sema type, an
  inline `Sema:` sub-bullet cites the canonical YAML, or marks
  `TBD` if the Sema definition is planned but not yet authored.
  Sema is the authority over meaning at serialization boundaries;
  the glossary defers to Sema for formal types.
- Cross-references SHOULD NOT duplicate the Sema-coupling work of
  their primary entries; the primary handles the Sema link.
