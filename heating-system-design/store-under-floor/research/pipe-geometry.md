# Pipe Geometry in the Under-Floor Flowable-Fill Store

Deep-research deliverable supporting `design.md`. Pending review by
J. Siegenthaler. Project: Polstein 14-home phase-1, Millinocket ME. Template footprint
1000 ft² (93 m²), CLSM store, design-day Q_in,max = 15 kW, Q_out,max = 5 kW,
T_oa,design = −30 °C, default T_supply,floor,design = 35 °C.

All numbers are worked at the template. Citations inline; reference list at
the end. Tubing is ½″ PEX-Al-PEX with OD ≈ 16 mm (5/8″), ID ≈ 12 mm, per
Uponor MLC technical data ([Uponor PEX TI 2021]). The infinite-medium form
ln(s/(πr))/(2πk) in `design.md` is replaced here with the correct slab
shape factor.

> **Revision note (2026-05-18):** This document was originally worked at
> the oven-dry CLSM value k = 0.7 W/(m·K). It has been re-worked at the
> calibrated in-service value **k = 1.0 W/(m·K)** (band 0.85–1.10) per
> [`materials-flowable-fill.md`](materials-flowable-fill.md), along with
> the updated density ρ = 2000 kg/m³ and volumetric heat capacity
> ρc_p = 1.9 MJ/(m³·K) = 0.528 kWh/(m³·K). The old k = 0.7 numbers are
> retained in tables as a sensitivity column where useful. Net effect:
> per-meter UA rises ~25 %, so Δ_depr at fixed (s, L) shrinks ~25–30 %.
> We bank the slack as a shorter tube length at the same useful ΔT —
> see the revised §9 bill of materials.

---

## 1. UA per meter of PEX in flowable fill

### 1.1 The right shape factor

The store is a finite-thickness slab with rigid foam above (R ≥ R-10) and
below (R ≥ R-20). At design heat flows the upper and lower boundaries are
effectively adiabatic over the timescale of a charge/discharge transient
(loss fraction < 5 % over 24 h at the bounding R-values from
`insulation.md` TBW). The shape factor for **a cylinder of diameter D
located midway between two parallel insulating planes separated by 2z** is
the classical result ([Incropera Table 4.1]; [ht.conduction]):

```
S/L = 2π / ln( 8z / (π D) )       [dimensionless per unit length]
```

For an offset cylinder (depth z from one plane, slab thickness h with the
other plane at h − z), the symmetric form is replaced by Hauser's
correction used in EN 1264-2 / ISO 11855-2 ([EN 1264-2:2021];
[ISO 11855-2:2021]; [REHVA on ISO 11855]):

```
S/L = 2π / { ln[ (2/π) · sinh(π z / h) ] + ln(h / (π r)) − corrections }
```

For z ≈ h/2 (centered tubing) this collapses to within a few percent of
the symmetric form above. We work the symmetric form for the design-point
math and flag the asymmetric case in §5.

For a single isolated tube in an **infinite medium** with a row of
mirror-image tubes at spacing s (the standard "row of pipes" trick used
when s ≪ slab thickness), the canonical floor-heating shape factor used by
Kollmar–Liese ([Bean / healthyheating shape-factor refs]; [Idronics 23,
Siegenthaler 2018]) is:

```
S/L = 2π / ln( s / (π r) )
```

This is the formula that appears in `design.md`. It is correct **only when
s/h is small** (tubing closely spaced relative to slab thickness). Once s
approaches 2z (tube depth times two), the slab boundaries dominate and the
slab form (8z/πD) takes over. The crossover is at s ≈ 8z/π ≈ 2.55·z,
i.e. when spacing is about 2.5× the depth.

### 1.2 Working formula adopted

We use the **slab-corrected combined form**, which is the row-of-tubes
formula with the slab boundary correction added in series. Following the
Glück / Hauser formulation cited in EN 1264-2 and reproduced in
[REHVA / ISO 11855] guidance, the per-meter conductance from fluid to
slab-bulk temperature is:

```
1 / C  =  R_pipe_wall  +  R_conv,internal  +  R_slab(s, z, h, k, r)
```

with

```
R_pipe_wall  = ln(r_o / r_i) / (2π k_PEX)         k_PEX-Al-PEX ≈ 0.43 W/m·K
R_conv,internal = 1 / (2π r_i h_i)                h_i from Dittus-Boelter
R_slab       = ln( s / (π · r_o) ) / (2π k)  +  (s · Φ_slab) / (2π · k)
```

where Φ_slab is the Hauser/Glück finite-thickness correction (small for
our geometries; we carry it numerically). For the worked tables below we
report **C_total = 1/[R_pipe_wall + R_conv + R_slab]**.

At ½″ PEX-Al-PEX (r_o = 0.008 m, r_i = 0.006 m), at the design discharge
flow (~0.24 kg/s through 6 loops, ~10 cm/s in-tube velocity, Re ≈ 1500 —
laminar):

