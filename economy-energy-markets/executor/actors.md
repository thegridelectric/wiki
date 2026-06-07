Status: Draft · Pass 0 · Updated 2026-06-06

> What this is: full role definitions for the six actors in the
> Economy Energy Markets architecture. Each section names what the
> actor commits to, what it receives, and the operational boundaries
> with the other actors. See [`primary.md`](primary.md) for the hub
> and [`value-flow.md`](value-flow.md) for the money mechanics.

## Customer

The homeowner enrolled in the DERA cohort with an installed
heat-pump thermal storage system.

**Commits to:**

- Service Level Agreement with the DERA, granting the DERA control
  over the storage-controlled load within stated comfort constraints.
- Supplier-of-record relationship with the CEP for retail electricity.
- Allowing physical install + occasional re-verification by the
  TA-Validator.

**Receives:**

- A flat-rate retail electricity bill from the CEP. The customer is
  NOT exposed to LMP-pass-through pricing or any other variable-rate
  product.
- A rebate from the DERA proportional to the storage-shifting their
  participation enabled. The rebate is a separate value stream from
  the CEP bill; the CEP bill does NOT reflect the rebate.
- Maintained comfort within SLA bounds (thermostat-driven; cohort
  surplus capacity).

**Switching:** The customer may switch CEPs at any time per Maine
MPUC rules. If the customer switches off the dedicated CEP, the DERA
relationship terminates and the rebate flow ends; this is by mutual
contractual design, not punitive.

## CEP (Competitive Electricity Provider)

Maine MPUC Chapter 305 licensed retail electricity supplier. Supplies
the dedicated cohort exclusively. Likely entity: Efficiency Maine
Trust if it elects to take on the role; otherwise a partner CEP with
an existing license (Option B).

**Commits to:**

- Maintaining a Chapter 305 license in good standing.
- Acting as supplier of record for every enrolled customer in the
  cohort.
- Offering a flat-rate residential electricity product.
- **Dedicated-cohort exclusivity.** Every customer of the CEP is a
  DERA-cohort member. The CEP serves no customers outside the
  cohort. (Necessary so ISO-NE can apply a uniform per-supplier
  settlement rule.)
- **Meter Reader exclusivity for AMR.** Every customer of the CEP is
  read by the Meter Reader and settled at LMP × Actual using the
  Meter Reader's III.6.4(f) AMR submission. No CEP customer is
  settled at the wholesale level via Versant's residential
  class-profile allocation or any other AMR. (This is what makes
  the "Versant unchanged" story work — see below.)
- Engaging a mission-aligned wholesale supply / hedging partner —
  joint-action agency, member-owned coop, or purpose-built nonprofit.
  See [`supply-partner.md`](supply-partner.md). Profit-maximizing
  corporate supply partners (Engie, Constellation, Shell, BP, NRG,
  Tenaska) are EXCLUDED regardless of operational fit.
- **Bringing its profile-shape position to the Market Maker.** For
  every product where the CEP has an obligation or charge tied to
  the cohort's load shape — wholesale energy (LMP × Profile),
  Versant monthly and annual Coincident Peak demand charges
  (CP rate × Profile CP), RPS obligations (REC volume × Profile
  MWh), and any other shape-dependent charge — the CEP submits its
  profile-based position into the Market Maker. The Market Maker
  clears that against the DERA's Actual delivery; the CEP retains
  a fixed administrative margin per customer per month; net flow
  from the trade goes to the DERA. The CEP does NOT compute or
  route the bilateral itself — it owns the profile-shape position;
  the Market Maker is the marketplace.
- Standard Chapter 305 customer protections: Terms of Service,
  5-day opt-out window, advance notice of renewal, anti-slamming
  authorization-prior-to-enrollment, complaint handling.

**Why these two exclusivity commitments are load-bearing.** The
architecture's "Versant changes nothing" property depends on ISO-NE
being able to apply a single, uniform settlement rule to the
dedicated CEP: settle at LMP × Actual using the Meter Reader's AMR
submission for the entire CEP, in all hours, for all customers. If
even one CEP customer were outside the cohort or settled via
Versant's standard profiled allocation, ISO-NE would need to apply
a mixed per-customer rule — which forces Versant-side per-meter
flagging and coordination of which meters use which settlement
basis. The whole point of the design is to NOT require that.
Versant continues its normal Rate A-1 reads, normal per-supplier
allocation, and normal Metering Domain residual reconciliation;
ISO-NE handles the dedicated CEP as a special-case at the
settlement-engine level (using our AMR submission as authoritative
per III.6.4(f)); Versant never has to know which of its bonus
meters belong to the cohort. Both exclusivity commitments above
are necessary, jointly, for this to hold.

