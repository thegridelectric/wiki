# Hardware layout — pass one

Status: Accepted · Pass 1 · Updated 2026-06-14 · Linear: OPS-407

**EDD: yes** the verification that matters now is a real round-trip: scada emits each type,
publishes to the dev rabbit broker, and gridworks-terminalasset decodes it through its sema
snapshot. (The earlier in-suite bar — `layout_gen` green for both layouts — still holds as a
sub-gate, but the round-trip is what proves the contract.)

> What this is: the first critical pass on the scada hardware-layout / components model.
> Drop the UUID `cac_id`s, replace make/model-as-CAC with a readable `gw1.device.type`
> `DeviceType`, simplify components, restructure `layout_gen`, and fill the sema component
> vocabulary against a real layout. A **shared dependency** — both the
> **simulated-test-environment** harness and **spruce-unlimbo** Chunk B need it — so it is
> its own flat Linear issue (OPS-407), referenced by name from both.

## ▶ DO THIS NEXT — scada↔terminalasset round-trip parity for every snapshot type

**Goal:** for every sema type the gwta snapshot carries (27 = 16 published components + the
node + their closure, at `gridworks-terminalasset/src/gwta/sema`), the scada `gwsproto` can
build an instance, publish it over the dev rabbit broker, and `gwta.sema`'s codec decodes it
clean. Only the **Hubitat pair is proven** so far (round-trip green after the Version fix
below); the other 25 are unverified and likely carry the same class of mismatch.

Recipe (extend the `/tmp/rt_{send,capture,decode}.py` harness from the Hubitat round-trip to
all types):
1. For each gwsproto type in the snapshot set, build an instance, serialize (`by_alias=True`
   where the type uses snake fields + camel aliases), and decode through `gwta.sema` — list
   every mismatch.
2. Fix the gwsproto type to match its sema word: **Version equal to the sema word's version**
   (not the inherited `ComponentGt` base), CamelCase serialized fields, no `cac_id`.
3. Prove the real path: scada publishes to `localhost:1885` (dev rabbit, MQTT, TLS off), a gwta
   subscriber decodes. Keep the harness as the re-runnable reproducer (EDD evidence).
4. **Cover old versions, not just latest.** Where scada may still emit a prior version, verify the
   `decode-old → upgrade() → decode-current` path — the snapshot seed used latest-only, so the
   upgrade functions for this pass's many version bumps are **untested**; stub/wrong `upgrade()`s
   fail a real consumer that receives older-version wire data.

**Then, the still-open sub-gates (ordered):**
- **scada fixture-regen green** — the committed `tests/config/{nolan,house0}-layout.json` carry
  the old shape; ~8 `tests/named_types/*` reds on missing `DeviceType`. Regenerate the fixtures
  (blocked on wiring tank sensors — see executor `hardware-layout.md`) + fix the hand-written
  sample dicts (`ComponentAttributeClassId` → `DeviceType`, per-component judgment) → `pytest`
  green for both layouts (the spruce-unlimbo merge gate).
- **layout_gen 3-builder refactor** — `house0_layout_gen` / `nolan_layout_gen` /
  `simple_sim_layout_gen` over shared tools, names-driven, per the durable intent now in
  `executor/hardware-layout.md` ("The three layout families"). Deferred; the design intent is
  captured there.

Work lives on the scada **`jm/delete-cac-id`** branch (the tunnel
`jm/spruce-unlimbo → jm/sim-test-env → jm/delete-cac-id`); do not cut off `dev`. The sema and
terminalasset sides are merged/committed (below).

## What I've learned (this session)

