Status: Draft · Pass 0 · Updated 2026-06-14

# The hardware layout

What this is: how a house's hardware is described, loaded, and generated —
the layout object, its load pipeline, and the (hacky) generation tooling.
**Current state only.** The rework (Sema layout types with axioms, the
`names/` system, doing multiple house types right) is spruce-unlimbo
Chunk B (OPS-334) — tracked there, not speculated here. Components
themselves are `executor/components.md`.

**First pass.** This is a first pass written to help *work with* the
system, not a critiqued design. Future TODO: review it with a critical eye
for design, the way `scada-ltn-link-state.md` was. But the layout is **not
as hair-on-fire** as the link-state machinery — it works, and it's **a bit of
both**. Much of the apparent complexity is the cost of a *consistent*
**interlinked database**: nodes, components, device types, channels, and
derived channels all cross-reference each other by name/id, and the axioms are
the referential-integrity constraints (a captured channel's
`CapturedByNodeName` resolves to *and matches* the capturing node;
`AboutNodeName` resolves; `InputChannelNames` exist; a device type bijects
with its make/model). That interlinking is worth paying for. The rest is
incidental cruft (the hardcoded buckets, the copy-paste tlayouts, the
config-list zoo, the dangling strategy names — the OFI targets). So the
critical pass is: **sharpen and simplify wherever it doesn't lose important
information** — keep the relational integrity, trim the cruft. Lower priority
than the link-state machinery.

## What a layout is

A layout is the node→component→device-type→channel graph for one house,
plus house-level facts. `HardwareLayout` (`data_classes/hardware_layout.py`)
is the base; `House0Layout` (`data_classes/house_0_layout.py`) adds House0
fields: `ZoneList`, `CriticalZoneList`, `TotalStoreTanks` (1–6),
`ZoneKwhPerDegFList`, `TankTempCalibrationMap`, `FlowManifoldVariant`,
`UseSiegLoop`, and the three GNodes (`MyScadaGNode`,
`MyTerminalAssetGNode`, `MyLeafTransactiveNodeGNode`). On disk it's
`<house>.generated.json` (e.g. `oak.generated.json`).

## Layout encodes the plant; the scada protocols share + disambiguate

Every GridWorks layout is the same plant class — a **thermal-storage heat-pump system**
(a heat pump, thermal storage, distribution, zones). The specific layout **encodes that
plant's sense/control surface**: what can be sensed, what can be actuated, and how. The
scada code reads that surface through **functional protocols** that (a) **share** the
common control logic across layouts by speaking in *capabilities*, not hard-coded
per-house node names, and (b) **disambiguate smoothly** where plants differ — feature-detect
from the layout and enable / disable / adapt. Because the domain is fixed, the
feature-detection is never "is this a heat-pump plant?" (always yes) but "this plant's dist
pump is a 010V on *these* nodes / a relay / a sim stub." The domain is given; the wiring
varies.

Two consequences:

- **SCADA-universal scaffolding belongs in every layout** — the local-control dispatch nodes
  and state machine are the scada itself, not a plant difference, so every layout (including
  a sim one) provides them; hard-requiring them is fine.
- **Plant-specific sense/control must be read as capability.** `LocalControl` already shows
  the pattern (`_dist_pump_recovery_enabled()` / `_store_pump_recovery_enabled()` feature-detect
  the relay/010V nodes and degrade gracefully when absent), but still hard-reaches for
  House0-named channels/devices in places. Generalizing that coupling — capability, not House0
  name — is what lets one scada serve House0, Nolan, and a sim plant alike.

The forcing function for getting this right is keeping **three diverse layouts** working at
once (House0, Nolan, and a deliberately-simplest fake-physics sim layout — `gw1.simple.sim.layout`):
two real layouts can mask leaked House0 assumptions; a third, radically-simpler one that still
has to run breaks them.

## Load pipeline

