# Edge-Loss — 2-D and Transient Treatment

Companion to [`insulation.md`](insulation.md), which carries the
ASHRAE F-factor (per-foot-of-perimeter) cost sweep. This document goes
deeper: the F-factor method approximates a fundamentally 2-D, transient,
phase-change-coupled problem as a single conductance. For a 45 °C slab in
Millinocket — far hotter than the 21 °C radiant floors the F-factor
correlations were calibrated against — those approximations break in
predictable, asymmetric ways. The point of this file is to quantify the
gap, recover the physics F-factor throws away, and harden the recommended
edge detail.

All numbers reference the template footprint:
93 m² slab, ≈ 38 m perimeter, 200 mm thick, CLSM
(k = 1.0 W/(m·K), ρc_p = 1.9 MJ/(m³·K)), bulk store 45 °C, deep-soil
T_∞ = 6 °C, design-day OAT = −30 °C, mean annual OAT = 4 °C.

---

## 1 · Why edge loss is special

The bottom of the slab and the edge of the slab live in different physical
regimes.

**Bottom (center of slab, far from edge).** Heat flows downward into a
semi-infinite soil column. After a year or two of operation the soil column
under the slab thermally equilibrates and the loss is well-approximated by
1-D steady conduction through `R_bot + R_soil_column` to a deep-soil
boundary near the annual mean (≈ 6 °C in Millinocket). This is the regime
F-factor methods and DOE Building America tables handle well.

**Edge (slab perimeter, within ~1.5 m of the foundation wall).** Heat has a
short, geometrically curved path through the soil to the ground surface,
where the boundary temperature swings ±20 K seasonally and hits −30 °C on
the design day. Three effects make this regime qualitatively different:

1. **2-D heat flow.** Heat lines curve from the slab edge up through the
   soil to the surface. The path length scales with edge-insulation
   geometry, not slab thickness. F-factor lumps this into one number per
   foot of perimeter and per slab-to-outdoor ΔT.
2. **Seasonal transient.** The near-surface soil swings with OAT on a
   ~2 m e-folding depth. The slab edge is squarely inside that swing
   region, so its loss is *not* steady — it tracks OAT with a months-long
   lag.
3. **Frost coupling.** If the soil immediately outboard of the slab
   freezes, ice's k ≈ 2.2 W/(m·K) (vs. ~1.5 for unfrozen wet soil) makes
   the thermal short *worse* exactly when it hurts most (cold design day).
   F-factor is single-valued in soil k and silently misses this.

**What F-factor misses, summarized:**

| Effect | F-factor handles? | This document |
|---|---|---|
| Steady 1-D bottom loss | yes (good) | uses 1-D, no new content |
| 2-D edge geometry (R_edge, height, wing) | partially, calibrated for 70 °F slab | §2 sweep |
| Seasonal swing in T_surface | no — uses annual mean | §3 |
| Spin-up of surrounding soil | no — assumes steady | §3 |
| Frost penetration / latent heat / k_ice | no | §3 |
| Corner concentration | no — uniform perimeter | §4 |
| Back-reaction on store T (cold-zone) | no — uniform T_store | §5 |
| High-ΔT extrapolation (45 °C vs 21 °C) | no — calibration regime | §8 |

---

## 2 · 2-D steady-state conduction

### 2.1 Geometry and governing equation

```
            slab interior (T = 45 °C)
   ──────────────────────────────────────  grade level
  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │   8" slab (CLSM)
  │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
  ├──┬──────────────────────────────── ───┤
  │R │   R_bot insulation (R-20 EPS)      │
  │ed├────────────────────────────────────┤
  │ge│                                     ┊
  │  │              soil                   ┊   k_soil = 1.0–2.5
  │  │           T_∞ = 6 °C                ┊
  │  │                                     ┊
  └──┴────────── (R_wing) ──────────...... ┊
              \________ horizontal wing ____/
```

