# Thermal-Store Simulator as a SEMA Agent

Design notes for building the under-floor thermal-store simulation as an
**agent that speaks SEMA over a local MQTT broker**, integrates with the
existing GridWorks SCADA actor system, and lays groundwork for a chaos-
testing suite spanning the wider agent ecosystem (gridworks-scada,
gridworks-marketmaker, future gridworks-timecoordinator).

## Why route the simulator through SEMA

Three reasons it earns its keep beyond "just write a script":

1. **The physics module is more useful as a controllable device than as
   a notebook.** Once it speaks SEMA, the existing transactive controls
   can drive it the same way they'd drive a real installation. Every
   control strategy, every market-bid logic, every fault-tolerance
   pathway is exercisable end-to-end before any concrete is poured.
2. **It is the cleanest way to test the SCADA upgrade for the
   under-floor store.** The new store requires new actor types (charging-
   tube circulator, discharging-tube circulator, mixing valve with
   geometry-derived margin, resistance element, T_HP,LWT command);
   exercising those against a high-fidelity simulator catches state-
   machine bugs that a unit test does not.
3. **It is a tractable first step toward chaos testing the whole agent
   ecosystem.** A SEMA-conformant simulator gives us a controllable,
   reproducible peer on the broker. Subsequent chaos hooks (broker
   disconnects, message loss, agent crashes, clock skew) can all
   build on it.

## What's already in the sibling repos

(From a survey of `/Users/jessica/GridWorks/{gridworks-scada,
gridworks-marketmaker, gridworks-base, gridworks-protocol, sema}/`.)

### SEMA — the protocol
- Spec: [`/Users/jessica/GridWorks/sema/spec/primary.md`](../../../../sema/spec/primary.md) (hub; spokes under `sema/spec/{registry,authoring}/`).
- A **boundary protocol**, not a runtime — JSON-Schema-typed messages with
  `TypeName` and `Version`, CamelCase fields, immutable primitive formats
  (e.g., `uuid4.str`, `utc.seconds`), monotonic versioning.
- Relevant message types already defined: `report` (5-min telemetry
  batches), `channel.readings`, `power.watts`, `snapshot.spaceheat`.

### SCADA — the actor system
- Base classes in
  [`gridworks-scada/gw_spaceheat/actors/sh_node_actor.py`](../../../../gridworks-scada/gw_spaceheat/actors/sh_node_actor.py)
  (`ShNodeActor`, extends `Actor` from `gwproactor`) and
  `pico_actor_base.py`.
- 49 component types already exist
  ([`gridworks-scada/packages/gridworks-scada-protocol/src/gwsproto/data_classes/components/`](../../../../gridworks-scada/packages/gridworks-scada-protocol/src/gwsproto/data_classes/components/)),
  including `SimPicoTankModuleComponent` (a simulated tank with depth
  layers — the right reference example for our simulator), `HpBoss` (HP
  control), I²C relay multiplexers (valve / element control), thermistor
  readers, BTU meters.
- Hardware topology is a JSON layout file (e.g.,
  [`gridworks-scada/tests/config/nolan-layout.json`](../../../../gridworks-scada/tests/config/nolan-layout.json));
  layout generation tooling lives in `gw_spaceheat/layout_gen/`.
- `is_simulated: bool` flag in `ScadaSettings` already stubs hardware
  out — the entry point for our simulator.

### MQTT — the transport
- Two brokers: **RabbitMQ with MQTT plugin on 1885** (`gridworks_mqtt`,
  SCADA ↔ cloud Atn) and **Mosquitto on 1883** (`local_mqtt`, SCADA ↔
  Scada2). Setup in [`gridworks-base/README.md`](../../../../gridworks-base/README.md).
- Topic routing goes through gwproactor's RabbitMQ binding pattern
  (not raw MQTT topic strings). Bindings already exist for
  TimeCoordinator → MarketMaker (`rjb.<TimeCoordinator-alias>.timecoordinator.sim-timestep`).

### MarketMaker — the price source
- [`gridworks-marketmaker/src/gwmm/market_maker_base.py`](../../../../gridworks-marketmaker/src/gwmm/market_maker_base.py).
- Publishes `LatestPrice`, `MarketPrice`, `HourlyPriceForecast`;
  receives `AtnBid` / `AcceptedBid` from transactive participants.
- Consumes `SimTimestep` from a TimeCoordinator to advance simulated
  time, via `new_timestep()` / `repeated_timestep()` hooks.

