# SCADA simulated test environment

Status: Draft · Pass 0 · Updated 2026-06-10 · Linear: OPS-40

> What this is: a design for a robust simulated test environment for the SCADA —
> simple simulated terminal assets plus simulated sensor drivers (with a "cheat"
> mode for direct value injection) that otherwise exchange data over the dev
> Rabbit broker, with the simulated terminal assets built on gridworks-base.
> Ported from Linear **OPS-40** (which began as a narrower "run dev scada
> without crashing / `gen_orange` layout" task — mostly done — and is reframed
> here into the broader goal).

## Problem

We do not have a robust test environment for the SCADA. Today's options are
the real hardware (slow, physical, one-house-at-a-time) or partial unit tests.
We can't cheaply stand up a *whole* heating system — terminal asset + sensors +
SCADA control — in software and exercise it end to end, which is what we need
to test control logic, layouts, and fleet behaviour with confidence (and is a
prerequisite for the hybrid real+simulated fleet vision).

The target: **extremely simple simulations of the terminal asset** plus
**simulated drivers** that read "sensor" data, where a simulated driver either
(a) listens over the **dev Rabbit broker** used in testing, or (b) has a
**cheat option** to supply its own values directly (no broker round-trip). The
simulated terminal assets are built on **gridworks-base**.

## Current state — scaffolding already exists (2026-06-07)

This design generalizes existing seams rather than starting fresh.

- **`is_simulated` flag** — `ScadaSettings.is_simulated`
  (`gw_spaceheat/actors/config.py:62`), read across actors to skip real
  hardware: `i2c_relay_multiplexer.py:68,94` swaps in `SimulatedPin` objects;
  `i2c_zero_ten_multiplexer.py:173,199` branches the 0–10 V output;
  `sh_node_actor.py:98,114` skips setpoint/temperature reads; `ltn/ltn.py:219,269`
  injects a hardcoded 60 °F tank temp.
- **Driver abstraction + MakeModel-dispatch factory** — abstract bases
  `MultipurposeSensorDriver` (`drivers/multipurpose_sensor/…:15-32`) and
  `PowerMeterDriver` (`drivers/power_meter/…:19-60`); factories dispatch on
  `component.cac.MakeModel` (`actors/power_meter.py:93-109`,
  `actors/multipurpose_sensor.py:61-90`). **A simulated driver already exists:**
  `GridworksSimPm1_PowerMeterDriver` (MakeModel `GRIDWORKS__SIMPM1`) returns
  fake values — the precedent for both "simulated driver" and "cheat" modes.
- **Simulated layout components** — `layout_gen/simulated_tanks.py` builds tank
  modules from `SimPicoTankModuleComponentGt`; `api_tank_module.py:42-44`
  accepts the sim component.
- **Integration harness** — `tests/utils/scada_live_test_helper.py` `ScadaLiveTest`
  (extends `TreeLiveTest` from `gwproactor_test`) already starts LTN + SCADA
  over a **real Rabbit broker** with `child1_simulated=True`, and polls async
  predicates. The dev broker is provisioned via gridworks-base
  (`tests/_stubs.py` `provision_topology`/`declare_topology`; SCADA rides the
  Rabbit MQTT plugin, base is AMQP/pika).
- **gridworks-base simulation primitives** — `GridworksActor` (GNode actor base),
  and test stubs `GNodeStubRecorder` / `TimeCoordinatorStubRecorder`
  (`tests/_stubs.py`) that already act as synthetic GNodes; `make_g_node_json`
  factory (`tests/conftest.py:34-71`).

