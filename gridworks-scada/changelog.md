# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-scada` code repo**. The matching git commit (in
`gridworks-scada`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-06-15 — Tank calibration v001 + retire stored TankTempCalibrationMap from layout (`5e6008df`)

**What (calibration v001):** Aligned gwsproto with the sema v001 calibration:
`LinearOneDimensionalCalibration`, `TankTempCalibration`, `TankTempCalibrationMap` → v001 with
`B`/`Depth*B` as **integer in the OutputUnit (FahrenheitX100)** domain. Fixed
`derived_generator.handle_affine` to compute `temp_x100 = int(M·(x_f·100) + B)` (apply B in
FahrenheitX100) — byte-identical to dev's working `int((M·x_f + B_f)·100)` with `B = B_f·100`.
Regenerated all 7 fixtures; the five real homes' calibrations are George's exact values sourced from
**dev/main × 100** (fixing the jm/spruce hand-shift, e.g. beech tank3 depth1 −481 → −108).

**What (retire stored map):** The layout no longer stores a `TankTempCalibrationMap` — each tank
depth's calibration lives in its (`identity`/`affine`) derived channel, the single source of truth.
Dropped the required key + loading + cross-check in `house_0_layout.py` (replaced
`validate_tank_temp_calibration_consistency` with a per-depth well-formed-derived-channel check);
`layout_db` stops writing `misc["TankTempCalibrationMap"]` (tmap stays a generation-time input);
`scada.py` stops passing `TMap` into `LayoutLite` (the Optional field now defaults None — a later
`layout.lite` bump can remove it). Removed the dead `process_synced_readings` / `_depth_calibration`
/ `hack_maple_primary_flow` cluster (the orphaned `self.tmap` path — `process_synced_readings` was
never dispatched; the active path is `handle_input_reading → _dispatch_derived_input → handle_affine`).

**Why:** the prior state mis-calibrated (B hand-shifted to FahrenheitX100 ints but `handle_affine`
applied it as °F); v001 makes value + code consistent, and the derived channels become the lone
calibration home. **Carried caveat:** removing `hack_maple_primary_flow` leaves maple's `primary-flow`
(= `sieg-send + sieg-flow`) **uncomputed** — see the design TODO (the `sum` strategy). Scada suite
green (114); gen scripts in the tlayouts repo.

## 2026-06-15 — WIP: add pico.btu.meter to House0Layout Components union (`fbebebc1`)

**What:** Added `PicoBtuMeterComponentGt` to the gwsproto `House0Layout` Components union (beech/
maple carry btu meters). WIP slice of the house0-layout build-up.

## 2026-06-15 — Add real-home runtime fixtures (beech/oak/maple/elm/fir) (`640a0d33`)

**What:** Added `tests/config/{beech,oak,maple,elm,fir}.json` — the five real House0 homes regenerated
from the (whipped-into-shape) tlayouts `gen_*.py` against the current scada layout_gen. Each loads as
`House0Layout` (beech 83 nodes/76 ch, oak 85/82, maple 78/73, elm 86/83, fir 87/84; 14 derived each)
and carries valid `g.node.gt` GNodes (promoted from the legacy flat shape, key-derived
BaseClass/GNodeClass + PositionPointId). Suite green (114).

**Why:** real per-home layouts as runtime test fixtures, replacing reliance on only the synthetic
nolan/house0 fixtures. The generators live in the tlayouts repo; this commit is just the generated
fixtures consumed by the scada tests.

## 2026-06-15 — Promote layout GNodes to g.node.gt; House0 dc↔sema bijection harness (`69ab5564`)

**What:** Promoted the layout's GNode representation to `g.node.gt/004`. `layout_db.py` emission and
both fixtures (`house0`/`nolan-layout.json`) now carry `g.node.gt`-shaped GNode entries —
`BaseClass` + `GNodeClass` aligned (axiom 1), `GNodeStatus → Status`, `PositionPointId` for the
non-Logical LTN/TA (axiom 2), Scada as `BaseClass: Logical`, and legacy `AtomicTNode →
LeafTransactiveNode`. The `g_node_alias`/`_id` accessors read `Alias`/`GNodeId` and were untouched.
Added `gw_spaceheat/house0_bijection.py` — the `dc → sema → dc` EDD harness.

