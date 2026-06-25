# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-scada` code repo**. The matching git commit (in
`gridworks-scada`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-06-23 — house0_sema_gen: heat-call + source axis + primary-flow emission (`1ad69983`)

**What:** Taught the sema-native gen to satisfy axioms 3 + 4. (1) Per-zone `heat-call` DerivedChannel
(Strategy `heat-call`) with a new `heat_call_source` config axis — `power` (whitewire-pwr,
`GreaterThanThreshold`) or `opto` (opto-input, `DigitalZeroIsActive`). The sim power meter emits the
per-zone `whitewire-pwr` source (node + DataChannel + ConfigList) only when power-sourced. (2)
`emit_primary_flow` wires the existing `primary_flow_source` axis: `Measured` emits a `primary-flow`
node + DataChannel (`DerivedSiegSum` lands with the sieg emitters).

**Why:** Phase-1 prerequisite — the gen must produce axiom-valid `gw.house0.layout` instances; the stub
now does (`GEN OK`, `sema validate OK`). The `opto` source branch is wired but its source emitter (a
gw108 opto sensor) is the next chunk; until then an opto config trips axiom 3's missing-source check.
(OPS-407.)

## 2026-06-23 — house0 heat-call axiom 3 (gwsproto) + source names to hydronic (`91db0a90`)

**What:** (1) Rewrote gwsproto `House0Layout.check_axiom_3` from `ZoneWhitewirePwrChannel` to
`ZoneHeatCallChannel`, mirroring the sema runtime: each zone needs a `zone{i}-{name}-heat-call`
DerivedChannel (Strategy `heat-call`) plus a per-zone source DataChannel (`whitewire-pwr` or
`opto-input`). (2) Moved the heat-call *source* channel names onto `HydronicSpaceheatZoneChannelNames`
(shared, known-optional, per-zone): `opto_input` and `whitewire_pwr`; removed `whitewire_pwr` from
`House0ZoneChannelNames` (no call-sites on the new class). (3) Updated `tests/config/gw.house0.layout.json`
to add the `zone1-main-heat-call` derived channel. The nolan/sim `opto_input` copies stay for now (5
old-`layout_gen` call-sites) — de-duped in the names sweep.

**Why:** require the semantic signal (heat-call) the control logic needs, not a specific sensor; its
source is a per-zone hardware choice (power ⇒ eGauge whitewire, opto ⇒ gw108). gw108 opto sensing is
cross-family (house0/nolan/sim going forward), so the source names belong on the shared hydronic zone,
revising the executor's earlier "families add their own raw-input names" split. Pairs with the sema
axiom-3 rewrite (sema changelog). (OPS-407.)

## 2026-06-23 — house0_sema_gen uses correct SpaceheatUnit (`a3f187eb`)

**What:** Fixed the sema-native house0 gen's stale unit references: channel-config `Unit` fields now use
`SpaceheatUnit` (`W`/`Fahrenheit`/`Celcius`/`VoltsRms`/`Gpm`/`Unitless`/`ThermostatStateEnum` — the values
the ConfigList serializes), while DerivedChannel `OutputUnit` keeps the gw1 `Unit` enum
(`WattHours`/`FahrenheitX100`). Removed the duplicate `Unit` import.

**Why:** a sema regen had renamed the gw1 unit members (`W`→`Watts`, `Fahrenheit`→`FahrenheitX100`),
which crashed the gen on `Unit.W` before it emitted anything; the channel configs need the old
`spaceheat.unit` values for now, so they bind to `SpaceheatUnit`. The gen now runs end-to-end and builds a
`House0Layout` — surfacing the next real gap (it does not emit per-zone `whitewire-pwr`, which the new
axiom 3 catches). (OPS-407.)

## 2026-06-23 — house0 layout axioms in gwsproto + odu-only fixture (`1ab30c6f`)

**What:** Ported the `gw.house0.layout` sema axioms to the gwsproto `House0Layout` type as
`check_axiom_1..4` (GlobalIdUniqueness, EssentialNodesExistence, ZoneWhitewirePwrChannel,
PrimaryFlowSourceChannelAgreement) and added `check_axiom_2` (Cardinality) to `House0Hydronic`
(axiom 1, SiegLoopControlImpliesPlumbed, was already present) — each mirrors the sema runtime logic
with PascalCase field accessors. Added `tests/config/gw.house0.layout.json`: a minimal sema-convention
`gw.house0.layout` instance — one zone (`main`), outdoor unit only (no `hp-idu`), no sieg loop,
`PrimaryFlowSource=Measured`.

**Why:** the EDD bar for house0 — gwsproto producers now enforce the same layout contract the sema
runtime does, and the fixture is the valid base we mutate to author each axiom's counterexample. Built
via the `dc_to_sema(House0Dc.load(...))` path (the in-flight `house0_sema_gen` is broken on a stale
`Unit.W`); the two "minor modifications" the bare stub needed to pass the existing axioms were a
`zone1-main-whitewire-pwr` channel (axiom 3) and a `primary-flow` DataChannel (axiom 4). Validates
`OK` against the sema runtime; all five axioms verified firing on mutated payloads. (OPS-407.)

## 2026-06-22 — pytest self-contained via pythonpath (`98aa12f5`)

**What:** Added `pythonpath = ["gw_spaceheat"]` to `[tool.pytest.ini_options]` in `pyproject.toml`.
Also settled the two `scada_gw108.py` `QUESTION FOR JESSICA` comments into plain statements (no value
change): the gw108's I²C peripherals share one bus (`/dev/i2c-1`), and the thermistor
`AdcReferenceVolts=3.3` is the divider pull-up supply.

**Why:** the test suite imports top-level `gw_spaceheat` modules (`show_layout`, `ltn_app`, …), so it
only collected when `gw_spaceheat` was on `sys.path` — previously supplied by the `gw` shell alias's
`PYTHONPATH`, which broke after the Coding→GridWorks checkout move. With this, `pytest` collects from the
repo root with no external `PYTHONPATH` (117 tests collected with `PYTHONPATH` unset). The gw108 comments
were the open hardware questions, now confirmed. (OPS-407.)

## 2026-06-22 — Batch 3 i2c: the gw1.scada.device.type.gt board (`e0325686`)

**What:** The capstone of the gwsproto→sema conformance sweep. Two new sub-types `I2cBus`
(`Name`/`BusNumber`) and `NativeGpioPin` (`Name`/`BcmPin`), and `ScadaDeviceTypeGt` rewritten to mirror
the sema `gw1.scada.device.type.gt/000` schema — composing `BusList`, `NativeGpioInputs`/`Outputs`,
`I2cRelays`, `CtAdc`, `ThermistorAdcs`, `Dacs`, `TelemetryNameList`, with the `BusMembership` axiom as a
`check_axiom_1` method (every I2cBus a config references must be a Name in BusList). The old nested
`BaseModel`s in `scada_device_type_gt.py` are retired. Local class name stays `ScadaDeviceTypeGt` while
the wire `TypeName` is `gw1.scada.device.type.gt`; the in-flight `Gw1ScadaDeviceTypeGt` name is renamed
back to `ScadaDeviceTypeGt` across `nolan_layout.py`, `relay.py`, `gw108_nolan_zones.py`, and the three
new names are exported from the package `__init__`. `scada_gw108.py` rebuilt against the new structure
(dict→list, `Register`→`RegisterIndex`, every config given `Name`/`I2cBus`, one `DefaultBus`).

**Why:** the board descriptor is the type the whole i2c family was built to compose; with it the sweep
covers the full hardware-layout vocabulary. The serialized gw108 is the schema's example, confirmed
against the sema runtime (`sema validate` → OK) and its `BusMembership` rejection. Two gw108 hardware
values had no prior field and are flagged in-code for Jessica (single-bus assumption;
`AdcReferenceVolts=3.3`). (OPS-407.)

## 2026-06-22 — Batch 2 i2c (`75da8146`)

