# Store-Under-Floor — Design Notes

> Status: **Draft · Pass 0** · Updated 2026-05-22 — split:
> [`worked-example.md`](worked-example.md) (cost ledgers) and
> [`scope-and-fidelity.md`](scope-and-fidelity.md) (scoping / FEA / standby)
> were extracted from this hub.

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
- **Q_in,max** (HP → store, design): **10 kW_th** default, **15 kW** upper
  bound. `Q_in_store_max` is a sweep parameter — see *Model parameters* below
  and [`scope-and-fidelity.md`](scope-and-fidelity.md) "Could the 15 kW
  Q_in,max be relaxed?" (reduced default reflects that HP-alone delivers
  ~10 kW at −30 °C OAT, so 5–10 kW of resistance is the upper-bound stretch).
- **Q_out,max** (store → floor + any FCU) = **5 kW_th** at design conditions.
- At the **15 kW upper bound**, sourcing is a single monoblock plus an inline
  electric resistance backup. The HP candidate list narrows after the −30 °C OAT
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

## Upper-emitter options (under evaluation)

The upper emitter — the layer that takes heat from the store and delivers it
to the room — is a **live design parameter, not locked**. Two candidate
stackups are under cost evaluation; the choice is **cost-driven** (Matt
Polstein's lean is the sleeper + nailed hardwood, but if Option B prices
cheaper he'd take it). Both options are costed in
[`worked-example.md`](worked-example.md).

| Option | Stackup | Active discharge ΔT | T_store → T_floor_supply (design day) |
|---|---|---|---|
| **A. Sleeper + nailed hardwood** (Matt's lean) | 2″ XPS R-10 / 3/4″ CDX glued / 1×4 sleepers + Matt-fab Al heat-transfer plates + PEX / 3/8″ CDX / 3/4″ solid nailed hardwood w/ water-based polyurethane | ~21 °F (11.7 K) | 122 °F → 101 °F |
| **B. 1.5″ polished structural-concrete overpour** (Siegenthaler's specified detail) | 2″ XPS R-10 / 1.5″ structural concrete overpour (¼″ aggregate + glass-fiber-reinforced topping, plastic-strip control joints; polished as finish floor) | ~26 °F (14.4 K) | 122 °F → 96 °F |

Option B widens the active-discharge range (~1.44× capacity at the same slab
depth) because the thinner overpour lowers the floor-supply temperature.
Option A is low-VOC dry-install with Matt's in-house aluminum-plate fab as a
major cost lever. **Numbers in this hub (capacity table, temperature stack)
default to Option A unless noted**; Option B's parallel numbers live in
[`worked-example.md`](worked-example.md).

## Leaky-top architecture — concept and operating modes

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

### Operational tradeoffs

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

### Decoupled-top fallback

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
corrected C with the calibrated k = 1.0.

> **Uncertainty in k — acknowledged in both docs.** The calibrated CLSM
> conductivity carries a real uncertainty band, **k ≈ 0.85–1.10 W/(m·K)** per
> the source review in [`materials-flowable-fill.md`](materials-flowable-fill.md).
> Headline numbers in this doc and in [`pipe-geometry.md`](pipe-geometry.md)
> use the central value **k = 1.0** (pipe-geometry has been **re-worked** at
> 1.0; its 2026-05-18 revision note + sensitivity column retain k = 0.7 to
> bound the lower edge of the band). Δ_depr scales roughly inversely with k,
> so the band translates to ≈ ±10–15 % on Δ_depr at the recommended geometry.
> Pinning k tighter is open research (in-service in-place measurement, or a
> calibrated pour test).

Heat extracted per meter of tube at design discharge: `q = Q_out / L_tube`.
Local depression at the tube wall: `Δ_depr ≈ q / C`.

For Q_out = 5 kW at s = 150 mm, calibrated k = 1.0, corrected
C = 2.0 W/(m·K) — sensitivity to active tube length L (q = Q_out / L;
Δ_depr ≈ q / C):

| L_tube | q (W/m) | Δ_depr |
|---|---|---|
| **750 m** — final post-task-#9 geometry (see [`scope-and-fidelity.md`](scope-and-fidelity.md) and [`pipe-geometry.md`](pipe-geometry.md) §9) | **6.7** | **3.3 K** |
| 940 m — pre-task-#9 design point (superseded) | 5.3 | 2.7 K |
| 600 m — leaner | 8.3 | 4.2 K |
| 300 m — skimpy | 16.7 | 8.4 K — wipes out the COP budget |

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
- [`worked-example.md`](worked-example.md) — incremental cost ledgers
  (baseline + Worked Examples A & B + "reading them together"), costing
  **both upper-emitter options** so the choice can be cost-driven.
- [`scope-and-fidelity.md`](scope-and-fidelity.md) — scoping analysis: which
  boundary condition binds the geometry, can Q_in be relaxed, do we still need
  FEA, capital-vs-operational envelope, and standby losses.
