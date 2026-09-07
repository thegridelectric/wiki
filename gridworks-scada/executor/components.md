Status: Draft · Pass 0 · Updated 2026-09-07

# Components, device types, and the config list

What this is: how the scada models a physical device in the hardware
layout — the `ComponentGt` / `Component` / Cac triad, `MakeModel`, the
per-family layout buckets, and the per-device config list — plus the
known irregularities and the directions we mean to take it (the Cac
rename, the config-list revamp, sim at the device boundary). Current
mechanics are verified against code (file:line); the critiques and
directions are marked as such. Pairs with `executor/actors.md` (how a
node becomes a running actor) and the simulated-actors design spoke.

## The core triad

Three objects model one device:

- **`ComponentGt`** — the serializable/wire form
  (`named_types/component_gt.py`). Fields: `ComponentId`,
  `ComponentAttributeClassId`, `ConfigList`, `DisplayName`, `HwUid`,
  `TypeName`, `Version`. Every concrete component type (e.g.
  `PicoTankModuleComponentGt`) subclasses this directly — one flat level,
  no hierarchy.
- **`Component[ComponentT, CacT]`** — the runtime pair
  (`data_classes/components/component.py`): holds `gt` (the ComponentGt)
  and `cac` (the device type). Specializations bind the two, e.g.
  `ElectricMeterComponent = Component[ElectricMeterComponentGt,
  ElectricMeterCacGt]`.
- **The Cac** — `ComponentAttributeClassGt`
  (`named_types/component_attribute_class_gt.py`): `ComponentAttributeClassId`,
  `DisplayName`, `MakeModel`, `MinPollPeriodMs`,
  `TypeName="component.attribute.class.gt"`. Axiom: `MakeModel` maps to a
  fixed `ComponentAttributeClassId` via `CACS_BY_MAKE_MODEL`
  (`type_helpers/cacs_by_make_model.py`), so the make/model pins the Cac
  identity.

**Component = instance, Cac = type.** The component is *this* device on
*this* house (its HwUid, its channel wiring); the Cac is the kind of
device (its make/model and model-level attributes). Many components share
one Cac.

### "Cac" is being renamed to `device.type.gt`

Decided (Jessica, 2026-06-11): rename the ComponentAttributeClass concept
to **`device.type.gt`**. It reads plainly — a component is a device, its
Cac is the device's *type*. This doc uses "device type" for the concept
and "Cac" only where naming the current code.

### What `.gt` means: a seed-table bijection

A `.gt` TypeName signifies a type in a **natural bijection with a seed
database table** — the type is the row shape of a DB-backed table, one
type ↔ one table. That is the lens for the zoo below: a `*.gt` is
DB-backed; a plain runtime data-class is not. Today only **three** device
types carry their own `*.cac.gt` (DB-backed) TypeName —
`ads111x.based.cac.gt`, `electric.meter.cac.gt`,
`resistive.heater.cac.gt` — every other component shares the generic
`component.attribute.class.gt`.

## DeviceType — and the retirement of MakeModel (summer 2026)

A component's device category is an open `pascal.case` **`DeviceType`** — a value of
the `gw1.device.type` enum — carried **directly on the component** (no `cac_id`). It
**replaced `MakeModel`**, which is being **retired across summer 2026** (the
`jm/delete-cac-id` work) along with its machinery: the per-device `cac.MakeModel` access
and the `CACS_BY_MAKE_MODEL` (`MakeModel → UUID`) bijection. The `spaceheat.make.model`
enum stays in sema as **frozen base vocabulary**, but it no longer carries device
identity — `DeviceType` does. (Parts of the intro + zoo below still describe the
pre-retirement Cac/`MakeModel` loader as it finishes deleting; read them as the
*as-is mid-migration* mechanics, with `DeviceType` the target.)

**DeviceType is a code class, not a manufacturer model number.** We intentionally do
**not** replicate the model numbers manufacturers use; we name the **class the code
cares about**. All residential eGauge power meters are one device type
(`EgaugePowerMeter`) — the code treats them identically, so they share a single type
regardless of the manufacturer's per-unit model variations. A new `DeviceType` value is
minted only when a category carries information the code must handle differently (the
same bar that earns a specialized `*.device.type.gt` record — see below).

**Sim is just another DeviceType.** A simulated device carries a `Sim*` `DeviceType`
(`GridworksSimSensor`, `GridworksSimRelayBank`, `GridworksSimPowerMeter`, … — the
successors to the legacy `GRIDWORKS__SIM*` make/models), so the layout reads "sim" at
the device boundary, legible in the artifact. This is the seam the simulated-actors
design builds on, minus the legacy driver-class indirection that sat beneath it
(`drivers/power_meter/`, the "Russian dolls" anti-pattern).

