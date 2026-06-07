Status: Draft · Pass 0 · Updated 2026-06-06

> What this is: the money flow through the Economy Energy Markets
> architecture, who pays whom, when, and a worked numerical example.
> See [`actors.md`](actors.md) for the role definitions and
> [`bilateral.md`](bilateral.md) for the structural pattern.

## The five money flows

The architecture has five recurring money flows, each on a defined
cadence:

1. **Customer → CEP** — flat-rate retail bill, monthly. Standard
   Maine CEP / Versant billing channel.
2. **CEP → ISO-NE** — wholesale settlement at LMP × Actual,
   following ISO-NE's standard settlement cadence (final monthly
   reconciliation; daily provisional). The Actual quantity comes
   from the Meter Reader's AMR submission per III.6.4(f).
3. **CEP → DERA via Market Maker** — the bilateral payment,
   monthly. The Market Maker computes `(Appliance Profile − Actual)
   × LMP`, summed per customer per interval, subtracts the CEP's
   fixed administrative margin, and routes the remainder to the
   DERA.
4. **DERA → Customer** — rebate, monthly. The customer receives a
   separate payment (NOT a bill credit on the CEP statement) from
   the DERA, calculated as a defined share of the bilateral receipt
   attributable to that customer.
5. **DERA → fixed-cost partners** — Meter Reader service fee,
   Market Maker transaction fee, TA-Validator install + recheck
   fees, infrastructure costs, green-bank debt service. All
   internal economics, monthly or as triggered.

Five flows, all monthly, all auditable, all separable.

## The books-clear argument

The ISO-NE settlement engine sees a vanilla CEP being settled at
LMP × Actual using interval data submitted by the AMR. Generators
get paid LMP × Generation. Loads pay LMP × Actual via their
suppliers. The market clears as if no DERA exists; from ISO-NE's
ledger, the cohort looks like any other interval-settled CEP.

The bilateral payment is entirely outside ISO-NE settlement. It
is a private commercial transfer between the CEP and the DERA,
brokered by the Market Maker. It does NOT require ISO-NE to do
anything new on the settlement side. It does NOT require Versant
to do anything beyond the III.6.4(e) confirmation letter.

This is the architectural simplification that III.6.4(f) buys us.
In the 2021 TER Initiative model, the ISO had to compute the
inc/dec value and pay the aggregator directly — a regulatory ask.
Under III.6.4(f), the ISO settles only the CEP, and the bilateral
lives in private commercial space.

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
- Actual usage by the DERA-controlled heat-pump-WITH-storage:
  shifted to the cheap night block. Roughly 80% / 5% / 10% / 5%
  across the four blocks. So 16 kWh × those fractions = 12.8 / 0.8
  / 1.6 / 0.8 kWh in each block.
- Customer flat retail rate: $0.16/kWh (illustrative).
- CEP fixed administrative margin: $3/month per customer
  (illustrative).

### Per-block math

For each block, the bilateral value =
`(Profile_kWh − Actual_kWh) × LMP / 1000`:

| Block | Profile (kWh) | Actual (kWh) | LMP ($/MWh) | Bilateral ($) |
| --- | ---: | ---: | ---: | ---: |
| midnight–6 AM | 1.6 | 12.8 | 5  | (1.6 − 12.8) × 5 / 1000 = −0.056 |
| 6 AM–noon | 4.8 | 0.8 | 60 | (4.8 − 0.8) × 60 / 1000 = +0.240 |
| noon–6 PM | 4.0 | 1.6 | 45 | (4.0 − 1.6) × 45 / 1000 = +0.108 |
| 6 PM–midnight | 5.6 | 0.8 | 80 | (5.6 − 0.8) × 80 / 1000 = +0.384 |

Daily total bilateral value: −0.056 + 0.240 + 0.108 + 0.384 =
**$0.676** for this single customer on this day.

### Whose money is whose

For this day, for this customer:

- **ISO-NE side:** CEP pays for 16 kWh actual, weighted by interval
  LMPs:
  `12.8 × 5 + 0.8 × 60 + 1.6 × 45 + 0.8 × 80 = 64 + 48 + 72 + 64 = $248 / 1000 = $0.248`.
  CEP wholesale cost = **$0.248** for the day.