**Why:** the bijection is the EDD proof that `gw.house0.layout` encodes every part of the
production House0 data-class layout. It showed all categories encoded except GNodes (loose legacy
dicts); promoting them to `g.node.gt` closes it — the harness now reports all 7 categories encode
and the GNode round-trip is identical. Scada suite green (114).

## 2026-06-15 — House0Layout + SimpleSimLayout layout types; layout round-trip return (`d1f5b0e6`)

**What:** Hand-ported the three layout types into gwsproto to match the Sema snapshot (Sema is the
source of truth). `House0Layout` (`gw.house0.layout`) carries the full shape mirroring the sema type
— optional `GNodes`/`ShNodes`/`DataChannels`/`DerivedChannels`/`Components` (House0 oneOf union) /
`DeviceTypes` (`ComponentAttributeClassGt` stand-in, like the Nolan scaffold) / `Hydronic`, with
only TypeName+Version required. `SimpleSimLayout` (`gw1.simple.sim.layout`) is the minimal stub. The
existing Nolan scaffold class was renamed `GwNolanLayout` → `NolanLayout` (file → `nolan_layout.py`)
for the agreed short local names; `House0Layout` + `SimpleSimLayout` registered in
`named_types/__init__`. Added `gw_spaceheat/layout_roundtrip_return.py` — the scada side of the
bidirectional layout round-trip (decodes + re-encodes a sent layout through gwsproto).

**Why:** Completes the sema→snapshot→gwsproto loop for the layout baselines; the round-trip
(`gridworks-terminalasset/layout_roundtrip.py` ↔ this return script) is green for house0 +
simple.sim. Scada suite green (114).

## 2026-06-14 — layout_gen: rebuild simulated tanks (new device-type model); green the suite (`955869b7`)

**What:** Greened the scada suite after the cac→DeviceType migration. (1) Rebuilt
`layout_gen/simulated_tanks.py` in the new device-type model — the deleted file used the gone
`MakeModel.GRIDWORKS__SIMMULTITEMP` / `ComponentAttributeClassId` / `make_cac_id` /
`CACS_BY_MAKE_MODEL` APIs; the rewrite registers a `gw1.device.type` record
(`GridworksSimSensor`) and emits `SimPicoTankModuleComponentGt(DeviceType=…)`, mirroring the
already-migrated `tank3.py`. (2) Re-wired `add_simulated_tanks` + the per-tank loop back into
both `fixture_layouts.py` builders, so the `*-depth{i}-device` channels the
`add_house0_derived_channels` tank-depth derived channels depend on exist again (buffer + tank1,
matching `TotalStoreTanks=1`). (3) Regenerated `tests/config/{nolan,house0}-layout.json` to the
DeviceType shape via `genlayout mktest`. (4) Fixed `show_layout.py`'s `print_component_dicts` to
join cacs by `DeviceType` (was `ComponentAttributeClassId`). (5) Fixed the `tests/named_types/*`
sample dicts — `ComponentAttributeClassId` → `DeviceType`, and bumped the stale `Version`
literals to the single current runtime version (`spaceheat.node.gt` 301→302, i2c.thermistor
001→002, i2c.multichannel 004→005, pico.tank 011→012, pico.flow 000→001).

**Why:** the in-suite `layout_gen`-green for both real layouts is the sub-gate of the
hardware-layout pass-one EDD bar (the real verification is the gwta round-trip). Suite now
114 passed / 3 skipped. The sim tank module's purpose is to exercise the `api_tank_module.py`
actor in unit tests. OPS-407.

## 2026-06-15 — gwsproto: add g.node.gt + its enums; GwNolanLayout scaffold (`a0210a00`)

