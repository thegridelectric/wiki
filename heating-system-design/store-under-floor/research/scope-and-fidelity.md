# Store-Under-Floor — Scope, Binding Constraints & Model Fidelity

> Status: Draft · Pass 0 · Updated 2026-05-22 — extracted from design.md.

Design-scoping analysis: which boundary condition sizes the geometry, whether
`Q_in` can be relaxed, whether FEA is needed, the capital-vs-operational
envelope, and standby losses. The core design and parameter interface live in
[`design.md`](design.md).

## Pipe-geometry impact of task #9 (perimeter exclusion)

The decision to skip tubes in the outer ~1.5 ft perimeter band reduces
the tube field from 940 m / 11 loops / 12-port manifold (the original
[`pipe-geometry.md`](pipe-geometry.md) §9 recommendation) to **750 m /
9 loops / 10-port manifold**. Δ_depr at the active tubes drops slightly
(better q-per-meter distribution among them); discharge capacity falls
from 6.8 kW to 6.2 kW (still well above the 5 kW Q_out spec). PEX
savings: ~$1 200 per house. Manifold savings: ~$200. The excluded
perimeter ring still contributes thermal mass via passive conduction
into the central zone; it is not lost capacity, just passive capacity.

## Which boundary condition actually binds the geometry?

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

## Could the 15 kW Q_in,max be relaxed?

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

## Do we still need finite-element analysis?

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

## Capital sizing vs. operational overdrive

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

## Standby losses — a binding architectural concern

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