- **EDD caught a real contract bug the in-suite tests could not.** gwsproto's Hubitat
  components inherited `Version "002"` from `ComponentGt`, but the sema words are `000`, so the
  sema decoder rejected them (`Unsupported version 002`). The fix: each gwsproto component
  declares its **own** `Version` matching its sema word (dfr/ads already did; the Hubitat pair
  didn't). This is the template for step 2 above — expect the same across the other 25.
- **The sema snapshot is the authoritative version reference, not memory.** `sema snapshot
  prepare <seed> && sema snapshot build --package-name gwta` emits a restricted runtime into
  `<consumer>/src/gwta/sema`; drafts are auto-excluded. gwta now decodes all 27. Latest versions:
  `electric.meter` / `gw108.*` / `web.server` / `i2c.thermistor.reader` = **002**,
  `i2c.multichannel` = **005**, `pico.tank` = **012**, `pico.flow`/`pico.btu` = **001**,
  `hubitat.*` / `dfr.*` / `ads.*` / `sim.*` = **000**, `spaceheat.node.gt` = **302**.
- **Six axiom validators were `NotImplementedError` stubs** (`CaptureAndPollingConsistency`,
  `HwUidPattern`, `PicoHardwareIdentityXor` / `PicoKOhmsConsistency` / `SensorOrderPermutation`,
  `ActorAndRelayIndexUniqueness`) — implemented (sema `a8a7f25`). `layout.lite/015`'s axiom is
  still a stub (not in the terminal-asset closure; larger job).
- **25 schemas lacked `examples:`** — added axiom-satisfying minimal examples so the snapshot
  round-trips all 27. Examples are non-normative (permitted on published versions).
- **`make_model` is fully gone from gwsproto** (`ThermistorMakeModel` → `ThermistorDeviceType`;
  `FlowMeterType` → open `str`). The umbrella `tlayouts/gen_*.py` hand-scripts still import
  `MakeModel` and will break until folded into the builders — expected (they are being retired).
- **The dev rabbit broker runs locally** (`gw-dev-rabbit` container; MQTT `localhost:1885`, TLS
  off). The Rabbit MQTT plugin turns topic dots into slashes; payloads are intact.
- **Version bumps owe upgrade functions — the sema prep should make this loud.** This pass
  bumped many component versions (`ComponentGt`/electric.meter/gw108.* → v002, etc.). Each new
  version owes a correct old→new `upgrade()`, and — exactly like the axiom validators — these are
  easy to leave as stubs. The snapshot's `decode-old → upgrade() → decode-current` leg is what
  exercises them, but the gwta seed used **latest-only** (`{}`), so that leg never ran. Whenever
  a consumer (gwta, the LTN) receives an **older-version** instance off the wire, a stub/wrong
  upgrade fails the decode. So `sema snapshot prepare` (and the per-word ritual) ought to surface
  "you bumped a version → implement/verify its upgrade()" as plainly as it surfaces the example
  gap. **Owed:** audit the upgrade functions for every version bumped this pass.

## What's landed

**Sema (merged via PR #27 into `jm/sim-vocab`):**
- `2d55705`, `0cd2175` — `gw1.device.type` enum; every cac-carrying component bumped to drop
  `ComponentAttributeClassId` / carry `DeviceType`; draft `*.device.type.gt` records; CACs
  frozen + `replaced_by`; `gw.nolan.layout` rebound + `DeviceTypeMembership` axiom; `layout.lite/015`.
- `abc369f` — `pico.flow`/`pico.btu` `FlowMeterType` moved to `formats/pascal.case` (in place, v001).
- `64bce72` — dfr + ads gap-fill (`dfr.config`/`dfr.component.gt`, `ads.channel.config` with
  `ThermistorDeviceType`/`ads111x.based.component.gt`, `thermistor.data.method`).
- `b7d2cae` — the Hubitat pair (`maker.api.attribute.gt`, `hubitat.gt`, `hubitat.poller.gt`, +
  the two component shells). MakerAPI URL/REST machinery is computed helpers, not serialized.
- `a8a7f25` — 6 axiom validators implemented + examples on 25 schemas (snapshot round-trips all 27).

**Scada (`jm/delete-cac-id`):**
- `b0f03292` + `b358a676` (to squash) — the cac→DeviceType migration: `ComponentGt` → `DeviceType`
  (v002); `ComponentAttributeClassGt` → device-type-record base; resolution joins by `DeviceType`
  (records optional); `layout_db` + 12 generators on `Gw1DeviceType`; `CACS_BY_MAKE_MODEL` dropped.
- `b23b07af` — `make_model` removed from gwsproto; relay `AsyncCaptureDelta`; `names/simple_sim/`.
- `609e098f` — Hubitat components declare `Version 000` (the round-trip fix).
- `b7a6e5a3` — gwsproto docstrings: MakerAPI helpers stay app-code.

**gridworks-terminalasset (`jm/ta-sema-snapshot`):**
- `b264c6a` — the sema snapshot at `src/gwta/sema` (all 27 types decode via `gwta.sema`).

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
sema layout word"), not here. The durable principle it rests on — *the layout encodes the plant's
sense/control surface; the scada protocols share + disambiguate, grounded in the thermal-storage
heat-pump domain; three diverse layouts are the forcing function* — lives in
`executor/hardware-layout.md` ("The three layout families"), which now also carries the durable
intent for the house0 / nolan / simple_sim builders, the `temp`/`set`/`heat-call` zone invariant,
and the per-layout heat-call detection mechanisms. What **this** pass owes that work is the
migrated, flat **component vocabulary** (including the sim components) the layout is built from.

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
`*.component.gt` types; four were missing from sema. **dfr + ads + Hubitat all done** — the
component gap-fill is complete. `near5` deliberately not added as a format (`OpenVoltageByAds`
is a bare number array).

## Why its own issue / dependents

A sizeable chunk depended on by **two** larger designs becomes its own flat issue (per the
shared-dependency rule), referenced by name from each — keeping Linear flat and the work
explainable. Dependents:
- **simulated-test-environment** — Phase A needs the new component shape to stand up the sim
  layout; the device-type model lives here. The gwta sema snapshot (now landed) is what the
  terminalasset side decodes against.
- **spruce-unlimbo Chunk B** — the `layout_gen` restructuring + the merge gate "layout
  generation green for both the `house0` and Spruce layouts."
- **The gwbase'd LTN** — will want the same shared sema hardware layout. The more nodes that
  read the layout, the more "fix the contract once, now" amortizes.

It is also the "critical pass" `executor/hardware-layout.md` already anticipated.
