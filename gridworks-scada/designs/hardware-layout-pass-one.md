# Hardware layout — pass one

Status: Accepted · Pass 1 · Updated 2026-06-15 · Linear: OPS-407

**EDD: yes** the verification that matters is the focused layout round-trip: gridworks-terminalasset
SENDS a layout (built through its sema snapshot) → scada RETURNS it (decoded + re-encoded through
gwsproto) → gwta confirms it is unchanged (`gridworks-terminalasset/layout_roundtrip.py` +
`gridworks-scada/gw_spaceheat/layout_roundtrip_return.py`). (In-suite `layout_gen`-green for both
real fixture layouts is the sub-gate; a broker-transport round-trip is a later, fuller form.)

> What this is: the first critical pass on the scada hardware-layout / components model — drop
> UUID `cac_id`s for a readable `gw1.device.type` `DeviceType`, simplify components, restructure
> `layout_gen`, fill the sema vocabulary against real layouts. A **shared dependency**
> (simulated-test-environment + spruce-unlimbo Chunk B), its own flat issue OPS-407.

## Orient (read this, not the history)

**Done:** the device-type model (`cac_id` → open `pascal.case` `DeviceType`); the full migrated
sema **component** vocabulary (dfr / ads / Hubitat / sim / gw108 / pico / electric-meter / …);
`g.node.gt`; and the scada↔gwta **component** round-trip — every component + node: gwsproto emits →
gwta's sema snapshot decodes (27/27). `gw.nolan.layout` is un-drafted (axioms parked in its
`stash_axioms.md`).

