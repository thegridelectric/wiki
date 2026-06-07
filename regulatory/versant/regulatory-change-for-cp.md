Status: Draft · Pass 0 · Updated 2026-05-30

> What this is: research notes on the **policy ask of expanding
> Versant Bangor Hydro Rate D-4's Coincident-Peak (CP) transmission
> demand election to include *thermal storage*** (not just
> separately-metered Electric Vehicle Charging and Battery Storage
> devices). The CP-vs-NCP question is decision-significant for the
> Knifes Edge HaaS economics; under the default NCP, transmission
> demand is unavoidable by TOU shifting and effectively kills the
> economic case (see
> [`scenarios/boe-delivery.md`](scenarios/boe-delivery.md)).
> Companion docs: [`versant.md`](versant.md) (the tariff
> baseline), [`todd-griset.md`](todd-griset.md) (the legal
> ecosystem).

## The policy ask

The Versant BHD consolidated tariff (Rate D-4, p. 20.1.1) restricts
the optional Coincident Peak transmission election ("DC Fast
Charging and Storage Eco option") to:

> *"separately metered Electric Vehicle Charging and/or Battery
> Storage devices."*

The plain-language reading — and confirmed by the tariff-reading
agent — is that "Battery Storage" means **electrochemical**
storage. **Thermal storage does not qualify** as currently written.
This is the load-bearing technical constraint:

- NCP (default): transmission demand billed on the customer's *own*
  monthly max 15-min in any TOU period. Cannot be reduced by TOU
  shifting.
- CP (election, currently restricted): transmission demand billed
  on the customer's 60-min load *coincident with* BHD's monthly
  system peak. A controllable thermal-storage HOA can predict and
  avoid that hour → ~0 transmission demand for the thermal load.

The ask: **expand the eligible-technology list to include thermal
storage** when configured as controllable load on a controllable
heat pump.

## Why this matters

For a 100-home HaaS HOA on Rate D-4 at 500 kW peak demand:

- NCP transmission demand: 500 kW × $17.41 = **$8,705 / month**
  during heating season = **~$52,200 / year HOA** (~$522 / home).
- CP transmission demand if thermal storage qualified and we
  successfully avoid the BHD coincident-peak hour: **near zero**.

So the policy change is worth roughly **$50k+/year HOA** for the
phase-1 100-home cluster, and proportionally more at full
300-home scale. Across the Maine residential heat-pump fleet
(Efficiency Maine targets 38,000 heat-pump homes by 2028) the
aggregate annual value is much larger.

## Precedent — has any state done this?

The agent's precedent scan:

- **California — CPUC D.09-08-027 (2009)** included **thermal
  energy storage** (ice-storage AC systems) in demand-response
  programs. PG&E's Permanent Load Shifting and Ice Bear are the
  canonical implementations. ([CPUC D.09-08-027](https://docs.cpuc.ca.gov/PUBLISHED/FINAL_DECISION/106008-24.htm))
- **Vermont — Green Mountain Power Rate 9 Critical Peak Pricing**
  is **technology-neutral**: any load shifted off the critical-peak
  hours qualifies, without enumerating eligible technologies.
  Thermal storage qualifies by default. ([GMP Rate 9](https://greenmountainpower.com/rates/))
- **Massachusetts — National Grid ConnectedSolutions** pays
  $200/kW for dispatchable load reduction but the enrolled-asset
  list is **battery + EV only** — thermal storage explicitly not
  enrolled. ([National Grid CS](https://www.nationalgridus.com/MA-Business/Energy-Saving-Programs/ConnectedSolutions))
- **New York — NYSERDA VDER + retail storage incentives** are
  battery / electrochemical only.

**Pattern:** the named-list form Versant uses is the Northeast
norm. The technology-neutral form (Vermont) and the explicit
thermal-storage enumeration (California) are the precedents
Maine could borrow.

## Maine policy alignment — unusually favorable

The Maine PUC already has the legal authority to do this.

**Relevant Maine policy.**

- **LD 528 / P.L. 2021 ch. 298** *directs the Maine PUC to
  investigate transmission and distribution rate designs accounting
  for energy storage* — energy storage broadly, not battery-only.
  Cited in MPUC's 2024 Annual Report.
  ([MPUC 2024 Annual Report](https://www.maine.gov/mpuc/sites/maine.gov.mpuc/files/inline-files/2024%20Annual%20Report%20Final_0.pdf))
- **Efficiency Maine's FY26–28 Beneficial Electrification Plan**
  targets **38,000 heat-pump homes** by 2028; storage-aware
  rate design directly supports the goal.
  ([EMT BE Plan, Jan 2025](https://www.efficiencymaine.com/docs/EMT_Beneficial-Electrification_Planning_Report_01_2025.pdf))
- **MPUC Docket 2024-00137** (stranded-cost rate design, order
  Apr 30 2025) shows the Commission is actively reshaping class
  rate design — receptive to new structures, not locked in.

## Advocacy path

Cleanest vehicle: either

1. **A Versant rate-case filing** in BHD's next general rate case,
   amending Rate D-4 to broaden the CP-election eligible-technology
   list; or
2. **A stand-alone MPUC petition** filed under existing LD 528
   authority asking for a rulemaking on storage-aware rate design.



### Likely coalition

- **Efficiency Maine Trust** — technical depth, BE-Plan
  alignment, would speak credibly to the heat-pump-fleet aggregate
  value.
- **Maine Office of the Public Advocate (OPA)** — rate-design
  perspective; consumer-cost-shift framing.
- **Industrial Energy Consumer Group (IECG)** — Tony Buxton and
  Todd Griset at Preti Flaherty routinely intervene in Versant
  rate cases; cost-shift-vigilance posture aligns *with* this ask
  (because storage-load-shifted away from coincident peak literally
  *reduces* the cost burden on other ratepayers).
- **NRCM, Sierra Club, Acadia Center** — environmental /
  beneficial-electrification framing.
- **Building electrification coalition** — installers, contractors,
  HP-distributors.
