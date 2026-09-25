Status: Draft · Pass 0 · Updated 2026-09-25

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

A component's device category is its **`DeviceType`**, carried directly on the
component. The sema words leave the field an open `pascal.case` string so other
organizations can use the schemas. Inside gwsproto every value comes from the two closed
lists we own, `gw1.device.type` (real) and `gw1.sim.device.type` (simulated), and the
twins type the field `AnyDeviceType` (`DeviceType | SimDeviceType`,
`gwsproto/enums/__init__.py`): `DeviceComponentBase` for every component twin, and the
five device-type record twins. A name in neither list raises at construction, not at
bind time in the loader; the two enums carry no `default()`, so an unknown name is never
coerced to a member. The enums are `StrEnum`s whose value is the name, so readers compare
and key on them as strings and the wire form is unchanged. The `spaceheat.make.model`
enum stays in sema as frozen base vocabulary and carries no device identity.

**DeviceType is a code class, not a manufacturer model number.** We intentionally do
**not** replicate the model numbers manufacturers use; we name the **class the code
cares about**. All residential eGauge power meters are one device type
(`EgaugePowerMeter`) — the code treats them identically, so they share a single type
regardless of the manufacturer's per-unit model variations. A new `DeviceType` value is
minted only when a category carries information the code must handle differently (the
same bar that earns a specialized `*.device.type.gt` record — see below).

**Sim is a disjoint vocabulary.** A simulated device carries a `gw1.sim.device.type`
value (`SimSensor`, `SimPowerMeter`, `SimGw108`, `SimKridaDoubleRelayBoard16`, …), and
the two enums share no values, so a consumer tells simulated from real by which
vocabulary the value belongs to, never by inspecting the name. The layout reads "sim"
at the device boundary, legible in the artifact.

**Sim lives at the board for board-resident devices; only a standalone device gets a
sim word.** A relay, a 0-10V output or a thermistor reader on a board is the real
component word (`i2c.relay.component.gt`, `gpio.relay.component.gt`,
`i2c.dac.output.component.gt`, `i2c.thermistor.reader.component.gt`) with no
`DeviceType` of its own; the board record's `DeviceType` (`SimGw108`,
`SimKridaDoubleRelayBoard16`) says sim for everything on it, and the real actors run
their genuine choreography against the sim register backend. There is no
`sim.relay.*` or `sim.dac.*` word and no sim relay or sim DAC actor. A device with no
board (a tank module, a power meter, a plain sensor) carries its own `DeviceType`, and
a `sim.*.component.gt` word exists only where the simulated device needs config the
real word cannot hold (`sim.sensor.component.gt`, `sim.pico.tank.module.component.gt`).
The simulated plant reads the same registers, so this is one mechanism for local tests
and the plant alike.

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
answers a different question, whether the layout carries any simulated
device (`HydronicLayout.has_simulated_component`), and gates only the
sim-time bridge; whether the scada may trade is the deed's
`validation_state` (`scada-ltn-link-state.md` "The trading gate").

A `GpioSensor` on a simulated board reads `sim_pin_value` in place of the
pin. It starts at 1, the idle level of a `DigitalZeroIsActive` opto, and a
test or the simulated plant sets it, which is how a sim zone's heat call is
driven from pin to derived channel (`actors/gpio_sensor.py`,
`tests/actors/test_gpio_sensor.py`).

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
| `pico.tank.module.component.gt` | Pico tank temp reader | no (generic) | none; `PicoBoardVariant`, optional `MicropythonVersion`; `extra=allow` |
| `pico.flow.module.component.gt` | Pico flow meter | no | none; `PicoBoardVariant`, optional `MicropythonVersion` |
| `pico.btu.meter.component.gt` | Pico BTU (flow+temp) | no | none; `PicoBoardVariant`, optional `MicropythonVersion`; `use_enum_values=True`, so its enum fields are strings at runtime |
| `electric.meter.component.gt` | power meter | **yes** | ElectricMeterChannelConfig |
| `ads111x.based.component.gt` | ADS1115 ADC sensor | **yes** | AdsChannelConfig |
| `i2c.thermistor.reader.component.gt` | I2C thermistor reader | no | I2cThermistorChannelConfig |
| `i2c.multichannel.dt.relay.component.gt` | I2C relay board | no | RelayActorConfig; `extra=allow`; scada no longer reads it (the gwsproto twin stays until the House0 word drops it) |
| `gw108.gpio.relay.component.gt` | GPIO relay | no | RelayActorConfig (exactly 1) |
| `gw108.gpio.sensor.component.gt` | GPIO sensor | no | ChannelConfig (exactly 1) |
| `hubitat.component.gt` | Hubitat hub | no | embedded `Hubitat` |
| `hubitat.poller.component.gt` | Hubitat poller | no | embedded `Poller` |
| `rest.poller.component.gt` | REST poller | no | embedded `Rest` |
| `web.server.component.gt` | web server | no | embedded `WebServer` |
| `fibaro.smart.implant.component.gt` | Fibaro Z-Wave | no | none |
| `resistive.heater.component.gt` | resistive element | **yes** | none |
| `sim.pico.tank.module.component.gt` | **sim** Pico tank | no | `SimulatesTypeName`/`Version`; `SimLifeS`/`SimRebootS` liveness script (the actor runs the pico in-process, no HTTP ingress; absent = no scripted death / a dead pico stays dead; reboots always succeed); `extra=allow` |
| `sim.pico.btu.meter.component.gt` | **sim** Pico BTU | no | `SimulatesTypeName`/`Version`; `SimLifeS`/`SimRebootS`; runs under `ApiBtuMeter` the way the sim tank runs under `ApiTankModule` |
| `sim.pico.flow.module.component.gt` | **sim** Pico flow | no | `SimulatesTypeName`/`Version`; `SimLifeS`/`SimRebootS`; no actor runs it (`ApiFlowModule` takes the real word only) |

