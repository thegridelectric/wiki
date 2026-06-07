Status: Draft · Pass 0 · Updated 2026-06-07

> What this is: the hub for the **GridWorks Economy Energy Market
> System** — the architecture that lets aggregations of heat-pump
> thermal storage capture the wholesale value of shifting load to
> times of renewable abundance, and share that value with the
> customers whose flexibility made it possible. The first deployment
> is behind the Keene Road substation in Versant Power's Bangor Hydro
> District, going live in coordination with ISO-NE Tariff Section
> III.6.4 (effective Nov 1, 2026). This hub is intentionally short;
> depth lives in the sub-specs.

## Why this architecture exists

Maine's Bangor Hydro District has substantial wind generation
behind the **Keene Road Export interface** — Stetson I/II,
Rollins, Bull Hill et al. When the interface binds, ISO-NE LMPs
at the wind nodes go deeply negative; some of those projects
have seen ~20% curtailment in a single year, with the
curtailment happening at deeply negative local prices.

The 100-home **Knifes Edge** development (Matt Polstein) sits
exactly behind that constraint. Heat-pump thermal storage gives
each home a flexible load that can absorb electricity during
those negative-price windows. The wholesale-market mechanism
that monetizes this flexibility — at the homeowner's pocket and
at the grid's benefit — is what this architecture builds.

**The opening:** ISO-NE Tariff Section III.6.4, effective
2026-11-01, lets a Distributed Energy Resource Aggregation
self-designate as Assigned Meter Reader. Under that path the
cohort can be settled at LMP × Actual at the wholesale level
without Versant Power changing anything operationally — the
master economy meter sits on a parallel service entrance per
III.6.4(d), and the CEP serving the cohort settles via the
TaReader's interval submission. The **Cleared Market** operated
by the GridWorks Market Maker routes the load-shifting value
from the CEP-side profile position to the per-asset
actual-delivery positions of the LTNs. Customers receive a
rebate from the TaAggregator proportional to the flexibility
their participation enabled.

**The vision beyond Knifes Edge.** Each MarketMaker is fractal:
runs its own internal markets at multiple timeframes, bids
outward into the next-higher-level MarketMaker, ends with
participation in ISO-NE wholesale markets. As the architecture
grows, MarketMakers sprout up at every grid constraint point —
panel-level inside a home (see
[Economy Panel](../../economy-panel/executor/primary.md)),
feeder-level, transformer-level, substation-level,
transmission-level — building out the collaborative low-voltage
grid map by agreeing on shared GNode aliases.

**The constraint frame.** The architecture works within three
layers of constraints we don't control (ISO-NE Tariff III.6.4,
FERC Orders 745 / 2222, Maine MPUC Chapter 305 / 322) and makes
specific GridWorks design choices within them. See
[`glossary.md`](glossary.md) for vocabulary partitioned by
ownership.

## The seven actors (one-line summary)

| Actor | Origin | Role |
| --- | --- | --- |
| **Customer** | generic | Homeowner with heat-pump thermal storage. Pays flat retail rate to CEP. Receives Customer Rebate from TaAggregator. Owns and can move TaTradingRights. |
| **CEP** | ME (industry, Ch. 305) | Supplier of record. Flat-rate retail. Net wholesale cost = LMP × Profile (structural guarantee). Commits to TaReader-exclusivity per-territory and Market Maker participation. |
| **TaAggregator** | GW | Fiduciary aggregator. Holds customer SLAs. Operates LTNs. Aggregates LTN financials. Routes Customer Rebates. May also hold the III.6.4 DERA registration (does in our Maine launch). |
| **TaReader** | GW | NEPOOL-wide trust anchor. Validates Participation Requirements (TaDeeds, TaTradingRights). Acts as agent-AMR for one or more DERAs per III.6.4(f). Submits to ISO-NE and to the Market Maker. |
| **LTN** (Leaf Transactive Node) | GW | Per-asset cryptographic identity. Holds delegated TaTradingRights. Bids in the Cleared Market. SCADA-honored dispatch authority. |
| **Market Maker** | GW | Fractal market operator anchored at a copper-sub-tree constraint point. Runs internal markets at multiple timeframes. Bids outward into the next-higher MarketMaker, ending at ISO-NE. |
| **TaValidator** | GW (independent) | Third-party (NOT GridWorks). On-site physical verification of installations. Signs TaDeeds. Randomized re-checks. Working candidate: Ridgeline Energy. |

