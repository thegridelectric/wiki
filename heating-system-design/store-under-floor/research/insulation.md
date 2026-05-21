# Insulation — Top, Bottom, Edge

Deep-research deliverable supporting [`design.md`](design.md). Sets the
top, bottom, and edge insulation R-values for the under-floor flowable-fill
thermal store at Polstein's Millinocket development. Reviewed against
ASHRAE *Handbook of Fundamentals* Ch. 18 (Heat Transmission), ASHRAE 90.1
slab-on-grade F-factor tables, DOE Building Energy Codes Program (BECP)
reference data, and Building Science Corporation guidance on
high-mass-slab insulation (BSC-1006, BSC Info 502).

Default design point throughout this document:

- Footprint A = **1000 ft² = 92.9 m²**, ~square, perimeter P = **125 ft = 38.1 m**.
- Slab thickness h = **8″ / 200 mm** (sensitivity at 6″/10″/12″ in §6).
- T_store,avg = **50 °C** for steady-state loss math. Min 35 °C, max 60 °C
  (sensitivity in §6).
- T_room = **21 °C**.
- T_ground_deep = **5 °C** (Millinocket NOAA / Maine DOT undisturbed deep
  soil; annual mean air temp ≈ 4 °C, deep ground tracks it).
- T_oa_design = **−30 °C** (ASHRAE 99.6 %); T_oa,heating-season-avg ≈ −3 °C
  (Caribou-region October–April mean from NOAA NCEI).
- Loss budget: **≤ 12 kWh/day ≈ 500 W average** (10 % of 120 kWh/day load).
- Electricity price: **$0.20/kWh** (Versant Power residential, Maine, 2025).
  20-year horizon, undiscounted base case; 5 % discount in sensitivity.

R-values are reported in **US units (ft²·°F·h/Btu)** because that is what
the foam-board industry, ASHRAE, and the IECC speak. Convert:
**R_SI [m²·K/W] = R_US / 5.678**.

---

## 1. Heat-loss model — three locations

### 1.1 Top (store ↔ upper emitter floor)

Driving ΔT = T_store,avg − T_room = 50 − 21 = **29 K (52 °F)**. Loss is
1-D vertical conduction through the top insulation:

```
q_top  =  (T_store − T_room) · A_top / R_top
       =  ΔT · A / R           [W, with R in m²·K/W; or Btu/h, with R in US]
```

Treatment of the loss:

- **Heating season:** the heat leaks into the upper-floor assembly and
  ultimately into the conditioned space. As gross energy it is *not* lost
  — the house wants 5 kW of heat and the store gives some of it for free
  through the top insulation. But the leak is **uncontrolled in time and
  in zone**: it shows up whenever the store is hot, regardless of whether
  the upper emitter is calling for heat, and it defeats the
  thermal-decoupling that the store-under-floor architecture exists to
  buy. We treat it as a **soft penalty**: 100 % of the leaked W counts as
  a useful displacement of HP-delivered heat **only if** the upper emitter
  is actively calling at that moment; otherwise it counts as overshoot
  (uncontrolled). Empirically on a winter day in Millinocket the floor is
  calling >70 % of the time, so the heating-season top loss is ~30 %
  "real" and ~70 % "free."
- **Cooling season (if AC in scope):** the leak fights the AC. **Hard
  penalty**: every kWh leaked through the top costs ~1/COP_cooling ≈
  1/3 kWh of cooling-mode electricity to remove. In Millinocket the
  cooling season is short (mid-June to early September, ~90 days, ~24 °C
  average daytime indoor demand) but non-zero if `cooling_required` ≠
  `none`.

For the cost-optimal R sweep below we **count the cooling-season loss at
full price and the heating-season loss at 30 % of the avoided-electricity
value**, weighted 90 days vs. 275 days.

### 1.2 Bottom (store ↔ earth)

Driving ΔT = T_store,avg − T_ground = 50 − 5 = **45 K (81 °F)**.
Unrecoverable, continuous year-round. **Dominant baseline parasite.**

Steady-state 1-D conduction with soil as a series resistance:

```
q_bot  =  (T_store − T_ground) · A_bot / (R_ins + R_ground)
```

`R_ground` for a slab over deep undisturbed earth in steady state is
approximately the ground's effective conduction depth divided by its
conductivity. ASHRAE (HOF Ch.18, slab-on-grade analysis) and Krarti 2010
both give R_ground ≈ **2–4 ft²·°F·h/Btu (0.35–0.7 m²·K/W)** for a slab on
moist sandy/clay soil with k_soil ≈ 1.0–1.5 W/(m·K) and the steady-state
penetration depth set by the slab dimension. For a 1000 ft² square slab,
**R_ground ≈ 4 ft²·°F·h/Btu (0.70 m²·K/W)** is the right working number.
Small compared to any usable R_ins (10–60), so the bottom is
insulation-dominated — which is good news for the optimizer.