- **Customer side:** flat retail $0.16/kWh × 16 kWh = **$2.56** for
  the day.
- **CEP gross margin (before bilateral):** $2.56 − $0.248 =
  **$2.312** for the day.
- **Equivalent profile cost (what CEP would have paid under
  profile-shape consumption):**
  `1.6 × 5 + 4.8 × 60 + 4.0 × 45 + 5.6 × 80 = 8 + 288 + 180 + 448 = $924 / 1000 = $0.924`.
- **Sanity check:** profile cost − actual cost = $0.924 − $0.248
  = $0.676, exactly equal to the bilateral total computed
  block-by-block above. The two ways of computing the
  load-shifting value agree, as they must.
- **CEP's "earned-margin" reference:** if the CEP had served a
  customer consuming on the profile, its margin would have been
  $2.56 − $0.924 = $1.636. That is the CEP's profile-shape
  reference margin.
- **Bilateral routes the delta:** the CEP's actual margin ($2.312)
  exceeds its reference margin ($1.636) by exactly the bilateral
  value ($0.676). The Market Maker routes this delta from the CEP
  to the DERA.
- **CEP's net margin after bilateral:** $1.636 (back to the
  reference) plus the agreed fixed administrative margin (negotiated
  separately and prorated daily; illustratively $3/month ÷ 30 ≈
  $0.10/day).
- **DERA receipt:** $0.676 − $0.10 (the CEP's daily share of the
  fixed admin margin) ≈ **$0.576** for the day.
- **Customer rebate share of DERA receipt:** a defined fraction
  (e.g., 50% — TBD per the DERA's cohort contract) of the bilateral
  value would flow back to the customer as a rebate; the rest funds
  DERA operations, Meter Reader fees, Market Maker fees, TA-Validator
  fees, green-bank debt service, and DERA margin. Illustratively the
  customer rebate share for this day: **$0.288**.

### Annual scale

A residential heat-pump-thermal-storage customer in Maine consumes
something on the order of 6,000–8,000 kWh/year for heating. If
their per-day bilateral value averages on the order of $0.50/day
during the 200-day heating season, that's **~$100/year of
bilateral value per customer**. The customer rebate share at 50%
is ~$50/year. The DERA's share funds the operational stack.

A 100-home cohort generates ~$10,000/year of bilateral value at
this scale. A 10,000-home regional buildout generates ~$1M/year.

These numbers are illustrative, not committed. The actual values
depend on Maine's LMP curve shape, the realized cohort's controlled
load, and the negotiated rebate share. Updated worked examples will
live in `appliance-profile.md` once that spoke is written.

## What's NOT in the value flow

- **No socialization to a slush fund.** Under standard profiled
  settlement (without III.6.4(f)), the load-shifting value would
  land in the ISO-NE Metering Domain residual and be socialized
  across all retail suppliers in the metering domain. Under
  III.6.4(f) with the CEP settled at LMP × Actual, no such residual
  is generated — the value flows directly to the bilateral
  computation.
- **No federal subsidy.** Unlike FERC Order 745, the bilateral does
  not depend on a Net Benefits Test or any subsidized payment from
  outside the wholesale market mechanism. The market clears with no
  hidden cross-subsidy.
- **No payment to GridWorks for value the DERA didn't create.** The
  DERA gets paid only for the load-shifting it actually performs,
  measured against an exogenous Appliance Profile. The Customer
  Baseline Load gaming problem of FERC 745 cannot occur here — the
  reference is exogenous to the DERA's control.

## Operational cadences

- **Daily:** Meter Reader submits interval data to ISO-NE per the
  III.6.4(f) timing SLA. Meter Reader submits parallel interval
  data to the Market Maker.
- **Monthly:** Market Maker computes the bilateral. CEP routes
  payment to the DERA via Market Maker. DERA routes rebate to
  customer.
- **Quarterly / triggered:** TA-Validator performs randomized
  re-checks on a sample of enrolled homes.
- **Annually:** Appliance Profile updated for the next settlement
  year. Heritage publication of all bilateral records (open-source
  / transparency commitment).