Plus one ISO-NE designation:

- **DERA** (Distributed Energy Resource Aggregation; III.6.4) — the
  ISO-NE-registered Aggregation entity. NOT a separate actor in our
  architecture; in our deployment, the GridWorks TaAggregator for
  Versant territory also holds the DERA registration.

See [`actors.md`](actors.md) for full role definitions, boundaries,
and what each commits to.

## Glossary

See [`glossary.md`](glossary.md). Five sections:

1. **GridWorks vocabulary (active)** — GridWorks-coined and
   GridWorks-controlled terms. We define and refine these.
2. **GridWorks heritage vocabulary** — earlier work (TER, TEM, GNode,
   VCharge, AMM-OPF) preserved for provenance.
3. **ISO-NE / NEPOOL / FERC industry vocabulary** — given to us; we
   use as is.
4. **Maine-specific industry vocabulary** — MPUC, Versant, Maine
   statute; given to us.
5. **UK Elexon precedent** — cited as architectural precedent for
   TaReader's role separation.

## Architectural invariants

Non-negotiable structural commitments. Sub-specs MAY refine how each
is satisfied; they SHALL NOT contradict any of them. Each invariant
is tagged with its origin: **GW** (GridWorks design choice), **ISO**
(ISO-NE / FERC constraint), **ME** (Maine MPUC / Versant constraint).

1. **The customer pays a flat retail rate.** (**GW**) The customer is
   NOT exposed to LMP-pass-through pricing. The cleared-market value
   capture lives between the CEP and the LTNs, not between the CEP
   and the customer.
2. **The CEP is settled at LMP × Actual at the wholesale level**,
   using interval data submitted by the TaReader acting as agent-AMR
   per ISO-NE Tariff Section III.6.4(f). (**ISO** authorizes; **GW**
   chooses to use it.) Two consequent exclusivity commitments are
   necessary jointly for the rule to hold: (a) within each ISO-NE
   territory of operation, the CEP serves only TaOwners
   (customers whose meter is read by the TaReader), and (b) every CEP
   customer is settled via the TaReader's AMR submission. Together
   these allow ISO-NE to apply a single per-supplier settlement rule
   to the CEP and let Versant continue normal Rate A-1 operations
   without per-meter coordination — the "Versant changes nothing"
   property.
3. **The CEP's net wholesale cost equals LMP × Profile by structural
   guarantee.** (**GW**) The Market Maker's clearing of the
   profile-shape position against the LTNs' actual-delivery positions
   leaves the CEP with exposure exactly equal to LMP × Profile
   independent of cohort load shape. This is the load-bearing
   simplification of the CEP role and the basis of the CEP
   value-prop pitch.
4. **The TaReader is the trust anchor.** (**GW**) All participation
   in the Economy Energy Market System routes through the TaReader's
   validation of Participation Requirements (currently evidenced by
   TaDeeds and TaTradingRights). The Market Maker accepts no
   participation outside the TaReader's authority chain. SCADA honors
   no dispatch from an LTN without TaReader-validated credentials.
   Architectural precedent: the UK Elexon Balancing and Settlement
   Code's separation of MOP / HHDC / HHDA from the Supplier.
5. **The TaReader is NEPOOL-wide and one entity.** (**GW**) Holds
   ISO-NE non-host AMR registrations across all NEPOOL territories
   in which it operates. Holds agent-AMR designations from one or
   more DERAs per III.6.4(f). Single legal entity at launch; the role
   is defined as an open standard so future interoperable TaReader
   implementations are possible.
6. **The DERA layer is open.** (**GW**) Multiple DERAs may operate
   concurrently on top of the same TaReader infrastructure. The
   TaAggregator role (which holds SLAs and aggregates LTN financials)
   is separable from the DERA role (which holds the ISO-NE
   registration). In our initial Maine launch, the GridWorks
   TaAggregator is also the GridWorks Versant DERA, but the
   architecture admits non-GridWorks TaAggregators and non-GridWorks
   DERAs sharing the TaReader.