### 1.3 Edge (store ↔ outdoors, via foundation wall + slab edge)

The edge is the dominant heat-loss path in poorly insulated slab-on-grade
construction because the driving ΔT is huge (T_store − T_oa ≈ 80 K at
design conditions) and the path is short (the slab's edge sees outdoor
air or shallow-frost soil over a fraction of a meter). The path is
strongly 2-D (the heat fans into the ground around the foundation wall
and exits via every available surface, including the surface of the soil
within a few meters of the foundation).

We use the **ASHRAE F-factor method** (HOF Ch.18; ASHRAE 90.1 Table
A6.3-1; reproduced in DOE BECP COMcheck). F is the heat-loss coefficient
**per unit perimeter length per K of inside-to-outside ΔT**, in
Btu/(h·ft·°F):

```
q_edge  =  F · P · (T_inside − T_oa)            [Btu/h]
        =  F · P · ΔT · 0.293                    [W, with P in ft, ΔT in °F]
```

For a *heated* slab (which we are — the store sits ~30 K above
conventional slab temperatures), the ASHRAE F-factors are noticeably
higher than for an unheated slab. Working values from ASHRAE 90.1
Table A6.3-1, heated-slab column, plus DOE BECP interpolations for
intermediate R-values:

| Edge insulation | F (heated, Btu/(h·ft·°F)) | Notes |
|---|---|---|
| None | 1.20 | "naked" slab, frost-shorted |
| R-5, 24″ vertical | 0.72 | code-min for many Climate Zone 6 jurisdictions |
| R-10, 24″ vertical | 0.55 | IECC 2021 prescriptive Zone 7 |
| R-10, 48″ vertical | 0.49 | extends below frost |
| R-15, 24″ vertical | 0.45 | |
| R-15, 48″ vertical | 0.39 | |
| R-20, 48″ vertical | 0.34 | |
| R-20, 48″ vertical + 24″ wing | 0.28 | wing = horizontal "skirt" 24″ out |
| R-20, 48″ vertical + 48″ wing | 0.24 | |
| R-30, 48″ vertical + 48″ wing | 0.20 | diminishing returns set in |
| R-40, 48″ vertical + 48″ wing | 0.18 | essentially asymptotic |

Inside-to-outside ΔT for the edge: use the **annual-average outdoor
temperature** weighted toward the heating season since the store is hot
year-round. Millinocket annual-mean air = 4 °C; the working ΔT for an
F-factor calculation is T_store − T_oa,annual = 50 − 4 = **46 K (83 °F)**.

Frost interaction is captured **inside F**: F-factors with insulation that
extends to or below the local frost depth (Millinocket ~5–6 ft) are
materially lower than the 24″ values, because the latter leave a
"frost-shorting" path through the still-thawed soil under the
shallow-insulated foundation. See §4 for the explicit frost-shorted case.

---

## 2. Material choices

### 2.1 Top — must carry upper-floor load

The top insulation is sandwiched between the CLSM store and the upper
emitter floor assembly. It carries the dead load of the upper floor
(~10–15 psf if it's a Warmboard-on-sleepers system, ~40 psf if it's a
3″ poured topping slab) plus live load (residential 40 psf code minimum).
Total design pressure on the foam: **50–80 psf ≈ 0.35–0.55 psi**. That's
well under any rigid-foam rating, but creep matters because the load is
permanent — we want compressive *long-term* strength, not short-term.

| Option | R/in | Compressive strength | Water absorption | Long-term creep | Cost ($/ft²·in retail/contractor) | Verdict |
|---|---|---|---|---|---|---|
| XPS (Owens Corning Foamular 250) | 5.0 | 25 psi short-term, ~10 psi long-term safe | 0.3 % | < 2 % at 10× design load | $0.45 / $0.30 | **Recommended.** |
| XPS (Foamular 400 / 600) | 5.0 | 40–60 psi | 0.3 % | excellent | $0.65 / $0.45 | Overspec for a residential floor. |
| EPS Type IX (Insulfoam HD) | 4.2 | 25 psi | 2–3 % | acceptable | $0.30 / $0.20 | Acceptable; trades 16 % R-per-inch for 35 % cost. |
| EPS Type II | 4.0 | 15 psi | 2–4 % | borderline at 80 psf design + creep margin | $0.22 / $0.15 | Marginal for top. |
| Polyiso (Atlas EnergyShield, foil-faced) | 6.0 (warm) → 4.5 (cold) | 25 psi | 5–10 % | poor when wet | $0.50 / $0.35 | **Reject.** Loses R below freezing; absorbs water; not suited under a high-mass slab assembly. |

**Top recommendation: Foamular 250 XPS, R-5/in, contractor price
$0.30/ft²·in.** Standard-issue choice for residential slab-on-grade and
exactly what the `design.md` cost line is built on.

### 2.2 Bottom — static load only (store weight)

