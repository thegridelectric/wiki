Status: Draft · Pass 0 · Updated 2026-06-06

> What this is: the hub for the **Economy Energy Markets** architecture —
> the GridWorks-designed market structure that lets aggregated heat-pump
> thermal storage cohorts capture the wholesale value of shifting load
> to times of renewable abundance, and share that value with the
> customers whose flexibility made it possible. The first deployment
> target is behind the Keene Rd substation
> operating in Versant Power's Bangor Hydro District and going live in
> coordination with ISO-NE Tariff Section III.6.4 (effective Nov 1, 2026).
> This hub is intentionally short; depth lives in the sub-specs.

## Architectural commitments (invariants)

These are non-negotiable structural commitments. Sub-specs MAY refine
how each is satisfied; they SHALL NOT contradict any of them.

1. **The customer pays a flat retail rate.** The customer is NOT exposed
   to LMP-pass-through pricing. The bilateral value-capture lives
   between the CEP and the DERA, not between the CEP and the customer.
2. **The CEP is settled at LMP × Actual at the wholesale level**, using
   interval data submitted by the Meter Reader (DERA's agent-AMR) per
   ISO-NE Tariff Section III.6.4(f). This is the load-bearing regulatory
   dependency for the architecture; if ISO-NE does not honor this
   interpretation, the architecture does not work as designed.
   **This settlement rule applies uniformly to every customer of the
   dedicated CEP.** Two consequent exclusivity commitments are
   necessary jointly for the rule to hold: (a) the CEP serves only
   DERA-cohort customers (no customers outside the cohort), and (b)
   every CEP customer is read by the Meter Reader (no customers
   settled via Versant's standard profiled allocation). Together,
   these commitments allow ISO-NE to apply a single per-supplier
   settlement rule to the dedicated CEP and let Versant continue
   normal Rate A-1 operations without per-meter coordination — the
   "Versant changes nothing" property.
3. **Three GridWorks-affiliated legal entities, separate from day one.**
   The DERA, the Meter Reader, and the Market Maker are each
   incorporated as distinct legal entities at launch, even when
   operating as integrated functions with shared staff and
   infrastructure. The structure (a) eliminates moral-hazard concerns
   from day one, (b) permits clean spin-off of any of the three later
   without regulatory or data-ownership transitions, and (c) follows
   the role-separation pattern established under the UK Elexon
   Balancing and Settlement Code.
4. **The Meter Reader is the DERA's agent-AMR, not the DERA itself.**
   The DERA designates the Meter Reader under III.6.4(f)'s "agent
   acting on its behalf" provision. The Meter Reader holds the
   ISO-NE non-host AMR registration in its own name from day one.
5. **The TA-Validator is fully third-party, never GridWorks.** Physical
   on-site verification and signed TA-Deeds come from an independent
   entity (Ridgeline Energy / Dave Korn is the working candidate).
6. **The Appliance Profile is exogenous and public.** The reference
   load shape used by the Market Maker is the typical
   heat-pump-without-storage profile for the customer's county in the
   customer's month, sourced from a public dataset (e.g., NREL
   ResStock). It is NOT derived from the DERA's own controlled load.
   It is updated annually with locked-in profile for each settlement
   year.
7. **Mission-aligned supply partner required.** The CEP's wholesale
   supply / hedging partner SHALL be a nonprofit, mission-aligned
   entity (joint-action agency, member-owned coop, or purpose-built
   nonprofit). The structural exemplar is **MMWEC** (Massachusetts
   Municipal Wholesale Electric Company). Load-shifting value created
   by the DERA SHALL NOT be extractable by a profit-maximizing corporate
   supply partner (Engie, Constellation, Shell, BP, NRG, Tenaska, or
   similar) regardless of operational fit.
8. **Open-source by default.** Tools and mechanisms developed for the
   architecture (Market Maker software, AMR data pipeline, TA-Deed
   protocol, Appliance Profile methodology) are open-source and
   available for any other entity to use to operate compatible
   deployments.

## The six actors (one-line summary)

| Actor | Role |
| --- | --- |
| **Customer** | Homeowner with heat-pump thermal storage. Pays flat retail rate to CEP. Receives rebate from DERA. |
| **CEP** | Maine MPUC Chapter 305 supplier of record. Flat-rate retail to customer; settled at LMP × Actual at wholesale via AMR data. Keeps fixed administrative margin per customer per month; routes the rest to DERA via Market Maker. |
| **DERA** | Distributed Energy Resource Aggregation per ISO-NE Tariff Section III.6.4. Holds customer SLA. Captures load-shifting value via Market Maker bilateral. Pays customer rebate. |
| **Meter Reader** | The DERA's agent-AMR under III.6.4(f). ISO-NE non-host AMR registration. Operates the GridWorks-installed meter behind Versant's bonus meter. Separate legal entity from day one. |
| **Market Maker** | The GridWorks-built broker for the CEP↔DERA bilateral. Computes the load-shifting value monthly; routes payment. Same routing mechanism for energy + FCM capacity + future products. Separate legal entity from day one. |
| **TA-Validator** | Independent third party (Ridgeline Energy / Dave Korn is the working candidate). On-site physical verification of installations. Signs TA-Deeds. Randomized re-checks. Architecturally separable from Meter Reader. |

See [`actors.md`](actors.md) for full role definitions, boundaries,
and what each commits to.

## Glossary

See [`glossary.md`](glossary.md). Terms are organized into five
sections: Core architecture terms (GridWorks primitives that travel
across deployments), Maine deployment terms, ISO-NE / NEPOOL
regional terms, UK Elexon precedent terms, and Heritage / GridWorks
technical terms.

## Six-actor diagram

```
       ┌───────────────────────────────────────────┐
       │                                           │
       │   ISO-NE settles dedicated CEP            │
       │   at LMP × Actual using AMR data          │
       │                                           │
       └─────┬─────────────────────────────────┬───┘
             │                                 ▲
   AMR data  │                  per-supplier   │  AMR data
   to ISO-NE │                  settlement     │  to ISO-NE
             ▼                                 │
       ┌───────────┐                ┌─────────┴───────┐
       │ Meter     │ interval data  │  CEP            │
       │ Reader    │───────────────▶│  (flat retail   │
       │ (AMR-     │  to Market     │   to customer;  │
       │  agent)   │  Maker         │   admin margin) │
       └─────┬─────┘                └────────┬────────┘
             │                               │
   TA-Deed   │                               │
   sigs +    │                               │  flat-rate
   raw reads │                               │  bill
             ▼                               ▼
       ┌───────────┐                ┌─────────────────┐
       │  TA-      │   verification │  Customer       │
       │  Validator│   on installs  │  (heat-pump     │
       │           │◀───────────────│   thermal       │
       └───────────┘                │   storage)      │
                                    └────────▲────────┘
                                             │
                                             │  rebate
                                             │  (load-shifting
                                             │   value flowing
                                             │   back)
       ┌───────────┐  bilateral     ┌────────┴────────┐
       │  Market   │  payment       │  DERA           │
       │  Maker    │───────────────▶│  (holds SLA;    │
       │           │  per month     │   captures      │
       │           │                │   value)        │
       └───────────┘                └─────────────────┘
              ▲
              │  (Profile − Actual) × LMP
              │  computed monthly
              │
        Appliance Profile
        (heat-pump-no-storage,
         per county per month,
         NREL ResStock)
```

See [`value-flow.md`](value-flow.md) for the full money flow with
worked examples.

## TOC

Core (defines the architecture):

- [`glossary.md`](glossary.md) — canonical terms, organized by scope
- [`actors.md`](actors.md) — six-actor definitions, boundaries, commitments
- [`value-flow.md`](value-flow.md) — money flow, who pays whom, worked example
- [`bilateral.md`](bilateral.md) — the structural pattern (CEP↔DERA via Market Maker)

Second-pass (refine the architecture):

- [`appliance-profile.md`](appliance-profile.md) — reference load shape methodology *(Open)*
- [`market-maker.md`](market-maker.md) — Market Maker internals + data flows *(Open)*
- [`meter-reader.md`](meter-reader.md) — operational AMR details + Elexon-pattern separation *(Open)*
- [`ta-validator.md`](ta-validator.md) — independent verification + TA-Deed framework *(Open)*
- [`settlement.md`](settlement.md) — ISO-NE side; the III.6.4(f) dependency *(Open)*
- [`regulatory-posture.md`](regulatory-posture.md) — what we ask of ISO-NE, MPUC, Versant *(Open)*
- [`supply-partner.md`](supply-partner.md) — mission-aligned partner candidates (MMWEC, NHEC, etc.) *(Open)*
- [`heritage.md`](heritage.md) — TER Initiative, Redefining DR, VCharge *(Open)*
- [`open-questions.md`](open-questions.md) — known uncertainties *(Open)*

## Where the first deployment lives

Operational scratch for the Knifes Edge stand-up lives at
`dera-stand-up/` (top-level, not in git). That folder holds deal
documents, regulator outreach drafts, candidate-entity research, and
timelines. This wiki domain holds the durable architectural spec
that the deployment implements.

## Status

- 2026-06-06 · Pass 0 · Architecture locked through key invariants and
  six-actor structure. Core spokes seeded; second-pass spokes are
  Open. Legacy intake from 2021 TER PDFs + Redefining DR + GNode
  materials pending as a follow-on check pass.