**Hardware backend selection is the layout's job.** Whether an actor drives real
silicon or a fake is a per-device fact the layout states, never a runtime flag. A
board-resident actor (`I2cBus`, `Relay` on a GPIO relay, `GpioSensor`,
`I2cThermistorReader`, `ZeroTenOutputer` on a board DAC) reads
`board_component.simulated`, true when the board record's DeviceType is a
`gw1.sim.device.type` value (`SimGw108`); `I2cBus` is the single seam, choosing
`SimI2c` or smbus2 from `layout.scada_board()`, and the actors above it run one
body of code either way (`actors/i2c_bus.py`, `drivers/sim_i2c.py`). So a bench
box with a real `Gw108RevB` record drives the real chips even while its tank
modules are `SimSensor` and it holds no TaDeed. `ScadaAppInterface.is_simulated`
(no TaDeed or any sim component) answers a different question, whether this
scada is a real terminal asset, and gates only system-level behavior (the
sim-time bridge). Residue: the House0 Krida and DFR multiplexers still read that
bit, because the House0 component vocabulary has no sim twin for either device;
both retire in the krida shift.

## Node → component, and the per-family buckets

An `ShNode` references its component by `ComponentId`; the layout
populates `node.component` at load. `ComponentId` stays on the wire
beside the node `Name` even where a `ComponentBinding` holds: the Name
is the unique identity within the house, the ComponentId identifies the
physical instance, so a replacement (same name, new uuid) is trackable. The layout stores devices in
**per-family buckets**, not one list: `Ads111xBased*`, `ElectricMeter*`,
`ResistiveHeater*`, and a catch-all `Other*`, each split into a `*Cacs`
list and a `*Components` list. `hardware_layout.py` `load_cacs()` /
`load_components()` iterate a **hardcoded** set of four bucket names and
decode each via a union decoder, then pair component↔cac via
`make_component()`.

## The component zoo (18 types)

| TypeName | device | own Cac? | per-device config |
|---|---|---|---|
| `pico.tank.module.component.gt` | Pico tank temp reader | no (generic) | ConfigList; `extra=allow` |
| `pico.flow.module.component.gt` | Pico flow meter | no | none |
| `pico.btu.meter.component.gt` | Pico BTU (flow+temp) | no | none |
| `electric.meter.component.gt` | power meter | **yes** | ElectricMeterChannelConfig |
| `ads111x.based.component.gt` | ADS1115 ADC sensor | **yes** | AdsChannelConfig |
| `i2c.thermistor.reader.component.gt` | I2C thermistor reader | no | I2cThermistorChannelConfig |
| `i2c.multichannel.dt.relay.component.gt` | I2C relay board | no | RelayActorConfig; `extra=allow` |
| `gw108.gpio.relay.component.gt` | GPIO relay | no | RelayActorConfig (exactly 1) |
| `gw108.gpio.sensor.component.gt` | GPIO sensor | no | ChannelConfig (exactly 1) |
| `hubitat.component.gt` | Hubitat hub | no | embedded `Hubitat` |
| `hubitat.poller.component.gt` | Hubitat poller | no | embedded `Poller` |
| `rest.poller.component.gt` | REST poller | no | embedded `Rest` |
| `web.server.component.gt` | web server | no | embedded `WebServer` |
| `dfr.component.gt` | DFRobot analog out | no | DfrConfig |
| `fibaro.smart.implant.component.gt` | Fibaro Z-Wave | no | none |
| `resistive.heater.component.gt` | resistive element | **yes** | none |
| `sim.pico.tank.module.component.gt` | **sim** Pico tank | no | `SimulatesTypeName`/`Version`; `SimLifeS`/`SimRebootS` liveness script (the actor runs the pico); `extra=allow` |

## Irregularities (the warts, surfaced on purpose)

1. **The per-family buckets are intentional, the loader's list is the wart.**
   Intent (Jessica, 2026-06-11): a family gets its own bucket exactly when
   its device type carries information the code needs — a specialized
   `*.cac.gt`. So the three buckets are the three specialized device types,
   and everything on the generic Cac lands in `Other*` by design — not an
   incomplete refactor. The residual wart is only that the loader iterates a
   **hardcoded** bucket list rather than deriving it from which device types
   are specialized.
2. **3 of 18 device types are DB-backed (`*.cac.gt`) — by design.** A device
   type earns a specialized Cac (and its own bucket) precisely when it holds
   model-level info the code needs; the other 15 are fine on the generic Cac,
   their identity carried by their `DeviceType` (`MakeModel` pre-retirement). (The open question is narrower: is
   the `ads111x.based` vs `i2c.thermistor.reader` split — same physical job,
   one specialized, one generic — the right call, or duplication.)
