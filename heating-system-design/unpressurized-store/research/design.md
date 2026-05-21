# Unpressurized-Store — Design Notes

Working design notes for the **decoupled pressurized-system / unpressurized-tank
thermal store** module. The module is intentionally **site-independent**: it
exposes a clean four-port thermal interface plus optional electric immersion
inputs so it can be mixed-and-matched into new-build (e.g.
[`../../store-under-floor/`](../../store-under-floor/)) or retrofit topologies
(e.g. replacing the 4×119 gal Vaughn buffer bank in the existing GridWorks
houses; see [`../parallel-buffer-house0.png`](../parallel-buffer-house0.png)).

Hardware partner: Garth Schultz / Thermal Energy HQ
(https://thermalenergyhq.com/), who manufactures the 350 gal unpressurized
tank (≈ $2300) shown in [`../cad1.png`](../cad1.png) and
[`../cad2.png`](../cad2.png) and has been willing to modify CAD for
non-standard inlet elevations. Hydronic consulting: John Siegenthaler.

George's first-draft schematic is at
[`../george-schematic-1.png`](../george-schematic-1.png).

## Why unpressurized, and the core constraint

A tall unpressurized polyethylene/steel tank is dramatically cheaper per kWh
of useful storage than a code-rated pressurized vessel, and it can be
fabricated tall-and-narrow for sharp stratification without the wall-thickness
penalty of a pressure rating. **Hard constraint: the system loop itself (heat
pump, emitters) stays pressurized closed-loop water/glycol — the unpressurized
water never crosses the module boundary.** This forces a heat-exchanger
between the HP loop and the tank water (per Siegenthaler's recommendation,
external plate, not an immersed indirect coil).

## Module boundary — four thermal ports + electric

The module owns: the tank(s), the charge-side plate HX, both circulators,
the HP-side valves (including the **Siegenthaler loop** mixing valve), the
load-side mixing/discharge valve, the **3-way injection-elevation valve**
on the HX outlet, all in-tank diffusers, and any in-tank immersion heaters.

It does **not** own: the heat pump, the emitters, DHW production, the
electric-resistance backup that lives in the HP supply pipe (that backup
belongs to whichever HP+emitter system is wrapped around the module).

External interface:

```
inputs(t):  T_HP_LWT, ṁ_HP, glycol_frac_HP, HP_running,
            T_load_return, ṁ_load_demand, T_load_supply_setpoint,
            P_immersion_cmd[i]                # per element, optional
outputs(t): T_HP_EWT, T_load_supply_actual,
            Q_to_load, Q_from_HP, Q_immersion,
            tank state (n-node stratified T profile),
            valve positions (injection-elevation, Sieg, discharge-mix)
```

## Parameter table (working defaults)

| Param | Default | Range | Notes |
|---|---|---|---|
| `n_tanks` | 1 | 1–3 | Series-thermocline if >1 |
| `tank_volume_gal` | 150 | 100–350 | Garth fabricates; 350 is his stock |
| `tank_H_over_D` | 3 | 2–4 | 150 gal @ H/D=3 → 24" × 71" |
| `T_top_max` | 60 °C | — | Soft cap matches HP soft LWT |
| `T_bottom_min` | 30 °C | — | Headroom for mid-injection + load mix |
| `n_inject_ports` | 3 | 2–4 | Elevations T/UM/LM, see below |
| `port_elev_frac` (T,UM,LM) | (0.92, 0.70, 0.46) | — | Fractions of tank height |
| `inlet_device` | disc diffuser | flute / disc / combined | See §Stratification |
| `outlet_device_bottom` | disc diffuser | bare / disc | Cheap insurance |
| `HX_approach_K` | 5 | 3–8 | Brazed plate, sized for Q_in,max |
| `HX_Q_design_kW` | 15 | 5–20 | Inherits from upstream HP sizing |
| `HP_side_glycol_frac` | 0.30 | 0–0.50 | Propylene, monoblock outdoor |
| `tank_side_glycol_frac` | 0.0 | — | Plain water, tank indoors |
| `n_immersion` | 1 | 0–2 | Upper-mid default |
| `P_immersion_each_kW` | 6 | 3–9 | For neg-price / resilience charging |
| `sieg_loop_present` | true | — | Load-side supply-temp PID (existing) |
| `discharge_return_switchable` | true | bool | Bottom vs LM return port |

## Anchoring the design — site-independent, comparison anchored

The module is parameterized; the **comparison** to the store-under-floor
design is anchored to Polstein's Millinocket scenario (−30 °C OAT, 15 kW
HP, 5 kW load, T_supply,floor,design = 35 °C) so the life-cycle cost
question reads head-to-head. See [`../../store-under-floor/research/design.md`](../../store-under-floor/research/design.md).

