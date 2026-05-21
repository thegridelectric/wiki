# Dashboard — Design Plan

A simple web dashboard that exposes the under-floor-store model
parameters as widgets, runs the capital-cost minimizer for the chosen
parameter values, and renders the costed BOM as a table plus a few
derived quantities and plots. **First deliverable** of the
heating-system-design repo.

## Goals

- Interactively explore the parameter surface in `../research/design.md`.
- Produce a costed BOM at any parameter point in <1 s.
- Show derived thermodynamic quantities (T_HP,LWT, useful ΔT,
  T_store,bulk,min/max, charging LMTD, Δ_depr) at the chosen point.
- Plot the headline cost-vs-`hours_of_store` curve so a user can read
  off the right hours-of-store target.
- Make it easy to compare two parameter points side-by-side (Scenario A
  vs. Scenario B).

## Non-goals (for v0)

- Real-time animation of the physics. The dashboard does sizing and
  cost; the agent does real-time physics.
- Authentication, multi-user state, persistence beyond URL query params.
- Beautiful design. Function over form.

## Technology

**Streamlit.** Reasons:

- Pure Python — same language as the engine; no JS toolchain.
- Sidebar widgets + main-area tables and plots are exactly what
  Streamlit does best.
- Hot reload, `st.cache_data` for free, hosted-deploy trivially.
- ~200 lines of code for the whole app.

Alternatives considered: Dash (overkill, heavier framework), Gradio
(more ML-flavored, less polish for tables), HTMX + FastAPI (more
flexibility but more code). Streamlit wins for v0.

## URL structure

Single page. Parameter state is encoded in the URL query string so a
user can share / bookmark a specific scenario:

```
https://<host>/?T_supply_floor=35&hours_of_store=24&slab_thickness_in=8
   &R_top=30&R_bot=60&R_edge=20&Q_in_store_max=10
   &two_separate_circuits=false&cooling_required=full_AC
   &T_store_max_cap=60&hp_curve_source=ecodan_published
```

Streamlit's `st.query_params` gives this for free.

## Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│  Sidebar (parameters)        │   Main area                          │
│                              │                                       │
│  Scenario:  ▼ Baseline       │   Scenario: Baseline                  │
│                              │                                       │
│  ── Boundary conditions ──   │   ┌─ Costed BOM ───────────────────┐ │
│  T_supply_floor [35] °C      │   │ Line item       Qty     Cost   │ │
│  Q_in_store_max [10] kW      │   │ Flowable fill   24.7yd³ $3 950 │ │
│  Q_out_max      [5]  kW      │   │ Top XPS R-30    1000ft² $1 800 │ │
│  T_oa_design    [-30] °C     │   │ Bottom EPS R-60 1000ft² $2 860 │ │
│                              │   │ Edge R-20 32"+wing       $550  │ │
│  ── Geometry / sizing ──     │   │ PEX (940 m)              $3 155│ │
│  hours_of_store [24]    h    │   │ Manifold (12-port)       $1 200│ │
│  slab_thickness [8]     in   │   │ ───────────────────────────────│ │
│  two_separate_circuits ▢     │   │ TOTAL                   $13 515│ │
│  cooling_required ▼ full_AC  │   │ $/kWh useful storage    $115   │ │
│                              │   └───────────────────────────────┘ │
│  ── Insulation R-values ──   │                                       │
│  R_top    [30] (sweep ─o─)   │   ┌─ Derived thermodynamics ──────┐  │
│  R_bot    [60]               │   │ T_HP,LWT,design     58 °C     │  │
│  R_edge   [20]               │   │ T_store,bulk,max    50 °C     │  │
│                              │   │ T_store,bulk,min    38 °C     │  │
│  ── HP / charge source ──    │   │ Useful ΔT           12 K      │  │
│  hp_curve_source ▼ ecodan    │   │ Charging LMTD       7.2 K     │  │
│  T_store_max_cap [60] °C     │   │ Δ_depr (disch)      2.7 K     │  │
│  charge_source_mix ▾ default │   │ Capacity            118 kWh   │  │
│                              │   │ Hours of store      23.6 h    │  │
│  [ Save as Scenario B ]      │   │ Standby loss        ~1 400 W  │  │
│  [ Reset to defaults ]       │   │ Standby loss / day  ~22 %     │  │
│                              │   └───────────────────────────────┘  │
│                              │                                       │
│                              │   ┌─ Cost vs hours_of_store ──────┐  │
│                              │   │ [line plot — sweep current   ]│  │
│                              │   │ [other params, vary hours ]   │  │
│                              │   └───────────────────────────────┘  │
│                              │                                       │
│                              │   ┌─ Scenario diff (A vs B) ──────┐  │
│                              │   │ (only shown when B is set)    │  │
│                              │   │ Δ Total cost: −$2 350         │  │
│                              │   │ Δ $/kWh:      −$20            │  │
│                              │   │ Δ Useful ΔT:  +5 K            │  │
│                              │   └───────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Inputs (sidebar widgets)