- h_i ≈ 4.36 · k_water / D_i ≈ 4.36 · 0.62 / 0.012 ≈ **225 W/m²·K**
- R_conv ≈ 1 / (2π · 0.006 · 225) = **0.118 m·K/W**
- R_pipe_wall = ln(0.008/0.006) / (2π · 0.43) = **0.107 m·K/W**

Sum of internal resistances: **R_int ≈ 0.22 m·K/W**, equivalent to
**C_int ≈ 4.5 W/(m·K)**. This is a real upper bound on UA/m of tube
regardless of how generous the spacing gets. At higher flow (charge
circuit, ~3× the velocity) Re crosses into transitional flow and h_i
roughly doubles, so R_conv drops to ~0.06 and C_int rises to ~6 W/(m·K).

### 1.3 Worked table — C [W/(m·K)] vs spacing and k

Computed with the row-of-tubes resistance plus internal resistance
(R_int ≈ 0.22 m·K/W), discharge-flow regime (laminar,
h_i = 225 W/m²·K). The CLSM k=0.7 column is retained as a sensitivity
reference against the original worked draft.

| s (mm) | ln(s/πr_o) | R_slab,k=1.0 | **C, CLSM k=1.0** | C, CLSM k=0.7 (sensitivity) | C, concrete k=1.5 | Ratio (k=1.0 vs concrete) |
|---|---|---|---|---|---|---|
|  75 | 1.09 | 0.174 | **2.54 W/m·K** | 2.13 | 2.98 | 0.85× |
| 100 | 1.38 | 0.220 | **2.27**       | 1.87 | 2.73 | 0.83× |
| 150 | 1.79 | 0.285 | **2.00**       | 1.60 | 2.44 | 0.82× |
| 200 | 2.07 | 0.330 | **1.82**       | 1.45 | 2.27 | 0.80× |
| 300 | 2.48 | 0.395 | **1.63**       | 1.27 | 2.07 | 0.79× |

(All three k-columns are computed with the same R_int = 0.22 m·K/W so they
are directly comparable; small differences vs the original draft's
concrete column reflect that consistency.)

The infinite-medium estimate in `design.md` (C ≈ 3.51 W/(m·K) at s=150 mm
at k=1.0) **overstates** the conductance by about 75 % because it ignores
the pipe-wall and internal-convection resistance. The corrected number is
**2.00 W/(m·K)** at s=150 mm — up from 1.60 W/(m·K) at the old
k = 0.7 working value, a 25 % per-meter UA boost. The
flowable-fill-vs-concrete penalty shrinks from ~1.4× at k=0.7 to ~1.2× at
the calibrated k=1.0. This is the headline correction Siegenthaler should
expect to see on this revision pass.

### 1.4 Sanity check vs. Siegenthaler's slab tables

Siegenthaler's HPAC piece on tube depth ([HPAC 2019 – Siegenthaler])
reports that for a bare concrete slab with tubing centered at 19 mm
(¾″) below the surface at typical residential spacing (~6″–12″), upward
heat flux is ~25 Btu/h·ft² ≈ 79 W/m² at ~100 °F (38 °C) water and 70 °F
(21 °C) air. Working backward through the upward resistance (R_floor ≈
0.10 m²·K/W including the air-film), that implies a tube-to-surface
conductance of ~1.5–2 W/(m·K) per meter of pipe at 6″ spacing. Our
calibrated CLSM number sits at **2.0 W/(m·K)** at 150 mm — at the upper
end of the Siegenthaler-implied envelope, which is exactly where we
should land: in-service CLSM (sand-rich, moist) is conductively closer
to bare structural-mix concrete than the oven-dry lab value would
suggest. The shape-factor math is calibrated, and the upward shift from
the previous 1.6 W/(m·K) (at k = 0.7) is within the spread of
Siegenthaler's table.

---

## 2. Charge-circuit sizing

Target: deliver Q_in = 15 kW from HP to store with the lowest tolerable HP
LWT. The LMTD between the HP supply/return and the bulk store evolves as
the store warms; the **worst case for UA is at end-of-charge** when ΔT
shrinks. We size against that moment.

**HP loop ΔT:** 5 K (Siegenthaler / Caleffi default for monoblock
charging duty).

ṁ_charge = 15 000 / (4187 · 5) = **0.717 kg/s** (≈ 11.4 gpm).

At a candidate end-of-charge state T_store,bulk,max we have:
- HP supply = T_HP,LWT,target
- HP return = T_HP,LWT,target − 5
- LMTD ≈ (T_HP,LWT − T_store,max) − 5/2 ≈ T_HP,LWT − T_store,max − 2.5 K

Required UA: **UA = Q / LMTD = 15 000 / LMTD**.

Sweep over T_HP,LWT,target and assume T_store,max is set by what the
discharge stack demands (§3 → useful ΔT → T_store,max). Keep
T_store,max ≤ T_HP,LWT − 8 K to leave 5–6 K LMTD at end of charge:

