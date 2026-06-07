Status: Draft · Pass 0 · Updated 2026-06-06

> What this is: full role definitions for the seven actors in the
> GridWorks Economy Energy Market System. Each section names what
> the actor commits to, what it receives, structural commitments,
> and operational boundaries with the other actors. See
> [`primary.md`](primary.md) for the hub and
> [`glossary.md`](glossary.md) for the canonical vocabulary.

## Customer

The homeowner enrolled in a TaAggregator's customer book with an
installed heat-pump thermal storage system. As the owner of the
TerminalAsset, the Customer is a **TaOwner** (see
[`glossary.md`](glossary.md)) — that role-name is used in the
glossary and in CEP-side exclusivity rules; in this actors spec
we use "Customer" for the broader homeowner identity that includes
the TaOwner role plus the CEP-customer relationship.

**Commits to:**

- Service Level Agreement with the TaAggregator, granting the
  TaAggregator-operated LTN delegated TaTradingRights and
  control authority over the storage-controlled load within stated
  comfort constraints.
- Supplier-of-record relationship with the CEP for retail
  electricity.
- Allowing physical install + occasional re-verification by the
  TaValidator.

**Receives:**

- A flat-rate retail electricity bill from the CEP. The customer
  is NOT exposed to LMP-pass-through pricing.
- A Customer Rebate from the TaAggregator, proportional to the
  storage-shifting their LTN's participation enabled. The rebate
  is a separate payment stream from the CEP bill.
- Maintained comfort within SLA bounds.

**Structural commitments:**

- **Owns the TaDeed** for their TerminalAsset — always, intrinsically
  to physical asset ownership. The TaDeed transfers with the asset
  on sale or transfer.
- **Owns the TaTradingRights** for their asset. **Exchanges them
  for an SLA contract** with a chosen TaAggregator (or holds them
  and runs their own LTN).
- **Has clawback authority on the TaTradingRights at any time per
  SLA terms** — claw back to a different LTN, a different
  TaAggregator, themselves (if un-aggregated participation is
  viable), or nowhere. Clawback is immediate and unilateral. SLA
  violations or service dissatisfaction surface as clawback of the
  rights.

**Switching:** Customer may switch CEPs at any time per Maine MPUC
rules. The customer may also switch TaAggregators independently of
switching CEPs (TaTradingRights move). These are separable
decisions — the CEP-supply relationship and the TaAggregator-service
relationship are not bundled.

## CEP (Competitive Electricity Provider)

Maine MPUC Chapter 305 licensed retail electricity supplier. The
Maine-specific instantiation of the Retail Supplier of Record role.
For our Maine launch: Efficiency Maine Trust, or a partner Maine CEP.

**Commits to:**

- Maintaining a Chapter 305 license in good standing.
- Acting as supplier of record for every enrolled customer in each
  ISO-NE territory of operation.
- Offering a flat-rate residential electricity product.
- **TaReader exclusivity (per-territory).** Within each ISO-NE
  territory of operation, the CEP serves only TaOwners — customers
  whose TerminalAsset is enrolled in the GridWorks DERA and whose
  meter is therefore read by the GridWorks TaReader. No CEP
  customer in that territory is settled at the wholesale level via
  the Host Utility's standard profiled allocation or via any other
  AMR.
- **Mandatory Cleared Market participation.** Every settlement
  period, the CEP's bulk profile-shape position is registered in
  the Market Maker and clears against the LTNs' actual-delivery
  positions. The CEP cannot opt out of a settlement period or
  refuse to clear.
- Engaging a mission-aligned wholesale supply / hedging partner —
  joint-action agency, member-owned coop, or purpose-built nonprofit.
  See [`supply-partner.md`](supply-partner.md). Profit-maximizing
  corporate supply partners (Engie, Constellation, Shell, BP, NRG,
  Tenaska) are EXCLUDED regardless of operational fit.
- Standard Chapter 305 customer protections: Terms of Service,
  5-day opt-out window, advance notice of renewal, anti-slamming
  authorization-prior-to-enrollment, complaint handling.

