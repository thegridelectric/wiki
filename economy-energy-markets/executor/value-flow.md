Status: Draft · Pass 0 · Updated 2026-06-06

> What this is: the money flow through the Economy Energy Market
> System architecture, who pays whom, when, and a worked numerical
> example. See [`actors.md`](actors.md) for the role definitions and
> [`cleared-market.md`](cleared-market.md) (Open) for the structural
> clearing pattern.

## The five money flows

The architecture has five recurring money flows, each on a defined
cadence:

1. **Customer → CEP** — flat-rate retail bill, monthly. Standard
   Maine CEP / Versant billing channel.
2. **CEP → ISO-NE** — wholesale settlement at LMP × Actual,
   following ISO-NE's standard settlement cadence (final monthly
   reconciliation; daily provisional). The Actual quantity comes
   from the TaReader's AMR submission per III.6.4(f). The Cleared
   Market on the GridWorks side uses a matching 2-stage cadence
   (see below) so the two settlements align.
3. **CEP → TaAggregator via Market Maker** — Cleared Market
   payment, monthly. The Market Maker computes the load-shifting
   value `(Appliance Profile − Actual) × LMP`, summed per LTN per
   interval across all CEP-side shape-dependent products (energy,
   FCM CP, RPS), subtracts the CEP's fixed administrative margin,
   and routes the remainder to the TaAggregator.
4. **TaAggregator → Customer** — Customer Rebate, monthly. The
   customer receives a separate payment (NOT a bill credit on the
   CEP statement) from the TaAggregator, calculated as a defined
   share of the Cleared Market receipt attributable to that
   customer's LTN.
5. **TaAggregator → fixed-cost partners** — TaReader service fees,
   Market Maker transaction fees, TaValidator install + recheck
   fees, infrastructure costs, green-bank debt service,
   TaAggregator margin. All internal economics, monthly or as
   triggered.

Five flows, all monthly, all auditable, all separable.

## The books-clear argument

The ISO-NE settlement engine sees the CEP being settled at LMP ×
Actual using interval data submitted by the TaReader as agent-AMR.
Generators get paid LMP × Generation. Loads pay LMP × Actual via
their suppliers. The market clears as if no Cleared Market exists;
from ISO-NE's ledger, the CEP looks like any other interval-settled
supplier.

The Cleared Market lives **outside** ISO-NE settlement. It is a
private commercial venue that clears CEP profile-shape positions
against LTN actual-delivery positions. ISO-NE does not see it; it
is not part of FERC-jurisdictional wholesale settlement.

This is the architectural simplification III.6.4(f) buys us. In the
2021 TER Initiative model, the ISO had to compute the inc/dec value
and pay the aggregator directly — a regulatory ask. Under
III.6.4(f), the ISO settles only the CEP, and the Cleared Market
lives in private commercial space.

## The structural guarantee

The clearing mechanics give the CEP a defined structural exposure:

> **The CEP's net wholesale cost equals LMP × Profile.**

The CEP pays LMP × Actual to ISO-NE (via the AMR submission). It
also pays (or receives) LMP × (Profile − Actual) via the Market
Maker. The sum of those two cash positions is exactly LMP ×
Profile, independent of actual cohort load shape. The Market Maker
structurally absorbs the Actual-vs-Profile delta.

The CEP's only Profile-shape risk is the LMP series itself (which
the mission-aligned supply partner hedges) and the total monthly
kWh forecast (predictable from heating-degree-day analysis). The
CEP carries no Actual-shape risk; the LTNs are exposed to that, and
that exposure is what creates the load-shifting value the Cleared
Market routes to them.

## Worked example: one customer, one cold day

A simplified example for intuition. The settlement engine works
the same way at scale.

### Inputs

- One customer, with a heat-pump thermal storage system using 16
  kWh of electricity over a single day.
- The day has 24 hourly intervals. For clarity we collapse to four
  6-hour blocks: midnight–6 AM, 6 AM–noon, noon–6 PM, 6 PM–midnight.
- LMPs (illustrative Maine zonal prices on a windy winter night):

  | Block | LMP ($/MWh) |
  | --- | --- |
  | midnight–6 AM | 5 |
  | 6 AM–noon | 60 |
  | noon–6 PM | 45 |
  | 6 PM–midnight | 80 |