7. **Three GridWorks-affiliated legal entities, separate from day
   one.** (**GW**) The TaAggregator, the TaReader, and the Market
   Maker are each incorporated as distinct legal entities at launch,
   even when operating as integrated functions with shared staff and
   infrastructure. This (a) eliminates moral-hazard concerns from
   day one, (b) permits clean spin-off of any of the three later
   without regulatory or data-ownership transitions, and (c) follows
   the role-separation pattern established under UK Elexon.
8. **The TaValidator role: third-party, open standard,
   MarketMaker-sub-tree-scoped.** (**GW**) Three clauses, all
   load-bearing:
   (a) **Third-party, never GridWorks.** Physical on-site
   verification and signed TaDeeds come from an independent
   entity (Ridgeline Energy is the working candidate).
   (b) **Open standard — anti-regulatory-hijacking.** Any
   qualified entity may become a TaValidator after meeting
   the certification requirements; no single entity holds
   a monopoly on the role. Regulatory capture of the role
   (granting only utilities, or only one company, the right
   to validate) would defeat the architecture.
   (c) **Scoped to one or more MarketMakers' sub-trees.** A
   TaValidator's operational scope is geographically localized
   to the copper sub-tree(s) under specific MarketMakers,
   where on-site verification is practically executable.
   See [`actors.md`](actors.md) "TaValidator" for the
   three-item attestation duties (asset type, GPS location,
   meter accuracy).
9. **The LTN is the structural unit of market participation.**
   (**GW**) Each metered load has its own LTN with a cryptographic
   identity. The LTN holds TaTradingRights delegated by the
   customer via the SLA. The Market Maker accepts LTN positions
   directly; a TaAggregator's books are an operational financial
   overlay across many LTNs, not the structural market participant.
10. **TaTradingRights are TaOwner-owned and clawback-able.** (**GW**)
    The TaOwner always owns the rights to their asset's market
    participation. The SLA is an exchange instrument — TaTradingRights
    for SLA service — with a clawback right reserved to the TaOwner.
    The TaOwner can claw back the rights at any time per SLA terms —
    to a different LTN, a different TaAggregator, themselves, or
    nowhere. The architecture's market discipline depends on this
    clawback being immediate and unilateral.
11. **The Appliance Profile is exogenous and public.** (**GW**) The
    reference load shape used by the Market Maker is the typical
    heat-pump-without-storage profile for the customer's county in
    the customer's month, sourced from a public dataset (e.g., NREL
    ResStock). It is NOT derived from any DERA's controlled load.
    Updated annually with a locked-in profile for each settlement
    year.
12. **Mission-aligned supply partner required.** (**GW**) The CEP's
    wholesale supply / hedging partner SHALL be a nonprofit,
    mission-aligned entity (joint-action agency, member-owned coop,
    or purpose-built nonprofit). Structural exemplar: **MMWEC**
    (Massachusetts Municipal Wholesale Electric Company).
    Profit-maximizing corporate supply partners (Engie, Constellation,
    Shell, BP, NRG, Tenaska, or similar) are EXCLUDED regardless of
    operational fit.
13. **Open-source by default.** (**GW**) Tools and mechanisms
    developed for the architecture (Market Maker software, TaReader
    data pipeline, TaDeed protocol, Appliance Profile methodology,
    LTN reference implementation) are open-source and available for
    any other entity to use to operate compatible deployments.
14. **Participation Requirements are framework-agnostic.** (**GW**)
    The current evidence mechanism for Participation Requirements
    uses cryptographic primitives (TaDeeds, TaTradingRights).
    The requirements themselves are an open standard; alternative
    evidence mechanisms (signed certificates, public ledgers, etc.)
    may be substituted as long as they meet the underlying
    requirements.