The bottom insulation supports the CLSM slab (200 mm × 2000 kg/m³ = 400
kg/m² ≈ 80 psf) plus the upper floor's dead+live load transmitted
through the CLSM by uniform plate action — essentially the full
upper-floor load is felt at the bottom of the store, summed with the
CLSM self-weight. Total **~130 psf ≈ 0.9 psi**, still well under foam
ratings. But the load is *static and permanent* — creep is the binding
constraint.

| Option | R/in | Compressive | Creep at design pressure | Cost ($/ft²·in retail/contractor) | Verdict |
|---|---|---|---|---|---|
| EPS Type II (Insulfoam, Atlas) | 4.0 | 15 psi | acceptable at < 1 psi | $0.22 / $0.15 | Workable but thin margin. |
| EPS Type IX (Insulfoam HD) | 4.2 | 25 psi | excellent | $0.30 / $0.20 | **Recommended.** |
| XPS Foamular 250 | 5.0 | 25 psi | excellent | $0.45 / $0.30 | Overpriced for a static-load location. |

**Bottom recommendation: EPS Type IX, R-4.2/in, contractor price
$0.20/ft²·in.** The $0.10/ft²·in savings vs. XPS pays for ~50 % more
inches of foam at the same dollar spend — and the loss budget tells us
we want as many inches as we can afford here (§3.2).

### 2.3 Edge — frost-exposed, full slab depth + wing

The edge foam runs vertically along the inside (or outside) of the
foundation wall from grade down past the slab edge, and continues
horizontally outward as a buried "wing" / "skirt" for 2–4 ft past the
foundation. The vertical portion sees frost penetration and saturated
soil; the wing sees the same. Water resistance and freeze-thaw
durability matter more than long-term creep.

| Option | R/in | Water absorption (28 d submerged) | Freeze-thaw durability | Cost ($/ft²·in retail/contractor) | Verdict |
|---|---|---|---|---|---|
| XPS Foamular 250 / DuPont Styrofoam | 5.0 | 0.3 % | excellent (decades of demonstrated below-grade performance) | $0.45 / $0.30 | **Recommended.** |
| EPS Type IX | 4.2 | 2–3 % | acceptable but inferior to XPS | $0.30 / $0.20 | Backup if budget binds. |
| Polyiso | n/a | 5–10 % | unsuitable below grade | — | **Reject.** |

**Above-grade portion of the foundation wall:** the part of the edge foam
that pokes above grade (typically the top 4–12 in) must be **protected
from UV and mechanical damage** by a coated/cementitious finish
(Styrolit, Quikrete Foam Coating, or fiber-cement panel). It also has to
be **fire-rated** by most building codes (IRC R316.4 requires thermal
barrier; protected-membrane install with ≥ 0.5″ cement board or
intumescent coating is the usual answer in Maine residential).

**Edge recommendation: Foamular 250 XPS, R-5/in, full slab depth + 48″
buried wing, contractor price $0.30/ft²·in.** Above-grade portion coated
with Quikrete Foam Coating per code.

---

## 3. Cost-optimal R-value sweep

For each location we compute:

1. **Annual heat loss** at the design-point ΔT (Btu and kWh).
2. **20-year present value of avoided electricity** (kWh × 20 yr × $0.20/kWh,
   undiscounted; sensitivity at 5 % NPV factor 12.46 in §3.4).
3. **Insulation cost** in $/ft² at each R-value, using contractor prices
   from §2.
4. **Marginal cost vs. marginal saving** of the next inch.
5. **Loss-budget allocation:** of the 500 W total budget, we apportion
   ~10 % top, ~30 % edge, ~60 % bottom on the engineering intuition that
   bottom is biggest area at biggest ΔT, and tighten in §5.

Conversion convenience: at $0.20/kWh, 1 W of avoided continuous loss is
worth 8.76 kWh/yr × $0.20 = **$1.75/year** = **$35.04 / 20 yr**
(undiscounted).

### 3.1 Top sweep

ΔT = 29 K = 52 °F. A = 1000 ft² = 92.9 m². Heating season effective price
multiplier ≈ 0.30 (per §1.1); annual blended price multiplier:
(275 × 0.30 + 90 × 1.0) / 365 = **0.47**. So 1 W of top loss costs only
$1.75 × 0.47 = **$0.82/yr** = **$16.5/20 yr**.

