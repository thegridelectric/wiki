# Store-Under-Floor — Design Notes

Working design notes for the decoupled thermal-store + radiant-floor system
going into Matt Polstein's 14-home phase-1 development in Millinocket, ME
(eventually 100 homes). Engaging John Siegenthaler as the consulting
hydronic engineer; this document captures the GridWorks side of the design
work and is **not yet reviewed by Siegenthaler**.

The hydronic topology lives in
[`../two-layer-floor.jpg`](../two-layer-floor.jpg): P1 charges the store from
the heat pump, P2 circulates store→floor, V1 bypasses the store for direct
HP→floor, and Z4 is an independent HP-fed zone (likely a fan coil, if AC is
in scope).

## Open question at top of the queue

> On the design day (−30 °C OAT), what supply-water temperature does the
> upper emitter need? This sets `T_store,bulk,min` (≈ `T_supply,floor` + a
> margin that is itself derived from tubing geometry below), which combined
> with the monoblock COP curve pins the useful ΔT we have to work with.

`T_supply,floor,design` is a **continuous parameter** in the model, not a
fixed number. Candidates:

| Upper emitter | `T_supply,floor,design` |
|---|---|
| Bare poured radiant slab, tight spacing | ≈ 30 °C |
| Poured radiant slab in a well-insulated house (typical) | ≈ 35 °C |
| Prefab radiant panel (Warmboard-style) on top of insulation | ≈ 40 °C |
| Fan-coil-dominant, or panel under finished wood | ≈ 45 °C |

Lower is better for COP; higher gives architectural flexibility. **Default
working value: 35 °C** until Polstein confirms the upper-emitter choice.

## Design-day boundary conditions

- Location: Millinocket, ME. ASHRAE 99.6 % heating DB ≈ **−30 °C (−22 °F)**.
- Indoor setpoint 21 °C.
- **Q_in,max** (HP → store) = **15 kW_th** at design conditions.
- **Q_out,max** (store → floor + any FCU) = **5 kW_th** at design conditions.
- 15 kW is sourced by a single monoblock plus an inline electric
  resistance backup. The HP candidate list narrows after the −30 °C OAT
  operating-envelope check (see [`../../heat-pumps/hp-curve.md`](../../heat-pumps/hp-curve.md) §12): the
  initial Mitsubishi PUZ-WM112 and Arctic 060A are **not** rated to
  operate at −30 °C and fall off the list. In-envelope candidates:
  - **Mitsubishi PUZ-HWM140VHA** (heating only): ~10 kW at −30 °C / LWT 40
    → resistance gap **~5 kW**.
  - **Arctic 060ZA/BE-R32** (reversible, supports AC): ~9–11 kW at design
    → resistance gap **~4–6 kW**.
  If `cooling_required=full_AC` is selected, the PUZ-HWM is disqualified
  and Arctic 060ZA/BE-R32 is the surviving recommendation. Resistance
  sits in the HP supply pipe between HP and store-charging tubes, so
  charging-tube sizing is unchanged by the split. Controller policy must
  minimize resistance use (every resistance kWh is COP-1). T_HP,LWT
  caps: **soft 60 °C, hard 65 °C** — pipe-geometry's recommended 58 °C
  design point sits comfortably inside.
- DHW is handled by a **separate** heat-pump water heater per house and is
  out of scope for this module.

## Template footprint for the math

All worked examples in this doc use **1000 ft² (92.9 m², round to 93 m²)**
of slab footprint. At 6" / 150 mm thickness that's 500 ft³ ≈ 18.5 yd³ ≈
**14.0 m³ of flowable fill**. Scale linearly with depth for other
thicknesses. The store IS the ground-floor slab — slab-on-grade pour of
flowable fill on rigid insulation over compacted earth, with another layer
of insulation between the store and the upper emitter floor.

## Materials — flowable fill (CLSM, no aggregate)

Per Siegenthaler: cement + sand + water, no coarse aggregate. Saves cost
because the store does not need structural strength — the upper emitter
floats on insulation above it. There is a thermal-property penalty vs.
structural concrete, mostly in conductivity (which matters a lot for tubing
geometry).

| Property | Flowable fill (calibrated) | Structural concrete (compare) |
|---|---|---|
| Density ρ | **≈ 2000 kg/m³** (band 1900–2100) | ≈ 2300 kg/m³ |
| Specific heat c_p | ≈ 0.9–1.0 kJ/(kg·K) | ≈ 0.9–1.0 kJ/(kg·K) |
| Volumetric heat capacity ρc_p | **≈ 1.9 MJ/(m³·K)** = **0.528 kWh/(m³·K)** | ≈ 2.1 MJ/(m³·K) = 0.58 kWh/(m³·K) |
| Thermal conductivity k | **≈ 1.0 W/(m·K)** (band 0.85–1.10) | ≈ 1.5 W/(m·K) |

**Specific heat per kg is essentially the same** between flowable fill
and structural concrete — both are silicate-bound cementitious
materials with similar atomic composition, and the published values
for either cluster in the 0.85–1.0 kJ/(kg·K) band. The thermally
meaningful difference between the two materials is **volumetric heat
capacity** (ρ·c_p), and that difference is driven almost entirely by
density (2000 vs. 2300 kg/m³) — CLSM has lower density because there
is no coarse aggregate filling the volume. The ~8 % volumetric
penalty is the cost of using flowable fill instead of structural
concrete; the specific-heat-per-kg comparison is a wash.

Density and k calibrated against ACI 229R-13, Stolarska & Strzałkowski
2020, Kim 2018, Do 2019, and the FHWA CLSM mix references — see
[`materials-flowable-fill.md`](materials-flowable-fill.md) for sources
and uncertainty bands. The k = 1.0 in-service value is materially
higher than the initial 0.7 working figure (which was an oven-dry
lab-CLSM number) and shrinks the conductivity penalty vs. structural
concrete from ~2× to ~1.5×.

### Capacity at the template footprint

`Capacity (kWh/K) = Volume (m³) × 0.528`

The recommended architecture (see "Leaky-top design" subsection below)
deliberately under-insulates the top with **2″ XPS (R-10)** between
store and upper emitter (per Siegenthaler). That admits a baseline
~1.5 kW peak passive transfer from the store into the upper floor at
design conditions (~1.2 kW at operating average). The upper emitter
itself is a **plywood-sleeper assembly with Matt-fabricated aluminum
heat-transfer plates and a solid nailed hardwood finish floor**.
The full stackup, bottom to top (per Siegenthaler's most recent
sketch):

