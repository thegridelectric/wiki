Status: Draft · Pass 0 · Updated 2026-06-06

> What this is: the structural pattern of the CEP↔DERA bilateral
> brokered by the Market Maker. Describes the formula, the timing,
> the contractual structure, and the extensibility to other products
> (FCM CP, future Order 2222 services). See [`actors.md`](actors.md)
> for the role definitions and [`value-flow.md`](value-flow.md) for
> the worked example.

## What the bilateral is

The bilateral is a **two-sided market** that clears inside the
GridWorks Market Maker between the CEP and the DERA. The CEP
brings its profile-shape position. The DERA brings the Actual
delivery. The Market Maker clears the trade. What the CEP pays
the DERA is the net flow out of that clearing, minus a fixed
administrative margin the CEP retains.

The Market Maker is not a calculator that routes a pre-determined
delta — it is a marketplace. The CEP and the DERA each take a
position in the marketplace every settlement period, on every
product that scales with load shape: wholesale energy (priced at
LMP), Versant monthly and annual Coincident Peak demand charges
(priced at the CP rate), any RPS obligation that scales with the
cohort's MWh, and any future product where a profile-shape vs
actual-shape distinction is meaningful. The market clears across
all these products together.

The bilateral market lives **outside** ISO-NE settlement. ISO-NE
settles the CEP at LMP × Actual using the Meter Reader's AMR
submission; the bilateral market is a private commercial venue
downstream of that. ISO-NE does not see it and it is not part of
FERC-jurisdictional wholesale settlement.

## The clearing formula

The market clears across all shape-dependent products in a single
settlement period (typically one calendar month). For a given
customer `c`:

```
B(c) = B_energy(c) + B_CP(c) + B_RPS(c) + ...

  B_energy(c) = Σ_intervals [ ( Profile(c, t) − Actual(c, t) ) × LMP(t) / 1000 ]
  B_CP(c)     = ( Profile_CP(c) − Actual_CP(c) ) × CP_rate(month)
  B_RPS(c)    = ( Profile_MWh(c) − Actual_MWh(c) ) × REC_value(month)
  ...
```

Where each term is the value of the CEP's profile-position minus
the DERA's actual-delivery for one product:

- **Energy.** `Profile(c, t)` is the customer's Appliance Profile
  usage in kWh for interval `t` — the heat-pump-without-storage
  typical-day shape for the customer's county and month, scaled to
  actual total monthly consumption. `Actual(c, t)` is the meter
  reading. `LMP(t)` is the wholesale Locational Marginal Price at
  the settlement zone in $/MWh. See
  [`appliance-profile.md`](appliance-profile.md).
- **Coincident Peak (CP) demand charges.** `Profile_CP(c)` is the
  customer's contribution to Versant's monthly or annual system
  peak under the Appliance Profile. `Actual_CP(c)` is the customer's
  actual contribution. `CP_rate(month)` is the Versant CP charge
  rate in $/kW.
- **RPS / REC obligations.** `Profile_MWh(c)` and `Actual_MWh(c)`
  are the total monthly volumes; `REC_value(month)` is the CEP's
  per-MWh REC procurement cost. Most of the time
  Profile_MWh ≈ Actual_MWh (the DERA doesn't change total energy
  use, only shape), so this term is small or zero — but it goes
  through the same market.
- Additional products go through the same `(Profile − Actual) ×
  price` form. Future Order 2222 services and any state-level
  programs that price profile-shape positions can be added without
  changing the architecture.

The cohort bilateral total is the sum over customers and products:
`B = Σ_c B(c)`.

The monthly net payment from CEP to DERA is `B` minus the fixed
administrative margin retained by the CEP:

```
Payment(CEP → DERA) = B − ( admin_margin × cohort_size )
```

Where `admin_margin` is the negotiated per-customer per-month
administrative margin (the CEP's fee for being the supplier of
record and handling billing, MPUC compliance, customer service,
and supply-partner hedging-coordination overhead).

## Why this works (the books-clear argument)

For the architecture to balance, two identities must hold:

**Identity 1: ISO-NE-side settlement is consistent.**
The CEP pays ISO-NE: `Σ Actual × LMP / 1000`.
ISO-NE pays generators: `Σ Actual × LMP / 1000`.
These match — the wholesale market clears at LMP × Actual without
any subsidy or socialization step.

**Identity 2: Customer-facing money is consistent.**
The customer pays the CEP: `retail_rate × total_kWh`.
The CEP collects retail revenue and pays wholesale at LMP × Actual.
The CEP's "earned-margin reference" (what its margin would be if
the customer consumed on the Appliance Profile) is:
`retail_rate × total_kWh − Σ Profile × LMP / 1000`.
The CEP's actual margin is:
`retail_rate × total_kWh − Σ Actual × LMP / 1000`.

The difference, `Σ (Profile − Actual) × LMP / 1000 = B`, is exactly
the bilateral value. Routing `B − admin_margin × cohort_size` from
the CEP to the DERA brings the CEP's net margin back to the
earned-margin reference plus the admin margin — neither too much
nor too little.

## Contract structure

The bilateral contract names:

1. **Parties.** CEP entity (name); DERA entity (name); Market Maker
   entity (name, as agent/clearing party).
2. **Cohort definition.** Identification of the enrolled customers
   (by Versant account or equivalent) and the rules for adding,
   removing, and transferring customers.
3. **Appliance Profile reference.** The specific public dataset and
   version (e.g., "NREL ResStock 2026-Q4 release") and the formula
   for scaling the per-county-per-month typical shape to the
   customer's actual monthly total.
4. **Settlement zone and LMP series.** The ISO-NE settlement zone
   used and the data source for the LMP series (ISO-NE published
   settlement prices). Day-Ahead vs Real-Time election — working
   assumption: Day-Ahead, since residential load shifting against
   day-ahead is the operational decision-making frame.
5. **Settlement cadence.** Monthly settlement, with a defined cure
   window if the Meter Reader's interval data needs correction.
6. **Admin margin.** The per-customer per-month dollar fee the CEP
   retains.
7. **Payment mechanics.** How the Market Maker computes, when
   payment is invoiced, how disputes are handled, what happens on
   non-payment.
8. **Exclusivity.** The CEP serves no other customers; this is the
   "dedicated CEP" commitment.
9. **AMR designation.** The CEP acknowledges the DERA's designation
   of the Meter Reader as agent-AMR per III.6.4(f) and agrees to
   accept the Meter Reader's interval data as authoritative for
   ISO-NE settlement of the cohort.
10. **Term and termination.** Initial term (probably 3-5 years),
    renewal mechanics, termination triggers, transition obligations.

The contract template lives in
`dera-stand-up/cep/amr-commitment-contract.md` for the Knifes Edge
deployment.

## Products the Market Maker handles natively vs other revenue

The bilateral clearing above handles all products where the CEP
has a profile-shape-dependent obligation that the DERA's control
discharges. There are also wholesale-market revenue streams that
flow **directly to the DERA**, bypassing the bilateral entirely.
The distinction:

**Cleared in the bilateral market (CEP profile-position vs DERA
actual-delivery):**

- Wholesale energy at LMP
- Versant monthly and annual Coincident Peak demand charges
- RPS / REC obligations that scale with cohort MWh
- Any other CEP-side obligation or charge that scales with the
  cohort's load shape

**Direct DERA revenue (not bilateral; the CEP has no position to
discharge):**

- **Active Demand Capacity Resource revenue** (per III.13). If the
  cohort is registered as an ADCR, capacity revenue comes to the
  DERA from ISO-NE directly. The CEP has no symmetric ADCR
  obligation to settle against.
- **Alternative Technology Regulation Resource revenue** (per
  III.14.2 / III.6.4(b)). Same structure — direct DERA revenue.
- **Future Order 2222 products** where the DERA registers the
  cohort as a market participant in its own right. Direct.

The Market Maker handles the bilateral products through one
uniform mechanism: profile-position × price for the CEP, actual
× price for the DERA, market clears. Direct-revenue products
don't flow through the Market Maker at all.

## What the bilateral is NOT

- **Not an ISO-NE market mechanism.** The bilateral is a private
  commercial contract. ISO-NE does not see it.
- **Not a financial derivative.** The bilateral is a payment based
  on observed quantities (Appliance Profile, Actual, LMP), not a
  derivative contract on price movements.
- **Not a baseline-and-event scheme.** Unlike FERC Order 745, there
  is no event-by-event participation decision, no baseline drift
  problem, no Net Benefits Test. The bilateral runs continuously,
  on every interval, against the exogenous Appliance Profile.
- **Not a guarantee.** The DERA's bilateral receipt depends on its
  actual load-shifting performance. If the DERA controls the
  cohort poorly (e.g., consumes during high-LMP intervals), the
  bilateral value can be negative and the DERA owes the CEP.
  This is by design — accountability to wholesale prices in all
  hours.

## Heritage

The bilateral formula is the operational realization of the TER
Participation Model described in the 2021 TER Initiative paper
(`dera-stand-up/old-market-participation-model/TER Initiative
Section 2 DRAFT.v1_4-3.pdf`). The 2021 paper proposed that the ISO
do this computation and pay the aggregator directly. Under
III.6.4(f) (effective Nov 1, 2026), the ISO settles only the CEP,
and the bilateral lives in private commercial space brokered by
the Market Maker. This is an architectural simplification, not a
departure from the 2021 model.

See [`heritage.md`](heritage.md) (Open) for the full lineage from
VCharge through the TER Initiative and the Algorand grant to the
present architecture.

## Open

- The day-ahead-vs-real-time settlement election deserves its own
  analysis. Working assumption: day-ahead. Real-time would be
  cleaner thermodynamically but harder to operationalize for
  monthly settlement.
- The admin margin number is a negotiated quantity; rough order of
  magnitude is $2-5/customer/month based on what a comparable
  flat-rate Maine CEP earns above its wholesale cost. Final number
  set per CEP partnership.
- The customer rebate share (DERA → Customer fraction of bilateral
  receipt) is a separate design decision. Working assumption: ~50%
  of net DERA receipt after operational costs. Subject to revision
  as the cohort financing model firms up.
