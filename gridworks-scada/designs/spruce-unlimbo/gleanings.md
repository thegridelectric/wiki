# Gleanings (spoke)

Status: Draft · Pass 0 · Updated 2026-08-11 · Linear: OPS-392

> What this is: residual live content from closed spokes — parked
> judgments and still-relevant survey facts that no longer warrant
> their own file. Closed into here 2026-08-11: `both-cases-survey.md`
> (the 2026-06-10 survey; resolved and stale parts dropped — git
> history keeps the full record), `layout-augments-fold.md`, and
> `nolan-layout-sema.md` (its zone-model gotchas resolved into
> `zone-relays-and-thermostat-model.md`).

## From the both-cases survey (2026-06-10, still relevant)

- **Lock-step coupling:** a tlayouts branch only works with the scada
  branch whose `layout_gen`/gwsproto it imports; tlayouts `jm/spruce`
  pairs with the spruce line (100×-scaled calibration ints, no
  `add_relays()` — cannot generate House0 layouts). Retiring the
  coupling is chunk B.
- **"Testing green for BOTH" structurally requires:** layout
  selection parameterized (pytest option or CI matrix, not the
  conftest nolan hardcode); layout-specific assertions keyed off the
  layout strategy or split per-case (`test_admin`'s explicit-override
  pattern generalized); un-skip `test_layout_gen` once the layout-gen
  rework lands.
- **Shared local-control skeleton:** one loader (Standby /
  AllTanksTou / BufferOnlyTou by SystemMode + SeasonalStorageMode),
  `LocalControlTouBase` 60 s loop; `ShNodeActor` hardcodes
  `H0N`/`H0CN` names throughout — the both-cases blocker at the code
  level. House0 FSM states: Initializing / HpOffStoreOff /
  HpOnStoreOff / HpOnStoreCharge / HpOffStoreDischarge / Dormant.
- Open: the tlayouts `new-builder` branch's purpose is unclear —
  check before deleting.

## The layout-augments fold (carry/skip, judged 2026-06-11)

`jm/layout-augments` is ~20 commits / ~7.7k insertions; the fold is a
hand-reconcile, lossy is fine (better to drop a change than
over-reconcile).

- **The one worth carrying: `DerivedChannelGt` v001→v002 + axioms**
  (`InputChannelNames`, `OutputQuantity` + `UnitQuantityProjection`,
  strategy renames `linear-fit`→`affine` /
  `layer-by-layer`→`system-model`, `EmissionMethod`/`EmitPeriodS`).
  Audit spruce's derived-channel instances + test configs;
  layout-augments' updated test configs are the template.
- **Probably already in spruce — confirm, then no-op:**
  `i2c.multichannel.dt.relay.component.gt` v004 with `I2cBus`; the
  relay actor's Gw108-vs-multiplexer branch; the `names/` namespace;
  `EmissionMethod`/`GpioSenseMode`/`HeatCallInterpretation`; the
  Gw108 GPIO component types; `SpaceheatNodeGt` v301 axioms.
- **Maybe (small):** `UnitQuantityProjection`; a standalone
  `GpioSensor` actor if spruce lacks one.
- **Skip:** the `layout_gen/` restructure (core/builders/subsystems,
  `LayoutIDMap`, `layout_cli.py`) — high-churn reorg; adopt only
  wholesale and deliberately. `ScadaDeviceTypeGt` (the `Cac` →
  `device.type.gt` rename) — whole-codebase migration, bring in
  deliberately. (The branch's I2c-bus actor carry is superseded — the
  bus is built and window-verified in place.)
- **Caveat:** judgments from a look-through, not a verified merge —
  the look-through misjudged `I2cBus` and the relay polymorphism, so
  confirm the "already in spruce" list at fold time.

## Closing `gw.nolan.layout` (parked; rides the epic-end promote)

The type exists (`sema/definitions/types/gw.nolan.layout/000.yaml`,
draft, ~25 axioms; `jm/nolan` holds WIP: a
`gw1.scada.device.type.gt` 000→001 ref bump, axioms-into-registry).
Close AFTER the layout-augments fold — the layout type references the
folded component/derived-channel shapes — and WITH the epic-end
promote (sequencing in `zone-relays-and-thermostat-model.md`):
finalize registry status, regenerate, validate against real layouts,
sema authoring discipline throughout.
