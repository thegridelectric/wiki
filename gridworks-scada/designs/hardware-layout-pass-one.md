# Hardware layout — pass one

Status: Accepted · Pass 1 · Updated 2026-06-14 · Linear: OPS-407

**EDD: no** build-out/refactor — verified by the suite (layouts load + `layout_gen` green
for BOTH the `house0` and Spruce layouts; `pytest`), not gated on a standalone real-world
experiment.

> What this is: the first critical pass on the scada hardware-layout / components model.
> Drop the UUID `cac_id`s, replace make/model-as-CAC with a readable `gw1.device.type`
> `DeviceType`, simplify components, restructure `layout_gen`, and fill the sema component
> vocabulary against a real layout. A **shared dependency** — both the
> **simulated-test-environment** harness and **spruce-unlimbo** Chunk B need it — so it is
> its own flat Linear issue (OPS-407), referenced by name from both.

## Status (2026-06-14)

Work branch: **`jm/delete-cac-id`** — the tunnel branch, nested
`jm/spruce-unlimbo → jm/sim-test-env → jm/delete-cac-id` (it contains all of
`origin/jm/spruce-unlimbo`). Continue here; do not cut off `dev` or `jm/spruce-unlimbo`.

**Done + green:**
- **Sema cac→DeviceType** — committed `2d55705`, `0cd2175`. `gw1.device.type` enum; every
  cac-carrying component bumped to drop `ComponentAttributeClassId` / carry `DeviceType`;
  draft `*.device.type.gt` records; CACs frozen + `replaced_by`; `gw.nolan.layout` rebound
  + `DeviceTypeMembership` axiom; `layout.lite/015`.
