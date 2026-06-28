# The authoring pipeline — sema_gen → sema_to_dc (spoke)

Status: Accepted · Pass 1 · Updated 2026-06-27 · Linear: OPS-407

> What this is: the one flow that makes sema the authored source of truth and the dc layout an output.
> `per-home config → sema_gen → axiom-valid gw.house0.layout → sema_to_dc → the dc HardwareLayout the
> scada loads`. `sema_gen` (authoring) and `sema_to_dc` (projection) are two halves of one pipeline —
> kept in one spoke. The detailed gen spec (required node/channel sets, the four config axes, per-
> position sourcing) is in [`generator-blueprint.md`](generator-blueprint.md).

## The pipeline

```
per-home config ──sema_gen──▶ gw.house0.layout (sema, axiom-valid) ──sema_to_dc──▶ dc HardwareLayout
                                                                                    (what scada loads)
```

- **`sema_gen(config)`** emits a `gw.house0.layout` directly from a per-home config, pulling stable IDs
  by name from a reference layout (`LayoutIDMap`). Already landed: `gw_spaceheat/house0_sema_gen.py`.
  Full house0-stub equivalence reached and **oak passes** (real 4-zone / 3-tank production home).
- **`sema_to_dc(sema_layout)`** projects the sema layout to the dc layout dict the running scada loads
  (then `House0Dc.load()`). **To build.** It is the inverse of the retiring `dc_to_sema` — harvest that
  function's worked-out field correspondence to write it, then delete `dc_to_sema`.

**Per the layout-boundary split ([`layout-boundary.md`](layout-boundary.md)), the pipeline forks the
authored side and the transform becomes `ops_and_sema_to_dc`:** the gen authors **both** the static
`gw.house0.layout` (no capture params) **and** a first-pass `operational-params.json` (the capture tuning
stripped from `channel.config`), and `ops_and_sema_to_dc(static ⊕ ops)` assembles the runtime dc — whose
`channel.config` is whole again, so device actors are unchanged. This is pass-one work (the
`channel.config` reshape forces it); the operational-params artifact is built this pass in the
[`operational-params.md`](operational-params.md) spoke.

## Retire dc_to_sema

`dc_to_sema` was the Phase-2 "translate legacy dc *into* sema" bridge; under the pivot, dc is an output,
so the reverse direction is dead weight on the ship path. Sequence:

1. Build `sema_to_dc` by inverting `dc_to_sema`'s field mapping (`gw_spaceheat/house0_bijection.py`).
2. Move the gwta wire round-trip (`layout_roundtrip.py`) onto a `sema_gen` layout instead of
   `dc_to_sema(load(...))` — nothing on the ship path needs the reverse.
3. Delete `dc_to_sema`, the `house0_sema_gen_check.py` equivalence oracle, and the
   `_to_new_convention` rename bridge (a temporary comparison-target hack).

## The oracle — diff-and-adopt, relaxed

The static check flips to the dc side and **relaxes to a review aid** (the real gate is behavioral —
House0 runs in sim, [`sim-run.md`](sim-run.md)):

1. Author the home's sema (axiom-valid, **with** heat-call etc.) → `sema_to_dc` → generated dc.
2. **Diff generated-dc against the frozen fixture.** The diff is the worklist: where the gen omits a
   builder (close it) and where the *stale fixture* is wrong (e.g. it lacks the per-zone heat-call
   DerivedChannel — all six fixtures fail house0 Axiom 3 today).
3. **Adopt** the corrected generated-dc as the new fixture. Comparison is content + id, order-
   insensitive (`_canon` sorts each collection by a stable key — list position is historical authoring
   order, not semantics).
4. After adoption, `generated-dc == fixture` is a cheap regression lock. The strict gate stays the
   sim-run boot.

## Regenerate tests/config/ as sema-authored MVPs (+ variants)

`tests/config/` stops being hand-frozen captures and becomes **sema-authored**: each home's MVP layout
authored as sema, projected to the dc fixture. Add the **obvious variants** the fleet needs:

- **beech sieg variant** — beech is `SiegLoopPlumbed=true, UseSiegLoop=false, PrimaryFlowSource=Measured`
  (a mechanical sieg loop, not controlled). maple is the controlled `DerivedSiegSum` case.
- **House0Sieg vs House0 no-sieg**, zone count (2/4), tank count.

On-disk naming: per the wiki Sema-typed-JSON convention the canonical instance is
`gw.house0.layout.json`; the multiple per-home test fixtures keep home names (`maple.json`, …) as
`gw.house0.layout` instances. (Confirm naming with JM when regenerating.)

## Fleet status

- ✅ **house0 stub + oak** — `sema_gen` content+id-equal to the dc layout, UUIDs preserved across the
  relay-name rename. oak proved the full real-device builder set: eGauge (`PwrChannelSpec` register
  map), ADS analog-temp (`AdsChannelSpec`), Reed flow meters (`FlowSpec`), real `pico.tank.module` +
  affine depth calibration (`TankSpec`), multi-zone relays/thermostats.
- ▶ **elm + fir** — same no-sieg shape; each home's bespoke device-map config.
- ▶ **beech + maple** — add the **sieg loop** (SiegLoopPlumbed/UseSiegLoop, sieg manifold relays, the
  BTU meter + `DerivedSiegSum` primary-flow). beech also gets its plain sieg variant.

**Key insight from oak — the fleet is config-BESPOKE, not just an invariant skeleton.** Real devices
carry hand-specified per-home data the config must encode: the eGauge per-channel `EgaugeRegisterConfig`
(unique modbus `Address` + register name) + `ModbusHost`/`HwUid`; the ADS i2c/terminal map; flow-meter
and tank-pico hardware UIDs; uppercase pwr display names; even invariant-looking nodes differ
(`hp-odu` display "Hp Odu" on oak vs "HP ODU" on the stub). So the gen config grows a **per-home device
map** fed to generic emitters — the config object, not just the builders, is the bulk of the fleet work.

## The closing step — migrate the OLD gen too (only if dc_to_sema survives transitionally)

Historically the harness bridged a rename in-memory (`_to_new_convention`). Under the pivot that bridge
is deleted with `dc_to_sema`. The durable principle survives: **changing the implicit House0 shape means
the dc side changes in lockstep** — when the authored sema adds/removes a channel or node (e.g. the
per-zone `heat-call` DerivedChannel: all production houses get one, all but spruce derive it from
whitewire power), `sema_to_dc` emits it and the regenerated fixture carries it. The mismatch that used
to be a bug is now simply the diff the adopt step resolves.
