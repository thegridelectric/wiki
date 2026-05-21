# Can a 150 gal Stratified Tank + Radiant Floor Avoid Versant TOU Hours?

## Which design this is about

Two designs are being compared at the system level (see
[`comparison-with-store-under-floor.md`](comparison-with-store-under-floor.md)):

- **Design A — store-under-floor.** Storage slab IS the heating system;
  PEX is buried in a 6" flowable-fill slab that doubles as store and
  emitter. See [`../../store-under-floor/research/design.md`](../../store-under-floor/research/design.md).
- **Design B — Garth tank + radiant floor (this module).** A 150 gal
  stratified water tank stores heat; a separate radiant floor emits it.
  In a ground-floor new-build, that radiant floor is **slab-on-grade**
  (~4" concrete on rigid foam over earth), which is the assumption for
  this analysis.

**This document analyzes Design B only.** It does *not* answer "which
design wins" — that's the comparison memo.

## Question

With a single 150 gal H/D=3 stratified tank charging a slab-on-grade
radiant floor (working defaults from [`design.md`](design.md)), can
Design B avoid running the heat pump during Versant Power's on-peak
windows (**07:00–12:00** and **16:00–20:00**) while keeping indoor air
temperature within **±2–3 °F (±1.1–1.7 K)** of setpoint?

**Answer (first cut): yes for typical Maine winter days down to about
−20 °C OAT, marginal at design-day (−30 °C).** The 5-hour morning peak
is the binding constraint; the 4-hour evening peak is easy. Below is
the back-of-envelope energy budget; a real answer needs the simulator
from [`../executor/simulator.md`](../executor/simulator.md) (TBD).

## TOU schedule + bridging requirement

| Window | Hours | Notes |
|---|---|---|
| 07:00–12:00 on-peak | **5 h** | Binding — longest single block |
| 12:00–16:00 off-peak | 4 h | Tank recharge window 1 |
| 16:00–20:00 on-peak | 4 h | Easier than morning |
| 20:00–07:00 off-peak | 11 h | Tank recharge window 2 (overnight) |

Tank recharge time at 15 kW HP charge into a 150 gal tank from 30 °C →
58 °C = 0.568 m³ × 28 K × 1.16 kWh/(m³·K) = **18.4 kWh / 15 kW ≈ 1.2 h**.
Both off-peak windows have ample headroom for full recharge.

## Energy budget for the 5-hour morning peak

Two reservoirs bridge the gap: (1) the tank and (2) the radiant-floor
mass itself.

### Reservoir 1 — tank deliverable energy

```
V = 150 gal = 0.568 m³
T_top,max = 58 °C   (2 K below the 60 °C cap)
T_top,useful_min = 37 °C   (2 K above the 35 °C supply setpoint)
Useful ΔT = 21 K
E_tank,useful = 0.568 × 21 × 1.16 = 13.8 kWh
```

That assumes ideal stratification. With realistic mixing, derate by
~15 % → **E_tank ≈ 11.7 kWh useful.** (The CFD work in
[`../executor/cfd.md`](../executor/cfd.md) will sharpen this number.)

### Reservoir 2 — radiant-floor thermal mass

Working assumption: 1000 ft² (93 m²) of **4" slab-on-grade** radiant
floor (~5.5 kWh/K of slab mass). Surface couples to room air at h_eff
≈ 12 W/(m²·K), so the floor → room coupling is ~1100 W/K.

Steady-state at design supply (35 °C in, ~30 °C out, slab surface ~23 °C,
room 21 °C, slab→room ΔT ≈ 2 K, slab→room Q ≈ 2.2 kW).

When the tank cuts off, the slab coasts. **For room air to stay within
−1.5 K of setpoint, the slab surface only needs to stay above ~21.1 °C**
(below that, slab→room ΔT drops below ~0.1 K and the room cools to match
envelope losses). That means the slab can release ~2 K worth of stored
energy from its mass before the room exits the dead band:

**4" slab-on-grade: ~11.0 kWh available across a 2 K surface-temperature
drop.**

### Total passive bridging budget

| Reservoir | kWh |
|---|---|
| Tank (150 gal, 21 K useful ΔT, 15 % mixing derate) | 11.7 |
| 4" slab-on-grade floor mass (2 K drop) | 11.0 |
| **Total** | **22.7** |

This bridges roughly **4.5 kW × 5 h** within the dead band.

## Compare to load × 5 h

Envelope load scaled linearly from a 5 kW @ −30 °C design point (per
the store-under-floor anchor — used here only as a calibration, not a
site commitment), 21 °C indoor:

| OAT (°C / °F) | Load (kW) | 5 h energy (kWh) | Budget used (of 22.7) |
|---|---|---|---|
| +5 / 41 | 1.6 | 8.0 | ✓ (35 %) |
| −5 / 23 | 2.5 | 12.7 | ✓ (56 %) |
| −15 / 5 | 3.5 | 17.6 | ✓ (77 %) |
| −20 / −4 | 4.0 | 20.1 | ✓ (89 %) |
| −30 / −22 | 5.0 | 25.0 | ✗ (110 %) |

**Reading the table:**

- **150 gal tank + 4" slab-on-grade handles the 5 h morning peak down
  to about −20 °C OAT** without breaching ±1.5 K indoor. Versant TOU
  avoidance is achievable for the great majority of Maine winter
  hours.
- **Design-day (−30 °C) is over budget.** On the coldest days, run the
  HP through the peak — TOU avoidance is a typical-day strategy, not
  a design-day one. (Versant typically pairs TOU with critical-peak
  override signals anyway.)

### Sidebar — upstairs zones on thinslab

If part of the radiant emitter is **thinslab on joists** (1.25–1.5"
gypcrete or topping slab — typical for upper floors), the floor-mass
reservoir shrinks to ~2.1 kWh/K, or roughly **4.2 kWh across a 2 K
drop** instead of 11.0. Total budget drops to ~15.9 kWh, and the
bridging limit moves up to roughly −5 °C OAT. Mitigations if Matt
plans thinslab upstairs zones: pre-heat the slab 1 K above setpoint
at 06:55, accept a wider 3 °F dead band, or size the tank up to 2×
150 gal. This isn't the headline case but is worth keeping in mind
for two-story floor plans.

## Sensitivity knobs (what to vary in the simulator)

- **Dead band tolerance.** Going from ±1.5 K → ±2.0 K roughly doubles
  the available floor-mass budget and pushes the limit OAT 5 K colder.
- **T_top,max.** Bumping the tank cap from 58 → 65 °C adds ~4 kWh of
  tank-useful energy but costs HP COP during charge.
- **Pre-charge strategy.** Floating indoor setpoint up by 0.5 K during
  the last 30 min of off-peak ("pre-cool from setback" in reverse) buys
  ~1.5 kWh of room+slab mass for free.
- **Mid-injection elevation.** Doesn't help bridging directly, but lets
  the HP run more often during off-peak at higher COP, lowering the
  capex-vs-opex equation.

## Honest caveats

1. Load scaling is linear-in-ΔT, which is the right first approximation
   but ignores solar gains, wind, and infiltration spikes.
2. The "1100 W/K floor-to-room coupling" assumes a finished slab; a
   wood-finish floor cuts this roughly in half and changes the budget.
3. Tank derate (15 %) is a guess until CFD lands; could be 5 % or 25 %.
4. No HP-cycling losses included — every cycle has a small thermal tax
   that the simulator needs to account for.
5. Envelope load anchored to store-under-floor's Millinocket numbers
   for shape; for any real site, plug in the actual Manual J.

## Next step

This analysis is the back-of-envelope. To answer crisply, the
N-node tank model + radiant-floor lumped-mass model + envelope model
need to run together against an hourly Maine TMY3 weather year with
Versant TOU prices applied. That's the **dashboard's** first non-trivial
output, queued behind the CFD calibration. See
[`../executor/simulator.md`](../executor/simulator.md) (TBD).