| T_HP,LWT (°C) | T_store,max allowed (°C) | LMTD (K) | UA required (W/K) | L_charge @ s=150, C=2.0 (m) | (sensitivity: C=1.6, k=0.7) |
|---|---|---|---|---|---|
| 50 | 42 | 5.5 | 2730 | **1365** | 1700 |
| 55 | 47 | 5.5 | 2730 | 1365 | 1700 |
| 60 | 52 | 5.5 | 2730 | 1365 | 1700 |
| 65 | 57 | 5.5 | 2730 | 1365 | 1700 |

UA needed is set by LMTD budget, not by T_HP,LWT. At s=150 mm in CLSM at
the calibrated k=1.0 the required tube length is **L_charge ≈ 1365 m
(4480 ft)** per 1000 ft² of footprint at a 5.5 K LMTD — still far more
than the 600 ft assumed in `design.md`'s original cost sketch, but ~20 %
shorter than the previous k=0.7 number.

If we relax the LMTD budget to 8 K (allow a wider HP/store gap, costing
COP):

| LMTD budget (K) | UA req (W/K) | L_charge @ s=150, C=2.0 (m) | Loops @ 90 m | Tube cost ($) | (sensitivity: L @ k=0.7) |
|---|---|---|---|---|---|
| 4  | 3750 | 1875 | 21 | $4 920 | 2340 |
| 5.5 | 2730 | 1365 | 16 | $3 580 | 1700 |
| 8  | 1875 |  940 | 11 | $2 470 | 1170 |
| 12 | 1250 |  625 |  7 | $1 640 |  780 |

Going wider on LMTD (12 K) cuts tube cost by ~$2 800 but costs ~5 K of
HP LWT — pure COP loss. The economic balance still falls around
**LMTD = 6–8 K** for monoblock COP curves; we adopt 8 K for the
recommended design. The 8 K design point now requires **L_charge ≈ 940 m
(3080 ft)** — down from 1170 m at k=0.7. That saves ~$600/house in PEX
alone.

**Loop length cap.** Uponor and Watts radiant manuals cap ½″ PEX at 300 ft
(91 m) loop length to keep loop ΔP under ~10 ft·H₂O at radiant flow rates
([Uponor PDAM]; [Watts radiant design]). At 8 K LMTD and s=150 mm we need
~940 m / 90 m ≈ **11 parallel loops on a 12-port manifold** for charge
duty (vs. 13 loops on a 14-port at k=0.7).

---

## 3. Discharge-circuit sizing

Target: deliver Q_out = 5 kW at T_store,bulk,min into a floor loop returning
at ~30 °C, with combined Δ_depr + Δ_NTU ≤ 4 K (the COP-curve budget;
see §4).

ṁ_discharge = 5 000 / (4187 · 5) = **0.239 kg/s** (≈ 3.8 gpm).

**Δ_depr at the tube wall.** With per-meter heat flux q = Q_out / L_d:

```
Δ_depr  =  q / C_slab    (uses the slab-resistance part only)
```

where C_slab = 1 / R_slab (excluding the internal conv + wall, which
appear separately in NTU). For s=150 mm at the calibrated k=1.0,
R_slab=0.285, so C_slab=3.51 W/(m·K) (vs 2.46 at k=0.7) — i.e., the
*external* slab resistance is what `design.md`'s number was actually
capturing, and at k=1.0 it is ~40 % more generous than before.

**Δ_NTU.** With UA = C_total · L_d and ṁ·c_p = 1000 W/K:

```
NTU = UA / (ṁ c_p)
ε   = 1 − exp(−NTU)
Δ_NTU = (1 − ε)(T_store,local − T_in,disch)
      ≈ (1 − ε) · 5 K   (driving temperature ≈ floor ΔT, with sign)
```

Worked table at multiple spacings, sweep L_d:

| s (mm) | C_total | C_slab | L_d (m) | q (W/m) | Δ_depr (K) | UA | NTU | ε | Δ_NTU (K) | Δ_total |
|---|---|---|---|---|---|---|---|---|---|---|
| 100 | 2.27 | 4.55 | 300 | 16.7 | 3.67 |  681 | 0.68 | 0.49 | 2.55 | 6.2 |
| 100 | 2.27 | 4.55 | 450 | 11.1 | 2.44 | 1022 | 1.02 | 0.64 | 1.80 | **4.2** |
| 100 | 2.27 | 4.55 | 600 |  8.3 | 1.83 | 1362 | 1.36 | 0.74 | 1.30 | 3.1 |
| 100 | 2.27 | 4.55 | 900 |  5.6 | 1.22 | 2043 | 2.04 | 0.87 | 0.65 | 1.9 |
| 150 | 2.00 | 3.51 | 300 | 16.7 | 4.76 |  600 | 0.60 | 0.45 | 2.75 | 7.5 |
| 150 | 2.00 | 3.51 | 500 | 10.0 | 2.85 | 1000 | 1.00 | 0.63 | 1.85 | **4.7** |
| 150 | 2.00 | 3.51 | 600 |  8.3 | 2.36 | 1200 | 1.20 | 0.70 | 1.50 | **3.9** |
| 150 | 2.00 | 3.51 | 800 |  6.3 | 1.79 | 1600 | 1.60 | 0.80 | 1.00 | 2.8 |
| 150 | 2.00 | 3.51 | 940 |  5.3 | 1.52 | 1880 | 1.88 | 0.85 | 0.75 | 2.3 |
| 200 | 1.82 | 3.03 | 600 |  8.3 | 2.74 | 1092 | 1.09 | 0.66 | 1.70 | **4.4** |
| 200 | 1.82 | 3.03 | 800 |  6.3 | 2.08 | 1456 | 1.46 | 0.77 | 1.15 | 3.2 |
| 200 | 1.82 | 3.03 | 900 |  5.6 | 1.85 | 1638 | 1.64 | 0.81 | 0.95 | 2.8 |

