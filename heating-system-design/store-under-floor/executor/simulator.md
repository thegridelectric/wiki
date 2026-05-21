# Simulator Agent — Design Plan

A SEMA-conformant agent that runs the under-floor thermal store as a
**peer GNode on the local RabbitMQ broker**, alongside
`gridworks-scada`. **Second deliverable** of the heating-system-design
repo. Extends `gwbase.SupervisableActor`; this is its own sibling
repo, **not** an in-process actor inside `gridworks-scada`.

## Goals

- Run the same physics engine the dashboard uses, but in real or
  simulated time, advancing state on a periodic tick.
- Accept commands from `gridworks-scada` over the local RabbitMQ
  broker — pump on/off, pump speed, mixing-valve position,
  resistance-element on/off (and its setpoint kW), HP-LWT setpoint.
- **Expose the operational overdrive** the dashboard's capital BOM does
  not see: the resistance element can drive `Q_in,store` *above* the
  HP-alone capability, and can drive `T_store` *above* the
  HP-favorable COP knee up to the PEX continuous-service limit. The
  agent simulates these regimes accurately; the controller (in scada or
  the future outer planner) decides when to use them.
- Publish telemetry back to the broker — temperatures at multiple
  depths in the slab, perimeter / bulk readings, fluid-loop in/out
  temperatures, instantaneous Q_in / Q_out / standby loss / electrical
  power.
- Optionally consume `SimTimestep` from a future `gridworks-
  timecoordinator` so accelerated- and replay-mode runs are possible.
- Pass `ScadaLiveTest`-equivalent integration tests against a real
  local RabbitMQ.
- Lay the substrate for chaos testing (broker disconnects, message
  loss, time skew, agent crashes) of the wider GridWorks agent system.

## Non-goals

- Decide which mode to run (charge vs discharge vs idle). The
  controller in `gridworks-scada` decides; this agent simulates the
  physical consequence.
- Implement HP firmware behaviour (defrost cycles, soft-start, capacity
  ramping). Model the HP at the COP-curve level only; defrost is a
  Phase-3 chaos-test concern.
- Talk directly to MarketMaker. The transactive controls live in
  scada; this agent never sees a price.

## Substrate summary (from gridworks-base survey)

Use **`gwbase.SupervisableActor`** as the base class. It handles
heartbeat + sim-time out of the box. It in turn extends
`gwbase.ActorBase`, which:

- Connects to RabbitMQ via **pika** (synchronous, SelectConnection).
- Declares per-actor exchanges `{routing_code}_tx` and
  `{routing_code}mic_tx`, plus an auto-named queue with auto-bindings.
- Routes messages through `DirectRoutingEnvelope` and
  `BroadcastRoutingEnvelope`; envelope builders are
  `actor.direct_envelope(...)` and `actor.broadcast_envelope(...)`.
- Calls subclass `process_message(envelope, body)` for every received
  payload.

The closest existing sibling template is
[`gridworks-marketmaker`](../../../../gridworks-marketmaker/) —
specifically `MarketMakerBase` extending `ActorBase`. We copy that
pattern, ignoring the market/Algorand bits.

Service discovery is **static** — peer aliases are hardcoded in
settings. Our actor publishes/subscribes by alias, and `gridworks-scada`
must also know our alias.

## Repo layout (the second-deliverable slice)

This is the same repo as the dashboard; the agent piece is the
`agent/` subpackage:

```
/Users/jessica/GridWorks/heating-system-design/
├── pyproject.toml
├── g_node.json                      # actor identity, alias "d1.thermal-store"
├── src/
│   └── gw_thermal_store/
│       ├── engine/                  # shared with dashboard
│       └── agent/
│           ├── __init__.py
│           ├── thermal_store_actor.py  # SupervisableActor subclass
│           ├── config.py               # extends GNodeSettings
│           ├── command_handler.py      # AnalogDispatch / FsmEvent → engine commands
│           ├── telemetry.py            # state → SingleReading / Report
│           ├── tick_loop.py            # advance physics every N seconds
│           └── data/
│               ├── channels.toml       # channel names + units + report cadence
│               └── peer_aliases.toml   # default peer-alias map
├── tests/agent/
│   ├── test_actor_recorder.py       # offline, no broker
│   ├── test_live_broker.py          # needs local RabbitMQ
│   └── test_command_handler.py
└── docs/
    └── architecture.md
```

## Actor identity

`g_node.json` at repo root:

```json
{
  "GNodeId": "<uuid4 generated once and locked>",
  "Alias": "d1.thermal-store",
  "BaseClass": "Logical",
  "GNodeClass": "TerminalAsset",
  "Status": "Active",
  "TypeName": "g.node.gt",
  "Version": "004"
}
```

