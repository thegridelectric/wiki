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

## Orient

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

**▶▶ Start here (immediate next slice): Siegenthaler-loop variants in House0, end-to-end to
`derived_generator`.** Structure **decided 2026-06-15** — the `FlowTopology` block (details + the
three configs + the source⟶channel axiom in the **"TODO — Siegenthaler variants + `primary-flow`"**
section at the bottom). The behavior test is a **deferred deliverable** (it needs the simulated
plant — the *next* focus); see "DELIVERABLE — `primary-flow` behavior test" at the bottom. The
implementable chain this pass:

1. **Layout type** — add the `FlowTopology` block to `gw.house0.layout` (`SiegLoopPlumbed` replacing
   `FlowManifoldVariant`; new `PrimaryFlowSource: Measured | DerivedSiegSum`; the source⟶channel
   axiom), through the sema → gwta → gwsproto loop; keep the gwsproto `flow_manifold_variant`
   computed property; confirm the **layout round-trip** stays green (runnable now).
2. **Gen builders** — make them sieg-variant-aware (no-loop / loop-not-running / loop-running) so the
   layout states the topology rather than it being implicit in which builders are called; set
   `gen_maple.py` to the loop-running config.
3. **`derived_generator`** — implement a **`sum` derived-channel strategy** in the active path
   (`handle_input_reading → _dispatch_derived_input`) so maple's `primary-flow = sieg-send + sieg-flow`
   is actually computed (it is **currently uncomputed** — the old `hack_maple_primary_flow` was
   removed). Code it this pass; *verify* it via the deferred deliverable.
4. **Behavior test — DEFERRED.** Left well-specified as a deliverable for the simulated-plant focus;
   do **not** build it this pass.

(Parked, separate: the axiom-enforcement loop is **WIP** — sema commit `3422ca9` embedded a beech
example + 4 axioms in `gw.house0.layout/000`; the sema **snapshot build is blocked** until the
bijection adapter serializes the poller `by_alias`. Resume after the sieg work, or instead, per
Jessica.) Everything below is the working method + the state already in place.

**Session status (2026-06-15):** the **typed-hydronic promotion** landed (sema `32540ef` + a
follow-up example-conformance commit) and the **scada↔gwta layout round-trip is green** for
`gw.house0.layout` + `gw1.simple.sim.layout`. The freeform `Hydronic` block became three new sema
words — `gw1.hvac.zone` (shared zone type, list-of-objects, killing the parallel-list axioms),
`gw.house0.primary.flow.source` (enum: `Measured` | `DerivedSiegSum`), and `gw.house0.hydronic`
(typed: `Zones`, `TotalStoreTanks`, `UseSiegLoop`, `SiegLoopPlumbed` [was `FlowManifoldVariant`],
`PrimaryFlowSource`, `Strategy`; axiom `UseSiegLoop ⟹ SiegLoopPlumbed`) — with `gw.house0.layout.Hydronic`
now a `$ref`. Per sema's spec the now-known shape belongs in the schema, not a freeform object +
hand-axioms. Getting the gwta snapshot to build also forced the `gw.house0.layout` **example** fully
conformant (poller PascalCase, real `DeviceTypes` records, `derived.channel.gt → 002`). The
measured-vs-derived `primary-flow` topology is now **explicit + axiom-tied**. `gw1.hvac.zone` is
shared so Nolan adopts it when its hydronic is promoted. **Still pending** (the behavior, not the
structure): the `sum` derived-channel strategy + sieg-variant-aware gen, verified by the **deferred**
simulated-plant behavior test — which depends on the sim-actor self-faking capability (next focus).
The earlier **v001 tank-calibration migration + stored-map retire** also landed green (sema `efeafc0`,
scada `5e6008df`); calibration lives only in the derived channels
(`linear.one.dimensional.calibration/001`, integer B in FahrenheitX100). See the changelogs.

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

**Read first:** `executor/components.md` §"What belongs in the hardware layout — and
what doesn't" (the topology field is hardware truth → belongs; per-instance
calibration is component-level → why it lives in the derived channel), and
`executor/testing.md` §"The harness" (`ScadaLiveTest`, the in-process LTN↔SCADA
harness the unit test extends — *test*, not the broker experiment in
`experimentation-rig.md`).

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