15. **Metering topology: master economy meter + per-TerminalAsset
    for market participation.** (**GW**)
    (a) **Master economy meter.** The TaReader reads a single
    revenue-grade (ANSI C12) master economy meter that captures
    the total economy-energy load behind a TaOwner's installation.
    Its interval data is what the TaReader submits to ISO-NE for
    III.6.4(f) AMR settlement. Working v1 choice: the EKM Omnimeter
    (committed externally in the 2026-06-05 ISO-NE letter).
    (b) **Per-TerminalAsset metering is required for per-asset
    market participation.** When a home has one TerminalAsset, the
    master economy meter is the per-TA meter. When a home has
    multiple TerminalAssets behind one master meter, each must
    have its own sub-meter so the Cleared Market can bid them
    separately. The architecture does not pre-commit to how those
    sub-meters are realized (panel-side, appliance-embedded, or
    hybrid) — see [`metering.md`](metering.md).
    (b.1) **No metering-by-inference.** Reported energy MUST come
    from physical measurement by a meter that measures the
    TerminalAsset and only the TerminalAsset. Inferring energy
    from control signals plus a device's nameplate power rating
    is NOT permitted — that path was an explicit failure mode of
    pre-2022 DR/aggregation schemes and would undercut the
    Cleared Market's integrity.
    (c) **CEP-exclusivity is structurally forced, not chosen.**
    You cannot split a single master economy meter across two CEPs
    without breaking the LMP × Actual settlement rule. The rule
    appears as the CEP-settlement commitment; this clause captures
    *why* it is structurally forced — the master meter is the
    physical seam that admits exactly one CEP.
    (d) **Telemetry-capable, not obligated.** The architecture is
    capable of publishing meter telemetry to the host utility
    (Versant) on request, supporting future distribution-side
    visibility scenarios. There is no current operational
    obligation to do so; the "Versant changes nothing" property
    remains the v1 posture.
16. **Consumer protection runs through the SLA, not the regulator.**
    (**GW**)
    (a) **Voluntary, contractual.** Each TaOwner participates
    voluntarily and contracts with a TaAggregator via a Service
    Level Agreement that defines rebate share, performance
    obligations, dispute resolution, opt-out, and clawback. The
    TaOwner holds the TaDeed and TaTradingRights and can claw
    back at any time per SLA terms.
    (b) **Office of Consumer Advocate is not a stakeholder for
    Economy Energy.** Economy Energy is a voluntary parallel
    sub-economy, not a regulated retail service. The OCA's
    jurisdiction over the standard Versant retail relationship
    is unchanged; their jurisdiction does NOT extend to Economy
    Energy market participation. This is what lets the
    architecture move without consumer-advocate intervenor
    processes.
    (c) **Structurally sound *because* participation is
    voluntary with immediate clawback.** The architecture's
    consumer-protection burden lives in the SLA design (which
    MUST be fair, accessible, and audit-friendly), not in
    regulator-mediated rate cases. Captive ratepayers need
    regulatory protection; voluntary participants with clawback
    need a well-designed contract.
17. **Settlement at the local Node LMP, not Zonal.** (**ISO/GW**)
    (a) The architecture commits to settlement at the local
    ISO-NE **Node LMP** (or **Apnode** weighted average for
    multi-nodal cohorts) covering the cohort's electrical home
    substation — NOT at the Maine Load Zone LMP. Local price
    volatility behind binding constraints — specifically the
    **Keene Road Export interface** in Versant's Bangor Hydro
    District, where wind generation at Stetson I/II, Rollins,
    Bull Hill et al. drives LMPs deeply negative when the
    interface binds — is the economic motivation for this
    deployment. Settling at the Maine Zonal LMP would forfeit
    that signal.
    (b) **Two ISO-NE registration paths give us this access.**
    Both are worth pursuing in parallel:
    (i) **III.6.4(f) DERA Load Asset** — the path described in
    the 2026-06-05 letter to ISO-NE. ISO-NE permits multi-nodal
    DER aggregations to settle at the weighted average of
    constituent Node LMPs. *Open follow-up:* verify the as-filed
    III.6.4 Load-Asset-flavored settlement-location wording
    (`mr1_append_a.pdf`) confirms Node-level (not Zonal) settlement.
    (ii) **Dispatchable Asset Related Demand (DARD)** —
    definitively settles at its own Node LMP per M-11. Our
    heat-pump-thermal-storage cohort is *very dispatchable*
    (load can be modulated, paused, scheduled on minute-to-hour
    timescales) and structurally fits the DARD pattern. Jon
    Lowell (ISO-NE contact) has expressed confidence that
    GridWorks can qualify. **Chasing down DARD qualification
    is a load-bearing open work item** — it bypasses the
    III.6.4(f) Load-Asset settlement-location ambiguity entirely.
    (c) Open follow-ups tracked in `dera-stand-up/` (operational)
    and (when seeded) `regulatory-posture.md` (architectural).