**What:** Added the gwsproto i2c config family (Batch 2 of the gwsproto→sema conformance sweep):
new types `I2cRelayConfig`, `I2cAdcConfig`, `I2cDacConfig`, `I2cThermistorInterfaceConfig` + the
`I2cAdcType` (Ads1115/Ads1015) and `I2cDacType` (Mcp4728/Mcp4725) enums. Introduced a shared
`PascalCase` format in `property_format.py` (alongside `NonNegativeInt`) and applied it to the config
name/bus fields (`RelayName`, `I2cBus`, `Name`, `DacName`). Reworked the Batch 1 bus-op types so each
sema schema axiom is mirrored as a `@model_validator(mode="after")` `check_axiom_n` method — replacing
the `Literal[0,1]`/`Literal[1,2]` shortcuts — covering `BitValueRange` (write.bit), `NumBytesRange`
(read.reg/write.reg), `ValueFitsNumBytes` (write.reg), and `ErrorIffFailure` (result).

**Why:** the configs are the per-chip descriptors the board (Batch 3) composes; the `PascalCase` format
keeps device/bus names wire-conformant rather than free `str`; axioms-as-methods is the standing rule
(see `GridWorks_CLAUDE.md`) — value-range constraints belong in a numbered `check_axiom_n` that mirrors
the sema axiom, not buried in a `Literal`, so the gwsproto producer and the sema runtime enforce the
same contract. Each type's emitted payload was confirmed against the sema runtime (`sema validate`)
before its example was added schema-side. (OPS-407.)

## 2026-06-22 — alphabetizing the gwsproto inits (`7201e5a4`)

**What:** Alphabetized the import blocks and `__all__` lists of `gwsproto/named_types/__init__.py`
and `gwsproto/enums/__init__.py` (ruff `I` + `RUF022`). This was only safe after the prior commit's
fix to the three modules that imported siblings *via the package `__init__`* — alphabetical order had
reordered an importer ahead of its dependency, triggering a partially-initialized-module circular
import.

**Why:** import hygiene, and it enforces the rule that a `named_types` module must never import from
the package `gwsproto.named_types` (always from the specific sibling module). (OPS-407.)

## 2026-06-22 — batch 1 i2c sema words (`210ed585`)

**What:** Aligned the gwsproto i2c bus-op family to the sema schemas (Batch 1 of the
gwsproto→sema conformance sweep). New types `I2cBitAddress`, `I2cRegAddress`, `I2cReadReg`,
`I2cWriteReg` + the `I2cOperation` enum; `I2cReadBit`/`I2cWriteBit`/`I2cResult` rewritten from
their old flat shape to **compose** the address sub-types (`Address: I2cBitAddress`/`I2cRegAddress`)
— `i2c.result` now carries `Operation: I2cOperation` (was a `Literal`), a widened `Value`, and no
address echo. Added a non-coercive `NonNegativeInt` to `property_format` (the i2c types import it,
replacing inline `Annotated[StrictInt, Field(ge=0)]`). Exported all new types/enum. Also fixed three
modules that imported siblings via the package `__init__` (`slow_contract_heartbeat`,
`gw108_gpio_sensor_component_gt`, `snapshot_spaceheat`) to import from the specific module — a
package-self-import is a latent circular-import trap.

**Why:** sema is the source of truth and these hand-written gwsproto types must match it; each was
verified by building a sample and decoding it through the sema runtime (`sema validate`), and the
validated sample became the schema's example. The composed/address shape mirrors sema's
`$ref`-composition. (OPS-407.)

**What:** Three things. (1) Moved the shared component base out of `named_types/`
into `gwsproto/type_helpers/component_base.py` and fixed its long-standing
class-name typo `CommponentBase` → `ComponentBase`; re-added `ComponentGt` (the
generic concrete component, `TypeName` `component.gt`) as a flat named type
inheriting `ComponentBase`. Repointed every concrete `*ComponentGt`, `decoders.py`
(fallback instantiates `ComponentGt`), `data_classes/hardware_layout.py`, and
`data_classes/components/component.py` to `ComponentBase` from `type_helpers`;
re-exported `ComponentGt` from `named_types`. (2) Implemented the
Channel-Name-uniqueness axiom as `check_axiom_1` in **each** concrete component
(removed the no-op stub from `ComponentBase`); existing per-component axioms
renumbered up. (3) Deleted unused components — `fibaro_smart_implant` (dead IoT
device, no field instances) and `resistive_heater` (both the named-type and the
data-class wrapper). 29 files.

**Why:** sema types do not inherit from one another, so the base belongs in
`type_helpers`, not the `named_types` sema-word namespace, and each component
owns its own axioms — the gwsproto half of honoring the flat-sema law (paying
down the "gwsproto inheritance is a flaw, left for the proactor port" interim
note). The matching sema-side axioms land separately (sema `2823a2b`). (OPS-407.)

## 2026-06-17 — name shuffle (`2ca8f730`)

**What:** Second pass of the sema-native name cleanup begun in `beb964e8`.
Renamed the generated zone type `Gw1HvacZone` → `HvacZone` (module
`gw1_hvac_zone.py` → `hvac_zone.py`) and the unit enum `Unit` → `SpaceheatUnit`,
updating every import site in `gw_spaceheat/` (house0 sema-gen, the `layout_gen/`
generators, `house0_bijection.py`) and gwsproto (`house0_hydronic`,
`house0_layout`, `unit_quantity_projection`, `device_types`). Also stripped the
redundant "Values:/links" docstring blocks from ~25 generated enum modules and
alphabetized the `SpaceheatUnit` import in `enums/__init__.py`. 68 files,
net −210 lines.

**Why:** the generated sema-native symbols should read by their bare domain names,
and the enum docstrings duplicated the schema_url already on each class — a sema
type's docstring is the `Sema:` URL and nothing else. Pure rename/cleanup; no
wire-format or schema change. (OPS-407.)

## 2026-06-16 — renaming (`beb964e8`)

**What:** Strip the `Gw1`/`Gw` prefixes from the generated sema-native names so
the generated symbols read by their bare domain names: `Gw1DeviceType` →
`DeviceType`, `GwQuantity` → `Quantity`, `GwHouse0Hydronic` → `House0Hydronic`,
and the module/class `gw1_scada_gw108` → `scada_gw108`. Mechanical rename swept
across the `layout_gen/` emitters, the actor drivers, `house0_sema_gen.py`,
`house0_bijection.py`, and the gwsproto data classes — no behavior change.

**Why:** The `Gw1`/`Gw` prefixes were legacy noise carried over from the old
naming; the sema-native convention names the type by its domain meaning alone.
Continuation of the house0_sema_gen naming-hygiene pass.

## 2026-06-16 — House0 names hold only House0-specific names (`63795377`)

**What:** Extended the sema-native gen with the fleet builders the sim stub never exercised, and got a
real production home (`oak.json`: 4 zones, 3 tanks, no sieg) to `sema_gen(config) == dc_to_sema(load)`
content+id-equal. New generic, config-driven emitters: eGauge power meter (`PwrChannelSpec` — modbus
register map + pump/boiler/whitewire about-nodes), ADS analog-temp (`AdsChannelSpec` — pipe temps; the
`GridworksTsnap1ScadaBoard` i2c map is an invariant constant), Reed flow meters (`FlowSpec`), real
`pico.tank.module` tanks vs the sim stub (`tank_kind` axis + `TankSpec`) with affine depth calibration
(depths 1&3 affine M·x+B, depth 2 identity). Surfaced bespoke-per-home knobs as config: web-server
`Port`, relay `I2cAddressList`, poller DisplayName uses the zone index (not device id), and three-way
zone-label casing. The diff harness (`house0_sema_gen_check.py`) gained an order-INSENSITIVE comparison
(`_canon` sorts each collection before `==`) — list position in a layout is historical load order, not
semantic, so the gen emits a canonical order and a fixture adopts it on migration.

**Why:** Task a of hardware-layout-pass-one — proving the gen reproduces a real fleet home (not just
the sim stub) end to end, with UUIDs preserved and on the new naming convention. Remaining fleet homes:
elm/fir (same no-sieg shape, different device maps), then beech/maple (the sieg loop).

