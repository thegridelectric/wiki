Status: Draft · Pass 0 · Updated 2026-06-06

> What this is: the hub for the **GridWorks Economy Energy Market
> System** — the architecture that lets aggregations of heat-pump
> thermal storage capture the wholesale value of shifting load to
> times of renewable abundance, and share that value with the
> customers whose flexibility made it possible. The first deployment
> is behind the Keene Road substation in Versant Power's Bangor Hydro
> District, going live in coordination with ISO-NE Tariff Section
> III.6.4 (effective Nov 1, 2026). This hub is intentionally short;
> depth lives in the sub-specs.

## How to read the spec

The architecture works within three layers of constraints we don't
control (ISO-NE Tariff III.6.4, FERC Orders 745 / 2222, Maine MPUC
Chapter 305 / 322), and makes specific GridWorks design choices
within those constraints. The glossary partitions terms by ownership
so it is always clear which is which. See
[`glossary.md`](glossary.md) for the canonical vocabulary.

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
8. **The TaValidator is fully third-party, never GridWorks.**
   (**GW**) Physical on-site verification and signed TaDeeds come
   from an independent entity (Ridgeline Energy / Dave Korn is the
   working candidate).
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

## The seven actors (one-line summary)

| Actor | Origin | Role |
| --- | --- | --- |
| **Customer** | generic | Homeowner with heat-pump thermal storage. Pays flat retail rate to CEP. Receives Customer Rebate from TaAggregator. Owns and can move TaTradingRights. |
| **CEP** | ME (industry, Ch. 305) | Supplier of record. Flat-rate retail. Net wholesale cost = LMP × Profile (structural guarantee). Commits to TaReader-exclusivity per-territory and Market Maker participation. |
| **TaAggregator** | GW | Fiduciary aggregator. Holds customer SLAs. Operates LTNs. Aggregates LTN financials. Routes Customer Rebates. May also hold the III.6.4 DERA registration (does in our Maine launch). |
| **TaReader** | GW | NEPOOL-wide trust anchor. Validates Participation Requirements (TaDeeds, TaTradingRights). Acts as agent-AMR for one or more DERAs per III.6.4(f). Submits to ISO-NE and to the Market Maker. |
| **LTN** (Leaf Transactive Node) | GW | Per-asset cryptographic identity. Holds delegated TaTradingRights. Bids in the Cleared Market. SCADA-honored dispatch authority. |
| **Market Maker** | GW | Operates the Cleared Market. Computes CEP bulk profile positions and LTN actual-delivery positions. Clears every settlement period. Routes net flows. |
| **TaValidator** | GW (independent) | Third-party (NOT GridWorks). On-site physical verification of installations. Signs TaDeeds. Randomized re-checks. Working candidate: Ridgeline Energy / Dave Korn. |

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

- 2026-06-06 · Architectural core: 14 invariants locked,
  seven-actor structure with Customer / CEP / TaAggregator / TaReader
  / LTN / Market Maker / TaValidator. Glossary partitioned by
  ownership (GridWorks vs industry vs precedent). Open spokes
  queued in TOC.
