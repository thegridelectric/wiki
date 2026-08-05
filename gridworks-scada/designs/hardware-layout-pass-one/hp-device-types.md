# HP device types — hp.device.type.gt + hp.control.box.device.type.gt (spoke)

Status: Draft · Pass 0 · Updated 2026-07-19 · Linear: OPS-407

> What this is: the converged design for retiring `gwsproto.enums.HpModel` into the
> device-type model — two new sema record families for heat pumps, the enum values, and
> how the layout carries them. Design converged 2026-07-15..17 (spruce field work +
> maple pump-doctor bug); written here for a fresh session to EXECUTE via
> sema word-authoring (read `sema/spec/primary.md` + the authoring spokes
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
  Optional: `Refrigerant`, `CompressorRatedAmps`, `Mca`, `Mop`, `ProductInfoUrl`,
  `DisplayName`.
- **`hp.control.box.device.type.gt/000`** — control boxes (the monobloc's indoor unit:
  hydraulics, control electronics, local touch-screen, ODU comms; no compressor).
  Required: `DeviceType` + the three pump facts. Optional: `WaterPumpRatedAmps`,
  `BackupHeaterKwList`, `Mca`, `Mop`, `ProductInfoUrl`, `DisplayName`.
- **`ProductInfoUrl`** (plain string, both families) links the publicly accessible
  product-info folder — the GridWorks pattern of a public Drive folder per device
  category (manuals, nameplates, wiring diagrams, controls notes). Deliberately
  unconstrained (no url format yet; scheme uncertainty), single field not a list.

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

## Decisions (resolved 2026-07-19, JM)

- **(a)** Append the two values to staging `gw1.device.type/001` in place — staging is
  mutable, no cascade.
- **(e)** Sema branch: `jm/i2c-relay-capability` — the line the gwta snapshot tracks;
  the single-bus-owner sema round (`Gw108Adc` + thermistor-reader `/003`) shares it.

## Execution state

- ✅ **Sema round** (sema `69bcac8`, 2026-07-19): the two schemas + registry entries
  (`versioning_strategy: literal` — the registry-wide convention; the earlier `string`
  note was a slip), enum values appended per (a), `ProductInfoUrl` on both families.
- ✅ **Nameplate examples** (sema `2925363`, merged to dev): real AE055 values from the
  Drive transcription; `MaxKwEl: 4.35` derived (18.9 A × 230 V), JM to confirm.
- ✅ **gwsproto twins** (scada `a7716865`): `HpDeviceTypeGt` +
  `HpControlBoxDeviceTypeGt`, in the `DeviceTypeDecoder` union; `sema validate` OK;
  conformance sweep fully conformant.
- **Remaining (scada side, its own gating):** `HpModel` enum retirement + the three
  consumer call sites reading DeviceType from the layout
  (`orig_sieg_loop.py`, `sh_node_actor.py:1325`, `all_tanks_tou.py`), retire
  `ScadaSettings.hp_model`/`hp_max_kw_el`, thin `hp-ctrl-box` components into
  layouts/gens, the OPS-450 maple sweep. First data beyond nameplates: spruce
  steady-state compressor draw 1.7–1.8 kW vs 4.3 kW circuit rating (2026-07-16).

## Open wrinkle: control-box Mca/Mop are per-heater-config

The AE055FEYMCG nameplate lists MCA/MOP per backup-heater configuration (2 kW: 12.0/15.0;
4 kW: 22.9/25.0) — the flat optional `Mca`/`Mop` fields cannot carry both, so the box
example omits them. Options when it matters: a per-stage list shaped like
`BackupHeaterKwList`, or treating Mca/Mop at the category level as unset where
config-dependent. Decide before the fields are load-consumed.