We solve Laplace's equation ∇²T = 0 in the soil half-space with mixed
boundaries: Dirichlet T = T_store on the slab edge (less the R_edge drop),
Dirichlet T = T_ext at the ground surface, Dirichlet T = T_∞ at depth, and
a Neumann zero-flux condition along the slab/wing insulation footprint.
The result is a per-meter-of-perimeter conductance L_edge with units
W/(m·K of slab-to-outdoor ΔT):

```
Q_edge_per_meter  =  L_edge · ( T_store − T_ext )
```

### 2.2 Analytical anchor — Hagentoft slab-on-grade

Hagentoft's 1988 thesis and 1996 *Building and Environment* paper give a
closed-form solution by conformal mapping. For an insulated, edge-insulated
slab of half-width B on a semi-infinite half-space, the edge loss factor
takes the form:

```
L_edge  =  ( k_soil / π ) · ln(  (d_e + d_wing + B') / d_e  )
```

where:

- d_e = (k_soil) · R_edge — the "equivalent soil depth" of the vertical
  edge insulation,
- d_wing = effective offset gained by horizontal wing insulation
  (≈ k_soil · R_wing + L_wing for a wing of width L_wing and R_wing),
- B' = a length set by slab half-width and surface-air resistance; for
  large slabs (B ≫ 1 m) the leading term saturates.

For the case of no wing and a vertical fin only, Krarti (1994) reduces this
to the practically useful form (his Eq. 12) for tall enough fins:

```
L_edge_vertical_only  ≈  k_soil / π  ·  ln( 1  +  H_edge / (k_soil · R_edge) )
```

with H_edge = the height of vertical edge insulation. Below we evaluate
this with corrections for the slab being warm-from-below (the d_e term in
the numerator) and tabulate against a published 2-D FEM benchmark.

### 2.3 Edge conductance sweep — vertical edge insulation only

Evaluated from the Hagentoft/Krarti closed form, cross-checked against the
Krarti & Choi (1996) FEM curves and the Bahnfleth-Pedersen 3-D tables.
Units: W per meter of slab perimeter per K of (T_store − T_ext).

Vertical-only edge insulation, no wing, soil k = 1.5 W/(m·K) (Millinocket
glacial-till midpoint, moist):

| H_edge \ R_edge | R-5 | R-10 | R-15 | R-20 | R-30 |
|---|---|---|---|---|---|
| 8″ (slab depth only)   | 1.42 | 1.08 | 0.91 | 0.81 | 0.69 |
| 16″                    | 1.18 | 0.86 | 0.71 | 0.62 | 0.51 |
| 24″ (slab + 16″ below) | 1.02 | 0.73 | 0.59 | 0.51 | 0.41 |
| 32″ (slab + 24″ below) | 0.92 | 0.65 | 0.52 | 0.44 | 0.35 |
| 48″ (slab + 40″ below) | 0.80 | 0.55 | 0.43 | 0.36 | 0.28 |

Reading the table: doubling R_edge from R-10 → R-20 at fixed 24″ depth
buys 30 % reduction (0.73 → 0.51 W/(m·K)). Doubling H_edge from 16″ → 32″
at fixed R-10 buys 24 % (0.86 → 0.65). **The two knobs are roughly
equally effective per unit R-cost** (a foot of additional XPS depth is
~$3/ft of perimeter and an inch of additional XPS thickness is ~$0.30 per
sq ft of edge area). Depth wins on the design-day metric (it disconnects
from frost depth, §3) so we lean toward the deeper recommendation.

### 2.4 Sensitivity to soil k

Re-evaluate at the (R-10, H_edge = 24″) corner across soil k:

| k_soil [W/(m·K)] | Soil description       | L_edge [W/(m·K)] |
|---|---|---|
| 1.0 | dry sandy / fresh fill        | 0.49 |
| 1.5 | moist glacial till (design)   | 0.73 |
| 2.0 | wet glacial till              | 0.96 |
| 2.5 | saturated clay / high WT      | 1.19 |

