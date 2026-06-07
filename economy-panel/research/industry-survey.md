Status: Draft · Pass 0 · Updated 2026-06-07

> Research note (not normative). Survey of the residential
> smart-panel and panel-level load-management industry, run
> 2026-06-07 to test the architectural and capital-structure
> gap thesis behind the Economy Panel. See
> [`../executor/primary.md`](../executor/primary.md) "Why this is
> open-source and not a startup."

## Thesis check — confirmed, with nuance

The "every smart panel is $3k+, VC-funded, firmware-as-safety"
pattern holds across all five major incumbents. NEC 2023 §220.70
+ §750.30 created a market that every player is rushing to
capture via UL 916 / UL 3141 software-certified EMS — i.e.
**firmware *is* the regulatory artifact that lets you avoid a
service upgrade.** No incumbent has shipped an independent
analog/electromechanical failsafe layer; none have published
BOM or firmware.

The capital-structure half of the thesis is also borne out: the
one founder who tried a software-light, retrofit-friendly path
(Jane Chen / Stepwise) is on a $1.4M pre-seed and partnered
with a contract manufacturer rather than vertically integrating
— so even the "lightest" entrant is still proprietary, just
smaller-scale.

## Incumbent profiles

### Stepwise
- **Product:** Stepwise Tap (launched 2024) — a smart power
  monitor that sits *between* the existing panel and a large new
  load (EV charger, heat pump, HPWH), measuring service-entrance
  amps and throttling the controllable load to stay under the
  main breaker. NOT a panel replacement. Manufactured via SoPark
  Corp partnership.
- **Constraint enforcement:** software/firmware in the Tap; no
  published analog failsafe — the main breaker itself is the
  only true backstop.
- **Funding:** $1.4M pre-seed (2023). 43North, NYU Innovation
  Venture Fund, NextFab, SBXi. No Series A reported as of 2026.
- **Jane Chen:** Wharton BS, MIT Sloan MBA. Prior venture
  **Artio** (residential EV-charger install platform). No
  EE/firmware background; no public stance on open source.

### SPAN
- **Product:** Full-replacement smart panels, 16–48 circuits,
  NEMA 3R. "PowerUp" firmware claims UL Power Control System
  (PCS) certification.
- **Pricing:** $2,550–$4,100 panel-only MSRP; $3k–$7k installed.
- **Constraint enforcement:** PowerUp firmware (proprietary).
  No independent analog failsafe disclosed.
- **Funding:** ~$419M total across 11 rounds. **$176M Series C
  closing January 2026**; **Eaton invested $75M in March 2026**.
  Pivoting hard into utility-side via "SPAN Edge" +
  Landis+Gyr partnership — i.e. doubling down on selling to
  utilities as managed DERMS, **NOT enabling resident-side
  transactive markets**.

### Lumin
- **Product:** Overlay smart-circuit controller, the Lumin Smart
  Panel, and the "Panel Guard" load-management module (early
  access Q1 2025). $2.1–2.9k hardware + $1–1.5k install.
- **Constraint enforcement:** firmware-based dynamic load
  management. Proprietary. Marketed explicitly as "avoid
  panel/service upgrades."
- **Funding:** historical investors include Energy Impact
  Partners; recent round not confirmed in the survey.

### Leviton Smart Load Center
- Complies with NEC 220.70 **only when paired with the Leviton
  Whole-Home Energy Monitor (LWHEM)** — i.e. the EMS path is
  firmware in the LWHEM + smart breakers. Standard breakers
  without LWHEM don't claim 220.70.

### Schneider Square D Energy Center
- $5–7.5k installed. UL 3141 certified. Markets explicitly to
  NEC 2026 Article 705 dynamic-capacity provisions for adding
  EV/heat-pump without service upgrade. Proprietary Wiser
  Energy app.
- Both Leviton and Schneider treat 220.70 / 750.30 / 3141 as a
  **moat**: UL certification cost is a barrier any open project
  will hit hard.

### Newer entrants
- **Savant Power Modules** — retrofit power modules that drop
  into QO/CH/1" load centers. Closest in spirit to a "layered"
  approach, but still proprietary firmware, no analog failsafe,
  no transactive hooks.
- **Koben Systems** (Schneider-backed Pulse panel) — proprietary.
- **No entrant found** with (a) open firmware, (b) explicit
  analog-failsafe layer, (c) transactive-market hooks, or (d)
  non-VC business model. **This is the gap.**

## Open-source precedents — none in the same lane

- **OpenEnergyMonitor** (emonPi2, emonTx) — circuit-level
  *monitoring* only. No control, no panel-level safety logic,
  not service-entrance rated.
- **OpenEMS** (OpenEMS e.V., Germany) — modular EMS for
  DER/storage/EV/heat-pumps + UI/backend. Closest cultural
  analog to the Economy Panel's protocol layer, but oriented to
  behind-the-meter battery + DER orchestration, not
  service-entrance overload protection, and not transactive-
  market clearing among appliances behind a panel.