**Decided structure (2026-06-15): a coherent `FlowTopology` block in `Hydronic`.**
Three distinct facts are in play, and today the layout represents only two of them —
one of which is arguably misfiled:

1. **Is the sieg loop *plumbed*?** — hardware truth. Today: `FlowManifoldVariant`
   (`House0` / `House0Sieg`).
2. **Does scada *control* the loop?** — operational/strategy (spawns `HpBoss` +
   `SiegLoop`). Today: `UseSiegLoop: bool`, read at ~12 `self.layout.use_sieg_loop`
   sites.
3. **Where does `primary-flow` come from?** — hardware truth. Today: **unrepresented**,
   implicit in which gen builders run (`add_btu(primary-btu)` / `add_flow(primary_flow)`
   vs not).

Fact 3 is **independent** of Facts 1–2: beech and maple are *both* `House0Sieg`-plumbed
yet beech measures `primary-flow` (from `primary-btu`) while maple derives it. So the
measured-vs-derived choice is driven by **"is there a flow meter at the primary
pump?"**, not by "is there a sieg loop." That physical fact has no home today.

The structure (altitude chosen 2026-06-15: *coherent topology block*, keeping the
operational `UseSiegLoop` where the actors read it for now — Fact 2 stays put; a later
pass MAY pull it into the strategy home per `executor/components.md` "operational
policy arguably doesn't belong in the layout"):

```
Hydronic:
  FlowTopology:                       # NEW named block — the physical flow truth
    SiegLoopPlumbed: bool             # was FlowManifoldVariant (House0Sieg ⟺ true)
    PrimaryFlowSource: Measured | DerivedSiegSum   # NEW — was implicit in builders
    # DistFlowSource / StoreFlowSource added the same way when those positions vary
  UseSiegLoop: bool                   # UNCHANGED — Fact 2 (operations), actors read it
  Strategy: House0                    # unchanged
```

- `SiegLoopPlumbed` **replaces** `FlowManifoldVariant` in the layout type. gwsproto keeps
  a computed `flow_manifold_variant` property (`House0Sieg` if plumbed else `House0`) so
  the two read sites — `check_house0_sieg_manifold` and the manifold `Strategy` at
  `scada.py:1728` — keep working untouched. The existing invariant
  ("`UseSiegLoop ⟹ House0Sieg`") becomes "`UseSiegLoop ⟹ SiegLoopPlumbed`".
- `PrimaryFlowSource` is the **cause**; the channels are the **effect**. Do NOT duplicate
  the strategy mechanics here — the `sum` inputs already live on the `primary-flow`
  `DerivedChannel` (`Strategy=sum`, `InputChannelNames=[sieg-send, sieg-flow]`). A new
  **axiom** ties them: `Measured ⟹ primary-flow is a DataChannel captured by a flow/btu
  node`; `DerivedSiegSum ⟹ primary-flow is a sum DerivedChannel over the sieg-loop
  inputs`. The layout states the topology; the channel set must agree with it.
- Same shape generalizes to `dist` / `store` later — add `DistFlowSource` /
  `StoreFlowSource` when a position actually varies, not pre-emptively.

**Config map under the new structure:**

| home | `SiegLoopPlumbed` | `UseSiegLoop` | `PrimaryFlowSource` |
|------|---|---|---|
| oak/elm/fir | false | false | Measured |
| beech | true | false | Measured |
| maple | true | true | DerivedSiegSum |

**Work to do:**
- **Encode `FlowTopology` in `gw.house0.layout`** through the sema → gwta → gwsproto loop
  (replace `FlowManifoldVariant` with `SiegLoopPlumbed`; add `PrimaryFlowSource`; add the
  source⟶channel axiom; keep the gwsproto `flow_manifold_variant` computed property), and
  confirm the **layout round-trip** stays green (`layout_roundtrip.py` — runnable now;
  this is *not* the blocked behavior test).
- Implement a **`sum` derived-channel strategy** in the active path
  (`handle_input_reading → _dispatch_derived_input`): `dc.Name = Σ InputChannelNames`
  (fresh payload + cached latest of the others), emitting in `OutputUnit` — replacing
  the removed hack, no per-house special-casing.
- Make the gen builders **sieg-variant-aware** so a layout expresses "primary-flow is
  measured" vs "primary-flow is the `sum` derived channel" by config, not by hand;
  set `gen_maple.py` to config (3) and confirm beech is config (2).
- **Behavior test (the EDD bar) — DEFERRED, see the deliverable below.** The real
  verification is a focused behavior test against all three sieg configs. It needs a
  **simulated plant**, which is the *next* focus — so it is **NOT built this pass**. It
  is left as a **well-specified deliverable** (next subsection) to be executed once the
  simulated-plant harness lands. (The `sum` strategy code itself can be written this
  pass; what cannot be done now is *verifying* it end-to-end.)

### DELIVERABLE — `primary-flow` behavior test (build when the simulated plant lands)

This is the EDD bar for the `sum`/topology work, **deferred** to the simulated-plant
focus (we cannot really test it before then). Hand it off as written; it is
self-contained. The harness drives **BTU meters** (`api_btu_meter`) + a `sieg-send`
flow sensor into `derived_generator` and checks the emitted readings. It rides on
`ScadaLiveTest` (`tests/utils/scada_live_test_helper.py`) — the in-process LTN↔SCADA
tree, no broker (see `executor/testing.md` "The harness"); the *simulated plant* is the
device-reading source that feeds it.

**The three configs under test (all three MUST pass):**

| # | config | `SiegLoopPlumbed` / `UseSiegLoop` | `primary-flow` source | what to assert |
|---|--------|------|------|------|
| 1 | no loop (oak/elm/fir) | false / false | Measured (own meter) | `primary-flow` DataChannel arrives intact; no derivation runs |
| 2 | loop, not controlled (beech) | true / false | Measured (`primary-btu`) | `primary-btu` meter emits `primary-flow` directly as a DataChannel — arrives intact |
| 3 | loop, controlled (maple) | true / true | DerivedSiegSum | `sieg-btu`→`sieg-flow` + `sieg-send` sensor→`sieg-send`; the `sum` strategy emits `primary-flow = sieg-send + sieg-flow` |

**Per-config recipe (config 3, the load-bearing one):**
1. Load the maple-shaped House0 layout (`SiegLoopPlumbed=true`, `UseSiegLoop=true`,
   `PrimaryFlowSource=DerivedSiegSum`); confirm `primary-flow` is present as a `sum`
   `DerivedChannel` with `InputChannelNames=[sieg-send, sieg-flow]`, `OutputUnit=GpmX100`,
   and is **absent** from DataChannels (axiom check).
2. Feed `sieg-btu` a reading → it emits `sieg-flow` (GpmX100). Feed the `sieg-send` flow
   sensor a reading → `sieg-send` (GpmX100).
3. Assert `derived_generator` emits a `primary-flow` reading whose value is
   `sieg-send + sieg-flow` (in GpmX100), with a sensible `ScadaReadTimeUnixMs`.
4. Edge cases: only one input seen yet → no emission (or a defined partial behavior —
   pin it down when implementing the strategy); both stale vs one-fresh-one-cached → uses
   the cached latest of the other (`self.data.latest_channel_values`).

**Also exercise the affine tank-calibration path (currently unverified end-to-end).**
The same harness should feed `api_tank_module` device readings (`*-depth{n}-device`,
WaterTempCTimes1000) through `handle_affine` and assert the calibrated `*-depth{n}`
(FahrenheitX100) equals `M*x + B` for a **non-zero B**. The scada suite has only ever run
`B=0` (identity), so the v001 `affine` math has no test yet — this closes that gap.

**Compliance tests WAIT for the data-classes → sema-types transition.** Making
`config/house0-layout.json` a fully-compliant fictitious single-zone House0 (+
maple/beech compliance tests) should wait: "fully compliant" is defined by the axioms
being lifted into sema, plus the new `FlowTopology` field and the three configs, so
writing the compliance assertions now chases a moving target. The layout *fixtures* are
durable and fine to shape now; the *assertions* follow the sema authority.