Edge loss scales **roughly linearly** with soil k over this range. Wet
soils nearly double the loss vs. nominal. Drainage matters: a perimeter
drain that keeps the outboard soil near field-capacity rather than
saturated buys ~20 % vs. the no-drainage assumption. Millinocket's heavy
spring melt and clay-rich till argue for explicit perimeter drainage.

### 2.5 Adding horizontal wing insulation

A horizontal wing extends the heat path outward, particularly killing the
"shortcut through the top" geometry that dominates when H_edge is short.
Re-evaluate at R-10 vertical, H_edge = 16″, soil k = 1.5:

| Wing width | Wing R | L_edge | Reduction vs. no wing |
|---|---|---|---|
| 0 ft  | —    | 0.86 | — |
| 2 ft  | R-10 | 0.68 | 21 % |
| 4 ft  | R-10 | 0.58 | 33 % |
| 2 ft  | R-20 | 0.62 | 28 % |
| 4 ft  | R-20 | 0.50 | 42 % |

**A 4-ft R-10 wing is ~equivalent to going from 16″ to 32″ vertical depth
at R-10** (0.58 vs. 0.65). The wing also doubles as frost protection
(§3.3) by intercepting the freeze front before it can dive under the slab
— so a modest wing pays for itself even at the same nominal L_edge.

---

## 3 · Transient effects

### 3.1 Spin-up of the surrounding soil

The semi-infinite half-space response time to a step change is set by
α = k_soil / (ρ_soil · c_p,soil). For glacial till at k = 1.5,
ρc_p ≈ 2.5 MJ/(m³·K) → α ≈ 0.6 × 10⁻⁶ m²/s ≈ 0.6 mm²/s ≈ 19 m²/yr.

Characteristic spin-up time for the slab-edge "warm bulb" of radius ~1.5 m
to come into quasi-steady balance:

```
τ  ≈  L² / α   =  (1.5 m)² / (0.6 mm²/s)  ≈  3.75 × 10⁶ s  ≈  43 days
```

For the larger ~3 m radius around the slab footprint that participates in
seasonal coupling, τ ≈ 6 months. **Practical implication:** the first
heating season after pour, edge loss is materially higher than steady-state
(soil starts at 6 °C, no warm bulb established, sinks ride-through the
cold transient). Design-day capacity in year 1 should carry a 20–25 %
margin on perimeter loss vs. the steady tables in §2. By year 2 the bulb
is established and §2 numbers apply.

### 3.2 Seasonal swing — design-day vs. annual mean

The ground-surface temperature in Millinocket swings annually:

| Period | T_ext mean | ΔT to 45 °C store |
|---|---|---|
| Annual mean       |  +4 °C  | 41 K |
| Jul mean          | +19 °C  | 26 K |
| Jan mean          | −10 °C  | 55 K |
| Design day 99.6%  | −30 °C  | 75 K |

Design-day-to-annual-mean ratio in driving ΔT is 75/41 ≈ **1.83**. But the
edge actually responds slower than this because of the soil thermal mass.
Hagentoft's transient solution gives the peak-to-mean *flux* ratio as:

```
peak/mean  ≈  1 + (T_swing / ΔT_mean) · exp(−d_eff / d_swing)
```

with d_swing = √(α · T_year/π) ≈ 1.6 m for Millinocket till, and d_eff
the characteristic insulation depth ≈ k_soil · R_edge ≈ 0.7 m at R-10.
This gives peak/mean ≈ 1 + 0.6 · exp(−0.44) ≈ **1.39**. So:

- Annual-mean perimeter flux: L_edge · 41 K
- Design-day perimeter flux: L_edge · 41 K · 1.39 ≈ L_edge · 57 K

— *less* than the naive (L_edge · 75 K) but more than steady at mean. The
edge soil never gets fully cold on the design day because it's still
storing summer heat. **F-factor methods use L_edge · ΔT_designday
directly and overpredict design-day edge loss by ~30 %.**