- Appliance Profile for a typical heat-pump-WITHOUT-storage in this
  customer's county-month: morning-and-evening peak shape, roughly
  10% / 30% / 25% / 35% across the four blocks. So 16 kWh × those
  fractions = 1.6 / 4.8 / 4.0 / 5.6 kWh in each block.
- Actual usage by the LTN-managed heat-pump-WITH-storage:
  shifted to the cheap night block. Roughly 80% / 5% / 10% / 5%
  across the four blocks. So 16 kWh × those fractions = 12.8 / 0.8
  / 1.6 / 0.8 kWh in each block.
- Customer flat retail rate: $0.16/kWh (illustrative).
- CEP fixed administrative margin: $3/month per customer
  (illustrative).

### Per-block math

For each block, the Cleared Market value =
`(Profile_kWh − Actual_kWh) × LMP / 1000`:

| Block | Profile (kWh) | Actual (kWh) | LMP ($/MWh) | Cleared value ($) |
| --- | ---: | ---: | ---: | ---: |
| midnight–6 AM | 1.6 | 12.8 | 5  | (1.6 − 12.8) × 5 / 1000 = −0.056 |
| 6 AM–noon | 4.8 | 0.8 | 60 | (4.8 − 0.8) × 60 / 1000 = +0.240 |
| noon–6 PM | 4.0 | 1.6 | 45 | (4.0 − 1.6) × 45 / 1000 = +0.108 |
| 6 PM–midnight | 5.6 | 0.8 | 80 | (5.6 − 0.8) × 80 / 1000 = +0.384 |

Daily total Cleared Market value: −0.056 + 0.240 + 0.108 + 0.384 =
**$0.676** for this single customer on this day.

### Whose money is whose

For this day, for this customer:

- **ISO-NE side:** CEP pays for 16 kWh actual, weighted by interval
  LMPs:
  `12.8 × 5 + 0.8 × 60 + 1.6 × 45 + 0.8 × 80 = 64 + 48 + 72 + 64 = $248 / 1000 = $0.248`.
  CEP wholesale cost (paid to ISO) = **$0.248** for the day.
- **Customer side:** flat retail $0.16/kWh × 16 kWh = **$2.56** for
  the day.
- **CEP gross retail margin (before clearing):** $2.56 − $0.248 =
  **$2.312** for the day.
- **Equivalent profile cost (what CEP would have paid under
  profile-shape consumption):**
  `1.6 × 5 + 4.8 × 60 + 4.0 × 45 + 5.6 × 80 = 8 + 288 + 180 + 448 = $924 / 1000 = $0.924`.
- **Sanity check:** profile cost − actual cost = $0.924 − $0.248
  = $0.676, exactly equal to the Cleared Market value computed
  block-by-block above. The two ways of computing the load-shifting
  value agree, as they must.
- **CEP's profile-shape reference margin:** if the CEP had served a
  customer consuming on the profile, its margin would have been
  $2.56 − $0.924 = $1.636. That is the CEP's structurally-guaranteed
  reference margin.
- **The Cleared Market routes the delta:** the CEP's actual retail
  margin ($2.312) exceeds its reference margin ($1.636) by exactly
  the Cleared Market value ($0.676). The Market Maker routes this
  delta from the CEP to the LTN (collected by the TaAggregator).
- **CEP's net margin after clearing:** $1.636 (back to the
  reference) plus the daily share of the fixed administrative margin
  (illustratively $3/month ÷ 30 ≈ $0.10/day) = **$1.736** for the
  day. This is the structural guarantee in action — the CEP's
  exposure is exactly LMP × Profile (with retail rate − Profile
  cost as margin), plus the agreed administrative margin.
- **TaAggregator receipt:** $0.676 − $0.10 (the CEP's daily share
  of the fixed admin margin) ≈ **$0.576** for the day.