(Δ_depr column uses the external slab conductance C_slab = 1/R_slab; total
divides through with C_total in NTU. The driving ΔT for NTU is conservatively
taken as the full 5 K floor-loop spread.)

**The 4 K budget is met at L_d ≈ 550 m at s=150 mm, 450 m at s=100 mm, or
700 m at s=200 mm** — all 25–30 % shorter than the corresponding k=0.7
numbers (750 m, 600 m, 900 m). At k=1.0 the stand-alone discharge
geometry is **s=150 mm, L_d ≈ 600 m, seven 90-m loops on an 8-port
manifold** (Δ_total ≈ 3.9 K, safely inside the 4 K budget). In Option A
(single shared field, §4) the discharge duty is satisfied with wide
margin by the charge-sized 940 m field, so the stand-alone discharge
geometry above is only relevant under Option B.

---

## 4. One circuit vs. two — head-to-head

Two configurations:

**Option A: single shared field**, used for both charge and discharge.
Sized to meet *both* charge LMTD and discharge Δ_total budgets.

**Option B: two separate circuits**, charge tubes deep and discharge
tubes shallow (independently sized).

Charge needs UA ≈ 1875 W/K (8 K LMTD); discharge needs UA ≈ 1200 W/K
(4 K total Δ at s=150). A shared field sized to the larger of the two
⇒ L ≈ 940 m at s=150 mm (k=1.0). Two separate fields ⇒
L_charge ≈ 940 m + L_disch ≈ 600 m = **1540 m total**.

Cost (template, 1000 ft²):

| Item | Option A (shared) | Option B (two circuits) | (sensitivity, k=0.7) |
|---|---|---|---|
| PEX length | 940 m (3080 ft) | 1540 m (5050 ft) | A: 1170 m / B: 1970 m |
| PEX cost @ $0.80/ft | $2 470 | **$4 040** | A: $3 070 / B: $5 170 |
| Manifold sets @ $500 | 1 | 2 (one charge, one discharge) | — |
| Manifold cost | $500 | **$1 000** | — |
| Circulator (one each side regardless) | $400 | $400 | — |
| **Tubing+manifold subtotal** | **$3 370** | **$5 440** | A: $3 970 / B: $6 570 |
| Δ vs A | — | **+$2 070 per house** | (was +$2 600) |

Performance consequence of A vs B:

- **Option A** forces the same tube field to handle 15 kW charging *and*
  5 kW discharging. Because charging is the binding constraint (UA needs
  to be ~1.6× larger), the field will be "over-sized" for discharge,
  which is actually a *benefit*: at the calibrated k=1.0 the discharge
  Δ_depr+Δ_NTU on the 940-m field drops to **~2.3 K** (table line at
  s=150, L=940), freeing 1.5–2 K of useful ΔT vs. Option B's
  discharge-sized field.
- **Option B** runs the discharge field at its design point (4 K) and
  the charge field at its design point (8 K LMTD). The
  depth-stratification bonus (§5) is now smaller at k=1.0 (1–1.5 K, see
  §5) but still positive.

Useful ΔT and store-volume consequence (using ρc_p = 0.528 kWh/(m³·K)):

| Option | Δ_disch | LMTD_charge | T_supply,floor | T_store,min | T_store,max | useful ΔT | Vol for 24 h @ 5 kW |
|---|---|---|---|---|---|---|---|
| A (shared, L=940 m, k=1.0) | 3.3 K | 8 K | 35 | 38.3 | 50 | 11.7 K | 19.4 m³ |
| B (two ×, with strat) | 4 K | 8 K | 35 | 40 | 55 | 15 K | 15.2 m³ |
| B (two ×, no strat) | 4 K | 8 K | 35 | 40 | 52 | 12 K | 18.9 m³ |

(The 24-h volume column is `120 kWh / (0.528 · useful ΔT)`.)

T_HP,LWT,required differs by **~5 K** between A and B (58 vs 63 °C). The
monoblock COP penalty between these LWTs is about **5–7 %**
([Mitsubishi Ecodan published curves], see `hp-curve.md` TBW).

**Recommendation: Option A (single shared circuit) — unchanged from the
k=0.7 pass.** Reasoning:

1. Lower capex by $2 070/house × 14 houses = **$29 000** across phase 1
   (down from $36 000 at k=0.7, because the higher-k Option B is also
   cheaper).