`HardwareLayout.load()` ingests the JSON and builds the graph:
`load_cacs()` → `load_components()` (pairs each component with its Cac,
instantiates the runtime `Component` subclass) → `load_nodes()` (links
`ShNode.ComponentId` → component) → `load_data_channels()` →
`load_derived_channels()` → `resolve_links()`. Devices arrive in
**per-family buckets** — `Ads111xBased*`, `ElectricMeter*`,
`ResistiveHeater*`, `Other*`, each a `*Cacs` + `*Components` pair — and
the loader iterates a list of bucket names. The bucketing is **intentional,
not arbitrary** (Jessica, 2026-06-11): a family gets its own bucket exactly
when its device type carries information the code needs — i.e. a specialized
`*.cac.gt` (`ads111x.based`, `electric.meter`, `resistive.heater`).
Everything whose device type is the generic `component.attribute.class.gt`
lands in `Other*`. So the three buckets are the three specialized device
types; the only residual wart is that the loader's bucket list is hardcoded
rather than derived from which device types are specialized.

**Load-time validations that bite (House0Layout `__init__`):** tank count
1–6; `TankTempCalibrationMap` M/B must match the tanks' derived channels
(identity/affine strategy); the system model requires `usable-energy` and
`required-energy` derived channels by exact name. These run at construction
— a layout that violates them fails to load (this is the class of failure
behind this morning's `AsyncCaptureDelta` greening, one layer up).

## Generation — two layers, the lower one hacky

- **In-repo `layout_gen/`** is the programmatic builder. `LayoutDb`
  (`layout_db.py`) accumulates bucket-keyed lists; per-device generators
  (`relay.py`, `multi.py` TSnap, `simulated_tanks.py`, `derived_channels.py`,
  `flow.py`, `egauge.py`, `dfr.py`, `tank3.py`, `gw108_nolan_zones.py`) each
  append nodes/components/cacs/channels — **the caller passes the bucket
  name** (no type-based dispatch). `fixture_layouts.py` assembles the
  house0 and nolan *test* fixtures; `genlayout.py` is the `mktest` CLI.
  `simulated_tanks.py` already emits `SimPicoTankModuleComponentGt` — the
  seed the dashboard experiment builds on.
- **The `tlayouts` sibling** (`/Users/jessica/GridWorks/tlayouts/`) is the
  real-house generator: one `gen_<house>.py` per house (oak, beech, elm,
  fir, maple, orange, almond, spruce, beachrose), each calling the same
  `layout_gen` device builders with house-specific config (zones, tank
  calibrations, hardware UIDs). Its own README says "hacky and temporary."
  It **runs in the scada venv** (imports `gw_spaceheat`/`layout_gen`
  directly, no packaging). The hackiness is concrete: 9 near-identical
  copy-paste gen scripts with no shared base, and per-house divergence in
  code rather than data — e.g. `gen_spruce.py` drops `add_relays()`
  entirely, uses one tank + BTU meters, default (zero) tank calibrations.
  `oak` is the full House0 (20 relays via the i2c multiplexer, 4 Pico tank
  modules, power meter, HpBoss) — the layout the dashboard experiment uses.

## Names — `gwsproto/names/`

Node and channel names are layered: `core/` (system actors:
primary_scada, ltn, power meter), `hydronic_spaceheat/` (the shared
heating vocabulary — zones, tanks, flows, pipes), and per-house-type
`house0/` and `nolan/`. `H0N`/`H0CN` (house-0 node/channel names) expose
static names (relays, pumps, pipe temps, powers) plus zone-/tank-indexed
names populated at instantiation from `ZoneList`/`TotalStoreTanks`. Names
are **invariant across hardware substitution** — swapping a sensor changes
the *capturing node*, not the channel name (`dist-swt` stays `dist-swt`).
This layered names system is half of the "multiple house types, done
right" rework.

## The three layout families — the rework, encoded

This captures durable **design intent** (partially encoded today in code +
the `tlayouts` hand-scripts). It is the target of spruce-unlimbo Chunk B /
OPS-334, with the device-type spine in OPS-407. Some of it is intent ahead of
code (flagged inline); review before relying. The seed is `layout.lite`
(`named_types/layout_lite.py`, a Sema type with axioms).

Three diverse layouts are kept working at once — the forcing function that
breaks leaked House0 assumptions — and each becomes a **Sema layout type**:

- **`gw.house0.layout`** — the five-home fleet (beech, elm, oak, fir, maple).
  Hubitat thermostats + eGauge power meter + TSnap ADS thermistors + pico tank
  modules.
- **`gw.nolan.layout`** — the gw108 one-off (Spruce). The gw108 board does room
  temp + whitewire sensing.
- **`gw1.simple.sim.layout`** — the deliberately-simplest fake-physics sim plant.

The `gw`/`gw1` prefix is deliberate vocabulary namespacing (`gw1.actor.class`,
`gw1.unit`, `gw.nolan.layout` leave room for other orgs' own words).

### The zone invariant — temp, set, heat-call exist in every layout

Every zone in every layout MUST carry the three semantic channels from
`HydronicSpaceheatZoneChannelNames`: `zone{i}-{label}-temp`, `-set`,
`-heat-call`. These are what the shared scada control logic speaks. What
**differs** per layout is the raw inputs they are built from and how heat-call
is detected — read as capability, never hard-coded per house.

| derived (shared) | house0 raw | nolan raw | simple_sim raw |
|---|---|---|---|
| `-heat-call` | `-whitewire-pwr` (eGauge power; `heat-call` strategy, GreaterThanThreshold) | `-opto-input` (gw108 opto; DigitalZeroIsActive) | `-opto-input` (SimSensor; DigitalZeroIsActive — same as nolan) |
| `-temp` / gw-temp | Hubitat `-stat-temp` + TSnap `-gw-temp` | gw108 `-gw-temp` | SimSensor `-gw-temp` |
| `-set` | derived `simple-falling-edge-setpoint` over `[gw-temp, heat-call]` | same | same |

The setpoint derivation is the same everywhere; the **heat-call source** is the
real divergence. Setpoint was first read straight off the Hubitat, but that was
not trustworthy — the derived `simple-falling-edge-setpoint` from gw-temp +
heat-call is the path (`derived_generator.py`). The power→whitewire mechanism
already exists: it is the generic `heat-call` strategy with
`GreaterThanThreshold` interpretation applied to a `-whitewire-pwr` power
channel.

### Per-layout raw-input names (use the `names/` classes)

Each builder drives channel/node names through the `names/` classes — not
hand-typed literals (the `tlayouts` fragility below):

- **house0** → `House0ZoneChannelNames`: `whitewire_pwr` (`-whitewire-pwr`),
  `stat_temp` (`-stat-temp`).
- **nolan** → `NolanZoneChannelNames`: `opto_input` (`-opto-input`), `gw_temp`
  (`-gw-temp`).
- **simple_sim** → a NEW `names/simple_sim/` subfolder mirroring nolan:
  `opto_input` + `gw_temp` only. No floor temp, no `stat_temp`, no
  `whitewire_pwr`.

The **zone-name list is a required input** to each builder — it indexes every
zone channel and node.

### layout_gen refactor — three builders, shared tools

Split `layout_gen`'s house-type assembly into `house0_layout_gen`,
`nolan_layout_gen`, and `simple_sim_layout_gen`. Each:

- composes the **shared** device tools (`add_tank3`, the relay/derived-channel
  tools, `add_egauge` / `add_gw108_nolan_zones` / the sim equivalents),
- routes names through the `names/` classes,
- takes the zone list as input.

This retires the nine copy-paste `tlayouts/gen_<house>.py` scripts (divergence
in *code*, not data): the per-house difference becomes config + which builder.

### Tank sensing — pico TankModule3 for the real layouts

house0 and nolan both read tank temps via pico **TankModule3** (`add_tank3`),
which emits raw `*-depth{n}-device` channels; the calibrated `*-depth{n}` are
`affine`/`identity` derived channels (per-depth M/B from the calibration map).
house0 = buffer + 3 tanks; nolan = buffer + 1 tank. The (now deleted)
`simulated_tanks.py` was the sim equivalent. **Current gap:** neither test
fixture wires a tank generator, so the raw `*-device` channels the derived
tank-temp channels depend on don't exist and the layout fails
`validate_derived_channels` — wiring `add_tank3` into each builder is what
closes it.

### simple_sim specifics

The simplest plant that is still a thermal-storage heat-pump system: a single
**large** storage tank (360 gallons, 3 depth sensors), **no buffer tank**, and a
**fixed single-tank shape** (no tank-count variable). **Every** reading comes
from the **SimSensor** — room temp, whitewire, *and* the tank depth temps — so
`add_tank3` is **not** used here: the `3` in TankModule3 names the pico hardware
device type (the old `GRIDWORKS__TANKMODULE3` make/model), which the sim does not
have. The sim still uses the **same detection mechanisms as nolan**
(`opto-input` → heat-call digital; `gw-temp` → setpoint), just sourced from the
SimSensor. It maps to the `gw1.simple.sim.layout` sema word (authored in the
simulated-test-environment design); the scada-side builder is
`simple_sim_layout_gen`.

### Fragile whitewire/gw-temp in the five homes — rename, keep the id

The five production homes were wired by hand in `tlayouts`, so their zone raw
channels are uneven: whitewire follows `-whitewire-pwr`, but `gw-temp` is
inconsistent (beech: both zones; maple: zone1 only; elm/fir/oak: none) and the
`temp`/`set`/`heat-call` invariant is not uniformly produced. Moving to sema
generation, any home whose channel name diverges from the canonical `names/`
value gets its **channel name changed to the canonical one while keeping the
immutable channel id** — so historical data stays connected across the rename.
Flag and fix per home as part of the migration.

## Hacky/irregular bits (current)

- Per-family buckets are intentional (specialized device type ⇒ own bucket),
  but the loader's bucket list is hardcoded, not derived from which device
  types are specialized.
- **Most of `layout_gen/` is hacky and irregular exactly at the
  spruce-unlimbo pain points** — multi-house-type handling (house0 / nolan /
  gw108), caller-passed bucket names, per-device generators that diverge in
  *code* not data. That mess is precisely what Chunk B's rework (`names/` +
  Sema layout types) targets; it is the reason the layout pipeline blocks
  moving spruce out of limbo.
- `tlayouts`: copy-paste gen scripts, per-house divergence in code not data,
  runs only inside the scada venv.
- **The derived-channel strategy names dangle.** `identity`, `affine`,
  `system-model`, `heat-call`, `simple-falling-edge-setpoint` (and the old
  `linear-fit` / `layer-by-layer` they replaced) are used as strings with
  **no canonical semantics home** (Jessica, 2026-06-11) — nothing specs what
  each strategy computes. The rework also grew companion fields
  (`EmissionMethod`, `EmitPeriodS`) — surfaced while migrating the stale
  `oak` layout, where the strategy renames + new required fields are a slice
  of the layout-augments fold, not a version bump. And because the names have
  no sema home, the only record of *what word became which*
  (`linear-fit`→`affine`, `layer-by-layer`→`system-model`) is the public data
  stream and the repos — so migrating `oak` meant **inferring** the rename by
  diffing current vs stale layouts. That inference is costlier and less sure
  than if the strategy carried its own versioned sema definition; it's a
  concrete case of "I'll just use the sema for this" being the cheaper, surer
  path. (Surfaced by the migration experiment — the EDD habit paying off.)
  **OFI:** give the strategy names a sema home — a versioned `strategy` enum
  (or a small type) — so a rename is an authoritative lookup, not an
  inference.
- `SynthChannels` list still instantiated though `DerivedChannels` is the
  real mechanism (`layout_db.py`).
- Heat-call + setpoint derived channels are wired for nolan but not yet for
  house0/simple_sim — the divergence is the heat-call **source** (gw108 opto vs
  eGauge whitewire-power vs SimSensor), not whether the channels exist. Target:
  all three layouts carry `temp`/`set`/`heat-call` (see "The three layout
  families — the rework, encoded").
- Spruce is special-cased (no relays, one tank, BTU meters) — house0-shaped
  injection into it fails to load.
- **`CACS_BY_MAKE_MODEL` — the MakeModel↔CAC-id bijection.** `layout_gen` and
  `ComponentAttributeClassGt`'s validator enforce a hardcoded 1:1 map from each
  *known* `MakeModel` to a single canonical `ComponentAttributeClassId` (a ~35-entry
  dict in `gwsproto/named_types/component_attribute_class_gt.py`). A CAC with a known
  MakeModel MUST use that MakeModel's canonical id; only `UNKNOWNMAKE__UNKNOWNMODEL`
  may use an arbitrary id. So `MakeModel` effectively *is* the device-type identity
  and the id is redundant with it for known models. Messy because: the table is a
  hardcoded constant (not data), it bakes a deployment-registration policy into the
  runtime type, and adding a device type means editing two coordinated places (the
  `spaceheat.make.model` enum value **and** the bijection). **In sema this rule is
  deliberately NOT an axiom** — the id↔MakeModel canonical mapping is GridWorks
  deployment policy, not a cross-system contract, so `component.attribute.class.gt`
  is structural-only (the shared-vocabulary sweep, 2026-06-12; sema changelog
  `6f73174`). **Resolution (Jessica, 2026-06-13) — the bijection and the UUID id are both
  removed.** The device type is identified by a **`gw1.device.type` enum** value
  (PascalCase, the existing `pascal.case` format) — a device *category*, not a
  make+model (several eGauge models lump under one value by design). ALL `cac_id` /
  `ComponentAttributeClassId` UUID identity is **dropped**, scada and sema alike;
  there is **no generic `component.attribute.class.gt` / `gw1.device.type.gt`** record.
  A component carries its `DeviceType` (a `pascal.case` field, kept open so component
  types stay version-stable); the **hardware-layout type enforces** `DeviceType ∈
  gw1.device.type`. Device types that carry real category-level data open a
  **specialized `<family>.device.type.gt`** (e.g. `gw1.scada.device.type.gt` for the
  gw108 board, `egauge.device.type.gt` for a modbus port); a **layout axiom** requires
  the matching specialized record present whenever a component references such a type
  (the component does not self-signal it). This drops `CACS_BY_MAKE_MODEL`, the
  UUID↔MakeModel mapping, and the projection idea entirely — the UUID-valued
  `gw1.device.type.id` enum was abandoned because sema string-enum values must be
  Python identifiers (`GwStrEnum`: value == member name), so UUIDs can't be enum members
  or projection targets. **Phasing:** a high-volume `gridworks-scada` migration removes
  every `cac_id` and restructures `layout_gen` around `DeviceType`; tracked as its own
  Ops issue (**OPS-407**, subsumes the earlier `replace-cacs-by-make-model` idea).

## Opportunities for improvement (OFIs)

- **`ChannelConfig` needs a rethink and overhaul (Jessica, 2026-06-11).** It is
  the thing at the center of the config-list mess: a zoo of per-component
  config types (`ChannelConfig`, `ElectricMeterChannelConfig`,
  `AdsChannelConfig`, `I2cThermistorChannelConfig`, `RelayActorConfig`,
  `DfrConfig`), `TelemetryName` overloading unit *and* meaning, and channel
  *identity* tangled with capture *policy* (`AsyncCaptureDelta`,
  `CapturePeriodS`, `PollPeriodMs`) in one object. The cost is not only machine
  (fragmentation, the snapshot-cadence liveness coupling) — it is human: "what
  is a channel config" takes seven drills of inference instead of one click at
  a sema type. The overhaul: a single sema-typed `channel.config` shape, with
  `TelemetryName → gw1.unit`, and identity separated from capture policy.
  Detail in `components.md` ("The config list — current shape, and a critique").
- **Strategy-name semantics need a sema home** (also noted in the hacky-bits
  above) — a versioned `strategy` enum/type so a rename is a lookup, not an
  inference.
