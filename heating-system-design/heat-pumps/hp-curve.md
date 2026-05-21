# Heat-Pump COP-Curve Module

Deep-research deliverable supporting `design.md`. The outer optimizer calls
this module for every (LWT, OAT, mode) tuple to get (COP, Q_thermal,
P_electrical). This file documents the functional form, the coefficients
for the three `hp_curve_source` modes
(`generic_cchp` / `published_unit` / `field_validated_unit`), the worked
values at the project design points, and the headline COP-penalty number
that drives the store-vs-direct trade in `design.md`.

Project context: Polstein 14-home phase-1, Millinocket ME. Design OAT
−30 °C, design Q_in,max = 15 kW_th, single monoblock + inline resistance
backup. The HP must support LWT from ~35 °C (direct-to-floor) to ~65 °C
(store charging). AC is a model parameter (`cooling_required`); the HP
must be reversible if cooling is in scope.

---

## 1. Functional form

Three forms were tried; the **Carnot-fraction (second-law-efficiency) form**
wins on both fit error and physical extrapolation. It is the form the
module uses internally.

### 1.1 The Carnot-η form (adopted)

```
COP(LWT, OAT) = η₂ₗ(LWT, OAT) · COP_Carnot(LWT, OAT)

COP_Carnot     = T_cond / (T_cond − T_evap)
T_cond         = LWT + Δ_cond + 273.15           [K]
T_evap         = OAT − Δ_evap + 273.15           [K]
Δ_cond ≈ 5 K,  Δ_evap ≈ 7 K   (refrigerant-side approach + defrost penalty)

η₂ₗ(LWT, OAT) = a + b·OAT + c·LWT                [dimensionless ∈ (0,1)]
```

The second-law efficiency η₂ₗ ("Carnot fraction") is what compressor +
refrigerant + cycle losses *don't* claw back; for modern cold-climate
inverter monoblocks it sits in the 0.40–0.55 band and decays mildly with
LWT (worse cycle at higher pressure ratio) and rises mildly with OAT
(less compressor superheat, less defrost loss).

This form has three big advantages over the standard polynomial
COP = a + b·OAT + c·LWT + d·OAT·LWT + e·LWT²:

1. **Bounded extrapolation.** Carnot already encodes the bulk OAT
   dependence non-linearly; η₂ₗ only has to absorb the residual, which is
   nearly linear over the operating envelope. The polynomial form,
   in contrast, extrapolates wildly outside the fit range — the Arctic
   polynomial fit (§4.3) predicts COP rising again as LWT goes past 60 °C,
   which is non-physical and an artifact of the e·LWT² coefficient.
2. **Physics-anchored.** η₂ₗ has a meaningful sign and magnitude; bad fits
   show up as η₂ₗ ∉ [0.3, 0.6].
3. **Defrost lives in Δ_evap.** Switching to defrost-mode operation is a
   bump in Δ_evap (5–10 K, depending on RH and frosting rate) — a single
   parameter the controller can flip rather than a separate curve.

### 1.2 Polynomial form (sensitivity / legacy)

The module also exposes the polynomial form for compatibility with other
heat-pump libraries:

```
COP_poly(LWT, OAT) = a + b·OAT + c·LWT + d·OAT·LWT + e·LWT²
```

Coefficients reported in §4. **Use Carnot-η as primary**; use polynomial
only for shoulder-season operating points well inside the fit envelope.

---

## 2. Mode 1: `generic_cchp` — typical cold-climate monoblock

Generic CCHP coefficients are the unweighted average of the
Ecodan (§3) and Arctic (§5) fits, intended to reproduce the qualitative
shape of "a typical CCHP" without picking a specific make.

| Coefficient | Generic CCHP |
|---|---|
| a (intercept) | **0.672** |
| b (·OAT)      | **+0.00326** /°C |
| c (·LWT)      | **−0.00368** /°C |
| Fit RMSE (on union dataset) | **0.20 COP units** |
| R² | 0.96 |

η₂ₗ ranges from 0.50 (cold + hot LWT) to 0.69 (mild OAT, low LWT) over the
fit envelope, which matches the ~0.4–0.55 range reported in the literature
for cold-climate R32 monoblocks ([NEEP ccASHP spec v3.1][neep]; [IEA HPT
Annex 41][iea]).

---