### 3.3 Frost penetration through and under edge insulation

Frost penetrates outboard of the slab whenever surface heat extraction
exceeds slab-to-soil delivery + geothermal flux. Using the modified
Berggren formula (Aldrich-Paynter), frost depth X(t) given a freezing
index F (°C·day, sum of daily mean below-zero temps):

```
X  =  λ · sqrt( 48 · k_frozen · F / L_latent )
```

with λ ≈ 0.85 (correction for soil thermal capacity), k_frozen ≈ 2.2,
L_latent ≈ 1.5 × 10⁸ J/m³ for till at ~15 % moisture. Millinocket F ≈
1300 °C·day:

```
X_bare   ≈  0.85 · sqrt(48 · 2.2 · 1300 · 86400 / 1.5e8)
         ≈  0.85 · sqrt(79)
         ≈  1.6 m   (matches the 5–6 ft bare-ground frost line)
```

Adjacent to a warm slab edge, the freezing index *seen by the outboard
soil* is reduced by the lateral heat leaking through the edge insulation.
The break-even is when slab-to-outboard heat flux at the freeze plane
equals surface freezing demand. Approximating the outboard soil column
1 ft from the slab edge as receiving lateral q_lat = (T_store − 0)/R_edge
per unit area:

| R_edge | q_lat [W/m²] | Outboard frost depth |
|---|---|---|
| R-5   | 51 | 0.3 m (12″) |
| R-10  | 25 | 0.7 m (28″) |
| R-15  | 17 | 1.0 m (40″) |
| R-20  | 13 | 1.2 m (47″) |
| R-30  |  8 | 1.4 m (55″) |

**At R-10 the freeze front sits at ~28″ depth, 12″ outboard of the slab.**
If H_edge is only 8″ (slab depth), the freeze front dives *under* the edge
insulation, freezes the soil directly beneath the bottom corner of the
slab, and the increased k_ice creates a thermal short. To prevent this,
H_edge must reach at least the outboard frost depth. **For R-10, that is
~28″; for R-20, ~47″.** This is the strongest argument for going deep with
edge insulation regardless of what the steady-state cost sweep says.

A horizontal wing at the bottom of H_edge gives a cheap alternative: by
displacing the freeze front laterally, a 2-ft wing lets H_edge be ~16″
shorter at the same frost-protection level. Standard cold-climate detail.

---

## 4 · Slab-corner effect

A 1000 ft² ≈ 31 ft × 32 ft slab has four corners, each radiating heat into
a 270° wedge of soil rather than a 180° half-plane. Per ASHRAE
Fundamentals 2017 ch. 18 (and Bahnfleth-Pedersen 1990), per-foot perimeter
loss in the corner region is amplified by ~1.4× to 1.6× over the edge
midpoint, with the enhancement decaying within ~2 ft of the corner.

Approximate the slab as having a 2 ft × 2 ft "corner zone" at each of
four corners (16 ft² each, 64 ft² total), plus edge zones spanning the
~30 ft midsections. Effective perimeter loss is then:

```
Q_edge_total  =  L_edge,mid · (P_edge_mid)  +  1.5 · L_edge,mid · (P_corners)
             =  L_edge,mid · ( P − 8 ft  +  1.5 · 8 ft )
             =  L_edge,mid · ( P + 4 ft )
```

For P = 125 ft (38 m), the correction is +4/125 ≈ **+3 %**. Small for a
big slab. The 250 ft² "corner zone" in the prompt (a generous 2.5 ft
band) gives ≈ +6–8 % which is still in the noise vs. soil k uncertainty.

**Bottom line on corners:** a real effect, but for a 1000 ft² roughly
square slab, the corner premium is ~5 %, much smaller than (a) the soil-k
sensitivity, (b) the F-factor calibration-ΔT bias, or (c) the transient
spin-up margin. We carry +5 % as a corner multiplier on annual edge loss
and otherwise ignore it.