## Irregularities (the warts, surfaced on purpose)

1. **The per-family buckets are intentional, the loader's list is the wart.**
   The intent: a family gets its own bucket exactly when
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
4. **Two ways to say "simulated."** Settled in "DeviceType — and the
   retirement of MakeModel": a `Sim*` `DeviceType` on the board (or on a
   standalone device's own record), and a `sim.*.component.gt` word only
   where the simulated device needs config the real word cannot hold.
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
what this rule replaces. `dfr.component.gt` and `dfr.config` are orphaned
(`replaced_by` the DAC output pair) and out of both layout words' unions;
the component twin is gone and the `dfr.config` twin remains.

## The pico params handshake

A pico posts its params word at every boot (`tank.module.params`,
`async.btu.params`, `flow.hall.params`, `flow.reed.params`) to its actor's
web route, and the actor answers with the same word carrying the values the
layout says the pico should run with. The exchange settles three things.

- **Which pico this is.** Identity is the `HwUid`. A post whose `HwUid`
  matches the component's is answered; a component with no `HwUid` yet
  accepts the first pico that names its node and logs the id for the layout
  to take; any other pico gets an empty answer and its readings are ignored.
- **What board it is.** The tank, BTU and hall-flow words carry the pico's
  `PicoBoardVariant` and `MicropythonVersion`. The component's values are
  what the house was provisioned with, and the scada never writes them. The
  actor holds an accepted post against them (`actors/pico_identity.py`) and
  sends a Warning `Glitch` to the LTN for each difference, once per scada
  run, because picos re-post at every boot and the pico-cycler reboots them.
  A component with no `MicropythonVersion` holds the post to none. The pico
  is answered either way. A post that matches the layout sends nothing.
- **Which version it speaks.** The answer goes back in the version the pico
  posted. The tank and BTU actors accept their identity-carrying version
  only. The flow actor accepts `flow.hall.params` 200 and 101, since
  deployed flow firmware posts 101, and checks identity on 200 alone;
  `flow.reed.params` has no version that carries identity.

A pico does not always make the boot post. On a power cycle some picos
resume readings with no params post, a different set on each boot, so a
pico can run unchecked, on its own capture settings, until its next boot
(`experiments/2026-09-19-spruce-pico-params/`).

The web handlers run off the proactor thread. A handler answers the pico
and queues the accepted post to its own actor (`send_threadsafe`);
everything that sends a message happens in `process_message`.

The params words are in no vendored closure, so the gwsproto conformance
test does not see their twins; `sema validate` on a serialized instance is
their check.

## A sensor out of service

A house carries a required sensing node or channel it cannot serve as
present and disabled, in preference to a sim stand-in. Disabled means
required by the layout word, declared in the layout, currently
unavailable, and pending a field visit. The layout words carry
`DisabledNodeNames` (whole sensing actors) and `DisabledChannelNames`
(single channels), with axioms that every name resolves, that no
disabled node or channel is an actuator's (an actuator is wired or
absent; `Relay` and `ZeroTenOutputer` are the two actuator classes), that
a derived channel with a disabled input is itself disabled, and that no
input of the transactive-power channel is disabled. The layout's lists
are the one place a missing sensor is declared; no component word carries
an `Enabled` flag. The web server's `Serve` is a different idea, whether
the scada runs its HTTP server. The why and the plan behind each disabled
name are the service-record word.

The scada (`HydronicLayout.node_disabled` / `channel_disabled`):

- builds a disabled node's actor and leaves it idle: gwproactor builds
  every child unconditionally, so the actor exists, keeps its web routes
  and its place in the pico-cycler's roster, and neither reads, reports
  nor alerts;
- filters a disabled channel at its actor's channel-discovery step, before
  the liveness and warning state is built, so there is no read, no
  `ChannelFlatlined`, no quiet-channel or open-thermistor Warning and no
  i2c broken-input latch; a sim pico does not post to itself and a
  slow-turner flow module publishes no made-up zero flow;
- skips a disabled DerivedChannel in the derived generator and stops device
  actors posting its inputs;
- reports nothing for it: `unreported_channels` returns the disabled set
  and the UnknownChannels line leaves it out;
- names the disabled set once at start and once a day in a
  `disabled-roster` Warning glitch, so a person sees what the house is not
  measuring.

The channels exist and carry no readings, and consumers see an absent
value exactly as they do for any channel that has not reported. This is
how a house keeps the channel set its layout word asks for while one
sensor is down, and why one dead pico does not cost every healthy pico on
the rail a reboot each missing-report period. Pinned by
`tests/actors/test_pico_disabled.py`.

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

- **The component zoo table is behind the twins.** It lists types with no
  gwsproto twin today (`fibaro.smart.implant`, `resistive.heater`,
  `rest.poller`, the `gw108.gpio.*` names) and lacks `i2c.relay`,
  `i2c.dac.output`, `gpio.relay`, `gpio.sensor`, `scada.board`,
  `device.component` and `sim.sensor`; the "18 types" count goes with it.

- The Cac → `device.type.gt` rename (taxonomy + the DB-table bijection it
  implies for which families get their own table).
- The config-list revamp + `TelemetryName` → `gw1.unit` (scope, migration,
  the channel-identity / capture-policy split).
- Whether the per-family buckets collapse to a uniform list.
- Unifying the two sim expressions onto the device-boundary pattern the
  simulated-actors design selects.