18. **MarketMaker is fractal, runs internal markets, and
    co-optimizes across timeframes.** (**GW**)
    (a) **Each MarketMaker runs its own internal markets** at
    multiple timeframes — not just a clearing house for one
    external market, but a market operator in its own right.
    Internal markets typically span day-ahead, hour-ahead,
    intra-hour, real-time, and ancillary-service timescales,
    with the specific set determined by the MarketMaker's
    constraint-point context.
    (b) **MarketMakers are fractal.** Each MarketMaker
    participates as a bidder in the next-higher-level
    MarketMaker; the hierarchy ends with participation in the
    ISO-NE wholesale markets. The same architectural primitive —
    a MarketMaker anchored at a copper-sub-tree constraint
    point, running internal markets, bidding outward — repeats
    self-similarly at every scale (e.g., panel-level MarketMaker
    → cohort-level MarketMaker behind Keene Road → ISO-NE).
    (c) **LTNs participate in multiple market structures
    simultaneously.** An LTN may bid into energy, regulation,
    ancillary services, and capacity at once via its
    panel/cohort MarketMaker. Coordinating across markets so a
    single control action is not double-counted is a structural
    requirement of LTN and MarketMaker design.
    (d) **No accountability gaps across markets.** A load
    participating in any market structure (e.g., regulation)
    that also affects another market's balancing mechanism
    (e.g., energy in the same hour) MUST be accountable in all
    of them. This is what prevents arbitrage between markets
    and what keeps the books-clear property holding at every
    level of the fractal hierarchy.

## Connections

The architecture is most precisely described as a set of typed edges
between actors. Each edge below names `source → sink`, what flows,
and the cadence. Grouped by what flows (data / dollars / bids).
The Market Maker is the structural center — every settlement period,
every LTN AND a CEP-defined profile-shape counterparty bid into the
same Cleared Market.

### Data flows

- **TaReader → ISO-NE** — validated interval AMR data per
  III.6.4(f). The TaReader acts as the DERA's agent-AMR. Cadence:
  every settlement interval (5- or 15-minute), submitted on the
  ISO-NE timing SLA.
- **TaReader → Market Maker** — parallel validated interval data,
  used by the Market Maker to compute LTN actual-delivery
  positions. Same cadence as the ISO-NE submission.
- **TaReader → CEP** — interval data and monthly settlement
  totals so the CEP can reconcile its retail book against what was
  submitted to ISO-NE on its behalf.
- **TaValidator → TaReader / TaAggregator / Market Maker** — signed
  TaDeed attestations from on-site verification of each install;
  randomized re-verification reports; independent audit reports of
  the TaReader's data integrity. Cadence: at install + quarterly /
  triggered re-verifications.

### Dollar flows

See [`value-flow.md`](value-flow.md) for the full five-flow
treatment and worked example. Summary:

- **Customer → CEP** — flat-rate retail bill. Monthly.
- **CEP → ISO-NE** — wholesale settlement at LMP × Actual.
  Provisional daily, final monthly.
- **CEP → TaAggregator (via Market Maker clearing)** — Cleared
  Market net payment routing the load-shifting value. Monthly.
- **TaAggregator → Customer** — Customer Rebate (separate payment,
  NOT a credit on the CEP bill). Monthly.
- **TaAggregator → fixed-cost partners** — TaReader fees, Market
  Maker fees, TaValidator fees, infrastructure, debt service,
  margin. Internal economics.

### Bid flows (the Cleared Market)

The Market Maker clears every settlement period. Two kinds of
participant submit bids into it:

- **Each LTN → Market Maker** — per-asset actual-delivery position,
  hourly. The LTN bids the realized (or about-to-realize) load
  shape of its TerminalAsset against the LMP curve. Credentialed
  via TaReader-validated TaTradingRights.