- **Sema FlowMeterType** — committed `abc369f`. `pico.flow`/`pico.btu` `001` `FlowMeterType`
  moved `$ref spaceheat.make.model → formats/pascal.case`, mutated in place (version `001`
  kept → aggregate layout words don't rebind).
- **Sema component gap-fill: dfr + ads** — uncommitted, `172 passed`. `dfr.config` +
  `dfr.component.gt`; `ads.channel.config` (`ThermistorMakeModel → ThermistorDeviceType`) +
  `ads111x.based.component.gt`; new versioned enum `thermistor.data.method`.
- **Scada cac→DeviceType migration** — uncommitted beyond WIP `b0f03292`. `ComponentGt` →
  `DeviceType` (v002); `ComponentAttributeClassGt` → device-type-record base (no `MakeModel`);
  `hardware_layout` resolution joins by `DeviceType` (records optional); `layout_db` + all 12
  generators on `Gw1DeviceType`; ~9 actor/driver dispatches moved `cac.MakeModel → DeviceType`;
  `show_layout` fixed; `CACS_BY_MAKE_MODEL` / `DEVICE_TYPE_BY_MAKE_MODEL` / `db.device_type_for`
  all dropped. `Gw1DeviceType` enum is **app-code only** — gwsproto sema types keep open
  `DeviceType: str`.

**Not done:** the **Hubitat** sema gap-fill (next), then the **scada fixture-regen green**.

## ▶ DO THIS NEXT — the Hubitat sema pair

Two beech components are still missing from sema: `hubitat.component.gt` and
`hubitat.poller.component.gt`. Harder than dfr/ads because the scada source carries
**`snake_case` fields** (`attribute_name`, `web_poll_enabled`, …) that violate sema's
CamelCase MUST — **re-case to CamelCase** (decided) and model the nested REST-poller URL
config. Trust the **migrated sema patterns** for shape (`electric.meter.component.gt`,
`i2c.thermistor.channel.config`); the old scada types are a field reference only and may be
stale.

**Timebox — 90 minutes.** Finishing the last pair closes the gap-fill so
no component dangler keeps pulling attention — worth doing. But the Hubitat sub-types are the
open risk (nested REST/URL config + the `snake_case` re-casing). If the modeling runs past
**90 minutes**, **punt** the remainder to a later focused pass rather than let it balloon —
lean toward modeling the **minimum the layout actually needs**, not the full REST plumbing.

First: read `sema/CLAUDE.md` + `spec/authoring/types.md` + `spec/authoring/enums.md`; post the
read-receipt. Then bottom-up (each word: author yaml → registry entry → `scripts/build_indexes.sh`
→ `scripts/regenerate_runtime.py` → `pytest` green):

1. **`maker.api.attribute.gt`** (from scada `MakerAPIAttributeGt`) — re-case every field
   (`attribute_name → AttributeName`, `channel_name → ChannelName`, `web_poll_enabled → WebPollEnabled`,
   …); refs `spaceheat.telemetry.name` + `spaceheat.unit`.
2. **`hubitat.gt`** and **`hubitat.poller.gt`** (from `HubitatGt` / `HubitatPollerGt`) — re-case;
   decide how much of the nested `URLConfig` REST machinery to model vs simplify (it is poller
   plumbing — lean toward the minimum the layout actually needs).
3. **`hubitat.component.gt`** (`Hubitat` → `hubitat.gt`) and **`hubitat.poller.component.gt`**
   (`Poller` → `hubitat.poller.gt`) — flat component shells with `DeviceType`, mirroring the
   dfr/ads components.
4. Registry entries (cluster with the existing dfr/ads gap-fill block before
   `electric.meter.channel.config`), bump `metadata.last_updated`, regen, suite green.

Source files to mine for fields: `gridworks-scada/packages/gridworks-scada-protocol/src/gwsproto/
named_types/{hubitat_gt,hubitat_poller_gt,hubitat_component_gt,hubitat_poller_component_gt}.py`.

## ▶ AFTER THAT — finish the scada cac→DeviceType green

The scada migration is code-complete but the **committed test fixtures still carry the old
shape**, so the suite is red on missing `DeviceType`. Run from `gw_spaceheat` (venv at
`gw_spaceheat/venv`), tests need `PYTHONPATH=gw_spaceheat`. To green:

1. **Regenerate** `tests/config/{nolan,house0}-layout.json` via
   `gw_spaceheat/layout_gen/genlayout.py mktest` (run from repo root; `LayoutIDMap` now
   tolerates old-shape src, so it can bootstrap from the existing fixtures).
2. **Fix the hand-written named-type sample dicts** in `tests/named_types/*` —
   `ComponentAttributeClassId` → `DeviceType` with the right `gw1.device.type` value
   (per-component judgment, not mechanical).
3. **`pytest` green for BOTH layouts** — the spruce-unlimbo merge gate.
4. **Sema decoder cross-check:** emit each new gwsproto type to JSON and run
   it through the sema runtime decoder — the real contract check that scada output conforms
   to the sema schemas, beyond internal green.

## The device-type model (the durable contract)

- **`gw1.device.type`** — sema enum, the universal device key. PascalCase values (the
  `pascal.case` format), e.g. `EgaugePowerMeter`, `GridworksScadaGw108`, pruned to what
  `gridworks-scada` uses. A device **category**, NOT a make+model (several eGauge models →
  one value, by design). `spaceheat.make.model` is **frozen**; this is a fresh vocabulary.
- **Components carry `DeviceType` as an open `pascal.case` string** (NOT an enum `$ref`) — so
  component types stay version-stable as the enum grows. The **hardware-layout type** enforces
  `DeviceType ∈ gw1.device.type` (the enum membership lives on the *layout*).
- **String in the sema types, enum in the scada app code.** gwsproto sema types use open
  `DeviceType: str`; scada app code (generators, actors, drivers) uses the `Gw1DeviceType`
  enum. `GwStrEnum` is a `str` subclass, so `Gw1DeviceType.X` sets the open field and compares
  equal to it with no friction.
- **All `cac_id` / UUID device identity is REMOVED.** A plain device is fully described by its
  `DeviceType` + the component's own fields (`ConfigList`, `DisplayName`, `HwUid`). The
  `CACS_BY_MAKE_MODEL` / bijection / projection machinery evaporates; `make_model` as a phrase
  is retired from scada app code.
- **Specialized records open per-family, only when the category carries real data** —
  `gw1.scada.device.type.gt` (gw108 GPIO/I²C/ADC numbers), `electric.meter.device.type.gt`,
  `ads111x.based.device.type.gt`. The component finds its record (when one exists) by the
  shared `DeviceType` key — `component → DeviceType → optional record`. Records are **optional**
  at runtime; the loader resolves `None` for record-less categories.
- **Membership is a layout axiom, not a per-component flag.** `DeviceTypeMembership`: if a
  component's `DeviceType` requires a record, the layout MUST contain it. A second axiom is
  owed — **`DeviceTypeRecordAlignment`**: a component's record must be the *right family* for
  its `DeviceType`. This replaces the silent guard the dropped `(MakeModel, cac_id)` pairing
  used to provide (`make_component` does no type check). Not yet on `gw.nolan.layout`.
- **Carried caveat — inheritance is deliberate debt.** The scada device-type records inherit
  from `ComponentAttributeClassGt` (Andy's inheritance — violates the flat-sema rule). Per the
  CLAUDE temporary directive this is **left as-is for the proactor port**, not repaired here.

**Why this shape (the toolchain wall):** the earlier plan — a UUID-valued `gw1.device.type.id`
enum + a `make.model → id` projection — was abandoned. Sema string-enum values must be valid
Python identifiers (`GwStrEnum`: the wire value *is* the member name), so UUIDs can't be enum
members. Dropping UUID identity entirely is the simpler, toolchain-honest answer.

## Scope — pass-one boundary

The spine: drop `cac_id`s → `gw1.device.type` `DeviceType`; simplify components; restructure
`layout_gen`; fill the sema **component** vocabulary against a real (beech) layout. **Deferred to
pass two:** the full `ChannelConfig` / config-list overhaul and `TelemetryName → gw1.unit` +
`gw1.quantity`.

**The near-term target is a new, _basic_ shared hardware layout** that scada and terminalasset
both stand up against — one common `hardware-layout.json`, typed by a new dedicated word
**`gw.simple.sim.layout`**, built from the sim components (`sim.sensor.component.gt` /
`sim.relay.component.gt`).

**Why a third layout (the point of it).** `gw.simple.sim.layout` is a deliberate **third choice
alongside House0 and Nolan** — the simplest plant we can imagine (fake the physics, stub the
devices) that is *still a genuine thermal-storage heat-pump system*. Its value is a **forcing
function**: two real layouts that differ mostly in hardware generation can still let House0
assumptions leak; a third, radically-simpler, fake-physics plant that *also* has to run is
different enough to break any House0-coupling that survived. Making the scada handle **all three**
gracefully is what proves the plant-abstraction seams are real, not aspirational — and the same
artifact doubles as the minimal fixture that stands up the simulated terminalasset. Two payoffs,
one layout.
"Basic" means a **small device set — NOT axiom-light and NOT half-wired**:

- It **carries all the structural tests `hardware_layout.py` enforces today**, ported into the
  layout word's axioms — global id uniqueness, node↔component↔channel wiring integrity,
  `ConfigList` existence, actor↔component match, channel about/captured-by node existence, etc.
- The instance is **fully wired**: every data-channel wiring present, i.e. the **complete
  `ConfigList` of every component** in it.

What's **not** in this first layout: the house-specific axioms; the *new* `DeviceTypeRecordAlignment`
axiom (not in `hardware_layout.py` today); completing `gw.nolan.layout`; or starting a
`gw.house0.layout`. Those are pulled by demand later. Finishing the *component* gap-fill (the
Hubitat pair) is the close-out; full *production-layout* completion is not.

**MVP test layout vs simulated production layouts — two different axes.** This first word is a
dedicated, concrete layout word for proving the simulated terminalasset — a **peer** of
`gw.nolan.layout`, not a base under it. Separately we *do* want to run **simulated versions of
real layouts** (a simulated `gw.nolan.layout`, etc.) — that needs **no new type**: it's an
*instance* of the real layout word with `sim.sensor` / `sim.relay` swapped in for the real
hardware (same type, sim-component instance), pulled when the harness replays production topology.

The structural tests ported from `hardware_layout.py` (id uniqueness, wiring integrity, ConfigList
existence, actor↔component match, …) apply to *any* layout, so the same axiom text appears in this
word **and** in `gw.nolan.layout` — **flat-repeated, not inherited** (flat-sema: there is no base
layout word). "Port once" means author the axiom text once and copy it into each flat word, not a
runtime base. So **do not name this word as a generic/base concept** (`gw.basic.layout` etc.) — that
falsely implies inheritance. It is a concrete, purpose-specific layout, named for what it is/does.

### Layout encodes the plant; the scada protocols share + disambiguate

A specific sema layout **encodes the plant's sense/control surface** — what can be sensed, what can
be actuated, and how. The scada code reads that surface through **functional protocols** that
(a) **share** the common control logic across layouts by speaking in *capabilities*, not hard-coded
House0 node names, and (b) **disambiguate smoothly** where plants differ — feature-detect from the
layout and enable / disable / adapt. This is what lets one scada serve House0, nolan, and the sim
plant alike.

**The shared protocols are grounded in a common domain, not arbitrary.** Every one of our layouts
is the same plant class — a **thermal-storage heat-pump system**: a heat pump, thermal storage,
distribution, and zones. That shape is *given*, so `LocalControl` (and its peers) is *the* controller
for that class and does a very similar thing for all of them by definition. The layout only supplies
the **realization** — how many tanks, which actuators, sieg-loop or not, real or sim. So the
feature-detection is never "is this a heat-pump plant?" (always yes) but "this plant's dist pump is a
010V on *these* nodes / a relay / a sim stub." The domain is fixed; the wiring varies. That makes
`gw.simple.sim.layout` precisely **a simulated thermal-storage heat-pump plant** — it carries the
domain shape (storage, zones, heat pump, dispatch nodes) in minimal/sim form, which is exactly what
lets `LocalControl` run its near-identical logic against it.

`LocalControl` (`actors/local_control/`) already shows both halves, unevenly:
`_dist_pump_recovery_enabled()` / `_store_pump_recovery_enabled()` feature-detect the required
relay/010V nodes and degrade gracefully when absent (the good pattern); but it still `raise`s when
the core dispatch nodes (`local_control_normal`/`backup`/`scada_blind`) are missing and reaches for
House0-named channels (`store_cold_pipe`, `hp_ewt`, `required_energy`) and devices (`dist_010v`,
zone relays) directly.

The split for "works for ALL layouts":
- **SCADA-universal scaffolding** (the local-control dispatch nodes, the state machine) belongs in
  *every* layout, including `gw.simple.sim.layout` — hard-requiring it is fine; it's the scada, not
  a plant difference.
- **Plant-specific sense/control** is what the layout encodes; the actors must read it as
  **capability** (the `_recovery_enabled` feature-detect pattern, generalized), not by House0 name —
  so a sim plant with a simpler actuator set still runs the shared protocols. Generalizing that
  coupling is the work that makes one scada serve every plant.

**Decision (2026-06-14): the ConfigList revamp is NOT pulled forward.** Tempting — we are
already in these files and it would avoid another version bump — but `TelemetryName` is
*everywhere* in scada, and **decisively, we cannot validate a change that broad without a
mature experimental harness that exercises all the production layouts** (the EDD bar). New
channel configs are authored in the **current** shape; revisit once the
simulated-test-environment harness can replay the production layouts.

## Gleanings — domain context (durable)

> **Naming — Nolan ↔ Spruce (keep both; not PII):** the gw108 house is **Nolan** in code and
> sema (`gw.nolan.layout`, Strategy `"Nolan"`, `gw108_nolan_zones.py`, `nolan-layout.json`)
> and **Spruce** colloquially — the next in the tree-name series (beech, elm, oak, fir, maple
> → spruce). Same house. "Nolan" is an honored legacy, not a name to scrub: Ms. Nolan was a
> Millinocket widow who lived in the original house; when she could no longer pay her mortgage,
> Matt Polstein bought the property and let her stay through her passing, then built the Nolan
> house. Matt was glad to have her legacy live on in the name.

**Deployment context (the field reality):**
- The first five homes all run the **House0** layout: **beech, elm, oak, fir, maple.**
  Electronics hand-made by George — not gw108.
- Common across all five: three store tanks + a buffer; Hubitat hubs driving Honeywell
  thermostats; a variety of heat pumps. **Siegenthaler loops on beech and maple** — a
  mechanical variation today, not a layout/software distinction.
- **Spruce is a one-off:** gw108 electronics, a plain radiant floor. The next ~12 new-builds
  use store-under-floor (radiant + bisecting insulation), so Spruce's specifics shouldn't be
  over-generalized into a layout word.

So House0 is the **fleet** layout (5 homes, one hardware generation); Spruce is a **single
experimental** layout (gw108) — the asymmetry behind whether house0 earns its own
`gw.house0.layout` word. House0 is *not* minimal: a full alternative stack (Hubitat/Honeywell
thermostat, dual Krida I2C relay boards, DFRobot pump DACs, ~47 ShNodes) vs Spruce's
GW108-unified stack (~30 ShNodes).

**Sema component gap-fill (beech coverage):** a beech layout (`tlayouts/output/`) names 11
`*.component.gt` types; four were missing from sema (Phase 1 added some device-type *records*
but missed these *components* + configs). **dfr + ads done** (above); **Hubitat pair remaining**
(DO THIS NEXT). `near5` deliberately not added as a format (`OpenVoltageByAds` is a bare number
array).

## Why its own issue / dependents

A sizeable chunk depended on by **two** larger designs becomes its own flat issue (per the
shared-dependency rule), referenced by name from each — keeping Linear flat and the work
explainable. Dependents:
- **simulated-test-environment** — Phase A needs the new component shape to stand up the sim
  layout; the device-type model lives here.
- **spruce-unlimbo Chunk B** — the `layout_gen` restructuring + the merge gate "layout
  generation green for both the `house0` and Spruce layouts."
- **The gwbase'd LTN** — will want the same shared sema hardware layout.
  A third consumer: the more nodes that read the layout, the more "fix the contract once, now"
  amortizes — and the more debt is avoided by not building against the old cac/make-model shape.

It is also the "critical pass" `executor/hardware-layout.md` already anticipated.
