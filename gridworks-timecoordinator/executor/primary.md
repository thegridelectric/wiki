# gridworks-timecoordinator — executor hub

Status: Draft · Pass 0 · Updated 2026-06-11

What this is: the rebuild spec for `gridworks-timecoordinator`, the
simulated-time authority. Mostly Open; this hub records what the
hello-world rebuild ([OPS-405](https://linear.app/gridworks/issue/OPS-405), shipped 2026-06-11, merged to `dev`)
settled. The poetry-era first-pass code lives whole on the `legacy`
branch — design intent, not implementation.

## Overview

The time coordinator broadcasts `sim.timestep` over the rabbit routing
fabric; every gwbase Orchestrator-tier actor already tracks simulated
time from these broadcasts (`on_simulated_time` hook, monotonic guard)
and can answer with `Ready` via `send_ready()`. The coordinator-side
Ready barrier (advance only when all expected participants have
reported) is Open — the hello coordinator free-runs.

## Settled facts (verified by the witnessed live run, 2026-06-11)

- **Not a GNode.** An `Orchestrator` subclass on plain
  `ServiceSettings` — no `g.node.gt.json`, no registry identity. Its
  alias lives in the GNode tree: **`d1.tc`**, chosen (over gwbase's
  `d1.time` example placeholder) anticipating a tree of time
  coordinators that work with each other. A root coordinator names
  itself as its own `my_time_coordinator_alias`. Harness participants
  must be configured with `my_time_coordinator_alias="d1.tc"`.
- **Naming.** Module `gwtc`, console script `tc-hello` (the
  gwbase/gwta precedent). uv project, src layout, Python
  `>=3.12,<3.14`, `gridworks-base>=0.5.2` from PyPI.
- **Transport.** `TransportClass.TimeCoordinator`, routing class
  `time` (`time_tx` consume / `timemic_tx` publish). Broadcasts are
  subscriber-bound: children bind their own queues to `timemic_tx`.
  Fabric direct edges into `time` exist from `ltn`, `mm`, `super`
  (Ready answers route); **no `ta→time` edge yet** — a gwbase
  `ROUTING_EDGES` addition when the simulated terminal asset joins the
  Ready barrier.
- **Hello mode pacing.** `tc-hello --beat-seconds B --step-seconds S`:
  every B wall-seconds, broadcast `sim.timestep` advancing `TimeUnixS`
  by S — sim time outruns wall time when S > B. Free-running; `Ready`
  arrivals are logged in `process_message`, nothing more.
- **Verified against gw-dev-rabbit** (dockerized dev broker): the live
  test's observer queue on `timemic_tx` received consecutive timesteps
  with advancing `TimeUnixS` — witnessed, not just sent.
- **Tests.** Offline smoke by default; broker tests marked `live`.

## Open

- The Ready barrier: who is "expected", straggler policy, advance
  rule — mine the `legacy` branch's semantics first (capture is
  explicit, silence is not capture).
- The tree of time coordinators (who advances whom).
- Pacing modes beyond free-run: as-fast-as-ready, scaled real-time.
- How `sim.timestep` crosses the MQTT bridge to scada-world consumers
  (specified in the scada simulated-test-environment design,
  `sim-time` spoke).