**Where to look** (don't mine this doc for the play-by-play):
- **Changelogs** — the commit-by-commit story: `wiki/{sema, gridworks-scada,
  gridworks-terminalasset}/changelog.md`.
- **`executor/hardware-layout.md`** — the durable spec: the device-type model **and** "The three
  layout families" (the builders, the `temp`/`set`/`heat-call` zone invariant, the per-layout
  sensor + heat-call mechanisms, and required-vs-optional being the *layout's* call).
- **The code you'll refactor (read to prepare):** `gw_spaceheat/layout_gen/` — `layout_db.py`
  (the `LayoutDb` + `add_stubs`) and the per-device builders (`relay`, `dfr`, `multi`, `flow`,
  `btu`, `egauge`, `gw108_nolan_zones`, `tank3`, `derived_channels`); and the loaded data classes
  `packages/gridworks-scada-protocol/src/gwsproto/data_classes/{hardware_layout.py,
  house_0_layout.py}` — the load pipeline + the structural validations the sema layout axioms
  mirror. **The device-type model below is the lens for that refactor** — read it first.

**Device-type model in one breath:** a component carries an open `pascal.case` `DeviceType` (a
`gw1.device.type` value) and no `cac_id`; the *layout type* enforces enum membership; specialized
`<family>.device.type.gt` records exist only where a category carries real data.

## ▶ DO THIS NEXT — build up `gw.house0.layout` bit by bit (Sema is the source)

**Sema is the source of truth for all three mutating layout types** (`gw.nolan.layout`,
`gw.house0.layout`, `gw1.simple.sim.layout`). The working loop is:

1. **Edit the layout type in Sema** (definition yaml + registry; `build_indexes.sh` +
   `regenerate_runtime.py`; `pytest` green).
2. **Snapshot to gwta** — `uv run sema snapshot prepare gwta_seed_request.yaml` +
   `build --package-name gwta`, then copy `output/sema/*` into
   `gridworks-terminalasset/src/gwta/sema/` (gwta round-trip green).
3. **Hand-change the gwsproto class** in scada to match (`named_types/`).
4. **Test against the round-trip script** — `gridworks-terminalasset/layout_roundtrip.py`
   (gwta SENDS a layout → scada RETURNS it → gwta verifies unchanged), paired with
   `gridworks-scada/gw_spaceheat/layout_roundtrip_return.py`.

Rinse/repeat. (This supersedes the earlier "gwsproto is the authority, sema not in the loop"
plan — Sema stays the source for the layout types.)

**Baseline DONE:** all three layout types run through the whole loop. Local class names are short —
`House0Layout`, `SimpleSimLayout`, `NolanLayout` (set via the snapshot `local_names.yaml`; the
reusable `sema/build_gwta_snapshot.sh` does prepare → remap → build → copy-to-gwta). The round-trip
script (`gridworks-terminalasset/layout_roundtrip.py` + `gw_spaceheat/layout_roundtrip_return.py`)
is green for house0 + simple.sim.

**House0 shape laid out:** `gw.house0.layout/000` now carries the full property set mirroring
`gw.nolan.layout` (new DeviceType model) — GNodes, ShNodes, DataChannels, DerivedChannels,
`Components` oneOf (the House0 set: eGauge `electric.meter`, `ads111x.based` TSnap, Krida
`i2c.multichannel.dt.relay`, `dfr`, `pico.flow.module`, `pico.tank.module` + `sim.pico.tank.module`,
`hubitat.component` + `hubitat.poller.component`, `web.server`), DeviceTypes oneOf, and a freeform
Hydronic block. **Optional-first** — only `TypeName`+`Version` required at v000 so the round-trip
stays green while collections fill in. gwsproto `House0Layout` mirrors it (DeviceTypes uses the
`ComponentAttributeClassGt` stand-in, like the Nolan scaffold).

**Next — parallel sema layout_gen + a data-class→sema adapter:** rather than rewrite the existing
data-class `layout_gen` in place, build a **parallel structure** that emits the sema layout types
(`House0Layout` etc.), and a **map** `House0Layout (data_classes loaded object) → House0Layout
(sema type)`. The adapter *populates* the sema layout from a real already-working loaded layout
(e.g. a beech-single-zone fixture — richer than the current sim-only fixture) instead of
hand-authoring it, and feeds it straight into the round-trip. The existing in-place generator stays
green throughout.

**Bijection EDD result (`gw_spaceheat/house0_bijection.py`) — CLOSED:** the `dc → sema → dc` harness
proves the loaded House0 layout encodes into the sema `House0Layout` **cleanly for all 7 categories**
— GNodes (3), ShNodes (47), DataChannels (35), DerivedChannels (8), Components (8), DeviceTypes (7),
Hydronic config (all 8 keys) — the inverse reloads via `load_dict`, and the GNode round-trip is
identical. Closing it required **promoting the layout's GNodes to `g.node.gt`**: `layout_db.py`
emission + both fixtures now carry `g.node.gt`-shaped GNode entries (`BaseClass` + `GNodeClass`
aligned per axiom 1; `GNodeStatus → Status`; `PositionPointId` for the non-Logical LTN/TA per axiom
2; Scada is `BaseClass: Logical`; legacy `AtomicTNode → LeafTransactiveNode`). The `g_node_alias` /
`_id` accessors read `Alias`/`GNodeId` and were untouched. Scada suite green (114).

**The goal for `gw.house0.layout`:** carry, as **sema axioms**, the structural invariants currently
enforced in `gwsproto/data_classes/house_0_layout.py` (and the base `hardware_layout.py`) —
required topology nodes, tank/zone structure, power-metering + relay rules, the system-model energy
channels, the tank-temp-calibration derived channels, the sieg-manifold rules, handle/ID
integrity. Building up the type = porting those validations into axioms (and tightening optional →
required toward `gw.nolan.layout` parity), each slice run through the loop, off what the adapter
emits.

**Deferred — the names sweep (after the parallel structures land):** all `house_0_names` `H0N` /
`H0CN` references across the code (~61 files) SHALL be replaced with the new per-domain names in
`gwsproto/names/` (`core` / `house0` / `hydronic_spaceheat` / `simple_sim` / `nolan`
`node_names` + `channel_names`). Sequenced **after** the parallel sema `layout_gen` + adapter are in
place, as a single replacement sweep.

**The ConfigList revamp IS pulled forward** into this work — a single `channel.config` shape with
`TelemetryName → gw1.unit` + `gw1.quantity`. The earlier "defer it" was gated on having a harness
to validate a `TelemetryName`-everywhere change; the round-trip + sim layout being built here *is*
that harness, so it folds into the loop above (it touches the layout types, the data classes, and
`layout_gen` alike).

Immutability this session = pushed-to-GitHub (unpushed sema words are mutable in place).

**Owed within the layout work:** the `DeviceTypeRecordAlignment` axiom (a component's specialized
record must be the right family for its `DeviceType`) is not yet on any layout.

## Gleanings — domain context (durable)

> **Naming — Nolan ↔ Spruce (keep both; not PII):** the gw108 house is **Nolan** in code and sema
> (`gw.nolan.layout`, Strategy `"Nolan"`, `gw108_nolan_zones.py`) and **Spruce** colloquially —
> next in the tree-name series (beech, elm, oak, fir, maple → spruce). Same house. Ms. Nolan was a
> Millinocket widow in the original house; Matt Polstein bought the property, let her stay through
> her passing, then built the Nolan house — an honored legacy, not a name to scrub.

**Field reality:**
- The first five homes run the **House0** layout: **beech, elm, oak, fir, maple** — electronics
  hand-made by George, not gw108. Common: three store tanks + a buffer; Hubitat hubs driving
  Honeywell thermostats; varied heat pumps. **Siegenthaler loops on beech and maple** (a mechanical
  variation, not a software distinction).
- **Spruce is a one-off:** gw108 electronics, plain radiant floor. The next ~12 new-builds use
  store-under-floor, so Spruce's specifics shouldn't be over-generalized.

So House0 is the **fleet** layout (5 homes, one hardware generation, ~47 ShNodes: Hubitat/Honeywell,
dual Krida I2C relays, DFRobot DACs); Spruce is a **single experimental** gw108 layout (~30
ShNodes). That asymmetry is why house0 earns its own `gw.house0.layout` word.

**Simulated tanks + the simple-sim layout (next phase):**
- `sim.pico.tank.module.component.gt` exists to **unit-test the `api_tank_module.py` actor** — it
  reports the same channels as a real `PicoTankModule3` but its `DeviceType` marks it as a sim
  sensor. The simple-sim layout MAY use it or not. (The nolan/house0 *fixture* layouts use it for
  buffer + tank1; rebuilt new-model in `layout_gen/simulated_tanks.py`.)
- **Nolan has exactly 1 storage tank** (buffer + tank1). The **simple sim is the same — 1 storage
  tank**, and its storage tank is **360 gallons**.
- **Tank gallons are articulated fragilely right now** — firm this up when building the simple-sim
  layout rather than carrying the fragile path forward.

**gwsproto versioning:** scada carries **one version per type at a time** — the current version
*replaces* the prior one (no retained `XxxNNN` old-version classes the way sema keeps them). Test
fixtures track the single live version.

**House0 build-up reference (gleaned from `tlayouts/gen_{beech,oak,elm,fir,maple}.py` + the
`gwsproto/data_classes` loaders):** common to all five — 1 eGauge power meter (HP ODU/IDU + 3 pumps
+ boiler), 1 TSnap ADS111x multipurpose sensor (dist/hp/store/buffer pipe temps; some homes add zone
air temp + OAT), 1 dual Krida I2C relay bank (iso-valve / charge-discharge / hp-failsafe /
hp-scada-ops / aquastat), 3 pico flow meters (primary/dist/store), buffer + 3 store tanks, Hubitat
hub driving Honeywell thermostat pollers (one per zone). **Varies:** zone count (beech 2, maple 2,
oak 4, elm 4, fir 4) and per-zone kWh/°F weights; FlowManifoldVariant (`House0Sieg` on beech, plain
`House0` elsewhere — sieg also on maple mechanically); OAT/zone-air-temp presence; flow-meter
hardware (pico-hall vs I2C). **Caveat:** the deployed `*.uploaded.json` are *pre-migration* (old
cac / enum-symbol serialization) — mine them for the *what* (families, channels, counts), not the
*how*; the new-model `gw.nolan.layout` is the structural template. The current-code authority for
required structure is the House0 validations in `data_classes/house_0_layout.py` (required topology
nodes, tank/zone structure, system-model energy channels, sieg-manifold rules).

## TODO — Siegenthaler variants + `primary-flow` (real vs derived); EDD on all 3

The House0 code must work across **three Siegenthaler configurations**, and the EDD
fixtures must cover all three:

1. **No loop** — `FlowManifoldVariant.House0`, `use_sieg_loop=False` (oak, elm, fir).
2. **Loop present, sieg code NOT running** — `FlowManifoldVariant.House0Sieg`,
   `use_sieg_loop=False` (beech): the plumbing has the loop but the scada doesn't
   actively control it (no SiegLoop/HpBoss actors).
3. **Loop AND running sieg** — `FlowManifoldVariant.House0Sieg`, `use_sieg_loop=True`
   (maple): SiegLoop + HpBoss actors active.

**`primary-flow` differs by config and must work in each:**
- **measured (DataChannel)** — beech: `primary-flow` comes straight from the
  `primary-btu` BTU meter; no derivation.
- **derived (sum)** — maple: `primary-flow = sieg-send + sieg-flow`. dev modelled this
  as a derived channel `DerivedChConfig(Name="primary-flow", Strategy="sum",
  OutputUnit=GpmX100)` over the sieg-loop inputs (`sieg-send` flow sensor +
  `sieg-btu`→`sieg-flow`). The old `hack_maple_primary_flow` did the sum imperatively;
  it was removed (already dead — `process_synced_readings` is never dispatched), so
  **maple's primary-flow is currently NOT computed** — a real gap.

**Missing: the physical-topology choice is implicit and belongs in the layout type.**
Whether `primary-flow` is measured or derived is determined by a **real physical
topology choice — is there a flow meter at/next to the primary pump?** (beech: yes →
measured; maple: no → derived from the sieg loop). Today that choice exists only
*implicitly* in which builders a gen script calls (`add_btu(primary-btu)` /
`add_flow(primary_flow)` vs not). Because it is physical topology, it SHALL be
represented **explicitly in `gw.house0.layout`** (and the Hydronic/topology block) —
not inferred from channel presence — so the layout itself states the flow-meter
topology and the measured-vs-derived primary-flow follows from it. Same logic
generalizes to the other flow positions (dist, store) where a meter may or may not be
physically present.

**Work to do:**
- **Encode the flow-meter topology in `gw.house0.layout`** (the primary-pump flow
  meter present/absent choice, and the analogous dist/store positions) as an explicit
  physical-topology field, since it drives measured-vs-derived flow channels.
- Implement a **`sum` derived-channel strategy** in the active path
  (`handle_input_reading → _dispatch_derived_input`): `dc.Name = Σ InputChannelNames`
  (fresh payload + cached latest of the others), emitting in `OutputUnit` — replacing
  the removed hack, no per-house special-casing.
- Make the gen builders **sieg-variant-aware** so a layout expresses "primary-flow is
  measured" vs "primary-flow is the `sum` derived channel" by config, not by hand;
  set `gen_maple.py` to config (3) and confirm beech is config (2).
- **EDD via a simulated plant:** build *enough of a simulated plant* to run against the
  House0 layout and confirm the calculations BASICALLY WORK on all three configs —
  in particular feeding the real + derived flow channels (`primary-flow`,
  `sieg-send`, `sieg-flow`, `dist-flow`, `store-flow`) and checking the derived
  results (the `sum`, the BTU-derived flows) are sensible. This is the verification
  bar for the sieg-flow work.