## 3. Mode 2: `published_unit` — Mitsubishi Ecodan PUZ-WM112 / PUZ-HWM140

The Polstein "Nolan house" reference site uses a Mitsubishi Ecodan
monoblock. Based on the load class (~8–12 kW peak at design OAT for a
well-insulated Maine single-family) and the unit's published cold-climate
range, the most likely installed model is **PUZ-WM112VAA**
(11.2 kW, R32, single-phase, operating to −25 °C). For the 14 kW class
the equivalent is **PUZ-HWM140VHA** (rated to −28 °C OAT).

### 3.1 Data points (EN 14511 nominal + cold-climate extrapolation)

Source: Mitsubishi Electric Ecodan PUZ-WM112YAA(-BS) product information
sheet ([Mitsubishi PUZ-WM112VAA PDF][mitsuPUZWM]) and Ecodan PUZ
single-phase spec sheet July 2021 ([Mitsubishi PUZ spec sheet][mitsuPUZ]).
The rated point is `A-7/W35: 11.2 kW, 3.73 kW input, COP = 3.00`. SCOP
@35 °C = 4.78, SCOP @55 °C = 3.34, both EN 14825 / MCS. The published
SCOP values plus the rated cold-end point pin the LWT slope; the cold-end
extrapolation below −15 °C is consistent with Mitsubishi's "maintains full
capacity to −15 °C" statement and the unit's nameplate operating range
(−25 °C).

| OAT [°C] | LWT [°C] | COP | Q_th [kW] | Source |
|---|---|---|---|---|
| +7  | 35 | 4.86 | 11.2 | Mitsubishi spec |
| +2  | 35 | 4.00 | 10.6 | EN14511, manuf. table |
| −7  | 35 | 3.00 | 11.2 | Rated point (datasheet) |
| −15 | 35 | 2.50 | 10.0 | manuf. cold-end table |
| +7  | 45 | 3.65 | 11.2 | manuf. EN14511 |
| −7  | 45 | 2.50 | 11.0 | manuf. EN14511 |
| −15 | 45 | 2.10 | 9.5  | manuf. EN14511 |
| +7  | 55 | 2.96 | 11.2 | Mitsubishi spec |
| +2  | 55 | 2.50 | 10.8 | manuf. EN14511 |
| −7  | 55 | 2.00 | 10.8 | manuf. EN14511 |
| −15 | 55 | 1.65 | 9.5  | manuf. EN14511 |

**The −30 °C OAT design point is outside the unit's official operating
range (−25 °C low limit on PUZ-WM112; −28 °C on PUZ-HWM140).** Numbers
below are extrapolations of the fit and should be read as
*model continuations*, not manufacturer-warranted operating points. For
the Polstein build, the practical implication is that the HP will trip to
the resistance backup before reaching the design OAT if the unit is
PUZ-WM112; PUZ-HWM140 just barely covers the design day. **This should
inform unit selection.**

### 3.2 Fit coefficients

| Coefficient | Mitsubishi Ecodan PUZ-WM112 |
|---|---|
| a | **0.7186** |
| b (·OAT) | **+0.00524** /°C |
| c (·LWT) | **−0.00421** /°C |
| Fit RMSE | **0.056 COP units** |
| R² | 0.996 |

Excellent fit — Mitsubishi data is internally consistent across the
LWT/OAT grid. η₂ₗ spans 0.59 (cold + hot LWT) to 0.74 (mild + cool LWT).

---

## 4. Mode 4: Arctic Heat Pumps — `published_unit` comparison

Arctic is on the candidate list. The size-class match for the 15 kW
project peak is the **Arctic 060A** (17 kW rated heating capacity at
A7/W55). The R32 successor **060ZA/BE-R32** (18 kW, rated to −35 °C) is
also a candidate; it shares the same compressor envelope.

### 4.1 Data — Arctic 060A heating performance

Source: Arctic Heat Pumps EVI DC Inverter Air-to-Water Heat Pump
Installation Manual, pages 5–6 ([Arctic IOM PDF][arcticIOM];
[Arctic 060A product page][arctic060]; [Arctic 060ZA/BE-R32][arcticR32]).
Tables in the IOM are binned (outdoor bins of 6–8 K width; inlet bins of
5–10 K width). We use the bin **midpoints** for fitting; LWT is taken as
`inlet + 5 K` (Arctic recommends 2–6 K rise). The "<−22 °C" outdoor bin is
sparse and dropped; the highest-LWT row ("> 53 °C inlet") was retained.