| Group | Widget | Parameter | Default | Range / values |
|---|---|---|---|---|
| Boundary | number | `T_supply_floor_design` (°C) | 35 | 28 – 45 |
| Boundary | number | `Q_in_store_max` (kW) | 10 | 5 – 20 |
| Boundary | number | `Q_out_max` (kW) | 5 | 3 – 10 |
| Boundary | number | `T_oa_design` (°C) | −30 | −40 – 0 |
| Geometry | slider | `hours_of_store` (h) | 24 | 6 – 48 |
| Geometry | number | `slab_thickness` (in) | 8 | 4 – 14 |
| Geometry | checkbox | `two_separate_circuits` | false | bool |
| Geometry | select | `cooling_required` | none | none / dehumid / full_AC |
| Insulation | number | `R_top` | 30 | 5 – 60 |
| Insulation | number | `R_bot` | 60 | 5 – 80 |
| Insulation | number | `R_edge` | 20 | 5 – 50 |
| HP / source | select | `hp_unit_selection` | puz_hwm140 | puz_hwm140 / arctic_060za / generic_cchp / field_validated |
| Materials | expander | unit-cost overrides | (defaults baked in) | — |

The capital-cost minimizer sizes for **HP alone at the design cold day**.
The HP selection pins `Q_in_store_max_design` (HP capacity at
`T_oa_design`) and `T_store_max_design` (HP LWT cap at acceptable COP).
The resistance element appears as a separate line item in the BOM but is
**not** a capital-sizing knob — its capacity is set by panel availability
and unit cost (~$100/kW). The operational overdrive that resistance buys
(higher Q_in_store, higher T_store than the HP alone could deliver) is a
property of the transactive operational model in
[`simulator.md`](simulator.md), not of this dashboard.

A "sweep ─o─" toggle next to `R_top`, `R_bot`, `R_edge`,
`slab_thickness`, and `hours_of_store` causes the main-area plot to
fix the other parameters and sweep the toggled one.

## Outputs (main area)

### Costed BOM table

`st.dataframe` with line items: flowable fill, top insulation,
bottom insulation, edge insulation + wing, PEX + support grid + fittings,
manifold + circulators + mixing valve, resistance element, HP unit
(priced via `../../heat-pumps/hp-curve.md`). Totals row, then
$/kWh-of-useful-storage row.

### Derived thermodynamics block

`st.metric` cards: T_HP,LWT,design, T_store,bulk,max,
T_store,bulk,min, useful ΔT, charging LMTD, Δ_depr (discharge),
total UA, capacity (kWh), hours-of-store actual, standby loss (W),
standby loss / daily delivered load (%), COP_charging at design,
COP_direct at design.

### Cost vs `hours_of_store` plot

Holding all other parameters fixed, sweep `hours_of_store` 6 → 48,
plot total cost and $/kWh on a twin-axis chart.

### Scenario A / B diff (optional)

