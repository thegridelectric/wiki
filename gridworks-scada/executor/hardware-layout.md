Status: Draft · Pass 0 · Updated 2026-09-24

# The hardware layout

What this is: how a house's hardware is described, loaded, and generated —
the layout object, its load pipeline, and the (hacky) generation tooling.
**Current state only.** The rework (Sema layout types with axioms, the
`names/` system, doing multiple house types right) is spruce-unlimbo
Chunk B ([OPS-334](https://linear.app/gridworks/issue/OPS-334)) — tracked there, not speculated here. Components
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
plus house-level facts. On disk it is one authored sema artifact per home,
a layout word (`gw.house0.layout` or `gw.nolan.layout`) whose `Hydronic`
block (`gw.hydronic`) carries the plant facts: `Zones`, `ZoneCallCircuits`,
`TotalStoreTanks` (0–6), `PrimaryFlowSource`, `PrimaryPumpOwner`,
`RefrigerantCycle`, `HpCommandNodeName`; the GNodes ride in `GNodes`.
The control family is the layout word's own TypeName, not a field.

Two of those are heat-pump facts of the installed house, stated once on
the layout because code branches on them and never inferred from channel
presence or device records. `PrimaryPumpOwner` (`HeatPump` or `Scada`)
says who runs the primary pump; the House0 `PrimaryPumpActuators` axiom
makes the primary-pump relay pair and `primary-010v` exist exactly when
the scada owns it, and a home whose heat pump owns its pump carries none
of them. It is distinct from the relay state `primary.pump.control`,
which says which side has the pump at this moment. `RefrigerantCycle`
(`Single` or `Cascade`) exists for the optimizer: two-compressor cascades
show a markedly flatter COP curve across outdoor temperature. The
refrigerant boundary (monobloc or split) is not a layout fact; each
family word's node roster already says what parts a home has.

The device records (`hp.device.type.gt`, `hp.control.box.device.type.gt`)
are the nameplate, true of every unit of a model, and keep the three
primary-pump booleans (factory-installed, overridable, always-on); the
layout states the install decision. The `PrimaryPumpRecordAgreement`
axiom ties them one way only: under `Scada` ownership no record joined to
the heat-pump nodes may ship its pump inside the unit with no override.
`HeatPump` ownership implies nothing about the record, because a heat
pump can drive a field-supplied pump from its own terminals, as spruce's
Samsung does. What changes without rewiring lives in the paired
`gw.operational.params` word, whose `FamilyParams` block is the family's
own word (`gw.house0.family.params` / `gw.nolan.family.params`),
`UseSiegLoop` among it. The loader pairs a layout word with its
family-params word and refuses an ops word whose `ScadaAlias` is not the
layout's Scada GNode alias (`sema_to_dc.py`). The runtime
`HydronicLayout` (`data_classes/hydronic_layout.py`) is built from the two
(`sema_to_dc.load_layout`); whether the plant has a Siegenthaler loop is
read off the layout's SiegLoop-classed node, not a field.

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
0–6; each tank depth has a well-formed `identity`/`affine` calibrated derived
channel (see "In-field tank-temp calibration"; the legacy `TankTempCalibrationMap`
cross-check is retired with the map); the system model requires `usable-energy`
and `required-energy` derived channels by exact name. These run at construction
— a layout that violates them fails to load.

## Generation — the tlayouts gens

No layout is hand-kept. Every layout, sim fixture or real deployment, is
emitted by the `tlayouts` sibling from the layout family's sema word,
id-preserving against the prior output and decoded through the word's
axioms before it is written. The generators, their invariants and the
config specs are in [`../../tlayouts/executor/primary.md`](../../tlayouts/executor/primary.md);
what the scada relies on is below.

- **The scada boots only gen output.** `tests/config` fixtures and a box's
  layout and ops files are byte-identical to a driver's `output/<house>/`.
- **Zone temp truth** is `zone{i}-{zone}-gw-temp` (`CelsiusTimes100`, about
  the zone node, captured by `analog-temp`), the accurate ADS sensor; the
  Honeywell stays the setpoint / state read.
- **Sim pairs**: the scada suite's House0 fixtures are two little houses with
  their own GNode identities, one per sieg-flow pattern (`gw.house0.orange.*`
  measures primary, `gw.house0.willow.*` derives it); all `SimDeviceType`,
  booted in-process by the suite. The sim sensor actor feeds the derived
  generator whenever a DerivedChannel consumes one of its channels. The real
  beech and maple layouts are box artifacts, not scada fixtures.
- **The board's relays and 0-10 V outputs** arrive as per-relay and
  per-output components against the board record, the power-on levels in
  the ops word.

> **OFI — where is the authority for a hardware layout?** Today it is the
> gen's config plus the id map of the prior output. It deserves a dedicated
> session in light of "where meaning lives". Hard constraint: the
> **gridworks-data *analytics* database** MUST NOT become the de-facto home
> for layout changes we intend to make — layout authority is a deliberate
> choice, not a side effect of where analytics data happens to live.

## Names — `gwsproto/names/`

Node and channel names live in vocabulary packages: `core/` (system actors:
primary_scada, ltn, power meter), `hydronic_spaceheat/` (the shared heating
vocabulary — zones, tanks, flows, pipes; the `temp`/`set`/`heat-call` zone
channels), and per-layout `house0/`, `nolan/`, `simple_sim/`. Names are
**invariant across hardware substitution** — swapping a sensor changes the
*capturing node*, not the channel name (`dist-swt` stays `dist-swt`).

**These packages compose; they do NOT inherit.** `House0ZoneChannelNames`,
`NolanZoneChannelNames`, and `SimpleSimZoneChannelNames` do **not** subclass
`HydronicSpaceheatZoneChannelNames` — they *use* it (e.g. for the shared
`zone{i}-{label}` base) and add only their own raw-input names
(`whitewire_pwr`/`stat_temp` for house0; `opto_input`/`gw_temp` for nolan + sim).
A layout draws on **more than one** package: a `house0.layout` uses **both**
`hydronic_spaceheat` (the shared `temp`/`set`/`heat-call`, tanks, flows, pipes)
**and** `house0` (the whitewire-pwr / stat-temp raw inputs). Composition, not a
single inheritance chain.

**Required vs optional is the LAYOUT's call, not the names'.** The name packages
are pure vocabulary — they neither know nor declare what a given plant must have;
**some names are optional.** It is the **layout type** (`gw.house0.layout` /
`gw.nolan.layout` / `gw1.simple.sim.layout`) that declares, via its `required`
lists and axioms, which channels and ShNodes are mandatory for that plant and
which are optional. The same name can be required in one layout and optional in
another; the layout — not `names/` — is the authority. A required list
names what every layout of the family must serve, never what a house merely
tracks; nodes are not required unless code binds to them (the heat-pump
units are named outright because a required channel met by a
DerivedChannel has no about-node, and the component binding needs the
nodes whatever form the channels take).

The canonical example is **`-gw-temp`**:
- In **nolan** it is **required** — the gw108 thermistor reading is *the* zone
  room temperature, and the zone setpoint is derived from it
  (`simple-falling-edge-setpoint` over `[gw-temp, heat-call]`). It is a
  `NolanZoneChannelNames` member and a required part of the nolan zone vocabulary
  alongside the `temp`/`set`/`heat-call` invariant.
- In **house0** it is **optional** — room temp normally comes from the Hubitat
  thermostat, and only some homes also wire a TSnap `-gw-temp` (beech has it both
  zones, maple zone1 only, elm/fir/oak none). Same name, optional here.

**Three categories, three authorities.** Beyond what the operational code reasons
about, a layout always tolerates **arbitrary experimental / hand-made** nodes and
channels. So a name falls into one of three kinds, and the authority differs:

| Kind | What it means | Authority |
|---|---|---|
| **Required** | every layout of this type MUST carry it | the **layout type** — `gw.house0.layout` etc. via its `required` lists + axioms (the binding contract) |
| **Known-optional** | the code knows it, uses it if present, tolerates absence | **`gwsproto/names/`** — being *in* the names catalog is what makes a name "known-optional" rather than an extra; the use-it-if-present behavior then lives in the operational code (`optional_channels`) |
| **Experimental extra** | the code has never heard of it | nobody — named by no one, required by no one, tolerated by all |

The discriminator between a known-optional and an extra is simply **"is it in
`names/`?"** — `buffer-cold-pipe` (a `names/` member, absent on some homes for
plumbing reasons, used if present) is known-optional; a bench-wired
`random-temp-sensor` is an extra.

**No gen emits a `zone-state` channel.** The Hubitat
`thermostatOperatingState` reading has unstable values and no names class
carries it; a zone's heat call is its derived `heat-call` channel. The
deployed beech and maple layouts still carry one `-state` channel per zone,
and the web frontend's thermostat table
(`gridworks-web-frontend/src/real-time/RealTimeStatusThermostatTable.tsx:119`)
reads it by name and shows "idle" when it is absent, so a deployed house
takes a regenerated layout only once that table reads `heat-call`. The LTN
dashboard (`actors/ltn/dashboard/channels/containers.py:141`) shows its
missing string.

**A layout answers its own store tanks.** `store_tanks(node_names)`
(`names/hydronic_spaceheat/helpers.py`) reads the tank reader nodes
(`tank1` to `tank6`) a layout carries and returns the per-tank
`TankChannelNames`. `HydronicLayout.store_tanks` / `has_store_tanks`, and the
same pair on `LayoutLiteDc`, are the lookup every reader goes through. A
layout with no tanks answers none, and the hottest and coldest store readers
answer None.

**A zone's `heat-call` channel is source-neutral.** Consumers read each
zone's derived `heat-call`; whether it came from an opto input or from
whitewire power is the derived generator's business.

**One rule for whether a device actor posts to the derived generator:**
`HydronicLayout.feeds_derived(channel_names)`, true when a DerivedChannel
consumes one of them. Pinning a node name or the sieg-loop flag in the
actor is what it replaces.

**Names classes are bare assignments, with no `Literal` annotation.** The
annotation narrows nothing a signature demands and doubles every rename.

**Store-tank element names are per tank; buffer and store-loop names are
not.** A store tank's elements are `tank{i}-top-elt` and `tank{i}-bottom-elt`
with their `-pwr` and `-relay` names (`TankNodeNames` / `TankChannelNames`).
The buffer's elements stay flat hydronic-tier names (`buffer-top-elt`).
`store-flow`, `store-btu`, `store-pump-relay` and the store pipes name the
store circuit, not a tank, and keep `store-*`.

**`backup` and `scada-blind` are House0 names.** They are House0 local
control states; a shared tier takes them only once the Nolan state machine
and its local control are worked through.

**`hp-odu` is the heat pump at a monobloc house.** Which device that is
belongs to the layout's device-type records (node → component →
DeviceType), not to the name.

