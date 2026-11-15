# ISO-NE real-time dispatch and the five-minute price

Status: Draft · Pass 0 · Updated 2026-11-15

> What this is: how ISO New England's real-time dispatch instruction
> reaches a resource, whether any resource follows the published price,
> and when the five-minute LMP exists relative to the interval it
> prices, from the Tariff, Market Rule 1 and OP-14 as read 2026-11-15.
> It settles what a price-responsive load like ours is, in ISO terms,
> and what it is not. Copies of the sources are in `sources/`.

## Why this matters to GridWorks

Our MarketMaker's real-time hourly price is the hour's first five-minute
LMP at the Keene Rd node, which ISO-NE posts about 25 s into the hour
(23.5 s at two boundaries measured 2026-11-15; the running log is
`scratch/isone-posting-latency.csv` in the umbrella). Whether that lag
puts our houses behind the generators depends on what the generators
are actually following. They are following a MW setpoint computed
before the interval; the price is the same calculation's shadow,
published afterwards. No ISO-NE resource is waiting on the public
price. Our houses, clearing on it, are doing something ISO-NE's own
mechanisms do not offer.

## The instruction is a MW setpoint

The Desired Dispatch Point is the signal. Tariff Section I.2.2,
"Desired Dispatch Point":

> "Desired Dispatch Point (DDP) means the control signal, expressed in
> megawatts, transmitted to direct the output, consumption, or demand
> reduction level of each Generator Asset, Dispatchable Asset Related
> Demand, Demand Response Resource, or Demand Response Distributed
> Energy Resource Aggregation"

It is sent electronically to the Designated Entity's ISO-connected
remote terminal unit every five minutes or less. OP-14 Rev 37, §II.F.2.a
(generators; the same wording is at §IV.F.2.a for DARDs and §VI.F.2.a
for demand response):

> "Normal Dispatch Instructions shall be transmitted electronically to
> each DE every five minutes or less, depending on system conditions."

OP-14 §II.C.3: "ISO shall communicate with the DE via electronic
dispatch through an ISO connected RTU or voice communications through
an automatic ringdown telephone circuit". §II.C.7 lists what the DE's
console must show: "ACK Required … Message Type … Desired Dispatch
Point (DDP) … Actual Generation … Economic Minimum Limit … Economic
Maximum Limit … Response Rate … Heartbeat". No price is on the list,
nor on the DARD list (§IV.C) or the demand response list (§VI.C).

A normal instruction needs no acknowledgement. OP-14 §II.F.2.b:

> "Manual acknowledgement of a normal Dispatch Instruction is not
> required; however, compliance with the Dispatch Instruction shall be
> in accordance with Offer Data without delay."

Continuous storage is the exception, with a four-second setpoint. OP-14
§VII.C.3: "ISO shall transmit Dispatch Instructions (in the form of a MW
setpoint) to each DE every four seconds or less." Market Rule 1
§III.1.10.6(c)(viii) gives the combined signal: "a combined dispatch
control signal equal to the Desired Dispatch Point (of the Generator
Asset) minus the Desired Dispatch Point (of the DARD) plus the AGC
SetPoint (of the ATRR)."

The computing system is UDS, the Unit Dispatch System (Tariff I.2.2:
"UDS is unit dispatch system software"), ISO-NE's security-constrained
economic dispatch. ISO-NE's 2024 training deck "Locational Marginal
Pricing" (iwem-02), Economic Dispatch slide: "Runs approximately every
10 minutes • Re-optimizes generation to meet load at minimum cost •
Results in desired dispatch points (DDP) in megawatts (MW) • Calculates
LMPs at each generator node". The deck's "10 minutes" disagrees with
OP-14's "five minutes or less"; OP-14 is binding.

## The price signal existed and was removed

Until at least 2016 the Tariff defined a Dispatch Rate in dollars. From
the Section I.2.2 definitions in ISO-NE's 2016-10-12 filing
(ER17-68-000):

> "Dispatch Rate means the control signal, expressed in dollars per MWh
> and/or megawatts, calculated and transmitted to direct the output,
> consumption or demand reduction level of each generating Resource,
> Dispatchable Asset Related Demand and Demand Response Resource"

and "Desired Dispatch Point (DDP) is the Dispatch Rate expressed in
megawatts." Manual M-11 Rev 48 (2014-12-03) §2.2.8: "The ISO's Unit
Dispatch Software (UDS) calculates Dispatch Rates (both Desired
Dispatch Points, in MW and a rate in $/MW)". The term appears nowhere
in the current Tariff Section I, Market Rule 1 §§III.1–III.12 or OP-14
Rev 37. The filing that removed it, and how an asset was expected to
use the dollar part while it existed, are open (see below).

## No resource self-dispatches against the published price

- **Generators and DARDs** may Self-Schedule, which fixes a commitment;
  above it the ISO dispatches on the offer. Market Rule 1 §III.1.10.3:
  "A Generator Asset that is online as a result of a Self-Schedule will
  be dispatched above its Economic Minimum Limit based on the economic
  merit of its Supply Offer." §III.1.11.3 makes dispatchability the
  rule: "With the exception of Settlement Only Resources, Settlement
  Only Distributed Energy Resource Aggregations, and Generator Assets
  that meet the size criteria to be Settlement Only Resources, External
  Transactions, and nuclear-powered Resources, all Resources must be
  Dispatchable Resources".
- **Demand response resources** cannot self-schedule. §III.1.10.3: "A
  Demand Response Resource or a Demand Response Distributed Energy
  Resource Aggregation shall not be Self-Scheduled."
- **Electric storage** registers as a dispatchable generator plus a
  DARD (§III.1.10.6(a)); a Continuous Storage Facility must be
  Self-Scheduled (§III.1.10.6(c)(vii)) and then follows the four-second
  setpoint.
