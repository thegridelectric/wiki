# Both-cases survey: layout gen · testing · local control

Status: Draft · Pass 0 · Updated 2026-06-10

> What this is: spruce-unlimbo spoke — verified survey (2026-06-10, by
> read-only inspection of `td/orig-pred-set` working tree vs `dev` via
> git) of how layout generation, testing, and local control work for the
> two house cases: House0 (the fleet) and Nolan (spruce). Feeds the
> merge-gate work in the hub.

## 1 · Layout generation (tlayouts + layout_gen)

**Pipeline.** tlayouts' per-house `gen_<house>.py` scripts are thin
orchestrators: they import builders from the scada repo's
`gw_spaceheat/layout_gen/` (`add_tank3`, `add_relays`, `add_btu`,
`add_thermostat`, …) plus `gwsproto` names (`H0N`, `H0CN`,
`FlowManifoldVariant`) and emit `output/<house>.generated.json`, which is
synced to the house (rclone idiom). tlayouts holds the house-specific
parameters (zones, pico HW UIDs, calibration constants); layout_gen holds
the structure. tlayouts' own README calls the scripts "hacky and
temporary."

**Lock-step coupling.** A tlayouts branch only works with the scada
branch whose layout_gen/gwsproto it imports:

- tlayouts `main` ↔ House0-era scada (uses `FlowManifoldVariant.House0Sieg`,
  decimal calibration B-values, `add_relays()`).
- tlayouts `jm/spruce` ↔ the spruce scada line: switches calibration
  B-values to 100×-scaled ints, gives `BtuCfg` explicit
  Flow/Hot/Cold channel names, and **drops `add_relays()`** — which is
  why it cannot generate correct House0 layouts.
- `new-builder` ("works w LocalControl etc"): gen_spruce there is a stub;
  purpose unclear — check before deleting.

**Spruce vs House0 generator shape** (gen_spruce vs gen_maple/gen_beech):
4 zones not 2; 1 store tank (team's one-tank conviction) vs 3; tank3
modules reused for `pipes1`/`floor1`/`floor2` sensing; 2 pico BTU meters
(store + dist) instead of hall/reed flow meters; no Hubitat thermostats,
no TSnap multipurpose, no DFRs.

**Branch hygiene found:** tlayouts `jm/spruce` is dirty (gen_elm pico
UID swap uncommitted, gen_spruce whitespace) plus stray proactor logs and
a nested `Users/…` backup dir. gen_spruce on `main` points at
`beech.generated.json` (copy-paste bug, fixed on `jm/spruce`).

## 2 · Testing

**Infrastructure.** Tests instantiate a scada via `gwproactor_test`
fixtures with `is_simulated=True`; the layout comes from
`tests/conftest.py`. Layout class is `House0Layout` for both cases, with
a `"Strategy"` key routing node names: `"House0"` → `House0NodeNames`
(relay-multiplexer, 3 tanks), `"Nolan"` → `NolanNodeNames` (vdc-relay
GPIO, 1 tank) — `house_0_layout.py:159-163`.

**Branch state vs dev** (23 test files changed, +5068/−282):

- `tests/conftest.py` **hardcodes `nolan-layout.json`** (dev used the
  default `hardware-layout.json`, renamed `house0-layout.json` on the
  branch). CI runs plain `pytest`, so **House0 tests never run on CI**.
- New layout-agnostic named-type tests (relay_actor_config,
  channel_config, …) — these pass under either layout.
- Layout-specific assertions are single-case: `test_scada.py:42` asserts
  Nolan's vdc relay; `test_derived.py:33-38` assumes 1 tank. Each fails
  under the other layout.
- `test_misc/test_admin.py` shows the right pattern already: relay/DAC
  tests override to `HOUSE0_LAYOUT_PATH` explicitly.
- `test_misc/test_layout_gen.py`: all 3 tests **skipped** — "layout_gen
  is under active rework on jm/layout-augmments" (the pointer to the
  layout-augments glean).

**What "testing green for BOTH" structurally requires:** layout
selection parameterized (pytest option or CI matrix, not a conftest
hardcode); layout-specific assertions keyed off the layout strategy or
split per-case (test_admin's override pattern generalized); un-skip
layout_gen tests once the rework lands.

## 3 · Local control, both cases

**Shared skeleton.** Both cases run the same loader
(`local_control_loader.py`: Standby / AllTanksTou / BufferOnlyTou by
SystemMode + SeasonalStorageMode), the same `LocalControlTouBase` (60 s
loop, pump doctors, TOU clock), and `ShNodeActor` as the capability
surface. `ShNodeActor` hardcodes `H0N`/`H0CN` names throughout (tank
channels, relay properties) — the both-cases blocker at the code level.

**House0 (dev): sense → decide → actuate.** Inputs: Honeywell zone
setpoints via Hubitat, tank thermistor temps via DerivedGenerator
calibration, TOU clock. FSM (`all_tanks_tou.py`): Initializing /
HpOffStoreOff / HpOnStoreOff / HpOnStoreCharge / HpOffStoreDischarge /
Dormant, driven by buffer-empty/full, storage-ready, defrost detection.
Actuation: relay state commands through the Krida i2c multiplexer.

**Nolan (`td/orig-pred-set`): sense → learn, no actuation yet.**

- Heat calls: mechanical-thermostat white-wire → optocoupler → Gw108
  GPIO pins (BCM 17/27/22/10) → `gpio_sensor.py` actors →
  `zone-X-opto-input` channels.
- Zone temps: shared ADS1115 (i2c 0x49) → `i2c_thermistor_reader.py` →
  gw-temp channels.
- Derived channels (`layout_gen/derived_channels.py`): `heat-call`
  (opto interpretation) and `simple-falling-edge-setpoint` — the zone
  setpoint is **learned** as the gw-temp at the heat-call falling edge,
  with belief tracked by the `SetpointPhase` enum
  (`derived_generator.py:35-46`: Unknown / LastHeatCallEndTemp /
  SuspectZoneBelow|AboveSetpoint — suspicion = the user moved the dial,
  drop the belief).
- **No control state consumes the predicted setpoint yet** — the branch
  is observation-only; the resistive elements run on a clock outside
  this codebase (the starter-scripts hack; not in this repo — locate it
  on the spruce host before Chunk D replaces it).

**DerivedGenerator refactor** (branch): from single-purpose tank
calibration (~640 lines) to a strategy-handler architecture
(identity / affine / heat-call / simple-falling-edge-setpoint /
system-model) — this is the "more nuanced derived channels" the seed
reported, and it's a both-cases asset, not a fork.

## Verification notes

All of the above from read-only git inspection 2026-06-10
(`td/orig-pred-set` tree vs `dev` via `git show`/`git diff`); no tests
were run. Single-pass agent survey — spot-check file:line pins before
building on a specific one. Open questions carried to the hub: where the
starter-scripts hack lives; whether Nolan layout omits relay nodes
entirely or includes unused ones; `new-builder`'s purpose.