### TimeCoordinator — referenced, not yet built
- `GNodeRole.TimeCoordinator` is defined and MarketMaker subscribes to
  its `SimTimestep` messages, but **no `gridworks-timecoordinator`
  repository exists yet**. Currently time-injection happens via the
  `LtnApp` parent in the SCADA live-test harness, not as a network
  service.
- This is a missing piece for both transactive simulation and chaos
  testing.

### Chaos testing — essentially absent
- No `chaos`, `fault`, or `inject` patterns in the codebases.
- The closest existing infrastructure is `ScadaLiveTest`
  ([`gridworks-scada/tests/utils/scada_live_test_helper.py`](../../../../gridworks-scada/tests/utils/scada_live_test_helper.py)),
  an async multi-process harness that spins up Ltn (parent), Scada, and
  optionally Scada2 (LAN secondary) apps and waits for messaging to
  quiesce. Good harness; no fault injection on top.

## Recommended architecture

**Live the simulator as an in-process SCADA actor**, not a separate
service. Reasons:

- Reuses `ShNodeActor`, layout JSON, settings, telemetry batching, link
  management, test harness — none of which we need to rebuild.
- Follows the precedent of `SimPicoTankModuleComponent`, which is
  exactly this pattern for a stratified water tank.
- Switching to a standalone process later is straightforward if we ever
  need it (gwproactor supports peer Scada2-style processes), but
  doing it first would multiply the integration work for no benefit
  at this stage.

### New module pieces

```
gridworks-scada/
  packages/gridworks-scada-protocol/src/gwsproto/data_classes/components/
    underfloor_store_component.py            # new ComponentType
  gw_spaceheat/
    actors/
      underfloor_store_simulator.py          # new ShNodeActor subclass
    layout_gen/
      underfloor_store.py                    # layout generator helper
  tests/
    actors/
      test_underfloor_store_simulator.py     # live tests
    config/
      polstein-nolan-store-layout.json       # template layout
```

### Inputs / outputs of the simulator actor

**Consumes** (over the SCADA command tree, all already typed):
- `FsmEvent` — relay / valve state changes (P1 on/off, P2 on/off, V1
  open/close, resistance element on/off, zone valves Z1–Z4).
- `AnalogDispatch` — modulated commands (pump speed 0–100 %, mixing-valve
  position 0–10 V, optionally an HP-LWT setpoint command).
- `SimTimestep` — externally-injected simulated time, when running
  against a TimeCoordinator. In standalone tests, an internal wall-clock
  tick is fine.

**Publishes** (telemetry, batched into the standard `report` envelope):
- `ChannelReadings` — multi-channel temperature reads:
  - `store_temp_top`, `store_temp_mid`, `store_temp_bot` (depth layers
    in the flowable-fill slab),
  - `store_temp_perimeter` (the cold-zone instrumentation from
    `edge-loss.md`),
  - `charge_loop_in`, `charge_loop_out`, `discharge_loop_in`,
    `discharge_loop_out` (fluid temps),
  - `floor_supply`, `floor_return`.
- `PowerWatts` — instantaneous Q_in_store_W, Q_out_store_W,
  Q_standby_loss_W, resistance_power_W, HP_thermal_power_W (with COP
  derived from `hp-curve.md`).
- `snapshot.spaceheat` — full SOC / energy-stored / useful-ΔT-remaining
  state, for the controller's planning horizon.

### Physics engine inside the actor

The actor's `tick()` method advances a **1-D layered finite-volume
model** of the slab plus a 0-D lumped fluid loop:

```
for each tick (default 1 s):
    for each depth layer i:
        Q_in_i  = sum_j  C_ij  · (T_layer_j  − T_layer_i)        # interlayer conduction
        Q_in_i += active_charge_flow ?  ṁ·cp·(T_chrg_fluid_i − T_layer_i) · effectiveness  : 0
        Q_in_i -= active_disch_flow ?  ṁ·cp·(T_layer_i − T_disch_fluid_i) · effectiveness  : 0
        Q_in_i -= top_loss_i + bot_loss_i + edge_loss_i           # from R-values
        T_layer_i += Q_in_i · Δt / (ρcp · V_i)
    publish channel readings if reporting interval elapsed
```

All the coefficients (`C_ij`, effectiveness, loss UAs) come straight
from the analytical work already in `pipe-geometry.md`, `insulation.md`,
and `edge-loss.md`. The HP COP curve from `../../heat-pumps/hp-curve.md`
gives `P_electrical = Q_thermal / COP(LWT, OAT)`.

### Time and price hookups

