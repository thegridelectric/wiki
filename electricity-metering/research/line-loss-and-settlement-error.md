# Line-loss attribution and the other settlement errors against meter class

Status: Draft · Pass 0 · Updated 2026-11-21

> What this is: a research note testing one hypothesis: that revenue-grade
> meter accuracy (0.2 to 0.5% of reading) is more onerous than helpful for
> residential settlement, because distribution-loss attribution and the
> other settlement machinery introduce errors that swamp the meter's own.
> Read from the primary documents on 2026-11-21 by a research agent;
> quotes are verbatim from the sources named. Not normative.

## Verdict

The hypothesis holds on magnitude and needs one correction in framing.
For a residential home settled in ISO New England, loss-attribution and
baseline errors are 10 to 100 times the meter class, and ISO-NE's own
rule concedes it: OP-18 Appendix C allows a Demand Response Resource
metering system an overall accuracy of 2.0 where billing-quality
equipment is not used, against 0.2 for a Wh meter at a tie or generator.
The correction: the loss factor is an administrative convention, so an
aggregator is paid on the rule. The rule's error relative to physics is a
bias on average plus a per-customer, per-hour scatter that nothing in
settlement corrects. Meter accuracy is the one term the aggregator
controls, and a systematic meter bias across a fleet of one make does not
average out the way random hourly loss error does.

## How ISO-NE handles losses between the retail meter and settlement

- **Transmission losses are in the price.** Manual M-28 Rev 64 §7.2.4.6:
  "PTF Losses are accounted for via the Loss Component of the Locational
  Marginal Price."
- **Distribution losses are the utility's, folded into the Load Asset.**
  M-28 §7.2.4(3): "The quantities reported may include an adjustment for
  non-PTF losses." §7.2.4.1: customers "are normally combined with
  non-PTF losses and other customer loads in the formation of a Load
  Asset"; "they may be estimated through load profiling in accordance
  with state dictates and governing procedures." There is no ISO loss
  factor for load; the state sets it.
- **Maine's rule is MPUC Chapter 321.** §5.B.3: losses within the local
  network "will reflect, at a minimum, variation between summer and
  winter and variation among voltage levels." §4.B.1.a: profile samples
  must achieve "a 90% confidence level with plus or minus 10% error
  margin in hourly load." §9.C: utilities filed a line loss study "before
  March 1, 1999" and a revision "before March 1, 2001". The factors are
  static, two-season, by voltage level, from a periodic utility study.
  The CMP and Versant values themselves were not obtained (maine.gov and
  cmpco.com refused every fetch); a search snippet of a circa-2000 MPUC
  table shows CMP secondary energy losses of 7.52%, unverified.
- **Comparable published factors.** National Grid MA, "Supplier Load
  Estimation" (2026-03-26): "Distribution Loss Factor / Primary Voltage
  Customers / Secondary Voltage Customers / 1.038 / 1.069". Dominion
  (PJM), "Line Loss Factors" (2018-03): "Secondary Distribution Loss
  Factor 1.03973"; the factors "represent the average distribution system
  line losses."
- **Demand response gets one system-wide static factor.** Market Rule 1
  §III.3.2.1(a)(iii): the obligation is the cleared MWh "increased by
  average avoided peak distribution losses." The offer "Shall not include
  average avoided peak transmission or distribution losses in the demand
  reduction quantity." The value, ISO-NE DASI conforming-changes filing
  (2024-08-27) §D: "The ISO currently calculates distribution losses at
  5.5 percent," from the Transmission Planning Technical Guide Rev 8.1
  §2.2.1.1: "2.5% for transmission and large transformer losses, and 5.5%
  for distribution losses." The same guide §2.3.9.2: "Under off-peak load
  conditions, the amount of distribution losses are generally lower." The
  peak number is applied to every hour.

## PJM and CAISO for comparison

- **PJM**: an EDC-assigned factor per customer. Manual 11 Rev 137
  §10.5.1: "the factor for the registration shall be the registration
  load reduction weighted average of the factors for end-use customers."
  Manual 18 Rev 63 §4: reduction is "Peak Load Contribution minus (the
  metered load multiplied by the loss factor)."
- **CAISO**: the Scheduling Coordinator adjusts. BPM for Metering v24
  §6.2.1.1: "adjust the Meter Data by an estimated Distribution System
  loss factor to derive an equivalent CAISO Controlled Grid level
  measure." DMM, Demand Response Issues and Performance 2024: "In 2024,
  only distribution loss adders are included" after removing adders
  "totaling over 11 percent."

## How wrong a static loss factor is

- **The study itself.** NZ Electricity Authority, "Guidelines on the
  calculation and use of loss factors" (2018) ¶43: distributors "will
  calculate a TLR for the entire network study area within ±20%"; "if a
  TLR ... is calculated to be 5%, then the actual TLR will lie between 4
  % and 6 %." SPS 2021 Loss Study (Texas PUC docket 54634) §10:
  "Typically, the results from a loss study will be within a few
  percentage points, plus or minus, of the actual losses"; its secondary
  composite factor is 1.119737 for energy and 1.149273 for demand, a
  three-point gap between the peak and average view of the same wires.