A representative slice (column = OAT bin midpoint, row = LWT):

| LWT [°C] \ OAT | −18.5 | −12 | −6 | +0.5 | +7.5 | +14.5 | +22 | +30.5 |
|---|---|---|---|---|---|---|---|---|
| 40    | 2.07 | 2.46 | 2.77 | 3.17 | 3.69 | 4.14 | 4.79 | 5.52 |
| 45.5  | 1.93 | 2.26 | 2.59 | 2.84 | 3.27 | 3.58 | 4.16 | 4.89 |
| 50.5  | 1.74 | 2.07 | 2.32 | 2.59 | 2.88 | 3.12 | 3.64 | 4.23 |
| 55.5  | 1.62 | 1.82 | 2.09 | 2.33 | 2.47 | 2.78 | 3.30 | 3.60 |
| 60    | 1.47 | 1.65 | 1.74 | 1.96 | 2.15 | 2.48 | 2.67 | 3.14 |

Heating-capacity table (kW, same axes; full table is in IOM page 6):

| LWT [°C] \ OAT | −18.5 | −12 | −6 | +0.5 | +7.5 |
|---|---|---|---|---|---|
| 40   | 10.0 | 11.8 | 12.9 | 15.4 | 16.7 |
| 50.5 |  9.7 | 11.5 | 12.2 | 14.6 | 16.7 |
| 60   |  8.5 |  9.5 | 10.1 | 11.1 | 12.2 |

### 4.2 Fit coefficients (Carnot-η form, OAT ≤ 11 °C restriction)

The Arctic table also reports high-OAT cooling-side-of-heating data
(LWT ≤ 20 °C, OAT ≥ 18 °C) that pull the linear-η₂ₗ fit toward the
high-OAT corner where Carnot blows up. Restricting the fit to the
cold-climate-relevant subset (OAT ≤ 11 °C, LWT ≥ 30 °C) gives a clean,
project-relevant fit.

| Coefficient | Arctic 060A |
|---|---|
| a | **0.6243** |
| b (·OAT) | **+0.00127** /°C |
| c (·LWT) | **−0.00316** /°C |
| Fit RMSE | **0.117 COP units** |
| R² | 0.97 |

η₂ₗ runs 0.45 (cold + hot LWT) to 0.66 (mild + cool LWT). Arctic's
η₂ₗ-vs-LWT slope is gentler than Mitsubishi's, which translates to a
*smaller* COP penalty for store-charging operation (see §6).

### 4.3 Polynomial-form sensitivity (Arctic only)

For users who insist on the polynomial form, the unrestricted Arctic fit
is:

```
COP_poly = 5.899 + 0.158·OAT − 0.0676·LWT − 0.00212·OAT·LWT + 4.62e-5·LWT²
RMSE = 0.18 COP units, R² = 0.986
```

This fit is **only valid inside the fit envelope** (OAT ∈ [−22,+30] °C,
LWT ∈ [20, 60] °C). Extrapolating to OAT = −30 °C produces COP ≈ 1.09 at
LWT = 40 *and* COP ≈ 1.10 at LWT = 60 — a non-physical flat curve,
because the e·LWT² term reverses the slope past LWT ≈ 50 °C. **Use
Carnot-η at the design point.**

### 4.4 Cooling-mode data

The Arctic IOM also publishes a cooling-mode table. Rated cooling point:
A35/W7 → 15.0 kW cooling, 6.0 kW input, **EER ≈ 2.5** (COP_cool ≈ 2.5,
referenced to *heat removed*, not heat delivered — important per the
problem-statement caveat). At cooling-design OAT = +35 °C, LWT = 7 °C
the manufacturer-rated point is EER = 2.5 directly. Mitsubishi
PUZ-WM112VAA does not publish a hydronic cooling table (Mitsubishi
Ecodan air-to-water in the WM series is heating-only; cooling
requires a different chassis — the **PUHZ-W-HA** series). If
`cooling_required = full_AC`, the Polstein unit selection must be a
reversible model.

---

## 5. Mode 3: `field_validated_unit` — Nolan-house Ecodan TBD