The Polstein development would assign per-house aliases like
`d1.polstein.house-01.thermal-store`; the alias structure follows
whatever convention `gridworks-scada` uses for the project deployment.

## Class skeleton

```python
# src/gw_thermal_store/agent/thermal_store_actor.py
from typing import override
from gwbase.supervisable_actor import SupervisableActor
from gwbase.types import RoutingEnvelope, GwBaseSemaCodec
from gwsproto.named_types import AnalogDispatch, FsmEvent, SingleReading, Report

from gw_thermal_store.engine.params import ThermalStoreParams
from gw_thermal_store.engine.physics import tick, State
from gw_thermal_store.agent.config import ThermalStoreSettings
from gw_thermal_store.agent.command_handler import CommandHandler
from gw_thermal_store.agent.telemetry import TelemetryEmitter
from gw_thermal_store.agent.tick_loop import TickLoop


class ThermalStoreActor(SupervisableActor):
    def __init__(self, *, settings: ThermalStoreSettings) -> None:
        super().__init__(
            settings=settings,
            my_super_alias=settings.supervisor_alias,
            my_time_coordinator_alias=settings.timecoordinator_alias,
        )
        self.params: ThermalStoreParams = ThermalStoreParams.load(
            settings.params_path)
        self.state: State = State.initial(self.params)
        self.commands = CommandHandler(self.params)
        self.telemetry = TelemetryEmitter(
            from_alias=self.alias,
            scada_alias=settings.scada_alias,
            channels=self.params.channels,
            send=self.send,
        )
        self.tick_loop = TickLoop(
            tick_seconds=settings.tick_seconds,
            advance=self._advance,
            time_mode=settings.time_mode,
        )
        self.codec = GwBaseSemaCodec()

    @override
    def local_start(self) -> None:
        self.tick_loop.start()

    @override
    def local_stop(self) -> None:
        self.tick_loop.stop()

    @override
    def process_app_message(self, *, envelope: RoutingEnvelope,
                            body: bytes) -> None:
        obj = self.codec.from_bytes(body)
        if isinstance(obj, AnalogDispatch):
            self.commands.on_analog(obj)
        elif isinstance(obj, FsmEvent):
            self.commands.on_fsm_event(obj)
        # SimTimestep handled by SupervisableActor base if subscribed

    def _advance(self, dt_seconds: float, sim_clock_s: float) -> None:
        """Single tick — called by TickLoop on a timer or on SimTimestep."""
        self.state = tick(
            state=self.state,
            params=self.params,
            commands=self.commands.snapshot(),
            dt_seconds=dt_seconds,
            oat=self.commands.outdoor_air_temp_c,
        )
        self.telemetry.publish(self.state, sim_clock_s)
```

## Configuration (extends GNodeSettings)

```python
# src/gw_thermal_store/agent/config.py
from pathlib import Path
from typing import Literal
from pydantic_settings import BaseSettings
from gwbase.config import GNodeSettings

class ThermalStoreSettings(GNodeSettings):
    # peer aliases — hardcoded, no central registry
    scada_alias:           str = "d1.scada"
    supervisor_alias:      str = "d1.super1"
    timecoordinator_alias: str = "d1.time"

    # physics tick rate
    tick_seconds: float = 1.0

    # operational overdrive limits — go ABOVE the capital-design ceilings
    # but never above hardware safety. These belong here, not in the
    # dashboard's capital-min config.
    resistance_capacity_kw:    float = 10.0   # panel-bounded
    T_store_operational_cap_c: float = 80.0   # PEX-limited (~95 °C)
    Q_in_store_operational_cap_kw: float = 25.0  # tube-field UA × max LMTD

    # time source: wall-clock for real-time, "sim_timestep" for
    # time-coordinator-driven runs (Phase 3 chaos / replay)
    time_mode: Literal["wall_clock", "sim_timestep"] = "wall_clock"

    # path to a TOML file containing the ThermalStoreParams config
    params_path: Path = Path("/etc/gridworks/thermal_store_params.toml")
```

Env-var prefix `GW_THERMAL_STORE_` (pydantic default for nested
settings). RabbitMQ URL inherited from `GNodeSettings` (default
`amqp://smqPublic:smqPublic@localhost:5672/d1__1`).

## Incoming messages

| TypeName | Source | Handled by | Effect |
|---|---|---|---|
| `analog.dispatch` | `gridworks-scada` actor command tree | `CommandHandler.on_analog` | Decode `AboutName` + `Value` into a target setpoint (pump speed, mixing-valve position, HP LWT command). Update the command shadow. |
| `fsm.event` | scada | `CommandHandler.on_fsm_event` | Relay / valve on/off (P1, P2, V1, Zones, resistance element). Update the command shadow. |
| `sim.timestep` | future timecoordinator | `SupervisableActor` base → `TickLoop` | Advance simulated clock by the indicated dt; call `_advance`. |
| `heartbeat.a` | supervisor | `SupervisableActor` base | Reply with own heartbeat. |

