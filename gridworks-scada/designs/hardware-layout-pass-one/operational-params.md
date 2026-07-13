# operational-params — the third SCADA artifact (spoke)

Status: Accepted · Pass 2 · Updated 2026-07-04 · Linear: OPS-407

> What this is: a third SCADA artifact alongside deployment config and the static hardware layout — the
> **operational / optimization parameters** (`operational-params.json`): the tunable state that changes
> *without* rewiring hardware. **Built this pass** — folded in from a would-be sibling design because it is
> too entangled with the `channel.config` reshape to defer (dropping capture params from the layout needs
> their new home *now*). The LTN live-update *transport* stays OPS-408 (its consumer), not this spoke.

## ▶ Next move (start here — active spoke)

**The sema reshape is DONE and committed on `jm/sim-vocab`:** ✅ `capture.tuning/000`; ✅ the
`channel.config` family strip (capture params off the 5 specialty types) + the 9-component `ConfigList`
drop, leaving `channel.config` **orphaned** (not deleted — `000` is published); ✅
`gw.house0.operational.params/000` (`GNodes` home-identity + `CaptureTuningList`). The behavioral net is in
place (`sim-run.md` ✅). See the four `wiki/sema/changelog.md` entries (2026-06-30) for exactly what changed.

**✅ Steps 1–3 done — the gwsproto types match the reshaped sema and the scada loads/runs**
(`gridworks-scada` `jm/gwsproto-ops-params`, off `jm/delete-cac-id`, commit `9fe86665`):
✅ added `CaptureTuning` + `GwHouse0OperationalParams` (both **validate clean through `sema validate`**);
✅ `ChannelConfig` → `CaptureTuning` as the unified simple-config (`ComponentBase.ConfigList` + 9 bare
components + every construction site), `channel_config.py` deleted; ✅ removed the two gwsproto-only legacy
types with no sema counterpart — generic `ComponentGt` (→ `ComponentBase` as decode-fallback/umbrella) and
dead `RESTPollerComponentGt`; ✅ suite green (115 passed / 3 skipped; the lone failure is a pre-existing
async-MQTT timing flake). **Approach A holds:** the gwsproto config types are the *assembled runtime* shape,
so they keep the capture params (filled at assembly) — the ~23 actor read sites are untouched (see "Why
nothing breaks" below). The 7 live `tests/config` fixtures were field-bumped `channel.config/001` →
`capture.tuning/000`.

**✅ Step 4 done (2026-07-04) — `ops_and_sema_to_dc` built**, forced by the gen machinery's move to
tlayouts (scada now consumes the two authored files): `sema_to_dc.assemble_runtime_layout` splices each
channel's `capture.tuning` onto its component's ConfigList entry (bare components get theirs rebuilt from
the channels their nodes capture), carrying both assembly checks — **assembly-coverage** and the
**`PollPeriodMs ≥ MinPollPeriodMs` floor**. Proven on oak: tlayouts authors → assemble → the dc LOADS OK,
only the known stale-fixture DerivedChannels diff remains.

**✅ Step 5 done (2026-07-08) — oak adopted + sim-booted:** `tests/config/oak.json` regenerated from the
assembled gen output — the 4 heat-call DerivedChannels frozen (UUIDs now stable via the LayoutIDMap
reference), the 21 relay DataChannels on the new-convention functional names (`vdc-relay1` → `vdc-relay`,
same Ids). The oracle converges (0 diffs, content-identical) and the behavioral gate passes: the adopted
oak boots in sim on `gw-dev-rabbit` (101 channels, 55 non-null). En route, `sim_layout.simulate_sensors`
gained `_as_capture_tuning` — swapped sim components' ConfigLists project to their `capture.tuning/000`
core (specialty entries like `ads.channel.config` fail `sim.sensor.component.gt` validation; pre-existing,
it bit maple too).

**▶ The next move — within the pass, now the core boots:** define `cop.curve` + `heating.curve`, extend
`gw.house0.operational.params` (a new version) with the control/optimization fields, and migrate the rest
(`SystemMode`, criticality, thermal-mass, FLO knobs) out of `actors/config.py` + the static layout.
Forward-only throughout (no `dc_to_sema`).

**⏳ Come back to: author initial `operational-params.json` for the whole existing fleet.** Every deployed
home (oak, elm, fir, beech-sieg, maple, the House0 variants, nolan) needs a **first** `operational-params.json`
authored as part of this design — the `capture.tuning` list now (per-channel capture params lifted from the
retiring `channel.config` params), and the control/curve fields once those leave `actors/config.py`. This
rides the sema gen (`sema_gen` emits **both** the static sema and `operational-params.json` per home), so the
fleet ops-params are produced by re-authoring, not hand-written JSON. **The fork is built into the
gen** (`tlayouts.house0_sema_gen.gen_artifacts` returns the static-layout + operational-params pair; the
snapshot types enforce the capture-stripped static shape structurally) and **the first two pairs are
gen-emitted** — `tlayouts/gen_oak_sema.py` (82 capture tunings) and `gen_house0_stub_sema.py` (36, the
all-sim skeleton), each written to `tlayouts/output/<home>/` after decoding through the sema snapshot.
Remaining homes ride the per-home gen build-out alongside the `tests/config/` regeneration in
[`gen-pipeline.md`](gen-pipeline.md).

## The artifact — one layout-typed type, a collection of sub-types

Resolved (Pass 2): **one `operational-params.json` file**, one **layout-typed** top type that *composes a
collection of sub-types*. Layout-typed (`gw.house0.operational.params`, `gw.nolan.operational.params`)
mirrors the layout types themselves — so its axioms bind to the layout (`CriticalZoneList ⊆ the layout's
zones`; one `ZoneKwhPerDegF` per zone), and nolan's genuinely-different control/optimization shape (radiant
floor, single tank) gets its own fields rather than a pile of house0 optionals. The **same entity** (the
LTN, via OPS-408) writes the whole file, so there is **no lifecycle split** inside it — sub-types are for
organization, not separate write-paths.