- **CEP-defined profile counterparty → Market Maker** — a single
  profile-shape position covering the CEP's full cohort. The bid
  quantity is `Appliance Profile × Total Cohort Usage`; the bid is
  defined by the CEP's contract with the TaAggregator (the
  CEP doesn't have to literally submit it itself — the architecture
  *defines* this counterparty bid so the structural guarantee
  holds). Hourly.
- **Market Maker → cleared positions** — the Market Maker clears
  the two-sided market. The net effect is that the CEP's exposure
  is exactly LMP × Profile (the structural guarantee); the delta
  between LMP × Profile and LMP × Actual is the load-shifting
  value, which the Market Maker routes to the LTNs (collected by
  the TaAggregator).

Two-stage settlement: the hourly clearing uses a *forecast* of
Total Cohort Usage for the day; once the 24h actuals are known
the clearing is trued up. This matches the ISO-NE
provisional/final cadence and isolates forecast risk in exactly
one place — the CEP's day-ahead total-kWh forecast — which is the
easiest risk in the architecture (heating-degree-day analysis is
well-understood and forecast error converges over a month).

### Authority flows (who validates whom)

- **TaOwner → LTN** — TaTradingRights delegation via SLA.
  Clawback-able at any time per SLA terms.
- **TaReader → LTN** — credential validation; SCADA honors no
  dispatch from an LTN without TaReader-validated credentials.
- **TaReader → Market Maker** — the Market Maker accepts no
  participation outside the TaReader's authority chain.

See [`cleared-market.md`](cleared-market.md) (Open) for the
clearing mechanics, [`value-flow.md`](value-flow.md) for money flow
with worked example.

## TOC

Core (defines the architecture):

- [`glossary.md`](glossary.md) — canonical terms, organized by ownership
- [`actors.md`](actors.md) — seven-actor definitions
- [`cleared-market.md`](cleared-market.md) — market clearing mechanics
- [`value-flow.md`](value-flow.md) — money flow, who pays whom, worked example

Second-pass (refine the architecture; written or being written):

- [`participation-requirements.md`](participation-requirements.md) (Open) — per-role requirements and evidence mechanisms
- [`ta-reader.md`](ta-reader.md) (Open) — TaReader as trust anchor; Elexon precedent
- [`ta-aggregator.md`](ta-aggregator.md) (Open) — TaAggregator as fiduciary aggregator
- [`leaf-transactive-node.md`](leaf-transactive-node.md) (Open) — LTN as per-asset agent
- [`appliance-profile.md`](appliance-profile.md) (Open) — reference load shape methodology
- [`market-maker.md`](market-maker.md) (Open) — Market Maker internals
- [`settlement.md`](settlement.md) (Open) — ISO-NE side, III.6.4(f) dependency
- [`settlement-cadence.md`](settlement-cadence.md) (Open) — 2-stage Cleared Market settlement (hourly forecast → daily true-up → monthly)
- [`metering.md`](metering.md) (Open) — master economy meter, per-TA sub-metering options for multi-TA homes, placement evolution, cost engineering
- [`regulatory-posture.md`](regulatory-posture.md) (Open) — asks of ISO-NE, MPUC, Versant
- [`supply-partner.md`](supply-partner.md) (Open) — MMWEC + mission-aligned candidates
- [`cep-partnership.md`](cep-partnership.md) (Open) — CEP deal pitch + personality fit
- [`heritage.md`](heritage.md) (Open) — TER Initiative, Redefining DR, VCharge

## Where the first deployment lives

Operational scratch for the Knifes Edge stand-up lives at
`dera-stand-up/` (top-level, not in git). That folder holds deal
documents, regulator outreach drafts, candidate-entity research, and
timelines. This wiki domain holds the durable architectural spec
that the deployment implements.

## Status

- 2026-06-07 · Architectural core: 18 invariants locked. Reading
  flow restructured (Why → Actors → Glossary → Invariants →
  Connections). Seven-actor structure with Customer / CEP /
  TaAggregator / TaReader / LTN / Market Maker / TaValidator.
  Glossary partitioned by ownership (GridWorks vs industry vs
  precedent). Open spokes queued in TOC.