**What:** Hand-ported from the gwta sema snapshot runtime: `GNodeGt` (`g.node.gt/004`, with all
5 axioms — ClassConsistency / PhysicalGNodeLocations / AliasTransitionConsistency /
GNodeClassNamespacing / AliasSuffixSemantics) and its two enums `BaseGNodeClass`
(`base.g.node.class`) + `GNodeStatus` (`g.node.status`), in gwsproto idiom (AslEnum / BaseModel /
property_format, PascalCase fields). Registered in the enum + named_type `__init__`. Also added a
`GwNolanLayout` scaffold (`gw.nolan.layout`, full structure, axioms as a commented TODO block;
`GNodes` now typed `List[GNodeGt]`). And `ads111x.based.component.gt`: the `OpenVoltageByAds`
Near5 field-validator became `check_axiom_1` (OpenVoltageByAdsRange [4.5, 5.5]) mirroring the new
sema axiom — the Near5 property format is retired.

**Why:** the layout types' `GNodes` field needs `g.node.gt`, which had no gwsproto class. Verified
end-to-end: gwsproto `GNodeGt` validates the snapshot's `g.node.gt` sample (axioms pass) → re-emits
→ `gwta.sema` decodes it back. Imports + collection clean (117 tests). Next session: the
`gw.house0.layout` + `gw1.simple.sim.layout` sema types, then copy all 3 layout runtimes into
gwsproto. OPS-407.

## 2026-06-14 — gwsproto: align all 27 types to the sema snapshot (`62cf522d`)

**What:** Brought gwsproto into full version + shape parity with the terminal-asset sema
snapshot (the rule: a gwsproto type's `Version` equals its sema word's version). (1) Bumped 10
lagging `Version` literals the cac→DeviceType migration left behind — `spaceheat.node.gt`
301→302; electric.meter / gw108.* / i2c.thermistor.reader 001→002; i2c.multichannel 004→005;
pico.tank 011→012; pico.btu / pico.flow / sim.pico.tank →001 (sim.pico also `SimulatesVersion`
011→012). Shapes already matched — version-only. (2) Created `SimSensorComponentGt` +
`SimRelayComponentGt` (were missing). (3) Gave the Hubitat nested sub-types
(`HubitatGt`, `HubitatPollerGt`, `MakerAPIAttributeGt`) `TypeName`/`Version` so they are proper
sema objects. All five exported from `named_types/__init__`.

**Why:** so scada can emit every snapshot type and gridworks-terminalasset's `gwta.sema` codec
decodes it. Verified end-to-end: each type built in gwsproto → serialized → decoded through
`gwta.sema` = **27/27**. Imports + collection clean (117 tests). The remaining suite reds are
the pre-existing old-shape layout fixtures (separate gate). OPS-407.

## 2026-06-14 — gwsproto: Hubitat components declare Version 000 (`609e098f`)

**What:** `HubitatComponentGt` and `HubitatPollerComponentGt` now declare
`Version: Literal["000"] = "000"` instead of inheriting `ComponentGt`'s `"002"`
(dfr/ads component types already had this override).

**Why:** A round-trip experiment (generate from gwsproto → publish to the dev
rabbit broker → capture → decode through the sema runtime) caught the bug: the
sema words `hubitat.component.gt` / `hubitat.poller.component.gt` are version
`000`, so the inherited `002` made the sema decoder reject the messages
("Unsupported version 002"). With the override both components decode clean
(2/2). EDD paying off — the contract mismatch was invisible to in-process tests
that don't cross the sema boundary.

## 2026-06-14 — gwsproto: remove MakeModel; relay AsyncCaptureDelta; names/simple_sim (`b23b07af`)

**What:** Completed the `make_model` removal at the gwsproto type level: `AdsChannelConfig`
and `multi.py`'s TSnap config moved `ThermistorMakeModel: MakeModel` →
`ThermistorDeviceType: str`; `btu.py`/`flow.py` moved `FlowMeterType: MakeModel` → `str`
(`Gw1DeviceType.SaierFlowSensor` / `.EkmFlowMeter`); the `MakeModel` enum was deleted and
unexported, one test dict key renamed. Also: added `AsyncCaptureDelta=1` to the 14 house0
relay configs in `relay.py` (they set `AsyncCapture=True` but RelayActorConfig v003's Axiom 1
now requires the delta — the generator had drifted from the committed fixture). Added a new
`names/simple_sim/` package (`opto_input` + `gw_temp`, mirroring nolan).