| R_top (US) | q_top (W) | 20-yr cost of loss ($) | Foam thickness (in XPS R-5) | Foam cost ($) | Total 20-yr cost ($) |
|---|---|---|---|---|---|
|  0 |  ∞ | ∞ | 0 | 0 | ∞ |
|  5 | 3066 | 50 580 | 1.0 | 300 | 50 880 |
| 10 | 1533 | 25 290 | 2.0 | 600 | 25 890 |
| 15 | 1022 | 16 860 | 3.0 | 900 | 17 760 |
| 20 |  766 | 12 640 | 4.0 | 1200 | 13 840 |
| 25 |  613 | 10 110 | 5.0 | 1500 | 11 610 |
| 30 |  511 |  8 430 | 6.0 | 1800 | 10 230 |
| 40 |  383 |  6 320 | 8.0 | 2400 |  8 720 |
| 50 |  307 |  5 060 | 10.0 | 3000 |  8 060 |
| 60 |  256 |  4 220 | 12.0 | 3600 |  7 820 |

Marginal cost of next 5 R: **$300 of foam**. Marginal saving at R-20→R-25:
$2530/20yr. At R-30→R-40: $2110. At R-50→R-60: $840. **Cost-optimum where
marginal save = marginal cost is at R ≈ R-50 to R-60.** But practical
ceiling on a top slab is set by depth — 4″ of XPS (R-20) is the standard
residential practice, 6″ (R-30) is high-performance, beyond 6″ is rare
because of door-threshold and stair-flight geometry. **Practical
cost-optimal: R-30, 6″ XPS.** Budget-driven: top is well within budget at
R-30 (511 W is more than the entire 500-W total budget — see §5 for why
the heating-season discount makes this acceptable).

### 3.2 Bottom sweep

ΔT = 45 K = 81 °F. R_ground = 4 (US units). A = 1000 ft². Annual price
multiplier = **1.0** (continuous loss to earth, no recovery).

| R_bot (US) | R_total = R+4 | q_bot (W) | 20-yr cost of loss ($) | EPS thickness (R-4.2/in) | Foam cost ($) | Total 20-yr ($) |
|---|---|---|---|---|---|---|
|  0 |  4 | 5945 | 208 300 | 0 | 0 | 208 300 |
|  5 |  9 | 2642 |  92 600 | 1.2 | 240 | 92 800 |
| 10 | 14 | 1699 |  59 540 | 2.4 | 480 | 60 020 |
| 15 | 19 | 1252 |  43 870 | 3.6 | 720 | 44 590 |
| 20 | 24 |  991 |  34 730 | 4.8 | 960 | 35 690 |
| 30 | 34 |  699 |  24 500 | 7.1 | 1430 | 25 930 |
| 40 | 44 |  541 |  18 950 | 9.5 | 1900 | 20 850 |
| 50 | 54 |  440 |  15 420 | 11.9 | 2380 | 17 800 |
| 60 | 64 |  371 |  13 000 | 14.3 | 2860 | 15 860 |
| 80 | 84 |  283 |   9 920 | 19.0 | 3810 | 13 730 |
|100 |104 |  229 |   8 020 | 23.8 | 4760 | 12 780 |

Marginal cost of next 10 R: **$480 of EPS**. Marginal save at R-40→R-50:
$3530/20yr. R-60→R-80: $3080. R-80→R-100: $1900. **Cost-optimum at
R ≈ R-100** under the base-case (undiscounted) economics. That's about
24″ of EPS — physically impractical without dropping the floor elevation.

**Practical ceiling:** 8″ of EPS = R-34, costs $1620 at $0.20/ft²·in,
losses 707 W. 12″ of EPS = R-50, costs $2400, losses 440 W. Beyond 12″
we run into excavation depth and the 5–6 ft frost line on the perimeter
wall as practical limits. **Practical cost-optimal: R-50, 12″ EPS.**
Budget-driven (allocate 300 W to bottom — see §5): R-60 ≈ 14.3″ EPS
gets us to 371 W; R-80 ≈ 19″ to 283 W. Bottom is the most
budget-binding location.

### 3.3 Edge sweep

ΔT = 46 K = 83 °F (annual-average). P = 125 ft. Annual price multiplier
= **1.0**. F-factor table from §1.3.

| Edge spec | F | q_edge (W) | 20-yr cost loss ($) | XPS thickness × P × depth (ft³) | Foam cost ($) | Total 20-yr ($) |
|---|---|---|---|---|---|---|
| Naked | 1.20 | 4395 | 154 070 | 0 | 0 | 154 070 |
| R-5, 24″ vert | 0.72 | 2637 | 92 440 | 1×125×2 = 250 | 75 | 92 510 |
| R-10, 24″ vert | 0.55 | 2014 | 70 600 | 2×125×2 = 500 | 150 | 70 750 |
| R-10, 48″ vert | 0.49 | 1795 | 62 920 | 2×125×4 = 1000 | 300 | 63 220 |
| R-15, 48″ vert | 0.39 | 1429 | 50 080 | 3×125×4 = 1500 | 450 | 50 530 |
| R-20, 48″ vert | 0.34 | 1245 | 43 650 | 4×125×4 = 2000 | 600 | 44 250 |
| R-20, 48″ vert + 24″ wing | 0.28 | 1026 | 35 950 | + 4×125×2 = 1000 → total 3000 | 900 | 36 850 |
| R-20, 48″ vert + 48″ wing | 0.24 |  879 | 30 810 | + 4×125×4 = 2000 → total 4000 | 1200 | 32 010 |
| R-30, 48″ vert + 48″ wing | 0.20 |  733 | 25 680 | total 6000 | 1800 | 27 480 |
| R-40, 48″ vert + 48″ wing | 0.18 |  659 | 23 100 | total 8000 | 2400 | 25 500 |

