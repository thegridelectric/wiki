# Hardware layout — pass one

Status: Accepted · Pass 1 · Updated 2026-06-13 · Linear: OPS-407

**EDD: no** build-out/refactor — verified by the suite (layouts load + `layout_gen`
green for BOTH `house0.layout` and `gw.nolan.layout`; `pytest`), not gated on a
standalone real-world experiment.

> What this is: the first critical pass on the scada hardware-layout / components
> model. Drop the UUID `cac_id`s, replace make/model-as-CAC with a `gw1.device.type`
> enum, simplify components, and restructure `layout_gen` around the device type. A
> **shared dependency** — both the **simulated-test-environment** harness and
> **spruce-unlimbo** Chunk B need it — so it lives as its own flat Linear issue
> (GridWorks_CLAUDE "Shared-dependency work earns its own flat Linear issue"),
> referenced by name from both, not as a sub-issue of either.

## Why its own issue

The simulated-test-environment harness needs the new, simpler component shape to
stand up a sim layout; spruce-unlimbo Chunk B needs `layout_gen` restructured to make
both `house0` and `nolan` layouts green at the merge gate. Both depend on the same
chunk of work. Per the shared-dependency rule it becomes one flat issue, referenced by
name in each dependent's prose — keeping Linear flat and the work explainable.

It is also the "critical pass" `executor/hardware-layout.md` already anticipated
("First pass… Future TODO: review it with a critical eye for design, the way
`scada-ltn-link-state.md` was").

## The device-type model (decided 2026-06-13)

- **`gw1.device.type`** — a new sema enum, the universal device key. PascalCase values
  (the existing `pascal.case` format, no underscores), e.g. `EgaugePowerMeter`,
  `GridworksSimSensor`, `GridworksScadaGw108`, pruned to the device types
  `gridworks-scada` actually uses. It is a device **category**, NOT a make+model —
  lumping several eGauge models under one value is correct by design (split later
  additively if ever needed). `spaceheat.make.model` is **frozen** at `/008`; this is a
  fresh, cleaner vocabulary, not a bump.
- **Components carry `DeviceType`** as a `pascal.case` **format** field (open string,
  NOT an enum `$ref`) — so component types stay version-stable as the enum grows. **The
  hardware-layout type enforces** `DeviceType ∈ gw1.device.type` (the enum `$ref` /
  axiom lives on the *layout*), so a layout self-validates that every device type is
  known.
- **All `cac_id` / UUID device identity is REMOVED** — scada and sema alike. No
  `ComponentAttributeClassId`, no generic `component.attribute.class.gt` /
  `gw1.device.type.gt`. A plain device is fully described by its `DeviceType` value +
  the component's own fields (`ConfigList`, `DisplayName`, `HwUid`). The
  `CACS_BY_MAKE_MODEL` / bijection / projection machinery all evaporates.
- **Specialized records open per-family, only when the category carries real data** —
  `gw1.scada.device.type.gt` (gw108 board: GPIO/I²C/ADC/DAC numbers — exists),
  `egauge.device.type.gt` (modbus port), `electric.meter.device.type.gt`,
  `ads111x.device.type.gt`. gw108 is the exemplar: numbers belonging to the device
  *category*, not the individual component.
- **A component does NOT signal whether it has a specialized record.** The sensor-code
  author knows; a **layout axiom** enforces it — *if a component references a
  `DeviceType` that requires a specialized record, the layout MUST contain that type's
  `<family>.device.type.gt`*. Consistency is a layout invariant, not a per-component
  flag.
- **Join by the enum value.** A component finds its specialized record (when one
  exists) via its `DeviceType`; the specialized `.gt` carries the same `DeviceType`
  key. This replaces `component → cac_id (UUID) → CAC` with `component → DeviceType →
  optional specialized record by the same readable key`.

**Why this shape (the toolchain wall):** the earlier plan — a UUID-valued
`gw1.device.type.id` enum + a `make.model → id` projection enforcing a bijection — was
**abandoned**. Sema string-enum values must be valid Python identifiers (`GwStrEnum`:
the wire value *is* the member name), so UUIDs can't be enum members or projection
targets (`regenerate_runtime.py` rejects them). Dropping UUID identity entirely is the
simpler, toolchain-honest answer — and it makes components dramatically easier to read.
(Now canon in `sema/spec/authoring/enums.md`.)

## The migration (high-volume)

A real combing-through of `gridworks-scada`:

- **Remove every `cac_id` / `ComponentAttributeClassId` concept**, replacing the
  device-type reference with `DeviceType` (a `gw1.device.type` value) across gwsproto
  `named_types/` + `data_classes/` (the Cac side of the component triad goes away), the
  layouts / fixtures, and `tlayouts`.
- **Restructure `layout_gen`** around `DeviceType` — the per-device generators and the
  hardcoded bucket dispatch reorganize; **drop `CACS_BY_MAKE_MODEL`** entirely (subsumes
  the earlier `replace-cacs-by-make-model` idea — folded in here, no separate design).
- **New sim components** (`sim.sensor.component.gt`, `sim.relay.component.gt`) carry
  `DeviceType`, no `cac_id`.
- **Reword the `scada_device_type_gt.py` warning docstring** — `gw1.scada.device.type.gt`
  is a per-family specialized record, not a "board-specific vs generic device-type"
  contrast (there is no generic record now).
- Regenerate fixtures; **`pytest` green for BOTH** house0 and nolan (the spruce-unlimbo
  merge-gate condition).

## Sequencing

1. **Sema first** — mint `gw1.device.type` (+ wire the `DeviceType` `pascal.case` field
   into the sim component types) on `jm/sim-vocab`. 
2. **Scada migration** — the combing-through above, on a `jm/` branch off
   `jm/spruce-unlimbo` (per the temporary branch directive).
3. **Dependents consume** — the sim harness builds Phase A on the migrated layout;
   spruce-unlimbo Chunk B parameterizes `layout_gen` by layout for both house cases.

## Scope — pass one (with some license to sprawl)

The **spine**: drop `cac_id`s → `gw1.device.type` enum + `DeviceType`; simplify
components; restructure `layout_gen`. **Boundary (guideline, not a wall):** pass one
stops at the device-type / CAC model. The full **`ChannelConfig` / config-list overhaul**
and **`TelemetryName` → `gw1.unit`** (executor/components.md "Direction") are **pass
two**. Some honest creep into adjacent `layout_gen` cleanup is expected and fine — when
something clearly outgrows the pass, it rolls to pass two rather than ballooning this
one.

## Dependents (referenced by name, not by relation)

- **simulated-test-environment** — Phase A needs the new component shape to stand up the
  sim layout; the device-type model lives here (the harness spoke points at this design
  by name).
- **spruce-unlimbo Chunk B** — the `layout_gen` restructuring + the merge-gate condition
  "layout generation green for both `house0.layout` and `gw.nolan.layout`."