3. **Two ways to read a thermistor.** `ads111x.based.component.gt`
   (specialized Cac, AdsChannelConfig) and
   `i2c.thermistor.reader.component.gt` (generic Cac,
   I2cThermistorChannelConfig) model the same physical job two ways —
   duplication from incremental growth.
4. **Two ways to say "simulated."** Now: a `Sim*` `DeviceType`
   (`GridworksSimSensor`, …) on a generic component (sim is a device-type
   value, legible at the boundary; successor to the legacy `GRIDWORKS__SIM*`
   make/models). Or: a dedicated `sim.*.component.gt` TypeName with
   `SimulatesTypeName`/`SimulatesVersion` (only `sim.pico.tank` so far) when
   the sim device needs extra config. The simulated-actors / self-faking-actors
   spokes build both out.
5. **`extra="allow"` on three types** (`pico.tank.module`,
   `sim.pico.tank.module`, `i2c.multichannel.dt.relay`) with no stated
   rationale — strict elsewhere.
6. **Near-duplicate sim type.** `sim.pico.tank.module` differs from
   `pico.tank.module` only by the two `Simulates*` fields — a whole second
   type instead of a sim marker on the one type.

## The config list — when a component carries one

A component carries a `ConfigList` if and only if the device has core
configuration to preserve beyond its binding: facts the actor needs to
drive the device that the layout states nowhere else. Otherwise the
component has no list at all. A list is never a home for capture or
report tuning; that lives in operational params (`capture.tuning`), and a
channel binds to its node through the DataChannel, not through a config
entry.

Applied to the board-resident words:

- **Relay** (`i2c.relay.component.gt`, `gpio.relay.component.gt`): the
  component names its board and which relay on it (`BoardComponentId`,
  `RelayName` or `GpioName`); the one `relay.control.config` carries what
  the relay actor needs to drive it (wiring, the event and state
  semantics of energizing and de-energizing). Real configuration, so the
  list stays.
- **0-10V output** (`i2c.dac.output.component.gt`): the component names
  its board and which DAC; the one `dac.output.config` carries the DAC
  channel and the EEPROM power-on code, reference, and gain. Real
  configuration, so the list stays.
- **Sensor** (`gpio.sensor.component.gt`): nothing to configure beyond
  the binding, so no list.

A single-device component's list has exactly one entry (axiom
`ExactlyOneConfig`); the list form is kept so the config word stays a
shared vocabulary word across component types rather than being
re-spelled on each. The old family of config words that carried
`Unit`, `Exponent`, and capture cadence on the component
(`channel.config`, `relay.actor.config`, the pico module configs) is
what this rule replaces; the retired `dfr.config` still carries that
shape in the beech fixture until the krida shift.

## What belongs in the hardware layout — and what doesn't

Critique / open articulation (Jessica invited it, 2026-06-11): the
hardware layout today carries more than hardware. Drawing the line:

- **Hardware truth (belongs in the layout):** which devices exist, their
  device type / make-model (including **whether they are simulated** — a
  hardware fact, legible per "say sim everywhere"), how they are wired
  (the command tree / handles), and what each channel measures. This is
  axis 3, hardware realization.
- **Operational policy (arguably does not belong):** capture/report
  cadence (`AsyncCaptureDelta`, `CapturePeriodS`, `PollPeriodMs`). It
  changes for bandwidth/reporting reasons, not because the hardware
  changed; binding it into the layout is what made cadence a hidden
  liveness lever.
- **Control / strategy (does not belong):** `Strategy`, zone kWh/°F,
  critical-zone lists — control configuration that references the layout
  but is not a fact about the hardware.
- **Calibration (type *or* instance — depends):** some calibration is
  model-level (a make/model's nominal beta, a calibration curve) and
  belongs with the device type (Cac / `device.type.gt`); but some is
  genuinely per-instance — thermistors vary unit to unit, so a specific
  sensor's correction is component-level data (Jessica, 2026-06-11). The
  point isn't "always type" — it's that the layout shouldn't bury
  calibration so it can't be told apart from wiring or capture policy.

The through-line: the layout should be the **hardware fact of the matter**
— what exists, how wired, what's measured, real-or-sim — and policy,
strategy, and calibration should reference it from their own homes rather
than ride inside it. This separation also sharpens the sim/real boundary
(a simulated device is a hardware fact the layout states plainly) and is a
natural input to the AllyLink/redo work, which is already pulling
realization out of actor code and into the layout.

## Open

- The Cac → `device.type.gt` rename (taxonomy + the DB-table bijection it
  implies for which families get their own table).
- The config-list revamp + `TelemetryName` → `gw1.unit` (scope, migration,
  the channel-identity / capture-policy split).
- Whether the per-family buckets collapse to a uniform list.
- Unifying the two sim expressions onto the device-boundary pattern the
  simulated-actors design selects.