`ScadaWeb.DEFAULT_SERVER_NAME` (`names/core/node_names.py`) is the proactor
web-server key every house uses, not a node name.

This composed, layout-governed names system is half of the "multiple house types,
done right" rework.

## Temperature encodings

A temperature DataChannel is what a sensor measured and is encoded
`CelsiusTimes100`. A temperature DerivedChannel is what the scada computes,
in the unit control code and people reason in, and is encoded
`FahrenheitX100`. A setpoint the scada derives is a DerivedChannel and
takes the Fahrenheit rule.

One hundredth of a degree is one digit finer than the sensors are
accurate, and we carry one digit past accuracy and no more. A
wall-thermostat setpoint reported in whole degrees Fahrenheit does not
land exactly on `CelsiusTimes100` (69 °F reads back as 69.008 °F); the
rounding is accepted, because the alternative is a Fahrenheit value in
`spaceheat.telemetry.name`, an enum that is closed to growth.

Scada code never reads a temperature's encoding itself:
`ChannelRegistry.temperature(name, raw)` pairs the raw value with the
channel's `TelemetryName` or `OutputUnit` and the resulting `Temperature`
answers in F. Producers write the same way:
`ChannelRegistry.temperature_from_c(name, c)` and `temperature_from_f`
round a measurement into the channel's declared encoding, so a producer
emits whatever its channel declares
(`tests/actors/test_temperature_producers.py`).

