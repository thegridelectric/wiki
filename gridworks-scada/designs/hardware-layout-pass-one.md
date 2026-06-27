# Hardware layout — pass one

Status: Accepted · Pass 1 · Updated 2026-06-26 · Linear: OPS-407

**EDD: yes** the verification that matters is the focused layout round-trip, scada-originated from a
real layout: scada loads a dc layout (e.g. `tests/config/maple.json`) → converts it to the
`gw.house0.layout` sema type (the house0 bijection) → SENDS it to gwta → gwta RETURNS it decoded +
re-encoded through its sema snapshot → scada confirms it is unchanged
(`gridworks-scada/gw_spaceheat/layout_roundtrip.py` drives;
`gridworks-terminalasset/layout_roundtrip_return.py` returns). (In-suite `layout_gen`-green for both
real fixture layouts is the sub-gate; a broker-transport round-trip is a later, fuller form.)

> What this is: the first critical pass on the scada hardware-layout / components model — drop
> UUID `cac_id`s for a readable `gw1.device.type` `DeviceType`, simplify components, restructure
> `layout_gen`, fill the sema vocabulary against real layouts. A **shared dependency**
> (simulated-test-environment + spruce-unlimbo Chunk B), its own flat issue [OPS-407](https://linear.app/gridworks/issue/OPS-407).

## Orient

**Done:** the device-type model (`cac_id` → open `pascal.case` `DeviceType`); the full migrated
sema **component** vocabulary (dfr / ads / Hubitat / sim / gw108 / pico / electric-meter / …);
`g.node.gt`; the typed-hydronic promotion (`gw1.hvac.zone`, `gw.house0.primary.flow.source`,
`gw.house0.hydronic`); the scada↔gwta **component** round-trip (27/27); and the scada↔gwta
**full-layout** round-trip — **all five House0 fleet layouts** (maple, beech, elm, oak, fir) survive
`dc → sema → gwta → scada` unchanged (`gw_spaceheat/layout_roundtrip.py`, real `*.device.type.gt`
records in the fixtures, `dc_to_sema` reading `dc.device_types`). The commit-by-commit story is in
the changelogs (`wiki/{sema, gridworks-scada, gridworks-terminalasset}/changelog.md`); the durable
distillate is in [`executor/hardware-layout.md`](../executor/hardware-layout.md). `gw.nolan.layout`
is un-drafted (axioms parked in its `stash_axioms.md`).

**Where to look** (don't mine this doc for the play-by-play):
- **Changelogs** — the commit-by-commit story.
- **`executor/hardware-layout.md`** — the durable spec: the device-type model **and** "The three
  layout families" (the builders, the `temp`/`set`/`heat-call` zone invariant, the per-layout
  sensor + heat-call mechanisms, and required-vs-optional being the *layout's* call).
- **The code:** `gw_spaceheat/layout_gen/` — `layout_db.py` (`LayoutDb` + `add_stubs`) and the
  per-device builders (`relay`, `dfr`, `multi`, `flow`, `btu`, `egauge`, `gw108_nolan_zones`,
  `tank3`, `derived_channels`); the loaded data classes
  `packages/gridworks-scada-protocol/src/gwsproto/data_classes/{hardware_layout.py, house_0_layout.py}`
  (the load pipeline + the structural validations the sema axioms mirror); and the new per-domain
  names hierarchy `gwsproto/names/` (`core` / `house0` / `hydronic_spaceheat` / `simple_sim` /
  `nolan`). `data_classes/device_types/gw1_scada_gw108.py` holds how the gw108 board is wired + how
  to flesh out the Nolan relay structure.

**Device-type model in one breath:** a component carries an open `pascal.case` `DeviceType` (a
`gw1.device.type` value) and no `cac_id`; the *layout type* enforces enum membership; specialized
`<family>.device.type.gt` records exist only where a category carries real data.

## Migration strategy — sema-first, translate, migrate last

The big in-code migration (every actor/accessor off the dc data-classes onto sema types, the ~76
call-site reference sweep, the `names/` sweep) is **deferred behind** two cheaper phases that de-risk
it. The point: find every vocabulary/axiom gap against the **real fleet** before touching call-sites.

- **Phase 1 — generate every existing layout as sema.** The sema-native gen (`house0_sema_gen`)
  produces each fleet home (beech, oak, elm, fir, maple) as a `gw.house0.layout` and nolan as
  `gw.nolan.layout`, each from a per-home config — the `tlayouts/gen_<house>_sema.py` scripts mirroring
  the old `gen_<house>.py`. Two things get proven the stub can't: the **axioms hold on all six real
  homes**, and `sema_gen(config) == dc_to_sema(load(old_gen(config)))` (content+id equal) per home. Gaps
  surface here — exactly how the bare stub exposed the missing `whitewire-pwr` / `heat-call` channels.
- **Phase 2 — translate, don't migrate.** The dc↔sema bijection is the translation layer: the running
  scada keeps loading dc layouts, but the **sema layout is the authored, axiom-validated artifact** and
  round-trips through gwta. The fleet is fully expressible + checked as sema, with a working
  translation, *without* migrating the actor code.
- **Phase 3 — the full code migration (later).** `names/` sweep, actors/accessors onto sema types,
  retire the old dc gen. De-risked by Phase 1+2.

Task a (below) is the Phase-1 engine; Task b's axioms are what Phase 1 validates against the fleet.

**Pass one is done when:** (1) every bespoke fleet layout generates as sema (`gen_<house>_sema`),
axiom-valid and content+id-equal to its dc layout; (2) the House0 axiom slice (Task b) is complete with
counterexamples; (3) the dc↔sema round-trip is green fleet-wide (Phase 2). The **deep code clean is
deferred to pass two** — ripping out `H0N`/`H0CN` (~61 files), the ~76 call-sites onto
`self.hydronic.*`, the full actor migration onto sema types, retiring the old dc gen (Phase 3), and the
G/H RequiredTopologyNodes axioms (which need `H0N` gone). The `channel.config`/board-component shape
cleanup ([OPS-427](https://linear.app/gridworks/issue/OPS-427)) is **not** the deferred clean — it's done now, while those versions are unpublished.

## ▶ Tasks — in order

The sema gen comes first because it is the only clean way to author axiom counterexamples: proving an
axiom *catches* a violation means feeding sema a layout that breaks it, and the dc path can't produce
one — the dc loader's Python guards (`house_0_layout.py`, the `1 ≤ tanks ≤ 6` check, etc.) raise at
`House0Dc.load()` before the sema codec ever sees it. A sema-native gen emits `gw.house0.layout`
directly, so it can gen a violating layout straight to sema; it is the **fixture factory** for the
axiom tests.

- **▶ Task a (ACTIVE) — the sema-native layout gen.** Generate `gw.house0.layout` directly from
  config and validate `sema_gen(config) == dc_to_sema(load(old_dc_gen(config)))` for the fleet
  configs; then drive the scada ↔ gwta round-trip off a *generated* sema layout. Blueprint below.
  **In flight:** the gen + its diff harness landed —
  `gw_spaceheat/house0_sema_gen.py` (`sema_gen(config, reference)`, stable IDs pulled by name from a
  reference layout via `LayoutIDMap`) and `gw_spaceheat/house0_sema_gen_check.py` (diffs
  `sema_gen == dc_to_sema(load(reference))`; the printed diff IS the remaining-builders worklist —
  generate → observe gap → close it). First equivalence target is the **stub `house0-layout.json`**
  (the only config the old gen reproduces; real fleet jsons are frozen captures with no per-house gen),
  then build up to maple. **Skeleton emits & matches:** GNodes, Hydronic, the 14 system-actor nodes,
  the power-meter device-type/component/nodes/`*-pwr` channels. **Worklist (gap to close):** the relay
  bank (i2c multichannel relay component + relay nodes + relay-state channels), hubitat + poller +
  thermostat zone channels, the two sim tanks + buffer (`sim.pico.tank.module` components + depth nodes
  + device/micro-v channels), the dfr 010V component + channels, and the 8 DerivedChannels (energy +
  tank/buffer calibration). **Names-hierarchy bugs found & fixed along the way** (`gwsproto/names/`):
  `House0NodeNames.__init__` called `House0ZoneNodeNames(zone, idx+1)` (arity mismatch); and
  `HydronicSpaceheatNodeNames` had malformed SpaceheatNames `hp_idu`/`primary_flow`/`vdc_relay`
  (underscores → hyphens — all fixed; House0 overrides `vdc_relay` to `relay1` anyway, but the base
  hydronic value is now well-formed too). Also fixed `House0ChannelNames.store_flow` (was a
  copy-paste of `primary-flow`).

  **Decision (2026-06-16) — new naming conventions NOW, preserve existing UUIDs.** The new `names/`
  hierarchy deliberately diverges from old `H0N`/`H0CN`: the systematic House0 change is that
  **relay-state channels drop the trailing relay-index** (`vdc-relay1` → `vdc-relay`; the base is
  already unique). The gen emits the new (`names/`) convention; the frozen fixtures keep their old
  names but their **UUIDs carry over** — the gen indexes a reference layout's channel ids by their
  *stripped* (new) name (`strip_relay_idx`), so an emitted new name inherits the existing UUID (this is
  exactly the `LayoutIDMap` "maintain uuids from an existing layout" feature, extended across the
  rename). The diff harness applies the same rename to the comparison target. **Verified:** the gen's
  `vdc-relay` carries the fixture's `vdc-relay1` UUID. *On-disk* fixture migration (writing the new
  names into the JSONs) is a clean follow-on once the runtime names-sweep moves scada code off
  `H0CN`; until then the gen + harness handle it in-memory so nothing breaks at runtime.

  **Relay bank DONE & matching:** `emit_relays` emits the i2c Krida component (14 `relay.actor.config`
  in exact layout order, 12 before 11), the relay-multiplexer node, the 14 relay nodes, and the 14
  relay-state DataChannels — all new-convention, UUIDs preserved, zero content diff vs the target.
  **All builders DONE — full house0 equivalence reached:** `sema_gen(config) ==
  dc_to_sema(load(house0-layout.json))` byte-for-byte (47 nodes, 35 data channels, 8 derived channels,
  8 components), UUIDs preserved across the rename. Builders: power-meter, web-server, thermostat
  (hubitat + per-zone poller), relays, sim tanks (buffer + tank1), dfr 010V, and the 8 DerivedChannels
  (usable/required energy `system-model` + per-depth `identity` calibration). Enum gotchas worth noting:
  `DerivedChannelGt.OutputUnit` is `GwUnit` (not `Unit`) and `EmissionMethod` is its own enum; the
  hubitat `MacAddress` rides the sema `mac.address` format (lowercase-only — pydantic normalizes upstream
  at the gwsproto boundary, sema validates). **Note — final byte-equality needs exact list ORDER**
  (`got_d == target_d` is order-sensitive for every collection): emit components in target order
  (electric-meter, web-server, hubitat, poller, i2c-relay, sim-buffer, sim-tank1, dfr) and nodes in
  target order (… store-pump, hubitat, zone-stat, zone, relay-mux, relays, tanks, 010V).

  **Fleet extension IN FLIGHT — oak at 82/85 nodes, 76/82 channels.** The multi-zone parametrization
  carried for free (relays 19–24, per-zone thermostats). Done this push: ① ✅ **eGauge** (real
  `electric.meter` + `EgaugePowerMeter` device-type via a `power_meter_kind`/`PwrChannelSpec` config
  axis — modbus register map, pump/boiler/whitewire about-nodes, uppercase channel displays);
  ② ✅ **ADS analog-temp** (`ads111x.based` + `GridworksTsnap1ScadaBoard` device-type + `analog-temp`
  node via an `AdsChannelSpec` axis — the board's i2c map is an invariant constant, only HwUid /
  OpenVoltage / terminal-block channel-list vary per home). **Remaining for oak (3 pieces):**
  ③ **flow meters** — 3× `pico.flow.module` (dist/primary/store, with `FlowNodeName`) → flow nodes +
  `*-flow`/`*-flow-hz` channels; ④ **real `pico.tank.module`** vs the sim stub — a tank-kind config
  axis (buffer + 3 tanks); ⑤ **affine tank calibration** — oak's buffer/tank depths 1 & 3 are `affine`
  (Strategy `affine` + `linear.one.dimensional.calibration` M/B), depth 2 `identity`; the gen emits all
  `identity`, so per-depth calibration becomes config.

  **✅ oak PASSES — `GEN OK [oak]`, the full fleet builder set works.** A real 4-zone / 3-tank /
  no-sieg production home is now generated content+id-equal: eGauge (`PwrChannelSpec` register map),
  ADS analog-temp (`AdsChannelSpec`), Reed flow meters (`FlowSpec`), real `pico.tank.module` + affine
  depth calibration (`TankSpec` — depths 1&3 affine M·x+B, depth 2 identity), and multi-zone
  relays/thermostats. Bespoke-per-home config knobs surfaced: web-server `Port`, relay `I2cAddressList`,
  poller DisplayName uses the **zone index** (not the device id), and zone-label casing splits three
  ways (`zone.capitalize()` → "Living-rm" for node/relay displays; `base.replace('-',' ').title()` →
  "Zone1 Living Rm" for channel displays). Real-tank ConfigList orders all-devices-then-all-micro-v
  (sim interleaves). **Comparison is now order-INSENSITIVE** (`_canon` sorts each collection by a
  stable key before `==`): list position in a layout is just historical authoring/load order, not
  semantically meaningful, so the gen emits its own canonical order and a frozen fixture adopts it on
  migration — equivalence is content + id, not position.

  **Remaining fleet work:** elm + fir (same no-sieg shape — just each home's bespoke device-map config),
  then beech + maple (add the **sieg loop**: SiegLoopPlumbed/UseSiegLoop, the sieg manifold relays,
  the BTU meter + `DerivedSiegSum` primary-flow). Per-position
  flow/temp **sourcing** (BTU-meter | flow-meter+analog-temps | derived-sum) is the config axis these
  share; maple/beech additionally bring the **sieg loop** (deferred until the no-sieg homes pass).

  **Key insight from oak — the fleet is config-BESPOKE, not just invariant skeleton.** Unlike the sim
  stub, the real devices carry hand-specified per-home data the gen config must encode: the eGauge has a
  per-channel `EgaugeRegisterConfig` (unique modbus `Address` + register name) + `ModbusHost`/`HwUid`;
  the ADS carries its i2c/terminal map; flow meters + tank picos carry hardware UIDs; pwr channel
  display names are uppercase (`DIST PUMP PWR`); even invariant-looking nodes differ (`hp-odu` display
  "Hp Odu" on oak vs "HP ODU" on the stub). So the gen's config grows a **device-map** section per home
  (mirroring what the dc fixtures froze) — this is the real shape of the four config axes for production
  homes, and the reason there is no single per-house gen today. Implication: the config object, not just
  the builders, is the bulk of the fleet work; structure it as a per-home device map fed to generic
  emitters.

  **Closing step — migrate the OLD gen to the new names, then drop the harness bridge ("update the OLD
  gen too").** The harness's in-memory `_to_new_convention` rename of the comparison target is a
  *temporary bridge* only. The real end-state: update the dc-side `layout_gen` builders (`relay.py`'s
  relay-state channel names, and any other renamed channels) to emit the **new convention natively**
  (off `names/`, not `H0CN`), so `dc_to_sema(load(old_gen(config)))` produces new names directly. Then
  **remove `_to_new_convention`** and confirm `sema_gen(config) == dc_to_sema(load(old_gen(config)))`
  holds with **no rename** — that is the genuine equivalence. Until that lands, verify the old
  `layout_gen` (`genlayout mktest` / `test_layout_gen`) still produces a self-consistent layout under
  the new names (no dangling old-name references between its component ConfigLists and its DataChannels).
- **Task b (QUEUED) — finish the layout axioms.** Port the structural validations
  (`house_0_layout.py`) into sema axioms (House0 only this pass), keeping the round-trip green at each
  addition, **and** adding a generated counterexample test per axiom (via the Task-a gen) proving it
  fires. Slice list + EDD recipe below. **Already landed:** axiom A (Cardinality) on
  `gw.house0.hydronic/000` — `1 ≤ TotalStoreTanks ≤ 6`, `1 ≤ |Zones| ≤ 6` — round-trip-green for all
  five fleet layouts; its counterexample test waits on the Task-a gen.

### Task a — generator blueprint (the required-node/channel sets ARE the gen spec)

The `required_topology_nodes` + `required_system_actor_nodes` properties
(`house_0_layout.py:541–619`) are deferred as *axioms* to pass-2, but they are **essential design
input for the gen now**: once we know a layout is House0, those sets are exactly the invariant
skeleton the generator must emit. The gen builds them from the **new per-domain names hierarchy**
(`gwsproto/names/` — `core` + `hydronic_spaceheat` + `house0`), NOT `H0N`/`H0CN`. (`House0NodeNames`
already mirrors `H0N`: class constants composed from `CoreNodeNames`/`HydronicSpaceheatNodeNames`,
plus `__init__(total_store_tanks, zone_list)` building `.tanks`/`.zones`. `House0ChannelNames` mirrors
`H0CN` the same way.)

**The House0 skeleton the gen emits:**

- **System-actor nodes (invariant, 14):** `s`, `s2`, `power-meter`, `derived-generator`, `ltn`, `la`,
  `lc`, `lc-normal`/`lc-backup`/`lc-scada-blind`, `admin`, `auto`, `pico-cycler`, `hp-boss`.
- **Topology nodes (mostly invariant):** heat-pump (`hp-odu` always; **`hp-idu` is config-dependent**
  — maple is `hp-odu`-only and still House0); pumps (`dist`/`primary`/`store`); pipe temps
  (`dist-swt`/`dist-rwt`/`hp-lwt`/`hp-ewt`/`store-hot`/`store-cold`/`buffer-hot` — **not**
  `buffer-cold`); flows (`dist`/`primary`/`store`); the relay bank (`vdc`/`tstat-common`/
  `charge-discharge`/`hp-failsafe`/`hp-scada-ops`/`thermistor-common`/`aquastat-ctrl`/
  `store-pump-failsafe`/`primary-pump-scada-ops`/`primary-pump-failsafe`); the three 010V outputers;
  `buffer` depths.
- **Config-driven parts** (the four axes): `Zones` · `TotalStoreTanks` · sieg (plumbed? controlled?)
  · per-position flow/temp sourcing. Detailed below.

**Channels — the set is known; the gen's only real per-channel choices are two:** (1) **DataChannel
vs DerivedChannel**, and (2) **which node captures it** (a DataChannel's `CapturedByNodeName` or a
DerivedChannel's `CreatedByNodeName`). From maple (75 Data + 16 Derived), DataChannels group cleanly
by their capturer, so the gen emits each group off the corresponding component:

| CapturedByNode | DataChannels it reports |
|---|---|
| `power-meter` (eGauge) | every `*-pwr` (hp-odu/idu, dist/primary/store-pump, oil-boiler, per-zone whitewire-pwr) |
| `analog-temp` (ADS111x TSnap) | pipe temps (dist-swt/rwt, hp-lwt/ewt, buffer-hot/cold-pipe), `oat`, zone gw-temp |
| `relay-multiplexer` | every relay-state channel (`*-relayN`) |
| `zero-ten-multiplexer` | `dist/primary/store-010v` |
| `buffer` / `tank{i}` (pico tank) | per-depth `*-device` + `*-micro-v` raw channels |
| `dist-flow` / `sieg-send` (pico flow) | `*-flow` + `*-flow-hz` |
| `store-btu` / `sieg-btu` (BTU meter) | `store-hot/cold-pipe` + `store-flow`; `sieg-cold/flow/hot` |
| `zone{i}-…-stat` (Hubitat poller) | per-zone `-set` / `-state` / `-temp` |

DerivedChannels are all `CreatedByNode = derived-generator` **except** `hp-keep-seconds-x-10`
(`sieg-loop`, `integrate-relay-motion`, sieg-only). Strategies: tank/buffer per-depth calibration is
`affine` (depth1/3) / `identity` (depth2); `primary-flow` is `sum` (derived config only);
`required-energy`/`usable-energy` are `system-model`. So the few real data-vs-derived questions live
at `primary-flow`, the calibrated `*-depth{n}` (Derived) vs raw `*-depth{n}-device`/`micro-v` (Data
off the tank module), and the sieg `hp-keep-seconds-x-10`.

**⏳ Deliberate gen hack — uniform per-zone bundle (REVISIT in pass-2).** To move fast, every zone is
REQUIRED to carry the same bundle, no per-zone variation:

1. a **Hubitat thermostat poller** reporting `zone{i}-{label}-temp` / `-set`; plus the **sick**
   `-state` channel (kept — see below);
2. **`zone{i}-{label}-whitewire-pwr`** — a DataChannel captured by `power-meter`;
3. **`zone{i}-{label}-heat-call`** — a DerivedChannel (Strategy `heat-call`, created by
   `derived-generator`) computed **from** whitewire-pwr, **not** the Hubitat.

*Why heat-call is derived, not Hubitat-reported.* The Hubitat's `thermostatOperatingState` heat-call
reporting has been **very inaccurate**. The replacement — heat-call derived from whitewire power —
**crystallized in Spruce/Nolan**, the first site with **no Hubitats/Honeywells**, which forced
deriving it directly. **The derivation already exists in scada:** `actors/derived_generator.py`
`handle_heat_call` (the `"heat-call"` Strategy) computes a binary heat-call from a raw whitewire-power
reading (threshold + interpolation), and a setpoint-learner consumes `[gw-temp, heat-call]`. What's
missing is that **no production layout declares a `heat-call` derived channel yet** — which is why the
live recalc still runs upstream in the **visualizer** (Thomas + George). Wiring a per-zone `heat-call`
derived channel closes that gap and unifies House0 + Nolan on one mechanism.

*Decision on the Hubitat `state` channel (2026-06-16): KEEP it, flag it sick.* Rather than rip out
the `thermostatOperatingState` polling (`poller.py` + `honeywell_thermostat.py`) and break the
dashboard consumers (`ltn/dashboard/{display/thermostats,display/power,display/picture,hackhp,
channels/containers}.py`), we **keep** `zone-state` but docstring it in `ZoneChannelNames`
(`data_classes/house_0_names.py`) as **sick / unstable — do not trust for heat-call**, while
`heat-call` (derived) is the trustworthy signal. It is **currently still required** (in
`ZoneChannelNames.all`), held there only for back-compat with the dashboard consumers; the direction
is to **retire it to known-optional** once whitewire-derived heat-call is the relied-on signal
everywhere. ("Required" is the contract; it says nothing about whether the readings can be trusted —
the worked example now lives in `executor/hardware-layout.md`.) The clean cross-family modeling
("Hubitat present but NOT the heat-call source" vs. Nolan's no-Hubitat) is the **open puzzle deferred
to pass-2**.

**Where "optional" lives — three categories, gated by code-awareness.** A layout has, beyond what the
operational code reasons about, **arbitrary experimental / hand-made nodes + channels** it always
tolerates. So channels fall into three kinds, not two:

1. **Required** — the code needs it; a `gw.house0.layout` **sema axiom** demands it.
2. **Optional** — the code **knows it, knows it's optional, and uses it if present**, but tolerates
   its absence. Example: `buffer-cold-pipe` — missing on some production homes for plumbing reasons;
   if present the code absolutely wants it. This is a **positive, enumerated** category, *not* merely
   "not required."
3. **Experimental / hand-made extras** — channels the operational code does **not** know about (a
   bench-wired `random-temp-sensor`). Always allowed, never reasoned about; the layout type stays open
   to them (not a closed set).

A known-optional channel (`buffer-cold-pipe`) and an experimental extra (`random-temp-sensor`) are
**categorically different** even though both are "not required": the first is in the code's vocabulary
with a use-it-if-present path; the second the code has never heard of. Collapsing them is the mistake
this taxonomy prevents.

So the authority splits cleanly by question — and the two authorities are *different*:

- **What is REQUIRED → sema.** The `gw.house0.layout` axioms are the binding contract for what every
  House0 layout MUST carry.
- **What OPTIONAL nodes/channels the code knows about → `gwsproto/names/`.** Being *in* the names
  hierarchy is precisely what makes a channel "known-optional" (the code knows it) rather than an
  experimental extra. names/ is the catalog of the knowable; the *use-it-if-present behavior* then
  lives in the operational code (and the dc loader's `optional_channels` is today's code-side list).
- **Experimental extras → named by no one, required by no one** — the test that separates a
  known-optional (`buffer-cold-pipe`, in names/) from an extra (`random-temp-sensor`, not in names/)
  is simply *"is it in names/?"* The layout type stays open to extras either way.

A conditional axiom MAY still constrain a *known* channel *when present* (e.g. "if `primary-flow` is a
sum DerivedChannel, …") — that is sema constraining the contract, not sema enumerating optionals.

*Consequence for validation:* maple's fixture has whitewire-pwr but **no** per-zone `heat-call`
derived channel, so emitting heat-call uniformly means `sema_gen(config)` won't strictly equal
`dc_to_sema(load(old_dc_gen(config)))` on the zone channels — until the obvious patch: **add the
correct `heat-call` derived channel to the maple (and fleet) hardware layouts** via the old gen, after
which the equivalence holds again. This is an instance of the "update the OLD gen too" principle at
the end of this blueprint — adding heat-call to the House0 shape obliges the dc-side builders to add
it as well (all production houses get a `heat-call` channel; all but spruce derive it from whitewire).

**Per-position flow/temperature sourcing — a config axis the gen must manage.** At each flow position
(`dist` · `primary` · `store` · `sieg`) the flow rate and the two pipe temperatures come from one of
two device kinds:

- **BTU meter** (`layout_gen/btu.py` `add_btu` → `PicoBtuMeterComponentGt`, `ApiBtuMeter`): one device
  bundles **flow + hot temp + cold temp** (+ optional CT), all DataChannels captured by the BTU node.
  Used at `store`/`sieg` in maple.
- **Flow meter** (`layout_gen/flow.py` `add_flow` → `PicoFlowModuleComponentGt`, `ApiFlowModule`,
  Hall/Reed): **flow only** (`*-flow` + `*-flow-hz`); the pipe temps for that position come from the
  **`analog-temp`** TSnap instead. Used at `dist` in maple.

So per position the config picks: BTU-meter | flow-meter + analog-temps | derived (the `primary` sum
case) | absent — the same shape as `PrimaryFlowSource` generalized to every position. The gen takes a
per-position selector and emits the right component + nodes + channels; `add_btu`/`add_flow` are the
reference for what each kind emits.

**So the gen = emit the invariant skeleton + the four config axes, using the names hierarchy.**
Examining the required sets is also how we catch over-specification (the `hp-idu` case): an entry a
real House0 home omits is config-driven, not invariant.

**Principle — require the semantic aggregate, not the hardware decomposition (the heat-pump case).**
hp-idu is the cleanest **known-optional node**: 2-part heat pumps have it, 1-part (maple) don't, and
the layout should NOT encode "is this a 1- or 2-part heat pump?" Instead, what we **require** is a new
derived **`heat-pump-power`** channel = Σ (all HP-unit power channels), Strategy `sum`, created by
`derived-generator`. `hp-odu`/`hp-odu-pwr` are required; **`hp-idu`/`hp-idu-pwr` become known-optional
in `names/`** (present only on 2-part HPs). The summands are exactly the `heat-pump-power` derived
channel's `InputChannelNames` (`[hp-odu-pwr]` or `[hp-odu-pwr, hp-idu-pwr]`) — **the same pattern as
`primary-flow`**: require the aggregate, let the summands be config, tie them with an axiom; no
separate `HeatPumpPowerChannels` attribute unless a consumer needs the list without reading the
derived channel. (This also fixes the over-strict `required_topology_nodes`, which wrongly lists
`hp_idu` as required — the requirement is `heat-pump-power`, not `hp-idu`.)

**Principle — changing the implicit House0 shape means updating the OLD gen too.** The validation
target `sema_gen(config) == dc_to_sema(load(old_dc_gen(config)))` only holds if both sides emit the
same shape. So whenever the gen **adds or removes** a channel or node from the House0 shape, the
dc-side `layout_gen` / `tlayouts gen_XX.py` builders MUST be updated **in lockstep** so the loaded
dataclasses still match — otherwise the equivalence breaks (that mismatch is the bug this rule
prevents, not a reason to relax the check). Concrete case in flight: the per-zone `heat-call` channel
— **all** production houses get a `heat-call` channel, **all but spruce** derive it from whitewire
power; the old gen must be updated to add it to maple and the rest of the fleet.

### Task b — the axiom slice list + EDD recipe (House0 only this pass)

`gw.house0.layout/000` is **unpushed → mutable in place**; axioms are added to `000` directly (no
bump). Already present: ① GlobalIdUniqueness, ② EssentialNodesExistence, ③ ZoneHeatCallChannel (a per-zone
`heat-call` DerivedChannel + a `whitewire-pwr`|`opto-input` source — *replaced* the old
ZoneWhitewirePwrChannel 2026-06-23), ④ PrimaryFlowSourceChannelAgreement (+ `UseSiegLoop ⟹
SiegLoopPlumbed` and Cardinality on `gw.house0.hydronic`). Gaps to port, simplest-first:

- **A — Cardinality ✅ LANDED** (`gw.house0.hydronic/000` #2): `1 ≤ TotalStoreTanks ≤ 6`,
  `1 ≤ |Zones| ≤ 6` (`house_0_layout.py:100–103`). Counterexample test still owed (waits on the gen).
- **B — WebServerPresent:** a `web.server` component named the default exists (`:111`).
- **C — SiegManifoldChannels:** `SiegLoopPlumbed ⟹` `hp-loop-on-off` + `hp-loop-keep-send`
  relay-state channels (`check_house0_sieg_manifold`).
- **D — SiegActors:** `UseSiegLoop ⟹` SiegLoop + HpBoss nodes (right actor class); `¬UseSiegLoop ⟹`
  no SiegLoop node (`check_actors_when_*`).
- **E — TankDepthCalibrationChannels:** each buffer/tank depth → an `identity`|`affine` DerivedChannel
  (`validate_tank_temp_calibration_consistency`).
- **F — SystemModelEnergyChannels:** usable + required energy, `system-model` strategy, created by
  `derived-generator`, exactly one of each (`validate_house0_system_models`).
- **I — DerivedInputChannelsExist (referential integrity):** every `DerivedChannel`'s
  `InputChannelNames` SHALL each resolve to an existing channel name in the **union** of DataChannels
  ∪ DerivedChannels (a derived channel MAY feed another derived channel — e.g. `transactive-power`
  summing the derived `heat-pump-power`). One of the executor's named referential-integrity
  constraints; clean, layout-wide, and independent of the others.
- **DeviceTypeRecordAlignment (owed):** for components whose `DeviceType` has an actual
  `*.device.type.gt` record (`Ads111xBasedDeviceTypeGt`, `ElectricMeterDeviceTypeGt`,
  `Gw1ScadaDeviceTypeGt`), the record must align — not yet on any layout.
- **G/H — RequiredTopologyNodes / RequiredSystemActorNodes — DEFERRED to pass-2:** the first-guess
  production-necessity spec, but written in `H0N` terms (which pass-2 drops) and already too strict
  (the maple `hp-idu` case). Do not port this pass.

**The per-axiom recipe (learned from Cardinality).** Each slice is one full sema→gwta→gwsproto loop:

1. **Pick the carrier + owner.** Bare `minimum`/`maximum`/`minItems`/`pattern` are **forbidden** in
   sema (primitive-constraint rule) → a non-structural invariant becomes an **axiom**. Put it on the
   type that *owns* the fields (Cardinality lives on `gw.house0.hydronic`, not the layout). Confirm
   the version is **unpushed → mutable** (`git branch -r --contains <commit>` empty) — else a new
   version is required.
2. **Write the axiom YAML** under `x-gridworks.axioms` (number, name, normative SHALL statement; use
   `a.`/`b.` clause labels when there are distinct counterexample obligations).
3. **Implement `check_axiom_N` in the jinja2 template** — the regen *ensures a template file exists*
   but does NOT add a stub for a new axiom to an existing template, so you hand-write the
   `@model_validator(mode="after") def check_axiom_N` in
   `src/sema/tools/runtime_generation/templates/axioms/<type>_<ver>.py.jinja2` (snake_case runtime
   field names). Then `scripts/build_indexes.sh` + `.venv/bin/python scripts/regenerate_runtime.py`;
   `pytest`.
4. **Snapshot to gwta** (`sema/build_gwta_snapshot.sh`) so gwta enforces it; confirm the
   start-from-fixture round-trip stays **green** for all five fleet layouts (the axiom passes on
   valid layouts).
5. **EDD the counterexample — prove it CATCHES a violation.** The dc path can't emit a violating
   layout (its Python guards raise first), so use the **Task-a sema gen** as the fixture factory:
   gen a layout that breaks the axiom, run `default_codec.from_dict(payload)`, **observe it raises**
   `Axiom N`, and **freeze that payload** as
   `sema/tests/runtime/<type>/fixtures/<ver>/axiom_<n>[_<label>].json` + a pytest asserting
   `pytest.raises(SemaError, match="Axiom N …")`. Generate → observe-the-failure → freeze-the-fixture
   is the EDD loop for axioms. (Existing pattern: `tests/runtime/derived_channel_gt/` +
   `fixtures/v002/axiom_*.json`.)

## Working method — sema is the source of truth

For all three mutating layout types (`gw.nolan.layout`, `gw.house0.layout`, `gw1.simple.sim.layout`)
the loop is: **(1)** edit the layout type in sema (definition yaml + registry; `build_indexes.sh` +
`regenerate_runtime.py`; `pytest`); **(2)** snapshot to gwta (`sema/build_gwta_snapshot.sh` does
prepare → remap → build → copy-to-gwta); **(3)** hand-change the gwsproto class to match
(`named_types/`); **(4)** run the round-trip script. Local class names are short — `House0Layout`,
`SimpleSimLayout`, `NolanLayout` (via the snapshot `local_names.yaml`). gwsproto carries **one
version per type at a time** (the current version replaces the prior; no retained `XxxNNN` classes
the way sema keeps them). Immutability tracks **pushed-to-GitHub** (unpushed sema words are mutable
in place).

**Deferred (sequenced after the gen + adapter land):**
- **The names sweep** — replace all `house_0_names` `H0N`/`H0CN` references (~61 files) with the new
  `gwsproto/names/` per-domain names, in one pass.
- **The reference sweep** — move the ~76 scada call-sites off the derived `self.layout` accessors onto
  `self.hydronic.*`, at dc-swap time.
- **The ConfigList revamp** — a single `channel.config` shape with `TelemetryName → gw1.unit` +
  `gw1.quantity` (the round-trip is the harness that lets it land).
- **spruce → Nolan rewrite** — `gen_spruce.py` is a stale House0-based gen marked OLD/BROKEN; it
  should be `gw.nolan.layout`.

## Gleanings — domain context (durable)

> **TODO for hardware-layout-pass-2 — drop `H0N`, knit the shared/different layout structures.**
> `required_topology_nodes` / `required_system_actor_nodes` are the first-guess production-necessity
> spec but are written in `H0N` terms and enforced nowhere yet. Pass-2 drops `H0N` and works out what
> each layout family shares vs. differs on — only then can these become real per-layout axioms.
> **Proof the guess is already too strict:** `maple` carries only an `hp-odu` (no `hp-idu`) yet is
> definitely still House0, so `required_topology_nodes` (which lists `H0N.hp_idu`) is wrong as-is.
> (Both properties carry "design brainstorm, not used yet" docstrings in the code.)

> **Naming — Nolan ↔ Spruce (keep both; not PII):** the gw108 house is **Nolan** in code and sema
> (`gw.nolan.layout`, Strategy `"Nolan"`) and **Spruce** colloquially — next in the tree-name series
> (beech, elm, oak, fir, maple → spruce). Same house. Ms. Nolan was a Millinocket widow in the
> original house; Matt Polstein bought the property, let her stay through her passing, then built the
> Nolan house — an honored legacy, not a name to scrub.

**Field reality:**
- The first five homes run the **House0** layout: **beech, elm, oak, fir, maple** — electronics
  hand-made by George, not gw108. Common: three store tanks + a buffer; Hubitat hubs driving
  Honeywell thermostats; varied heat pumps. **Siegenthaler loops on beech and maple** (a mechanical
  variation, not a software distinction). Zone count varies (beech/maple 2, oak/elm/fir 4).
- **Spruce is a one-off:** gw108 electronics, plain radiant floor. The next ~12 new-builds use
  store-under-floor, so Spruce's specifics shouldn't be over-generalized.

So House0 is the **fleet** layout (5 homes, one hardware generation, ~47 ShNodes); Spruce is a
**single experimental** gw108 layout (~30 ShNodes). That asymmetry is why house0 earns its own word.

**Simulated tanks + the simple-sim layout (next phase):**
- `sim.pico.tank.module.component.gt` exists to **unit-test `api_tank_module.py`** — same channels as
  a real `PicoTankModule3` but its `DeviceType` marks it a sim sensor.
- **Nolan has exactly 1 storage tank** (buffer + tank1); the **simple sim is the same — 1 storage
  tank, 360 gallons**. **Tank gallons are articulated fragilely** — firm this up when building the
  simple-sim layout.

## Deferred deliverable — the Siegenthaler / `primary-flow` behavior test

The `FlowTopology` structure **landed**: `gw.house0.hydronic` carries `SiegLoopPlumbed` (was
`FlowManifoldVariant`), `UseSiegLoop`, and `PrimaryFlowSource` (`Measured` | `DerivedSiegSum`), with
the source⟶channel agreement axiom. The three configs the code must handle:

| home | `SiegLoopPlumbed` | `UseSiegLoop` | `PrimaryFlowSource` |
|------|---|---|---|
| oak/elm/fir | false | false | Measured |
| beech | true | false | Measured |
| maple | true | true | DerivedSiegSum |

What is **deferred to the simulated-plant focus** (cannot be verified before it) is the **behavior
test** — the EDD bar for the `sum`/topology + tank-calibration work. It rides on `ScadaLiveTest`
(`tests/utils/scada_live_test_helper.py`, in-process LTN↔SCADA, no broker; see `executor/testing.md`
"The harness"); the simulated plant is the device-reading source that feeds it.

**The three configs under test (all MUST pass):**

| # | config | source | assert |
|---|--------|------|------|
| 1 | no loop (oak/elm/fir) | Measured (own meter) | `primary-flow` DataChannel arrives intact; no derivation runs |
| 2 | loop, not controlled (beech) | Measured (`primary-btu`) | `primary-btu` emits `primary-flow` directly as a DataChannel |
| 3 | loop, controlled (maple) | DerivedSiegSum | `sieg-btu`→`sieg-flow` + `sieg-send`→`sieg-send`; the `sum` strategy emits `primary-flow = sieg-send + sieg-flow` |

**Config 3 recipe:** load the maple-shaped layout; confirm `primary-flow` is a `sum` DerivedChannel
(`InputChannelNames=[sieg-send, sieg-flow]`, `OutputUnit=GpmX100`) and **absent** from DataChannels.
Feed `sieg-btu` → `sieg-flow`; feed `sieg-send` → `sieg-send`; assert `derived_generator` emits
`primary-flow = sieg-send + sieg-flow`. Edge cases: only one input seen → no emission (or a defined
partial — pin it down); one-fresh-one-cached → uses the cached latest (`self.data.latest_channel_values`).

**Also exercise the affine tank-calibration path (unverified end-to-end).** Feed `api_tank_module`
device readings (`*-depth{n}-device`, WaterTempCTimes1000) through `handle_affine` and assert the
calibrated `*-depth{n}` (FahrenheitX100) equals `M*x + B` for a **non-zero B** — the suite has only
ever run `B=0` (identity), so the v001 `affine` math has no test yet.

**Compliance tests WAIT for the data-classes → sema-types transition** — "fully compliant" is defined
by the axioms being lifted into sema, so writing the assertions now chases a moving target. The layout
*fixtures* are durable and fine to shape now; the *assertions* follow the sema authority.

## I²C / board-resident components — actor layer (in flight)

The durable model now lives in
[`executor/hardware-layout.md`](../executor/hardware-layout.md) "I²C and
board-resident components": the three layers (bus / board / device), the board
as single source of physical truth, the full `i2c.*` + board sema vocabulary,
the two enforcement tiers, the `BusMembership` / cross-consistency / layout
bijection invariants, and the decision to route ADC reads through `I2cBus`.
The sema words are authored and green (Batches 1–3 — sema `dc6800e` + the gw108
board example) **and** the gwsproto bus-op types are now aligned to the composed
family (`I2cWriteBit`/`I2cReadBit`/`I2cWriteReg`/`I2cReadReg`/`I2cResult`, nested
`Address`, `Operation` enum). What remains is the **actor wiring** to make the
board the resolved source of truth at runtime.

### Remaining build steps (rough dependency order)

1. **Device-type values first.** Mint the `gw1.device.type` enum values for the
   board-resident coarse `DeviceType`s — "ADC on gw108" and "I²C relay on gw108"
   (e.g. `Gw108Adc`, `Gw108I2cRelay`). The thermistor and relay components below
   carry these, so they come first.
2. **Thermistor reader → `i2c.thermistor.reader.component.gt/003`.** A version
   bump dropping `AdcAddress`, `AdcReferenceVolts`, `SeriesResistanceKOhms`, and
   `Bus` (all now on the board); keep `TempCalcMethod` + `ConfigList`;
   `DeviceType` becomes the `Gw108Adc` value; the reader names its board ADC by
   `Name`. Full version ritual (schema `/003` + registry + `002→003` upgrade
   template + regen), then align the gwsproto type and set the moved facts in
   `scada_gw108`.
3. **Relay decommission → `i2c.relay.component.gt`.** Retire
   `I2cMultichannelDtRelayComponent` for one-relay-per-component: a new
   `ComponentBase` type carrying `RelayName` + chosen `WiringConfig` + the one
   `relay.actor.config`, `DeviceType` = `Gw108I2cRelay`. Remove
   `i2c_relay_multiplexer` + `i2c_relay_board`; rework `relay.py` to resolve
   `RelayName` against the board and write via `I2cBus`. Layout + fixture
   migration (every relay node re-pointed) — its own chunk.
4. **Wire the `I2cBus` actor.** Have it receive the composed bus-ops and reply
   `I2cResult` to the **requester** (today it goes to `primary_scada`; needs the
   `Header.Src` reply-to so the result returns with its `TriggerId`). Route the
   ADC reads through `I2cBus` per the executor decision.
5. **Layout bijection axiom.** Add to each layout type (`gw.house0.layout`,
   `gw.nolan.layout`, `gw1.simple.sim.layout`) that the DataChannel set is in
   bijection with the `ChannelName` set across all component `ConfigList`s.

### Open

- **`I2cResult` routing** — the reply-to (step 4) so a relay can confirm its own
  actuation by `TriggerId`.
- **Bus actor ↔ hardware bus bijection** (a hardware-layout axiom, deferred with
  the actor wiring): each `I2cBus` actor ShNode (`spaceheat.name`, e.g.
  `default-bus`) ↔ a board `BusList` entry (`i2c.bus`, `pascal.case` `Name`,
  e.g. `DefaultBus`), via the `pascal.case ↔ spaceheat.name` casing map.
- **Device-type value names** — the exact `gw1.device.type` strings for "ADC on
  gw108" / "I²C relay on gw108" (e.g. `Gw108Adc`, `Gw108I2cRelay`).

## Channel-config overhaul (scada half) — done (2026-06-26)

The channel-config slice ([OPS-427](https://linear.app/gridworks/issue/OPS-427)) landed on
`gridworks-scada` `jm/delete-cac-id` and `sema` `jm/sim-vocab`. Scada suite green (112), sema green
(241). The durable shape:

- **`channel.config` carries neither `Unit` nor `Exponent`** — across all six
  ChannelConfigBase-family types (`channel.config`, `ads.channel.config`,
  `i2c.thermistor.channel.config`, `electric.meter.channel.config`, `dfr.config`,
  `relay.actor.config`). A channel's identity is its `TelemetryName` (which already encodes
  scaling, e.g. `GpmTimes100`); its unit resolves from `TelemetryName`, never from the config.
  `egauge.register.config` (its `Unit`) and `maker.api.attribute.gt` (its functional `Exponent`)
  are out of the family and keep both.
- **The metered transactive set is declared once, not flagged per-node.** `InPowerMetering` is gone
  from `spaceheat.node.gt` (303) and `data.channel.gt` (003). In its place a single
  `derived.channel.gt` with **`Strategy="transactive-power"`** names the metered `PowerW` channels
  in `InputChannelNames`. The **power-meter actor** computes it (not the derived-generator, so
  `power.watts` latency is unchanged) — it reads the channel's inputs to know what to sum. The
  strategy is deliberately distinct from `"sum"`: the layout needs exactly one identifiable,
  nameplate-bound transactive declaration, and a generic sum (which appears elsewhere) would route
  to the wrong actor. `Strategy` stays an open string for now — a sema enum is deferred until the
  derived-strategy vocabulary settles, since sema enums coerce unknown values to a default and so
  would be weaker than the code-level strategy validation.
- **Layout axiom (the metering boundary).** Exactly one `transactive-power` DerivedChannel; its
  inputs resolve to existing `PowerW` DataChannels; each input's about-node carries
  `NameplatePowerW`. Lives in `hardware_layout.check_transactive_metering_consistency` and is
  mirrored in the sema layout words — `gw.house0.layout` axiom 5 and `gw.nolan.layout` axiom 1
  (executable validators; the house0 example carries a transactive-power channel). This axiom is
  where the retired `spaceheat.node.gt` "InPowerMetering implies NameplatePowerW" obligation now
  lives.
- **No defaulted nameplates.** The metered set is config-declared (the eGauge gen per channel, the
  sim gen via `transactive_about_nodes`), and a transactive node MUST state its `NameplatePowerW` —
  no builder default. `CoreChannelNames.transactive_power` is the channel name.
- **Removed as dead:** `TelemetryTuple` and its four unused `HardwareLayout` properties, the unused
  `asset-electric-power` name, the eGauge `NameplatePowerW=10` default.

### Carried forward (not in this slice)

- **Functional relay ShNode names.** The gen still builds relay nodes as `relay{krida-idx}`. The
  intended shape is functional ShNode names assigned to the PascalCase hardware relays on the board
  device type (the board-resident model) — a value-changing layout migration, folded into the relay
  decommission chunk (step 3 above).
- **Gen/round-trip gate for all homes.** `dc_to_sema` currently fails the `ZoneHeatCallChannel`
  axiom because the fleet fixtures lack the zone heat-call + whitewire/opto source channels the
  heat-call work added — fixture staleness on that axis, separate from channel-config.
- **`SendToDerived` removal** (still on `i2c.thermistor.channel.config`) and the **old
  `layout_gen/` LayoutDb builders** sweep (under rework on `jm/layout-augmments`).
- **`channel_stubs()` / `ChannelStub`** in `house_0_names.py` — fully unused, still carrying the
  retired `in_power_metering`; delete when convenient.
- **The transactive *audit declaration*** — this slice only drops `InPowerMetering` and adds the
  `transactive-power` channel. Making the audited quantity fully first-class (inspected-meter
  binding, energy-from-register vs our integral, the committed/signed reported stream, single-CT
  preference, directional combination) stays open in `explorations/metering.md`.