**Why the two exclusivity commitments are jointly load-bearing.**
The architecture's "Versant changes nothing" property depends on
ISO-NE being able to apply a single, uniform settlement rule to the
CEP: settle at LMP × Actual using the TaReader's AMR submission for
the entire CEP's territory book, in all hours, for all customers.
If even one CEP customer were outside the TaReader's read set or
settled via Versant's standard profiled allocation, ISO-NE would
need to apply a mixed per-meter-point rule — which forces
Versant-side per-meter flagging and coordination. The whole point
of the design is to NOT require that. Versant continues its normal
Rate A-1 reads, normal per-supplier allocation, and normal Metering
Domain residual reconciliation; ISO-NE handles the CEP as a
special case at the settlement-engine level (using the TaReader's
AMR submission as authoritative per III.6.4(f)); Versant never has
to know which of its bonus meters belong to a TaReader-read
customer. Both exclusivity commitments above are necessary jointly
for this to hold.

**Receives:**

- Retail revenue from the customer (flat rate × kWh).
- **Net wholesale cost = LMP × Profile** by structural guarantee
  of the Cleared Market. The CEP's exposure is exactly equal to
  LMP × Profile regardless of cohort actual-shape; the Market
  Maker absorbs the Actual-vs-Profile delta. CEP hedges against
  Profile-shape forecast (predictable, county-month, public data),
  not against Actual variability.
- CEP gross margin per customer: `flat retail × kWh − LMP × Profile
  per customer` — a defined per-customer per-month administrative
  margin that covers bill issuance, MPUC compliance, customer
  service, hedging-coordination overhead, and reasonable reserves.

**Carries:**

- The CEP carries Profile-shape commodity risk in principle (LMP ×
  Profile is a stochastic quantity). In practice, the mission-aligned
  supply partner takes most of that risk via a Profile-shape supply
  contract. Net residual risk to the CEP is small.

**Does NOT:**

- Know about LTNs, TaTradingRights, TaAggregators, or TaDeeds.
  The CEP enrolls in a defined product structure; the LTN-layer
  architecture is below its accounting line.
- Negotiate per-customer terms. The Cleared Market clears
  automatically; the CEP is not party to per-customer or per-asset
  pricing decisions.
- Hold the customer SLA for DERA-side services. The TaAggregator
  does that.
- Submit interval data to ISO-NE itself. The TaReader does that.

## TaAggregator

GridWorks-defined fiduciary aggregator entity. Holds Service Level
Agreements with customers, operates Leaf Transactive Nodes on their
behalf, aggregates LTN financials, routes Customer Rebates. May also
hold the III.6.4 DERA registration for its customer base. One of
one-or-more TaAggregators that may operate on top of the same
TaReader infrastructure.

In our initial Maine launch: the GridWorks Versant TaAggregator
holds the SLAs for all enrolled GridWorks customers in Versant
territory (Knifes Edge + the 6 Millinocket pilot homes + future
enrollments), operates their LTNs, and also holds the III.6.4 DERA
registration with ISO-NE for the corresponding Aggregation.

**Commits to:**

- **Fiduciary duty to customers.** The TaAggregator holds delegated
  TaTradingRights and operates LTNs on behalf of the customers.
  This is a fiduciary relationship by architectural commitment —
  the TaAggregator MUST act in the customers' financial and service
  interests, not extract value at their expense.
- Operating LTNs that meet the LTN-layer Participation Requirements
  for every enrolled customer.
- Holding the SLA with each enrolled customer, with terms that name
  the trading-rights delegation, the comfort guarantees, the rebate
  flow, the contract term, and the customer's right to move
  TaTradingRights at any time.
- Aggregating LTN-level Cleared Market receipts into customer-level
  rebates, monthly.
- Paying Customer Rebates on a defined cadence (typically monthly,
  coincident with the Cleared Market settlement).
- Funding operational costs out of the TaAggregator's share:
  TaReader fees, Market Maker fees, TaValidator fees,
  customer-acquisition costs, optimizer infrastructure, support
  staff, green-bank debt service (where applicable), and the
  TaAggregator's own margin / reserves.
- **III.6.4 DERA registration with ISO-NE** for the Aggregation it
  represents (in our launch deployment).
- **Designating the TaReader as agent-AMR** per III.6.4(f) for the
  Aggregation.

**Receives:**

- Aggregate Cleared Market receipts from the LTNs it operates,
  flowing through the Market Maker.
- Wholesale-market revenue from any future Order 2222 / III.14.2
  Active Demand Capacity Resource / Alternative Technology
  Regulation Resource participation built on top of the Cleared
  Market energy clearing — these are direct DERA revenues, not
  routed through the Cleared Market.

**Structural commitments:**

