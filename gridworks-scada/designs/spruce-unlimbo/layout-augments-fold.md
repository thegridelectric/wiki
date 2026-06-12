Status: Draft · Pass 0 · Updated 2026-06-11

# Folding jm/layout-augments into jm/spruce-unlimbo

> What this is: spruce-unlimbo spoke (Chunk B, the layout pipeline) — a
> curated **carry / skip** list for folding the `jm/layout-augments` branch
> into `jm/spruce-unlimbo`. Judgment from a **look-through, not a mechanical
> diff**; lossy is fine (Jessica: better to drop a change than over-reconcile).
> Parked here so it stops being a dangling task.

## The branch

`jm/layout-augments` is ~20 commits, ~167 files, ~7.7k insertions — a big
refactor: `layout_gen/` restructured to `core/`/`builders/`/`subsystems/`, the
`names/` namespace, new enums/types, `gw.nolan.layout`, and a
`DerivedChannelGt` v001→v002 rework. `jm/spruce-unlimbo` is ~67 commits ahead
of the merge-base on its own line, so this is a hand-reconcile, not a clean
merge.

## Carry / skip (judgment — confirm against spruce's current state when folding)

**The one worth carrying — `DerivedChannelGt` v001→v002 + axioms.** The real
value, and it's exactly the rework that's been biting us. v002 adds
`InputChannelNames`, `OutputQuantity` (+ `UnitQuantityProjection` validation),
and axioms: affine ⇒ `Calibration` in Parameters, system-model ⇒ `EnergyModel`.
It carries the **strategy renames** (`linear-fit`→`affine`,
`layer-by-layer`→`system-model`) and the `EmissionMethod`/`EmitPeriodS` fields
that the stale-`oak` migration hit. Folding this is what would have made that
migration a lookup instead of archaeology — and it overlaps the sibling
dangler "a sema home for the strategy names." Medium reconcile: audit spruce's
derived-channel instances + test configs, add the new fields, rename
strategies (layout-augments' updated test configs are the template).

**Probably already in spruce — confirm, then no-op.** This session found
spruce already has several things the look-through flagged as "carry":
- `i2c.multichannel.dt.relay.component.gt` is at **v004 with `I2cBus`** —
  spruce has it (the agent guessed v002→v003; wrong).
- the **Relay actor already branches** Gw108-GPIO vs i2c-multiplexer.
- the `names/` namespace, `EmissionMethod`/`GpioSenseMode`/`HeatCallInterpretation`,
  `Gw108GpioRelay/SensorComponentGt`, `TelemetryNameQuantityProjection`,
  `SpaceheatNodeGt` v301 axioms — all present.
  Confirm each in a quick pass; don't re-carry.

**Maybe — small, low cost.** `UnitQuantityProjection` (output-unit↔quantity
validation, one file); a standalone `GpioSensor` actor if spruce lacks one.

**Skip — phase-2, not worth the churn now.**
- The whole `layout_gen/` restructure (core/builders/subsystems, `LayoutIDMap`,
  `genlayout.py`→`layout_cli.py`) — spruce's incremental layout_gen works;
  this is a high-churn reorg that undoes spruce's progress. Adopt only if/when
  we commit to the new structure wholesale.
- `ScadaDeviceTypeGt` (the `Cac → device.type.gt` rename) — a whole-codebase
  migration; bring in deliberately, not as part of this fold.
- `I2cReadBit`/`WriteBit`/`Result` + the new `i2c_bus`/`i2c_relay_board`/
  `i2c_thermistor_board` actors — unused in spruce; carry only when building
  out I2C-bus orchestration.

## If you carry one thing

`DerivedChannelGt` v002 + its axioms (with the strategy renames and
`EmissionMethod`/`EmitPeriodS`). It's the genuinely-ahead piece, it un-dangles
the strategy-semantics question, and the test-config template is right there.
Everything else is either already in spruce or phase-2.

## Caveat

These are judgments from reading the branch, not a verified merge. The
"already in spruce" list especially wants a 5-minute confirm at fold time —
the look-through already misjudged `I2cBus` and the relay polymorphism, so
trust but verify.