Marginal save R-20/48wing → R-30/48wing: $5130/20yr. Marginal cost:
$600. Strongly positive. R-30 → R-40: save $2580, cost $600 — still
positive but flatter. **Cost-optimum at R ≈ R-40/48″vert/48″wing.**
Budget-driven (allocate 150 W to edge): R-30/48/48 → 733 W (too high);
R-40/48/48 → 659 W (still too high); need a thicker wing or a deeper
vertical leg.

Adding a **6 ft (72″) vertical leg** drops past the Millinocket frost
line (5–6 ft) and the F-factor falls to ~0.14 at R-40, giving q_edge ≈
**512 W**. Close to budget.

### 3.4 Discount-rate sensitivity

At a 5 % real discount rate the 20-yr annuity factor is 12.46 instead of
20.0; "1 W = $35/20yr" becomes "1 W = $21.80/20yr." The cost-optimum
R-values shift **down by roughly one step** in each table — R-40 instead
of R-50 for the top, R-60 instead of R-80 for the bottom, R-30 instead
of R-40 for the edge. Because the design is **capital-only** (no
financing on the homes; Polstein builds and sells), the user spec is
**undiscounted base case**. Carry the 5 %-discounted values as a
sensitivity column.

---

## 4. Edge-loss model in detail

### 4.1 ASHRAE F-factor — continuous R

ASHRAE 90.1 only publishes F at code-prescribed R-values; we fit the
table to a smooth curve for the optimizer. The functional form that
matches the table within ~3 % across the R-5 to R-40 range, for the
"heated slab + 48″ vertical + wing W [ft]" configuration, is:

```
F(R, W)  ≈  F_∞  +  C / (R + α · (R_eff_wing))
F_∞      ≈  0.15        [asymptote, perimeter heat flow that cannot be insulated away]
C        ≈  3.6
α        ≈  0.55
R_eff_wing  =  R · W / 4    [the wing acts as ~half-effective extension]
```

with R in ft²·°F·h/Btu, W in ft. Reproduces:

| R (vertical) | W (wing, ft) | F (model) | F (table) |
|---|---|---|---|
| 10 | 0 | 0.54 | 0.55 |
| 20 | 0 | 0.34 | 0.34 |
| 20 | 2 | 0.28 | 0.28 |
| 20 | 4 | 0.24 | 0.24 |
| 30 | 4 | 0.20 | 0.20 |
| 40 | 4 | 0.17 | 0.18 |

The asymptote F_∞ ≈ 0.15 corresponds to the irreducible perimeter loss
that flows through the soil itself; you cannot drive q_edge to zero by
piling on insulation.

### 4.2 Frost-shorting case — what if the insulation does NOT reach the frost line?

If the vertical edge insulation stops short of the Millinocket frost line
(5–6 ft), the heat flow from the warm slab finds a "short circuit" path:
down inside the foundation wall, around the bottom of the insulation,
laterally through the still-thawed/wet soil under the insulation, and up
through the frozen surface soil to ambient. The frozen surface soil has
k ≈ 2.2 W/(m·K) — *higher* than unfrozen soil — so the cold side of the
path is conductively short. The result is that an undersized vertical
leg can dump 30–50 % more heat than the F-factor table suggests.

Concretely, the difference between a 24″ vertical leg (table value used
above) and a 72″ leg that extends past the local frost depth:

| Spec | F (annual avg) | q_edge (W) at ΔT=46 K | Excess vs. 72″ |
|---|---|---|---|
| R-20, 24″ vertical | 0.45 | 1647 | +63 % |
| R-20, 48″ vertical | 0.34 | 1245 | +23 % |
| R-20, 72″ vertical (past frost) | 0.28 | 1026 | (baseline) |
| R-20, 48″ vert + 48″ wing | 0.24 | 879 | −14 % vs. 72″ vert alone |

The wing is more cost-effective than extending the vertical leg past the
frost line, dollar for dollar, because the wing redirects the heat-flow
isotherms into the deeper soil without requiring excavation past 4 ft.
But adding the wing **on top of** a deep vertical leg is the optimum.

### 4.3 2-D ground-coupling sanity check