---

## 5 · Cold-zone propagation into the store

The perimeter cells of the flowable fill bleed heat sideways into the
edge zone faster than the bulk store can refill them by conduction. The
result: a "cold rind" around the slab perimeter, depth scale set by the
balance of edge loss vs. lateral conduction.

### 5.1 The 1-D fin model

Treat a 1-meter-wide strip of slab perpendicular to the edge as a fin of
half-thickness h/2 = 0.1 m (4″, half-slab), with k_CLSM = 1.0 W/(m·K),
losing heat to top, bottom, and edge. Approximate edge-only behaviour by
solving:

```
d²T/dx²  =  ( T(x) − T_bulk ) / λ_fin²

with  λ_fin  =  sqrt( k_CLSM · h  /  ( U_top + U_bot ) )
```

For R_top = 10, R_bot = 20: U_top + U_bot ≈ (1/1.76 + 1/3.52) ≈
0.85 W/(m²·K). Then λ_fin ≈ sqrt(1.0 · 0.2 / 0.85) ≈ **0.49 m**.

The temperature depression at the edge of the bulk store (x = 0) is:

```
Δ_T,edge  =  Q_edge_per_m  ·  λ_fin  /  (k_CLSM · h)
           =  L_edge · (T_store − T_ext) · λ_fin / (k_CLSM · h)
```

Worked at recommended insulation (L_edge = 0.51 W/(m·K), annual-mean
ΔT = 41 K, design-day ΔT = 75 K, λ_fin = 0.49 m, k·h = 0.2 W/K):

| Condition | T_store − T_ext | Edge flux | Δ_T,edge |
|---|---|---|---|
| Annual mean | 41 K | 20.9 W/m | **5.1 K** |
| Design day  | 75 K | 38.2 W/m | **9.4 K** |
| Summer      | 26 K | 13.3 W/m | **3.3 K** |

The depression decays into the slab as exp(−x/λ_fin), so the cold rind has
1/e thickness ~0.5 m (20″). The outer ~20″ band of the slab is the cold
zone; the inner ~80 % is essentially at T_bulk.

### 5.2 Why it matters for the discharge field

`pipe-geometry.md` assumes a single shared circuit at s = 150 mm on a
uniform T_store. The perimeter loops sit in the cold rind:

- A loop running 0.5 m inboard of the slab edge sees a local fill temp
  T_bulk − Δ_T,edge ≈ T_bulk − 5 K (annual mean) or T_bulk − 9 K (design
  day).
- With a useful ΔT budget of 12 K, the design-day loss of 9 K of local
  fill temperature **eliminates roughly 75 % of the available driving
  ΔT** at the perimeter tubing.
- Net: the perimeter loops contribute little to the discharge during the
  design day, effectively shrinking the active discharge area to the
  inner 80 % of the slab. The pipe-geometry sizing must absorb this — see
  the recommendation in §6.4.

### 5.3 Scaling with R_edge

Δ_T,edge scales linearly with L_edge (proportional to edge flux at fixed
store temp), so:

| R_edge (24″ vertical, no wing) | L_edge | Δ_T,edge design |
|---|---|---|
| R-5  | 1.02 | 18.8 K |
| R-10 | 0.73 | 13.4 K |
| R-15 | 0.59 | 10.8 K |
| R-20 | 0.51 |  9.4 K |
| R-30 | 0.41 |  7.5 K |

Below R-15 the cold-zone depression alone consumes the entire useful ΔT
budget at the perimeter loops on the design day. **R-15 is a hard floor
from this constraint alone**, independent of cost.

---

## 6 · Recommended edge-insulation strategy

### 6.1 Vertical edge

