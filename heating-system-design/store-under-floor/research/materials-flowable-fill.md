# Materials — Flowable Fill (CLSM) for the Under-Floor Thermal Store

Research-grade reference document for the cement-sand flowable fill used as
the storage medium in the under-floor thermal store. Companion to
[`design.md`](design.md); supersedes the working numbers in the Materials
section there where the two disagree (see [§7 Recommendation](#7-recommendation)).

The defining constraint: the store is **non-structural** (upper floor floats
on insulation above it), so we are free to drop coarse aggregate and use a
cement-sand-water CLSM mix optimized for cost, pumpability and thermal
mass — accepting the thermal-conductivity penalty vs. structural concrete.

---

## 1. Recommended mix

CLSM (Controlled Low-Strength Material) per **ACI 229R-13**. The store
application calls for a **sand-rich, no-fly-ash or low-fly-ash mix**: we
want the highest practical density and conductivity within the CLSM
envelope, since the store's job is thermal mass, not lightness or
excavatability margin.

The FHWA-published "low fly ash content" sand mix is a published baseline
that closely matches our intent (high sand, modest cement, low fly ash, no
foam):

| Constituent | kg/m³ | lb/yd³ | Source |
|---|---|---|---|
| Portland cement (Type I/II) | 59 | 100 | FHWA Fly Ash Facts, Table 5-2 |
| Fly ash (Class F or C) | 178 | 300 | FHWA Fly Ash Facts, Table 5-2 |
| Fine aggregate (concrete sand, ASTM C33) | 1,542 | 2,600 | FHWA Fly Ash Facts, Table 5-2 |
| Water | 297 | 500 | FHWA Fly Ash Facts, Table 5-2 |
| **Total wet density** | **≈ 2,076** | **≈ 3,500** | FHWA Fly Ash Facts, Table 5-2 |
| 28-day unconfined compressive strength | 1.0–1.4 MPa | 150–200 psi | FHWA Fly Ash Facts |

Source: FHWA, *Fly Ash Facts for Highway Engineers*, Chapter 5 — Fly Ash in
Flowable Fill, Table 5-2.
<https://www.fhwa.dot.gov/pavement/recycling/fach05.cfm>

Per **NRMCA CIP 17** and the **FlowableFill.org guide spec**, the broader
proportioning envelope ACI 229R-13 sanctions is:

- Portland cement: 50–200 lb/yd³ (30–120 kg/m³)
- Fly ash: 50–300 lb/yd³ (30–180 kg/m³) — optional
- Fine aggregate (sand): 2,400–3,000 lb/yd³ (1,425–1,780 kg/m³)
- Water: 300–500 lb/yd³ (180–300 kg/m³)
- Admixtures as required

Source: FlowableFill.org Guide Specification for CLSM (cites ACI 229R).
<https://www.flowablefill.org/downloads/CLSMSpecifications1.pdf>

Source: NRMCA CIP 17 — Flowable Fill.
<https://www.nrmca.org/wp-content/uploads/2021/01/17pr.pdf>

**Recommended order language to supplier:**

> CLSM per ACI 229R-13, sand-rich excavatable mix, target 28-day f'c =
> 150–250 psi (1.0–1.7 MPa), wet density ≥ 2,000 kg/m³ (125 lb/ft³),
> slump 6–10 in (150–250 mm), normal-set (no Type III, no accelerator),
> low-bleed, fly-ash content ≤ 200 lb/yd³.

Rationale for staying near the upper end of the strength/density band:
denser mix → higher k and higher ρc_p (both are what the store is for),
and 150–250 psi is still far below anything that would be hard to drill
through if a future PEX repair is needed.

---

## 2. Thermal property table

All values are for **cured, ambient-humidity** CLSM unless noted. The
single biggest source of spread is **moisture state** — k roughly doubles
from oven-dry to fully saturated for a cement-sand matrix, because water
(k ≈ 0.6 W/m·K) displaces air (k ≈ 0.03 W/m·K) in the pore network.

| Property | Oven-dry | Cured, in-service (recommended) | Saturated | Source |
|---|---|---|---|---|
| Density ρ (kg/m³) | 1,850–1,950 | **1,950–2,100** | 2,000–2,150 | FHWA Ch.5 (sand mix 2,076); ACI 229R-13 (typical 1,840–2,320) |
| Specific heat c_p (kJ/kg·K) | 0.80–0.90 | **0.90–1.00** | 0.95–1.05 | Stolarska & Strzałkowski 2020 (mortar VHC 1.70–1.93 MJ/m³K → c_p ≈ 0.85–1.0); cement-mortar review |
| Volumetric heat capacity ρc_p (MJ/m³·K) | 1.55–1.75 | **1.85–2.05** | 1.95–2.20 | Stolarska & Strzałkowski 2020, Table for dry & saturated mortar (1.70–1.93 MJ/m³K) |
| Thermal conductivity k (W/m·K) | 0.5–0.8 | **0.9–1.1** | 1.2–1.7 | Kim et al. 2018/2019 (CLSM by-products 0.84–0.87 ambient); Stolarska & Strzałkowski 2020 (mortar 1.23–1.67 dry, 2.35–2.54 sat); Eltayeb et al. 2019 (CLSM 0.16–0.31 W/mK for foam-LD variant — lower bound) |
| Thermal diffusivity α = k/(ρc_p) (×10⁻⁶ m²/s) | 0.32–0.46 | **0.49–0.59** | 0.61–0.77 | Computed from rows above; consistent with Stolarska & Strzałkowski mortar 0.71–0.96 dry, 1.29–1.37 sat (denser mortar) |

Sources:

- **ACI 229R-13** — Report on Controlled Low-Strength Materials.
  <https://www.concrete.org/Portals/0/Files/PDF/Previews/22913.pdf>
- **Kim, Park, Lee et al. 2018**, "Thermal conductivity of CLSM under
  various degrees of saturation using a modified pressure plate extractor
  apparatus — a case study for geothermal systems," *Applied Thermal
  Engineering*. <https://www.sciencedirect.com/science/article/abs/pii/S1359431118322312>
- **Do, Kim, Tae 2019**, "Thermal Conductivity of CLSM Made Entirely from
  By-Products," *Key Engineering Materials* 773: 244-249. Reports k =
  0.84–0.87 W/m·K, sensitive to saturation and curing condition.
  <https://www.scientific.net/KEM.773.244>
- **Stolarska & Strzałkowski 2020**, "The Thermal Parameters of Mortars
  Based on Different Cement Type and W/C Ratios," *Materials* 13(19):
  4258. Cement mortar (not CLSM but the closest binder analogue): k =
  1.23–1.67 W/m·K dry, 2.35–2.54 W/m·K saturated; ρc_p = 1.70–1.93 MJ/m³K.
  <https://pmc.ncbi.nlm.nih.gov/articles/PMC7579191/>
- **Wang et al., "Thermal properties of cement mortar with different mix
  proportions"**, *Materiales de Construcción*: cement-mortar k = 1.5–2.7
  W/m·K, c_p = 0.87–1.04 kJ/kg·K, α = 0.89–1.26 ×10⁻⁶ m²/s for f'c =
  6–60 MPa. Indicates leaner / lower-strength mortars sit at the low end
  of k. <https://materconstrucc.revistas.csic.es/index.php/materconstrucc/article/view/2293>

### Why the in-service recommended value sits between dry and saturated

A cured CLSM slab sitting on rigid insulation, sealed by the upper floor
assembly, with PEX water tubing inside it, equilibrates at internal
relative humidity well above the lab "ambient air dry" reference but well
below saturation. Lab measurements at "room-temperature curing" (Kim et
al. 2018; Do et al. 2019) report 0.84–0.87 W/m·K. We bump the
recommendation slightly higher (0.9–1.1) because (a) our mix is
sand-rich, not by-product-rich, and the published mortar literature
(Stolarska 2020, Wang) consistently shows higher k for sand-binder
matrices, and (b) the slab is in chronic contact with PEX-borne moisture
flux that holds it above lab-ambient-dry.

---

## 3. Comparison row — structural concrete and plain sand

| Material | ρ (kg/m³) | c_p (kJ/kg·K) | ρc_p (MJ/m³·K) | k (W/m·K) | α (×10⁻⁶ m²/s) |
|---|---|---|---|---|---|
| **CLSM (this doc, in-service)** | **1,950–2,100** | **0.90–1.00** | **1.85–2.05** | **0.9–1.1** | **0.49–0.59** |
| Structural concrete (normal-weight, ambient) | 2,300–2,400 | 0.85–0.90 | 2.0–2.15 | 1.4–2.5 (typ 1.8) | 0.7–1.2 |
| Plain sand, dry | 1,500–1,700 | 0.80 | 1.20–1.36 | 0.2–0.4 | 0.17–0.29 |
| Plain sand, saturated | 1,900–2,100 | 1.0–1.3 (incl. water) | 2.0–2.6 | 1.5–2.5 | 0.6–1.2 |

Sources for the comparison rows:

- Structural concrete: Wang et al. *Materiales de Construcción* (k =
  1.5–2.7 W/m·K for f'c = 6–60 MPa mortar; structural concrete with
  coarse aggregate sits at upper end). Material-properties.org concrete
  reference. <https://material-properties.org/concrete-density-heat-capacity-thermal-conductivity/>
- Sand (dry / saturated): Smits et al. 2010, *Vadose Zone Journal*,
  "Thermal Conductivity of Sands under Varying Moisture and Porosity in
  Drainage–Wetting Cycles" — dry k ≈ 0.23–0.35 W/m·K, saturated > 2.0
  W/m·K. <https://acsess.onlinelibrary.wiley.com/doi/10.2136/vzj2009.0095>

### Engineering reading of the comparison

- **vs. structural concrete:** CLSM gives up ~10 % of ρc_p (price of
  losing the densest aggregate) and **about half the conductivity**.
  That conductivity penalty is what drives the ~2× tube-length penalty
  derived in `design.md` §"Δ_depr — the dominant term".
- **vs. plain sand:** A dry compacted sand slab would be a thermal
  disaster (k ≈ 0.3). A saturated sand slab is competitive on paper but
  is not constructable — no way to keep it saturated, no way to keep
  PEX in place, no way to prevent settlement.

CLSM is the right answer: 60–70 % of structural-concrete conductivity,
near-100 % of its thermal mass, at 60 % of the delivered cost and with
no compaction or finishing labor.

---

## 4. Cost data (Northeast US benchmarks)

Published per-yard pricing for CLSM specifically is rare — most ready-mix
plants quote on request and bundle delivery zone and minimum-load
surcharges. The numbers below combine national CLSM benchmarks with
Northeast ready-mix supplier data.

### Delivered material price (CLSM, ready-mix truck)

| Source | $/yd³ (delivered, 2024–2025) | Notes |
|---|---|---|
| FlashFillServices contractor guide 2025 | $100–$150 | National average, sand mix |
| FlowableFill.org / NRMCA promotional | $100–$130 | Cited typical |
| Quick Mix (Atlanta region) base concrete pricing benchmark | $195–$225 for 3,000–5,000 psi structural | CLSM trades at ~50–60 % of structural — implies ~$110–$135 |
| Auburn Concrete (Maine, largest in-state supplier) | quote-only; 2025 price list referenced but not published | Direct quote required: (207) 777-7101 |
| Hughes Bros (Bangor ME), Haley's (central ME) | quote-only | Use as the Millinocket-region quote pool |

**Working delivered price (Northeast/Maine):** **$110–$145 / yd³** for the
recommended sand-rich mix in 2025 dollars. The original working value of
$100–130 / yd³ in `design.md` is slightly low for Maine in 2025; bump to
**$120–140 / yd³** as the planning number until a project quote comes back.

Sources:

- FlashFill Services contractor guide 2025.
  <https://www.flashfillservices.com/post/how-flowable-fill-works>
- FlowableFill.org (National Ready-Mixed Concrete Association affiliate).
  <https://www.flowablefill.org/financial.html>
- Quick Mix Concrete 2025 pricing.
  <https://www.quickmixconcrete.us/pricing/>
- Auburn Concrete. <https://auburnconcrete.com/>

### Pump / placement premium

For a 14-house residential slab program, the slab is at grade — most pours
will not need a boom pump; a line pump or direct chute will do. But the
flowable nature of CLSM and the embedded PEX restraint make a small pump
a near-universal choice in practice.

| Item | Cost (2025) | Source |
|---|---|---|
| Line-pump surcharge on the mix | $25 / yd³ | Quick Mix Concrete pricing page |
| Boom-pump hourly (32–40 m) | $210–$235 / hr + $3–4.50 / yd³ | Industry 2025 price sheets via Angi / CountBricks |
| Typical small-residential boom pump call-out | $700–$1,200 flat (3-hr min) | Angi 2025 |
| Fuel / environmental surcharge | ~$55 flat | Quick Mix Concrete |

**Working install premium:** add **$25–$40 / yd³** for line-pump-placed
CLSM in a residential slab. That is consistent with the $120 → $150 / yd³
spread in `design.md` (delivered → installed).

**Working installed price (Northeast/Maine):** **$145–$175 / yd³**
(updated from the design.md working $120–150 to reflect 2025 Northeast
pricing). On the template footprint of 18.5 yd³ that is **$2,700–$3,250
per house** for the storage medium itself, vs. the $2,500 in the design.md
ledger — within model noise but biased high. The design.md cost table
should be revised once a real Auburn Concrete or Hughes Bros quote is in
hand.

Sources:

- Angi, "What Does Concrete Pumping Cost? 2025/2026 Data."
  <https://www.angi.com/articles/concrete-pumping-cost.htm>
- Quick Mix Concrete (line-pump surcharge data point).
  <https://www.quickmixconcrete.us/pricing/>

---

## 5. Strength and install caveats

### Compressive strength is irrelevant — and so is excavatability

ACI 229R-13 defines CLSM as a cementitious mixture with f'c ≤ 1,200 psi
(8.3 MPa). Most CLSM applications target 50–300 psi for excavability
("removable" CLSM); higher-strength CLSM (up to 1,200 psi) is
"non-removable."

The recommended mix above lands at **150–250 psi at 28 days** — well
within both the removable and excavatable envelope, and is more than
sufficient for our case because:

- No structural load: the upper floor floats on insulation above the
  store. The CLSM slab carries only its own self-weight plus the
  insulation board, the upper-floor slab/panel, and the floor live load
  — all distributed over the entire footprint via the upper-floor
  assembly. Bearing pressure on the CLSM is under 1 psi.
- The bottom insulation (EPS R-4/in) below the CLSM sets the bearing
  surface, not the CLSM strength. CLSM at 100 psi has more than 100× the
  bearing capacity of the EPS it sits on.
- "Excavatable" is irrelevant to us — but if a future PEX repair is
  ever needed, the 150–250 psi mix is still drillable / chippable by
  hand with a rotary hammer.

Sources:

- ACI 229R-13 §2 (CLSM definition; 1,200 psi cap).
- FHWA *Fly Ash Facts*, Ch. 5 (excavatability vs. strength thresholds).
- ACI Committee 229 FAQ. <https://www.concrete.org/frequentlyaskedquestions.aspx?faqid=745>

### Set time and cure-before-load schedule

| Milestone | Time after pour | Source |
|---|---|---|
| Initial set / walkable | 1–5 hr | FHWA Ch.5; NRMCA CIP 17 |
| Sufficient set to top with insulation board | 24 hr | conservative builder's rule |
| 28-day design strength | 28 d | ACI 229R-13 standard |
| Earliest practical upper-floor pour or panel install | 7 d | reaches ~70 % of 28-d strength |

Schedule implication: **plan for 7 days between the CLSM pour and the
upper-floor install**, and **24 h between the CLSM pour and the top
insulation install**. In practice the 24-h gap is the binding constraint;
the 7-day gap is absorbed by other site work.

### Bleeding, subsidence, shrinkage

- **Subsidence**: high-fly-ash CLSM with high water content can settle
  ~11 mm per meter of fill depth (1/8 in per foot) due to bleed-water
  loss (FHWA Ch.5). Our 150 mm slab → ~1–2 mm of expected subsidence,
  well within the upper-insulation board's tolerance. Mitigation:
  keep fly ash ≤ 200 lb/yd³ and slump ≤ 8 in.
- **Drying shrinkage**: ACI 229R-13 reports CLSM drying shrinkage of
  the order 200–1,000 microstrain (0.02–0.10 %) — comparable to
  concrete, but the slab is unbonded (sitting on EPS) so shrinkage
  releases through edge movement rather than cracking the slab.
- **Cracking**: thin (≤ 6 in) sand-rich CLSM slabs without aggregate
  *can* check-crack on the surface. Acceptable for us — the slab is
  buried under insulation and serves as bulk thermal mass, not as a
  finished surface.

Source: FHWA *Fly Ash Facts* Ch.5, "Engineering Properties" subsection.
ACI 229R-13 chapter on properties (volume change, bleeding).

### PEX restraint during the pour

Water-filled 1/2" PEX in CLSM of wet density 2,000 kg/m³ has a buoyant
uplift of roughly 0.85 N/m (PEX inner volume ~127 mm² → 0.127 L/m → buoyant
force ≈ 0.127 × (2.0 − 1.0) × 9.81 = 1.25 N/m, less the tube self-weight
and water weight). A tied-down tube grid at 600–900 mm tie spacing
(standard practice for radiant in slabs) is sufficient.

The CLSM is self-leveling and self-consolidating — no vibration is
required, and vibration would risk dislodging tube ties. Specify a
**non-vibrated placement**. Source: NRMCA CIP 17.

---

## 6. Strength summary, in one sentence

Recommended mix delivers **150–250 psi at 28 days** vs. **< 1 psi**
bearing-pressure demand from the upper-floor assembly above. Margin is
two orders of magnitude. Strength is not the design constraint —
conductivity and ρc_p are.

---

## 7. Recommendation paragraph

For the downstream design code (`design.md` Materials table, sizing
spreadsheet, and the geometry/optimizer in `pipe-geometry.md`), use the
following working values with uncertainty bands:

| Property | Recommended working value | Uncertainty band | Change vs. `design.md` working value |
|---|---|---|---|
| Density ρ | **2,000 kg/m³** | 1,900–2,100 | ↑ from 1,900 (sand-rich mix is denser than the design.md draft assumed) |
| Specific heat c_p | **0.95 kJ/(kg·K)** | 0.90–1.00 | unchanged |
| Volumetric heat capacity ρc_p | **1.90 MJ/(m³·K)** = **0.53 kWh/(m³·K)** | 1.80–2.00 | ↑ from 1.80 by ~6 % |
| Thermal conductivity k | **1.0 W/(m·K)** | 0.85–1.10 | ↑ from 0.70 — the design.md value was the dry-lab end of the range; in-service CLSM with a sand-rich mix and chronic ambient moisture sits ~30–40 % higher |
| Thermal diffusivity α | **0.53 ×10⁻⁶ m²/s** | 0.45–0.60 | derived; up from 0.39 implied by the design.md values |
| Delivered cost | **$130 / yd³** | $110–$145 | bumped up from $100–130 to reflect 2025 Northeast pricing |
| Installed (line-pumped) | **$160 / yd³** | $145–$175 | bumped up from $120–150 |

### Two design.md numbers that need explicit revision

1. **k = 0.7 W/(m·K) is too pessimistic** for the in-service slab. The
   pipe-geometry derivation in `design.md` used k = 0.7 to compute
   Δ_depr ≈ 3.4 K at 600 m of tube and s = 150 mm. Repeating with
   k = 1.0: ln(0.15 / (π·0.008)) = 1.79; C = 2π × 1.0 / 1.79 = 3.5
   W/(m·K). q = 8.3 W/m → **Δ_depr ≈ 2.4 K** instead of 3.4 K. That is
   1 K of recovered headroom in the temperature stack — directly
   convertible to COP at the heat pump. The "+5 K rule" is even more
   comfortable than design.md estimated, and the tube-length penalty vs.
   structural concrete shrinks from ~2× to ~1.5×.

2. **Installed cost of $135 / yd³** in the design.md ledger should be
   updated to **$160 / yd³** for 2025 Northeast planning. On the
   template footprint that changes the "Flowable fill installed" line
   from $2,500 to $2,960 — a 4 % bump on the $5,800 store-assembly
   subtotal, **≈ $58 / kWh instead of $55 / kWh** of useful storage. Not
   architecture-changing.

### What is NOT changing

- **c_p ≈ 0.95 kJ/(kg·K)** stays. The mortar-thermal-properties
  literature is tight on this; nothing in the CLSM-specific literature
  argues against it.
- **ρc_p ≈ 1.9 MJ/(m³·K)** is essentially the design.md value plus the
  density bump. Capacity tables in `design.md` move up ~6 % — within
  the granularity of the slab-thickness sweep, no table re-do required
  unless we are tuning capacity to within ~5 %.

### Open questions to resolve with a real supplier quote

1. **Auburn Concrete / Hughes Bros / Haley's CLSM price** for the
   Millinocket job. The $130 / yd³ working number is benchmarked, not
   quoted.
2. **Pumping plan**: is the contractor's standard residential pour going
   to use a line pump, boom pump, or chute? The $25–40 / yd³ premium is
   sensitive to this.
3. **Mix flexibility**: can we get the sand-rich (≤ 100 lb/yd³ fly ash)
   mix specified without a custom design fee? Most ready-mix plants run
   stock CLSM with 200–300 lb/yd³ fly ash for cost reasons.

---

## Citation list (master)

1. **ACI 229R-13** — Report on Controlled Low-Strength Materials.
   American Concrete Institute, 2013 (reapproved 2022).
   <https://www.concrete.org/store/productdetail.aspx?ItemID=22913>
   Preview: <https://www.concrete.org/Portals/0/Files/PDF/Previews/22913.pdf>
2. **FHWA**, *Fly Ash Facts for Highway Engineers*, Chapter 5 — Fly Ash
   in Flowable Fill. <https://www.fhwa.dot.gov/pavement/recycling/fach05.cfm>
3. **FHWA**, *User Guidelines for Waste and Byproduct Materials in
   Pavement Construction*, FHWA-RD-97-148 §076 — Flowable Fill.
   <https://www.fhwa.dot.gov/publications/research/infrastructure/pavements/97148/076.cfm>
4. **NRMCA**, CIP 17 — Flowable Fill.
   <https://www.nrmca.org/wp-content/uploads/2021/01/17pr.pdf>
5. **FlowableFill.org**, Guide Specification for CLSM.
   <https://www.flowablefill.org/downloads/CLSMSpecifications1.pdf>
6. **Kim, Park, Lee et al. 2018**, "Thermal conductivity of CLSM under
   various degrees of saturation using a modified pressure plate
   extractor apparatus — a case study for geothermal systems," *Applied
   Thermal Engineering* 146: 188–197.
   <https://www.sciencedirect.com/science/article/abs/pii/S1359431118322312>
7. **Do, Kim, Tae 2019**, "Thermal Conductivity of CLSM Made Entirely
   from By-Products," *Key Engineering Materials* 773: 244–249.
   <https://www.scientific.net/KEM.773.244>
8. **Stolarska & Strzałkowski 2020**, "The Thermal Parameters of Mortars
   Based on Different Cement Type and W/C Ratios," *Materials (Basel)*
   13(19): 4258. <https://pmc.ncbi.nlm.nih.gov/articles/PMC7579191/>
9. **Wang et al.**, "Thermal properties of cement mortar with different
   mix proportions," *Materiales de Construcción*.
   <https://materconstrucc.revistas.csic.es/index.php/materconstrucc/article/view/2293>
10. **Smits et al. 2010**, "Thermal Conductivity of Sands under Varying
    Moisture and Porosity in Drainage–Wetting Cycles," *Vadose Zone
    Journal* 9: 172–180.
    <https://acsess.onlinelibrary.wiley.com/doi/10.2136/vzj2009.0095>
11. **Angi**, "What Does Concrete Pumping Cost? 2025/2026 Data."
    <https://www.angi.com/articles/concrete-pumping-cost.htm>
12. **Quick Mix Concrete**, 2025 pricing page.
    <https://www.quickmixconcrete.us/pricing/>
13. **FlashFill Services**, "How Flowable Fill Works: Complete
    Contractor Guide 2025."
    <https://www.flashfillservices.com/post/how-flowable-fill-works>
14. **Auburn Concrete** (Maine ready-mix supplier; quote-only).
    <https://auburnconcrete.com/>