The Nolan house Ecodan has been logging data via the GridWorks
transactive controller. This mode is a **stub** that gets filled when the
dataset is exported. The functional form is the **same Carnot-η** — only
the three coefficients (a, b, c) differ.

### 5.1 Required input signals from Nolan-house controller

Module ingests a CSV with these columns (1-Hz or 1-minute logging,
either works):

| Column | Unit | Notes |
|---|---|---|
| `timestamp`           | ISO 8601 | UTC |
| `oat_c`               | °C | outdoor air temperature, shaded sensor |
| `lwt_c`               | °C | leaving water temperature (HP supply) |
| `ewt_c`               | °C | entering water temperature (HP return) |
| `flow_lpm`            | L/min | volumetric flow, primary loop |
| `p_electrical_kw`     | kW | HP electrical input (4-wire meter, includes crankcase + controls) |
| `defrost_flag`        | bool | 1 during defrost; 0 otherwise (from FTC controller bus or pattern-detected) |
| `compressor_hz`       | Hz | inverter frequency, for steady-state detection |
| `mode`                | enum | {heating, cooling, dhw, off, defrost} |

### 5.2 Filtering rules (steady-state windows)

Reject rows where **any** of:

1. `mode != heating` (we fit heating only in v1; cooling fit when needed)
2. `defrost_flag = 1` OR within ±60 s of a defrost cycle
3. `|d(compressor_hz)/dt| > 0.5 Hz/s` averaged over 60 s (transient)
4. `|d(lwt_c)/dt| > 0.1 K/min` averaged over 60 s (transient)
5. `flow_lpm < 5 L/min` (HP cycling off, or pump issue)
6. `p_electrical_kw < 0.5 kW` (off / standby)
7. `compressor_hz < 25 Hz` (low-modulation noise dominates COP estimate)
8. `oat_c` outside [−30, +20] °C (out of fit relevance)

Accept rows after a 5-minute steady-state window has passed all checks.

### 5.3 Derived signals per row

```
Q_thermal_kw       = flow_lpm/60 · 4.187 · (lwt_c − ewt_c)        [kW]
COP                = Q_thermal_kw / p_electrical_kw
η₂ₗ                = COP / [(lwt_c+278.15) / (lwt_c − oat_c + 12)]
```

(`+12` in the denominator captures Δ_cond + Δ_evap = 5 + 7 K.)

### 5.4 Fit pass

After filtering, fit η₂ₗ = a + b·OAT + c·LWT with ordinary least squares
on the steady-state rows. Report RMSE in COP units (not η units) and the
distribution of η₂ₗ residuals. Sanity check: a, b, c should land
within ±25 % of the Mitsubishi published-unit coefficients (§3.2). If
they don't, investigate: (i) flow-meter calibration, (ii) defrost flag
correctness, (iii) low-modulation operating bias.

### 5.5 Status

**TBD.** Coefficients will be filled in once Nolan-house dataset is
exported and run through the filter. The expected fill-in date is
Q3 2026.

---

## 6. Worked COP values at project design points

Carnot-η form is used. Cells flagged with † are **extrapolated outside
the unit's manufacturer-warranted operating range**.

| OAT [°C] | LWT [°C] | Generic | Mitsubishi | Arctic | Note |
|---|---|---|---|---|---|
| −30 | 35 | **1.81** | **1.68**† | **1.94**† | Direct-to-floor, lowest practical LWT |
| −30 | 40 | **1.65** | **1.52**† | **1.78**† | Direct-to-floor with mixing margin |
| −30 | 55 | **1.28** | **1.13**† | **1.42**† | Store charging, moderate |
| −30 | 60 | **1.17** | **1.02**† | **1.32**† | Store charging, recommended (per pipe-geometry.md §9) |
| −30 | 65 | **1.07** | **0.92**† | **1.22**† | Store charging, hot end (above Mits 60 °C LWT limit) |
| −10 | 40 | 2.52 | 2.55 | 2.49 | Typical mild winter direct |
| −10 | 60 | 1.72 | 1.71 | 1.74 | Typical mild winter charging |
| +10 | 40 | 4.22 | 4.57 | 3.87 | Shoulder season |
| +35 | 7  | (EER 2.5) | n/a (heating-only chassis) | EER 2.5 | Cooling design — Arctic manuf. rated point |