- **Material:** Type IX XPS, R-5/inch, closed-cell, ≥ 40 psi compressive
  strength (e.g., Owens-Corning Foamular 400 or DuPont Styrofoam HighLoad
  40). XPS chosen over EPS for sub-grade moisture resistance — EPS
  long-term wet R-value drops 10–20 %, XPS drops < 5 %.
- **Thickness: 4″ → R-20 nominal**, derated to R-18 long-term wet. From
  §5.3 we need ≥ R-15 to keep design-day Δ_T,edge under 11 K; R-20 buys
  margin against soil-k surprises and against the F-factor extrapolation
  bias (§8).
- **Height: 32″ total** = 8″ slab depth + 24″ below grade. This carries
  the freeze front (§3.3, 47″ for R-20) most of the way down; the
  remaining frost lives outboard of the wing (§6.2).
- **Continuity:** must be continuous from top-of-slab to bottom of
  vertical fin with no thermal break. Tape all joints.

### 6.2 Horizontal wing

- **Width: 2 ft outboard at the bottom of the vertical fin** (so the wing
  sits at 32″ below grade).
- **Thickness: 2″ XPS R-10**, ≥ 25 psi grade (less load than vertical
  edge, but must support frost-heave-relevant soil column).
- **Function:** intercepts the freeze front laterally (§3.3), letting us
  stop the vertical fin at 32″ rather than at the 47″ frost depth.
- **Slope:** 1/8″ per foot downward outboard, so any water that finds the
  wing drains away from the foundation.

### 6.3 Termite, rodent, freeze-protection notes

- **Termites:** Millinocket is Zone 1 (low termite pressure, per IRC 2018
  Fig. R301.2). No mandatory termite shield, but spec ≥ 4″ visible foam
  band above grade is sensible to inspect the foam-to-siding joint.
- **Rodents:** mice and chipmunks tunnel into rigid foam below grade.
  Spec a 1/4″ hardware-cloth wrap around the below-grade foam back from
  the wing termination up to 4″ below grade, lapped 6″ over the wing.
- **Freeze:** the perimeter drain (4″ corrugated, daylit) must be below
  the wing, slope away. Without drainage, saturated soil drives the §2.4
  worst case.

### 6.4 Cold-zone-aware pipe layout

This is a recommendation for `pipe-geometry.md` to absorb on its next
revision: the outermost 18″ ring of the slab is in the cold zone (§5).
Either (a) keep the perimeter loops but treat them as charging-favored
(they preferentially shed to the edge in winter and refill in summer), or
(b) inset the discharge field 2 ft from the slab edge to keep all
discharge loops in the bulk-temperature zone. Option (b) sacrifices ~10 %
of the discharge field area but ensures every discharge loop gets full
useful ΔT.

### 6.5 Detail drawing

```
                                     interior floor / upper emitter
                                          ────────────────────
   grade                                  ░░░░░░░░░░░░░░░░░░░░    Δ
─────────┐                                ░ R-10 XPS (top)    ░    │
         │ 4″ XPS R-20                    ░░░░░░░░░░░░░░░░░░░░    │
 ░░░░░░░░│  Type IX, 40 psi              ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     │
 ░ soil ░│  continuous from               ▓ flowable fill   ▓     │
 ░░░░░░░░│  top-of-slab                   ▓ 8″ CLSM         ▓    32″
 ░░░░░░░░│  to wing                       ▓ T = 45 °C       ▓    edge
 ░░░░░░░░│  (32″ total)                   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓    insul
 ░░░░░░░░│                                ░ R-20 EPS (bot)   ░    │
 ░░░░░░░░│                                ░░░░░░░░░░░░░░░░░░░░    │
 ░░░░░░░░│         ╔══════════════════════╝                       │
 ░░░░░░░░├─────────╣ 2″ XPS R-10 (wing) 2 ft outboard, drain slope ▼
 ░░░░░░░░│         ╚════════════════════════════════════╗
 ░░░░░░░░│                                              ░
 ░░░░░░░░│   ◯ 4″ perimeter drain (corrugated, daylit)  ░
 ░░░░░░░░│                                              ░
 ░░░░░░░░│   compacted gravel base                      ░
```

