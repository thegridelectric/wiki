# Polstein 14-Home Heating Decision — Problem Statement & Working Conclusions

> Research notes capturing what Matt Polstein actually needs to decide for
> his Millinocket, ME development (14 homes phase 1, eventually 100), and
> our partial conclusions about how to get him there. Not yet a built
> model; this frames the work. See
> [`../store-under-floor/research/design.md`](../store-under-floor/research/design.md)
> for the store engineering, and
> [`../store-under-floor/research/simulator-agent.md`](../store-under-floor/research/simulator-agent.md)
> for the (separate) device-fidelity simulator idea.

## Problem statement

Matt needs to make **good lifecycle-cost choices about each home's entire
heating system** — not just whether to build the store-under-floor. The
real question is a whole-system comparison under genuine cost pressure:

- **Low heating load** in these homes, so the store-under-floor's
  **+$14k incremental** (Example A in the store design doc) is *extremely*
  painful — it buys decoupled control with ~no added storage.
- **Propane** is a fallback he explicitly does **not** want.
- He is considering **resistive electric instead of a heat pump** — at
  least to start — *if* the regulatory regime gives low-cost electricity.
  (Resistive: trivial capital, COP 1; HP: high capital, COP 1.5–3.)
- He is open to **using less insulation** to save capital **if** electricity
  is cheap enough to make the higher running load tolerable.
- He wants **homeowner comfort**, so he is unlikely to accept using the
  radiant floor itself as the store (coupled slab can't run cold while
  keeping the floor warm). It may still be evaluated as a reference point.
- The likely concrete contest is a **single 119-gallon tank + radiant
  floor** vs. the **store-under-floor**.

## Working conclusions

1. **This is a multi-axis lifecycle-cost comparison**, not an A-vs-B pick:
   - heat source: {resistive, heat pump} (propane as the baseline to beat)
   - storage: {none, 119-gal tank (~16 kWh, ~$1–2k), store-under-floor A
     (~50 kWh, +$14k), store-under-floor B (~155 kWh, +$18k), coupled slab
     (~50 kWh, comfort-compromised)}
   - envelope insulation: a continuous capital-vs-load knob
   - electricity regime: flat-cheap → flat-expensive → moderate-TOU →
     aggressive-TOU/dynamic

2. **The electricity regime is the dominant, uncertain axis.** So the
   honest deliverable is a **regime-conditional breakeven map** ("what
   minimizes lifecycle cost as a function of the price world you expect"),
   not a single point recommendation. Expected shape:
   - Flat, cheap power → storage arbitrage ≈ 0, HP barely pays its capital
     → **resistive + minimal storage + less insulation likely wins**;
     Matt's instinct is correct.
   - High price and/or large TOU spread → HP efficiency + storage arbitrage
     both pay, insulation pays back → store (or at least the tank) pencils.

3. **Comfort is a constraint, not a cost line.** It rules out (or heavily
   penalizes) the coupled-slab-as-store option and bounds insulation
   reductions.

4. **The 119-gal tank vs. store-under-floor question reduces to:** is the
   extra ~35–140 kWh of storage worth the ~$12–16k capital premium over a
   tank? That is almost entirely a function of arbitrage value under the
   chosen price regime.

5. **Critical path is an analytical techno-economic model — not
   gridworks-base, not FEA.** Required pieces:
   - capital BOM per config (store BOM largely exists; need tank,
     resistive, insulation-level BOMs)
   - annual heat load = f(insulation, Maine TMY, setpoint) — degree-day or
     simple hourly RC
   - operating cost = f(load, source efficiency, storage, price trace),
     with a **perfect-foresight dispatch LP** for the storage configs —
     this gives the *upper bound* on arbitrage value and is a cheap,
     decisive screen (if a store doesn't pencil with a clairvoyant
     controller, it never will)
   - NPV over a horizon under each regime → the breakeven map

6. **gridworks-base and FEA are downstream refinements for survivors
   only.** The store-under-floor does **not** need to be a gridworks-base
   actor for Matt's decision. The gwbase transactive sim refines the
   arbitrage number (real forward-looking control vs perfect foresight);
   FEA produces trustworthy transient `Q(SOC, LWT, OAT)` curves. Both
   matter only once a config survives the analytical screen and needs
   operating-cost accuracy. The store design doc's own "Do we still need
   FEA?" section agrees: no for procurement sizing, yes eventually for the
   operating-cost simulator.

## AWHP market trajectory, R290, and rollout timing

> **Hypothesis from Jessica — needs research to validate.** Provenance: market
> read, not yet sourced. Flagged here because it bears directly on the
> HP-vs-resistive axis above and on *when* Matt commits to a heat source.

- **Air-to-water heat pumps (AWHP) are still a niche product in the US**, so they
  carry a niche-product price premium today. This is part of why "HP" sits as the
  high-capital option in the multi-axis comparison above — the capital number is
  inflated by an immature US market, not just by the technology.
- **Likely refrigerant transition to R290 (propane).** Globally, AWHP is moving
  toward R290 (low-GWP, driven by F-gas / refrigerant-phasedown regulation). The
  hypothesis is the US market follows. **To validate:** the global R290 trend and
  its US timeline; whether the in-envelope candidates in
  [`../heat-pumps/hp-curve.md`](../heat-pumps/hp-curve.md) (Mitsubishi PUZ-HWM,
  Arctic 060) are R32 or R290 and their roadmaps; R290 install constraints
  (flammable-refrigerant charge limits, siting) for a monoblock feeding the store.
- **Timing question (the decision-relevant part):** Matt installs **14 homes in
  phase 1, eventually ~100.** Will US AWHP prices fall — as the market matures and
  R290 scales — **before he installs the remaining ~86 homes?** Implications:
  1. The HP-vs-resistive answer may **differ between phase 1 and later phases**:
     resistive (or a cheaper interim) now, HP later once prices drop.
  2. The lifecycle-cost model should treat **HP capital cost as time-varying /
     phase-dependent**, not a single fixed number — a price-decline curve is its
     own scenario axis, alongside the electricity-regime axis.
  3. It may argue for **designing the hydronics HP-ready now** (so a later
     swap-in is cheap) even if phase 1 ships with resistive.

## Open inputs needed before building the model

- **Config shortlist** — which heat-source × storage × insulation
  combinations to model (~8–12).
- **Electricity regimes** — 3–5 concrete price scenarios (flat ¢/kWh
  levels + TOU schedules), or a Maine ISO-NE / utility tariff to anchor.
- **NPV horizon + discount rate** (15 / 20 / 30 yr?).
- **Comfort spec** — design-day setpoint maintenance (have 21 °C / −30 °C
  OAT / 5 kW from the store design doc).
- **Load-model fidelity** — per-house design load + degree-day annual
  energy for v1, or hourly?

## Status / next action

Not yet built. **Transcribe the John Siegenthaler / Matt Polstein Zoom call
first** — John's input most directly shapes the config shortlist and the
comfort/insulation constraints (the model's inputs), so feeding it in before
scaffolding avoids hard-coding assumptions. In parallel, Matt/Jessica to
supply the electricity regimes and NPV horizon. Then scaffold the analytical
comparison (capital BOM + load model + perfect-foresight dispatch LP + NPV)
— proposed home: a new `heating-economics/` sibling, or alongside the
existing `engine/cost.py` referenced by the store design doc.