- Separate legal entity from day one (per the three-separate-entities commitment in `primary.md`).
- **The TaAggregator and DERA are conceptually separable.** The
  TaAggregator role is GridWorks-defined: customer-facing
  fiduciary, SLA holder, LTN operator, financial aggregator. The
  DERA is an ISO-NE term: the III.6.4-registered Aggregation. In
  our deployment they're held by the same legal entity for
  operational simplicity; the architecture admits a future where
  these are different entities (e.g., a TaAggregator without DERA
  registration delegates Aggregation-level functions to a
  DERA-registered partner).
- **One of one-or-more TaAggregators.** The TaReader serves multiple
  TaAggregators. Customers can choose which TaAggregator to delegate
  their TaTradingRights to (or move them later). The TaAggregator
  market is open and competitive.

**Does NOT:**

- Bid directly in the Cleared Market. The LTNs (which the
  TaAggregator operates) are the structural bidders.
- Read meters. The TaReader does that.
- Verify physical installations. The TaValidator does that.
- Settle retail bills with customers. The CEP does that.

## TaReader

GridWorks-defined NEPOOL-wide operational meter-reading entity.
Reads the meters of enrolled assets every interval; validates
Participation Requirements at participation time; acts as agent-AMR
per III.6.4(f) for one or more DERAs. Submits authoritative interval
data to ISO-NE and parallel data to the Market Maker. Single legal
entity at launch; the role is an open standard for future
interoperable implementations.

**Two distinct rule sets apply jointly.** The TaReader must
satisfy:

1. **FERC / ISO-NE rules for being an Assigned Meter Reader.**
   Industry rules — given to us. III.6.4(f) timing SLAs, OP-18
   metering / telemetry standards, M-28 settlement procedures,
   six-year data retention per III.6.4(g), coordination-agreement
   obligations with each Host Utility. We comply; we don't redefine.
2. **GridWorks rules for being a TaReader.** Our open-standard
   rules — we define. Participation Requirements validation
   (TaDeeds, TaTradingRights), TaTradingRights move-event honoring,
   SCADA dispatch integration, Market Maker data feed, open-source
   software stack, cryptographic-audit-trail discipline,
   spin-off-ready API surface.

The architecture's design satisfies both sets. Sub-spec
[`ta-reader.md`](ta-reader.md) (Open) will detail the requirements
under each rule set and how they interact.

**Architectural precedent.** The TaReader's role separation from
the customer-facing Supplier (CEP) follows the UK Elexon Balancing
and Settlement Code's structural separation of the Meter Operator
(MOP), Half-Hourly Data Collector (HHDC), and Half-Hourly Data
Aggregator (HHDA) roles from the Supplier. The Elexon framework has
run a competitive market in these services for 25+ years; we adopt
the structural separation and combine the HHDC + HHDA roles into
the TaReader.

**The TaReader does NOT audit itself.** Per the TaValidator commitment in `primary.md`,
the TaValidator is fully third-party and performs independent
audits of the TaReader's data integrity. The TaReader cannot mark
its own homework; the TaValidator's randomized spot checks are
what makes the data path trustworthy at scale.

**Commits to:**

- **Holding ISO-NE non-host AMR registrations** in its own name
  across each NEPOOL territory in which it operates (Versant BHD
  initially; CMP, Eversource, others as we expand).
- **Holding agent-AMR designations from one or more DERAs** per
  III.6.4(f). For each designation, the TaReader submits AMR data
  for the relevant Aggregation. Multiple DERAs can share the
  TaReader.
- **Validating Participation Requirements** before honoring any
  data submission, market participation, or SCADA dispatch from any
  participant. Specifically:
  - Validates TaDeeds — verifies the TaValidator's signature,
    cross-checks against current asset registry.
  - Validates TaTradingRights — verifies the customer's delegation
    chain to the named LTN.
  - Honors trading-rights MOVE events — when a customer moves
    rights, the TaReader immediately updates its participation
    registry; the next clearing cycle reflects the move.
- **Operating the GridWorks-installed meter** behind the Host
  Utility's bonus meter at each enrolled home (in deployments
  using the parallel-metering configuration like Versant Rate A-1).
- Submitting interval data to ISO-NE on the III.6.4(f) timing SLA
  (by 0800 next business day to the Host Participant where
  required; by 1300 second business day to ISO-NE).
- Submitting parallel interval data to the Market Maker for
  Cleared Market computation.
- Conformance with ISO-NE Operating Procedure No. 18 (Metering and
  Telemetering) and Manual M-28 (Market Rule 1 Accounting).