1. 2″ XPS R-10 leaky-top insulation, glued to the store slab.
2. **3/4″ CDX exterior-grade plywood** glued to the XPS — distributes
   sleeper line-loads across the foam and gives the sleepers a
   fastener substrate (foam alone won't hold a screw).
3. 1×4 plywood sleepers laid flat on the lower plywood, glued and
   screwed; gaps sized for PEX runs.
4. PEX in the sleeper gaps at ~8″ on center.
5. **Matt-fabricated aluminum omega heat-transfer plates** keying
   into the sleeper tops, wrapping around each PEX run (Polstein's
   in-house fab vs. ~$2.50/ft² commercial price — meaningful savings
   at the 100-home scale).
6. **3/8″ CDX plywood** over the plates and sleepers; glued and
   screwed.
7. **Solid 3/4″ nailed hardwood** with **water-based polyurethane
   finish** as the wear surface (Polstein's preference; specifies
   **low VOC** and avoids the urea-formaldehyde found in engineered
   hardwood / laminate products).

The whole upper assembly is dry-install with effectively zero VOC
when the plywood spec is CDX (PF resin, not interior-grade UF
plywood) and the hardwood finish is water-based. **Roth aluminum-
skin panel + CDX plywood + solid hardwood** is held as a higher-
performance alternative (~+$1 500/house, slightly better
water-temperature performance, faster heat distribution).
**Schluter BEKOTEC + thin overpour + plywood + hardwood** is a
middle option but reintroduces a pour. Under the sleeper-default
scheme, the **active discharge range** runs from T_store,max
(~**122 °F**) down to T_floor,supply + margin (~**101 °F**) — about
**21 °F** (11.7 K). Below 101 °F, the passive leak continues
delivering decaying heat without the active loop. The table below shows the
**active range** capacity (kWh the active loop can deliver at full
spec) and the corresponding ride-through hours at the 5 kW design
load.

| Slab thickness | Volume (m³) | Active capacity (kWh) | Hours @ 5 kW (active) |
|---|---|---|---|
| 4" / 100 mm | 9.3 | **64** | **13 h** |
| 6" / 150 mm | 14.0 | 96 | 19 h |
| 8" / 200 mm | 18.6 | 127 | 25 h |
| 10" / 250 mm | 23.2 | 159 | 32 h |
| 12" / 300 mm | 27.9 | 191 | **38 h** |

(Active capacity = volume × 0.528 kWh/(m³·K) × 14.4 K × 0.90 perimeter-
exclusion factor. Add ~70 % more low-grade capacity below 96 °F as
passive leak; counted separately because it isn't on-demand.)

## Cost analysis — incremental over a baseline radiant floor

Numbers below are **incremental costs vs. a typical Polstein-class
1000 ft² on-grade radiant-floor build**. The baseline ("Nolan-style")
already includes a poured radiant slab, embedded PEX, a zone manifold +
circulator, and the standard high-performance insulation package —
assumed **R-20 below the slab and R-15 at the edge**. Those items
continue to exist in the decoupled design — the existing radiant slab
simply moves up to sit on top of the new top-of-store insulation as
the **upper emitter**. What this table prices is everything **added**
to make that radiant slab behave as the *emitter* of a decoupled,
transactively charged store.

Excluded from the table (priced elsewhere or unchanged): the heat pump
itself, the upper emitter floor assembly (depends on the choice the
project makes between poured radiant, prefab panel, or fan-coil
hybrid), and controls / transactive software.

### Why each upgrade is incremental

The store imposes harsher loss conditions than the emitter it replaces,
which is the root reason the bottom and top insulation packages have
to grow. Two effects compound:

1. **Higher driving ΔT to ground.** A typical radiant emitter slab
   runs at 24–28 °C (room-warm). The store at recommended operating
   point runs **44–50 °C** average. Against ~6 °C deep soil that's
   ~40 K driving ΔT vs ~25 K for the emitter — **~60 % more heat per
   ft² leaks at the same R**.
2. **Loss from a store is fully wasted; loss from an emitter is
   partly useful.** A radiant emitter's downward leak is a modest tax
   on a useful function (room warming). A store's leak is electricity
   you bought to use later, warming the dirt instead. The marginal
   value of avoided loss is higher for the store, so the cost-optimal
   R is higher.

At the recommended T_store,avg = 45 °C, bottom-loss vs R-value:

| Bottom R | Loss (W) | kWh/day | $/yr @ $0.20/kWh |
|---|---|---|---|
| R-16 (code minimum) | ~1 320 | 31.6 | ~$2 300 |
| R-20 (Polstein baseline) | ~1 050 | 25.2 | ~$1 840 |
| R-30 | ~700 | 16.8 | ~$1 230 |
| R-60 (recommended) | ~350 | 8.4 | ~$610 |

Upgrading R-20 → R-60 saves ~$1 230 / yr; the ~$1 200 incremental
cost pays back in **about a year**. The top insulation (entirely new
in the decoupled architecture) does similar work in the opposite
direction — preventing the hot store from cooking the upper emitter
when the house doesn't want heat.

### Unit cost reference

| Item | Unit cost | Source |
|---|---|---|
| Flowable fill installed (pumped, no finish) | **$160 / yd³** | [`materials-flowable-fill.md`](materials-flowable-fill.md) |
| Top insulation (XPS Foamular 250, foot-traffic rated) | **$0.30 / ft²·in** | [`insulation.md`](insulation.md) |
| Bottom insulation (EPS Type IX, high-density) | **$0.20 / ft²·in** | [`insulation.md`](insulation.md) |
| Edge insulation (XPS R-5/in, full depth) | **$0.30 / ft²·in** | [`insulation.md`](insulation.md) |
| ½″ PEX-Al-PEX installed in flowable fill | **$0.80 / ft installed** | [`pipe-geometry.md`](pipe-geometry.md) |
| Charging manifold (10–12 port) + P1, P2, V1, mixing valve | **~$1 400 / set** | hydronic-supply pricing |
| Inline resistance element (electric, 10 kW class) | **~$800** | typical price for 240 V 10 kW immersion / inline element |

Both worked examples below use the **leaky-top architecture with a
1.5″ polished structural concrete overpour as upper emitter**
(Siegenthaler's specified detail). The stackup, bottom to top:

- 6″ XPS R-30 below the store (against earth)
- Flowable-fill store slab (4″ in Example A, 12″ in Example B)
- 2″ XPS R-10 top insulation (the "leaky-top" layer)
- **1.5″ structural concrete overpour using ¼″ crushed-stone aggregate
  + glass-fiber-reinforced topping mix + bottom-up plastic-strip
  control joints; polished as the finished floor surface** (Matt
  Polstein's preference for bare polished cement; no separate
  finish-floor layer needed)

Both omit the inline resistance element from the BOM — its presence is
an operational decision (panel capacity, transactive-controller
policy) priced separately from the store hardware. Cost differences
below are stated as **delta vs. a "standard radiant floor" baseline**
— a 4″ structural radiant slab on grade, polished as finish floor,
with embedded PEX at 12″ spacing, a 6-port zone manifold + circulator,
R-20 EPS below, and R-15 XPS edge. The baseline build cost is what
Polstein would otherwise have spent on a typical polished-radiant
house; the worked examples price only what changes.

Temperature stack assumed by both worked examples:

| Quantity | Worked-example value |
|---|---|
| Indoor setpoint | **70 °F** |
| Design outdoor air temperature | **−22 °F** |
| Floor-supply target on design day (1.5″ overpour, 6″ PEX spacing) | **87 °F** |
| Active-discharge floor (T_store below this → passive-only) | **96 °F** |
| Store charged maximum (HP-alone capable at design cold day) | **122 °F** |
| HP leaving water at design (charging) | **136 °F** |
| HP leaving water in direct-HP→floor mode (V1) | **~91 °F** |
| Active discharge ΔT (store charged → store-active-floor) | **26 °F** |
| Baseline passive store→floor transfer at design ΔT (52 °F) | **~1.5 kW peak / ~1.2 kW avg** |

Siegenthaler's 1.5″ overpour lowers the floor-supply temperature
~8 °F relative to a 4″ structural emitter. That benefits HP COP in
direct-HP→floor mode (LWT drops ~8 °F) and widens the store's active
discharge range from 18 °F to **26 °F** — capacity scales by 26/18 =
**1.44×** at the same slab thickness.

## Baseline build: 7″ polished structural radiant floor on grade

Both worked examples below are priced against the same baseline —
Matt Polstein's standard high-performance Maine build before the
decoupled-store project:

| Baseline line item | Detail | Cost |
|---|---|---|
| 7″ structural radiant slab | 21.6 yd³ × $220 delivered+placed | $4 750 |
| Embedded PEX, 12″ spacing | 300 m × $0.80/ft installed | $790 |
| Zone manifold + circulator | 6-port | $700 |
| Bottom insulation R-20 | 4″ EPS | $800 |
| Edge insulation R-15 | 24″ vertical × ~125 ft perimeter | $375 |
| Polish + seal as finish floor | $4/ft² × 1000 ft² | $4 000 |
| **Baseline total** | | **~$11 400** |

Baseline storage capability: the slab is both the store and the
emitter, so its useful range is bounded by the floor-surface comfort
ceiling (~85 °F) and room temperature (~70 °F). At ~0.575 kWh/(m³·K)
× 16.5 m³ × ~5 K useful swing, the slab provides
**~50 kWh of coupled storage** — useful but inflexible (the
controller can't run the store cold while keeping the floor warm,
or vice versa; that's the Nolan-house limitation we're trying to
fix).

Temperature stack assumed by both new-design examples below:

| Quantity | Worked-example value |
|---|---|
| Indoor setpoint | 70 °F |
| Design outdoor air temperature | −22 °F |
| Floor-supply target on design day (sleeper emitter, plywood substrate) | **92 °F** |
| Active-discharge floor (T_store below this → passive-only) | **101 °F** |
| Store charged maximum (HP-alone capable) | 122 °F |
| HP leaving water at design (charging) | 136 °F |
| HP leaving water in direct-HP→floor mode (V1) | ~95 °F |
| Active discharge ΔT | **21 °F** (11.7 K) |
| Baseline passive store→floor transfer | ~1.5 kW peak / ~1.2 kW avg |

### Worked Example A — lean variant (4″ flowable-fill store)

**Use case:** shifts from coupled to decoupled control without
materially adding storage capacity. Not sized for multi-day outages.
4″ is the minimum practical pour thickness.

**Active capacity:** 9.3 m³ × 0.528 kWh/(m³·K) × 11.7 K × 0.90 =
**49 kWh ≈ 10 h** at 5 kW. Plus ~30 kWh of low-grade passive tail
below 101 °F. Roughly the same kWh as baseline (~50 kWh) but now
**fully decoupled** — the store can drop in temperature
independently of the floor surface.

**Cost delta vs. baseline 7″ polished radiant:**

| Line item | Δ vs. baseline | Cost |
|---|---|---|
| Heating mass: 7″ structural concrete → 4″ flowable fill | 21.6 yd³ × $220 ($4 750) → 12.4 yd³ × $160 ($1 980) | **−$2 770** |
| PEX: 300 m in slab → 750 m store + 370 m emitter | $790 → $2 940 | **+$2 150** |
| Finish floor: polish + seal → solid nailed hardwood w/ water-based finish (low-VOC) | $4 000 → $7 500 | **+$3 500** |
| ADD: top insulation R-10 XPS (leaky-top, Siegenthaler) | 2″ × 1000 ft² × $0.30/ft²·in | **+$600** |
| UPGRADE: bottom insulation R-20 → R-60 | +10″ EPS Type IX | **+$2 000** |
| UPGRADE: edge insulation R-15 → R-20 28″ + R-10 wing | deeper + outboard | **+$250** |
| ADD: lower CDX plywood layer (3/4″, glued to XPS) | distributes sleeper load, fastener substrate; PF-resin (low-VOC) | **+$1 500** |
| ADD: 1×4 sleepers + Matt-fab aluminum heat-transfer plates + 3/8″ CDX top plywood + adhesive | $700 sleepers + $1 000 Matt-fab plates + $1 500 top plywood + $200 fasteners/adhesive | **+$3 400** |
| ADD: emitter-side manifold + circulator | distinct from charging manifold | **+$700** |
| ADD: charging-side manifold + P1 + P2 + V1 + mixing valve | 10-port + 3 circulators + 3-way mix | **+$1 400** |
| In-house emitter install labor (Polstein's crew) | sleeper + plate + double-plywood install | **+$1 300** |
| **Net cost difference per house** | | **≈ +$14 030** |
| **$ / kWh of active useful storage** | $14 030 ÷ 49 kWh | **≈ $286 / kWh** |

**Honest read:** Example A delivers ~the same kWh as baseline, but
decoupled. The $14 000 is buying *control flexibility*, not added
storage. Justifies itself only if the transactive value of
decoupled mode-switching is meaningful.

### Worked Example B — outage-resilience variant (12″ flowable-fill store)

**Use case:** ride through ~24 h of grid outage at the full 5 kW
heating load on top of everyday transactive arbitrage. Adds
significant decoupled storage on top of decoupled control.

**Active capacity:** 27.9 m³ × 0.528 × 11.7 × 0.90 = **155 kWh ≈
31 h** at 5 kW. Plus ~110 kWh of low-grade passive tail. **~3×
baseline storage**, fully decoupled.

**Cost delta vs. baseline 7″ polished radiant:**

| Line item | Δ vs. baseline | Cost |
|---|---|---|
| Heating mass: 7″ structural concrete → 12″ flowable fill | 21.6 yd³ × $220 ($4 750) → 36.5 yd³ × $160 ($5 840) | **+$1 090** |
| PEX | $790 → $2 940 | **+$2 150** |
| Finish floor: polish → solid nailed hardwood (low-VOC) | $4 000 → $7 500 | **+$3 500** |
| ADD: top insulation R-10 XPS | unchanged | **+$600** |
| UPGRADE: bottom insulation R-20 → R-60 | unchanged | **+$2 000** |
| UPGRADE: edge insulation R-15 → R-20 40″ + R-10 wing | taller for deeper slab | **+$340** |
| ADD: lower CDX plywood layer (3/4″) | unchanged | **+$1 500** |
| ADD: sleeper + Matt-fab plates + 3/8″ CDX top plywood + adhesive | unchanged | **+$3 400** |
| ADD: emitter manifold + circulator | unchanged | **+$700** |
| ADD: charging manifold + P1 + P2 + V1 + mixing valve | unchanged | **+$1 400** |
| In-house emitter install labor | unchanged | **+$1 300** |
| **Net cost difference per house** | | **≈ +$17 980** |
| **$ / kWh of active useful storage** | $17 980 ÷ 155 kWh | **≈ $116 / kWh** |
| **$ / kWh of *added* storage** vs. baseline 50 kWh | $17 980 ÷ (155 − 50) kWh | **≈ $171 / kWh of marginal storage** |

### Leaky-top architecture — concept and operating modes

The default architecture used by both worked examples above. The
top insulation is deliberately thin (R-8 instead of R-30) so a
**baseline ~1.5 kW passively flows from the store into the upper
emitter at design conditions**, doing useful heating work while the
store discharges. The active P2 / mixing-valve loop only has to
deliver `house_load − 1.5 kW` on top of the baseline. The useful
temperature range of the store thereby extends below
T_floor,supply, because the bottom of the discharge curve is
handled by the passive leak rather than the active tube field.

This trade is the right default because the baseline leak is *useful
heat into the house* most of the time the store is hot, not loss. The
old "decoupled, minimize-top-transfer" framing treated the leak as
wasted; the leaky-top framing treats it as a fixture of the load
profile.

#### Operational tradeoffs

The leaky-top architecture commits the project to a particular
seasonal operating concept:

1. **Three-mode operation, all using the same hardware.** The store
   plays a different role each season, but the hydronics don't change:
   - **Winter — hot store.** Charged, T_store ≈ 38–50 °C. Baseline
     ~1.5 kW leaks upward to the floor; active P2 + mixing valve tops
     up to meet house load.
   - **Summer — cold store.** Chilled overnight by running the HP in
     reverse, T_store ≈ 10–15 °C. Baseline ~0.9 kW of *cooling* leaks
     upward (heat falling *into* the cold store), giving radiant
     cooling baseline. Active loop circulates chilled water from the
     store to the floor with dew-point control on the supply.
   - **Shoulder — neutral store.** T_store sits near room temperature;
     leak is ~zero. HP feeds the floor directly through V1 (heating)
     or the Z4 fan coil (cooling/dehumidification) as needed.
2. **Radiant cooling is supported, not lost.** Conduction follows the
   temperature gradient; the leak helps in whichever direction makes
   sense. The 14 K ΔT from a 24 °C room to a 10 °C store across R-8
   gives ~930 W of passive cooling — well-matched to a Maine summer
   daytime load. (An earlier draft of this section incorrectly stated
   radiant cooling was impossible; that was based on a stale "hot
   store all year" mental model. Corrected.)
3. **Z4 fan coil is optional, not mandatory.** Useful for
   dehumidification and fast-response pulses, but no longer the only
   cooling path under the leaky-top design.
4. **Floor surface temperature.** 1.5 kW through 1000 ft² is
   ~16 W/m² of baseline heating output; the cold-store mirror gives
   ~10 W/m² of baseline cooling. Both are comfortably below typical
   radiant outputs (30–50 W/m² heating, 20–40 W/m² cooling). With the
   active loop overlaid, the floor surface stays in comfort range in
   both seasons; worth verifying at commissioning.
5. **Seasonal transitions** are temperature swings of the store
   itself, not drain-and-park. Spring: walk the store from hot to
   neutral, then push to cold over a few days as cooling load
   appears. Fall: reverse. Both swings are anticipated from weather
   forecast and managed by the transactive controller. ~1 week of
   anticipatory activity each transition.
6. **Condensation control** during cooling-mode operation is a real
   concern wherever cold supply water meets warmer room air. Standard
   remedies (vapor barrier on the room-side face of the upper
   emitter, dew-point-limited chilled-water supply) apply unchanged.
   The store mass itself is fully insulated and not exposed to room
   air, so internal condensation in the fill is not at issue.
7. **Controller complexity rises.** Day-ahead scheduling, seasonal
   transition planning, and direction-of-leak management all live in
   the transactive control layer.

#### Decoupled-top fallback

The "decoupled" design with R-30 top insulation remains available as
a fallback option for projects where the seasonal-transition
controller can't be trusted (legacy fixed-setpoint controls would
struggle; the GridWorks transactive stack is built for this). Under
the decoupled fallback, useful ΔT collapses from 18 °F (10 K active)
to ~22 °F (12 K, between T_store_max ≈ 122 °F and
T_floor_supply+margin ≈ 100 °F) — so capacity per slab depth is
roughly cut in half. The top-insulation BOM line grows from $510 to
$1 800. Same hardware everywhere else. The model exposes
`top_insulation_strategy ∈ {leaky_baseline, decoupled}` as a
parameter; default `leaky_baseline`.

### Reading the two worked examples together

Both examples replace Matt's baseline **7″ polished structural radiant
slab on grade** (~$11 400 build cost, ~50 kWh of coupled storage)
with a decoupled leaky-top store under a sleeper-emitter + nailed
hardwood floor.

| Metric | Baseline 7″ polished radiant | Example A (4″ flowable-fill store) | Example B (12″ flowable-fill store) |
|---|---|---|---|
| Build cost (full, not delta) | $11 400 | ~$25 400 | ~$29 400 |
| Active storage | ~50 kWh coupled | **49 kWh decoupled** | **155 kWh decoupled** |
| Coupling regime | Slab IS store IS emitter | Decoupled | Decoupled |
| **Cost delta vs. baseline** | reference | **+$14 030** | **+$17 980** |
| What the delta buys | — | Decoupled control, ~0 added storage | Decoupled control + 3× storage |
| $ / kWh of *all* active storage | — | $286 / kWh | $116 / kWh |
| $ / kWh of *added* storage vs baseline | — | n/a (no added kWh) | $171 / kWh of marginal storage |

The headline reads:

- **Example A (~$14 k incremental)** delivers no added kWh — it
  buys *decoupled control*. The active store can drop in
  temperature while the floor stays warm, enabling transactive
  charge-and-discharge cycling that the coupled baseline can't do
  at all.
- **Example B (~$18 k incremental, +$3 950 over A)** adds 105 kWh
  of *decoupled* storage on top of the control flexibility — full-
  day outage ride-through plus arbitrage windows. The marginal
  cost of going from 4″ to 12″ is dominated by the flowable-fill
  line; every other line stays constant.

The marginal $3 950 between Examples A and B is the highest-value
spend in the table — it converts a "decoupled-control-only" build
into a full outage-resilient one for ~28 % more capital.

**Two unstated cost lines:** the in-house Matt-fab aluminum plate
($1 000 vs commercial $2 500) and Polstein's crew labor (vs.
sub-contracted) materially shift these numbers if Matt cannot
manufacture in-house at the assumed cost. A commercial-plate +
sub-contracted-labor build would add **~$2 500 / house** to either
example. The Roth aluminum panel alternative (no Matt-fab, full
commercial-panel cost) lands ~$1 500 / house above the sleeper
default.

### Pipe-geometry impact of task #9 (perimeter exclusion)

The decision to skip tubes in the outer ~1.5 ft perimeter band reduces
the tube field from 940 m / 11 loops / 12-port manifold (the original
[`pipe-geometry.md`](pipe-geometry.md) §9 recommendation) to **750 m /
9 loops / 10-port manifold**. Δ_depr at the active tubes drops slightly
(better q-per-meter distribution among them); discharge capacity falls
from 6.8 kW to 6.2 kW (still well above the 5 kW Q_out spec). PEX
savings: ~$1 200 per house. Manifold savings: ~$200. The excluded
perimeter ring still contributes thermal mass via passive conduction
into the central zone; it is not lost capacity, just passive capacity.

### Which boundary condition actually binds the geometry?

The two boundary conditions are stipulated, not derived: **Q_in,max = 15 kW**
into the store from the HP, and **Q_out,max = 5 kW** out of the store to the
floor, both on the design day. Only one of them ends up sizing the tube
field. At the recommended geometry (940 m of ½″ PEX at s = 150 mm,
C = 2.0 W/(m·K) → total UA ≈ 1 880 W/K, per
[`pipe-geometry.md`](pipe-geometry.md)):

- **Q_in,max = 15 kW binds.** The charging LMTD between the HP-side fluid
  (entering at T_HP,LWT = 58 °C, leaving ≈ 53 °C) and the store bulk
  during a charge (~50 °C → ~52 °C as it fills) is roughly **8 K**.
  Required UA = 15 000 W / 8 K = **1 880 W/K** — essentially equal to
  what 940 m of tube delivers. The 15 kW input is the constraint that
  *sized the tube length*; lowering Q_in,max (say to 12 kW) would
  immediately let us shrink the tube field, while raising it would force
  more tube, more loops, more cost.

- **Q_out,max = 5 kW does not bind.** Discharge runs at lower ṁ
  (5 kW / 5 K ΔT = 0.24 kg/s, vs charge 0.72 kg/s) and the same
  1 880 W/K of UA. The ε-NTU effectiveness on the discharge side is
  NTU = 1 880 / 1 000 = 1.88 → ε = 0.85, so the maximum extractable Q at
  T_store,min = 38 °C with floor return at 30 °C is ε × ṁc_p × ΔT =
  0.85 × 1 000 × 8 ≈ **6.8 kW** — about 36 % of headroom over the 5 kW
  spec. The discharge constraint could be tightened to ~7 kW before the
  geometry would need to change.

The asymmetry comes from the 3:1 ratio in stipulated Q_in vs Q_out,
combined with the fact that charging LMTD is small (HP LWT close to
bulk T as the store fills) while discharging LMTD is large (T_store
≫ floor return). If Polstein were to ever revise the stipulated
boundary, **changes to Q_in,max have an immediate cost impact via tube
length; changes to Q_out,max within ~7 kW are free.**

### Could the 15 kW Q_in,max be relaxed?

The 15 kW stipulation was set before V1 and mode 3 were fully in the
architecture. With those in place, the **store-charging tube field only
has to carry whatever the HP is depositing into the store mass**, not
the HP's full output. Heat that the HP sends directly to the floor
through V1 never touches the store tubes.

This matters because the HP itself only delivers ~10 kW at −30 °C OAT
(see [`../../heat-pumps/hp-curve.md`](../../heat-pumps/hp-curve.md));
the 15 kW Q_in,max number was always a **HP + resistance** hybrid.
Sizing the tube field for less than 15 kW means:

| Q_in,store,max | Required UA | Tube length | PEX | Savings vs. 15 kW |
|---|---|---|---|---|
| 15 kW | 1 880 W/K | 940 m | $3 155 | baseline |
| 12 kW | 1 500 W/K | 750 m | $2 525 | −$630 |
| 10 kW | 1 250 W/K | 625 m | $2 100 | −$1 055 |
| 8 kW | 1 000 W/K | 500 m | $1 680 | −$1 475 |

Plus a smaller manifold (8-port vs 12-port, ~−$200) and potentially a
smaller resistance element. Total plausible capital saving: **$1 500–
$2 000 per house** at Q_in,store,max ≈ 8–10 kW.

There is a quiet COP win on top: at Q_in,store,max = 10 kW the HP can
fill the store from its own output alone, with **no resistance kWh
going to the store**. Resistance backup, if kept at all, would only fire
to support the floor-direct path during extreme cold snaps when HP
capacity falls below 5 kW (sub-−35 °C OAT).

The tradeoff is **recharge speed during quiet windows** — short
cheap-electricity windows where the house is *not* calling for heat and
the controller would want to refill at maximum rate (mode 1, HP-only-
to-store). In mode 3 with a heat call active, the HP makes 10 kW total
and only 5 kW goes to the store anyway, so the tube UA is never
binding. Mode-1 fast refill is the only case where Q_in,store,max > 5 kW
buys anything. How often that case matters depends on the price
schedule's window structure.

**Recommendation:** promote `Q_in_store_max` to a **continuous model
parameter**, default **10 kW** (matches the HP-only capability at
−30 °C with no resistance into the store). Let the outer transactive
optimizer sweep it against capital cost vs. missed-arbitrage cost.
Q_in,store,max = 15 kW should be treated as the *upper bound* of the
sweep, not the default.

This makes the parameter list a column wider but the new default is a
strict cost improvement under any reasonable Maine TOU schedule.

### Do we still need finite-element analysis?

For the *capital-cost-minimizer module* this doc scopes — **no.** The
analytical shape-factor work in [`pipe-geometry.md`](pipe-geometry.md)
(slab shape factor with pipe-wall + internal-convection resistance in
series), validated against EN 1264-2 / ISO 11855-2 and Siegenthaler's
published radiant-slab tables, gives sizing-grade UA-per-meter numbers.
The 2-D + transient edge-loss treatment in [`edge-loss.md`](edge-loss.md)
covers the one place where a steady-state 1-D treatment was clearly
inadequate (perimeter cold-zone, frost interaction, corner factor).
Together those two are enough to issue a defensible procurement spec.

For the *outer transactive operating-cost simulator* — **yes, eventually.**
Three classes of question the current analytical work does not answer:

1. **Transient charge/discharge curves at varying SOC.** Real-life Q_in
   and Q_out track the *current* bulk-T, not a steady-state LMTD; charging
   slows as the store warms, discharging slows as it cools. A 2-D
   transient FEM (or even a 1-D layered slab model with depth-resolved
   nodes) is the right tool to produce the Q(SOC, LWT, OAT) curve the
   controller will plan against.

2. **Operation-mode interactions when `two_separate_circuits=true`.**
   The Option A vs Option B comparison in pipe-geometry §4 is steady-state
   only; Option B's depth-stratification claim deserves a transient FEM
   if we ever revisit the boolean.

3. **Perimeter exclusion (task #9).** The 5–9 K cold-zone Δ_T,edge
   identified by [`edge-loss.md`](edge-loss.md) creates a non-uniform
   bulk-T that the steady-state shape-factor math averages away. A 2-D
   FEM is the cleanest way to recompute the effective discharge UA after
   excluding the perimeter ring, and to decide whether the 940 m tube
   length over-buys the central zone.

Bottom line: ship the current analytical numbers for the procurement
spec; budget a 2-D transient FEM pass before the outer operating-cost
simulator is treated as authoritative.

### Capital sizing vs. operational overdrive

The HP + inline-resistance **hardware architecture is fixed across all
scenarios**. The split between what the capital-cost minimizer sizes for
and what the operational (transactive) layer exploits is cleaner once
named:

**The capital BOM sizes for the HP alone at the design cold day.**

- `T_store,max,design` = the highest LWT the HP can deliver at
  `T_oa,design` with acceptable COP. From
  [`../../heat-pumps/hp-curve.md`](../../heat-pumps/hp-curve.md): a soft
  cap of 60 °C and a hard cap of 65 °C for the in-envelope monoblocks.
- `Q_in,store,max,design` = the HP's thermal output at `T_oa,design`
  and `T_HP,LWT,design`. ~10 kW for the PUZ-HWM140VHA class, ~9–11 kW
  for the Arctic 060ZA/BE-R32.
- These two pin the tube-field UA, the slab volume, the useful ΔT,
  and the costed BOM the dashboard shows.

**The resistance element is a fixed cheap add-on, not a capital
sizing parameter.** Roughly $100/kW; the only capital question is how
many kW the panel can sink. The BOM has a line for it but its capacity
does not change the geometry or insulation choices.

**The transactive gwbase model (the agent + the outer controller)
sees a *bigger* operating envelope than the capital design sized for.**

- Higher peak `Q_in,store`: HP (~10 kW at −30 °C) **plus** whatever
  resistance the panel allows (5, 10, 15+ kW). The combined rate is
  bounded by the **tube field UA**, which was sized for HP-alone
  charging — so the resistance overdrive is capped at whatever extra
  thermal the tubes can absorb at the existing UA. Practically: the
  resistance can fully utilize the residual fluid-ΔT headroom up to the
  PEX continuous-service temp.
- Higher `T_store,max`: resistance has no LWT-vs-COP penalty. The
  operational ceiling rises to the PEX limit (~95 °C continuous, design
  to ~80 °C with safety margin). When the resistance pushes the store
  above the HP's design ceiling, the next HP charge cycle simply has
  to wait until SOC drains back into the HP-favorable range. The
  controller plans this.

**Net implication for the parameter surfaces.** The capital-cost
minimizer (dashboard, `engine/cost.py`) takes:

- `T_supply_floor_design`, `hours_of_store`, `T_oa_design`,
  `hp_unit_selection` (→ derives `Q_in,store,max,design` and
  `T_store,max,design`), `two_separate_circuits`, `cooling_required`,
  slab thickness and R-values.

The transactive operational model (`agent/`, future outer controller)
additionally takes:

- `resistance_capacity_kw`, `T_store_operational_cap` (≤ PEX limit),
  expected price/weather schedule.

The agent runs the same physics engine in both cases; it simply
permits the resistance command to drive `Q_in,store` and `T_store`
above the capital-design values up to the operational limits. The BOM
does not change.

### Standby losses — a binding architectural concern

At the recommended package the store still bleeds **~1 700 W nominal**
(~511 W top + ~371 W bottom + ~800 W edge per the 2-D analysis, partially
recoverable as house heat during heating season). That is roughly **20 %
of daily delivered load**. The original 10 % loss budget in this doc is
**economically unreachable**: closing the residual gap to 10 % would
cost another ~$2 500+ of foam at a marginal $0.40–1.00 per avoided kWh,
far above Maine's $0.20/kWh retail electricity. The recommended position
is to **relax the standby-loss budget to ~20–25 %** and accept that the
decoupled-store architecture carries a meaningful continuous parasitic
load.

Additionally, [`edge-loss.md`](edge-loss.md) identifies a **cold-zone
depression at the store perimeter** of **Δ_T,edge ≈ 5 K (annual mean)
to 9 K (design day)**, decaying ~0.5 m into the slab. The final tube-field recommendation
above already accounts for this: tubes in the outer ~1.5 ft perimeter
band are skipped (active field covers the central 80 % of the slab),
which drops the tube count from 940 m to 750 m and saves ~$1 400 in
PEX + manifold without sacrificing the 5 kW discharge spec. The
excluded perimeter ring still acts as passive thermal mass via
conduction into the central zone. This matters two ways for the larger project:

1. The operating-cost simulator should not assume a 90 %-efficient store;
   it is closer to 75–80 % over a typical cycle.
2. The arbitrage threshold for using the store rather than the V1
   direct-HP-to-floor path rises: every kWh routed through the store now
   pays a ~30 % COP penalty *and* a ~5 % standby penalty over its
   typical residence time, so cheap-vs-peak price spreads need to clear
   ~40 % to make the round trip worthwhile.

This needs Polstein review. Options to bring losses down further: thicker
slab (raises capacity, so loss-as-percent drops but absolute loss rises);
lower T_store,avg (cuts loss but also cuts useful ΔT, forcing bigger
volume); a more lossy but cheaper insulation package (worse standby, but
the COP-penalty argument may favor it if the store sees few cycles).

Heat pump, resistance element, upper floor, and controls are priced
separately in the larger-project bill of materials.

## Hydronic temperature stack

The chain from emitter back to HP on the design day:

```
T_supply,floor   ──── set by upper emitter (parameter, default 35 °C)
       +
   margin Δ      ──── derived from geometry — see below
       =
T_store,bulk,min ──── store temp at end of longest ride-through
       +
useful ΔT        ──── continuous optimizer variable
       =
T_store,bulk,max ──── top-of-charge store temp
       +
charging LMTD    ──── HP-to-store approach at full Q_in = 15 kW
       =
T_HP,LWT,design  ──── what the HP must deliver at −30 °C OAT
```

The COP penalty of the monoblock pushes us to keep `T_HP,LWT,design` as low
as possible, which pushes every layer of the stack down.

## Decomposing the margin between `T_supply,floor` and `T_store,bulk,min`

The common "+5 K rule of thumb" is shorthand for three physically distinct
effects, all of which depend on **discharge-tube geometry** rather than
being free parameters:

1. **Local-temperature depression** Δ_depr around the discharge tubing —
   the tube pulls heat out of the fill faster than conduction can replenish
   it, so the fill in the immediate vicinity of the discharge tube sits
   below the bulk store temperature.
2. **Fluid outlet approach** Δ_NTU — the fluid exits the discharge tube
   field slightly below the local fill temp, governed by
   NTU = UA_total / (ṁ·c_p).
3. **Mixing-valve authority margin** Δ_mix — the mixing valve needs a few K
   of headroom on the hot side to throttle without driving full open.

### (1) Δ_depr — the dominant term

For tubing buried in a medium of conductivity k at tube spacing s and
tube radius r, the steady-state conductance per unit length is approximately

```
C  =  2π · k  /  ln( s / (π·r) )      [W / (m · K)]
```

For 1/2" PEX (r ≈ 0.008 m) at s = 150 mm in flowable fill (k = 0.7 W/m·K)
the infinite-medium form gives:

```
ln(0.15 / (π · 0.008))  =  ln(5.97)  =  1.79
C_∞  =  2π · 0.7 / 1.79   ≈  2.45 W/(m · K)
```

**This overstates the real per-meter conductance.** The slab is finite-
thickness with insulated boundaries, and the pipe-wall + internal-
convection resistances are not negligible. The corrected per-meter
conductance is

```
1 / C  =  R_pipe_wall  +  R_conv,internal  +  R_slab(s, z, h, k, r)
       ≈  0.22 m·K/W   +   ln(s/(π r)) / (2π k)
```

For s = 150 mm and the **calibrated** k = 1.0 W/(m·K) for CLSM (see
[`materials-flowable-fill.md`](materials-flowable-fill.md)):

```
C_corrected  ≈  2.0 W/(m · K)        (½″ PEX, s = 150 mm, k_CLSM = 1.0)
```

For structural concrete at k = 1.5: C ≈ 2.5 W/(m·K) corrected. **The
flowable-fill conductivity penalty vs. structural concrete shrinks to
~1.5×** at the calibrated k. All downstream numbers in this doc use the
corrected C with the calibrated k. The geometry sub-document
([`pipe-geometry.md`](pipe-geometry.md)) was worked at the earlier
k = 0.7 W/(m·K); its conclusions are conservative on Δ_depr (numbers
shrink ~30 % at the calibrated k) but the recommended geometry should be
revisited under a future revision pass.

Heat extracted per meter of tube at design discharge: `q = Q_out / L_tube`.
Local depression at the tube wall: `Δ_depr ≈ q / C`.

For Q_out = 5 kW and a single shared 940 m field at s = 150 mm
(the recommended design point from [`pipe-geometry.md`](pipe-geometry.md) §9
at calibrated k = 1.0), using corrected C = 2.0 W/(m·K):

- q = 5000 / 940 = 5.3 W/m
- Δ_depr ≈ 5.3 / 2.0 ≈ **2.7 K**

For a leaner 600 m field:

- q = 8.3 W/m → Δ_depr ≈ **4.2 K**

For a skimpy 300 m field:

- q = 16.7 W/m → Δ_depr ≈ **8.4 K** — wipes out the COP budget.

Geometry directly buys or loses degrees of useful ΔT at the bottom of the
stack. Every K of avoidable Δ_depr is a K of COP headroom or a K less store
volume.

### (2) Δ_NTU — secondary

```
NTU         =  UA / (ṁ · c_p)
ε           =  1 − exp(−NTU)
Δ_NTU       =  (1 − ε) · (T_fill,local − T_in,disch)
```

At Q_out = 5 kW with a ~5 K floor-loop ΔT (T_in,disch ≈ 30 °C):

- ṁ·c_p = 5000 W / 5 K = 1000 W/K
- UA (600 m × 2.45) = 1470 W/K → NTU ≈ 1.47 → ε ≈ 0.77
- If T_fill,local − T_in,disch = 10 K, Δ_NTU ≈ 2.3 K
- Halve the tube length: NTU = 0.74, ε = 0.52, Δ_NTU ≈ 4.8 K

Δ_NTU is real but secondary to Δ_depr, and the two scale similarly with
tube length, so they are strongly correlated.

### (3) Δ_mix — small fixed adder

Budget **1–2 K** for mixing-valve authority. Effectively a constant.

### Putting it together

```
T_store,bulk,min  =  T_supply,floor  +  Δ_depr  +  Δ_NTU  +  Δ_mix
```

The popular "+5 K" rule is the sum of (≈ 3 K + ≈ 1 K + ≈ 1 K) and is
**only valid if the discharge tubing geometry is generous enough**. A
skimpy discharge field can easily push the margin to 8–10 K, eating the
COP budget alive. This is exactly why tubing geometry is the headline
research deliverable, not an afterthought.

## Head loss through the store, and the direct-HP-to-floor bypass

The decoupled architecture pays a real COP penalty whenever heat is routed
**through** the store instead of being delivered direct from HP to floor:

```
T_HP,LWT  >  T_store,bulk,max  >  T_store,bulk,min  >  T_supply,floor
              \_____________/    \________________/    \____________/
              charging LMTD       useful ΔT             discharge margin
                                                        (Δ_depr+Δ_NTU+Δ_mix)
```

For the working draft numbers (T_supply,floor = 35 °C, discharge margin
~5 K, useful ΔT ~15 K, charging LMTD ~8 K):

- **Direct HP → floor (V1 bypass):** HP LWT only needs ~40 °C. On the
  in-envelope cold-climate monoblocks fit at −30 °C OAT,
  **COP ≈ 1.5–1.8** (per [`../../heat-pumps/hp-curve.md`](../../heat-pumps/hp-curve.md)).
- **HP → store → floor (full round trip):** HP LWT must reach ~60 °C to
  bring the store to its charged max. **COP ≈ 1.0–1.3**.

That is roughly a **26–33 % COP penalty** for every kWh routed through
the store at design conditions (generic CCHP 29 %, Mitsubishi 33 %, Arctic
26 %). The earlier "~30 %" framing holds, but the absolute COPs are
materially lower than the initial 2.0–2.2 / 1.4–1.5 working figures —
operating costs in the outer transactive model should be sized to the
revised numbers. The store earns its keep only when the
**arbitrage value** of time-shifting that kWh (cheap-window electricity vs.
peak-window electricity) exceeds that penalty.

The architecture preserves the lower-penalty path: V1 in the diagram,
combined with the zone valves, lets the controller run **HP → floor
directly** whenever the house is calling for heat *and* electricity is
cheap *and* the store is adequately full. The under-floor store is
reserved for genuine multi-hour to multi-day time-shift duty.

**Offsetting head loss with the house thermal envelope.** A complementary
trick: in cheap-electricity windows, run the HP direct-to-floor at
*slightly above* the current zone demand, letting the upper emitter slab
and the house's interior mass coast a few hours past setpoint. The house
envelope is a free, lossy micro-store sitting in series with the floor;
comfort-band-widening transactive controls already exploit it. Short
horizon (hours, not days), but it stacks cleanly with the V1 bypass.

**Operating regimes the outer optimizer should evaluate** on a
representative weather + price year:

1. HP direct to floor (V1 open, store quiescent) — best COP, no time shift.
2. HP charging store while floor draws from store — full round-trip penalty.
3. HP charging store *and* feeding floor direct (diagram's mode 3) —
   pump-speed split decides energy allocation.
4. Floor drawing from store only, HP off — store pays back banked heat.

## Tubing geometry — headline research deliverable

The deep-research sub-document
[`pipe-geometry.md`](pipe-geometry.md) (TBW) is where the geometry math
lives. The required deliverables are:

- **UA-per-meter-of-PEX in flowable fill** from the slab shape factor
  (not the infinite-medium form used in the Δ_depr estimate above).
  Calibrated to k ≈ 0.7 W/(m·K) for CLSM and validated against
  Siegenthaler's published radiant-slab tables.
- **Charge-circuit sizing:** choose (s, L_tube, depth) to deliver
  Q_in = 15 kW at acceptable charging LMTD, given the chosen HP LWT.
- **Discharge-circuit sizing:** choose (s, L_tube, depth) to deliver
  Q_out = 5 kW at minimum useful store temperature, holding
  Δ_depr + Δ_NTU below the budget set by the COP curve.
- **One circuit vs two:** total tube + manifold cost head-to-head against
  the useful-ΔT gain from depth-stratification.
- **Depth placement:** if `two_separate_circuits=true`, putting charge
  tubes deep and discharge tubes shallow creates a vertical thermal
  gradient that behaves like soft stratification. Quantify the gain with
  a 2-D finite-volume model.
- **Spacing optimum:** cost of tube + install labor + manifold ports vs.
  UA gained. Likely flat optimum in 100–200 mm for flowable fill;
  pinpoint it.
- **Pressure drop & circulator sizing** for the recommended layout.
- **Install practicality** in a flowable-fill pour: tube restraint
  against float (fill density 1900 kg/m³, water-filled PEX floats),
  manifold elevation, air-vent placement. To be reviewed with Siegenthaler.

## Model parameters (the module's interface)

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `T_supply_floor_design` | continuous (°C) | 35 | Upper-emitter requirement on design day |
| `hours_of_store` | continuous (h) | sweep 6–48 | Primary output curve |
| `Q_in_store_max` | continuous (kW) | 10 | Max heat rate INTO store mass via charging tubes. Original spec was 15 kW; reduced default reflects mode-3 / V1 architecture and pure-HP-no-resistance recharge. Sweep range 5–15 kW. |
| `two_separate_circuits` | bool | true (TBC) | In-store circuit count |
| `top_insulation_strategy` | enum | `leaky_baseline` | `decoupled` (R-30, minimize transfer) or `leaky_baseline` (R-8, ~1.5 kW design-day baseline leak handles part of house load; ~2× useful capacity at ~½ the $/kWh — see "Alternative architecture" subsection) |
| `cooling_required` | enum | tbd | none / dehumidification_only / full_AC |
| `hp_curve_source` | enum | generic_cchp | generic / published_unit / field_validated_unit |
| `R_top`, `R_bot`, `R_edge` | continuous | sweep | Insulation R-values |
| `slab_thickness` | continuous (m) | derived | From capacity required |
| `s_charge`, `s_discharge` | continuous (m) | derived | Charge / discharge tube spacing |

Locked design choices (not parameters):

- Store medium: flowable fill, sand-cement, no aggregate.
- Form factor: slab-on-grade, with insulation above (store↔floor) and
  below (store↔earth) and at edge.
- 15 kW sourced from single monoblock + inline resistance backup.
- DHW: separate HPWH, out of scope.

## Verification

- Hand-compute capacity at the template footprint at 3 depths × 3 useful
  ΔTs; cross-check against the table.
- Sanity-check ρc_p and k of flowable fill against ACI 229R or equivalent.
- Spot-check Δ_depr predictions against Siegenthaler's published in-slab
  temperature data.
- Re-derive the 30 % COP-penalty number against the Mitsubishi Ecodan
  published curve once the HP-curve module is built.

## File map

- [`design.md`](design.md) — this file. Overall design + temperature stack
  + cost ledger + parameter list.
- [`glossary.md`](glossary.md) — definitions for k, CLSM, UA, LMTD, NTU,
  the Δ-margins, hydronic-schematic labels, and project-specific names.
- [`simulator-agent.md`](simulator-agent.md) — design for packaging the
  thermal-store model as a SEMA-conformant SCADA actor on the local MQTT
  broker, with a chaos-testing roadmap that builds on it.
- [`materials-flowable-fill.md`](materials-flowable-fill.md) — calibrated
  CLSM thermal & cost properties with sources and uncertainty bands.
- [`pipe-geometry.md`](pipe-geometry.md) — deep research on in-store
  tubing geometry: slab shape factor, charge/discharge sizing, 1-vs-2
  circuit comparison, depth stratification, spacing optimum, pressure
  drop, install practicality. Re-worked at the calibrated k = 1.0 W/(m·K);
  pre-perimeter-exclusion recommendation: shared single circuit,
  s = 150 mm, mid-slab depth, 8″ pour, 940 m / 11 loops / 12-port
  manifold. **Final recommended geometry after task #9 perimeter
  exclusion: 750 m / 9 loops / 10-port manifold** (active tube field
  in the central 80 % of the slab), useful ΔT = 12 K, T_HP,LWT = 58 °C,
  ~112 kWh ≈ 22 h @ 5 kW ride-through.
- [`insulation.md`](insulation.md) — cost-optimal R sweep for top, bottom,
  and edge with first-pass ASHRAE F-factor perimeter loss. Recommended
  package: top R-30 XPS, bottom R-60 EPS Type IX, edge R-30 XPS 6 ft
  vertical + 4 ft wing. Total ~$7 010/house insulation, ~1 400 W standby
  loss, ~22 % of daily delivered load. 10 % loss budget is economically
  unreachable; doc recommends relaxing to 20–25 %.
- [`edge-loss.md`](edge-loss.md) — 2-D + transient slab-edge perimeter-loss
  model with frost-depth interaction and corner factors. Refines the
  F-factor recommendation in `insulation.md`: edge spec drops from R-30 ×
  6 ft to R-20 × 32" + 2 ft R-10 wing (~$1 800 saving). Identifies a new
  design constraint — perimeter cold-zone depression Δ_T,edge ≈ 5–9 K
  decaying 0.5 m into the slab — that the discharge-tube layout in
  `pipe-geometry.md` does not yet account for.
- [`../../heat-pumps/hp-curve.md`](../../heat-pumps/hp-curve.md) — parameterized HP COP module with three
  modes (generic CCHP, published Mitsubishi/Arctic, field-validated stub).
  Recommended functional form is Carnot-fraction (better than polynomial
  on RMSE *and* extrapolation). Narrows candidate units to PUZ-HWM140VHA
  (heating only) or Arctic 060ZA/BE-R32 (reversible). Confirms the ~30 %
  COP-penalty number but revises the absolute COPs down by ~0.3 (direct
  1.5–1.8, charging 1.0–1.3 at −30 °C OAT). Soft cap T_HP,LWT = 60 °C,
  hard cap 65 °C.
- [`worked-example.md`](worked-example.md) — (TBW) one full design point
  end-to-end.