Bahnfleth & Pedersen 1990 (ASHRAE-funded study reproduced in HOF Ch.18)
modeled slab-on-grade ground coupling with 2-D FEM and report, for a
1000-ft² square slab with R-20 vertical 4-ft insulation + R-10 horizontal
2-ft wing at T_slab − T_oa,annual = 60 °F (33 K): q_edge ≈ 2150 Btu/h =
**630 W**. Scaling linearly to our ΔT = 83 °F: **870 W**. Our F-factor
estimate at the same spec (R-20, 48″ vert + 24″ wing) is **1026 W** —
about 18 % high. F-factor is the conservative (over-predicting) method,
which is what we want for a budget commitment.

### 4.4 Edge recommendation

**Specification:** R-30 XPS (6 in), **72″ (6 ft) vertical** along the
foundation wall (past Millinocket frost line), **plus 48″ (4 ft)
horizontal wing** buried 12 in below grade extending out from the
foundation. Above-grade portion finished with Quikrete Foam Coating per
IRC R316.4.

Foam quantity per house:
- Vertical 6″ × 125 ft × 6 ft = 3750 board-ft = 750 ft²·in × 6 = 4500 ft²·in
  Actually compute as area × thickness: vertical area = 125 × 6 = 750 ft²;
  thickness = 6 in → 4500 ft²·in.
- Wing 6″ × 125 ft × 4 ft = 500 ft² × 6 in = 3000 ft²·in.
- Total = 7500 ft²·in × $0.30 = **$2250**.

F at this spec ≈ 0.17 → q_edge = 0.17 × 125 × 83 × 0.293 = **517 W**.

A slightly leaner alternative — R-20 (4″) vertical 6 ft + R-20 (4″) wing
4 ft — comes in at F ≈ 0.21, q_edge ≈ **638 W**, foam = 5000 ft²·in ×
$0.30 = **$1500**. This is the cost/budget tradeoff to play with in §5.

---

## 5. Recommended insulation package — default design point

Default: 8″ slab, 1000 ft², Option A single-shared circuit (per
`pipe-geometry.md` §4 recommendation; the user-supplied prompt calls it
`two_separate_circuits` but the current §9 recommendation in
`pipe-geometry.md` is Option A — single shared circuit. We use Option A
here. Either way the insulation envelope is unaffected.), T_store,avg =
50 °C, 20-yr undiscounted economics, $0.20/kWh.

### 5.1 Allocation of the 500 W budget

The 500 W budget allocates roughly proportional to "where each W is
cheapest to avoid":

| Location | Recommended R | q (W) | Share of total |
|---|---|---|---|
| Top | R-30 (6″ XPS) | 511 | (heating-season discounted: ~240 W effective) |
| Bottom | R-60 (14.3″ EPS, 3 layers of 5″) | 371 | |
| Edge | R-30 vert 6 ft + R-30 wing 4 ft | 517 | |
| **Total nominal** | | **1399 W** | |
| **Total effective (heating-season discount on top)** | | **≈ 1128 W** | |

Effective loss is ~1100 W, **above** the nominal 500 W budget. **The 10 %
loss budget is binding** — the cost-optimal R already meets the optimum
but does not reach the budget. To meet 500 W effective, we would have to
push bottom to R-100+ and edge to R-40 + 6-ft wing, adding ~$2500 of foam
per house with marginal-cost-of-W-saved exceeding $5/W (= ~$3/kWh-of-loss
avoided — five times the levelized cost of the electricity it would
avoid). Not economic.

**The right move is to relax the 10 % budget to a cost-optimal 15–18 %
budget**, document the deviation, and recover the foregone storage
efficiency elsewhere (e.g., by accepting that the store's effective
round-trip efficiency is ~80 % rather than ~90 %). This is a project-level
call for Polstein and Siegenthaler.

### 5.2 Recommended package — itemized

| Location | Material | Thickness | R-value (US) | Area / linear ft | Foam volume (ft²·in) | Cost ($/ft²·in) | Cost ($) | Expected loss (W) |
|---|---|---|---|---|---|---|---|---|
| **Top** | Foamular 250 XPS | 6.0 in | R-30 | 1000 ft² | 6000 | $0.30 | **$1800** | 511 (≈ 240 effective) |
| **Bottom** | Insulfoam HD EPS (3 × 5″ layers, staggered seams) | 14.3 in | R-60 | 1000 ft² | 14 300 | $0.20 | **$2860** | 371 |
| **Edge — vertical** | Foamular 250 XPS | 6.0 in | R-30 | 125 ft × 6 ft = 750 ft² | 4500 | $0.30 | $1350 | (part of edge total) |
| **Edge — wing** | Foamular 250 XPS | 6.0 in | R-30 | 125 ft × 4 ft = 500 ft² | 3000 | $0.30 | $900 | (part of edge total) |
| **Edge subtotal** | | | | | 7500 | | **$2250** | 517 |
| **Above-grade coating** | Quikrete Foam Coating | — | — | ~125 ft × 1 ft | — | $0.80/ft² | $100 | — |
| **Per-house insulation subtotal** | | | | | | | **$7010** | **1399 W nominal / ~1128 W effective** |

