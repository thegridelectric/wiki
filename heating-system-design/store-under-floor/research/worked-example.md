# Store-Under-Floor — Worked Cost Examples

> Status: Draft · Pass 0 · Updated 2026-05-22 — extracted from design.md.

Incremental cost ledgers for the decoupled store. These cost the **two
upper-emitter options under evaluation** — sleeper + nailed hardwood (Matt's
lean) vs. a 1.5″ polished concrete overpour — because the choice is **cost-driven**
(see [`design.md`](design.md) "Upper-emitter options"). The design and parameter
interface live in [`design.md`](design.md).

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