- **Spread across utilities.** EPRI 1016097, "Distribution System Losses
  Evaluation" (2008-12) §3: "peak losses for the distribution system
  ranged from 2.79% to 6.04% and averaged 3.83%. Energy losses ranged
  from 1.71% to 7.96%." "approximately 70% of the energy losses occur
  off peak"; the loss factor (average over peak loss) "is between 20% and
  40%" against a load factor of "40% and 60%", the I² effect: loss
  percentage at peak runs about twice the annual average.
- **Hourly factors exist elsewhere.** EPRI §2 quotes SCE's hourly formula
  for service below 2 kV and ERCOT's rule to "forecast the Settlement
  Interval DLFs as a percentage of load for each Settlement Interval."
  ISO-NE and Maine do neither.
- **UK.** Sohn Associates for Ofgem (2009-03): cumulative losses
  "400/230V 7%"; "losses are related to the square of the current so are
  more significant at times of peak load." Elexon, "Annual Demand Ratio":
  the ideal is 1, "variations of +/- 1.5% are expected."

No study was found that puts a percent on static class-average against
actual hourly losses for a residential feeder. The nearest quantified
items are the NZ ±20% relative band, EPRI's two-to-one peak over average,
and the SPS energy-versus-demand gap.

## The other errors that dwarf meter class

- **Profiles and flat hours.** Maine settles on AMI interval data since
  2013 (estimates only when interval data is missing). ISO-NE then
  flat-profiles the hour: Feb 2025 filing, "the hourly revenue quality
  meter value is apportioned equally across all twelve five-minute
  intervals within the hour." Massachusetts still profiles most
  residential customers (EnergyChoiceMatters, 2026-04-23).
- **Estimated data.** M-28: "the ISO, at its discretion, may insert a
  temporary estimated meter reading". PJM M11 §10.6: interval data "shall
  at a minimum comply with the NAESB VEE (Validate, Edit & Estimate)
  standards." Market Rule 1 §III.3.6: a Requested Billing Adjustment
  needs an error "equal to or greater than the 1,000 MWh per Asset over a
  calendar month", which a residential aggregation never reaches.
- **Baseline error, residential.** Nexant for CAISO, "Baseline Accuracy
  Assessment" (2017-11) Table 3-1: the 10-of-10 baseline for residential
  AC cycling "is downwardly biased by 12% to 14% and event to event
  magnitude of errors is sufficiently large to occasionally nullify
  actual reductions"; "With 500 customers, control groups are more than
  twice as precise as day and weather matching baselines." Demand Side
  Analytics for CPUC, "Statewide Residential ELRP Baseline Evaluation"
  (2023-01) Table 29: individual-customer MPE from −30.4 (P5) to +46.1
  (P95). Mohajeryami, arXiv 1608.05117: aggregated residential NYISO
  baseline "0.2 kWh/hour accuracy MAE in NYISO is almost equal to 11%
  accuracy."
- **Unaccounted-for energy.** ERCOT 2024 UFE Analysis Report: UFE as
  percent of load 0.90% (2007), 0.26% (2022), −0.24% (2023), −0.88%
  (2024). Small system-wide, allocated to each load asset by share of
  load, hour by hour, sign flipping year to year.

## Conclusion, per home per hour, against a 0.2 to 0.5% meter

| error source | magnitude |
|---|---|
| distribution loss level at secondary voltage | 4 to 7%, study good to about ±1 point |
| static factor against the actual hour | a few points, peak about twice average |
| residential baseline, single home | 10 to 15% bias, 20%+ scatter |
| residential baseline, a few hundred homes | 5 to 10% |
| profiles and estimation where interval data is missing | percent-level |
| unaccounted-for energy | under 1% system-wide |

A heat-pump storage home draws at winter peak, when feeder losses are
highest, so a class average understates its losses when it consumes and
overstates the avoided losses when it sheds off-peak; ISO-NE's 5.5% DR
factor is a planning peak number applied to every hour. A loss factor
corrects the bias on average across the utility's class; correcting its
level moves everyone's payment together. It does not touch the
per-customer, per-hour error, single-digit percent for losses and tens of
percent for baselines. Meter error of 0.2% is below all of these by one
to two orders of magnitude, and OP-18 Appendix C encodes the judgment:
"WH Meter (3) 0.2" for billing metering against "DRR Metering systems
(4) 2.0".

The practical question for GridWorks is whether the 2.0 overall path is
open to our own metering at the Retail Delivery Point. OP-18 §V.B.8 says
it is, where the meter "will not be used for utility billing purposes."

## Not opened

All maine.gov pages and PDFs (403), the CMP load-profiles page (timeout),
the PJM 2013 M&V process deck (426), the AEMC Oakley-Greenwood profiling
report, ISO-NE M-MVDR, web.archive.org. Where a search snippet stands in
for one of these the text says so.