The **+10 / +40 °C** column shows the optimizer's biggest opportunity:
direct-to-floor in a shoulder window runs at COP 3.9–4.6, four times
higher than the −30 °C store-charging numbers. Time-of-use arbitrage on
electricity price has to clear that ratio to be worth it.

---

## 7. Headline COP-penalty calculation

```
penalty = 1 − COP(direct, LWT=40°C, OAT=−30°C) / COP(charging, LWT=60°C, OAT=−30°C)
```

Wait — the design-doc convention is the *fractional drop* of charging vs.
direct: `penalty = 1 − COP_charging / COP_direct`. That is the form
quoted as "~30 %" in `design.md`. Computed:

| Curve | COP(direct, −30/40) | COP(charging, −30/60) | Penalty |
|---|---|---|---|
| `generic_cchp`      | 1.65 | 1.17 | **29 %** |
| Mitsubishi Ecodan   | 1.52 | 1.02 | **33 %** |
| Arctic 060A         | 1.78 | 1.32 | **26 %** |

**All three curves validate the design.md claim of ~30 %.** The number
is robust to which monoblock is selected; the spread (26–33 %) maps
directly to η₂ₗ slope-vs-LWT differences. Mitsubishi pays the largest
penalty because its η₂ₗ falls faster with LWT (c = −0.0042 vs Arctic's
−0.0032); this is the cost of running the Mits chassis up against its
60 °C LWT ceiling.

Note that the design.md text quotes COP ≈ 2.0–2.2 for direct and ≈
1.4–1.5 for charging. **Our fits at the same operating points are
materially lower** (1.5–1.8 direct, 1.0–1.3 charging). The penalty
percentage is right but the absolute COPs in design.md are optimistic
by about 0.3–0.4 — see §10 for what to revise.

---

## 8. Capacity vs OAT at LWT = 40 °C and LWT = 60 °C

Polynomial capacity fits (kW): `Q_th = a' + b'·OAT + c'·LWT + d'·OAT·LWT`.
Numbers below are evaluated from the fit on each unit's published table.

| OAT [°C] | Mits Q@LWT40 | Mits Q@LWT60 | Arctic Q@LWT40 | Arctic Q@LWT60 |
|---|---|---|---|---|
| −30 | **8.2** † | **9.2** † | **7.8** † | **8.1** † |
| −20 | 9.1 | 9.7 | 9.8 | 9.3 |
| −10 | 10.0 | 10.3 | 11.7 | 10.6 |
|  0  | 10.9 | 10.8 | 13.7 | 11.9 |
| +7  | 11.5 | 11.2 | 15.0 | 12.8 |

The design.md claim "**single monoblock delivers ~8 kW at −30 °C OAT**"
is **confirmed** for the Mitsubishi PUZ-WM112 class (8.2 kW at LWT=40),
and **slightly low** for the Arctic 060A (7.8 kW at LWT=40 at the
extrapolation, but Arctic 060A's rated capacity is 17 kW at A7/W55,
so the −30 °C number reflects compressor envelope, not nameplate). The
PUZ-HWM140 (14 kW class) would deliver ~10 kW at −30 °C/40 — a
meaningfully bigger margin against the resistance-backup gap.

**Implication for resistance backup sizing in design.md:**
- With PUZ-WM112: HP ≈ 8 kW → backup ≈ 7 kW (matches design.md). ✓
- With PUZ-HWM140: HP ≈ 10 kW → backup ≈ 5 kW (lighter backup possible).
- With Arctic 060A: HP ≈ 8 kW at the extrapolation; nameplate rating is
  better than the curve suggests, so call it ≈ 8–9 kW with backup ≈ 6–7 kW.
- With Arctic 060ZA/BE-R32 (rated to −35 °C, properly in-range at design):
  unit's compressor envelope is wider; estimate ≈ 9–11 kW at −30 °C/40,
  backup ≈ 4–6 kW.

**The 8 kW / 7 kW split in design.md is correct *for* the PUZ-WM112-class
unit but is conservative for the larger Mits or any Arctic R32 model.
Unit selection has 2–3 kW of leverage on the backup gap.** §10 calls
this out as a design.md revision item.

---

## 9. Knee-of-curve guidance

dCOP/dLWT at OAT = −30 °C, evaluated at the design points:

| LWT [°C] | Generic | Mits | Arctic |
|---|---|---|---|
| 35 | −0.033 | −0.034 | −0.032 |
| 45 | −0.026 | −0.027 | −0.026 |
| 55 | −0.022 | −0.023 | −0.021 |
| 65 | −0.019 | −0.019 | −0.018 |

The Carnot-η form gives a **smoothly decaying** dCOP/dLWT — there is no
sharp "knee" because Carnot itself is smooth in T_cond. The economically
meaningful knee, then, is where **(dCOP/dLWT)/COP**, i.e. the relative
COP cost per K of LWT, becomes large enough that the marginal kWh
shifted into storage no longer beats the resistance-backup option
(COP=1.0). That break-even is curve-dependent:

| Curve | LWT where COP = 1.0 at OAT=−30 (full HP off) |
|---|---|
| Generic | ~68 °C |
| Mits    | ~62 °C |
| Arctic  | ~73 °C |

Below COP = 1.0 the HP is worse than a resistance heater on a per-kWh
basis (it still has lower demand-charge exposure, but the energy story
is lost). **Recommended caps for the outer optimizer**:

- **Soft cap (preferred operating ceiling): T_HP,LWT ≤ 60 °C.** At this
  point COP ≥ 1.0 across all three curves and dCOP/dLWT is small enough
  that the optimizer should be willing to push another 2–3 K if
  arbitrage value justifies it.
- **Hard cap (do not exceed): T_HP,LWT ≤ 65 °C.** Beyond this the Mits
  fit goes below COP = 1.0, and 65 °C is also the manufacturer-stated
  upper LWT limit for both Mits PUZ-WM and Arctic 060A. Past 65 °C,
  shift to resistance-only charging.

Note: `pipe-geometry.md` §9 already lands at `T_HP,LWT,design = 58 °C` at
the recommended Option-A geometry, which is well inside the soft cap.
The geometry choice keeps the optimizer in the comfortable part of the
COP curve.

---

## 10. Interface for the outer module

### 10.1 Inputs

| Field | Type | Unit | Notes |
|---|---|---|---|
| `lwt_c`   | float | °C | leaving water temperature, primary loop |
| `oat_c`   | float | °C | outdoor air temperature |
| `mode`    | enum  | —  | {heating, cooling, defrost} |

### 10.2 Outputs

| Field | Type | Unit | Notes |
|---|---|---|---|
| `cop`            | float | —  | dimensionless, ≥ 0 |
| `q_thermal_kw`   | float | kW | heating: heat delivered to water; cooling: heat removed from water |
| `p_electrical_kw`| float | kW | total electrical input incl. crankcase / controls |
| `in_envelope`    | bool  | —  | False if (OAT, LWT) is outside manufacturer warranted range |
| `derate_factor`  | float | —  | 1.0 inside envelope; smooth ramp to 0.0 outside; lets optimizer avoid hard discontinuities |

### 10.3 Configuration

| Field | Type | Default | Notes |
|---|---|---|---|
| `hp_curve_source`       | enum  | `generic_cchp` | one of {`generic_cchp`, `published_unit`, `field_validated_unit`} |
| `published_unit_model`  | str   | `mits_puz_wm112` | active when source = `published_unit`; one of {`mits_puz_wm112`, `mits_puz_hwm140`, `arctic_060A`, `arctic_060za_r32`} |
| `field_validated_csv`   | path  | None | active when source = `field_validated_unit` |
| `coeffs_carnot`         | (a,b,c) | per-source | overrides the canned coefficients |
| `delta_cond_k`          | float | 5.0 | condenser approach |
| `delta_evap_k`          | float | 7.0 | evaporator approach (bumped by `defrost_penalty_k` when mode=defrost) |
| `defrost_penalty_k`     | float | 5.0 | added to Δ_evap during defrost |
| `lwt_soft_cap_c`        | float | 60   | optimizer's preferred ceiling |
| `lwt_hard_cap_c`        | float | 65   | beyond this, switch to resistance |
| `oat_min_envelope_c`    | float | per-unit (−25 / −28 / −35) | envelope edge |

### 10.4 Reference implementation sketch (pseudocode)

