# The authoring pipeline — sema_gen → sema_to_dc (spoke)

Status: Accepted · Pass 1 · Updated 2026-07-15 · Linear: OPS-407

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
  by name from a reference layout (`LayoutIDMap`). Full house0-stub equivalence reached and **oak
  passes** (real 4-zone / 3-tank production home). **Channel UUIDs — DataChannels and DerivedChannels
  alike — are durable identity, keyed by `(home, channel name)`:** the archive's time series join on
  channel id, so a re-mint splits a channel's history. The gen mints an id only for a name absent from
  the reference; adoption is the mint-once event that promotes new ids into the stable reference (a
  *renamed* channel is deliberately a new channel — new id, new series).
- **`sema_to_dc(sema_layout)`** projects the sema layout to the dc `House0Layout` the running scada
  loads. **Built** (`gw_spaceheat/sema_to_dc.py`), forward-proven on oak — `sema_to_dc(sema_gen(oak))`
  loads cleanly. The projection plumbing already existed as `sema_to_layout_dict` inside the retiring
  `house0_bijection.py` EDD harness; `sema_to_dc` moves it to a durable module and wraps
  `House0Dc.load_dict`. `dc_to_sema` still backs the gwta round-trip, so its deletion stays a separate
  follow-on (below).

**Per the layout-boundary split ([`layout-boundary.md`](layout-boundary.md)), the pipeline forks the
authored side and the transform becomes `ops_and_sema_to_dc`:** the gen authors **both** the static
`gw.house0.layout` (no capture params) **and** a first-pass `operational-params.json` (the capture tuning
stripped from `channel.config`), and `ops_and_sema_to_dc(static ⊕ ops)` assembles the runtime dc — whose
`channel.config` is whole again, so device actors are unchanged. This is pass-one work (the
`channel.config` reshape forces it); the operational-params artifact is built this pass in the
[`operational-params.md`](operational-params.md) spoke. **Both halves are built (2026-07-04):** the
tlayouts gen emits the two artifacts per home (`gen_artifacts`), and scada's
`sema_to_dc.assemble_runtime_layout` / `ops_and_sema_to_dc` reassemble them with the coverage +
poll-floor checks — proven end to end on oak (assembled dc loads; only the known stale-fixture
DerivedChannels diff remains to adopt).

## Where the gen files live — everything authoring-side in `tlayouts` (moved 2026-07-04)

- **The gen machinery lives in `tlayouts`, on the sema snapshot** (`src/tlayouts/house0_sema_gen.py`
  + `src/tlayouts/sema/` + the `src/tlayouts/names/` mirror + `layout_id_map.py`): no gwsproto, no
  scada venv — `uv run python gen_<home>_sema.py` is the whole authoring stack. This supersedes the
  earlier machinery-in-scada split: the gen is authoring-side and belongs with the per-home gen
  files. The ported gen builds the STATIC sema shape natively (the snapshot component types reject
  capture params) and accumulates `capture.tuning` as the emitters run; `gen_artifacts(config,
  reference)` returns the (static layout, operational params) pair, both snapshot-validated before
  writing.
- **Per-home gen files — `tlayouts/gen_<home>_sema.py`:** each home's config inline (oak +
  house0-stub moved out of the retired `house0_sema_gen_check.py`), alongside the legacy dc-based
  `gen_oak.py`/… until those retire.
- **Scada keeps the consuming side** — `gw_spaceheat/sema_to_dc.py`: `assemble_runtime_layout` /
  `ops_and_sema_to_dc` (static ⊕ ops → runtime dc, with the coverage + poll-floor checks) and the
  file-based diff-and-adopt oracle.
- **Two outputs, both sema-authored:** production layouts → **`tlayouts/output/<home>/`**
  (`gw.house0.layout.json` + `gw.house0.operational.params.json`); test fixtures →
  **`gridworks-scada/tests/config/`** (adopted from the assembled artifacts). The same per-home
  config feeds both.
- **Naming vocabulary OFI:** `src/tlayouts/names/` is a mirror of `gwsproto/names` pending the
  names-in-sema design (encode the closed name sets as sema enums, the zone/tank/flow patterns as a
  naming word; gridworks-terminalasset needs the same vocabulary) — see the mirror's README.

## Retire dc_to_sema

`dc_to_sema` was the Phase-2 "translate legacy dc *into* sema" bridge; under the pivot, dc is an output,
so the reverse direction is dead weight on the ship path. Sequence:

1. ✅ Build `sema_to_dc` (`gw_spaceheat/sema_to_dc.py`) — done; `sema_to_layout_dict` moved there out
   of the `house0_bijection.py` harness (and the vestigial `gnode_src` kwarg + dead imports dropped).
2. Move the gwta wire round-trip (`layout_roundtrip.py`) onto a tlayouts-authored layout instead of
   `dc_to_sema(load(...))` — nothing on the ship path needs the reverse.
3. Delete `dc_to_sema` and the `_to_new_convention` rename bridge (a temporary comparison-target
   hack). ✅ The `house0_sema_gen_check.py` equivalence oracle went early (2026-07-04), deleted with
   the gen's move to tlayouts — its `_canon` lives on in `sema_to_dc.py`, its per-home configs in
   the tlayouts gen files.

## The oracle — diff-and-adopt, relaxed

The static check flips to the dc side and **relaxes to a review aid** (the real gate is behavioral —
House0 runs in sim — the sim-boot harness, [`../../executor/testing.md`](../../executor/testing.md)).
Implemented as `sema_to_dc.diff_against_fixture(home)`
(canon, order-insensitive). Oak has been through the full cycle: the gen ran ahead of the frozen
fixture (19 vs 15 DerivedChannels — the 4 per-zone `heat-call` the stale fixture lacked), the
corrected output was adopted (`4182d88c`/`7000d3a7`), and the oracle sits at 0 diffs:

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