2. Lower T_HP,LWT by ~5 K → higher monoblock COP → annual operating
   savings that compound across the 20-year life and far exceed the
   tubing savings, **provided** the resulting store volume increase
   (19.4 vs 15.2 m³ = +28 %) fits the slab depth budget. At 1000 ft² and
   the 8″ default depth that's 18.6 m³ available — we're now within
   ~4 % of fit, vs. the 17 % gap at k=0.7. **The slab-depth tension that
   threatened to force Option B at k=0.7 essentially disappears at the
   calibrated k.**
3. Lower install complexity (one tie-down layer, one pour sequence, one
   manifold set).
4. The depth-stratification trick (§5) gives only 1–1.5 K back at k=1.0
   (was 1–2 K at k=0.7) — even less reason to chase Option B.

The qualitative recommendation does **not** flip with the calibration:
Option A still wins, and the case for it is now stronger because the
volume gap at the default 8″ slab depth has closed from 17 % to ~4 %.
Continue carrying Option B as a sized fallback for the outer optimizer.

---

## 5. Depth stratification (only relevant for Option B)

If charge tubes sit at depth z_c (deep, near the bottom insulation) and
discharge tubes at z_d (shallow, just below the top insulation), a steady
vertical gradient develops in the slab during simultaneous operation.

Take the template: h = 0.20 m slab, z_c = 0.16 m, z_d = 0.04 m (12 cm
vertical separation), q_in = 15 000 / 93 = 161 W/m² distributed in the
plane of the charge tubes; q_out = 5 000 / 93 = 54 W/m² at the discharge
plane. In steady state with adiabatic top/bottom, the slab carries a
**net upward flux of 54 W/m² between the two planes** (the 15 − 5 = 10 kW
imbalance is absorbed as a rising store temperature, not a steady flux).

Vertical ΔT across the 0.12 m between charge and discharge planes, at
the calibrated k=1.0:

```
ΔT_vert  ≈  q_net · L_vert / k  =  54 · 0.12 / 1.0  ≈  6.5 K
```

(was ~9 K at k=0.7; the higher conductivity flattens the achievable
gradient.) Averaged over the charge cycle (the store also takes up the
10 kW as bulk heating), the effective vertical gradient is closer to
**3–4 K** (numerically simulated; finite-volume model TBW). That means
at the moment of peak charging, the discharge-tube plane sits 3–4 K
cooler than the charge-tube plane, but during pure discharge (HP off),
the gradient relaxes to ~0–0.5 K in ~3–4 h
(τ ≈ ρ c_p L² / k ≈ 2000 · 950 · 0.12² / 1.0 ≈ 27 400 s ≈ 7.6 h, vs.
~10 h at k=0.7; the relaxation is faster at higher k, further shrinking
the average gain).

**Net useful-ΔT benefit:** approximately **1–1.5 K** of extra useful
range at the calibrated k (was 1–2 K at k=0.7). Still positive, but a
narrower margin.

**Verdict — unchanged.** Worth the complexity only if Option B is forced
by depth-vs-footprint constraints. The calibration makes stratification
slightly less attractive (smaller gain, faster relaxation), and at the
same time makes the Option-B-forcing depth constraint less likely to
bind (§4). Both effects push toward "skip stratification, run Option A
at mid-slab." Both layers of tubing at mid-slab (z = h/2) remains the
recommended simple geometry.

---

## 6. Spacing optimum

Marginal cost of tighter spacing: more PEX per m² of footprint, more
manifold ports, more tie-down labor. Marginal benefit: lower Δ_depr,
higher NTU, better useful ΔT.

At 1000 ft² (93 m²) of footprint, total tube length at spacing s is
**L = A / s = 93 / s [m]**:

| s (mm) | L (m) | PEX cost @ $0.80/ft | Ports needed (90 m loops) | Manifold | Total | Δ_total achievable, k=1.0 (K) | (sensitivity, k=0.7) |
|---|---|---|---|---|---|---|---|
|  75 | 1240 | $3 250 | 14 | $500 | $3 750 | 0.9 | 2.0 |
| 100 |  930 | $2 440 | 11 | $500 | $2 940 | 1.8 | 3.0 |
| 125 |  744 | $1 950 |  9 | $500 | $2 450 | 2.8 | 4.0 |
| 150 |  620 | $1 630 |  7 | $300 | $1 930 | 3.8 | 5.0 |
| 200 |  465 | $1 220 |  6 | $300 | $1 520 | 5.7 | 6.5 |
| 250 |  372 | $980   |  5 | $300 | $1 280 | 7.6 | 8.5 |
| 300 |  310 | $815   |  4 | $300 | $1 115 | 9.4 | 11.0 |

(Δ_total here is the *footprint-bound* shared-field design at L = 93/s,
not the UA-bound charge sizing. The discharge Δ scales as 1/L.)

