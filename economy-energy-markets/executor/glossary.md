Status: Draft · Pass 0 · Updated 2026-06-06

> What this is: the canonical glossary for the Economy Energy Markets
> architecture. Terms are grouped by scope, with **Core architecture
> terms** being GridWorks primitives that travel across deployments,
> and the remaining sections covering deployment-specific, regional,
> precedent, and heritage vocabulary.

## Core architecture terms (GridWorks primitives)

These are stable across deployments. Architectural debates use these.

- **Economy Energy** — electric energy delivered at times of renewable
  abundance, when wholesale LMPs are low or negative. The product
  Economy Energy Markets exists to deliver. Industry framing
  originated with Matt White (ISO-NE).
- **the Bilateral** — the two-sided market clearing in the
  GridWorks Market Maker between the CEP and the DERA. CEP brings
  profile-shape position; DERA brings actual delivery; market
  clears. See [`bilateral.md`](bilateral.md).
- **the Market Maker** — the GridWorks-built broker for the
  Bilateral. The marketplace where CEP and DERA trade. May be
  capitalized as "GridWorks Market Maker" when distinguishing the
  GridWorks implementation from the architectural role; other
  entities may build interoperable Market Makers.
- **DERA** — Distributed Energy Resource Aggregation. In our
  architecture, the GridWorks-owned entity that holds the customer
  SLA, captures the load-shifting value via the Bilateral, pays the
  customer rebate, and operates the optimizer.
- **AMR** — Assigned Meter Reader. The role permitted under ISO-NE
  Tariff Section III.6.4(f) for a DERA to designate itself, an
  agent, or the Host Utility as the entity reading the cohort's
  meters. In our architecture, the DERA designates the Meter Reader
  as its agent-AMR.
- **Meter Reader** — the operational AMR entity. A separate legal
  entity from the DERA. Reads the GridWorks-installed meter at each
  enrolled home, submits interval data to ISO-NE per III.6.4(f),
  submits parallel data to the Market Maker. In Elexon terminology,
  combines the Data Collector and Data Aggregator roles.
- **TA-Validator** — Trusted Asset Validator. Independent
  third-party entity (NOT GridWorks) that physically verifies
  installations and signs TA-Deeds. Working candidate: Ridgeline
  Energy / Dave Korn.
- **TA-Deed** — cryptographically signed asset record covering
  location, system type (e.g., heat pump + thermal storage), meter
  make/model and serial, install validator identity, and timestamp.
  Produced by the TA-Validator at install and at randomized
  re-checks.
- **Appliance Profile** — the exogenous reference load shape used
  in the Bilateral. Heat-pump-without-storage typical-day shape for
  the customer's county and month, sourced from a public dataset
  (e.g., NREL ResStock), scaled to the customer's actual monthly
  total consumption.
- **the cohort** — the customers enrolled in a given DERA, all on
  a common dedicated CEP, all read by a common Meter Reader.
- **Host Utility** — the role of the regulated electric distribution
  utility (EDC) in the deployment territory. Named per deployment.
  In the Knifes Edge deployment: Versant Power.
- **Retail Supplier of Record** — the role of the licensed retail
  electricity supplier for the cohort. Named per deployment. In
  Maine: CEP. In MA: CES. Etc.
- **Mission-Aligned Supply Partner** — the role of the wholesale
  supply / hedging partner contracted by the CEP. Must be a
  nonprofit, mission-aligned entity (joint-action agency, member
  coop, or purpose-built nonprofit). Structural exemplar: MMWEC.
- **Customer Rebate** — the monthly payment from the DERA to the
  customer, as a defined share of the DERA's bilateral receipt
  attributable to that customer.

## Maine deployment terms (state/utility-specific)

These map the Maine instantiation of core terms. The Knifes Edge
deployment uses these specifically; other state deployments will
substitute their own equivalents.