When the user clicks "Save as Scenario B", the current parameters are
frozen as B and a new editable A appears. The main area adds a
side-by-side BOM compare and an absolute / percent delta table.

## Engine-side interface the dashboard calls

```python
from gw_thermal_store.engine import (
    ThermalStoreParams,  # pydantic dataclass with all the widgets above
    size_geometry,       # ThermalStoreParams -> Geometry
    cost_bom,            # (ThermalStoreParams, Geometry) -> BOM
    standby_loss,        # ThermalStoreParams -> LossBudget
    hp_cop,              # (lwt, oat, curve_source) -> (COP, Q_th, P_el)
)

# Per page render:
params = ThermalStoreParams(**st.session_state)
geom = size_geometry(params)
bom = cost_bom(params, geom)
loss = standby_loss(params)
cop_direct = hp_cop(lwt=params.T_supply_floor_design + 5,
                    oat=params.T_oa_design,
                    curve_source=params.hp_curve_source)
cop_charging = hp_cop(lwt=geom.T_HP_LWT,
                      oat=params.T_oa_design,
                      curve_source=params.hp_curve_source)
```

All engine functions are pure and decorated with `@st.cache_data` so
re-renders for unchanged inputs are free.

## Validation hooks shown to the user

The engine raises typed validation errors when a parameter combination
is infeasible (e.g., `T_HP,LWT,required > 65 °C hard cap`,
`useful_ΔT ≤ 0`, `slab_thickness < required_for_hours_of_store`).
The dashboard catches these and shows a red banner with the failing
constraint and a one-line hint at which parameter to change.

## Cache strategy

- `@st.cache_data` on the engine functions (pure, fast, cheap to
  invalidate on parameter change).
- `@st.cache_resource` on the materials tables / HP curve tables (they
  don't change between renders).

## Deploy

- Local dev: `uv run streamlit run src/gw_thermal_store/dashboard/app.py`.
- Internal staging: Streamlit Community Cloud, free tier (single user is
  fine for v0). Auth via Streamlit's built-in OIDC or just IP allowlist.
- Eventual prod: Dockerfile, deploy onto whatever internal Kubernetes
  / Fly.io / similar GridWorks already uses.

## Build phases

| Phase | Scope | Estimated work |
|---|---|---|
| 0 | Engine functions (`size_geometry`, `cost_bom`, `standby_loss`, `hp_cop`) with unit tests | 2–3 days |
| 1 | Streamlit app with sidebar widgets + BOM table + derived thermodynamics, no plots, no scenario diff | 1 day |
| 2 | Add cost-vs-hours_of_store plot and any other 1-D sweep plots | 0.5 day |
| 3 | Scenario A / B compare with diff table | 0.5 day |
| 4 | Validation error banners + polish | 0.5 day |
| 5 | Deploy to staging URL, share with Polstein / Siegenthaler | 0.5 day |

Total ~5 days for a usable v0.

## Testing

- Engine unit tests cover the math (one test per function with hand-
  computed expected values from `../research/`).
- Dashboard rendering test: import the Streamlit app module, assert it
  imports cleanly and that a sample parameter set produces a non-empty
  BOM (uses `streamlit.testing.v1` framework).
- Manual: walk through the parameter ranges in a browser, confirm no
  combination produces a Python exception or a nonsensical BOM.

## Open design questions (for early iteration)

- Do we want a "preset scenarios" dropdown (Baseline / Negative-price /
  Outage-resilience / Polstein-default) that snaps the sidebar to a
  named parameter set? Probably yes for v0.5.
- Do we want to expose the unit-cost overrides as editable widgets, or
  keep them code-side only? Code-side for v0; expose if Polstein wants
  to play with Siegenthaler-quoted pricing.
- Where do operating-cost / annual-arbitrage numbers come from? This
  module is capital-only; the dashboard should NOT lie about op cost.
  Either leave it out of the BOM, or show a separately-tagged
  "operating-cost estimate (out of scope)" with a clear caveat.