## Capacity ballpark

Water: ≈ 1.16 kWh/(m³·K). A 150 gal (0.568 m³) tank at 20 K useful ΔT →
**13.2 kWh useful**. Equivalent run-times:

| Load | Hours |
|---|---|
| 2.5 kW (typical winter) | 5.3 h |
| 5.0 kW (design-day discharge to 1000 ft² slab) | 2.6 h |
| 8.0 kW (large load) | 1.7 h |

Design-day capacity is short on purpose — at −30 °C the HP runs flat-out
and the store's job is bridging compressor cycling/defrost, not long-haul
shifting. Long-haul shifting is for **mild-day price-arbitrage and
solar-self-consumption**, where the load is much smaller.

## Stratification — disc diffusers at all 3 inlet elevations

With **active port-elevation selection** via the 3-way valve, the
self-stratifying property of a Moscone-style flute is redundant: the valve
already picks the right elevation. Three identical symmetric circular
disc diffusers, one per port, give cleaner thermocline preservation and a
repeated fabrication part for Garth. Flute vs disc is being CFD-validated
in [`../executor/cfd.md`](../executor/cfd.md) before the design freezes.

Discharge-return port is switchable between bottom and LM elevation,
controlled by comparing emitter-return temperature to the probe at LM.

## Siegenthaler loop (`sieg valve`)

Existing, working in the GridWorks 4×119 gal Vaughn houses: a load-side
PID that recirculates a fraction of the load-supply water to make the
desired floor-supply temp from whatever the tank is currently offering.
Stays as-is in the new module on the **load** side. The new
**injection-elevation valve** on the HP/HX side is structurally similar
but with different control logic (driven by HX-outlet temperature vs
tank thermocline, not by emitter setpoint).

## Open questions (TODO before design freeze)

1. **Garth's 350 gal exact dimensions** — visual estimate from CAD is
   D ≈ 42" / H ≈ 58" / H/D ≈ 1.4. Confirm with Garth.
2. **150 gal tall-narrow fabrication** — is Garth willing to fabricate
   a 24" × 71" custom tank at a reasonable price uplift over the 350 gal
   stock unit? Material: HDPE vs. epoxy-lined steel.
3. **Insulation strategy** — Garth's stock product, additional jacket,
   or site-installed rigid board? UA target for the standby-loss budget.
4. **Immersion-heater electrical interlock** — what does the agent need
   to do to safely cut the element if tank top exceeds `T_top_max`?
5. **Heat-exchanger model number** — confirm a brazed-plate vendor
   (Alfa Laval, SWEP, GEA) and SKU at the 15 kW / 5 K approach design
   point.
6. **CFD validation of disc vs flute** — flute is being kept as a
   fallback until the CFD comparison rules it in or out. See
   [`../executor/cfd.md`](../executor/cfd.md).
7. **N-node tank model coefficients** — to be calibrated from CFD
   outputs; see [`../executor/cfd.md`](../executor/cfd.md) §Use 2.
8. **TOU bridging** — first-cut energy budget in [`tou-bridging.md`](tou-bridging.md): tank + 4" slab covers the 5 h Versant on-peak block down to ~−20 °C OAT within ±1.5 K dead band; thinslab is tighter; design-day requires running the HP through the peak.
9. **Life-cycle cost comparison to store-under-floor** — stub at [`comparison-with-store-under-floor.md`](comparison-with-store-under-floor.md). Four scenarios: TOU only; TOU + wholesale; + solar self-consumption; + outage resilience. Needs the engine + dashboard before it produces real numbers.