- **CEP** — Competitive Electricity Provider; Maine's name for the
  Retail Supplier of Record, licensed under Maine MPUC Chapter 305.
- **Versant Power** — the Host Utility for the Knifes Edge
  deployment. Investor-owned EDC serving northern and eastern Maine.
- **Versant Bangor Hydro District (BHD)** — Versant's service
  territory in eastern Maine, including the Knifes Edge
  development site.
- **Rate A-1** — Versant's residential TOU storage-controlled
  tariff. "Home Eco Rate with Bonus Meter." Provides the existing
  parallel-metering configuration our architecture uses without
  modification.
- **bonus meter** — the second meter Versant installs under Rate
  A-1, on a physically separate circuit, measuring the
  storage-controlled load. GridWorks installs its own meter behind
  this bonus meter; both measure the same thing.
- **Chapter 305** — Maine MPUC rule governing Competitive
  Electricity Provider licensure.
- **Chapter 322** — Maine MPUC rule governing CEP / Host Utility
  coordination contracts.
- **Standard Offer** — Maine's default residential electricity
  supply, procured by the MPUC via competitive auction. The baseline
  alternative customers can fall back to if they don't elect a CEP.
- **MPUC** — Maine Public Utilities Commission.
- **Efficiency Maine Trust** — quasi-public Maine entity under
  35-A MRS Chapter 97. Candidate CEP if it elects to take the role.
- **the Knifes Edge deployment** — the 100-home development in
  Millinocket, Maine (developer: Matt Polstein) that is the first
  deployment of the Economy Energy Markets architecture.
- **Keene Road constraint** — transmission constraint in northern
  Maine behind which significant wind generation gets curtailed.
  The Knifes Edge deployment is sited to absorb curtailment-prone
  Economy Energy behind this constraint.

## ISO-NE / NEPOOL terms (regional regulatory and market structure)

Same across all NEPOOL deployments (CT, MA, ME, NH, RI, VT).

- **III.6.4** — ISO-NE Tariff Section: Metering and Telemetry
  Requirements for Distributed Energy Resource Aggregations. Effective
  Nov 1, 2026.
- **III.6.4(d)** — names allowed metering configurations including
  parallel metering behind a Retail Delivery Point.
- **III.6.4(e)** — requires written confirmation from the Host
  Utility that appropriate metering and system upgrades are in place
  to support load reporting and any necessary reconstitution.
- **III.6.4(f)** — permits the DERA to designate itself, an agent,
  or the Host Utility as Assigned Meter Reader.
- **III.6.7(c)(i)2** — DERA attestation requirement under
  Resource Aggregation registration.
- **Host Participant Assigned Meter Reader** — under M-28 and
  III.6.4, the AMR designation typically held by the Host Utility.
- **FCM** — Forward Capacity Market.
- **CP** — Coincident Peak. Versant allocates monthly and annual
  CP demand charges to CEPs based on contribution to system peak
  intervals.
- **LMP** — Locational Marginal Price. The settled wholesale energy
  price at a specific Price Node and interval.
- **ADCR** — Active Demand Capacity Resource. ISO-NE capacity-market
  participation pathway for demand-side resources.
- **ATRR** — Alternative Technology Regulation Resource. ISO-NE
  regulation-service pathway for storage and demand-side resources.
- **OP-18** — ISO-NE Operating Procedure No. 18: Metering and
  Telemetering Criteria. Defines technical standards the Meter
  Reader must meet.
- **M-28** — ISO-NE Manual: Market Rule 1 Accounting. Defines
  settlement-side accounting including loss allocation and Metering
  Domain residual computation.
- **Metering Domain residual** — the loss/unmetered-load allocation
  Host Participants compute under M-28. The "small profile/interval
  delta" between Versant's profiled allocation and our AMR submission
  for the dedicated CEP absorbs into this mechanism.
- **FERC Order 745** — 2011 demand-response compensation rule.
  Predecessor framework; deeply flawed for storage-controlled load.