**Receives:**

- Retail revenue from the customer (flat rate × kWh).
- A predictable per-customer per-month administrative margin that
  covers bill issuance, MPUC compliance, customer service,
  hedging-coordination overhead, and a small profit/contribution to
  reserves.
- Recognition as the supplier of record on the customer's bill.

**Carries:**

- The CEP carries wholesale commodity risk in principle (it is paying
  LMP × Actual to the ISO). In practice, the mission-aligned supply
  partner takes most of that risk; what remains is bounded and small
  given the dedicated-cohort scale and the bilateral with the DERA.

**Does NOT:**

- Run the optimizer or hold the customer SLA. Both belong to the
  DERA.
- Submit interval data to ISO-NE itself. The Meter Reader does that.
- Take a position on the bilateral math. The fixed administrative
  margin is the only number the CEP cares about; everything else
  flows through.

## DERA (Distributed Energy Resource Aggregation)

The GridWorks-owned DERA entity registered with ISO-NE under Tariff
Section III.6.4 (effective Nov 1, 2026). Holds the customer
relationship for control + service. Captures the load-shifting
value via the Market Maker bilateral.

**Commits to:**

- Registering with ISO-NE as a Distributed Energy Resource
  Aggregator.
- Designating the Meter Reader as its agent-AMR under III.6.4(f).
- Holding a Service Level Agreement with each enrolled customer
  covering control rights, comfort guarantees, rebate flow, and
  contract term.
- Operating a Transactive Energy Management platform that meets the
  technical commitments of the 2021 TER Initiative
  (see [`heritage.md`](heritage.md)) — 24/7, automated, market-based
  interaction, asynchronous and flexible in real time, accountable
  to real-time wholesale prices in all hours.
- Submitting interval data to ISO-NE per III.6.4(f) data delivery
  SLAs (by 0800 next business day to the Host Participant where
  required; by 1300 second business day to ISO-NE).
- Retaining six years of meter data per III.6.4(g).
- Paying the customer rebate, monthly, from the DERA's share of the
  Market Maker bilateral.

**Receives:**

- The CEP's gross margin above the fixed administrative margin,
  routed monthly via the Market Maker.
- Per-home interval data from the Meter Reader for control and
  verification.
- Wholesale-market revenue from any future Order 2222 / III.14.2
  Active Demand Capacity Resource / Alternative Technology
  Regulation Resource participation that is built on top of the
  energy bilateral.

**Does NOT:**

- Settle retail bills with customers. The CEP does that.
- Own or operate the Meter Reader. The Meter Reader is a separate
  legal entity from day one.
- Sign its own AMR data. The TA-Deed signatures come from the
  TA-Validator independently.

## Meter Reader

The DERA's agent-AMR under III.6.4(f). A separate legal entity from
day one. Initially a wholly-owned GridWorks subsidiary; designed for
clean spin-off.

**Commits to:**

- Holding the ISO-NE non-host AMR registration in its own name.
- Operating the GridWorks-installed meter behind Versant's bonus
  meter at each enrolled home.
- **Reading every customer of the dedicated CEP, with no gaps.**
  Each new customer enrolled in the cohort and onboarded onto the
  CEP must have a GridWorks meter installed, TA-Deed signed, and
  meter reads flowing in the Meter Reader's AMR submission before
  ISO-NE settlement applies to that customer under the dedicated-CEP
  rule. The CEP's exclusivity commitments above depend on this:
  any gap (an enrolled CEP customer not yet in the AMR submission)
  breaks the uniform per-supplier settlement rule ISO-NE applies
  to the dedicated CEP.
- Submitting interval data to ISO-NE on the III.6.4(f) timing SLA.
- Submitting parallel interval data to the Market Maker for
  bilateral computation.
- Conformance with ISO-NE Operating Procedure No. 18 (Metering and
  Telemetering) and Manual M-28 (Market Rule 1 Accounting).
- Six-year data retention.
- Accepting TA-Deed signatures from the TA-Validator as the
  authoritative install record for each meter.
- Compliance with the III.6.4(f) coordination-agreement obligations
  with Versant.

**Receives:**

- A per-meter or per-customer service fee from the DERA, internally
  modeled now (so the unit economics are clear) and invoicing
  externally on any future spin-off.

**Structural commitments:**

- Separate legal entity from day one. Distinct corporate identity,
  separate financial books.
- Architecturally designed for clean spin-off later: defined API
  surface to downstream consumers (DERA, Market Maker, ISO-NE),
  data namespace not shared with DERA, independent regulatory
  standing.