- **Customer Rebate share of TaAggregator receipt:** a defined
  fraction (e.g., 50% — TBD per the TaAggregator's SLA policy) of
  the value flows back to the customer as a Customer Rebate; the
  rest funds TaAggregator operations, TaReader fees, Market Maker
  fees, TaValidator fees, green-bank debt service, and TaAggregator
  margin. Illustratively the Customer Rebate share for this day:
  **$0.288**.

### Annual scale

A residential heat-pump-thermal-storage customer in Maine consumes
something on the order of 6,000–8,000 kWh/year for heating. If
their per-day Cleared Market value averages on the order of
$0.50/day during the 200-day heating season, that's **~$100/year of
Cleared Market value per customer**. The Customer Rebate share at
50% is ~$50/year. The TaAggregator's share funds the operational
stack.

A 100-customer TaAggregator generates ~$10,000/year of Cleared
Market value at this scale. A 10,000-customer regional buildout
generates ~$1M/year.

These numbers are illustrative, not committed. The actual values
depend on Maine's LMP curve shape, the realized cohort's controlled
load, and the negotiated Customer Rebate share. Updated worked
examples will live in [`appliance-profile.md`](appliance-profile.md)
once that spoke is written.

## What's NOT in the value flow

- **No socialization to a slush fund.** Under standard profiled
  settlement (without III.6.4(f)), the load-shifting value would
  land in the ISO-NE Metering Domain residual and be socialized
  across all retail suppliers in the metering domain. Under
  III.6.4(f) with the CEP settled at LMP × Actual, no such residual
  is generated — the value flows directly to the Cleared Market.
- **No federal subsidy.** Unlike FERC Order 745, the Cleared Market
  does not depend on a Net Benefits Test or any subsidized payment
  from outside the wholesale market mechanism. The market clears
  with no hidden cross-subsidy.
- **No payment to GridWorks for value the LTNs didn't create.** The
  LTNs (and through them, the TaAggregator) get paid only for the
  load-shifting actually performed, measured against an exogenous
  Appliance Profile. The Customer Baseline Load gaming problem of
  FERC 745 cannot occur here — the reference is exogenous to LTN
  control.

## Two-stage Cleared Market settlement

The Cleared Market settles in two stages on the GridWorks side,
mirroring the ISO-NE provisional/final cadence:

- **Stage 1 — hourly forward clearing.** Each hour the Market
  Maker clears LTN actual-delivery positions against a CEP-side
  profile counterparty bid. The profile bid quantity is
  `Appliance Profile × Forecast Total Cohort Usage` for the day,
  where the forecast is the CEP's day-ahead heating-degree-day
  forecast of total cohort kWh. This produces a provisional
  daily Cleared Market net.
- **Stage 2 — daily true-up.** Once the 24h actual total cohort
  usage is known (typically next-day from the TaReader's
  interval data), the profile bid quantity is recomputed using
  the realized total, and the Cleared Market net for that day
  is trued up. The delta between the provisional and true-up
  net is small (it's only the cohort-total forecast error, not
  per-asset shape error).
- **Monthly settlement.** The Cleared Market net for the month
  is the sum of trued-up daily nets. This is what flows from
  CEP to TaAggregator (flow 3 above).

Why 2-stage rather than after-the-fact-only clearing: LTNs need
an hourly price signal to bid against — that's how they decide
when to charge thermal storage. After-the-fact-only clearing
loses the price signal. Why 2-stage rather than hourly-only
clearing: the profile bid depends on total cohort usage, which
isn't fully known until end-of-day, so an hourly bid is
necessarily provisional.

Forecast risk is isolated in exactly one place — the CEP's
day-ahead total-kWh forecast for the cohort. This is the easiest
risk in the architecture; heating-degree-day analysis is
well-understood and forecast error converges to ~0 over a
settlement month.

A dedicated `settlement-cadence.md` spoke will formalize this
once the core spokes are seeded.

## Operational cadences

- **Every interval (5- or 15-minute):** TaReader reads enrolled
  meters, generates auditable interval records, submits to ISO-NE
  per the III.6.4(f) timing SLA, submits parallel data to the
  Market Maker.
- **Hourly:** Market Maker accepts LTN per-asset bids and the
  CEP-defined profile counterparty bid; clears provisionally
  against forecast total cohort usage.
- **Daily:** Cleared Market trued up against realized total
  cohort usage.
- **Monthly:** Trued-up daily nets summed; CEP routes payment to
  TaAggregator. TaAggregator routes Customer Rebates.
  TaAggregator pays operational fees.
- **Quarterly / triggered:** TaValidator performs randomized
  re-verifications of enrolled assets AND independent audits of
  the TaReader's data integrity.
- **Annually:** Appliance Profile updated for the next settlement
  year. Publication of clearing records (open-source / transparency
  commitment).