Anything else is logged at WARN and dropped.

## Outgoing messages

| TypeName | Cadence | Channels carried |
|---|---|---|
| `single.reading` | On change (configurable hysteresis per channel) | One channel per message, used for high-priority readings the controller needs immediately. |
| `channel.readings` | Periodic (default 5 s window) | Time-aligned batch of recent samples for all active channels. |
| `report` | Periodic (default 5 min) | Snapshot batch: store state, energy in / out / loss totals, FSM states, command audit. |
| `snapshot.spaceheat` | On demand (request/reply) | Full state for controller planning horizon. |

### Channel set (initial)

| ChannelName | Unit | Source in engine state |
|---|---|---|
| `store_temp_top` | °C | T_layer[N] |
| `store_temp_mid` | °C | T_layer[N/2] |
| `store_temp_bot` | °C | T_layer[0] |
| `store_temp_perimeter_top` | °C | T_perimeter[N] |
| `store_temp_perimeter_bot` | °C | T_perimeter[0] |
| `charge_loop_in` | °C | fluid_in_charge |
| `charge_loop_out` | °C | fluid_out_charge |
| `discharge_loop_in` | °C | fluid_in_disch |
| `discharge_loop_out` | °C | fluid_out_disch |
| `floor_supply_after_mix` | °C | T_supply_floor (after mixing) |
| `floor_return` | °C | T_return_floor |
| `q_in_store_w` | W | derived |
| `q_out_store_w` | W | derived |
| `q_standby_loss_w` | W | derived (top + bot + edge) |
| `resistance_power_w` | W | from command shadow |
| `hp_thermal_w` | W | derived from HP COP curve + commanded LWT |
| `hp_electrical_w` | W | derived |
| `soc_pct` | % | (E_stored − E_min) / (E_max − E_min) |

All units SI in the message body; the engine carries them internally as
`pint.Quantity` and unit conversions happen at the boundary.

## Time mode

Two supported sources:

- **`wall_clock`** — `TickLoop` runs on `threading.Timer` at
  `tick_seconds` intervals; each tick advances the engine by the
  elapsed real time. This is the production mode for a deployed
  house.
- **`sim_timestep`** — `TickLoop` is driven by `SimTimestep` messages.
  Each incoming timestep tells the actor "advance simulated time to
  T+dt"; the actor runs as many internal substeps as needed to cover
  dt at `tick_seconds` granularity. This is the mode for accelerated
  replay and Phase-3 chaos tests.

Selection is a config flag, not two different agents.

## Local dev workflow

Steps to bring up the full local stack:

```bash
# 1. RabbitMQ (in gridworks-base)
cd /Users/jessica/GridWorks/gridworks-base
./x86.sh        # or ./arm.sh
# → broker at localhost:5672, admin UI at localhost:15672

# 2. The thermal-store actor (this repo)
cd /Users/jessica/GridWorks/heating-system-design
uv sync
export GW_THERMAL_STORE_PARAMS_PATH=./tests/agent/fixtures/baseline.toml
uv run python -m gw_thermal_store.agent

# 3. The scada peer (separate terminal)
cd /Users/jessica/GridWorks/gridworks-scada
# normal scada bring-up

# 4. Watch the RabbitMQ admin UI for messages flowing
open http://localhost:15672
```

A `Makefile` target `make dev` in the heating-system-design repo will
orchestrate steps 1–2 via a foreground tmux session.

## Testing

### Unit tests (`tests/agent/`)