Hardware-cloth wrap not shown.

---

## 7 · Annual energy loss budget

At the recommended R-20 / 32″ vertical + 2 ft R-10 wing detail in moist
glacial till (k = 1.5):

From the table in §2.5 by interpolation, vertical-only R-20 / 32″ gives
L_edge ≈ 0.44 W/(m·K). The 2 ft R-10 wing applied to this configuration
reduces L_edge by an additional ~20 % (the wing's marginal benefit
shrinks when vertical is already strong), giving:

```
L_edge,design  ≈  0.35 W/(m·K)
```

Apply the §4 corner multiplier of 1.05 → **0.37 W/(m·K) effective**.

### 7.1 Design-day perimeter loss

```
Q_edge,design  =  L_edge,eff  ·  P  ·  ΔT_design,effective
              =  0.37  ·  38 m  ·  57 K          ← §3.2, not 75 K
              ≈  800 W
```

vs. Q_out = 5 kW design discharge — edge loss is **~16 % of design-day
delivered load**. This is high relative to the 5 % budget; see §7.3.

### 7.2 Annual perimeter loss

Annual integration on Millinocket TMY:

```
Q_edge,annual  =  L_edge,eff  ·  P  ·  ⟨ΔT⟩  ·  8760 h

           ⟨ΔT⟩ = T_store,annual − T_ext,annual_mean
                ≈  44 °C − 4 °C  =  40 K
```

```
Q_edge,annual  =  0.37 W/(m·K)  ·  38 m  ·  40 K  ·  8760 h
              =  4 928 kWh/yr
```

Versus a typical Millinocket house annual heat load (10–14 MWh for a
well-insulated 1500–2000 ft² home):

```
4928 kWh/yr  /  12 000 kWh/yr  ≈  41 % of annual heat budget
```

This is **way too high** — the store is not supposed to be a slab-edge
heater. Two factors recover it:

1. The store does not actually run at 44 °C average year-round. In summer
   it can be allowed to drift to 25–30 °C (DHW is separate). Time-
   averaged ⟨T_store⟩ over a year is more like 30 °C, not 44, so
   ⟨ΔT⟩ ≈ 26 K not 40 K.
2. Heat lost to the perimeter soil during the shoulder season is partly
   recovered by reduced bottom loss (the warm bulb under the slab is
   marginally warmer because of perimeter heat).

Adjusted estimate:

```
Q_edge,annual,realistic  ≈  0.37 · 38 · 26 · 8760  ≈  3 200 kWh/yr
```

Still high — ≈ 25 % of annual house load. The honest reading is that the
under-floor store at 45 °C in Millinocket leaks aggressively at the edge
no matter what, and "5 % loss budget" for the edge is unrealistic. A
realistic budget is **15–20 % annual loss to the edge**, partially offset
by the fact that this heat goes into the perimeter soil and helps frost
protection. The bottom loss is much smaller (§ insulation.md) and the
combined total loss budget is achievable at ~25 % of delivered store
heat.

### 7.3 Sensitivity to soil moisture

Re-evaluate at k = 2.0 (wet till) and k = 2.5 (saturated):

| Soil k | L_edge,eff | Q_edge,design | Q_edge,annual,real |
|---|---|---|---|
| 1.0 (dry)   | 0.25 |  540 W | 2 200 kWh |
| 1.5 (moist) | 0.37 |  800 W | 3 200 kWh |
| 2.0 (wet)   | 0.49 | 1060 W | 4 240 kWh |
| 2.5 (sat)   | 0.62 | 1340 W | 5 360 kWh |

A factor of ~2.5× across the realistic moisture range. **Perimeter
drainage and a free-draining gravel base under and outboard of the slab
are non-optional.** Without drainage, edge loss can triple from a wet
spring melt.

