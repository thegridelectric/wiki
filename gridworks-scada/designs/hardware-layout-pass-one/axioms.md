# Layout axioms — house0 + nolan (spoke)

Status: Accepted · Pass 1 · Updated 2026-06-29 · Linear: OPS-407

> What this is: finish the layout axioms this pass — **house0 and nolan** — porting the structural
> validations into sema axioms, keeping the boot/round-trip green at each addition, and adding a
> generated counterexample per axiom (the [`gen-pipeline.md`](gen-pipeline.md) gen is the fixture
> factory). The dc path can't emit a violating layout (its Python guards raise first), so the sema-
> native gen is the only clean way to author counterexamples.

## The channel-stub enforcement pattern (governs every channel-existence axiom)

A required channel is a **stub**: a *name that must exist, bound to its semantic subject and unit — not
to its hardware capturer.* Every channel-existence axiom (house0 and nolan alike) enforces three things
and deliberately omits a fourth:

- **Existence in the union.** Exactly one channel of that `Name` across `DataChannels ∪ DerivedChannels`.
  The union is essential — the requirement is satisfied by *either* form (see the pair below).
- **`AboutNodeName`** — the semantic subject (what the reading is *about*). The invariant: `dist-swt` is
  about the `dist-swt` node, full stop.
- **Unit / quantity** — the meaning of the value (disjunctive, per the pair below).
- **NOT `CapturedByNodeName`.** Which hardware node reads a channel (eGauge vs ADS-TSnap vs a BTU meter
  at a given position) is **config-bespoke** — it is the per-position-sourcing axis
  ([`generator-blueprint.md`](generator-blueprint.md)). Pinning the capturer in the contract would couple
  the layout to one hardware decomposition — the same over-specification "require the semantic aggregate,
  not the hardware decomposition" rejects. Capturer/component wiring is a **separate** concern, enforced
  by the component↔channel bijection axiom **deferred to pass-two** with the i2c board model
  ([`i2c-board-components.md`](i2c-board-components.md)). Referential integrity stays: *if*
  `CapturedByNodeName` is present it must resolve to a node (`ChannelBindingIntegrity`) — that is not a
  requirement to be captured by a *specific* node.

**Two senses of "pair" — both real:**

1. **The data-OR-derived unit disjunction (the unit pair).** Because a channel MAY be realized as a
   DataChannel *or* a DerivedChannel, the unit enforcement is two branches:
   - **DataChannel** → constrain `TelemetryName` (which encodes scaling): a pipe temp is
     `WaterTempCTimes1000`|`CelsiusTimes100`; a flow is `GpmTimes100`.
   - **DerivedChannel** → constrain `OutputUnit` + `OutputQuantity`: e.g. `FahrenheitX100` / `Temperature`.

   The axiom asserts "this stub exists, about node X, and *whichever* form it takes, its unit matches the
   branch for that form" — so a raw sensor reading and a calibration/derivation both satisfy it without
   the contract committing to which. Exemplars in the stash: `PipeTemperatureChannelSemantics`,
   `TankTemperatureChannelSemantics`, `PipeFlowChannelSemantics`.
2. **The raw-device / effective-derived channel pair.** Some quantities carry a genuine *pair of
   channels*: a raw `*-depth{n}-device` DataChannel (off the tank module) AND a calibrated `*-depth{n}`
   effective DerivedChannel (`affine`|`identity`). The effective channel is the required stub; the
   device channel is its raw input. The calibration axiom (house0 slice E / nolan
   `TankTemperatureChannelSemantics`) ties the pair.

So the contract asserts *"a reading about X, in unit U, in either form, exists"* and stays silent on the
hardware that produces it. This is the altitude every existence axiom below is written at.

## house0 — slice list (simplest-first)

`gw.house0.layout/000` is **`staging` → mutable in place** (OPS-445 status model); axioms are added to
`000` directly (no bump).
Already present: ① GlobalIdUniqueness, ② EssentialNodesExistence, ③ ZoneHeatCallChannel (per-zone
`heat-call` DerivedChannel + a `whitewire-pwr`|`opto-input` source — *replaced* the old
ZoneWhitewirePwrChannel 2026-06-23), ④ PrimaryFlowSourceChannelAgreement, ⑤ TransactivePowerChannel
(+ `UseSiegLoop ⟹ SiegLoopPlumbed` and Cardinality on `gw.house0.hydronic`). Gaps to port:

- **A — Cardinality ✅ LANDED** (`gw.house0.hydronic/000` #2): `1 ≤ TotalStoreTanks ≤ 6`,
  `1 ≤ |Zones| ≤ 6` (`house_0_layout.py:100–103`). Counterexample test still owed.
- **B — WebServerPresent:** a `web.server` component named the default exists (`:111`).
- **C — SiegManifoldChannels:** `SiegLoopPlumbed ⟹` `hp-loop-on-off` + `hp-loop-keep-send` relay-state
  channels (`check_house0_sieg_manifold`).
- **D — SiegActors:** `UseSiegLoop ⟹` SiegLoop + HpBoss nodes (right actor class); `¬UseSiegLoop ⟹` no
  SiegLoop node (`check_actors_when_*`).
- **E — TankDepthCalibrationChannels:** each buffer/tank depth → an `identity`|`affine` DerivedChannel
  (`validate_tank_temp_calibration_consistency`).
- **F — SystemModelEnergyChannels:** usable + required energy, `system-model` strategy, created by
  `derived-generator`, exactly one of each (`validate_house0_system_models`).
- **I — DerivedInputChannelsExist (referential integrity):** every `DerivedChannel`'s
  `InputChannelNames` SHALL each resolve to an existing channel in the **union** of DataChannels ∪
  DerivedChannels (a derived channel MAY feed another — e.g. `transactive-power` summing the derived
  `heat-pump-power`).
- **DeviceTypeRecordAlignment (owed):** for components whose `DeviceType` has a `*.device.type.gt`
  record (`Ads111xBasedDeviceTypeGt`, `ElectricMeterDeviceTypeGt`, `Gw1ScadaDeviceTypeGt`), the record
  must align.
- **G/H — RequiredTopologyNodes / RequiredSystemActorNodes — DEFERRED to pass-2:** written in `H0N`
  terms (which pass-2 drops) and already too strict (the maple `hp-idu` case). Do not port this pass.

## nolan — un-stash the axioms

`gw.nolan.layout/000` axioms are parked in
`sema/definitions/types/gw.nolan.layout/stash_axioms.md` (lifted out so the type generates a runtime
without validators). This pass: port the nolan slice too. The stash is the structural reference; note
it predates channel-config-overhaul (it still references the retired `InPowerMetering` /
`asset-electric-power` — reconcile to `transactive-power` when porting). Key nolan-specific structure:

- **Zones** (`ZoneShNodeStructure` / `ZoneChannelStructure`): per zone `zone{i}-{Z}` + `-whitewire` /
  `-stat` / `-floor` nodes; channels `-temp` / `-set` / `-heat-call` / `-failsafe-relay` / `-ops-relay`
  / `-floor-temp`. Nolan is radiant-floor (`floor-swt`, per-zone `-floor-temp`), gw108 opto-sourced
  heat-call — contrast House0's Hubitat `-stat-temp` + whitewire-sourced heat-call.
- **Tanks** (`TankShNodeStructure`): buffer + `tank{i}` depths 1–3; Nolan has exactly 1 storage tank
  (buffer + tank1).
- **Relays** (`RelayBoardConfigBijection`, `VdcRelaySemantics`, `ElementRelaySemantics`, zone
  failsafe/ops): gw108 board-resident relays with `relay.actor.config/003`, handle-topology closure.

## gw1.simple.sim.layout — its own word (not a house0 variant)

The simplified sim stand-in for House0 ([`sim-run.md`](sim-run.md)) is authored as
**`gw1.simple.sim.layout`** (no buffer, single tank, relays deferred) — **not** shoehorned into
`gw.house0.layout`. So **house0 keeps buffer as a required part of its shape**; the no-buffer case does
not relax a house0 axiom. `gw1.simple.sim.layout` carries its own (minimal) axioms appropriate to the
sim — outside the house0+nolan completion scope of this spoke, but the word must exist and load for the
sim-run.

## Validity authority + the revised bijection (see `layout-boundary.md`)

Two boundary decisions (2026-06-28) govern this spoke:

- **sema axioms are the sole layout-validity authority.** The dc `HardwareLayout` is assembled from
  axiom-valid sema, so the dc-side `check_*` methods are duplication — **dropped**, but **only once the
  matching sema axiom exists** (port → then drop; this *is* the Task-b workstream). The dc keeps no
  structural validation.
- **`ComponentDataChannelBijection` is revised.** Because a component carries a `ConfigList` only when it
  has per-channel hardware binding, the global `C == D` no longer holds. It becomes a **per-component local
  bijection**: *for a component that has a `ConfigList`, its `ChannelName` set equals exactly the
  DataChannels whose `CapturedByNodeName` is that component's node.* Composes with the kept
  `ChannelCaptureConsistency` + `CapturedByNodeName` referential integrity.
- **NEW — `CaptureNodeHasComponent` (recovers what the ConfigList drop silently removed).** The old global
  `C == D` bijection guaranteed, for free, that every captured channel was tied to an actual
  hardware-bearing component (it had to appear in *some* `ConfigList`). Once the no-binding components drop
  their `ConfigList`, that guarantee is gone — `ChannelBindingIntegrity` only checks the capturer *resolves
  to a node*, not that the node bears a component, so a raw reading could name a component-less logical/
  command node as its capturer and still validate. Restore it with a small structural axiom, **house0 and
  nolan both**: *for every `DataChannel`, if `CapturedByNodeName` is present, that ShNode SHALL have a
  non-null `ComponentId`.* Composes with `ComponentReferenceIntegrity` (`ComponentId` → a real component),
  so together they re-assert "captured by a real component." `DerivedChannel`s are **exempt** — they carry
  `CreatedByNodeName` (a derived-generator, legitimately component-less), not a capturer.
  - **The by-*kind* check stays pass-two.** That the component is of a *kind* able to capture the channel
    (thermistor↔temp, flow-module↔flow, meter↔power) is the component↔channel **capability** axiom already
    deferred above with the i2c board model — pulling it forward means encoding a channel-kind↔
    component-kind capability map the board model is about to reorganize. Pass-one recovers the structural
    "real component" guarantee; pass-two adds the semantic "right kind" guarantee.

## The per-axiom EDD recipe (learned from Cardinality)

Each slice is one full sema→gwta→gwsproto loop:

1. **Pick the carrier + owner.** Bare `minimum`/`maximum`/`minItems`/`pattern` are **forbidden** in
   sema → a non-structural invariant becomes an **axiom**. Put it on the type that *owns* the fields
   (Cardinality lives on `gw.house0.hydronic`, not the layout). Confirm the version is **unpushed →
   mutable** (`git branch -r --contains <commit>` empty) — else a new version is required.
2. **Write the axiom YAML** under `x-gridworks.axioms` (number, name, normative SHALL statement; use
   `a.`/`b.` clause labels when there are distinct counterexample obligations).
3. **Implement `check_axiom_N` in the jinja2 template** — regen *ensures a template file exists* but
   does NOT stub a new axiom, so hand-write the `@model_validator(mode="after") def check_axiom_N` in
   `src/sema/tools/runtime_generation/templates/axioms/<type>_<ver>.py.jinja2` (snake_case runtime
   field names). Then `scripts/build_indexes.sh` + `.venv/bin/python scripts/regenerate_runtime.py`;
   `pytest`.
4. **Snapshot to gwta** (`sema/build_gwta_snapshot.sh`) so gwta enforces it; confirm the boot / round-
   trip stays green (the axiom passes on valid layouts).
5. **EDD the counterexample — prove it CATCHES a violation.** Use the gen as the fixture factory: gen a
   layout that breaks the axiom, run `default_codec.from_dict(payload)`, **observe it raises**
   `Axiom N`, and **freeze that payload** as
   `sema/tests/runtime/<type>/fixtures/<ver>/axiom_<n>[_<label>].json` + a pytest asserting
   `pytest.raises(SemaError, match="Axiom N …")`. (Existing pattern: `tests/runtime/derived_channel_gt/`
   + `fixtures/v002/axiom_*.json`.)