- **Time**: Subscribe to `SimTimestep` from whatever GNode is acting as
  TimeCoordinator. In the SCADA test harness today that's the `LtnApp`
  parent process; eventually it should be the standalone
  gridworks-timecoordinator (see roadmap below). Standalone runs can
  fall back to wall-clock ticks gated by an `is_simulated_time` flag.
- **Price**: Subscribe to `LatestPrice` from MarketMaker. The
  simulator itself doesn't decide what to do with price — that's the
  transactive controls' job — but **the simulator's snapshots feed the
  controller's planning state**, so the price-aware decisions get
  driven against a realistic physics response.

## Chaos-testing roadmap

The simulator-as-agent makes the rest of the chaos suite tractable.
Suggested phasing:

### Phase 1 — Determinism & reproducibility (low-hanging fruit)
- Seeded RNG inside the simulator (for any stochastic processes —
  measurement noise, defrost-cycle jitter, etc.).
- Scenario replay: load a price + weather trace, run end-to-end, assert
  cumulative kWh / cost / comfort metrics within tolerance.
- Golden-master tests on snapshot sequences.

### Phase 2 — Single-link fault injection
Add hooks in `gwproactor` (or a sibling chaos-injection library):
- **Broker disconnect / reconnect** at scheduled or randomized times.
- **Message-loss probability** per link (drop X % of `report` messages
  upstream, see if SCADA's resend logic catches up).
- **Latency injection** per link (add N ms of delay to a particular
  topic).

The thermal-store simulator is the load that exercises each of these
— while the broker is flaky, the simulator keeps producing physical
state, and we measure whether the controller stays in spec.

### Phase 3 — Multi-actor scenarios
- **Agent crash + restart** — kill the simulator process mid-run, watch
  whether SCADA / Atn / MarketMaker recover gracefully and whether
  state catches up after restart.
- **Time skew** — once gridworks-timecoordinator exists as a peer
  service, deliberately drift its clock vs. wall-clock; assert no
  agents lose their footing.
- **Out-of-order messages** — reorder a percentage of timesteps; assert
  the FSMs in `LeafAlly` / `HpBoss` / our new
  `UnderfloorStoreSimulator` handle it.
- **Bid storms / price spikes** — feed MarketMaker an extreme price
  trajectory; verify simulator's controller bids stay within
  protocol-defined limits.

### Phase 4 — Scale
- Many simulator instances on one broker (every house in the Polstein
  development gets its own actor; the broker serves them all). At 100
  homes × 7 actors per house, ~700 actors on one MQTT broker — well
  within Mosquitto's capacity, but worth stress-testing the message
  fanout and the MarketMaker's bid-handling throughput.

## Missing prerequisite: `gridworks-timecoordinator`

The biggest gap surfaced by the survey is that **the TimeCoordinator
role is referenced everywhere but does not exist as a deployable
service yet**. Building it as a new sibling repo unlocks both:

- Real transactive simulation (MarketMaker, simulator, and SCADA all
  advancing simulated time in lockstep over the broker).
- Time-skew chaos testing (Phase 3 above).

This is probably a small repo — a single actor that publishes
`SimTimestep` at a configurable rate (real-time, accelerated, or
externally-stepped), plus a REST endpoint for one-shot time queries.
Worth scoping as a sibling deliverable, not a blocker for the
simulator itself (which can fall back to LtnApp-injected time in the
SCADA test harness for Phase 1 work).

## Concrete next steps

1. Stand up the `UnderfloorStoreSimulator` actor in
   `gridworks-scada/gw_spaceheat/actors/` extending `ShNodeActor`,
   using `SimPicoTankModuleComponent` as a copy-and-modify template.
2. Add `UnderfloorStoreComponent` to gwsproto with the parameters from
   the model interface in [`design.md`](design.md): `T_supply_floor_design`,
   `hours_of_store`, `Q_in_store_max`, `two_separate_circuits`,
   `cooling_required`, fill thickness, R-values, etc.
3. Wire the 1-D layered physics engine inside the actor's `tick()`.
4. Generate a Polstein-Nolan-store layout JSON; instantiate via
   `ScadaLiveTest` and run a baseline 24-hour scenario.
5. Add scenario replay with a Maine TMY weather file + a representative
   Maine TOU price trace; produce golden-master snapshot.
6. Scope `gridworks-timecoordinator` as a sibling repo, schedule.
7. Begin Phase 2 chaos hooks once the simulator is producing stable,
   reproducible physics for unstressed scenarios.
