Status: Draft · Pass 0 · Updated 2026-05-30

> What this is: notes on **Maine LD 2112** — the Community Choice
> Aggregation (CCA) statute enacted April 13, 2026 — and why **it
> is not the right tool** for the transactive-storage cohort
> use-case explored elsewhere in heating-system-design. Captured
> for completeness; the CCA mechanism is relevant to other Maine
> energy-supply substitution stories but does not apply to the
> narrow self-selected storage-cohort case.

## What LD 2112 does

- Signed into law **2026-04-13** by Gov. Mills (LD 2112 / HP 1427
  of the 132nd Legislature).
- Makes Maine the **11th CCA state** (after MA, CA, NY, IL, NJ, OH,
  RI, NH, VA, MD).
- Authorizes Maine **municipalities** to form a **Community Choice
  Aggregator (CCA)** that **procures bulk electricity supply** on
  behalf of residents and small commercial customers within the
  municipal boundaries.
- Enrollment model: **opt-out** — residents are enrolled by default
  and may opt out individually.
- Supply only — delivery continues to be provided by the IOU; the
  IOU continues to read meters as AMR.
- Implementation rulemaking is **pending at MPUC** — no rule has
  been adopted yet.

Sources:
[Maine LD 2112 / HP 1427](https://legislature.maine.gov/legis/bills/getPDF.asp?paper=HP1427&item=3&snum=132),
[pv-magazine 2026-04-28](https://pv-magazine-usa.com/2026/04/28/maine-becomes-the-11th-state-to-allow-community-choice-aggregation/).

## Why it's the wrong tool for transactive-storage

CCA's opt-out enrollment is a **feature** for broad-base supply
substitution (where most customers benefit from cheaper bulk
procurement of the same product). It is a **bug** for transactive-
storage aggregation:

1. **Only storage-equipped customers can capture the value.** The
   DERA value-capture mechanism — the **Cleared Market** operated
   by the GridWorks Market Maker, where the CEP brings its
   profile-shape position and the LTNs bring per-asset
   actual-delivery positions, with the customer rebate funded out
   of the TaAggregator's share — only generates surplus from
   customers whose load can actually be shifted. Forcing a
   non-storage customer into the cohort produces no
   storage-shifting and no rebate; they'd be no better off than on
   Standard Offer and arguably worse if the cohort's CEP charges a
   slightly higher flat rate to cover the cohort's administrative
   overhead.
2. **Rate A-1 already provides the eligibility filter.** The bonus
   meter + sized-storage-device requirement self-selects exactly
   the cohort that benefits from Cleared Market participation.
3. **Cohort coherence matters operationally.** Diluting a
   storage-controlled cohort with non-controllable customers
   degrades the wholesale market signal and the
   capacity-market-participation case.
4. **The structural fit is wrong.** CCA is municipal-scope (whole
   town, all residents). Transactive-storage cohorts are
   technology-scope (those who invested in storage).

So **the transactive-storage cohort is opt-in by design**, run
through a CEP (Efficiency Maine or partner) under existing
Chapter 305 authority — not through a CCA.

## When LD 2112 *would* matter

- Statewide / municipal energy-supply substitution programs
  (cheaper bulk procurement of Standard Offer-equivalent product).
- Local clean-energy procurement preferences (Brookfield
  hydropower offtake by Millinocket residents, for example).
- Renewable-energy carve-outs that benefit from default enrollment.

These are unrelated to the heating-system-design / transactive-load
story.

## Open follow-ups

- **MPUC implementation rulemaking timeline.** When can the first
  Maine municipality actually form a CCA?
- **Millinocket as a potential CCA?** Matt Polstein's Town Council
  seat could move a CCA petition, but only if the broader town
  energy-supply story justifies it — independent from the Knifes
  Edge project.
- **Interaction with the transactive-storage cohort.** Would a
  Millinocket-wide CCA conflict with the campus interval-settlement
  structure? Probably no — the CCA contracts for the *default*
  supply; the storage-cohort opts into the EM-as-CEP arrangement
  instead. Worth confirming once both structures are concrete.