**Why:** `make_model` is retired across the hardware-layout vocabulary — device identity is the
`gw1.device.type` `DeviceType` now (sema side merged in PR #27). Doing the gwsproto type
migration cleanly first makes the eventual sema-generated upgrade graceful. The relay fix
unblocks house0 layout generation; `names/simple_sim/` seeds the third layout family. Imports
green, 117 tests collect. The umbrella `tlayouts/gen_*.py` hand-scripts still import
`MakeModel` and will break until folded into the new builders (expected — they are being
retired). OPS-407.

**What:** Docstrings only (no functional change) on `HubitatGt` and `HubitatComponentGt`:
record that the MakerAPI URL helpers (`url_config` / `maker_api_url_config` / `refresh_url` …)
are computed in app code, are NOT part of the `hubitat.gt` / `hubitat.component.gt` sema
contract, and will NOT be generated when these types are regenerated from sema in the proactor
port — they must keep living in app code.

**Why:** The matching sema words were just authored (sema `b7d2cae`); the URL machinery turned
out to be derived helpers, not serialized state. The note keeps the next agent (and the proactor
port) from assuming a sema-generated dataclass will carry these methods. Also flags that this
vocabulary serves the five legacy House0 homes with no forward expansion.

## 2026-06-14 — Hardware-layout pass one: cac_id → DeviceType migration (WIP `b0f03292`, `b358a676`)

**What:** The scada side of the cac→DeviceType migration, landed as two WIP commits (to be
squashed). `b0f03292`: `ComponentGt` drops `ComponentAttributeClassId` and carries
`DeviceType: str` (v002); `ComponentAttributeClassGt` becomes the device-type-record base keyed
by `DeviceType` (its `CACS_BY_MAKE_MODEL` Axiom-1 + the UUID gone); `hardware_layout` resolution
joins by `DeviceType` with the specialized record now optional; `layout_db` + the 12 `layout_gen`
generators restructured; new `Gw1DeviceType` enum (app-code only — the gwsproto sema types keep
an open `DeviceType: str`). `b358a676` ("remove cac_id"): the ~9 actor/driver dispatches moved
`cac.MakeModel → DeviceType`; the generators re-swept onto `Gw1DeviceType.X`; the `MakeModel`
field removed from the record base; `show_layout` fixed; `pico_flow`/`pico_btu` `FlowMeterType`
retyped to `str`; and `cacs_by_make_model.py` + the transitional `device_type_by_make_model.py`
deleted.

**Why:** Retire UUID device identity (`cac_id`) and make/model-as-CAC across the scada hardware
layout in favour of a readable `gw1.device.type` `DeviceType`. A device is now fully described by
its `DeviceType` plus its own fields; the `CACS_BY_MAKE_MODEL` bijection evaporates, the silent
type-alignment guard it provided moves to a layout axiom, and `make_model` as a phrase leaves
scada app code. Matches the sema contract in `2d55705` / `0cd2175`. Test fixtures are not yet
regenerated — regenerating them + greening the suite is the next step.

## 2026-06-13 — Rip out UNKNOWN device handling + the sim-multi-temp tank gen (`fc5f4d14`)

**What:** Deleted `unknown_power_meter_driver.py`, `unknown_multipurpose_sensor_driver.py`,
and `layout_gen/simulated_tanks.py`. `power_meter.py` / `multipurpose_sensor.py` no longer
fall back to an Unknown driver — an unrecognized device (or missing i2c/adafruit libs) now
raises `NotImplementedError`. `fixture_layouts.py` no longer adds simulated tanks to the
house0/nolan fixtures; dropped the obsolete (already-skipped) `test_tank_device_capture_period`.

**Why:** OPS-407 (hardware-layout-pass-one). The scada should loudly refuse unknown hardware
rather than run silently against it. The sim multi-temp tank (`GRIDWORKS__SIMMULTITEMP` /
`SimPicoTankModuleComponentGt`) is superseded by the all-purpose `GridworksSimSensor`
(configured from its Component `ConfigList`), so the old sim-tank layout-gen goes — matching
the `gw1.device.type` enum dropping `UnknownDeviceType` + `GridworksSimMultiTemp`. Fixtures
are temporarily tankless until `GridworksSimSensor` is wired (later in OPS-407). `pytest`
green (114 passed).

## 2026-06-13 — docstring warning about aging stuff (`6989180f`)

**What:** Added a warning docstring to `gwsproto/named_types/scada_device_type_gt.py`
(`ScadaDeviceTypeGt`, `gw1.scada.device.type.gt`).

**Why:** The simulated-test-environment design resolved (Jessica, 2026-06-13) that
the generic device-type is `gw1.device.type.gt` (UUID-primary identity +
`MakeModel: string` descriptor), distinct from this **board-specific** type
(NativeGpio / I2cRelays / CtAdc / ThermistorAdcs / Dacs). The docstring marks that
boundary at the type so the two are never conflated — conflation would re-couple the
generic, version-stable, cross-company identity to SCADA-board hardware specifics. It
also flags that this type is gwsproto-only (not in sema — `gw.nolan.layout` dropped
its ref, sema `6f73174`/`af2bf49`) and that its `ComponentAttributeClassGt`
inheritance is the proactor-port flatten flaw, not a pattern to mirror.

## 2026-06-11 — Green the test suite: House0 AsyncCaptureDelta + local test dotenv wiring (`b3cf2c4b`)

**What:** Two coupled fixes landed together so `pytest` passes both
locally and in CI on `jm/spruce-unlimbo`:

1. **AsyncCaptureDelta restored to House0 layout.** `dab55d20` bumped
   `RelayActorConfig` to `003`, which *enforces* Axiom 1 (if
   `AsyncCapture` is true, `AsyncCaptureDelta` must exist — and the
   check is `not AsyncCaptureDelta`, so both absent and `null` fail),
   but only `nolan-layout.json` got the values. Added
   `AsyncCaptureDelta: 1` to the 14 relay configs in
   `tests/config/house0-layout.json` that lacked the key (relays are
   binary state, so a delta of 1 captures every change, matching
   nolan's relays). This is the bug behind CI's two `value_error`
   failures on `relay18`. `tests/config/layout-lite.json` carries the
   same `null` deltas but is loaded through the lite path, which does
   not exercise the axiom in any test — left untouched on purpose, since
   the goal was a green suite, not a speculative edit.

2. **Local test dotenv actually loads now.** `tests/conftest.py` declared
   `TEST_DOTENV_PATH` / `TEST_DOTENV_PATH_VAR` but never wired them, so
   `gwproactor_test` fell back to its own default name and loaded nothing.
   The LTN broker (`scada_mqtt = MQTTClient()`, `tls.use_tls` defaults
   True) then tried TLS against the plain local mosquitto and hung —
   every scada↔LTN link test timed out after 10 s. conftest now sets
   `GWPROACTOR_TEST_DOTENV_PATH` so the repo's local config loads, and
   `tests/.env-gw-spaceheat-test` is committed (copied from
   `tests/config/.env-local`, TLS off) and removed from `.gitignore` —
   the test rig should travel with the repo, not be hand-created per
   checkout. CI still overwrites it from `.env-ci` (TLS on, with certs),
   so CI keeps exercising the TLS path.

**Why:** the branch's tests were red both locally (link timeouts) and in
CI (the axiom failures). The merge `bb4f6294` was an early suspect but
was a red herring — the regression is the config-version bump that
enforced the axiom without backfilling House0, plus a long-standing dead
dotenv wiring that only bites a fresh checkout with no local rig.

## 2026-06-11 — Sim-time bridge: scada-side sim.timestep listener (OFI) (`aa802567`, PR #571)

**What:** On branch `jm/sim-time-bridge` (off `jm/spruce-unlimbo`): a
minimal listener that subscribes over MQTT to the time coordinator's
`sim.timestep` broadcasts, parses the JSON directly (deliberately
bypassing the gwsproto codec — OFI: interim, dies in the uv/AllyLink
rebuild), tracks latest sim time, and triggers the link keepalive per
the bridge plan (1-minute timesteps feed ping/ack; existing scada/LTN
stay wall-clock).

**Why:** the sim-time spoke of the simulated-test-environment design
(OPS-40, hub + spoke Accepted · Pass 1 2026-06-11) — the simplest
scada-side hook for the bridge, per the decision to keep scada sim-time
machinery minimal until the rebuild.

## 2026-06-11 — Merge branch 'dev' into jm/spruce-unlimbo (`bb4f6294`)

**What:** Merge commit bringing the branch up to current dev (docs
additions, standby/ltn/sieg_loop updates). One conflict,
`tests/config/nolan-layout.json` (both-added): resolved keeping the
branch's version-bumped copy — RelayActorConfig `003` /
I2cThermistorChannelConfig `001` — over dev's stale `002`/`000`; only
those four Version lines differed.

**Why:** keep the spruce-unlimbo working branch current with dev per
its own design ("merge dev forward regularly"), and as the base for
the upcoming sim-time bridge work, which branches off
`jm/spruce-unlimbo`. The branch's bumped config versions are the ones
its post-glean code requires (the poison-message lesson: stale-version
payloads against post-bump code).

## 2026-06-10 — Bump nolan-layout config versions to match RelayActorConfig 003 / I2cThermistorChannelConfig 001 (`77d882ac`)

**What:** In `tests/config/nolan-layout.json`: the
`gw108.vdc.relay.component.gt` ConfigList entry 002→003
(RelayActorConfig) and the `i2c.thermistor.reader.component.gt`
component 000→001 + its two ConfigList entries 000→001
(I2cThermistorChannelConfig). Version strings only; the bumped types
added validators, no new required fields.

**Why:** The `2b603cc0` glean cherry-pick bumped these type versions and
updated `house0-layout.json`, but `nolan-layout.json` didn't exist on
`jm/spruce-new`, so the pick couldn't touch it — leaving every
nolan-layout load (and therefore `gws run` and the whole test suite,
which conftest points at this file) failing pydantic validation. Found
via `gws run --dry-run`; both scada and LTN dry-runs pass after the fix.

## 2026-06-10 — Bump channel config versions for RelayActorConfig and I2cThermistorChannelConfig (`dab55d20`, cherry-pick of `2b603cc0` onto `jm/spruce-unlimbo`)

**What:** Second of two cherry-picks gleaning `jm/spruce-new` onto
`jm/spruce-unlimbo` (the spruce-unlimbo working branch, cut from
`td/orig-pred-set`). Adds `ChannelConfigBase` type helper, bumps
RelayActorConfig / I2cThermistorChannelConfig (+ related channel-config
named types) versions, adds named-type tests, and adds the
`airtable_pat` setting + `.env-template` lines. Conflict resolved in
`.env-template` only (union of both sides; the pick's truncated
real-prefix Airtable PAT replaced with an empty placeholder).

**Why:** Branch-reconciliation step of the spruce-unlimbo design: these
two commits were the only content in `jm/spruce-new` not already in
`td/orig-pred-set` (which contains `jm/spruce` as an ancestor). After
this lands, `jm/spruce` and `jm/spruce-new` are fully gleaned and can be
deleted.

## 2026-06-10 — docstring for actors/scada.py (`a5451f43`, cherry-pick of `62bc7218`)

**What:** Replaces scada.py's one-line module docstring with one
explaining that Scada is the prime actor in a gwproactor app: child
actors load from the hardware layout + actor registry, so layout
`ActorClass` values must resolve through `gw_spaceheat/actors/__init__.py`
exports or the proactor cannot instantiate them.

**Why:** First of the two `jm/spruce-new` glean cherry-picks onto
`jm/spruce-unlimbo` (see entry above). The docstring captures the
layout→registry coupling that bit during spruce bring-up.

## 2026-06-10 — OFI comment (`8a0e1689`)

**What:** Add an OFI comment in `gw_spaceheat/actors/sieg_loop.py`
`moving_to_hp_off_valve_position` pointing at OPS-400
`sieg-semantic-harmonization`. No behavior change.

**Why:** Flags in-code that, after `e6ba4f51`, control state `HpOff` no longer
uniquely determines valve posture (it branches on static `settings.system_mode`
with no disambiguating telemetry), and that default-when-off is per-heat-pump
(Maple Mitsubishi vs Beech LG) and not yet parameterized — so the next reader
sees the seam and the tracking issue without spelunking the changelog.

## 2026-06-10 — Open sieg valve in Standby (`e6ba4f51`, PR #570)

**What:** In `gw_spaceheat/actors/sieg_loop.py`, the transition into
`SiegControlState.HpOff` no longer hard-codes `moving_to_full_keep` (loop
CLOSED). It now routes through a new `moving_to_hp_off_valve_position(event)`
that branches on `self.settings.system_mode`: `Standby` → `moving_to_full_send`
(valve OPEN); anything else → `moving_to_full_keep` (CLOSED — heating-season
behavior unchanged). Authored + merged by Thomas.

**Why:** The simple sieg code keeps the loop closed whenever the heat pump is
off — correct for the heating season, wrong for summer/Standby (especially when
the valve is otherwise not moving). Maple sat in Standby with the loop closed
post-incident; the first action is putting the loop in full send. SiegLoop
learns posture from the **static startup config** `settings.system_mode` (env
`SCADA_SYSTEM_MODE`), so the new posture takes effect on the restart that
switches a SCADA to Standby (which also rebuilds the LocalControl tree). Design
`sieg-summer-posture`, OPS-395. Known OFI (`sieg-semantic-harmonization`,
OPS-400): control state `HpOff` no longer uniquely determines valve posture and
telemetry can't disambiguate (valve-state `SingleMachineState` still TODO); and
default-when-off is per-heat-pump (Maple Mitsubishi vs Beech LG), not yet
parameterized.

## 2026-06-09 — ltn sends correct scada wrapped (`981f0939`)

**What:** Replace the five `Message(..., Dst="broadcast", ...)` publishes in
`gw_spaceheat/actors/ltn/ltn.py` with real proactor-peer addressing: `Bid` → the
MarketMaker (`Dst="mm"`); `FloNextHourPlans`, `Glitch`, and both
`FloParamsHouse0` sends → the scada (`Dst=self.scada.name`, i.e. `"s"`). Each
site carries a HACK comment to revert to a real `rjb` broadcast once the LTN is a
gwbase actor (it leaves the scada lexicon).

**Why:** `Dst="broadcast"` is a magic string the proactor turns into a wire
routing key with no valid GridWorks envelope, so a gwbase consumer
(JournalKeeper) drops it at parse — silent data loss (prod saw `broadcast.glitch`
/ `broadcast.flo-next-hour-plans`). Addressing a real peer makes a valid
`gw.<src>.to.<peer>.<type>` key that gwbase parses (tolerant short-form parse,
gridworks-base design `must-accept-current-ltn-messages`). `"mm"` is deliberately
the gwbase `RoutingClass.MarketMaker` token, so the key already matches the
new/future rabbit structure. Design `ltn-sends-gw-wrapped`, OPS-387; depends on
the gridworks-base parser change publishing.

## 2026-05-14 — Add back a much-pruned docs folder (`c05a7625`, merged `6734aa0f` / PR #562)

**What:** Restores a `docs/` folder to the scada repo with three focused,
hand-pruned documents — `docs/editor-setup.md` (109 lines),
`docs/provisioning.md` (257 lines), and `docs/tls.md` (123 lines). No code
changes; docs only. Authored 2026-05-07, merged to `dev` on 2026-05-14.

**Why:** The repo's earlier `docs/` had been removed; this brings back a
deliberately slimmed-down subset covering the three things a human setting
up scada actually needs — editor setup, device provisioning, and TLS — as
repo-standalone docs (a repo's own docs stand alone for a human and don't
reference the wiki). Curated-minimum rather than the full former tree.