- Elexon Balancing and Settlement Code precedent: in UK BSC, the
  Meter Operator, Data Collector, Data Aggregator, and Supplier are
  separate commercial entities by structural design. Our Meter
  Reader combines the BSC Data Collector + Data Aggregator roles.

**Does NOT:**

- Verify physical installations. The TA-Validator does that.
- Hold the customer SLA. The DERA does that.
- Compute the bilateral. The Market Maker does that.

## Market Maker

The GridWorks-built broker for the CEP↔DERA bilateral. The
infrastructure piece that makes the value transfer mechanical and
auditable. Separate legal entity from day one. Initially
GridWorks-affiliated; designed for clean spin-off as a standalone
product company.

**Commits to:**

- Computing the load-shifting value monthly: `(Appliance Profile −
  Actual) × LMP`, summed per customer per interval over the
  settlement period. See [`bilateral.md`](bilateral.md) for the
  exact formula.
- Routing payment from the CEP to the DERA per the bilateral
  contract, monthly.
- Maintaining auditable records of every bilateral computation:
  inputs (Meter Reader interval data, Appliance Profile reference,
  LMP series), formula, output, signed by the relevant parties.
- Extending the same routing mechanism to FCM Coincident Peak
  allocations (CEP's profile-based CP allocation versus actual
  AMR-derived CP) and to any future Order 2222 / III.14.2 products
  where a CEP↔DERA bilateral is the cleanest split.
- Open-source publication of the Market Maker software and protocol.

**Receives:**

- A per-customer per-month transaction fee from the DERA (or
  alternatively from the CEP — the bilateral contract names which
  party bears the Market Maker cost) for brokerage services.

**Structural commitments:**

- Separate legal entity from day one.
- Designed for spin-off as a standalone product company.
- Open-source posture: tech is open; the GridWorks Market Maker is
  one implementation; others can build interoperable Market Makers.

**Does NOT:**

- Take a position. The Market Maker is a clearing mechanism, not a
  counterparty. It does not bear LMP risk, does not bear default
  risk between CEP and DERA, and does not extract a percentage of
  the bilateral value.
- Submit data to ISO-NE. The Meter Reader does that.

## TA-Validator

Independent third party performing on-site physical verification of
installations and signing cryptographic deeds (TA-Deeds) attesting
to physical reality. Fully third-party from day one — never
GridWorks. Working candidate: Ridgeline Energy / Dave Korn.

**Commits to:**

- On-site verification at each install: meter make/model and serial,
  location, system type (heat pump + thermal storage configuration),
  installer identity, photo evidence, timestamp.
- Issuing a cryptographically signed TA-Deed per install that
  attests to the verified facts.
- Performing randomized re-checks on existing enrolled homes at a
  defined cadence (e.g., quarterly sample, ~5% of homes).
- Maintaining an auditable signature key infrastructure.
- Reporting irregularities or suspected fraud to the Meter Reader
  and (under defined protocols) to ISO-NE and MPUC.

**Receives:**

- A per-install verification fee paid by the DERA.
- A periodic re-check fee paid by the DERA.

**Structural commitments:**

- Genuinely independent of GridWorks. Separate ownership, separate
  governance, separate operational chain of command. NOT a
  wholly-owned GridWorks entity.
- Verification keys held under the TA-Validator's exclusive control;
  GridWorks-affiliated entities cannot forge TA-Deed signatures.
- The TA-Validator's signature is the authoritative physical-reality
  record. The Meter Reader cannot accept reads from an unverified
  install for AMR settlement purposes.

**Does NOT:**

- Read meters day-to-day. The Meter Reader does that.
- Operate equipment on the customer's premises beyond initial
  verification and randomized re-check visits.
- Take a commercial position in the bilateral. Compensation is fee
  for service, fixed and disclosed.

## Why six actors, not five

In earlier framings, the TA-Validator was sometimes counted as a
sixth "deal participant" and sometimes treated as a supporting
service to the Meter Reader. The architectural commitment is that
the TA-Validator is **architecturally necessary but commercially
out-of-band** — it is paid for service, like an auditor, and does
not participate in the bilateral cash flows. Five entities are in
the deal flow (Customer, CEP, DERA, Meter Reader, Market Maker);
the TA-Validator is the sixth role, supplying the trust property
that makes the AMR data auditable.

## Open

- The supply partner discussion is in [`supply-partner.md`](supply-partner.md)
  (placeholder). MMWEC is the structural exemplar; concrete partner
  identification is a critical-path operational item.
- The fixed administrative margin number (the CEP's per-customer
  per-month fee) requires negotiation with the CEP entity and is
  not architecturally fixed.