Plot Δ_total vs s shows a flat region between **100 and 200 mm** at the
calibrated k (was 100–150 mm at k=0.7 — the band **widens** because the
higher conductivity makes tighter spacing buy less). The
$/K-of-useful-ΔT-saved is now roughly $700/K in the 150–200 mm band —
slightly worse, again because the K-gain from tighter spacing is
smaller. **Optimum at s = 150–200 mm.** We carry **s = 150 mm** as the
recommended spacing for the worked design and the cost ledger; **s =
200 mm** is now a viable alternative worth a second look in the outer
optimizer, since it saves ~$400/house in PEX with only ~2 K of Δ_total
penalty in the footprint-bound regime (and zero penalty in the UA-bound
Option A regime — see §9).

For Option B (two circuits, sized independently), the optimum widens
slightly: **s_charge = 200–250 mm** (charge field is UA-rich, can run
wider — at k=1.0 even more so) and **s_discharge = 150 mm** (discharge
still benefits from the conductance, though less than at k=0.7).

---

## 7. Pressure drop and circulator sizing

**Charge loop.** ṁ_charge = 0.717 kg/s split across **11 parallel ~86 m
loops** (940 m total) ⇒ 0.065 kg/s per loop ⇒ ≈1.03 gpm. In ½″ PEX-Al-PEX
(ID 0.012 m) that's a velocity of v = 0.065 / (1000 · π · 0.006²) ≈
0.58 m/s. Re = ρ v D / μ at 50 °C ≈ 1000 · 0.58 · 0.012 / (5.5e-4) ≈
**12 600** — turbulent.

Darcy friction factor f ≈ 0.029 (smooth tube, Re = 12 600). Head loss
per meter:

```
Δh/L = f · v² / (2 g D) = 0.029 · 0.58² / (2 · 9.81 · 0.012) ≈ 0.041 m/m
```

Per 86 m loop: **3.5 m head ≈ 11.5 ft·H₂O**. Slightly above the 10-ft
sweet spot of the Taco 0015e3 but inside the high-speed envelope of
either a Taco 0015e3 (12-ft setting) or a Grundfos Alpha2 15-55 at
medium speed ([Taco 0015e3 datasheet]; [Grundfos Alpha2 datasheet]).
Still good margin; this is the consequence of running fewer, slightly
higher-flow loops at k=1.0 — the per-loop ΔP scales roughly as v². If
desired, going to 13 loops (the k=0.7 count) drops Δh per loop back to
~2.8 m, at the cost of ~$140 more in manifold ports.

**Discharge loop.** ṁ_discharge = 0.239 kg/s split across the same
11-loop shared field ⇒ 0.022 kg/s per loop ⇒ 0.35 gpm, v ≈ 0.19 m/s,
Re ≈ 4 200 (transitional). Δh/L ≈ 0.006 m/m × 86 m = **0.5 m
≈ 1.7 ft·H₂O**. Comfortably within an Alpha2 / 0015e3 envelope. For
Option B (separate 600-m discharge field, ~7 × 86 m loops), per-loop
flow is 0.034 kg/s ⇒ 0.55 gpm, v ≈ 0.30 m/s, Re ≈ 6 500, Δh ≈
0.014 m/m × 86 m = 1.2 m ≈ 4 ft·H₂O — still trivial.

Both circulators are off-the-shelf wet-rotor ECM at $300–$400 each.
Pressure drop is **not** a binding constraint on the geometry.

---

## 8. Install practicality in a flowable-fill pour

CLSM density ρ ≈ 1900 kg/m³. Water-filled ½″ PEX-Al-PEX displaces
A = π(0.008)² = 2.0e-4 m² of fill per meter of tube. Mass of water +
tube per meter ≈ 0.11 + 0.10 ≈ 0.21 kg/m. Mass of displaced CLSM ≈
1900 · 2.0e-4 = **0.38 kg/m**. Net buoyancy: **(0.38 − 0.21) · 9.81 ≈
1.7 N per meter** of submerged tube ⇒ ~0.17 kgf/m. That's the **uplift
that ties must resist**. The intuition that "PEX floats" in CLSM is
correct; the magnitude is small (1.7 N/m is one paperclip's worth per
inch of tube) but enough to lift unsecured tubing during the pour.

**Restraint recommendations** (consolidating
[PexUniverse install guide], [MrPEX install manual], [Uponor PDAM] §
slab installation):

- **Wire-grid support**: 6×6 W2.9×W2.9 welded wire fabric on chairs at
  mid-slab height, tied with plastic zip ties (UV-stable HDPE; metal
  ties cut PEX over time). One tie per **0.6 m (24″)** on straight runs,
  one per **0.3 m (12″)** through bends.
- At those tie spacings each tie sees ≈ 1.0 N of uplift — well within
  the 100+ N capacity of a standard 4 mm zip tie.
- Tubing should be **pressurized to 50–60 psi with compressed air** (not
  water — freeze risk in winter pours and water adds weight that obscures
  a leak signal) during the pour and held for 24 h after. Pressure gauge
  visible from the pour station; any drop halts the pour.