- Six-year data retention per III.6.4(g).
- Compliance with III.6.4(f) coordination-agreement obligations with
  each Host Utility.

**Receives:**

- Per-meter or per-customer service fees from the DERAs / TaAggregators
  it serves, internally modeled now (so the unit economics are
  clear) and externalized as invoices on any future spin-off as a
  standalone trust-infrastructure entity.

**Structural commitments:**

- Separate legal entity from day one (per the three-separate-entities commitment in `primary.md`).
- NEPOOL-wide scope (per the TaReader commitments in `primary.md`).
- Open standard for the role (per the TaReader commitments in `primary.md`) — the
  TaReader's protocol, software, and operational standards are
  open-source, so future TaNotaries (potentially run by other
  entities in other regions, or by alternative providers) can
  interoperate.
- Designed for clean spin-off as a standalone trust-infrastructure
  service. Defined API surface to downstream consumers (DERAs,
  TaAggregators, Market Maker, ISO-NE, SCADA). Data namespace
  isolated from any DERA / TaAggregator the TaReader serves.
  Regulatory standing (ISO-NE AMR registration) held in the
  TaReader's own name from day one.

**Does NOT:**

- Verify physical installations. The TaValidator does that.
- Hold customer SLAs. The TaAggregator does that.
- Bid in the Cleared Market. LTNs do that.
- Operate as a DERA. The TaReader is the agent-AMR; the DERA is the
  ISO-NE-registered Aggregation entity (which a TaAggregator
  typically holds).

## LTN (Leaf Transactive Node)

GridWorks-defined per-asset entity with a cryptographic identity.
Holds TaTradingRights delegated by the customer via the SLA.
Bids in the Cleared Market. SCADA-honored dispatch authority for
the asset it represents.

**Commits to:**

- Holding a cryptographic identity (key pair, signed assertions,
  audit trail). Currently anchored by the TaDeed + TA-Trading-Right
  combination validated by the TaReader.
- **Meeting the LTN-layer Participation Requirements** —
  - The asset it represents has a valid TaDeed signed by a
    TaValidator and validated by the TaReader.
  - The LTN holds delegated TaTradingRights for that asset,
    delegated by the customer via the SLA.
  - The asset's meter is read by the TaReader.
  - The LTN can receive SCADA dispatch commands that the TaReader
    honors.
- **Bidding in the Cleared Market** on behalf of its asset.
  Specifically: submits actual-delivery position (Actual × LMP) for
  each settlement period.
- Accepting clearing outcomes from the Market Maker.
- Operating its asset within the customer's SLA-defined comfort
  constraints.
- Honoring TaTradingRights revocation / move events promptly. When
  a customer moves rights, the LTN's authority terminates
  immediately for that asset.

**Receives:**

- Per-asset Cleared Market receipts from the Market Maker, routed
  through the TaAggregator (or directly to the customer if the LTN
  is customer-operated rather than TaAggregator-operated).

**Structural commitments:**

- One LTN per metered load. The LTN is the structural unit of
  market participation.
- LTNs MAY be operated by a TaAggregator (the default in our
  deployment) or by the customer directly (un-aggregated
  participation, supported but not the default).
- LTN-level audit trail enables disaggregable verification — the
  Market Maker's clearing can be decomposed back to per-asset
  contributions, with full provenance via TaDeeds and
  TaTradingRights.

**Does NOT:**

- Operate independently of a TA-Trading-Right delegation. Without a
  valid delegation chain validated by the TaReader, the LTN has no
  authority to bid or dispatch.
- Sign its own TaDeed. The TaValidator does that.

## Market Maker

GridWorks-built infrastructure that operates the Cleared Market.
Single legal entity at launch; designed for clean spin-off as a
standalone product company.

**Commits to:**

- Operating the Cleared Market every settlement period (typically
  monthly).
- Computing positions:
  - For each CEP: the bulk profile-shape position (sum over the
    CEP's TaOwners per ISO-NE territory of (Appliance
    Profile × monthly total kWh × LMP), summed across products —
    energy, FCM CP, RPS, etc.).
  - For each LTN: the actual-delivery position (Actual × LMP per
    interval, summed across products).
- Clearing the market: net flows route CEP exposure to LMP ×
  Profile by structural guarantee; the Cleared Market receipt
  flows to LTNs proportional to load-shifting contribution.