**Names hygiene — `House0*` classes hold ONLY House0-specific names.** The name classes stay
flat/separate and do NOT compose from one another; the **consumer picks the appropriate class** per
name. Removed every name from `House0ChannelNames`/`House0NodeNames` that duplicates a
`core`/`hydronic_spaceheat` name: `House0ChannelNames` now carries only the 12 House0 krida relay-state
channels (dropped the power/pipe-temp/flow/010V/energy channels and `vdc-relay`), and `House0NodeNames`
only the krida relay nodes + House0 instrumentation (`hubitat`, `analog-temp`, `relay-multiplexer`,
`zero-ten-multiplexer`, the BTU nodes) — dropping the system actors, pumps, pipe temps, flows, 010V,
buffer, oat. `House0ZoneChannelNames` likewise keeps only `whitewire_pwr`/`stat_temp`. The generator
now references `CoreNodeNames`/`HydronicSpaceheatNodeNames` (and the channel equivalents) directly for
the shared names, and the `House0*` classes only for House0-specific ones. Verified: both gen configs
(house0 + oak) stay `GEN OK`, all fleet layouts still load, maple round-trip green. (OPS-407.)

## 2026-06-16 — house0_sema_gen relay bank + uuid-preserving new-convention naming (`cad3962c`)

**What:** Built the relay bank in the sema-native gen (`house0_sema_gen.py`): `emit_relays` emits the
i2c Krida `I2cMultichannelDtRelayComponentGt` (14 `relay.actor.config` in exact layout order, krida idx
12 before 11), the relay-multiplexer node, the 14 relay nodes (with their handles/display names), and
the 14 relay-state DataChannels — driven by compact `_RELAY_KINDS` / `_NONZONE_RELAYS` spec tables plus
a per-zone failsafe/ops pair. The gen now emits the **new `names/` convention**, whose one systematic
House0 change is that relay-state channels drop the trailing relay-index (`vdc-relay1` → `vdc-relay`).
UUIDs are preserved across that rename: the gen indexes a reference layout's channel ids by their
*stripped* (new) name (`strip_relay_idx`), so an emitted new name inherits the frozen fixture's existing
UUID — the `LayoutIDMap` "maintain uuids from an existing layout" feature extended across the rename.
The diff harness (`house0_sema_gen_check.py`) applies the same rename to its comparison target. Also
fixed two `names/` defects surfaced here: `House0ChannelNames.store_flow` (was a copy-paste of
`primary-flow`) and `HydronicSpaceheatNodeNames.vdc_relay` (`vdc_relay` → `vdc-relay`, a malformed
SpaceheatName); and added the zone relay-state channel names to `House0ZoneChannelNames`.