| Member | Kind | Holds |
|---|---|---|
| **`capture.tuning`** | sub-type, **per-channel** (a list) | `ChannelName`, `CapturePeriodS`, `AsyncCapture`, `AsyncCaptureDelta`, optional `PollPeriodMs`. Carries the moved `CaptureAndPollingConsistency` axiom (below). Generic — shared across layouts. |
| **`cop.curve`** | sub-type, per-home | `Intercept`, `OatCoeff`, `LwtCoeff`, `Min`, `MinOatF`. A reusable concept; its own clean word. |
| **`heating.curve`** | sub-type, per-home | `AlphaTimes10`, `BetaTimes100`, `GammaEx6`, `IntermediatePowerKw`, `IntermediateRswtF`, `DdPowerKw`, `DdRswtF`, `DdDeltaTF`, `MaxEwtF`. The house thermal / RSWT model. |
| **control / mode scalars** | **inline** on the top type | `SystemMode`, `SeasonalStorageMode`, `UseSiegLoop`, `OilBoilerBackup`, `ShortCycleBuffer`, `HpTurnOnMinutes`, `LoadOverestimationPercent`, `HorizonHours`, `Latitude`, `Longitude`. Small scalars — not worth their own words. |
| **per-zone lists** | **inline** on the top type | `CriticalZoneList`, `ZoneKwhPerDegFList`. Layout-shaped; the layout-binding axioms live here. |

So the top type composes **three sub-type words** (`capture.tuning`, `cop.curve`, `heating.curve`) and
carries the control scalars + per-zone lists inline. Penalties are **not** here (FLO-side — see below);
`flo.penalties` was considered and dropped.

## What crosses the rewiring boundary — the field inventory

> Can you change it without rewiring hardware? If yes, it's operational, not topology.

**Most of `actors/config.py` is operational, not deployment.** By the rewiring test:

- **Stays deployment config** (`.env` / settings): broker clients (`local_mqtt`, `gridworks_mqtt`),
  `admin`, `persister`, logging levels, `paho_logging`, `timezone_str`, `is_simulated`, `airtable_pat`.
- **Moves to `operational-params.json`:**
  - *capture / telemetry tuning* → `capture.tuning`: `seconds_per_report` (the home-wide `CapturePeriodS`
    default), `seconds_per_snapshot`, `async_power_reporting_threshold`; plus the per-channel
    `CapturePeriodS` / `AsyncCapture` / `AsyncCaptureDelta` / `PollPeriodMs` leaving `channel.config`.
  - *house thermal model* → `heating.curve`: `alpha`, `beta`, `gamma`, `intermediate_power`,
    `intermediate_rswt`, `dd_power`, `dd_rswt`, `dd_delta_t`, `max_ewt_f`.
  - *COP curve* → `cop.curve`: `cop_intercept`, `cop_oat_coeff`, `cop_lwt_coeff`, `cop_min`, `cop_min_oat_f`.
  - *control / mode* → inline: `system_mode`, `seasonal_storage_mode`, `hp_turn_on_minutes`,
    `short_cycle_buffer`, `load_overestimation_percent`, `oil_boiler_backup`, `latitude`, `longitude`,
    `HorizonHours`; plus `UseSiegLoop`, `CriticalZoneList`, `ZoneKwhPerDegFList` (the last two out of
    `gw.house0.hydronic` today).

**`PollPeriodMs` → operational (optional).** By the strict rewiring test it is operational — you can poll
faster/slower without touching wiring, bounded below only by the hardware floor `MinPollPeriodMs` (on
`ads111x.based.device.type.gt`, which **stays** on the device type). It moves into `capture.tuning`
alongside `CapturePeriodS` so the two stay in **one** artifact, and stays **optional**. The
`CaptureAndPollingConsistency` axiom (today on `dfr.config`) **moves with them**, reshaped conditional:
*if `PollPeriodMs` is present, then `CapturePeriodMs` (= `CapturePeriodS`×1000) > `PollPeriodMs`* (plus the
multiple-of clause). The one cross-artifact relation left — `PollPeriodMs ≥ MinPollPeriodMs` — is a **floor
check**, enforced at assembly time in `ops_and_sema_to_dc` (the layout owns `MinPollPeriodMs`; the ops file
owns `PollPeriodMs`).

**Carve-out — these go to the LAYOUT, not ops** (they *fail* the rewiring test — swapping them *is*
rewiring): `hp_model` and `hp_max_kw_el` (HP nameplate — already `# TODO: move to layout`), and
`whitewire_threshold_watts` (also `# TODO: move to layout`).

## What this spoke builds vs what stays OPS-408

- **This spoke (pass-one):** the `operational-params.json` artifact + the **sema types** for it
  (`gw.house0.operational.params` + `capture.tuning` / `cop.curve` / `heating.curve`) + the
  `ops_and_sema_to_dc` assembly, and the migration of the fields above **out of** config and the static
  layout into it.
- **OPS-408 (Thomas), the consumer:** the **LTN live-update transport** (web → LTN → SCADA, in Auto,
  SLA-preserving) that *pushes* updates to these params. It is **gated by this spoke** creating the sema
  types (the transport carries types this spoke defines).

## Why nothing breaks (the assemble pattern)

The runtime dc `HardwareLayout` the device actors read is **assembled**, not authored:

```
ops_and_sema_to_dc( static-layout sema ⊕ operational-params.json ⊕ live state ) → runtime dc
```

So moving a field here does **not** change the runtime `channel.config` — device actors still read
`CapturePeriodS` / `AsyncCaptureDelta` / `PollPeriodMs` off their component, because assembly merged them
back. The split is in **authoring / source-of-truth**. The reshape (`channel.config` → `ChannelName`, base
removed), the first-pass `operational-params.json`, and the assembly land **together** — no broken interim.