**Terminal asset** is a GNode *role* ("avatar for a real-world transactive
device"), not a scada actor; the SCADA reports on its behalf via
`terminal_asset_alias` (`layout_gen/layout_db.py:232-233`). A *simulated*
terminal asset is therefore a GNode actor (built on gridworks-base) that
publishes synthetic telemetry.

## What's missing (the design's scope)

The gaps between today and a full sim environment:

### 1. Simulated drivers for every sensor type (with cheat mode)
- Generalize the `GRIDWORKS__SIMPM1` precedent: a simulated driver for each
  abstraction (multipurpose/thermistor, power, flow, relay, 0–10 V).
- Each simulated driver supports two modes:
  - **broker mode** — subscribe to synthetic telemetry on the dev Rabbit broker
    (values produced by the simulated terminal asset), or
  - **cheat mode** — return caller-supplied values directly (no broker), for
    fast deterministic unit tests.
- Plug in via the existing MakeModel dispatch (add `GRIDWORKS__SIM*` values via
  the Sema word process) — no new factory machinery.

### 2. Simulated terminal asset on gridworks-base
- A `GridworksActor`-based synthetic GNode (GNodeClass `TerminalAsset`) that
  models an *extremely simple* heating system and **publishes synthetic sensor
  telemetry** over AMQP/the dev broker for the simulated drivers to read.
- "Extremely simple" first: plausible tank temps, flows, power that respond
  coarsely to SCADA relay/voltage commands — enough to exercise control paths,
  not a thermodynamic model. Richer physics is a later iteration.
- Reuse the `GNodeStubRecorder` / `make_g_node_json` patterns.

### 3. A complete simulated layout
- Extend `simulated_tanks.py` into a full **all-simulated hardware layout**
  (every component a `Sim*`/`GRIDWORKS__SIM*`), so `ScadaLiveTest` can bring up
  a whole simulated house in one call.

### 4. Harness wiring
- Add the simulated terminal asset as a participant in `ScadaLiveTest`
  alongside LTN + SCADA, and expose the cheat-injection seam to tests.

## First increment (Jessica, 2026-06-10): simulated temperature readers

The first concrete slice, motivated by spruce-unlimbo's merge gate ("real
tests of nolan AND house0"): **simulated temperature readers good enough
to exercise the simple-falling-edge-setpoint evaluation in test mode.**

- A simulated zone-temperature reader (the Nolan path: stands in for
  `i2c_thermistor_reader.py`'s gw-temp channels) that **responds 70 °F
  constant**, cheat-mode style — no broker required.
- Built with the **broker hook from day one**: the reader's value source
  is a seam that can later subscribe to synthetic telemetry on the dev
  Rabbit broker (scope item 1's broker mode), but the first
  implementation only stubs it.
- Note: the setpoint evaluation *learns* at a heat-call **falling edge**
  (gw-temp + heat-call are both inputs), so seeing it produce a setpoint
  in tests also needs heat-call transitions — either a simulated
  opto/GpioSensor with a scriptable square wave, or direct injection of
  `zone-X-opto-input` readings in the test. Constant-70 °F alone proves
  the plumbing, not the learning.
- House0 side: tank temps already have a sim path
  (`SimPicoTankModuleComponentGt` + the LTN's hardcoded 60 °F) — reuse,
  don't duplicate.

This slice should land as part of making the test suite run under BOTH
layouts (see spruce-unlimbo's merge gate), not as a Nolan-only fixture.

- **Cheat vs broker as the default.** Is the common case direct value injection
  (fast, deterministic, no broker) with broker-mode reserved for true
  end-to-end tests? Likely yes — confirm and make cheat the unit-test default.
- **Where the simulated terminal asset lives** — in `gridworks-base` proper (so
  it's reusable beyond scada and beyond tests), vs in scada/base test utilities.
  Leaning toward a real (non-test) gridworks-base component if we want it for a
  live simulated fleet, not just CI.
- **How synthetic physics is specified** — hardcoded curves vs a small
  declarative model vs scripted scenarios (for chaos testing). Start hardcoded;
  design the seam for scenarios.
- **Domain placement of this design** — kept under `gridworks-scada/` because the
  goal is testing SCADA, but the simulated-terminal-asset half is gridworks-base
  work; if the base simulation framework grows it may graduate to a cross-cutting
  `wiki/designs/` design. Flag at ratification.
- **New MakeModel sim values** — exact `GRIDWORKS__SIM*` names per sensor type.

## Implementation notes

- **No code yet.** Per the implementation gate, this design must reach
  `Accepted` (Pass ≥ 1) on every spoke before scada/base edits matching its
  scope begin.
- **Any Sema change** (new `GRIDWORKS__SIM*` MakeModel values, sim component
  types) goes through `/make-sema-word` — read `sema/CLAUDE.md` and follow it.
- Touch points: `gridworks-scada` (`drivers/`, `actors/` factories, `layout_gen/`,
  `tests/utils/`), `gridworks-base` (simulated terminal asset GNode actor,
  dev-broker test topology), `gridworks-protocol`/`sema` (MakeModel + sim
  component types).
- Relationship: subsumes OPS-40's original `gen_orange` dev-layout checklist;
  related to **OPS-118** (Dev mosquitto in Docker — the dev broker).