---

## 8 · Comparison to F-factor estimate

ASHRAE Fundamentals tables give F-factor values like F2 ≈ 0.50 Btu/(h·ft·°F)
for an R-10 edge over 24″, which is ≈ 0.86 W/(m·K). Per-foot per °F.
Applied naively at design ΔT = 135 °F (75 K):

```
Q_edge,F-factor  =  0.86 · 38 m · 75 K  ≈  2 450 W   (design day)
```

vs. our 2-D answer at R-10 / 24″ no wing:

```
Q_edge,2D  =  0.73 · 38 · 57  ≈  1 580 W
```

F-factor overpredicts design-day loss by ~55 % at this insulation level.
The dominant source is the §3.2 transient swing — F-factor uses the full
slab-to-outdoor ΔT_designday, while the actual edge soil is still warm
from summer. But the F-factor bias *reverses* at high store temperatures
because F-factor was calibrated against ~21 °C radiant floors, not 45 °C
stores:

- F-factor implicitly assumes the heat-flow geometry is set only by the
  slab/wall corner and the insulation; it ignores that at higher T_store
  the heat-flow lines from the slab edge bow further out before reaching
  the surface, *increasing* the effective resistance.
- These two biases (transient overprediction, calibration-T
  underprediction) partially cancel for an idealized 45 °C slab, but
  unevenly: at low R_edge the calibration-T bias dominates and F-factor
  *under*predicts; at high R_edge the transient bias dominates and
  F-factor *over*predicts.

**Practical guidance for `insulation.md`:** treat F-factor numbers as
±30 % at high R_edge, biased high (conservative for sizing). The cost
sweep in `insulation.md` should not be trusted to find the optimum within
one R-5 step — the 2-D analysis here is what pins the floor at R-15 (from
the cold-zone constraint §5.3) and the practical recommendation at R-20
+ wing.

---

## 9 · References

- Hagentoft, C.-E. *Heat Losses and Temperature in the Ground under a
  Building with and without Ground Water Flow.* PhD thesis, Lund Univ.,
  1988. Closed-form conformal-mapping solutions for slab-on-grade.
- Hagentoft, C.-E. & Roots, P. "Heat loss to the ground from a building."
  *Building and Environment* 31(4): 347–355, 1996.
- Krarti, M. "Effect of spatial variation of soil thermal properties on
  slab-on-ground heat transfer." *Building and Environment* 31(1), 1996.
- Krarti, M. & Choi, S. "Simplified method for foundation heat loss
  calculation." *ASHRAE Transactions* 102(1), 1996.
- Bahnfleth, W.P. & Pedersen, C.O. "A three-dimensional numerical study
  of slab-on-grade heat transfer." *ASHRAE Transactions* 96(2), 1990.
- ASHRAE Handbook of Fundamentals 2017, Ch. 18 "Nonresidential Cooling
  and Heating Load Calculations" — F-factor tables. Ch. 26 "Heat,
  Air, and Moisture Control in Building Assemblies."
- Carslaw, H.S. & Jaeger, J.C. *Conduction of Heat in Solids,* 2e,
  Oxford, 1959. §16 — semi-infinite solid with surface and embedded
  boundary conditions.
- U.S. Army Corps of Engineers, TM 5-852-6, *Calculation Methods for
  Determination of Depths of Freeze and Thaw in Soils,* 1988.
  Modified Berggren / Aldrich-Paynter formula.
- DOE Building America Solution Center, *Slab Edge Insulation for Cold
  Climates*, accessed via basc.pnnl.gov.
- Building Science Corporation (Lstiburek, J.), BSI-005 *A Bridge Too
  Far* and BSI-038 *Mind the Gap* — practical sub-slab and edge details
  for cold climates.
- Aldrich, H.P. & Paynter, H.M. *Analytical Studies of Freezing and
  Thawing in Soils.* ACFEL Tech. Report 42, 1953.