**gwsproto config types are the assembled *runtime* shape, not the authoring shape (decided).** The
capture-param fields (`CapturePeriodS` / `AsyncCapture` / `AsyncCaptureDelta` / `PollPeriodMs`) **stay on
the gwsproto `*.channel.config` types** as optional fields; `ops_and_sema_to_dc` populates them per channel
from `capture.tuning` (keyed by `ChannelName`). The **sema schema** is what strips them from the
`channel.config` family (authoring source-of-truth = static ⊕ ops), so gwsproto deliberately does **not**
mirror the stripped sema shape on these fields — it mirrors the runtime. This keeps the ~23 actor read
sites (`cfg.CapturePeriodS`, `telemetry_config.AsyncCaptureDelta`, `cfg0.PollPeriodMs`, …) **unchanged**.
Forward-only: no `dc_to_sema` / `dc_to_ops` — the fleet is re-authored via the sema gen, which now emits
**both** the static sema and `operational-params.json`. A **live LTN update** → re-assemble → actor
reconfig is the dynamic path (OPS-408's transport drives it).

`ops_and_sema_to_dc` carries the two genuinely-new validity checks (both the merge's own concern;
layout-structure validity stays in the sema axioms):

- **Assembly coverage:** do the operational params cover every channel the static layout declares?
- **Poll floor:** for every channel with a `PollPeriodMs`, `PollPeriodMs ≥ MinPollPeriodMs` for that
  channel's device type.

## Relationship to the FLO

`flo_params` (`gwsproto/named_types/flo_params_house0.py`) is an **assembled message** built from layout
physical facts (tank gallons, HP nameplate) ⊕ operational params (the curves, mode, knobs) ⊕ live
forecasts/state — not a stored file. So these operational params are *inputs* to the FLO-params assembly,
resolving the overlap where physical facts appear to live in two places: physical facts stay in the layout;
tunable choices live here; `flo_params` is computed from both. Three findings pin the FLO boundary:

- **Penalties stay FLO-side.** The `Rswt*` / `Stability*` penalty knobs have **zero readers in scada** —
  they flow into `flo_params` purely as input to the private optimizer (gridworks-innovations). They are
  FLO-owned config, **not** scada-operational; `flo.penalties` was considered as a sub-type and **dropped**.
- **`NumLayers` is layout-derived**, not a tuning (`ltn.py`: `NumLayers = 3·num_tanks·3`) — it stays
  computed in assembly. `HorizonHours` *is* a real scalar tuning → inline on the top type.
- **`flo_params_house0` is NOT reshaped this pass (OFI).** It is the wire-contract to the private FLO;
  changing its shape needs Thomas + a gridworks-innovations change. Later aligning it to *reuse*
  `cop.curve` / `heating.curve` (assembly becomes a sub-object copy) is a clean DRY follow-on. A separate
  "which `FloParamsHouse0` fields does the optimizer actually consume" dead-field sweep also needs the
  private repo — both flagged for the `flo.params` owner.

## Resolved (Pass 2) + what genuinely stays open

Resolved this pass (was "Open"):

- **Which params cross the boundary** — the inventory above; `PollPeriodMs` → ops (optional), axiom moves.
- **The artifact shape** — one layout-typed type composing 3 sub-types + inline scalars/per-zone lists;
  one `operational-params.json`, variants = the per-home authored instances (oak, elm, …) + the structural
  variants the gen already emits (sieg vs non-sieg, zone/tank counts).

Genuinely still open (does **not** block the forced core):

- **Re-assembly + actor reconfig** — the live-update mechanics when OPS-408 pushes a change. **Testing this
  end-to-end needs the simulated environment** (a SCADA on a sim layout + a live LTN to push the update +
  observe it applied) — the sim-test-environment rig ([OPS-40](https://linear.app/gridworks/issue/OPS-40)).
- **`flo_params` sub-type reuse + the FLO dead-field sweep** — OFIs above, owned by the `flo.params` owner.
