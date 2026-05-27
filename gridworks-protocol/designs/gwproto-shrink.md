# Design: shrink gwproto to proactor surface

Status: Draft · Pass 0 · Updated 2026-05-26

> A concrete keep/migrate/delete plan for the boundary-types surface in
> `gridworks-protocol` (`gwproto`), based on a full import audit of
> `gridworks-proactor` and `gridworks-scada` against `gwproto`'s current
> contents and `gwsproto` (the SCADA-side companion package). Goal:
> shrink `gwproto` to just what `gridworks-proactor` actually needs,
> after `scada` flips its imports to `gwsproto`.

## TL;DR

- **gwproto is ~90% redundant with gwsproto today.** 43 of 53
  named_types and 26 of 34 enums in `gwproto` ALSO EXIST in `gwsproto`
  on `dev`. They were ported; the import sites in `scada` were just
  never updated.
- **Proactor's real gwproto surface is small** — ~25 distinct symbols,
  dominated by transport plumbing (`Message`, `Header`, `MQTTCodec`,
  `MQTTTopic`, `gwproto.messages.*`) plus `HardwareLayout`/`ShNode` and
  the web-server/REST-poller helper types.
- **The cleanup is a 3-step move:** (1) MIGRATE scada imports from
  `gwproto.*` to `gwsproto.*` for the 43+26 duplicated names;
  (2) DELETE those names from `gwproto`; (3) decide PORT-or-KEEP for
  the residue (5 named_types + 8 enums that scada uses but `gwsproto`
  doesn't have).
- Two items are deletable today with zero scada/proactor changes:
  `data_classes/mixin` (truly dead) and the `MessageDiscriminator`
  TypeVar (declared, never used). A third — `pydantic_named_types` —
  is used internally by `decoders.py` so should not be removed, but
  it has zero external callers and should be demoted off the public
  surface. The aggregators `named_types/cacs` and `named_types/components`
  are *only* used by `default_decoders.py`, which is itself scada-only —
  they delete in step 4 of the migration, not step 1.

## Method

- Branch state (verified 2026-05-26): `gridworks-protocol` on `dev`
  (+1 unpushed local `Remove deprecated CodeGenerationTools`);
  `gridworks-proactor` on `dev` (+2 unpushed local); `gridworks-scada`
  on `dev` (fast-forwarded from `origin`).
- Imports surveyed: `grep -rh "from gwproto\|^import gwproto"` across
  `gridworks-proactor/{src,tests}` (~84 import sites) and
  `gridworks-scada/{gw_spaceheat,tests}` (203 distinct import lines
  across 153 files).
- `gwsproto` type surface taken as the union of `dev` + `jm/spruce`.
  `jm/spruce` adds new types and bumps versions but does not subtract;
  every gwproto-exclusive candidate listed below was verified absent
  on BOTH branches.

## The keep core (proactor's actual surface)

Everything `gridworks-proactor` imports from `gwproto`. Uploader and
ingester are subsets of this set; timecoordinator has no live `gwproto`
import (only a commented-out one). Therefore proactor's surface IS the
minimum viable gwproto.

### Top-level (re-exports from `gwproto/__init__.py`)

`HardwareLayout`, `MQTTCodec`, `MQTTTopic`, `Message`, `ShNode`,
`as_enum`, `create_message_model`, `DecodedMQTTTopic`.

### Submodules

- `gwproto.message`: `Header`, `Message`, `ensure_arg`
- `gwproto.messages`: `Ack`, `AnyEvent`, `CommEvent`, `EventBase`,
  `EventT`, `Ping`, `PingMessage`, `Problems`, `ProblemEvent`,
  `ShutdownEvent`
- `gwproto.decoders`: required to provide `MQTTCodec`/
  `create_message_model` re-exports (keep the file, drop unused
  exports — see DELETE below)
- `gwproto.errors`: `SchemaError`
- `gwproto.topic`: `MQTTTopic`, `DecodedMQTTTopic` (top-level
  re-exports source from here)

### Data classes

- `gwproto.data_classes.hardware_layout` (`HardwareLayout`)
- `gwproto.data_classes.sh_node` (`ShNode`)
- `gwproto.data_classes.components.rest_poller_component`
  (`RESTPollerComponent`)

### Named types (only 2 used by proactor)

- `gwproto.named_types.spaceheat_node_gt` (`SpaceheatNodeGt`)
- `gwproto.named_types.web_server_gt` (`WebServerGt`,
  `DEFAULT_WEB_SERVER_NAME`)

### type_helpers

- `AioHttpClientTimeout`, `RESTPollerSettings`, `URLConfig`,
  `WebServerGt`

### Enums (only 1 used by proactor)

- `gwproto.enums.actor_class` (`ActorClass`)

## MIGRATE — scada flips imports from `gwproto` to `gwsproto`

These exist in `gwsproto` already; scada is the only blocker. The
migration is a mechanical rewrite of `from gwproto.X import Y` →
`from gwsproto.X import Y`.

### Named types (43 to migrate in scada)

`Ads111xBasedCacGt`, `Ads111xBasedComponentGt`, `AdsChannelConfig`,
`AnalogDispatch`, `ChannelConfig`, `ChannelReadings`,
`ComponentAttributeClassGt`, `ComponentGt`, `DataChannelGt`,
`DfrComponentGt`, `DfrConfig`, `EgaugeRegisterConfig`,
`ElectricMeterCacGt`, `ElectricMeterChannelConfig`,
`ElectricMeterComponentGt`, `FibaroSmartImplantComponentGt`,
`FsmAtomicReport`, `FsmFullReport`, `HubitatComponentGt`,
`HubitatGt`, `HubitatPollerComponentGt`, `HubitatPollerGt` (and
`MakerAPIAttributeGt`), `I2cMultichannelDtRelayComponentGt`,
`MachineStates`, `PicoBtuMeterComponentGt`,
`PicoFlowModuleComponentGt`, `PicoTankModuleComponentGt`,
`PowerWatts`, `RelayActorConfig`, `Report`, `ResistiveHeaterCacGt`,
`ResistiveHeaterComponentGt`, `RESTPollerComponentGt`,
`RESTPollerSettings` / `URLConfig` / `URLArgs` / `RequestArgs`
(from `rest_poller_gt`), `SendSnap`, `SingleReading`,
`SpaceheatNodeGt`, `SyncedReadings`, `SynthChannelGt`,
`TankModuleParams`, `TicklistHall`, `TicklistHallReport`,
`TicklistReed`, `TicklistReedReport`, `WebServerComponentGt`.

Notes:
- `SpaceheatNodeGt` is also in proactor's keep core — it stays in
  `gwproto` for proactor and gets re-imported from `gwsproto` in
  scada. The two will coexist until the proactor refactor.
- Where scada uses `from gwproto.data_classes.components.<x> import …`,
  the `gwsproto` equivalent is at the same relative path; verify
  shape per type before flipping.

### Enums (26 to migrate in scada)

`ActorClass`, `AquastatControl`, `ChangeAquastatControl`,
`ChangeHeatPumpControl`, `ChangeHeatcallSource`,
`ChangePrimaryPumpControl`, `ChangeRelayPin`, `ChangeRelayState`,
`ChangeStoreFlowRelay`, `FsmActionType`, `FsmReportType`,
`GpmFromHzMethod`, `HeatPumpControl`, `HeatcallSource`,
`HzCalcMethod`, `MakeModel`, `PrimaryPumpControl`,
`RelayClosedOrOpen`, `RelayEnergizationState`, `RelayEventBase`,
`RelayWiringConfig`, `StoreFlowRelay`, `TelemetryName`,
`TempCalcMethod`, `ThermistorDataMethod`, `Unit`.

## PORT-OR-KEEP — scada uses these but gwsproto doesn't have them

Each is a one-line decision per item: **port** (copy into gwsproto,
then treat as MIGRATE) or **keep** (leave in gwproto and accept that
scada keeps a gwproto import for it). Default recommendation: **port
to gwsproto, then delete from gwproto** — keeps the long-run
direction consistent (one Sema-governed home for scada's boundary
types).

### Named types (5 — all gwproto-exclusive on dev AND jm/spruce)

| Name | Notes |
| --- | --- |
| `Alert` (`alert.py`) | Status alerts. Default: port. |
| `HeartbeatB` (`heartbeat_b.py`) | Versioned heartbeat. Default: port. |
| `HubitatTankComponentGt` (`hubitat_tank_component_gt.py`) | Tank-variant of hubitat component. May be obsoleted by gwsproto's pico_tank_module path — verify before porting. |
| `HubitatTankSettingsGt` (`hubitat_tank_gt.py`) | Sub-type of above. Same caveat. |
| `KeyparamChangeLog` (`keyparam_change_log.py`) | Audit log for key parameter changes. Default: port. |

### Enums (8 — all gwproto-exclusive on dev AND jm/spruce)

`AdminEvent`, `AdminState`, `AlertPriority`, `ChangeValveState`,
`FsmName`, `KindOfParam`, `RelayPinSet`, `Strategy`.

Defaults: port `AdminEvent`/`AdminState`/`AlertPriority` (paired with
the `Alert` named_type). `Strategy` and `KindOfParam` likely
SCADA-internal — port. `FsmName` overlaps the gwsproto FSM family —
verify before porting. `ChangeValveState`/`RelayPinSet` slot beside
the existing `ChangeRelay*`/`RelayWiringConfig` family in gwsproto —
port.

## DELETE — provably unused now (zero scada or proactor work needed)

Verified by both external grep (proactor + scada) AND internal grep
(within gwproto itself, including transitive use by other gwproto
modules).

| Item | Verification |
| --- | --- |
| `gwproto.data_classes.mixin` (`StreamlinedSerializerMixin`) | 0 external references; 0 internal references inside gwproto besides its own class definition. |
| Top-level `MessageDiscriminator` (the `TypeVar` declared in `decoders.py:31`) | 0 external references; declared but unused inside `decoders.py` past line 31. Drop both the declaration and the re-export from `__init__.py`. |

### Adjacent: demote, don't delete

| Item | Action | Why |
| --- | --- | --- |
| Top-level `pydantic_named_types` | Drop from `gwproto/__init__.py` `__all__` + re-export, KEEP the function in `decoders.py`. | 0 external references, but used internally by `decoders.py` at lines 225 and 265 — load-bearing in the keep-core's decoder path. |

### NOT deletable today — defer to step 4

The following look unused from outside but are actually used
internally by a scada-only dependency cluster, so they delete *after*
scada migrates:

| Item | Why it can't go now |
| --- | --- |
| `gwproto.named_types.cacs` (aggregator) | Imported by `gwproto.default_decoders.py` (line 10) which scada calls via `default_cac_decoder`. |
| `gwproto.named_types.components` (aggregator) | Imported by `gwproto.default_decoders.py` (line 19) which scada calls via `default_component_decoder`. |
| `gwproto.default_decoders` (whole file) | Used by scada; not by proactor. |
| `gwproto.decoders.CacDecoder`, `ComponentDecoder` | Used by scada; not by proactor. Keep `decoders.py` for the proactor exports (`MQTTCodec`, `create_message_model`), but drop these classes. |

## Sequencing

The cleanup is naturally three commits across two repos, in order:

1. **gwproto: delete provably-unused + demote internal helper.**
   Delete `data_classes/mixin.py` and the `MessageDiscriminator`
   `TypeVar`; drop `pydantic_named_types` from the public surface
   (keep the function). Strictly local to gwproto. No scada change.
2. **gwsproto: port the residue.** Bring the 5 named_types + 8 enums
   in PORT-OR-KEEP over (those marked port). Local to scada repo.
3. **scada: flip imports.** Rewrite all `from gwproto.{enums,named_types,
   data_classes}.X import Y` to `from gwsproto.X import Y` for
   everything in MIGRATE plus the newly-ported names. Mechanical pass;
   the keep-core imports (`Message`, `Header`, `HardwareLayout`,
   etc.) stay on `gwproto`.
4. **gwproto: drop the migrated bulk + scada-only cluster.** Remove
   the 43 named_types + 26 enums + their `__all__` entries. Also
   delete the scada-only dependency cluster: `default_decoders.py`,
   the `named_types/cacs` and `named_types/components` aggregators,
   and `CacDecoder` / `ComponentDecoder` from `decoders.py` (keep
   `MQTTCodec` + `create_message_model` for proactor). Verify
   proactor + uploader + ingester still build.

Steps 2 and 3 may sensibly land on `jm/spruce` since that branch is
where new types currently get added; or on a dedicated
`jm/gwproto-shrink` branch off `dev`.

## Forward path

After this cleanup, gwproto is essentially: `Message`, `Header`,
`MQTTCodec`/`MQTTTopic`/`DecodedMQTTTopic`, the `messages.*`
event/ack family, `HardwareLayout`, `ShNode`, `SpaceheatNodeGt`,
the web-server + REST-poller plumbing, `ActorClass`, `SchemaError`,
`as_enum`, `create_message_model`. ~30 symbols, a single concern:
"what `gridworks-proactor` needs to wire its MQTT actors together."

When `gridworks-proactor` is refactored (see
[[../research/concerns/proactor-link-and-addressing]] — TBD; today
the issue is captured in
[[../../gridworks-scada/research/concerns/transport-and-links]]), the
question of whether this residual surface migrates into proactor
itself, into a renamed package, or stays in gwproto can be settled
then. For now, gwproto becomes a small, honest, proactor-scoped
package instead of a mixed-history boundary-types dumping ground.

## Open

- **`from gwproto.named_types import *`** sites in scada: confirmed
  benign because gwproto's `named_types/__init__.py` `__all__` is
  explicit; star-import only pulls listed names. The MIGRATE pass
  should replace each star-import with explicit named imports from
  gwsproto.
- **`gwproto.named_types.dfr_config`, `egauge_register_config`,
  several hubitat-related sub-files** export sub-types not in
  `named_types/__all__` (e.g. `MakerAPIAttributeGt`). They're
  imported by full path in scada; the migration list above includes
  the sub-type names but the per-file mapping should be verified
  during the mechanical pass.
- **gwsproto's `gw108_*` / `i2c_thermistor_reader_*` types on
  jm/spruce** do not have gwproto counterparts; they're new content,
  irrelevant to this cleanup but worth noting that the long-run
  gwsproto surface is growing while gwproto's is shrinking.
- **gwproto README still calls the package an "Application Shared
  Language" (ASL).** The ASL term has been replaced by Sema
  everywhere else (`wiki/glossary.md`). The README should be updated
  as part of this cleanup; track separately.
