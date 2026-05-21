# `executor/` — Plans for the Code That Realizes This Design

This folder holds **design plans for three executable artifacts** that turn
the research in [`../research/`](../research/) into something testable,
buildable, and operable. Mirrors the pattern in
[`../../store-under-floor/executor/`](../../store-under-floor/executor/) but
adds a CFD project, because the diffuser-geometry sub-question requires
buoyancy-driven CFD that the fast 1-D simulator can't answer.

## The three projects

- **[`cfd.md`](cfd.md)** — Offline CFD analysis (OpenFOAM, 2-D axisymmetric,
  buoyantBoussinesqPimpleFoam). First pass: **flute vs disc diffuser**
  thermocline preservation. Second pass (later): calibrate the 1-D
  multi-node model's mixing/entrainment coefficients from CFD runs across
  the operating envelope. **This is the first deliverable** because it
  unblocks the diffuser CAD ask to Garth and pins the simulator's
  numerical coefficients.

- **`dashboard.md`** (TBD) — Streamlit dashboard analogous to
  [`../../store-under-floor/executor/dashboard.md`](../../store-under-floor/executor/dashboard.md).
  Exposes the parameter table from
  [`../research/design.md`](../research/design.md) as widgets, runs the
  costed-BOM minimizer, and renders capacity, standby loss, and the
  capital cost vs. shift-kWh trade. Second deliverable.

- **`simulator.md`** (TBD) — SEMA-conformant
  `gwbase.SupervisableActor` running the **1-D N-node stratified-tank
  model** in real-time or simulated-time, with the injection-elevation
  valve, Sieg loop, and immersion-heater commands wired to a local
  RabbitMQ broker. Third deliverable, depends on CFD-derived
  coefficients for the mixing/entrainment terms.

## Shared engine

All three projects share a Python core (target repo:
`/Users/jessica/GridWorks/heating-system-design/`, alongside the
store-under-floor engine). The engine has no I/O; CFD case generation,
dashboard, and agent all wrap it. Engine surface:

| Function | Inputs | Outputs |
|---|---|---|
| `size_module(params)` | parameter set from `../research/design.md` | tank H/D, HX kW + plates, valve sizes, port elevations |
| `cost_bom(params, geometry)` | params + geometry | BOM line items + totals + $/kWh useful |
| `standby_loss(params)` | params | W of loss split by tank surface + ports |
| `tick(state, dt, commands, inputs)` | N-node tank state + valve cmds + boundary temps/flows | next state + telemetry |
| `generate_cfd_case(params, case_spec)` | params + a case spec (inlet device, flow rate, ΔT) | OpenFOAM case directory ready to run |
| `fit_1d_coeffs(cfd_results)` | CFD field outputs | mixing/entrainment coefficients for `tick` |

The CFD project's outputs flow back as inputs to the engine: it's not a
fork, it's a calibration step.

## File map

- [`README.md`](README.md) — this file.
- [`cfd.md`](cfd.md) — first-pass CFD plan (flute vs disc).
- `dashboard.md` (TBD).
- `simulator.md` (TBD).