- **Settlement Only Resources**, "generators of less than 5 MW of
  maximum net output … that have elected Settlement Only Resource
  treatment" (Tariff I.2.2), take no instruction. Nothing found
  describes them as responding to price.
- **ISO-NE's Price-Responsive Demand** is not PJM's. The PRD project
  page: "Project Implemented: 6/1/18 … Introduced the DRR desired
  dispatch point (DDP), which is a request to reduce consumption by a
  specified megawatt amount below the megawatt level of expected
  consumption during the dispatch interval", and it "Prohibited DRRs
  from self-scheduling load reductions that occur as a part of normal
  business operations". The older Real-Time Price Response Program
  (Market Rule 1 Appendix E, cited in the 2011 Order 745 filing
  ER11-4336) is gone from the current rule.

## When the five-minute price exists

Market Rule 1 §III.2.3: "by using the power flow solution produced by
the State Estimator for the pricing interval … the ISO shall obtain a
State Estimator solution every five minutes". §III.2.5(b): "the
calculation set forth in this Section III.2.5 shall be performed for
every five-minute interval, using the ISO's Locational Marginal Price
program, producing a set of nodal Real-Time Prices based on system
conditions during the pricing interval."

M-11 Rev 48 (2014) §2.2.8 drew the line explicitly: "Dispatch Rates and
Real-Time Reserve Designations are calculated ex-ante for use in
Real-Time dispatch. Real-Time Prices, adjusted Real-Time Reserve
Designations based on actual conditions and Real-Time Reserve Clearing
Prices are calculated on an ex-post basis". In 2015 ISO-NE replaced
the LMP Calculator; FERC's letter order in ER15-1238-000 (2015-04-17)
accepts a change "that will ensure that dispatch rates and real-time
energy market prices are more closely aligned." The current rule uses
neither "ex ante" nor "ex post".

Publication. Market Rule 1 §III.2.9A(a): "The ISO normally will post
provisional Real-Time Prices, Real-Time Reserve Clearing Prices and
Regulation clearing prices in Real-Time or soon thereafter." Final
prices may take up to five business days. The ISO Express report
"Preliminary Real-Time Five-Minute LMPs": "The time listed in each row
indicates the start of the interval; for example, 9:15 indicates that
the LMPs are effective from 9:15 until the next time new LMPs are
published. Current data are made available in approximate real-time."
The Web Services API v1.1 page for `/fiveminutelmp/current/all` says
only "Get the current Five Minute LMPs for all locations." No posting
lag is documented anywhere found.

## Open

- The ER15-1238 filing itself (not the letter order): is today's
  five-minute price ex ante from the dispatch solve or ex post from the
  State Estimator, and how are the two "aligned"?
- The filing that removed the Dispatch Rate from the Tariff, and what
  the dollar signal was for while it existed.
- Whether a Settlement Only Resource or an unregistered load has any
  standing to follow the published price, and what our houses are in
  ISO terms (DARD, DRR, DER aggregation under Order 2222, or outside
  the market behind the Versant meter).
- The posting lag over a day and across market conditions: the running
  log in `scratch/isone-posting-latency.csv`.

## Sources

Read 2026-11-15; copies in `sources/`.

- [Tariff Section I (definitions)](https://www.iso-ne.com/static-assets/documents/regulatory/tariff/sect_1/sect_i.pdf) `sources/sect_i.pdf`
- [Market Rule 1 §§III.1–III.12](https://www.iso-ne.com/static-assets/documents/2014/12/mr1_sec_1_12.pdf) `sources/mr1_sec_1_12.pdf`
- [OP-14 Rev 37, Technical Requirements for Assets and Resources](https://iso-ne.com/op14) `sources/op14.pdf`
- [M-11 Rev 48 (2014)](https://www.iso-ne.com/static-assets/documents/2014/12/m_11_market_operations_revision_48_12_03_14.doc) `sources/m11_rev48.doc`; [M-11 Rev 62 (current)](https://www.iso-ne.com/static-assets/documents/100020/m_11_revision_62_effective_02_28_25.pdf)
- [ER17-68-000 filing (2016)](https://www.iso-ne.com/static-assets/documents/2016/10/er17-68-000.pdf) `sources/er17-68.pdf`
- [ER15-1238-000 FERC letter order (2015)](https://www.iso-ne.com/static-assets/documents/2015/04/er15-1238-000_4-17-15_ltr_order_accepting_lmp_calculator_rev.pdf) `sources/er15-1238-000_4-17-15_ltr_order_accepting_lmp_calculator_rev.pdf`
- Training 2024-09-24: [Unit Commitment and Dispatch](https://www.iso-ne.com/static-assets/documents/100016/20240924-iwem-01-unit-commitment-and-dispatch.pdf), [Locational Marginal Pricing](https://www.iso-ne.com/static-assets/documents/100016/20240924-iwem-02-locational-marginal-pricing.pdf) `sources/20240924-iwem-0*.pdf`
- [Preliminary five-minute LMPs report](https://www.iso-ne.com/isoexpress/web/reports/pricing/-/tree/lmps-rt-five-minute-prelim)
- [Web Services API: /fiveminutelmp/current/all](https://webservices.iso-ne.com/docs/v1.1/rest.fiveminutelmp.current.all.html)
- [PRD project page](https://www.iso-ne.com/participate/support/customer-readiness-outlook/prd-project)
- [ER11-4336 Order 745 filing (2011)](https://www.iso-ne.com/static-assets/documents/regulatory/ferc/filings/2011/aug/er11_4336_000_prd_filing.pdf) `sources/prd2011.pdf`