- **EnergyMe-Home** (ESP32-S3, hobbyist) — 17-channel monitor.
- **Babelbee** — moribund.

**No published open-source design exists for layers (a)
electromechanical service-entrance overload protector or (c)
panel-level transactive clearing.**

## NEC 220.70 / 750.1 outside residential

Mostly commercial BMS (Schneider EcoStruxure, Siemens Desigo,
Eaton EnergyAware), utility-side DERMS (AutoGrid, EnergyHub,
Itron), and EV-charger load-management (Wallbox, ChargePoint
Power Management). None target residential service-entrance
failsafe + panel-internal market clearing.

## Strategic implication — Stepwise's struggle is the niche

The clearest read of Stepwise's trajectory: classic struggling-
pre-seed pattern. **Pre-seed in 2023, no Series A by mid-2026** —
~3 years without a follow-on round, against a typical 12–24 month
cadence. The pivot from full panel framing to the in-between
"Tap" (a monitor between the existing panel and one new load) is
product-market-fit hunting, not consolidation. Contract-
manufactured via SoPark rather than vertically integrated:
capital-light, consistent with not raising more. SPAN's $176M
Series C plus Eaton's $75M (and Eaton's distribution muscle)
hardens the moat against any sub-$10M-funded entrant.

Caveats: public funding + product-positioning signals only. No
revenue, install-count, or burn data. The pattern is consistent
with failing-but-not-yet-dead; also consistent with running lean
and surviving.

If the read is right, **the niche Stepwise was chasing —
resident-side, lighter-weight, retrofit-friendly load management
— is being abandoned by the venture-funded category** as SPAN
pivots to utility-side DERMS. That makes the Economy Panel
architecture *more* important, not less. The capital structure
is what foreclosed Stepwise's option to go open + transactive;
an open-source-first approach without VC-return pressure may be
the only way that niche actually gets filled.

This is not a criticism of Stepwise. The pattern they were
trying to fit was incompatible with the cap-table they had;
recognizing the structural incompatibility is what motivates
the Economy Panel's open-source-from-day-one posture.

## Evidence gaps

- No public pricing for Stepwise Tap.
- Lumin's recent funding round not confirmed.
- Schneider/Square D firmware architecture not disclosed in
  marketing — internal analog backstop (if any) would require
  spec-sheet deep-dive or FCC filings.
- UL 3141 listing for SPAN is self-reported in their support
  docs; not independently verified with UL.

## Source URLs

Stepwise — [getstepwise.com](https://www.getstepwise.com/) ·
[43North profile of Jane Chen](https://43north.org/charging-ahead-jane-chens-electrical-revolution-with-stepwise/) ·
[Tracxn funding](https://tracxn.com/d/companies/stepwise/__q4lzmr-Z8rf2LOczQ1sVnypVVjcBM0Qt8xL-Zymo5m8) ·
[Boston Globe – Stepwise &amp; Savant](https://www.bostonglobe.com/2024/07/09/business/stepwise-savant-ev-biden-charger-electrical-panels-jane-chen-royal-simmons/)

SPAN — [panel specs](https://support.span.io/hc/en-us/articles/4411673294743-SPAN-Panel-System-Designs-Specifications) ·
[Latitude Media – $176M Series C](https://www.latitudemedia.com/news/span-is-raising-a-176-million-series-c/) ·
[PV Magazine – Eaton $75M](https://pv-magazine-usa.com/2026/03/09/eaton-invests-75-million-in-span-to-scale-smart-home-electrical-panels/)

Lumin — [Panel Guard launch](https://www.solarpowerworldonline.com/2024/12/new-lumin-smart-panel-energy-management/) ·
[Lumin smart panel](https://www.luminsmart.com/)

Leviton — [Smart Load Center / 220.70](https://leviton.com/support/resources/product-support/decora-smart-support/leviton-load-center/smart-load-center-capabilities)

Schneider — [Square D Energy Center](https://www.se.com/us/en/product-range/131469381-square-d-energy-center-smart-panel/) ·
[OhmSnap review](https://www.ohmsnap.com/smart-panels/schneider-square-d-energy-center)

NEC — [220.70 explainer](https://filipinoengineer.com/blog/2025/07/understanding-nec-2023-section-220-70-energy-management-systems-emss.html) ·
[Mike Holt 220.70 calc PDF](https://www.mikeholt.com/files/PDF/23_CALC_220.70.pdf)

Other — [Savant Smart Panel](https://savant.com/power/smart-panel/) ·
[OpenEnergyMonitor](https://github.com/openenergymonitor) ·
[OpenEMS](https://github.com/OpenEMS/openems) ·
[EnergyMe-Home (Hackster)](https://www.hackster.io/jabrillo/energyme-home-open-source-smart-energy-meter-ea8ab7)
