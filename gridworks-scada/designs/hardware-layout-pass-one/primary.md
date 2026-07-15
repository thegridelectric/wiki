# Hardware layout — pass one (hub)

Status: Accepted · Pass 1 · Updated 2026-07-15 · Linear: OPS-407

**EDD: yes** — and the verification that *matters* is behavioral, not static. The real bar is a
House0-replicating simulated terminal asset (the sim plant, [OPS-40](https://linear.app/gridworks/issue/OPS-40);
harness in [`../../executor/testing.md`](../../executor/testing.md)) that runs the **actual scada code**
against an authored layout end to end — which is what tests the many lines this pass touches. The cheap
gates are: each home's `gw.house0.layout` / `gw.nolan.layout` is axiom-valid, and
`sema_to_dc(sema_gen(home_config))` loads cleanly. Exact content-equality to the frozen fixtures is a
**review aid** (diff to see what changed, then adopt the corrected fixture), **not** a strict gate —
being able to run House0 in sim means we don't have to be fussy about static byte-equality now.

**▶ Active spoke: [`operational-params.md`](operational-params.md)**

> What this is: the first critical pass on the scada hardware-layout / components model. Sema becomes
> the **authored source of truth** for a layout; the dc `HardwareLayout` the running scada loads is a
> generated **output** (`sema_to_dc`). Drop UUID `cac_id`s for a readable `gw1.device.type`
> `DeviceType`, simplify components, author every fleet home as sema, fill + complete the axioms
> (house0 **and** nolan), and regenerate `tests/config/` as sema-authored MVPs (+ obvious variants).
> A **shared dependency** (simulated-test-environment + spruce-unlimbo Chunk B), its own flat issue
> [OPS-407](https://linear.app/gridworks/issue/OPS-407). Part of the **Flexible SCADA: layouts &
> hardware** project (`https://linear.app/gridworks/project/flexible-scada-layouts-and-hardware-ce7472d7ef34`).

## The direction (the pivot — read this first)

Earlier the plan translated the legacy dc layout *into* sema (`dc_to_sema`) and used the dc fixture as
the truth oracle. **That is backwards.** Settled direction:

- **Sema is authored; dc is generated.** A home is authored as a sema layout (parameterized per home),
  validated against complete axioms. `sema_to_dc` projects it to the dc `HardwareLayout` the running
  scada loads. No actor migration is needed — scada keeps loading dc; dc just stops being a hand-frozen
  capture and becomes a projection of sema.
- **We want `sema_to_dc`, not `dc_to_sema`.** `dc_to_sema` leaves the ship path. Its worked-out
  field correspondence is harvested to build `sema_to_dc` (the inverse), then it is deleted, along with
  the `sema_gen_check` oracle and the `_to_new_convention` rename bridge.
- **The oracle flips to the dc side — and relaxes.** `sema_to_dc(sema_gen(config))` is diffed against
  the frozen fixture; the diff is a **review aid** (the worklist of what the gen still omits + what the
  stale fixture got wrong); corrected output (e.g. the added heat-call channels) is **adopted** as the
  new fixture. The strict gate is **behavioral** — House0 boots and runs against the sim terminal asset
  ([OPS-40](https://linear.app/gridworks/issue/OPS-40)) — not static byte-equality. Given the sim rig,
  we don't have to be fussy about exact fixture equality now.
- **`tests/config/` becomes sema-authored.** Each fixture is regenerated from its authored sema MVP;
  the obvious variants are added (beech **sieg** variant; House0Sieg vs no-sieg; zone/tank counts).
- **Pass-one keeps the current dc *shape*** — today's component decomposition. One slice of pass-two
  was pulled forward (2026-07-09, forced by the gw108 board replacing the krida panel at beech): relay
  node names are **functional** (`relay1` → `vdc-relay`), with the krida board position held in
  `RelayIdx`, not the name. The board-resident / i2c-bus actor model stays **pass-two**
  ([`i2c-board-components.md`](i2c-board-components.md)).

## Spokes (in order)

- ✅ **device-type + component vocabulary** — `cac_id` → open `pascal.case` `DeviceType`; the full
  migrated sema component vocabulary; `g.node.gt`; typed-hydronic promotion. Distillate in
  [`../../executor/hardware-layout.md`](../../executor/hardware-layout.md).
- ✅ **channel-config overhaul** ([OPS-427](https://linear.app/gridworks/issue/OPS-427)) — landed
  2026-06-26; the `ChannelConfigBase` family carries neither `Unit` nor `Exponent`; the
  `transactive-power` metering boundary. Notes in [`gleanings.md`](gleanings.md).
- **[`layout-boundary.md`](layout-boundary.md)** — *the pass's core statement.* What a layout IS (static
  physical topology + control nodes) vs is NOT; the **three-artifact split** (config / layout / operational
  params, the [`operational-params.md`](operational-params.md) spoke); the rewiring test; the bare
  `channel.config` base type is **removed** (specialty `ConfigList`s only); **sema axioms as sole validity
  authority** (drop the dc
  `check_*`); forward-only transforms; **sieg as its own layout**; the board is not a layout factor.
- **[`operational-params.md`](operational-params.md)** — *active.* The third artifact
  `operational-params.json`: capture tuning + `SystemMode` + criticality/thermal-mass + FLO knobs split
  out of config + the static layout, with `ops_and_sema_to_dc` assembly. Forces the `channel.config`
  collapse; do it before the fleet gen files (the shape every gen targets). The LTN live-update transport
  is [OPS-408](https://linear.app/gridworks/issue/OPS-408) (Thomas), the consumer.
- ✅ **[`sim-run.md`](sim-run.md)** — *done.* The behavioral safety net: the scada boots + runs every
  device code path on `gw-dev-rabbit` with self-generating `SimSensorActor`s.
  Shipped (`b4623fe1`/`d8ce5570`/`822b150c`); it's the gate the rest of the pass verifies
  through. Richer coherent plant stays [OPS-40](https://linear.app/gridworks/issue/OPS-40).
- **[`code-for-three-layouts.md`](code-for-three-layouts.md)** — What `gw_spaceheat`
  must change to run three layouts: discriminate by `TypeName`, a **command tree per layout**
  (House0 keeps pico-cycler/hp-boss/sieg; simple_sim is minimal, **no pico-cycler**; nolan its own), and
  the on-disk naming answer. The pass-one cut is the smallest change that boots `gw1.simple.sim.layout`.
- ✅ **[`universe-guardrail.md`](universe-guardrail.md)** — *done (boot check).* The **universe** model
  (first alias segment = `d1`/`hw1`/single-production `w`) and the scada-side boot check
  (`universe_of(alias) == universe_of(broker_host)`, `localhost ⇒ d1`). Shipped (`822b150c`), with
  `sim_layout.py` dev-ifying aliases. The layout-internal sema axiom stays deferred (in the spoke);
  the hard server-side boundary (rabbit perms) is a `gridworks-base` follow-on.
- **[`gen-pipeline.md`](gen-pipeline.md)** — The authoring pipeline: per-home config →
  `sema_gen` → axiom-valid sema → `sema_to_dc` → dc fixture; retire `dc_to_sema`; the diff-and-adopt
  review aid; fleet status (oak ✅, elm/fir/beech-sieg/maple remaining); regenerate `tests/config/`.
  References [`generator-blueprint.md`](generator-blueprint.md) for the gen spec.
- **[`axioms.md`](axioms.md)** — finish the layout axioms, **house0 and nolan** this pass, each with a
  generated counterexample (the gen is the fixture factory).
- **[`sieg-primary-flow.md`](sieg-primary-flow.md)** — the deferred Siegenthaler / `primary-flow`
  behavior test (rides the simulated-plant focus).
- **[`i2c-board-components.md`](i2c-board-components.md)** — the board-resident / i2c-bus actor model.
  **Deferred to pass-two** (own chunk). The sema vocabulary is fully authored ahead (2026-07-03:
  `relay.control.config`, `i2c`/`gpio.relay.component.gt`, `gw1.device.type/001`; 2026-07-09: the
  capability reshape — `i2c.*.capability` + `i2c.expander` — and the krida board record) and the
  functional-naming slice landed in pass-one, so pass-two needs no further sema round; the actor
  wiring + layout migration stay pass-two.
- **[`gleanings.md`](gleanings.md)** — durable domain context (field reality, Nolan↔Spruce naming),
  the sema-source-of-truth working method, and the deferred sweeps.

## What's landed (short pointers)

- The device-type model (`cac_id` → `pascal.case` `DeviceType`), full sema component vocabulary, the
  scada↔gwta **component** round-trip (27/27), and the **full-layout** round-trip for all five House0
  homes via the (now-retiring) `dc_to_sema` path. The commit-by-commit story is in the changelogs
  (`wiki/{sema, gridworks-scada, gridworks-terminalasset}/changelog.md`); the durable distillate is in
  [`../../executor/hardware-layout.md`](../../executor/hardware-layout.md).
- The sema-native gen, authoring-side in **tlayouts on the sema snapshot** (2026-07-04):
  `tlayouts.house0_sema_gen.gen_artifacts` emits each home's (static layout, operational params)
  pair, snapshot-validated; oak + house0-stub gens live (`gen_oak_sema.py`, `gen_house0_stub_sema.py`);
  scada keeps the consuming side (`gw_spaceheat/sema_to_dc.py`: `assemble_runtime_layout` /
  `ops_and_sema_to_dc` + the file-based diff-and-adopt oracle). The `house0_sema_gen_check.py`
  equivalence oracle retired with the move. Detail in [`gen-pipeline.md`](gen-pipeline.md).
- Channel-config overhaul landed (scada `jm/delete-cac-id`, sema `jm/sim-vocab`); suites green.
- The operational-params reshape, sema side + gwsproto catch-up: `capture.tuning/000`, the
  `channel.config` family strip, `gw.house0.operational.params/000` (the four 2026-06-30
  `wiki/sema/changelog.md` entries); gwsproto `CaptureTuning` + `GwHouse0OperationalParams`,
  `channel_config.py` deleted (`9fe86665`). Detail in [`operational-params.md`](operational-params.md).
- The board-resident relay vocabulary, authored ahead of pass-two (sema `11be3be` + `fae8d27`,
  2026-07-03): `relay.control.config/000`, `i2c.relay.component.gt/000` / `gpio.relay.component.gt/000`,
  `gw1.device.type/001`. Notes in [`i2c-board-components.md`](i2c-board-components.md).
- Functional relay names + the capability round (2026-07-09; scada `4182d88c`/`ba6c6e65`/`7000d3a7`,
  sema `3c7e3fb`, tlayouts `d75cae0`): relay nodes named by function with board position in `RelayIdx`;
  the `i2c.*.capability` + `i2c.expander` board vocabulary and the `KridaDoubleRelayBoard16` record in
  oak's `DeviceTypes`, with the relay mux resolving pins from the record instead of `gw_to_pin`;
  sema-authored oak adopted (heat-call DerivedChannels frozen, oracle at 0 diffs). Notes in
  [`i2c-board-components.md`](i2c-board-components.md).
- The operational-params control block end to end (2026-07-13/15; sema `7657167`, tlayouts `b69e483`,
  scada `ce2522c8` + `82caac3e`): `cop.curve`/`heating.curve` + the inline control scalars on
  `gw.house0.operational.params`, the gen's required `OpsSpec`, the gwsproto twins, and the scada
  loading the authored artifact — 45 actor read sites off settings, the 22 fields deleted from
  `ScadaSettings`. Detail in [`operational-params.md`](operational-params.md).
- gwta snapshot rebuilt to the capability vocabulary + a catch-up to current sema (2026-07-15,
  `0a18bd7`); snapshot round-trip green (47 samples).

## Carried caveats

- **Fleet fixtures other than oak are stale on the heat-call axis** — each carries the
  `*-whitewire-pwr` source DataChannel but no per-zone `*-heat-call` DerivedChannel (house0 Axiom 3).
  Resolved by regenerating each fixture from sema, as oak was (`4182d88c`), not by patching JSON.
- **`gw.nolan.layout/000`** is un-drafted; its axioms are parked in
  `sema/definitions/types/gw.nolan.layout/stash_axioms.md` (zone/tank structure reference).
- **`gw.house0.layout/000` is `staging` → mutable in place** — axioms are added to `000` directly
  (no bump). The whole layout cluster is staging under the OPS-445 status model (dev brokers only);
  it promotes via `sema promote` when this pass settles, and scada's conformance sweep
  `--release-gate` stays red until then.
- **An orphaned nolan intent from the deleted `jm/nolan` sema branch** (May-14 WIP, never in dev):
  `gw.nolan.layout/000` gains `gw1.heat.call.interpretation:000` as an axiom dependency (it also
  sketched a `gw1.scada.device.type.gt/001` that was never authored). If still wanted, fold it into
  the staging `000` directly when nolan's axioms are drafted.
- **Layout `examples:` regenerate from the gen, never by hand** — the main sema suite decodes every
  example through the generated runtime (OPS-442), so a reshape that stales an embedded example is
  caught in CI; the fix is re-emitting from the tlayouts gen.
- **Deep code clean is pass-two:** ripping out `H0N`/`H0CN` (~61 files), the ~76 call-site sweep onto
  `self.hydronic.*`, the full actor migration onto sema types, the G/H RequiredTopologyNodes axioms.
  Pass-two is gated on the sim plant ([OPS-40](https://linear.app/gridworks/issue/OPS-40)) — a
  migration that wide verifies behaviorally, against the simulated terminal asset, before it starts.
