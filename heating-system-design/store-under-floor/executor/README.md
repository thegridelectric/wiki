# `executor/` — Plans for the Code That Realizes This Design

This folder holds **design plans for the two executable artifacts** that
turn the research in `../research/` into something testable and
operable. Both artifacts live in the same new repository at
`/Users/jessica/GridWorks/heating-system-design/`, which we are
**converting into a uv-managed Python package**. The two artifacts share
a single core "engine" (the parameter → costed-BOM + simulated-physics
code) and differ only in how that engine is wrapped:

- **[`dashboard.md`](dashboard.md)** — a simple web dashboard
  (Streamlit) that exposes the model parameters as widgets, runs the
  capital-cost minimizer for the chosen parameter values, and renders
  the costed BOM as a table plus a few derived quantities and plots.
  This is the **first** deliverable so we can rapidly explore the
  parameter surface and align with Polstein / Siegenthaler on
  scenario inputs.

- **[`simulator.md`](simulator.md)** — a SEMA-conformant agent that
  extends `gwbase.SupervisableActor`, connects to a local RabbitMQ
  broker, accepts commands from `gridworks-scada` (relay states, pump
  speeds, mixing-valve setpoints), runs the 1-D layered thermal model
  in real-time or simulated-time, and publishes telemetry back to the
  broker as `SingleReading` / `Report` messages. This is the **second**
  deliverable and is the basis for end-to-end testing of the
  transactive controls and (eventually) chaos testing of the broader
  GridWorks agent ecosystem.

## The shared engine

Both artifacts wrap the same Python module. The engine has no I/O of
its own; it's a pure-functional core that:

| Engine function | Inputs | Outputs |
|---|---|---|
| `size_geometry(params)` | parameter set from `../research/design.md` | tube length, spacing, loop count, manifold size, useful ΔT, T_HP_LWT_required, T_store_min/max |
| `cost_bom(params, geometry)` | params + geometry | BOM line items + totals + $/kWh |
| `standby_loss(params)` | params | W of loss split top/bottom/edge |
| `tick(state, dt, commands, oat, hp_lwt)` | current store state + commands | next state + emitted telemetry |
| `hp_cop(lwt, oat, mode)` | LWT, OAT, curve mode | COP, Q_thermal, P_electrical |

The dashboard calls `size_geometry` + `cost_bom` + `standby_loss`
synchronously. The simulator agent calls `tick` every simulated second
plus `hp_cop` whenever the HP is running. The cost / sizing functions
are decoupled from the time-stepping physics so the dashboard does not
need to run real time.

## Why one repo, not two

The two artifacts share enough code (the engine, the parameter dataclass,
the BOM definitions, the unit tables) that splitting them creates a sync
burden with no benefit. A single uv-managed repo with three subpackages
(`engine`, `dashboard`, `agent`) is the right scope.

## Repo layout target

```
/Users/jessica/GridWorks/heating-system-design/
├── pyproject.toml                  # uv-managed
├── README.md
├── src/
│   └── gw_thermal_store/
│       ├── __init__.py
│       ├── engine/                 # pure physics + cost; no I/O
│       │   ├── params.py           # ThermalStoreParams pydantic model
│       │   ├── geometry.py         # size_geometry()
│       │   ├── cost.py             # cost_bom()
│       │   ├── losses.py           # standby_loss()
│       │   ├── physics.py          # tick(), 1-D layered slab model
│       │   ├── hp_curve.py         # hp_cop() — Carnot-fraction model
│       │   └── data/
│       │       ├── materials.toml  # CLSM properties, insulation costs
│       │       └── hp_curves.toml  # generic, Ecodan, Arctic coefficients
│       ├── dashboard/              # Streamlit app
│       │   ├── app.py
│       │   └── plots.py
│       └── agent/                  # gwbase actor
│           ├── thermal_store_actor.py
│           ├── config.py
│           ├── command_handler.py
│           └── telemetry.py
├── tests/
│   ├── engine/
│   │   ├── test_geometry.py
│   │   ├── test_cost.py
│   │   └── test_physics.py
│   ├── dashboard/
│   │   └── test_app_renders.py
│   └── agent/
│       ├── test_actor_recorder.py
│       └── test_live_broker.py     # needs local RabbitMQ
├── g_node.json                     # actor identity
└── docs/
    ├── architecture.md
    └── operator-guide.md
```

## File map for this folder

- [`README.md`](README.md) — this file.
- [`dashboard.md`](dashboard.md) — dashboard design plan.
- [`simulator.md`](simulator.md) — simulator-agent design plan.
