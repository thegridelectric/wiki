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
- **Sema component gap-fill: dfr + ads** — committed `64bce72`, `172 passed`. `dfr.config` +
  `dfr.component.gt`; `ads.channel.config` (`ThermistorMakeModel → ThermistorDeviceType`) +
  `ads111x.based.component.gt`; new versioned enum `thermistor.data.method`.
- **Scada cac→DeviceType migration** — WIP-committed `b0f03292` + `b358a676` (to squash). `ComponentGt` →
  `DeviceType` (v002); `ComponentAttributeClassGt` → device-type-record base (no `MakeModel`);
  `hardware_layout` resolution joins by `DeviceType` (records optional); `layout_db` + all 12
  generators on `Gw1DeviceType`; ~9 actor/driver dispatches moved `cac.MakeModel → DeviceType`;
  `show_layout` fixed; `CACS_BY_MAKE_MODEL` / `DEVICE_TYPE_BY_MAKE_MODEL` / `db.device_type_for`
  all dropped. `Gw1DeviceType` enum is **app-code only** — gwsproto sema types keep open
  `DeviceType: str`.
- **Sema Hubitat pair — gap-fill complete** — pending commit. Five flat words bottom-up:
  `maker.api.attribute.gt/000` (snake→Camel re-cased; refs `spaceheat.telemetry.name:007` +
  `spaceheat.unit:001`), `hubitat.gt/000`, `hubitat.poller.gt/000`, and the two shells
  `hubitat.component.gt/000` + `hubitat.poller.component.gt/000` (carry `DeviceType`, mirror
  dfr/ads). The MakerAPI URL/REST machinery turned out to be **computed helpers, not serialized
  state** — excluded from the contract (noted in each word's `extended_description` and the
  gwsproto docstrings). `MacAddress` is a plain string (no `mac.address` format — speculative on
  legacy-only words). `172 passed`; the three top-level types pass the sema decoder cross-check.

**Not done:** the **scada fixture-regen green** (the spruce-unlimbo merge gate).

## ▶ DO THIS NEXT — finish the scada cac→DeviceType green

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

**The first shared scada↔terminalasset layout is constructed elsewhere.** A new dedicated word
**`gw1.simple.sim.layout`** — the simplest plant that is still a thermal-storage heat-pump system,
built from the sim components — is the first shared `hardware-layout.json` both sides stand up
against. It is authored in the **simulated-test-environment** design (`build-plant.md`, "The first
sema layout word"), not here: it carries today's `hardware_layout.py` structural validations as
axioms and is fully wired (the complete `ConfigList` of every component), but **none** of the
house-specific or `DeviceTypeRecordAlignment` axioms, and it does not complete `gw.nolan.layout` or
start `gw.house0.layout`. The durable principle it rests on — *the layout encodes the plant's
sense/control surface; the scada protocols share + disambiguate, grounded in the thermal-storage
heat-pump domain; three diverse layouts are the forcing function* — lives in
`executor/hardware-layout.md`. What **this** pass owes that work is the migrated, flat **component
vocabulary** (including the sim components) the layout is built from.

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
but missed these *components* + configs). **dfr + ads + Hubitat all done** (above) — the
component gap-fill is complete. `near5` deliberately not added as a format (`OpenVoltageByAds`
is a bare number array).

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
