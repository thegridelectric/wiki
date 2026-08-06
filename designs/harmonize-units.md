# harmonize-units

Status: Draft · Pass 0 · Updated 2026-08-06 · Linear: OPS-489

**EDD: no** vocabulary/config refactor; verified by the channel.config
boot/round-trip harness plus the suites, not a standalone real-world
experiment.

> What this is: retire `TelemetryName` in favor of `gw1.unit` +
> `gw1.quantity`, give every unit value machine-readable affine
> metadata, and land the single `channel.config` shape — one deliberate
> foundational cascade.

## The change

Three pieces that land together because they share one cascade:

1. **`TelemetryName` → `gw1.unit` + `gw1.quantity`.** TelemetryName
   overloads unit and meaning (`WaterTempCTimes1000` says both "water
   temperature" and "°C ×1000"). Split the axes: quantity carries the
   meaning, unit carries the encoding.
2. **Affine metadata on every gw1.units value.** Each value declares
   `{quantity, scale, offset}` to its quantity's base unit, as
   structured data alongside the description prose. The runtime then
   generates one `convert(value, from_unit, to_unit)` and a
   `display(value, unit) -> (float, label)` (natural display units per
   quantity: °F for temperature, GPM for flow). A new unit value cannot
   be authored without declaring what it means numerically.
3. **The ConfigList revamp.** A single sema-typed `channel.config`
   shape, with channel identity separated from capture policy
   (`AsyncCaptureDelta`, `CapturePeriodS`, `PollPeriodMs`). The zoo of
   per-component config types collapses. Problem statement:
   `wiki/gridworks-scada/executor/components.md` "The config list";
   the boot/round-trip harness is what lets it land.

## What the code becomes

```python
from sema.runtime.units import display
val, label = display(12150, "WaterTempCTimes1000")   # (53.9, "°F")
```

Deleted on landing: `gwsproto/conversions/temperature.py` (the
hand-written branch table this design generalizes) and the experiments
repo's interim shared `display.py`. Every repo that renders readings
stops hand-deriving conversions from enum description prose.

## Sequencing

One cascade, deliberately. gw1.units is published and foundational, so
restructuring it forces a version bump that rolls through every
referrer. The TelemetryName drop forces the same roll. Doing them
separately pays the cascade twice; this design exists so they are
scheduled as one move. Until it lands, the interim is the option-A
shape: per-repo conversion tables written from the enum descriptions
(cheap, correct, unverified against the prose).

## Boundary

Unit conversions are affine maps only. Sensor transfer curves (the
thermistor µV→°C step in the ads-noise experiment) are calibration and
stay in code. This design must not grow a curve mechanism.

## Alternatives considered

- **Per-repo conversion tables from the enum descriptions** (the
  status quo, `convert_temp_to_f` shape). Kept as the interim; rejected
  as the end state because nothing machine-checks a table against the
  prose, and the encodings straddle two enums with four temperature
  scalings.
- **A standalone `unit.projection` word** carrying pairwise
  `{Scale, Offset}` rows as registry-shipped instance data. Avoids the
  gw1.units republish, but invents a second mechanism (canonical
  instance data shipped with the registry) and its only virtue —
  cascade avoidance — disappears once the TelemetryName drop is
  scheduled anyway.

## Open

- The exact metadata shape on enum values is a sema spec change —
  change-controlled, grill before authoring. Includes: where the
  per-quantity display-unit preference lives, and whether display
  outputs may be `number`-typed.
- The `gw1.quantity` vocabulary itself (named in the OPS-407
  deferred-sweeps list; not yet designed).
- Scheduling: which milestone carries the cascade.

Next move: the spec grill on the metadata shape.