Code passes and stores the `Temperature` itself
(`channel_temperature(name)`, `setpoints_at_onpeak_start:
dict[SpaceheatName, Temperature]`). Temperatures order across encodings,
and `.f` or `.c` appears only where a number chosen in degrees meets one
(the 1.0 °F cold margin, a display). Nothing that holds a `Temperature`
carries `_f` in its name. "Is this encoding a temperature" is answered by
constructing one, which raises `ValueError` otherwise; displays that show
degrees for temperatures and raw values for the rest rely on that and keep
no list of encodings.

A gen that moves temperature channels moves the device-type record's
`TelemetryNameList` with them: the tsnap driver accepts a record only when
its list is within the driver's supported set.

Every gen emits `CelsiusTimes100`. Open: whether the upstream data repos
convert by each channel's `TelemetryName` or assume a scale is unchecked,
and a deployed house takes the new encoding only after that is known
([OPS-542](https://linear.app/gridworks/issue/OPS-542)).
`data.latest_temperatures_f` in the House0 control code is not a channel
reading (rounded, implausible store layers scrubbed, missing layers filled
from below, about seventy readers); whether its values become
`Temperature` is undecided.

## The three layout families — the rework, encoded

This captures durable **design intent** (partially encoded today in code +
the `tlayouts` hand-scripts). It is the target of spruce-unlimbo Chunk B /
[OPS-334](https://linear.app/gridworks/issue/OPS-334), with the device-type spine in [OPS-407](https://linear.app/gridworks/issue/OPS-407). Some of it is intent ahead of
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

### The sieg flow identity — `primary-flow = sieg-send-flow + sieg-flow`

The Siegenthaler loop splits the primary flow: `sieg-flow` recirculates
through the loop, `sieg-send-flow` is the send line to the house. A house
measures two of the three and derives the third through a DerivedChannel:
beech measures `primary-flow` (a BTU pico) and `sieg-flow`, so its
`sieg-send-flow` is the **`difference`** strategy; maple measures
`sieg-send-flow` and `sieg-flow` (Hall picos) and its `primary-flow` is the
**`sum`** strategy (`DerivedSiegSum`). Both strategies live in the derived
generator and the scada layout loader. `sieg-send-flow` is therefore required
as a DataChannel OR a DerivedChannel, its node is not required, and a
BTU-sourced or derived flow has no `-hz` channel (House0 axiom 8 does not
require `sieg-flow-hz`). The sim pairs cover one pattern each (orange
measures primary, willow sums).

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
`affine`/`identity` derived channels (per-depth M/B — see "In-field tank-temp
calibration" below). house0 = buffer + 3 tanks; nolan = buffer + 1 tank. The (now
deleted) `simulated_tanks.py` was the sim equivalent. **Current gap:** neither test
fixture wires a tank generator, so the raw `*-device` channels the derived
tank-temp channels depend on don't exist and the layout fails
`validate_derived_channels` — wiring `add_tank3` into each builder is what
closes it.

### In-field tank-temp calibration

A tank probe's raw reading drifts per probe + per depth, so each calibrated tank
temperature is the raw device reading run through a **linear correction**
`y = M·x + B`:

- **Raw channel** `<reader>-depth{n}-device` — `WaterTempCTimes1000`, emitted by
  the pico TankModule3 (or the SimSensor in `simple_sim`).
- **Calibrated channel** `<reader>-depth{n}` — a derived channel that applies the
  correction. `Strategy: affine` carries the coefficients in
  `Parameters.Calibration`, a **`linear.one.dimensional.calibration`** object
  (`M` slope, `B` intercept, both finite; self-describing via `TypeName`/`Version`).
  When `M == 1.0` and `B == 0.0` the derived channel uses `Strategy: identity`
  (no correction) and carries no Calibration. `derived_generator.handle_affine`
  applies `M·x + B` then scales to `FahrenheitX100`.

The calibration word sits outside the layout closure: `derived.channel.gt`
types `Parameters` as a bare object and declares no dependency on
`linear.one.dimensional.calibration`, so neither the tlayouts snapshot
validation nor the scada reverse-conformance check would see a version
skew there (a `001` in the artifact against gwsproto's `000` pin refused
every affine channel at boot on 2026-09-06). tlayouts therefore seeds the
calibration word into its snapshot and builds the calibration through the
snapshot class, so the word rides the closure copy and the standing scada
conformance check covers it; the Nolan sim fixture carries its real twin's
four affine channels so the suite's artifact-boot test covers the path.

**How the coefficients are found.** They are **hand-discovered**: probe readings
are logged to the database, compared against reference temperatures in a
spreadsheet, and the per-depth `M`/`B` that best fit are read off and encoded.
This is a deliberate, occasional field activity, not an automated loop — the tree
homes' (beech, oak, …) coefficients are George's hand-fit values and MUST be
preserved across any layout rework.

**Where the calibration lives (the canonical pattern).** The calibration is a
property of the **derived channel** — each `<reader>-depth{n}` carries its own
`linear.one.dimensional.calibration`. The layout does **not** store a separate
calibration map; the derived channel is the single source of truth for a depth's
correction, so adjusting an in-field calibration = editing that one derived
channel's `Parameters.Calibration` (or regenerating the layout from updated
coefficients). `gw.nolan.layout` already follows this; house0 is being moved to
match (the legacy `TankTempCalibrationMap` layout field is retired — its M/B were
always required to equal the derived channels' anyway, so it was redundant
duplication). The generator still accepts the per-tank coefficients as a
generation-time input (the source of George's values); it just writes them into
the derived channels rather than into a stored map.

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

## I²C and board-resident components

A scada board hosts many parts — relays, an ADC, a DAC, GPIO — that
each need a physical address on the board. Both families follow this
pattern: the gw108 and the two-board Krida relay panel House0 runs
(`KridaDoubleRelayBoard16`, one device, basement markings `Relay1`–`Relay32`
as the RelayNames). The board is the **single source
of physical truth**; the parts on it are thin references that name *which*
thing they are and let the board hold the address. Three layers, the outer
two backed by actors:

1. **Bus** — one `I2cBus` actor per physical bus, the serialized exclusive
   owner of bus traffic. **All** bus traffic — relay bit read-modify-writes
   and ADC register reads alike — goes through it; that serialization is the
   only safe way to share one bus.
2. **Board** — `gw1.scada.device.type.gt`, pure data: the physical map
   (`BusList`, `NativeGpioInputs`/`NativeGpioOutputs`, `I2cRelays`, `CtAdc`,
   `ThermistorAdcs`, `Dacs`), resolved through a node's `BoardComponentId` and
   shared by **many** ShNodes. The gw108 instance is
   `data_classes/device_types/scada_gw108.py`.
3. **Device** — the per-relay / per-reader component, carried by **at most
   one** ShNode via `ComponentId`. Thin: it names *which* sub-device on the
   board it is (by that sub-device's `Name`) plus its control/channel config;
   it does **not** restate the physical address. `spaceheat.node.gt/302`
   already carries both `ComponentId` and `BoardComponentId`.

Board-resident parts stay uniform `ComponentBase`, each with its own coarse
`gw1.device.type` value and no specialized `*.device.type.gt` record — their
physical facts live in the board's config lists. A layout carries one
`scada.board.component.gt` per board, an `i2c-bus` node per bus and one
`i2c.relay.component.gt` per relay, on both families; the relay actor
resolves its `RelayName` against the board record at boot
(`tests/actors/test_relay_i2c_house0.py` proves all thirteen House0 relays
on both fixtures).

### The Sema I²C vocabulary

Generic `i2c.*` primitives carry nothing GridWorks-specific; only the board
descriptor and the Broadcom-pin word (`gw.native.gpio.pin`) are `gw*`. The
sema schemas are the source of truth; the durable shape:

- **Addressing is bus-relative.** `i2c.bit.address` `{I2cAddress,
  RegisterIndex, BitIndex}` and `i2c.reg.address` `{I2cAddress, RegisterIndex}`
  locate a target by device address *independent of which physical bus it is
  on*, so neither carries a `Bus`. That is what lets one address word serve
  both the bus-op messages and the board descriptor. All address fields are
  `non.negative.int` (a 0 address/register/bit is valid).
- **The physical bus.** `i2c.bus` `{Name (pascal.case), BusNumber}` — one bus
  on a board, `BusNumber` the Linux i²c adapter (`/dev/i2c-<BusNumber>`). A
  board declares its buses in `BusList`.
- **Per-device configs** — each carries a `pascal.case` `Name` (its
  silk-screen name) and an `I2cBus` naming its board bus:
  `i2c.relay.config`, `i2c.adc.config`, `i2c.thermistor.interface.config`,
  `i2c.dac.config`. Chipset enums `i2c.adc.type` (`Ads1115`/`Ads1015`) and
  `i2c.dac.type` (`Mcp4728`/`Mcp4725`).
- **Bus-op messages** (the actor wire protocol): `i2c.read.bit`,
  `i2c.write.bit` (+`Value`), `i2c.read.reg` (+`NumBytes`), `i2c.write.reg`
  (+`Value`), `i2c.result` `{Operation, Value?, Success, Error?, UnixTimeMs,
  TriggerId}`. `Bus` on every op is the `I2cBus` actor's `spaceheat.name`;
  requests carry a `TriggerId` and `i2c.result` correlates back by it (so it
  echoes no address). `Value` is a single `non.negative.int` widened to hold a
  bit or a 1–2 byte register word.

The free-key string→int maps (`NativeGpio`, `I2cRelays`, `Dacs`) became typed
**arrays** because sema's codec PascalCases all keys, so a free-key map can't
decode; the board keeps `NativeGpioInputs`/`NativeGpioOutputs` as two lists to
hold the in/out distinction structurally.

**Two enforcement tiers** (the recurring sema theme): **formats are hard**
(`pascal.case`, `non.negative.int`, `positive.float`, … reject at the codec
boundary); **enum membership is soft** (an unknown value coerces to the enum's
default rather than raising); **array length is unenforced**. So a value range
or a list-length bound is an **axiom**, not a primitive constraint —
`Value ∈ {0,1}` (`i2c.write.bit`), `NumBytes ∈ {1,2}` and `Value` fits
(`i2c.read.reg`/`write.reg`), `Error` non-blank ⇔ `¬Success` (`i2c.result`).

### Invariants (referential integrity)

- **`BusMembership`** (enforced on `gw1.scada.device.type.gt`): every device
  config's `I2cBus` appears in the board's `BusList`.
- **Board↔component cross-consistency** (the relay actor enforces it at
  boot; the Nolan word states it as axiom 2 and the House0 word gains its
  `BoardResolution` mirror in the sema wave that drops the multichannel
  word, OPS-392): a relay
  component's `RelayName ∈ board.I2cRelays`; its `WiringConfig ∈` that relay's
  `SupportedWiringConfigs`; no two relay components on one board share a
  `RelayName` (⇒ no bit-address collision); a thermistor reader's ADC
  reference resolves in `board.ThermistorAdcs`.
- **Layout-level bijections** (target): the DataChannel set ↔ the `ChannelName`
  set across all component `ConfigList`s; each `I2cBus` actor ShNode ↔ a board
  `BusList` entry, via a defined `pascal.case ↔ spaceheat.name` casing map
  (`DefaultBus ↔ default-bus`).

### ADC reads route through `I2cBus` (decided)

The thermistor reader is a **client** of the `I2cBus` actor, not a direct
hardware owner — no parallel Adafruit access. This is safe because the slow
part of an ADS1115 read happens **off-bus**: issue `start-conversion` (a
discrete bus op), sleep off-bus through the ~1–8 ms conversion, then issue
`read-result` (another op). The bus is held only for the µs-scale register
transactions, so a queued relay write slots in between and relay latency stays
bounded. Granularity is **per ADC chip** (the 4-channel mux unit). The ADS1115
holds its result in its own register until read, so an intervening transaction
to a *different* address is harmless; the one rule is never start a second
conversion on the *same* chip before reading the first. This is why `I2cBus`
gained register ops (`I2cReadReg`/`I2cWriteReg`) alongside the bit ops.

The `I2cBus` actor (`actors/i2c_bus.py`) receives the composed ops and
replies `I2cResult` to the requester named by `Header.Src`, so a relay
confirms its own actuation by `TriggerId`. `relay.py` has one I2C
actuation path for both families; there is no multiplexer actor.

### The ADC noise floor

The thermistor reader's baseline configuration (single-shot 128 SPS, read
at 1 Hz, raw) measures 0.011–0.012 °C sample-to-sample stddev on the
gw108 zone thermistors, about 45× below the 0.5 °C async-report
threshold, so zone temperatures need no smoothing. The noise is white
(a 5 Hz + EMA mode reduced it by the √5 the arithmetic predicts), so
any future averaging can be sized by calculation rather than
re-measured; smoothing buys ~1 s of lag and ~30 % bus occupancy at
5 Hz × 4 channels for a reduction the zone temps do not need. One
channel (zone3-upstairs at spruce) carries a low-frequency component
smoothing cannot remove. The open question the floor leaves is
glitch robustness, not noise: the reader publishes each in-band sample
as truth, so one garbled-but-plausible read publishes a wrong value.
Candidate closures are two consecutive in-band samples before an async
publish, or the EMA, which absorbs single-sample glitches by
construction. Record and reproducer: `experiments/2026-08-06-ads-noise/`.

### Expander types and the energized level

The two boards' expanders speak different bus protocols, so the board
record names the chip (`ExpanderType` on `i2c.expander`, enum
`i2c.expander.type`). The gw108 uses a TCA9555 (addressed output, input
and configuration registers); the Krida panel a PCF8575 (one
quasi-bidirectional port written and read as a word, no configuration
register). The bus actor drives each accordingly, and picks fake silicon
from the board record alone, never a runtime flag: a simulated House0
board is a `gw1.sim.device.type` value (`SimKridaDoubleRelayBoard16`,
driver `SimPcf8575`; the gw108's is `SimTca9555`).

The Krida panel is active-low (power-on all-high is every relay off)
while the gw108 drives high, so the record carries a required
`RelayEnergizedLevel` (axiom `RelayEnergizedLevelRange`) and the relay
actor translates its logical pin value to the board's level at the write
and at the readback. The gw108 rev B driver is an NPN low-side switch
with a 100k base pull-down, so a floating pin is off there too; rev C
keeps active-high. The Krida first bank is inverted on the wire (marking
1 → pin 7, …, 8 → pin 0), declared as pin data on the record.

Krida addresses are field-chosen by DIP switch: the record carries
`AllowedI2cAddressList` and no `I2cAddress`; the chosen pair lives on the
board component's `I2cAddressList`, index-aligned. The relay and bus
actors read only the fixed address today; the chosen-address path is an
open gap.

### The 0-10V output actuator

Every 0-10V output in both families is an actuator on the relay pattern:
one node (`secondary-010v` on Nolan; `dist-010v`, `primary-010v`,
`store-010v` on House0; ActorClass `ZeroTenOutputer`, a leaf under its
boss in the command tree), one `i2c.dac.output.component.gt` naming the
board record and its DAC channel with one `dac.output.config`
(`ChannelName`, `ActorName`, `DacChannel`: wiring only, chip-neutral), and
one `VoltsTimesTen` DataChannel about and captured by the output node so
the commanded level reports. The command is `AnalogDispatch`, `Value`
volts times ten, 0 to 100. Each output reports its own `ActuatorsReady`;
the scada's required actuators are the `ZeroTenOutputer` nodes.

**One actor arm.** `ZeroTenOutputer` resolves its DAC from the board
record's `i2c.dac.capability` entry and drives it through the `I2cBus`
single owner (`muxed_op`, `MuxName` None where the record has no mux).
The chip branch is in the driver layer, keyed on the record's `DacType`
and the board's `DeviceType`: `drivers/mcp4728.py` (gw108: internal
reference, gain 1, five-times output stage for 10.24 V full scale, a
storable EEPROM power-on value) and `drivers/gp8403.py` (the DFRobot
modules on House0's I2C panel, two `Gp8403` entries at addresses 94 and 95
in the `scada.krida` record, registers 0x02 and 0x04, 10 V full scale,
stores nothing). Sema carries what crosses a boundary or varies per
house; facts fixed by the choice of device are these driver tables. The
top code clamps at 4095: rounding to 4096 under the 12-bit mask wrote 0 V
at full scale (found on beech, scada `6bfa2bf9`).

**The power-on level is an operational param.** What the pump does with
the scada down is a per-house tunable, not wiring, so it lives in
`ZeroTenPowerOnList` (`zero.ten.power.on`: node name and
`PowerOnVoltsTimesTen`, at most 100) on both ops words. Nolan's secondary
pump is 76; House0's dist, primary and store are 20, 40 and 0. Boot fails
loudly when a DAC-backed output has no ops entry. On the MCP4728 the actor
verifies the chip EEPROM against the ops level at boot and reprograms only
on a mismatch, the one EEPROM-touching path; the GP8403 stores nothing, so
the ops level is what the actor asserts at boot and on every heartbeat,
and a scada-down DFRobot pump sits at the chip's own default (a driver
fact of a prototype on its way out, not something to work around). On
both chips the 60 s heartbeat re-asserts the LAST COMMANDED value, the
power-on value only until the first command, one reading per successful
write. An unwired DAC channel has no component and its EEPROM is never
touched. The ops word loads once at boot (`actors/scada_data.py`
`load_operational_params`); a changed level is edit the artifact, restart.

**Sim.** No simulated GP8403: the sim House0 record
`SimKridaDoubleRelayBoard16` carries two `Mcp4728` entries, so the sim
House0 drives its three outputs through `SimMcp4728` on the same arm and
verify path as Nolan (`SimI2c.muxless_dacs`). The GP8403 arm is covered by
a unit test of the driver's wire bytes and by the beech witness.

Verified: the real MCP4728 on the bench 2026-09-05
(`experiments/2026-09-05-dac-output-bench/` "Found", run 4) and spruce's
secondary pump 2026-09-06 (`experiments/2026-09-06-spruce-pump-speed-sweep/`);
the GP8403 arm end to end on beech `dist-010v` 2026-09-13
(`experiments/2026-09-12-beech-dist-010v-sweep/`: dist pump power followed
the level, 4 W at 2 V to 48 W at 10 V, up and down).

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
- **`CACS_BY_MAKE_MODEL` — the MakeModel↔CAC-id bijection (being retired, summer 2026).**
  `MakeModel` and this bijection are the **pre-`DeviceType`** mechanism — read this as
  the as-is loader code finishing its `jm/delete-cac-id` deletion; the target is the open
  `DeviceType` (`gw1.device.type`) carried on the component, no canonical-id map. `layout_gen` and
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
  Ops issue (**[OPS-407](https://linear.app/gridworks/issue/OPS-407)**, subsumes the earlier `replace-cacs-by-make-model` idea).

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
  Detail in `components.md` ("The config list — when a component carries one").
- **The ops fixture filenames carry a retired word.** `tests/config`
  names them (`gw.house0.orange.operational.params.json`,
  `gw.nolan.operational.params.json`). The naming rule for a one-word
  ops file is undecided and the rename waits for it; the sema-typed
  JSON filename convention would give
  `<subject>-gw.operational.params-000.json`, which puts the same
  question to the layout files.
- **Strategy-name semantics need a sema home** (also noted in the hacky-bits
  above) — a versioned `strategy` enum/type so a rename is a lookup, not an
  inference.