- Routing payments per the clearing.
- Maintaining auditable records of every clearing: inputs (TaReader
  interval data, Appliance Profile reference, LMP series), formula,
  output, signatures.
- Open-source publication of Market Maker software and protocol.

**Receives:**

- Per-customer per-month transaction fees from participating
  TaAggregators and CEPs (or alternatively from the LTN-side via the
  TaAggregator's allocation), for brokerage services.

**Structural commitments:**

- Separate legal entity from day one (per the three-separate-entities commitment in `primary.md`).
- **Open standard.** The clearing protocol, the data formats, the
  Appliance Profile interface, and the clearing-routing mechanics
  are all open-source. The GridWorks Market Maker is one
  implementation; other entities can build interoperable Market
  Makers.
- Designed for spin-off as a standalone product company.

**Does NOT:**

- Take a position. The Market Maker is a clearing mechanism, not a
  counterparty. It does not bear LMP risk, default risk, or
  performance risk; it does not extract a percentage of clearing
  value beyond the defined transaction fee.
- Submit data to ISO-NE. The TaReader does that.
- Validate Participation Requirements. The TaReader does that.

## TaValidator

Independent third-party entity performing three related audit
functions: (1) on-site physical verification at install, (2)
randomized re-verification of installed assets, and (3) **independent
audit of the TaReader's data integrity** — randomized spot checks
of the TaReader's reported submissions against physical reality.
Fully third-party from day one — never GridWorks. Working candidate:
Ridgeline Energy.

**The role is an open standard.** Any qualified entity may become
a TaValidator after meeting the certification requirements; no
single entity holds a monopoly. This is anti-regulatory-hijacking —
capture of the role by a single utility or a single company would
defeat the architecture.

**A TaValidator's operational scope is localized to one or more
MarketMakers' sub-trees** — the copper sub-tree(s) under specific
MarketMaker GNodes, where on-site verification is practically
executable. A TaValidator may serve multiple MarketMaker sub-trees;
multiple TaValidators may serve overlapping sub-trees.

**The three architectural attestations.** The TaValidator's
on-site verification produces a signed TaDeed attesting to three
load-bearing facts — what the entire downstream trust chain rests
on:

1. **Asset type** — what the TerminalAsset *is* (heat pump +
   thermal storage configuration, hot water heater, EV charger,
   residential battery, etc.).
2. **GPS location** — where the TerminalAsset *physically lives*
   (lat/lon), so the GNode address corresponds to a real place on
   the copper sub-tree.
3. **Meter accuracy** — that the meter reads the TerminalAsset's
   electrical consumption *accurately and exclusively* (the meter
   measures the TerminalAsset and nothing else).

These three are the trust surface of the architecture. The
broader on-site checklist (serial numbers, installer identity,
photo evidence, timestamp) lives in operational practice; the
three architectural attestations are what every downstream
market action depends on.

**Why this role exists separately from the TaReader.** It is
essential that the entity validating asset reality and auditing the
TaReader's data is NOT the TaReader itself. The TaReader's data
submissions to ISO-NE and to the Market Maker drive real money
flows; an unaudited TaReader would have moral hazard at a structural
level. The TaValidator's randomized independent audits — taking its
own on-site readings, comparing to the TaReader's submissions,
flagging any discrepancy — are the structural defense against this
moral hazard.

**Commits to:**

- **On-site verification at install.** Meter make/model and serial,
  location, system type (heat pump + thermal storage configuration),
  installer identity, photo evidence, timestamp. Issues a
  cryptographically signed TaDeed attesting to the verified facts.
- **Randomized re-verification of installed assets.** Sample of
  enrolled homes at a defined cadence (e.g., ~5% sample quarterly).
  Re-checks that the asset still matches the TaDeed: hasn't been
  swapped, hasn't been moved, hasn't been disconnected.
- **Independent audit of the TaReader's data integrity.** Random
  spot checks where the TaValidator takes its own meter readings
  on-site (or from a parallel telemetry channel where available) and
  compares against what the TaReader has submitted to ISO-NE and to
  the Market Maker for the same interval. Discrepancies trigger
  investigation and (where merited) escalation to ISO-NE and MPUC.
- **Maintaining an auditable signature key infrastructure** under
  its exclusive control. GridWorks-affiliated entities cannot forge
  TaValidator signatures.
- **Reporting irregularities or suspected fraud** to the TaReader,
  to the TaAggregator (where applicable), and (under defined
  protocols) to ISO-NE and MPUC.

**Receives:**

- Per-install verification fees and periodic re-check fees, paid by
  the TaAggregator.

**Structural commitments:**

- Genuinely independent of GridWorks. Separate ownership, governance,
  operational chain of command. NOT a wholly-owned GridWorks entity.
- **Open standard, not single-license.** Any qualified entity may
  certify as a TaValidator; no entity has a monopoly on the role.
- **Operational scope localized to one or more MarketMaker sub-trees.**
  Geographic locality is required for practical on-site verification.
- Verification keys held under the TaValidator's exclusive control;
  GridWorks-affiliated entities cannot forge TaDeed signatures.
- The TaValidator's signature is the authoritative physical-reality
  record. The TaReader cannot accept reads from an unverified
  install for AMR settlement purposes.

**Does NOT:**

- Read meters day-to-day. The TaReader does that.
- Operate equipment on the customer's premises beyond initial
  verification and randomized re-check visits.
- Take a commercial position in the Cleared Market. Compensation is
  fee for service, fixed and disclosed.

## DERA — the ISO-NE designation

**Not a separate actor in the GridWorks architecture, but a
designation that an actor (typically the TaAggregator) holds.**

In ISO-NE terminology, a DERA (Distributed Energy Resource
Aggregation, per Tariff Section III.6.4) is an entity that registers
an Aggregation of distributed energy resources to participate in
NEPOOL wholesale markets. The DERA has the authority under III.6.4(f)
to designate itself, an agent acting on its behalf, or the Host
Utility as the Assigned Meter Reader.

In our architecture:

- The **GridWorks TaAggregator** (for the Versant territory in our
  Maine launch) ALSO holds the III.6.4 DERA registration for the
  Aggregation it represents.
- The TaAggregator-as-DERA designates the **TaReader** as agent-AMR
  per III.6.4(f).
- The TaReader submits interval data to ISO-NE for the DERA's
  Aggregation.

The TaAggregator and DERA roles are architecturally separable. A
future non-GridWorks TaAggregator could be served by the same
TaReader; that TaAggregator would hold its own III.6.4 DERA
registration (or, if it elects to not register, would not have
ISO-NE-wholesale-market participation rights for its customer book).

## Why seven actors + one designation

The list:

| # | Actor | Origin |
| --- | --- | --- |
| 1 | Customer | generic |
| 2 | CEP | Maine industry term (Chapter 305) |
| 3 | TaAggregator | GridWorks |
| 4 | TaReader | GridWorks |
| 5 | LTN | GridWorks |
| 6 | Market Maker | GridWorks |
| 7 | TaValidator | GridWorks (independent third party) |

Plus the **DERA** designation (ISO-NE term, held by the TaAggregator
in our deployment).

The seven actors map cleanly onto distinct concerns:

- **Customer:** owns the asset and the trading rights; receives
  service and rebates.
- **CEP:** retail supply, ISO-NE settlement at the wholesale level;
  knows nothing of the LTN layer.
- **TaAggregator:** customer-facing fiduciary; SLA holder; LTN
  operator; rebate routing; (optionally also) DERA registration.
- **TaReader:** trust anchor; participation validator; agent-AMR;
  Elexon-style trust infrastructure.
- **LTN:** per-asset cryptographic market participant; SCADA
  dispatch authority.
- **Market Maker:** clearing infrastructure; not a counterparty.
- **TaValidator:** independent physical verification.

Each role is genuinely distinct; no concern is held by two actors;
each actor's role is necessary and sufficient for its function. The
DERA designation is held by the TaAggregator in our deployment but
is conceptually separable — making the architecture portable to
deployments where the DERA role is held by a different entity.

## Open

- The supply partner discussion is in
  [`supply-partner.md`](supply-partner.md) (Open). MMWEC is the
  structural exemplar; concrete partner identification is a
  critical-path operational item.
- The fixed administrative margin number (the CEP's per-customer
  per-month fee) requires negotiation with the CEP entity and is
  not architecturally fixed.
- The Customer Rebate share fraction (TaAggregator → Customer
  fraction of LTN Cleared Market receipts after operational costs)
  is a TaAggregator policy choice, not architecturally fixed.
  Working assumption: ~50% of net.
- The detailed mechanics of TaAggregator-as-DERA registration with
  ISO-NE need to be confirmed against current ISO-NE process docs
  (see [`settlement.md`](settlement.md), Open).