**Why:** Task a of hardware-layout-pass-one, executing the decision to adopt the new naming conventions
now while keeping existing production-layout UUIDs. The relay bank is the largest builder; landing it
proves the new-convention + uuid-preservation approach end to end (verified: the gen's `vdc-relay`
carries the fixture's `vdc-relay1` UUID, zero content diff on relay nodes/channels). Remaining gen
builders (web-server, hubitat+poller, sim tanks, dfr, the 8 derived channels) follow. (OPS-407.)

## 2026-06-16 — prep for house0_sema_gen (`7697db49`)

**What:** Added the sema-native House0 layout generator and its diff harness in `gw_spaceheat/`.
`house0_sema_gen.py` builds a `gw.house0.layout` Sema object directly from a config
(`sema_gen(config, reference)`), pulling stable IDs by name from a reference layout via `LayoutIDMap`
(the same mechanism the old dc gen uses); this skeleton emits GNodes, the Hydronic block, the 14
invariant system-actor nodes, and the power-meter device-type/component/nodes/`*-pwr` channels.
`house0_sema_gen_check.py` diffs `sema_gen(config) == dc_to_sema(load(reference))` and prints the
field-level gap. Also fixed two bugs in the `gwsproto/names/` hierarchy surfaced by running the gen:
`House0NodeNames.__init__` called `House0ZoneNodeNames(zone, idx+1)` (arity mismatch — the class takes
only `idx`); and `HydronicSpaceheatNodeNames` carried malformed SpaceheatNames `hp_idu`/`primary_flow`
(underscores → hyphens, which fail the SpaceheatName format).

**Why:** Task a of hardware-layout-pass-one — a sema-native gen is the **fixture factory** for the
layout-axiom counterexample tests (only it can emit a layout that *violates* a `gw.house0.layout`
axiom, since the dc loader's Python guards raise before the sema codec runs) and the parallel the
`sema_gen == dc_to_sema(load(...))` equivalence is checked against. The diff harness is the EDD driver:
generate → observe the gap → close it. The names fixes are the underscore-format bugs the design
predicted this pass would surface. (OPS-407.)

## 2026-06-16 — mark required-node layout properties as design-brainstorm, not used yet (`a82e714c`)

**What:** Added "DESIGN BRAINSTORM — NOT USED YET" docstrings to `House0Layout.required_topology_nodes`
and `required_system_actor_nodes` (`data_classes/house_0_layout.py`), noting they are enforced
nowhere, are written in legacy `H0N` terms, and are already known too strict (maple runs `hp_odu`-only,
no `hp_idu`, yet is still House0).

**Why:** these two properties are a first-guess spec of what the five production homes need to run, to
be reworked into real per-layout sema axioms in hardware-layout-pass-2 (after `H0N` is dropped). The
docstrings stop a reader mistaking them for live validation. (OPS-407.)

## 2026-06-15 — bring back thoughts on scada device type gt (`d4608cfd`)

**What:** Added two gwsproto files sketching the gw108 SCADA-board device type. `named_types/
scada_device_type_gt.py` defines `ScadaDeviceTypeGt` (`gw1.scada.device.type.gt/001`, a transitional
type extending `ComponentAttributeClassGt`) plus its config sub-models — `I2cBitAddress`
(I2cAddress/Register/BitIndex), `I2cRelayConfig` (address + `SupportedWiringConfigs` + Notes),
`I2cAdcConfig`, `I2cThermistorInterfaceConfig`, `I2cDacConfig`, `NativeGpioConfig` (name→BCM-pin
in/out maps). `data_classes/device_types/gw1_scada_gw108.py` is the concrete `gw108_device_type`
instance: native GPIO (zone whitewires + shutdown in; tstat-power/Vdc/watchdog/power-off out), the
full I2C relay bank on expanders `0x20`/`0x21` (zone failsafe + scada relays, buffer/store heating
elements, heat-pump enable, boiler-buffer valve, misc), the CT ADC (`0x48`, ADS1115), one thermistor
ADC (`0x49`, 5.65 kΩ pullup), and the zones DAC (`0x60`, MCP4728).

**Why:** captures how the gw108 hardware board is actually wired and how the Nolan relay structure
should be fleshed out — the device-type record the hardware-layout pass-one work points at as the
lens for the Nolan layout refactor. Brought back as reference for that build-out; not yet wired into
a layout. (OPS-407.)

## 2026-06-15 — patch layout roundtrip script (`e48393be`)

**What:** Flipped the focused layout round-trip to **scada-originated**: removed the scada returner
(`gw_spaceheat/layout_roundtrip_return.py`) and added a driver (`gw_spaceheat/layout_roundtrip.py`)
that loads a real dc layout JSON (default `tests/config/maple.json`), converts it to the
`gw.house0.layout` sema type via the house0 bijection, ships it to gwta (shelling out to the
terminalasset venv), decodes the return through gwsproto, and compares — with a channel-level diff
reporter (the thing that surfaced the `SecondsX10` degradation).

**Why:** the round-trip should start from a real deployed-style layout (a dc), not a gwta-built
minimal instance — so it proves scada↔gwta wire agreement end-to-end from `maple.json`. Pairs with the
gwta returner (gridworks-terminalasset `a83b8614`).

## 2026-06-15 — cleaning up gwsproto enums (`096c5f21`)

**What:** Brought the gwsproto enums and `derived.channel.gt` into faithful agreement with the gwta
snapshot. Enums: bumped `gw1.unit` 000→001 (added `Seconds`, `SecondsX10`, `Milliseconds`), `gw1.quantity`
000→001 (added `Time`), `gw1.actor.class` 011→012 (added `SimSensorActor`, `SimRelayActor`); ported the
missing `i2c.adc.channel` (v000); added the matching `UNIT_TO_QUANTITY` rows (the three time units →
`Time`). Normalized every gwsproto enum so its docstring `Sema:` URL version equals its `enum_version()`
classmethod (added the method where only `version()` or a bare docstring existed; left genuinely
version-less enums alone). Ported `gw1.unit.quantity.projection` as `UnitQuantityProjection`
(`named_types/unit_quantity_projection.py`). `derived.channel.gt`: made `OutputUnit`/`OutputQuantity`/
`InputChannelNames` required and replaced the bespoke validators with `check_axiom_1..4` copied verbatim
from gwta (PascalCase); the sieg `hp-keep-seconds-x-10` channel now carries `OutputUnit=SecondsX10`
(→ `OutputQuantity=Time`); gens set `OutputQuantity=UnitQuantityProjection.project(OutputUnit)` at each
site. Also finished the `AslEnum`→`SemaEnum` rename (three straggler refs in `actors/relay.py`,
`actors/i2c_relay_multiplexer.py`, the `gw_str_enum.py` docstring) and regenerated the sieg-loop
fixtures (`maple`, `beech`).

**Why:** the earlier `derived.channel.gt` "Optional OutputUnit" was a symptom of gwsproto's `gw1.unit`
lagging gwta — it lacked `SecondsX10`, so the one trigger-only channel had no unit to name. Syncing the
enums makes the unit expressible and lets the type match gwta's contract exactly (required fields + the
unit↔quantity projection axiom), closing the last ⚠️ in the hardware-layout pass-one type checklist.
Scada suite green (114 passed, 3 skipped; the lone `test_async_power_update` failure is a pre-existing
timing flake, passes in isolation). (OPS-407.)

## 2026-06-15 — rip out all cac references; update components (`9e258d01`)

**What:** Deleted the legacy ComponentAttributeClass ("cac") machinery from `gwsproto` and switched
the loader + gens to the device-type model. Gone: `CacDecoder` (→ `DeviceTypeDecoder`, regex
`.*\.device\.type\.gt`), the `*.cac.gt` types (`ads111x.based.cac.gt`, `electric.meter.cac.gt`,
`resistive.heater.cac.gt`), `ComponentAttributeClassGt` / `component.attribute.class.gt`, the
`cacs.py` union, and every `ComponentAttributeClassId`. The loader's `cacs`/`load_cacs`/`.cac` became
`device_types`/`load_device_types`/`.device_type`; the four `*Cacs` layout buckets collapsed to the
single gwta `DeviceTypes` list; `layout_db.add_cacs` → `add_device_types`. Record-bearing families
(ads111x, electric.meter, gw1.scada) emit real `*.device.type.gt` records; record-less families read
identity off `component.gt.DeviceType`. Also: `derived.channel.gt` bumped v001→v002 (`OutputQuantity`,
auto-derived from `OutputUnit`); `web.server.component.gt` pinned to v002; the divergent
`scada_device_type_gt.py` (v001) dropped for the new `gw1_scada_device_type_gt.py` (v000);
`house0_bijection` `DeviceTypes` is now a trivial passthrough. Incidental: `vdc_relay_name` reads
`self.hydronic.Strategy` (fixes a latent break fixture-regen exposed).

**Why:** every gwsproto component type already carried the open `DeviceType` string and the loader
already keyed "cacs" by `DeviceType` — the cac layer was dead weight pretending to be a contract that
no gwta type matches. Removing it makes `dc_to_sema` trivial (the round-trip blocker) and aligns
gwsproto to the gwta `gw.house0.layout` wire shape. Scada suite green (114 passed, 3 skipped),
dc→sema→dc bijection lossless, all six gens load. One open divergence: gwta `derived.channel.gt` v002
makes `OutputUnit`/`OutputQuantity` required, gwsproto keeps them Optional for trigger-only channels —
flagged in the hardware-layout pass-one checklist for a decision. (OPS-407.)

## 2026-06-15 — Support maple sieg-loop config: sum + integrate-relay-motion derived-channel strategies (`fe4e1794`)

**What:** Two changes so the `use_sieg_loop=True` (config-3) gen path works (maple is the first
layout to exercise it): (1) `hardware_layout.validate_derived_channels` gained `case "sum"`
(validate ≥2 `InputChannelNames` + `EmissionMethod.OnTrigger` — maple's derived `primary-flow =
sieg-send + sieg-flow`) and `case "integrate-relay-motion"` (the SiegLoop-produced
`hp-keep-seconds-x-10` channel; derived-generator skips it). (2) Fixed that channel's definition in
`layout_db.add_stub_scadas` — `Strategy` was `"Integrate relay motion"` (invalid `SpaceheatName`,
spaces) and `EmissionMethod` was missing; now `"integrate-relay-motion"` + `OnTrigger`.

**Why:** the sieg-loop gen path was never validated before (no layout ran `use_sieg_loop=True`); both
were latent breaks the maple config-3 build-out surfaced. With them, maple's dc gen loads, the full
actor stack instantiates, and `dc_to_sema` produces a clean sema layout (`PrimaryFlowSource=
DerivedSiegSum`, the `sum` `primary-flow` channel). Scada suite green (114). (hardware-layout
pass-one, OPS-407.)

## 2026-06-15 — add hydronic to layout in layout_gen (`d31b2918`)

**What:** `LayoutDb.dict()` now folds the flat hydronic keys the per-device builders write
(`ZoneList`/`CriticalZoneList`/`ZoneKwhPerDegFList`/`TotalStoreTanks`/`FlowManifoldVariant`/
`UseSiegLoop`/`Strategy`) into the typed nested `"Hydronic"` block (`gw.house0.hydronic` shape:
`Zones` of `gw1.hvac.zone`, `SiegLoopPlumbed`, `PrimaryFlowSource`, …) via a new `_nest_hydronic`.
The builders keep reading the flat `misc` keys during generation (e.g. `add_house0_relays` reads
`misc["ZoneList"]`), so only the *output* shape changed. Added `StubConfig.primary_flow_source`
(default `"Measured"`).

**Why:** the generated/deployed layout now carries the same typed `Hydronic` structure the dc + sema
use, so `gen → dc.load → dc_to_sema → gwta` runs on the typed shape end-to-end. Verified: gen produces
a nested layout, the dc reads `self.hydronic`, `dc_to_sema` has no gaps; committed flat fixtures still
load via the dc dual-read; scada suite green (114). (hardware-layout pass-one, OPS-407.)

## 2026-06-15 — House0 dataclass: carry typed gw.house0.hydronic; bijection writes nested Hydronic; add sieg_send name (`1efa487c`)

**What:** `House0Layout` (data class) now builds and carries `self.hydronic: GwHouse0Hydronic`
(`_build_hydronic`): it reads the nested `"Hydronic"` block if present, else builds the typed
hydronic from the legacy flat top-level keys (`ZoneList`/`FlowManifoldVariant`/… — transitional,
dual-read). The flat accessors (`self.zone_list`, `self.critical_zone_list`,
`self.zone_kwh_per_deg_f_list`, `self.total_store_tanks`, `self.use_sieg_loop`,
`self.flow_manifold_variant`) are now **derived from `self.hydronic`** so the actor sites are
untouched (a later sweep moves those references onto `self.hydronic.*`). `load_args` reads the sieg
topology from the typed `Hydronic` too. The dc→sema map (`house0_bijection.dc_to_sema`) now just uses
`dc.hydronic`, and `sema_to_layout_dict` writes the nested `"Hydronic"` block (not flat keys), so
`dc → sema → dc` is lossless again (it broke when `House0Layout.Hydronic` became typed). Also fixed a
`sieg_send` typo (`HNN.seig_send` → `HNN.sieg_send`) in `hydronic_spaceheat/channel_names.py`.

**Why:** the dc structure now matches the sema layout (the hydronic type lives on the dataclass), so
the dc→sema bridge — the validation reference for the forthcoming parallel sema gen — is clean and
the bijection round-trip holds. `dc → sema → dc` lossless, scada ↔ gwta round-trip green, scada suite
green (114). (hardware-layout pass-one, OPS-407.)

## 2026-06-15 — gwsproto: port gw1.hvac.zone + gw.house0.hydronic + primary-flow-source enum; type House0Layout.Hydronic (`964f32b8`)

**What:** Hand-ported the three new sema words into gwsproto to match the gwta snapshot:
`enums/gw_house0_primary_flow_source.py` (`GwHouse0PrimaryFlowSource`: `Measured` | `DerivedSiegSum`,
an `AslEnum`), `named_types/gw1_hvac_zone.py` (`Gw1HvacZone`: `Name`/`Critical`/`KwhPerDegF`), and
`named_types/gw_house0_hydronic.py` (`GwHouse0Hydronic`: `Zones`/`TotalStoreTanks`/`UseSiegLoop`/
`SiegLoopPlumbed`/`PrimaryFlowSource`/`Strategy` + axiom `UseSiegLoop ⟹ SiegLoopPlumbed`). Changed
`House0Layout.Hydronic` from `Optional[dict]` to `Optional[GwHouse0Hydronic]`. Exports added.

**Why:** the gwsproto wire type now mirrors the gwta snapshot's typed `gw.house0.layout` (the
hand-port step of the sema→gwta→gwsproto loop) instead of passing Hydronic through as a freeform
dict. Full typed Hydronic decodes + re-encodes PascalCase, the axiom fires, the house0 + simple.sim
round-trips stay green, scada suite green (114). Nolan's Hydronic stays freeform in both gwta and
gwsproto (unchanged) — it adopts `gw1.hvac.zone` when its hydronic is promoted. (hardware-layout
pass-one, OPS-407.)

## 2026-06-15 — derived_generator: add the `sum` derived-channel strategy (`9fb6d584`)

**What:** Added `handle_sum` to `DerivedGenerator` (registered as strategy `"sum"`, with an
init-time check that the inputs share one unit). It emits `dc.Name = Σ InputChannelNames` — reading
the fresh input payload plus the cached latest of the other inputs (`self.data.latest_channel_values`)
and waiting, emitting nothing, until every input has been seen. Generic (no per-house names).

**Why:** the active path needs a `sum` strategy so a Siegenthaler-loop house can derive
`primary-flow = sieg-send + sieg-flow` (replacing the removed `hack_maple_primary_flow`). This is the
strategy half; the per-house *wiring* (declaring the derived channel in the gen) is separate and
currently blocked on a domain question (no house's gen is in the derived-sum config yet — see the
design). `test_derived` green; scada suite green (`test_power_meter::test_async_power_update` is a
pre-existing async-timing flake, unrelated). (hardware-layout pass-one, OPS-407.)

## 2026-06-15 — Serialize layout poller by_alias (PascalCase) in bijection + round-trip adapters (`4c0d497b`)

**What:** Added `by_alias=True` to the layout `model_dump(...)` calls in `gw_spaceheat/house0_bijection.py`
(the dc→sema bijection adapter) and `gw_spaceheat/layout_roundtrip_return.py` (the scada round-trip
return). The Hubitat poller types (`HubitatPollerGt` / `maker.api.attribute.gt`) use snake_case
python fields with `alias_generator=snake_to_camel`, so a plain `model_dump` emitted snake_case keys
(`hubitat_component_id`, `attribute_name`, …); `by_alias=True` emits the PascalCase wire names. GNode
types are PascalCase-native (no alias) so the GNode round-trip stays identical.

**Why:** the parked "bijection adapter serializes the poller by_alias" gap — snake_case poller keys
are non-PascalCase and were what fed the bad `gw.house0.layout` sema example (since corrected). The
deployed-layout writer (`LayoutDb.dict()`) already uses `by_alias=True`, so deployed fixtures +
tlayouts outputs were already PascalCase (no regen needed); this aligns the bijection/round-trip
adapters. Bijection harness green (GNode round-trip identical, poller now PascalCase); scada suite
green (114 passed); house0 + simple.sim round-trips green. (hardware-layout pass-one, OPS-407.)

**What (calibration v001):** Aligned gwsproto with the sema v001 calibration:
`LinearOneDimensionalCalibration`, `TankTempCalibration`, `TankTempCalibrationMap` → v001 with
`B`/`Depth*B` as **integer in the OutputUnit (FahrenheitX100)** domain. Fixed
`derived_generator.handle_affine` to compute `temp_x100 = int(M·(x_f·100) + B)` (apply B in
FahrenheitX100) — byte-identical to dev's working `int((M·x_f + B_f)·100)` with `B = B_f·100`.
Regenerated all 7 fixtures; the five real homes' calibrations are George's exact values sourced from
**dev/main × 100** (fixing the jm/spruce hand-shift, e.g. beech tank3 depth1 −481 → −108).

**What (retire stored map):** The layout no longer stores a `TankTempCalibrationMap` — each tank
depth's calibration lives in its (`identity`/`affine`) derived channel, the single source of truth.
Dropped the required key + loading + cross-check in `house_0_layout.py` (replaced
`validate_tank_temp_calibration_consistency` with a per-depth well-formed-derived-channel check);
`layout_db` stops writing `misc["TankTempCalibrationMap"]` (tmap stays a generation-time input);
`scada.py` stops passing `TMap` into `LayoutLite` (the Optional field now defaults None — a later
`layout.lite` bump can remove it). Removed the dead `process_synced_readings` / `_depth_calibration`
/ `hack_maple_primary_flow` cluster (the orphaned `self.tmap` path — `process_synced_readings` was
never dispatched; the active path is `handle_input_reading → _dispatch_derived_input → handle_affine`).

**Why:** the prior state mis-calibrated (B hand-shifted to FahrenheitX100 ints but `handle_affine`
applied it as °F); v001 makes value + code consistent, and the derived channels become the lone
calibration home. **Carried caveat:** removing `hack_maple_primary_flow` leaves maple's `primary-flow`
(= `sieg-send + sieg-flow`) **uncomputed** — see the design TODO (the `sum` strategy). Scada suite
green (114); gen scripts in the tlayouts repo.

## 2026-06-15 — WIP: add pico.btu.meter to House0Layout Components union (`fbebebc1`)

**What:** Added `PicoBtuMeterComponentGt` to the gwsproto `House0Layout` Components union (beech/
maple carry btu meters). WIP slice of the house0-layout build-up.

## 2026-06-15 — Add real-home runtime fixtures (beech/oak/maple/elm/fir) (`640a0d33`)

**What:** Added `tests/config/{beech,oak,maple,elm,fir}.json` — the five real House0 homes regenerated
from the (whipped-into-shape) tlayouts `gen_*.py` against the current scada layout_gen. Each loads as
`House0Layout` (beech 83 nodes/76 ch, oak 85/82, maple 78/73, elm 86/83, fir 87/84; 14 derived each)
and carries valid `g.node.gt` GNodes (promoted from the legacy flat shape, key-derived
BaseClass/GNodeClass + PositionPointId). Suite green (114).

**Why:** real per-home layouts as runtime test fixtures, replacing reliance on only the synthetic
nolan/house0 fixtures. The generators live in the tlayouts repo; this commit is just the generated
fixtures consumed by the scada tests.

## 2026-06-15 — Promote layout GNodes to g.node.gt; House0 dc↔sema bijection harness (`69ab5564`)

**What:** Promoted the layout's GNode representation to `g.node.gt/004`. `layout_db.py` emission and
both fixtures (`house0`/`nolan-layout.json`) now carry `g.node.gt`-shaped GNode entries —
`BaseClass` + `GNodeClass` aligned (axiom 1), `GNodeStatus → Status`, `PositionPointId` for the
non-Logical LTN/TA (axiom 2), Scada as `BaseClass: Logical`, and legacy `AtomicTNode →
LeafTransactiveNode`. The `g_node_alias`/`_id` accessors read `Alias`/`GNodeId` and were untouched.
Added `gw_spaceheat/house0_bijection.py` — the `dc → sema → dc` EDD harness.

**Why:** the bijection is the EDD proof that `gw.house0.layout` encodes every part of the
production House0 data-class layout. It showed all categories encoded except GNodes (loose legacy
dicts); promoting them to `g.node.gt` closes it — the harness now reports all 7 categories encode
and the GNode round-trip is identical. Scada suite green (114).

## 2026-06-15 — House0Layout + SimpleSimLayout layout types; layout round-trip return (`d1f5b0e6`)

**What:** Hand-ported the three layout types into gwsproto to match the Sema snapshot (Sema is the
source of truth). `House0Layout` (`gw.house0.layout`) carries the full shape mirroring the sema type
— optional `GNodes`/`ShNodes`/`DataChannels`/`DerivedChannels`/`Components` (House0 oneOf union) /
`DeviceTypes` (`ComponentAttributeClassGt` stand-in, like the Nolan scaffold) / `Hydronic`, with
only TypeName+Version required. `SimpleSimLayout` (`gw1.simple.sim.layout`) is the minimal stub. The
existing Nolan scaffold class was renamed `GwNolanLayout` → `NolanLayout` (file → `nolan_layout.py`)
for the agreed short local names; `House0Layout` + `SimpleSimLayout` registered in
`named_types/__init__`. Added `gw_spaceheat/layout_roundtrip_return.py` — the scada side of the
bidirectional layout round-trip (decodes + re-encodes a sent layout through gwsproto).

**Why:** Completes the sema→snapshot→gwsproto loop for the layout baselines; the round-trip
(`gridworks-terminalasset/layout_roundtrip.py` ↔ this return script) is green for house0 +
simple.sim. Scada suite green (114).

## 2026-06-14 — layout_gen: rebuild simulated tanks (new device-type model); green the suite (`955869b7`)

**What:** Greened the scada suite after the cac→DeviceType migration. (1) Rebuilt
`layout_gen/simulated_tanks.py` in the new device-type model — the deleted file used the gone
`MakeModel.GRIDWORKS__SIMMULTITEMP` / `ComponentAttributeClassId` / `make_cac_id` /
`CACS_BY_MAKE_MODEL` APIs; the rewrite registers a `gw1.device.type` record
(`GridworksSimSensor`) and emits `SimPicoTankModuleComponentGt(DeviceType=…)`, mirroring the
already-migrated `tank3.py`. (2) Re-wired `add_simulated_tanks` + the per-tank loop back into
both `fixture_layouts.py` builders, so the `*-depth{i}-device` channels the
`add_house0_derived_channels` tank-depth derived channels depend on exist again (buffer + tank1,
matching `TotalStoreTanks=1`). (3) Regenerated `tests/config/{nolan,house0}-layout.json` to the
DeviceType shape via `genlayout mktest`. (4) Fixed `show_layout.py`'s `print_component_dicts` to
join cacs by `DeviceType` (was `ComponentAttributeClassId`). (5) Fixed the `tests/named_types/*`
sample dicts — `ComponentAttributeClassId` → `DeviceType`, and bumped the stale `Version`
literals to the single current runtime version (`spaceheat.node.gt` 301→302, i2c.thermistor
001→002, i2c.multichannel 004→005, pico.tank 011→012, pico.flow 000→001).

**Why:** the in-suite `layout_gen`-green for both real layouts is the sub-gate of the
hardware-layout pass-one EDD bar (the real verification is the gwta round-trip). Suite now
114 passed / 3 skipped. The sim tank module's purpose is to exercise the `api_tank_module.py`
actor in unit tests. OPS-407.

## 2026-06-15 — gwsproto: add g.node.gt + its enums; GwNolanLayout scaffold (`a0210a00`)

**What:** Hand-ported from the gwta sema snapshot runtime: `GNodeGt` (`g.node.gt/004`, with all
5 axioms — ClassConsistency / PhysicalGNodeLocations / AliasTransitionConsistency /
GNodeClassNamespacing / AliasSuffixSemantics) and its two enums `BaseGNodeClass`
(`base.g.node.class`) + `GNodeStatus` (`g.node.status`), in gwsproto idiom (AslEnum / BaseModel /
property_format, PascalCase fields). Registered in the enum + named_type `__init__`. Also added a
`GwNolanLayout` scaffold (`gw.nolan.layout`, full structure, axioms as a commented TODO block;
`GNodes` now typed `List[GNodeGt]`). And `ads111x.based.component.gt`: the `OpenVoltageByAds`
Near5 field-validator became `check_axiom_1` (OpenVoltageByAdsRange [4.5, 5.5]) mirroring the new
sema axiom — the Near5 property format is retired.

**Why:** the layout types' `GNodes` field needs `g.node.gt`, which had no gwsproto class. Verified
end-to-end: gwsproto `GNodeGt` validates the snapshot's `g.node.gt` sample (axioms pass) → re-emits
→ `gwta.sema` decodes it back. Imports + collection clean (117 tests). Next session: the
`gw.house0.layout` + `gw1.simple.sim.layout` sema types, then copy all 3 layout runtimes into
gwsproto. OPS-407.

## 2026-06-14 — gwsproto: align all 27 types to the sema snapshot (`62cf522d`)

**What:** Brought gwsproto into full version + shape parity with the terminal-asset sema
snapshot (the rule: a gwsproto type's `Version` equals its sema word's version). (1) Bumped 10
lagging `Version` literals the cac→DeviceType migration left behind — `spaceheat.node.gt`
301→302; electric.meter / gw108.* / i2c.thermistor.reader 001→002; i2c.multichannel 004→005;
pico.tank 011→012; pico.btu / pico.flow / sim.pico.tank →001 (sim.pico also `SimulatesVersion`
011→012). Shapes already matched — version-only. (2) Created `SimSensorComponentGt` +
`SimRelayComponentGt` (were missing). (3) Gave the Hubitat nested sub-types
(`HubitatGt`, `HubitatPollerGt`, `MakerAPIAttributeGt`) `TypeName`/`Version` so they are proper
sema objects. All five exported from `named_types/__init__`.

**Why:** so scada can emit every snapshot type and gridworks-terminalasset's `gwta.sema` codec
decodes it. Verified end-to-end: each type built in gwsproto → serialized → decoded through
`gwta.sema` = **27/27**. Imports + collection clean (117 tests). The remaining suite reds are
the pre-existing old-shape layout fixtures (separate gate). OPS-407.

## 2026-06-14 — gwsproto: Hubitat components declare Version 000 (`609e098f`)

**What:** `HubitatComponentGt` and `HubitatPollerComponentGt` now declare
`Version: Literal["000"] = "000"` instead of inheriting `ComponentGt`'s `"002"`
(dfr/ads component types already had this override).

**Why:** A round-trip experiment (generate from gwsproto → publish to the dev
rabbit broker → capture → decode through the sema runtime) caught the bug: the
sema words `hubitat.component.gt` / `hubitat.poller.component.gt` are version
`000`, so the inherited `002` made the sema decoder reject the messages
("Unsupported version 002"). With the override both components decode clean
(2/2). EDD paying off — the contract mismatch was invisible to in-process tests
that don't cross the sema boundary.

## 2026-06-14 — gwsproto: remove MakeModel; relay AsyncCaptureDelta; names/simple_sim (`b23b07af`)

**What:** Completed the `make_model` removal at the gwsproto type level: `AdsChannelConfig`
and `multi.py`'s TSnap config moved `ThermistorMakeModel: MakeModel` →
`ThermistorDeviceType: str`; `btu.py`/`flow.py` moved `FlowMeterType: MakeModel` → `str`
(`Gw1DeviceType.SaierFlowSensor` / `.EkmFlowMeter`); the `MakeModel` enum was deleted and
unexported, one test dict key renamed. Also: added `AsyncCaptureDelta=1` to the 14 house0
relay configs in `relay.py` (they set `AsyncCapture=True` but RelayActorConfig v003's Axiom 1
now requires the delta — the generator had drifted from the committed fixture). Added a new
`names/simple_sim/` package (`opto_input` + `gw_temp`, mirroring nolan).

**Why:** `make_model` is retired across the hardware-layout vocabulary — device identity is the
`gw1.device.type` `DeviceType` now (sema side merged in PR #27). Doing the gwsproto type
migration cleanly first makes the eventual sema-generated upgrade graceful. The relay fix
unblocks house0 layout generation; `names/simple_sim/` seeds the third layout family. Imports
green, 117 tests collect. The umbrella `tlayouts/gen_*.py` hand-scripts still import
`MakeModel` and will break until folded into the new builders (expected — they are being
retired). OPS-407.

**What:** Docstrings only (no functional change) on `HubitatGt` and `HubitatComponentGt`:
record that the MakerAPI URL helpers (`url_config` / `maker_api_url_config` / `refresh_url` …)
are computed in app code, are NOT part of the `hubitat.gt` / `hubitat.component.gt` sema
contract, and will NOT be generated when these types are regenerated from sema in the proactor
port — they must keep living in app code.

**Why:** The matching sema words were just authored (sema `b7d2cae`); the URL machinery turned
out to be derived helpers, not serialized state. The note keeps the next agent (and the proactor
port) from assuming a sema-generated dataclass will carry these methods. Also flags that this
vocabulary serves the five legacy House0 homes with no forward expansion.

## 2026-06-14 — Hardware-layout pass one: cac_id → DeviceType migration (WIP `b0f03292`, `b358a676`)

**What:** The scada side of the cac→DeviceType migration, landed as two WIP commits (to be
squashed). `b0f03292`: `ComponentGt` drops `ComponentAttributeClassId` and carries
`DeviceType: str` (v002); `ComponentAttributeClassGt` becomes the device-type-record base keyed
by `DeviceType` (its `CACS_BY_MAKE_MODEL` Axiom-1 + the UUID gone); `hardware_layout` resolution
joins by `DeviceType` with the specialized record now optional; `layout_db` + the 12 `layout_gen`
generators restructured; new `Gw1DeviceType` enum (app-code only — the gwsproto sema types keep
an open `DeviceType: str`). `b358a676` ("remove cac_id"): the ~9 actor/driver dispatches moved
`cac.MakeModel → DeviceType`; the generators re-swept onto `Gw1DeviceType.X`; the `MakeModel`
field removed from the record base; `show_layout` fixed; `pico_flow`/`pico_btu` `FlowMeterType`
retyped to `str`; and `cacs_by_make_model.py` + the transitional `device_type_by_make_model.py`
deleted.

**Why:** Retire UUID device identity (`cac_id`) and make/model-as-CAC across the scada hardware
layout in favour of a readable `gw1.device.type` `DeviceType`. A device is now fully described by
its `DeviceType` plus its own fields; the `CACS_BY_MAKE_MODEL` bijection evaporates, the silent
type-alignment guard it provided moves to a layout axiom, and `make_model` as a phrase leaves
scada app code. Matches the sema contract in `2d55705` / `0cd2175`. Test fixtures are not yet
regenerated — regenerating them + greening the suite is the next step.

## 2026-06-13 — Rip out UNKNOWN device handling + the sim-multi-temp tank gen (`fc5f4d14`)

**What:** Deleted `unknown_power_meter_driver.py`, `unknown_multipurpose_sensor_driver.py`,
and `layout_gen/simulated_tanks.py`. `power_meter.py` / `multipurpose_sensor.py` no longer
fall back to an Unknown driver — an unrecognized device (or missing i2c/adafruit libs) now
raises `NotImplementedError`. `fixture_layouts.py` no longer adds simulated tanks to the
house0/nolan fixtures; dropped the obsolete (already-skipped) `test_tank_device_capture_period`.

**Why:** OPS-407 (hardware-layout-pass-one). The scada should loudly refuse unknown hardware
rather than run silently against it. The sim multi-temp tank (`GRIDWORKS__SIMMULTITEMP` /
`SimPicoTankModuleComponentGt`) is superseded by the all-purpose `GridworksSimSensor`
(configured from its Component `ConfigList`), so the old sim-tank layout-gen goes — matching
the `gw1.device.type` enum dropping `UnknownDeviceType` + `GridworksSimMultiTemp`. Fixtures
are temporarily tankless until `GridworksSimSensor` is wired (later in OPS-407). `pytest`
green (114 passed).

## 2026-06-13 — docstring warning about aging stuff (`6989180f`)

**What:** Added a warning docstring to `gwsproto/named_types/scada_device_type_gt.py`
(`ScadaDeviceTypeGt`, `gw1.scada.device.type.gt`).

**Why:** The simulated-test-environment design resolved (Jessica, 2026-06-13) that
the generic device-type is `gw1.device.type.gt` (UUID-primary identity +
`MakeModel: string` descriptor), distinct from this **board-specific** type
(NativeGpio / I2cRelays / CtAdc / ThermistorAdcs / Dacs). The docstring marks that
boundary at the type so the two are never conflated — conflation would re-couple the
generic, version-stable, cross-company identity to SCADA-board hardware specifics. It
also flags that this type is gwsproto-only (not in sema — `gw.nolan.layout` dropped
its ref, sema `6f73174`/`af2bf49`) and that its `ComponentAttributeClassGt`
inheritance is the proactor-port flatten flaw, not a pattern to mirror.

## 2026-06-11 — Green the test suite: House0 AsyncCaptureDelta + local test dotenv wiring (`b3cf2c4b`)

**What:** Two coupled fixes landed together so `pytest` passes both
locally and in CI on `jm/spruce-unlimbo`:

1. **AsyncCaptureDelta restored to House0 layout.** `dab55d20` bumped
   `RelayActorConfig` to `003`, which *enforces* Axiom 1 (if
   `AsyncCapture` is true, `AsyncCaptureDelta` must exist — and the
   check is `not AsyncCaptureDelta`, so both absent and `null` fail),
   but only `nolan-layout.json` got the values. Added
   `AsyncCaptureDelta: 1` to the 14 relay configs in
   `tests/config/house0-layout.json` that lacked the key (relays are
   binary state, so a delta of 1 captures every change, matching
   nolan's relays). This is the bug behind CI's two `value_error`
   failures on `relay18`. `tests/config/layout-lite.json` carries the
   same `null` deltas but is loaded through the lite path, which does
   not exercise the axiom in any test — left untouched on purpose, since
   the goal was a green suite, not a speculative edit.

2. **Local test dotenv actually loads now.** `tests/conftest.py` declared
   `TEST_DOTENV_PATH` / `TEST_DOTENV_PATH_VAR` but never wired them, so
   `gwproactor_test` fell back to its own default name and loaded nothing.
   The LTN broker (`scada_mqtt = MQTTClient()`, `tls.use_tls` defaults
   True) then tried TLS against the plain local mosquitto and hung —
   every scada↔LTN link test timed out after 10 s. conftest now sets
   `GWPROACTOR_TEST_DOTENV_PATH` so the repo's local config loads, and
   `tests/.env-gw-spaceheat-test` is committed (copied from
   `tests/config/.env-local`, TLS off) and removed from `.gitignore` —
   the test rig should travel with the repo, not be hand-created per
   checkout. CI still overwrites it from `.env-ci` (TLS on, with certs),
   so CI keeps exercising the TLS path.

**Why:** the branch's tests were red both locally (link timeouts) and in
CI (the axiom failures). The merge `bb4f6294` was an early suspect but
was a red herring — the regression is the config-version bump that
enforced the axiom without backfilling House0, plus a long-standing dead
dotenv wiring that only bites a fresh checkout with no local rig.

## 2026-06-11 — Sim-time bridge: scada-side sim.timestep listener (OFI) (`aa802567`, PR #571)

**What:** On branch `jm/sim-time-bridge` (off `jm/spruce-unlimbo`): a
minimal listener that subscribes over MQTT to the time coordinator's
`sim.timestep` broadcasts, parses the JSON directly (deliberately
bypassing the gwsproto codec — OFI: interim, dies in the uv/AllyLink
rebuild), tracks latest sim time, and triggers the link keepalive per
the bridge plan (1-minute timesteps feed ping/ack; existing scada/LTN
stay wall-clock).

**Why:** the sim-time spoke of the simulated-test-environment design
(OPS-40, hub + spoke Accepted · Pass 1 2026-06-11) — the simplest
scada-side hook for the bridge, per the decision to keep scada sim-time
machinery minimal until the rebuild.

## 2026-06-11 — Merge branch 'dev' into jm/spruce-unlimbo (`bb4f6294`)

**What:** Merge commit bringing the branch up to current dev (docs
additions, standby/ltn/sieg_loop updates). One conflict,
`tests/config/nolan-layout.json` (both-added): resolved keeping the
branch's version-bumped copy — RelayActorConfig `003` /
I2cThermistorChannelConfig `001` — over dev's stale `002`/`000`; only
those four Version lines differed.

**Why:** keep the spruce-unlimbo working branch current with dev per
its own design ("merge dev forward regularly"), and as the base for
the upcoming sim-time bridge work, which branches off
`jm/spruce-unlimbo`. The branch's bumped config versions are the ones
its post-glean code requires (the poison-message lesson: stale-version
payloads against post-bump code).

## 2026-06-10 — Bump nolan-layout config versions to match RelayActorConfig 003 / I2cThermistorChannelConfig 001 (`77d882ac`)

**What:** In `tests/config/nolan-layout.json`: the
`gw108.vdc.relay.component.gt` ConfigList entry 002→003
(RelayActorConfig) and the `i2c.thermistor.reader.component.gt`
component 000→001 + its two ConfigList entries 000→001
(I2cThermistorChannelConfig). Version strings only; the bumped types
added validators, no new required fields.

**Why:** The `2b603cc0` glean cherry-pick bumped these type versions and
updated `house0-layout.json`, but `nolan-layout.json` didn't exist on
`jm/spruce-new`, so the pick couldn't touch it — leaving every
nolan-layout load (and therefore `gws run` and the whole test suite,
which conftest points at this file) failing pydantic validation. Found
via `gws run --dry-run`; both scada and LTN dry-runs pass after the fix.

## 2026-06-10 — Bump channel config versions for RelayActorConfig and I2cThermistorChannelConfig (`dab55d20`, cherry-pick of `2b603cc0` onto `jm/spruce-unlimbo`)

**What:** Second of two cherry-picks gleaning `jm/spruce-new` onto
`jm/spruce-unlimbo` (the spruce-unlimbo working branch, cut from
`td/orig-pred-set`). Adds `ChannelConfigBase` type helper, bumps
RelayActorConfig / I2cThermistorChannelConfig (+ related channel-config
named types) versions, adds named-type tests, and adds the
`airtable_pat` setting + `.env-template` lines. Conflict resolved in
`.env-template` only (union of both sides; the pick's truncated
real-prefix Airtable PAT replaced with an empty placeholder).

**Why:** Branch-reconciliation step of the spruce-unlimbo design: these
two commits were the only content in `jm/spruce-new` not already in
`td/orig-pred-set` (which contains `jm/spruce` as an ancestor). After
this lands, `jm/spruce` and `jm/spruce-new` are fully gleaned and can be
deleted.

## 2026-06-10 — docstring for actors/scada.py (`a5451f43`, cherry-pick of `62bc7218`)

**What:** Replaces scada.py's one-line module docstring with one
explaining that Scada is the prime actor in a gwproactor app: child
actors load from the hardware layout + actor registry, so layout
`ActorClass` values must resolve through `gw_spaceheat/actors/__init__.py`
exports or the proactor cannot instantiate them.

**Why:** First of the two `jm/spruce-new` glean cherry-picks onto
`jm/spruce-unlimbo` (see entry above). The docstring captures the
layout→registry coupling that bit during spruce bring-up.

## 2026-06-10 — OFI comment (`8a0e1689`)

**What:** Add an OFI comment in `gw_spaceheat/actors/sieg_loop.py`
`moving_to_hp_off_valve_position` pointing at OPS-400
`sieg-semantic-harmonization`. No behavior change.

**Why:** Flags in-code that, after `e6ba4f51`, control state `HpOff` no longer
uniquely determines valve posture (it branches on static `settings.system_mode`
with no disambiguating telemetry), and that default-when-off is per-heat-pump
(Maple Mitsubishi vs Beech LG) and not yet parameterized — so the next reader
sees the seam and the tracking issue without spelunking the changelog.

## 2026-06-10 — Open sieg valve in Standby (`e6ba4f51`, PR #570)

**What:** In `gw_spaceheat/actors/sieg_loop.py`, the transition into
`SiegControlState.HpOff` no longer hard-codes `moving_to_full_keep` (loop
CLOSED). It now routes through a new `moving_to_hp_off_valve_position(event)`
that branches on `self.settings.system_mode`: `Standby` → `moving_to_full_send`
(valve OPEN); anything else → `moving_to_full_keep` (CLOSED — heating-season
behavior unchanged). Authored + merged by Thomas.

**Why:** The simple sieg code keeps the loop closed whenever the heat pump is
off — correct for the heating season, wrong for summer/Standby (especially when
the valve is otherwise not moving). Maple sat in Standby with the loop closed
post-incident; the first action is putting the loop in full send. SiegLoop
learns posture from the **static startup config** `settings.system_mode` (env
`SCADA_SYSTEM_MODE`), so the new posture takes effect on the restart that
switches a SCADA to Standby (which also rebuilds the LocalControl tree). Design
`sieg-summer-posture`, OPS-395. Known OFI (`sieg-semantic-harmonization`,
OPS-400): control state `HpOff` no longer uniquely determines valve posture and
telemetry can't disambiguate (valve-state `SingleMachineState` still TODO); and
default-when-off is per-heat-pump (Maple Mitsubishi vs Beech LG), not yet
parameterized.

## 2026-06-09 — ltn sends correct scada wrapped (`981f0939`)

**What:** Replace the five `Message(..., Dst="broadcast", ...)` publishes in
`gw_spaceheat/actors/ltn/ltn.py` with real proactor-peer addressing: `Bid` → the
MarketMaker (`Dst="mm"`); `FloNextHourPlans`, `Glitch`, and both
`FloParamsHouse0` sends → the scada (`Dst=self.scada.name`, i.e. `"s"`). Each
site carries a HACK comment to revert to a real `rjb` broadcast once the LTN is a
gwbase actor (it leaves the scada lexicon).

**Why:** `Dst="broadcast"` is a magic string the proactor turns into a wire
routing key with no valid GridWorks envelope, so a gwbase consumer
(JournalKeeper) drops it at parse — silent data loss (prod saw `broadcast.glitch`
/ `broadcast.flo-next-hour-plans`). Addressing a real peer makes a valid
`gw.<src>.to.<peer>.<type>` key that gwbase parses (tolerant short-form parse,
gridworks-base design `must-accept-current-ltn-messages`). `"mm"` is deliberately
the gwbase `RoutingClass.MarketMaker` token, so the key already matches the
new/future rabbit structure. Design `ltn-sends-gw-wrapped`, OPS-387; depends on
the gridworks-base parser change publishing.

## 2026-05-14 — Add back a much-pruned docs folder (`c05a7625`, merged `6734aa0f` / PR #562)

**What:** Restores a `docs/` folder to the scada repo with three focused,
hand-pruned documents — `docs/editor-setup.md` (109 lines),
`docs/provisioning.md` (257 lines), and `docs/tls.md` (123 lines). No code
changes; docs only. Authored 2026-05-07, merged to `dev` on 2026-05-14.

**Why:** The repo's earlier `docs/` had been removed; this brings back a
deliberately slimmed-down subset covering the three things a human setting
up scada actually needs — editor setup, device provisioning, and TLS — as
repo-standalone docs (a repo's own docs stand alone for a human and don't
reference the wiki). Curated-minimum rather than the full former tree.