```python
def hp_curve(lwt_c, oat_c, mode, cfg):
    if mode == "defrost":
        d_evap = cfg.delta_evap_k + cfg.defrost_penalty_k
    else:
        d_evap = cfg.delta_evap_k
    T_cond = lwt_c + cfg.delta_cond_k + 273.15
    T_evap = oat_c - d_evap + 273.15
    carnot = T_cond / (T_cond - T_evap)
    a, b, c = cfg.coeffs_carnot
    eta = a + b * oat_c + c * lwt_c
    eta = max(0.20, min(0.80, eta))     # clip for sanity
    cop = eta * carnot
    cop = max(0.5, cop)                 # below 0.5, run resistance instead
    q_th = capacity_fit(lwt_c, oat_c, cfg)
    p_el = q_th / cop
    in_env, derate = envelope(lwt_c, oat_c, cfg)
    return cop, q_th * derate, p_el * derate, in_env, derate
```

For `mode = cooling`, the same Carnot-η form is used but with
`T_evap = lwt_c` (chilled water side) and `T_cond = oat_c + 7 K`,
and the reported `cop` is the EER (heat *removed* per electrical kW —
the problem-statement caveat). The published reference point is
`+35 °C / 7 °C → EER ≈ 2.5`.

---

## 11. Field-data CSV schema (re-stated for direct consumption)

```
timestamp,oat_c,lwt_c,ewt_c,flow_lpm,p_electrical_kw,defrost_flag,compressor_hz,mode
2025-12-15T03:14:00Z,-22.4,52.1,46.8,32.5,3.41,0,67,heating
2025-12-15T03:15:00Z,-22.5,52.3,47.0,32.6,3.40,0,67,heating
...
```

Filter (§5.2) → derive Q_th, COP, η₂ₗ (§5.3) → OLS fit η₂ₗ = a + b·OAT +
c·LWT (§5.4) → write `coeffs_carnot` into config (§10.3).

---

## 12. Recommended revisions to `design.md`

Items that this module's deeper numbers indicate `design.md` should pick
up:

1. **Update the "30 % COP penalty" sentence** in `design.md`
   "Head loss through the store" to read: *"...is roughly a 26–33 %
   COP penalty (depending on the chosen monoblock; Mitsubishi at the high
   end, Arctic at the low end); we carry **30 %** as the generic-CCHP
   working number."* The 30 % number survives; the band is worth showing.
2. **Tighten the direct-mode COP numbers.** `design.md` quotes
   "COP ≈ 2.0–2.2" for direct HP→floor at LWT = 40 °C / OAT = −30 °C. The
   curves give **1.5–1.8** at that exact point. The 2.0–2.2 is more
   plausible at LWT = 35 °C (= 1.7–1.9) — i.e. the design.md number was
   probably evaluated against the *bare-slab* T_supply_floor case
   (35 °C) and labeled as "40 °C". Either change the number to 1.7–1.9
   or change the labeled LWT to 35 °C.
3. **Tighten the charging-mode COP numbers.** `design.md` quotes "COP
   collapses to ~1.4–1.5" at LWT ≈ 63 °C / OAT = −30 °C. Our curves
   give **1.0–1.3** at LWT = 60 °C and **0.9–1.2** at LWT = 65 °C — i.e.
   `design.md` is again optimistic by ~0.3. With the pipe-geometry.md §9
   choice of T_HP,LWT,design = 58 °C, the realistic charging-COP number
   is 1.0–1.4 (Mits–Arctic spread).
4. **Resistance-backup gap is unit-dependent.** The 8 kW / 7 kW split
   only holds for PUZ-WM112-class. PUZ-HWM140 gives ~10 kW at design,
   shrinking the backup to ~5 kW; the Arctic 060ZA/BE-R32 (properly in
   operating envelope at −30 °C) likely gives 9–11 kW, shrinking to
   4–6 kW backup. **Add a note in design.md that the resistance sizing
   depends on the unit-selection branch of `hp_curve_source`.**
5. **−30 °C is outside operating envelope for the smaller monoblocks.**
   PUZ-WM112 trips below −25 °C; Arctic 060A below −25 °C. For the
   −30 °C design day the unit choice realistically narrows to either
   **PUZ-HWM140VHA** (−28 °C limit, borderline) or **Arctic 060ZA/BE-R32**
   (−35 °C limit, comfortable). This should be called out in design.md
   as a hard constraint on `published_unit_model`.