- **`test_command_handler.py`** — feed it example `AnalogDispatch` and
  `FsmEvent` payloads (from scada's protocol package fixtures), assert
  the resulting command shadow matches.
- **`test_telemetry.py`** — feed a known engine state, assert the
  emitted `SingleReading`/`ChannelReadings` carry the expected values
  and units.
- **`test_actor_recorder.py`** — extend `SupervisableActor` with a
  recorder mixin, send dummy messages without a real broker
  (synchronous handler invocation), assert routing behaviour.

### Integration tests (`tests/agent/test_live_broker.py`)

Requires `./x86.sh` to be running (skipped otherwise via
`pytest.importorskip` or a `@pytest.mark.requires_broker`).

Pattern (cribbed from `gridworks-marketmaker`):

```python
async def test_thermal_store_against_scada_stub():
    scada_stub = ScadaStubRecorder(settings=stub_settings)
    actor      = ThermalStoreActor(settings=actor_settings)

    scada_stub.start()
    actor.start()
    try:
        # Send an AnalogDispatch to set pump P1 speed.
        cmd = AnalogDispatch(
            FromHandle="d1.scada",
            ToHandle="d1.thermal-store",
            AboutName="P1.speed",
            Value=80,
            ...
        )
        scada_stub.send_to(actor_alias, cmd)

        # Wait for telemetry feedback.
        readings = await scada_stub.await_readings(channel="q_in_store_w",
                                                    timeout=10.0)
        assert readings[-1].Value > 0
    finally:
        actor.stop()
        scada_stub.stop()
```

### Engine + agent end-to-end

Run a 24-hour scenario in sim_timestep mode at 1000× wall clock; assert
that under a fixed command sequence the final store SOC and total
energy-delivered match a golden-master file (regenerated only when the
engine math intentionally changes).

## Build phases

| Phase | Scope | Estimated work |
|---|---|---|
| 0 | uv-bootstrap the repo, pin `gwbase`, `gwsproto`, `pika`, `pydantic-settings`. Carve out `engine/` from the dashboard work. | 0.5 day |
| 1 | `ThermalStoreActor` skeleton subclassing `SupervisableActor`; `config.py`; `g_node.json`; "hello world" run that connects and heartbeats. | 1 day |
| 2 | `CommandHandler` — decode `AnalogDispatch` and `FsmEvent` into command shadow. Unit tests. | 1 day |
| 3 | `TickLoop` with `wall_clock` mode + wiring to engine `tick()`. | 0.5 day |
| 4 | `TelemetryEmitter` — `SingleReading` + `Report` emission. | 1 day |
| 5 | Local integration test with `./x86.sh` broker + stub scada peer; end-to-end "command in → telemetry out" passes. | 1 day |
| 6 | `sim_timestep` mode + accelerated replay test (24 h in <1 min). | 1 day |
| 7 | Docs (`docs/architecture.md`, `docs/operator-guide.md`) + README. | 0.5 day |

Total ~6.5 days after the dashboard's engine work is in place.

## How `gridworks-scada` is configured to see us

In scada's settings:

```python
class ScadaSettings(...):
    thermal_store_alias: str = "d1.thermal-store"   # (new)
```

In scada's component layout JSON (e.g., the Polstein-Nolan-store
layout), add a new ShNode of class `TerminalAsset` with our alias and a
component-type pointing to a new `RemoteThermalStoreComponent` — a thin
proxy that translates scada-side commands (relay state changes, pump
speeds) into `AnalogDispatch` / `FsmEvent` messages addressed to
`d1.thermal-store`, and consumes our telemetry to populate the scada
report.

The thermal-store agent itself does **not** appear in scada's process
tree. Scada talks to it like it would talk to a remote piece of
hardware.

## Chaos-test groundwork (Phase 3 of the broader roadmap)

Once the actor is up and stable, hooks for chaos testing can be added
without changing the engine:

- **Broker fault injection.** Wrap the pika connection in an
  intercepting layer that, on a configurable schedule or random seed,
  drops the connection, drops a percentage of messages, or adds
  latency. Implement as a thin shim around `gwbase.ActorBase`'s
  RabbitMQ wiring.
- **Engine fault injection.** Optional `Fault` class injected into the
  engine: stuck thermistor, runaway pump, frozen valve. Expose via a
  `inject_fault.<...>` admin message (separate from the normal command
  surface) so test orchestration can fire it.
- **Time skew.** Once `gridworks-timecoordinator` exists, drift its
  clock vs. wall-clock and watch every actor's response.
- **Crash + restart.** Kill the actor process mid-run, restart it,
  watch whether scada's "remote thermal-store" proxy reconnects
  gracefully and whether the engine resumes from a persisted snapshot
  or reinitialises.

A separate `gridworks-chaos` repo (or a top-level test orchestrator in
`gridworks-base`) is the right home for the scenario-driver logic.
This document scopes only the simulator-agent side.

## Gaps / dependencies

1. **`gridworks-timecoordinator` does not exist yet.** Required for
   `sim_timestep` mode in production. For local dev and engine tests,
   wall-clock mode is fine; for the multi-actor replay tests
   (Phase 6), build it as a tiny sibling repo (single actor that
   publishes `SimTimestep` at a configurable rate) — probably a few
   hundred lines of code based on the MarketMaker pattern.

2. **`RemoteThermalStoreComponent` does not exist in scada yet.** It
   has to be added on the scada side as part of bringing this
   simulator online for end-to-end tests. The work is in the scada
   repo, not here, but listed for visibility.

3. **`AnalogDispatch` may need new `AboutName` values** for the
   thermal-store-specific channels (pump P1 speed, pump P2 speed, V1
   open/close, mixing-valve position, resistance element on/off). If
   the existing string-based `AboutName` field is flexible enough,
   no protocol change. Confirm against the scada protocol package.

4. **No central alias registry.** Confirmed gap in the gwbase survey.
   We hardcode peer aliases. If the project ever wants dynamic
   registration, that's a gwbase enhancement, not a simulator
   feature.