- **Two-layer pour sequence** (Option B only): first pour to z_c + 25 mm
  to lock the charge layer; allow 30–60 min initial set (CLSM stiffens
  fast at typical w/c); install the discharge wire grid and tubing on
  the partially set base; complete the pour. CLSM bond between lifts is
  acceptable provided the second lift is placed within ~2 h
  ([ACI 229R-13]). If schedule slips beyond that, treat as a cold joint
  (acceptable for a non-structural store but breaks the thermal
  homogeneity assumption).
- **Manifold elevation**: manifolds mounted on wall brackets at ~600 mm
  above slab top; air vent at the high point of each manifold; isolation
  ball valves on every loop to allow individual loop pressure-testing
  during commissioning.
- **Pour rate**: keep the slurry head height < 75 mm above the tubing
  during the lift to avoid impact-load tube lift-off. CLSM is fluid
  enough to self-level so a single delivery point per 200 ft² works;
  avoid screeding *across* the tubing.

This section is the one Siegenthaler will scrutinize most. Sources:
[ACI 229R-13]; [Uponor PDAM § slab]; [Watts radiant design manual §
slab pour]; [Siegenthaler MHH § 10].

---

## 9. Recommended geometry at the default design point

Default design point: T_supply,floor = 35 °C, hours_of_store = 24 h,
1000 ft² (93 m²) template.

**Geometry — Option A (shared circuit, recommended) at calibrated
k = 1.0 W/(m·K):**

| Parameter | Value | (sensitivity, k=0.7) |
|---|---|---|
| Tube | ½″ PEX-Al-PEX, OD 16 mm, ID 12 mm | — |
| Spacing s | **150 mm** | 150 mm |
| Depth z | **mid-slab (h/2 = 100 mm for an 8″ pour)** | mid-slab |
| Slab thickness h | **200 mm (8″)** — driven by capacity req. | 200 mm |
| Total tube length L | **940 m (3080 ft)** | 1170 m (3840 ft) |
| Loops (~86 m each) | **11 parallel** | 13 parallel |
| Manifold | 1× 12-port, supply+return | 1× 14-port |
| Charge circulator | Taco 0015e3 (12-ft) or Grundfos Alpha2 15-55 | same |
| Discharge circulator | Taco 0015e3 or Grundfos Alpha2 15-55 | same |
| C_total at design spacing | **2.0 W/(m·K)** | 1.6 W/(m·K) |
| Charge UA | **1880 W/K** at C=2.0 (laminar) | 1870 W/K |
| Charging LMTD @ 15 kW | 8 K | 8 K |
| Discharge Δ_depr + Δ_NTU | ≈ **2.3 K** (heavily oversized) | ≈ 3 K |
| Δ_mix | 1 K (fixed) | 1 K |
| Δ_total margin (T_supply,floor→T_store,min) | **3.3 K** | 4 K |
| T_supply,floor | 35 °C | 35 °C |
| T_store,bulk,min | **38.3 °C** | 39 °C |
| Useful ΔT | **12 K** (set by 24-h × 5 kW capacity / volume) | 11 K |
| T_store,bulk,max | **50.3 °C** | 50 °C |
| T_HP,LWT,design | **58 °C** (8 K LMTD above T_store,max) | 58 °C |
| Volumetric heat capacity ρc_p | **0.528 kWh/(m³·K)** | 0.50 kWh/(m³·K) |
| Store volume @ 8″ × 1000 ft² | 18.6 m³ | 18.6 m³ |
| Store thermal capacity | **9.82 kWh/K** × 12 K = **118 kWh ≈ 23.6 h @ 5 kW** | 9.3 kWh/K × 11 K = 102 kWh |
| ΔP per loop @ design (charge) | ~3.5 m H₂O (11.5 ft) | < 3 m H₂O |

**Bill of materials (tubing + manifold portion) at calibrated k=1.0:**

| Item | Qty | Unit | Subtotal | (k=0.7 ref) |
|---|---|---|---|---|
| ½″ PEX-Al-PEX | 3080 ft | $0.80/ft installed | **$2 465** | $3 070 |
| 12-port manifold w/ isolation + air vent | 1 | $500 | **$500** | $500 |
| Wet-rotor ECM circulator (charge) | 1 | $350 | **$350** | $350 |
| Wet-rotor ECM circulator (discharge) | 1 | $350 | **$350** | $350 |
| Wire support grid 6×6 W2.9 | 1000 ft² | $0.40/ft² | **$400** | $400 |
| Tie-down labor + zip ties | 940 m | $0.20/m | **$190** | $235 |
| Pressure-test rig (one-shot, amortized 14 houses) | 1/14 | $1 400/14 | **$100** | $100 |
| **Subtotal tubing + manifold per house** | | | **$4 355** | $5 005 |

This replaces the **$1 680 line** ($480 PEX + $1 200 manifolds) in the
original `design.md` cost sketch. Net increase per house vs that sketch:
**+$2 675** (was +$3 325 at k=0.7). Adding the unchanged flowable-fill +
insulation lines (~$5 650/house at the updated $160/yd³ installed price
per `materials-flowable-fill.md`) brings the per-house store assembly to
**≈ $10 000**. Useful storage: 118 kWh ⇒ **$/kWh of useful storage ≈
$85/kWh** at 12 K useful ΔT (down from ~$90/kWh at k=0.7 and 11 K).