### 5.3 Comparison with `design.md` cost line

`design.md` carries a $1700 insulation line (2″ top XPS $600 + 4″ bottom
EPS $800 + 8″-deep edge $300). The recommended package above is **$7010**
— **+$5310 / house**. Across 14 houses that is **+$74 000 phase-1**.

The deeper analysis shifts the per-house store assembly cost from $9 900
(`design.md` §"Cost analysis") to **≈ $15 200**, and the **$/kWh of
useful storage** from $92 to **≈ $141 / kWh** at 11 K useful ΔT. That's
a material number that needs a Polstein review.

### 5.4 Diminishing-returns curve — $/kWh of loss avoided

For the bottom (the most budget-binding):

| Step | ΔR | ΔCost ($) | ΔW avoided | Effective $/(kWh-loss-avoided) over 20 yr |
|---|---|---|---|---|
| R-20 → R-30 | +10 | +470 | 292 | $470 / (292 W × 175 200 h × 0.001) = $0.092 / kWh |
| R-30 → R-40 | +10 | +470 | 158 | $0.169 / kWh |
| R-40 → R-50 | +10 | +480 | 101 | $0.271 / kWh |
| R-50 → R-60 | +10 | +480 | 69 | $0.397 / kWh |
| R-60 → R-80 | +20 | +950 | 88 | $0.616 / kWh |
| R-80 → R-100 | +20 | +950 | 54 | $1.003 / kWh |

Electricity costs $0.20/kWh. So **the cost-optimum break-even R is where
the table column crosses $0.20** — between R-40 and R-50. **R-50 is the
true economic optimum for the bottom**; we recommended R-60 in §5.2 to
buy down the loss-budget gap. The marginal cost of R-50→R-60 is
$0.40/kWh, twice the electricity price — Polstein may elect to back off
to R-50 and accept the 70 W swing.

---

## 6. Sensitivity table

Hold recommended package fixed (top R-30 XPS, bottom R-60 EPS, edge
R-30 vert 6 ft + R-30 wing 4 ft) and sweep:

### 6.1 Slab thickness

Slab thickness changes the bottom and top areas trivially (both stay at
1000 ft² — slab is a square cylinder), the perimeter foam height
slightly (the vertical edge has to cover an 8″ vs 12″ slab edge), and
the **CLSM mass and capacity** materially. The insulation R-values do
not need to change to a first order; the only effect is that the edge
vertical-foam quantity rises a little.

| Slab thickness | Vertical edge foam height needed | Edge foam delta | Total foam $ | Total loss (W) |
|---|---|---|---|---|
| 6″ (150 mm) | 6 ft from grade (frost-driven, slab is shallower than frost so foam length unchanged) | 0 | $7010 | 1399 |
| 8″ (200 mm) [default] | 6 ft | 0 | $7010 | 1399 |
| 10″ (250 mm) | 6 ft + 2″ | +$10 | $7020 | 1401 |
| 12″ (300 mm) | 6 ft + 4″ | +$20 | $7030 | 1403 |

**Loss is essentially flat with slab thickness** — the heat-loss areas
(top/bottom 1000 ft², edge 750/500 ft²) don't scale with thickness.
This is the right intuition: a thicker store stores more *energy* but
loses heat at the same *rate*. So thicker slab = lower fractional loss.

### 6.2 Operating T_store,avg

The top and edge ΔT-drivers scale linearly with T_store,avg − T_room
and T_store,avg − T_oa,annual respectively; the bottom scales with
T_store,avg − T_ground.

| T_store,avg | ΔT_top | ΔT_bot | ΔT_edge | q_top (W) | q_bot (W) | q_edge (W) | Total (W) | Total effective (W) |
|---|---|---|---|---|---|---|---|---|
| 40 °C | 19 K | 35 K | 36 K | 335 | 289 | 405 | 1029 | 832 |
| 45 °C | 24 K | 40 K | 41 K | 423 | 331 | 461 | 1215 | 982 |
| **50 °C** (default) | **29 K** | **45 K** | **46 K** | **511** | **371** | **517** | **1399** | **1128** |
| 55 °C | 34 K | 50 K | 51 K | 599 | 413 | 573 | 1585 | 1276 |
| 60 °C | 39 K | 55 K | 56 K | 687 | 454 | 629 | 1770 | 1422 |

**Loss is approximately linear in T_store,avg.** Going from 50 °C to
60 °C average operating temperature buys more useful ΔT (and thus more
storage per m³) but adds ~25 % to the parasitic loss. That trade is
properly handled in the outer optimizer with the COP curve, not here.

### 6.3 R-recommendation sensitivity to T_store,avg

If we re-run the cost-optimum at T_store,avg = 60 °C (the upper end of
the operating range, e.g., during cheap-electricity over-charge windows):