- **FERC Order 2222** — 2020 order requiring RTO/ISO market access
  for DER aggregations. The III.6.4 framework is ISO-NE's compliance.
- **NEPOOL** — New England Power Pool. Participating Transmission
  Owners and stakeholders of ISO-NE.

## UK Elexon terms (role-separation precedent)

Cited as the architectural precedent for the three-entity legal
separation. Not part of US operations.

- **BSC** — Balancing and Settlement Code. UK regulatory framework
  for electricity market settlement.
- **MOP** — Meter Operator. The entity that owns and maintains the
  physical meter.
- **HHDC** — Half-Hourly Data Collector. The entity that retrieves
  data from the meter.
- **HHDA** — Half-Hourly Data Aggregator. The entity that aggregates
  data and submits for settlement.
- **MPAN** — Meter Point Administration Number. Per-meter identifier
  to which a MOP, HHDC, HHDA, and Supplier are each assigned.
- **Supplier** — the licensed retail electricity supplier in UK
  terminology. Functionally equivalent to a US CEP / CES / ESCo.

Our Meter Reader combines the BSC roles of HHDC + HHDA. Our
TA-Validator function does not have a direct BSC analog but
resembles independent physical-asset verification.

## Heritage / GridWorks technical terms

Carried forward from prior GridWorks work. Not all are in current
active use; preserved for conceptual continuity and provenance.

- **TER** — Transactive Energy Resource. Defined in the 2021 TER
  Initiative paper as a Physical Resource capable of 24/7, real-time,
  geographically localized response to grid conditions with negligible
  consequence to primary use. Heritage term; our architecture is
  the post-III.6.4 evolution of the TER Participation Model.
- **TEM** — Transactive Energy Management. Defined in the 2021 paper
  as a technology platform embracing market-based principles for
  24/7 grid interaction, asynchronous and flexible in real time,
  responsive/resilient/elastic. Heritage term; the architectural
  spec for what a Market Maker must do.
- **TER Participation Model** — the market-clearing model proposed
  in the 2021 TER Initiative Section 2. The CEP brings the TER
  Position (Profile-based); the DERA brings Incs and Decs (Actual −
  Profile). Our Bilateral is the post-III.6.4 realization, with the
  market clearing in the private GridWorks Market Maker instead of
  at the ISO.
- **VCharge** — the prior GridWorks-principals venture (Pennsylvania,
  Massachusetts, Maine, UK, Ireland, Germany; 2009–2016) that
  demonstrated the commercial viability of TER aggregation,
  including ISO-NE ATRR pilot participation, PJM regulation, and
  energy-supplier operation in PPL territory.
- **GNode** — Grid Node. GridWorks's hierarchical naming scheme
  for grid topology + market-structure positions. Implementation
  detail; documented in `legacy/g-node-factory/`.
- **Atomic TNode** — the software agent authorized to represent a
  Terminal Asset in market transactions. Implementation-level
  abstraction.
- **Representation Contract** — the long-lasting contract between
  an Atomic TNode and its Terminal Asset specifying response speed,
  accuracy, and edge-case handling. Implementation-level
  abstraction.
- **AMM-OPF** — Automated Market Maker Optimal Power Flow. The
  longer-term technical vision from the 2022 Algorand grant for
  decentralized grid-balancing markets that respect Optimal Power
  Flow constraints. Not used in the current architecture; the
  current Market Maker is a simpler bilateral broker that doesn't
  attempt OPF semantics.

## Further reading

- [`primary.md`](primary.md) — architecture hub with the six-actor
  diagram and invariants
- [`actors.md`](actors.md) — role definitions and boundaries
- [`bilateral.md`](bilateral.md) — Bilateral mechanics and clearing
- [`value-flow.md`](value-flow.md) — money flow with worked example
- [`heritage.md`](heritage.md) (Open) — full TER Initiative /
  Redefining DR / VCharge lineage
