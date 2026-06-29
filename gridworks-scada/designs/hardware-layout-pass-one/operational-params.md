# operational-params — the third SCADA artifact (spoke)

Status: Accepted · Pass 2 · Updated 2026-06-29 · Linear: OPS-407

> What this is: a third SCADA artifact alongside deployment config and the static hardware layout — the
> **operational / optimization parameters** (`operational-params.json`): the tunable state that changes
> *without* rewiring hardware. **Built this pass** — folded in from a would-be sibling design because it is
> too entangled with the `channel.config` reshape to defer (dropping capture params from the layout needs
> their new home *now*). The LTN live-update *transport* stays OPS-408 (its consumer), not this spoke.

## ▶ Next move (start here — active spoke)

The behavioral net is in place (`sim-run.md` ✅: scada boots + runs on `gw-dev-rabbit`, sim sensors
self-generate, universe guardrail). **Do this reshape now, before the fleet gen files** — it pins the
three-artifact shape every home's gen file targets, so each home is authored once, not re-authored after.
The sim-run net + oak are the verification. The decision tree is resolved (Pass 2); execute in this order:

1. **Forced core (lands together — no broken interim):**
   - **Define `capture.tuning`** (per-channel) and **collapse the `channel.config` family** — drop
     `CapturePeriodS` / `AsyncCapture` / `AsyncCaptureDelta` / `PollPeriodMs` from the specialty types, and
     **remove the bare `channel.config` base type entirely** (see [`layout-boundary.md`](layout-boundary.md)
     for the base-removal + the 9-component `ConfigList` drop worklist).
   - **Build `ops_and_sema_to_dc`** — extend `gw_spaceheat/sema_to_dc.py` to merge `static sema ⊕
     operational-params` into a whole-`channel.config` dc, with the **assembly coverage** check + the
     **`PollPeriodMs ≥ MinPollPeriodMs` floor** check.
   - **Verify on oak** — `sema_gen(oak) → (static ⊕ ops) → ops_and_sema_to_dc → dc`, diff-and-adopt vs the
     fixture, and **boot it in sim** (`sim_boot`) — the behavioral gate, not byte-equality.
2. **Within the pass, right after the core boots:** define `cop.curve` + `heating.curve`, the layout-typed
   `gw.house0.operational.params`, and migrate the rest of the fields (`SystemMode`, criticality,
   thermal-mass, FLO knobs) out of `actors/config.py` + the static layout into the ops artifact.

**Dependency to clear first:** the `channel.config` family + the new ops types are **sema** changes —
confirm those types are still **unpushed/mutable** before editing in place (`git branch -r --contains`).
Forward-only throughout (no `dc_to_sema`).

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