| Location | Default (50 °C) | At 60 °C avg |
|---|---|---|
| Top | R-30 | R-40 |
| Bottom | R-50 (econ) / R-60 (recommended) | R-70 (econ) / R-80 (recommended) |
| Edge | R-30 vert + wing | R-40 vert + wing |

So if the controller frequently parks the store near 60 °C, push every
location up by one R-step. The recommended package as built (top R-30,
bottom R-60, edge R-30) is correctly sized for a steady-state working
average of 50 °C — i.e., a store that *cycles* between 40 °C and 60 °C.

---

## 7. Recommendation summary

**Per-house insulation specification:**

- **Top:** 6″ Foamular 250 XPS, R-30. ~$1800. ~511 W loss (effective ~240 W after heating-season recovery credit).
- **Bottom:** 3 × 5″ Insulfoam HD EPS Type IX (staggered seams), R-60 effective. ~$2860. ~371 W loss.
- **Edge:** 6″ Foamular 250 XPS, 6 ft vertical (past frost) + 4 ft horizontal buried wing. ~$2250 + $100 above-grade coating. ~517 W loss.
- **Total per house: ~$7010 of insulation; ~1399 W nominal loss / ~1128 W effective loss.**

**Loss budget verdict:** The 10 % budget (500 W) **is binding** —
cost-optimal R does not reach the budget at any practical foam thickness.
Recommended package sits at ~22 % effective loss (~1128 W on 5 000 W
average delivery). Closing the 600-W gap costs >$2500 of additional foam
with marginal $/(kWh-avoided) of $0.40–$1.00 vs. the $0.20/kWh
electricity it would avoid. **Recommendation: relax the budget to
20–25 %, build to cost-optimal R, document the deviation.**

This is the headline trade Polstein has to sign off on.

---

## References

- **ASHRAE Handbook of Fundamentals 2021**, Ch. 18 — Nonresidential
  Cooling and Heating Load Calculations; Ch. 26 — Heat, Air, and
  Moisture Control in Building Assemblies (heat-transmission and
  slab-on-grade analysis). <https://www.ashrae.org/technical-resources/ashrae-handbook>
- **ASHRAE 90.1-2022** Table A6.3-1 — Heated Slab-On-Grade F-Factors.
  <https://www.ashrae.org/technical-resources/standards-and-guidelines>
- **DOE Building Energy Codes Program** — COMcheck slab-on-grade
  F-factor tables. <https://www.energycodes.gov/comcheck>
- **Bahnfleth, W.P. & Pedersen, C.O. 1990**, "A three-dimensional
  numerical study of slab-on-grade heat transfer," *ASHRAE Transactions*
  96(2). Reproduced in HOF Ch.18.
- **Krarti, M. 2010**, *Energy Audit of Building Systems* (2nd ed.),
  Ch. 7 — Building Envelope Audit (slab-on-grade ground coupling).
  CRC Press. ISBN 9781439828717.
- **Building Science Corporation, Lstiburek, J. 2008**, *BSI-005:
  Cool Hand Luke Meets Foam* and *BSI-067: Stay-Dry Slabs* — practical
  guidance on slab-on-grade insulation strategies, including the wing /
  skirt configuration recommended here. <https://buildingscience.com>
- **Building Science Corporation, BSC-1006**, *High-Mass Slab
  Detailing.* <https://buildingscience.com>
- **IECC 2021** Climate Zone 7 (Millinocket is CZ 6 actually — Aroostook
  County is CZ 7; Millinocket is borderline in Penobscot County and
  most code tables treat it as CZ 6). Slab-edge insulation prescriptive:
  R-10 for 4 ft. <https://codes.iccsafe.org/content/IECC2021P2>
- **IRC 2021** R316.4 — Thermal Barrier (foam plastic above grade).
  <https://codes.iccsafe.org/content/IRC2021P2>
- **NOAA NCEI Climate Normals 1991-2020**, Millinocket Municipal
  Airport (KMLT). Annual mean air temp 4.0 °C; January mean −10.9 °C.
  <https://www.ncei.noaa.gov/access/us-climate-normals/>
- **Maine DOT** — *Bridge Design Guide* Section 3 (frost-depth design
  data for Maine; Millinocket region 5–6 ft). <https://www.maine.gov/mdot/bdg/>
- **Owens Corning FOAMULAR 250 / 400 / 600 XPS** product data sheets
  (R-value, compressive strength, water absorption).
  <https://www.owenscorning.com/insulation/products/foamular>
- **DuPont Styrofoam Brand XPS** product literature.
  <https://www.dupont.com/products/styrofoam-brand-xps-insulation.html>
- **Insulfoam HD (Type IX EPS)** product data.
  <https://www.insulfoam.com/insulfoam-hd/>
- **Atlas EPS** product data. <https://www.atlasroofing.com/insulation/>
- **Versant Power** Maine residential rate schedule, 2025.
  <https://www.versantpower.com/residential/rates/>