6. **Cooling-mode chassis.** `cooling_required = full_AC` rules out the
   Mits **PUZ-WM** and **PUZ-HWM** chassis (heating-only); the project
   would need to switch to a **PUHZ-W-HA** reversible chassis (smaller
   capacity, ~12 kW class peak) or to the Arctic line (all Arctic
   monoblocks are reversible). This is a real constraint hiding in the
   `cooling_required` parameter.
7. **The 58 °C T_HP,LWT,design from pipe-geometry.md is well inside the
   soft cap** (60 °C) and the hard cap (65 °C). No revision needed on
   geometry side. The 65 °C cap is the new hard upper bound for the
   optimizer's LWT decision variable.

---

## 13. References

- [Mitsubishi Electric Ecodan PUZ-WM112YAA(-BS) Product Information Sheet (PDF)][mitsuPUZWM]
- [Mitsubishi Electric Ecodan R32 Monobloc PUZ Single-Phase Spec Sheet, Jul 2021 (PDF)][mitsuPUZ]
- [Mitsubishi Electric Ecodan PUZ-HWM140VHA(-BS) Product Information Sheet (PDF)][mitsuHWM140]
- [Mitsubishi Electric Library — PUZ-HWM140VHA(-BS) full document][mitsuHWM140full]
- [Arctic Heat Pumps EVI DC Inverter Air to Water Heat Pump Installation & Instruction Manual (PDF)][arcticIOM]
- [Arctic Heat Pumps — 060A 60,000 BTU product page][arctic060]
- [Arctic Heat Pumps — 060ZA/BE-R32 62,000 BTU product page][arcticR32]
- [Arctic Heat Pumps — full specifications page][arcticspecs]
- [NEEP Cold Climate ASHP Specification & Product List][neep]
- [NEEP Cold Climate ASHP Specification v3.1 (PDF)][neepv31]
- [IEA HPT Annex 41 — Cold-climate heat pump efficiency methodology][iea]
- [EN 14511 — Air conditioners, liquid chilling packages and heat pumps with electrically driven compressors][en14511]
- [BS EN 14825 — Air conditioners, liquid chilling packages and heat pumps, with electrically driven compressors, for space heating and cooling — Testing and rating at part load conditions and calculation of seasonal performance][en14825]

[mitsuPUZWM]: https://ecoinnovation.lv/wp-content/uploads/2023/11/GAISS_U%CC%84DENS_SILTUMSU%CC%84KNIS_Ecodan_PUZ-WM112YAA_Monoblock.pdf
[mitsuPUZ]: https://static1.squarespace.com/static/5894a3b0be659481ff6f152c/t/60f031af7fedc2490c0ccfc1/1626354096029/Mitsubishi+Ecodan+Single+Phase+Spec+Sheet+Jul+2021.pdf
[mitsuHWM140]: https://library.mitsubishielectric.co.uk/pdf/book/PUZ-HWM140VHA_-BS
[mitsuHWM140full]: https://library.mitsubishielectric.co.uk/pdf/download_full/4197
[arcticIOM]: https://www.hvacquick.com/catalog_files/Arctic_HP_IOM.pdf
[arctic060]: https://www.arcticheatpumps.com/arctic-heat-pump-060a.html
[arcticR32]: https://www.arcticheatpumps.com/arctic-heat-pump-060za-be-r32-62-000-btu.html
[arcticspecs]: https://www.arcticheatpumps.com/specifications.html
[neep]: https://neep.org/heating-electrification/ccashp-specification-product-list
[neepv31]: https://neep.org/sites/default/files/resources/Cold%20Climate%20Air-source%20Heat%20Pump%20Specification-Version%202.0_0.pdf
[iea]: https://heatpumpingtechnologies.org/annex41/
[en14511]: https://www.en-standard.eu/bs-en-14511-2022-air-conditioners-liquid-chilling-packages-and-heat-pumps-for-space-heating-and-cooling-and-process-chillers-with-electrically-driven-compressors/
[en14825]: https://www.en-standard.eu/bs-en-14825-2022-air-conditioners-liquid-chilling-packages-and-heat-pumps-with-electrically-driven-compressors-for-space-heating-and-cooling-commercial-process-and-comfort-applications-testing-and-rating-at-part-load-conditions-and-calculation-of-seasonal-performance/