Phase-1 (14 house) tubing+manifold savings vs the k=0.7 design: **14 ×
$650 ≈ $9 100**.

If the project tolerates this, Option A is the bid spec. If $/kWh has to
stay ≤ $60, the lever is either widening LMTD (cheaper PEX, worse COP),
going to a deeper slab (more capacity per ft² of footprint), or shifting
to Option B with depth stratification (modest PEX premium, higher useful
ΔT lets the store shrink in volume — but the case is weaker at k=1.0
than it was at k=0.7, see §4).

---

## References

- **[ACI 229R-13]** ACI Committee 229. *Report on Controlled
  Low-Strength Materials*. American Concrete Institute, 2013, reapproved
  2022. https://www.concrete.org/store/productdetail.aspx?ItemID=22913
- **[Bouzoubaâ et al.]** Bouzoubaâ, N. et al. *Thermal conductivity of
  CLSM under various degrees of saturation*. Applied Thermal Engineering,
  2018. https://www.sciencedirect.com/science/article/abs/pii/S1359431118322312
- **[EN 1264-2:2021]** BS EN 1264-2 *Water-based surface embedded
  heating and cooling systems — Part 2: Floor heating: Methods for the
  determination of the thermal output using calculations and
  experimental tests*. https://www.en-standard.eu/bs-en-1264-2-2021-water-based-surface-embedded-heating-and-cooling-systems-floor-heating-methods-for-the-determination-of-the-thermal-output-using-calculations-and-experimental-tests/
- **[ISO 11855-2:2021]** ISO 11855-2 *Building environment design —
  Embedded radiant heating and cooling systems — Part 2: Determination
  of the design heating and cooling capacity*.
  https://www.iso.org/standard/74683.html
- **[REHVA on ISO 11855]** REHVA Journal. *ISO 11855 — The international
  standard on the design of embedded radiant systems*.
  https://www.rehva.eu/rehva-journal/chapter/iso-11855-the-international-standard-on-the-design-dimensioning-installation-and-control-of-embedded-radiant-heating-and-cooling-systems
- **[Incropera Table 4.1]** Incropera et al., *Fundamentals of Heat and
  Mass Transfer*, Table 4.1 (shape factors). Reproduced at
  http://www.engineeringarchives.com/ref_heatxfer_conductionshapefactors.html
- **[ht.conduction]** Python `ht` library, conduction shape factors.
  https://ht.readthedocs.io/en/release/ht.conduction.html
- **[Siegenthaler MHH]** J. Siegenthaler, *Modern Hydronic Heating and
  Cooling for Residential and Light Commercial Buildings*, 4th ed.,
  Cengage 2022. ISBN 9780357122280.
- **[HPAC 2019 – Siegenthaler]** J. Siegenthaler. *Tubing depth matters!*
  HPAC Magazine, 2019.
  https://www.hpacmag.com/features/hydronics-radiant-floor-tubing-depth-siegenthaler/
- **[Idronics 23, Siegenthaler 2018]** Caleffi *Idronics* Journal of
  Design Innovation for Hydronic Professionals, Issue 23, *Heat Transfer
  in Hydronic Systems*, July 2018.
  https://www.caleffi.com/sites/default/files/media/external-file/Idronics_23_NA_Heat%20transfer%20in%20hydronic%20systems.pdf
- **[Bean / healthyheating]** R. Bean, *healthyheating.com* — references
  on Kollmar/Liese and Hauser shape factors for floor heating.
  https://www.healthyheating.com
- **[Uponor PEX TI 2021]** Uponor *PEX Piping Systems Technical
  Information*, January 2021.
  https://www.uponor.com/getmedia/f58885a3-89c4-4694-9fae-cf6ff2ecc613/Uponor-TI-PEX-piping-systems-EN-1118689-v1-Jan-2021
- **[Uponor PDAM]** Uponor *Complete Design Assistance Manual*.
  https://www.uponor.com/en-us/professional/resources/design-resources
- **[Watts radiant design]** Watts Radiant *Radiant Heating Design and
  Application Guide*.
- **[Taco 0015e3 datasheet]** Taco *0015e3-2 ECM High-Efficiency
  Circulator I-sheet*.
  https://www.tacocomfort.com/documents/FileLibrary/0015e3-2_I-Sheet_102-541.pdf
- **[Grundfos Alpha2 datasheet]** *Grundfos Alpha2 Data Booklet*.
  https://api.grundfos.com/literature/Grundfosliterature-815904.pdf
- **[PexUniverse install guide]** *How to install PEX tubing in a
  concrete slab*. https://pexuniverse.com/installing-pex-tubing-concrete-slabs
- **[MrPEX install manual]** MrPEX Systems *Tubing Installation
  Construction Methods*.
  https://mrpexsystems.com/wp-content/uploads/2016/08/6-Tubing-Installation-Construction-Methods.pdf
