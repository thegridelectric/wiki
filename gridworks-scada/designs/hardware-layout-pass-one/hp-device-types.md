# HP device types — hp.device.type.gt + hp.control.box.device.type.gt (spoke)

Status: Draft · Pass 0 · Updated 2026-07-17 · Linear: OPS-407

> What this is: the converged design for retiring `gwsproto.enums.HpModel` into the
> device-type model — two new sema record families for heat pumps, the enum values, and
> how the layout carries them. Design converged 2026-07-15..17 (spruce field work +
> maple pump-doctor bug); written here for a fresh session to EXECUTE via
> `/make-sema-word` (read `sema/CLAUDE.md` + `spec/primary.md` + the authoring spokes
> first — the ritual, not this doc, governs the mechanics).

## Why (the one-paragraph case)

`HpModel` (4 values, never sema-registered) rides `ScadaSettings.hp_model` with a silent
default (`actors/config.py:58`, `# TODO: move to layout`); consumers
(`orig_sieg_loop.py`, `sh_node_actor.py:1325`, `all_tanks_tou.py`) branch control
behavior on it. It is a parallel identity scheme — the MakeModel pattern pass-one
retired. Heat pumps need exact-designation identity because the code branches on model
(contrast: the eGauge stays ONE coarse class because the code is indifferent — the
granularity follows what the code cares about); the most granular instance lives in the
hardware layout. The maple defect ([OPS-450](https://linear.app/gridworks/issue/OPS-450))
is the running cost of these facts having no structured home.

## The two record families (both `status: staging`, owner `gridworks-energy`, flat,
`DeviceType`-keyed — the `ads111x.based.device.type.gt` pattern)

- **`hp.device.type.gt/000`** — compressor-bearing units: monobloc ODUs, hydro-kit
  ODUs *and* IDUs (the cascade IDUs carry their own refrigerant cycle).
  Required: `DeviceType`, `MaxKwEl` (absorbs `HpMaxKwEl` from settings),
  `HeatingCapacityBtuHr`, `CoolingCapacityBtuHr`, + the three pump facts below.
  Optional: `Refrigerant`, `CompressorRatedAmps`, `Mca`, `Mop`, `DisplayName`.
- **`hp.control.box.device.type.gt/000`** — control boxes (no compressor; the
  monobloc's indoor box). Required: `DeviceType` + the three pump facts.
  Optional: `WaterPumpRatedAmps`, `BackupHeaterKwList`, `Mca`, `Mop`, `DisplayName`.

**The three primary-pump facts — REQUIRED on both families** (the unit owning the pump
signal varies by architecture; the maple bug is the cost of assumed defaults):

1. `PrimaryPumpFactoryInstalled` (bool) — ships inside the unit vs field-supplied.
2. `PrimaryPumpOverridable` (bool) — the unit exposes its pump-control signal so an
   external interrupt can be wired (Samsung/LG two-stage terminal-block pattern; false
   where the pump is sealed in with no signal out, e.g. the AE055 box).
3. `PrimaryPumpAlwaysOn` (bool) — under the unit's own control the pump never stops
   (maple's Mitsubishi; note the Samsung AE055 under external-stat config does stand its
   pump down — field-observed 2026-07-16).

## Enum values (`gw1.device.type`)

Nameplate-grounded, full designation = identity: **`SamsungAE055FCYDCG`** (monobloc
ODU) and **`SamsungAE055FEYMCG`** (control box). `pascal.case` forbids underscores
(pattern `^[A-Z][A-Za-z0-9]*$`, `Make_Model` a literal counterexample; format immutable)
but allows consecutive capitals — designation verbatim after the make prefix. Existing
four HpModel values get nameplate-grounded mints as their nameplates are confirmed
(fir's hydrokit pair is documented: IDU AM048CNBFCB / ODU AM048TXMDCH). Nameplate data
for the spruce pair is transcribed in the Samsung AE055 Drive folder.

## Layout carriage (NO new layout sema)

- Thin component on the `hp-ctrl-box` node (identity + `DeviceType` + `ConfigList`; all
  model facts on the record); `hp-odu` gets the same treatment when the family mints.
  Layout, not ops — swapping a heat pump is rewiring.
- Override-wired-at-this-house is expressed by the **presence of the
  `primary-pump-scada-ops`/`primary-pump-failsafe` relay nodes** (now optional per home
  — [`generator-blueprint.md`](generator-blueprint.md) + the gen_maple note, OPS-450).
  Failsafe de-energized = unit keeps control (relay-semantics pattern).
- Future cross-consistency axiom, in place on the staging layout words once the records
  exist: relays present ⇒ the hp record has `PrimaryPumpOverridable: true`.
- Node naming already canonized in `gwsproto/names/hydronic_spaceheat` (`1ded34cc`):
  a monobloc IS its `hp-odu`; `hp-idu` = own-refrigerant-cycle indoor units;
  `hp-ctrl-box` = the monobloc indoor box; multi-outdoor-compressor systems index
  `hp-odu1`/`hp-odu2` (the Arctic case); the tentative `heat-pump` entry was deleted.

## Open decisions for the executing session (ask JM)

- **(a)** Append the two values to staging `gw1.device.type/001` in place (lean — staging
  is mutable, no cascade) vs mint `002`.
- **(e)** Sema branch: `jm/i2c-relay-capability` (lean — the line the gwta snapshot
  tracks) vs fresh `jm/<topic>`.

## Execution checklist (sema round only)

Read `sema/CLAUDE.md` verbatim → `/make-sema-word` ritual → the two schemas + registry
entries (`versioning_strategy: string`, `status: staging`) + enum values per (a) →
`scripts/build_indexes.sh` + `scripts/regenerate_runtime.py` → pytest + registry
validation green → suggest commit (JM commits). **Follow-on, separate (scada side, its
own gating):** gwsproto twins, `HpModel` enum retirement + the three consumer call
sites reading DeviceType from the layout, thin components into layouts/gens, the
OPS-450 maple sweep. First data for the records beyond nameplates: spruce steady-state
compressor draw 1.7–1.8 kW vs 4.3 kW circuit rating (2026-07-16).
