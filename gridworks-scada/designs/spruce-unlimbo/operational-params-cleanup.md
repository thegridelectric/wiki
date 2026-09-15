# Operational params cleanup (spoke)

Status: Draft · Pass 0 · Updated 2026-09-15 · Linear: OPS-392

> What this is: spruce-unlimbo spoke that finishes the operational-params
> surface: each family's ops word carries only what that family tunes,
> and the tunables still living in scada settings move to the ops word.
> The per-family decode, the paired-artifact check and the identity /
> site-fact removals are done; what remains is listed here.

## ▶ Do this next

Items 2 to 5 below need no sema change and ride on any scada commit;
take them first. Item 1 waits for `control-strategy-selection.md` to
land the per-role selectors, because the store knobs it removes are
what the loaders select on today.

## The words today

Both `gw.house0.operational.params/000` and
`gw.nolan.operational.params/000` are **staging** (in-place edits, no
version). They share `ScadaAlias`, `CaptureTuningList`,
`ZeroTenPowerOnList`, `ActuationAuthority`, `ServiceMode`, `CopCurve`,
`HeatingCurve`, `HpMaxKwEl`, `OnPeakWindows`, and the six House0 store /
optimization knobs (`SeasonalStorageMode`, `HpTurnOnMinutes`,
`ShortCycleBuffer`, `LoadOverestimationPercent`, `OilBoilerBackup`,
`HorizonHours`). House0 alone carries `UseSiegLoop`.

The scada decodes the ops artifact through the word its `TypeName`
names (`sema_to_dc.py` `decode_operational_params`), refuses a
layout/ops pair that is not in `APPROVED_PAIRS`, and finds the file as
`operational-params.json` beside the layout (`actors/config.py:22`).
`.ops` is the union of both gwsproto types; House0-only fields are
reached through `isinstance` guards (`sema_to_dc.py` `use_sieg_loop`).

## What this spoke owns

1. **The Nolan word sheds the store knobs.** A Nolan home has no thermal
   store to season; the six knobs ride on its word only so the
   House0-shaped loaders, `layout.lite` and the derived generator run for
   every family (the `⏳ TEMPORARY` note in gwsproto
   `nolan_operational_params.py` says so, in a docstring that should be
   `Sema: <url>` only; the note lives here now). Once
   `control-strategy-selection.md` gives each ops word its own selector
   per control role and `SeasonalStorageMode` retires, remove the six
   fields from the Nolan word in place, regenerate the gwsproto twin and
   the sim-spruce / spruce / honeysuckle ops output from tlayouts, refresh
   the closure mirror, and `sema validate` both fixture pairs. Sema
   word-gate before the edit. `CopCurve` / `HeatingCurve` stay: Nolan
   heating-season control will want them.
2. **`whitewire_threshold_watts` leaves scada settings.** A heat call is
   sensed by opto (Nolan) or by metering the call wire (House0); which, is
   a wiring fact the layout already binds through the heat-call
   `derived.channel.gt` and its `Parameters["Threshold"]`. The settings
   field duplicates that parameter, and its one reader is
   `procedural/dist_pump_monitor.py:147`. Point the reader at the
   channel's parameter and delete the setting. Do not move `Threshold`
   out of `Parameters`: `derived.channel.gt/002` is published, so a
   `HeatCallTuningList` on the ops words would cost a word version for no
   behavior change this season.
3. **`Latitude` / `Longitude` are required settings, not defaults.**
   They left the ops word as site facts and now sit in `ScadaSettings`
   and `LtnSettings` with Millinocket defaults (`actors/config.py:133`,
   `actors/ltn/config.py:45`). An assumed default hides a value the
   deployer must declare; make both required from `.env`, until the
   TaValidator owns site facts.
4. **Leftover dead files and the duplicate validator.** `show_settings.py`,
   `getkeys.py`, `scratch.py` through `scratch4.py` in `gw_spaceheat/`.
   `HydronicLayout.validate_house0_system_models` duplicates
   `gw.house0.layout` axiom 8, and the runtime layout is built only from
   the validated word (`HydronicLayout.from_sema`; `load_dict` is gone),
   so delete it.
   Ask before each delete batch.
5. **`tank_kind` is required in the gen config.** `LayoutGenConfig`
   defaults it to `"sim"` (`tlayouts/src/tlayouts/layout_gen.py:217`),
   an assumed default answering a varying question; make it required like
   the thermostat axes.

Then the docs: `../../designs/hardware-layout-pass-one/operational-params.md`
still describes one word with `SystemMode`, `Latitude` and `Longitude`
inline and `hp_model` / `whitewire_threshold_watts` bound for the layout;
bring it to the two-word shape above, or fold it into the executor and
delete it when that hub closes.

## Gates and sequencing

- Sema word-gate before item 1: read `sema/spec/primary.md` plus the
  `registry/` and `authoring/` spokes for types, post the summary, wait.
- gwsproto mirrors, the tlayouts ops output and the closure mirror move
  in the same cluster as the sema edit; `sema validate` on both fixture
  pairs proves the pair.
- Mirror-before-artifact: gwsproto mirrors deploy to scada and LTN
  before any ops artifact speaks a new enum value; an unknown value
  coerces silently to the default at decode, and a coerced authority is
  a lie with actuation consequences.

## Owned elsewhere

Items this spoke once queued and that other spokes now carry:

- `SeasonalStorageMode` retirement and per-role strategy selectors:
  `control-strategy-selection.md`.
- Nolan-wrong direct name reads, actor ↔ layout duplicate properties,
  the `H0N` / `H0CN` retirement, the hydronic file reviews:
  `correct-house0.md` rung 5.
- The House0 fixture pair regenerated from tlayouts, the suite green
  against both families: `correct-house0.md` rungs 1 to 4.
- Axiom counterexample fixtures per layout word: `layout-word-axioms.md`.
- Heat-pump components and device-type records replacing
  `ScadaSettings.hp_model`; hp-boss as modbus owner: the spruce-settled
  `hp-device-type-records` and `hp-twin` spokes.
- Retiring `layout.lite` in favour of the raw layout + ops words: the
  spruce-settled `publish-layouts-and-operational-params` spoke; until
  then the scada keeps sending `layout.lite`
  (`control-strategy-selection.md` decision 4).
- MonitorOnly meaning no physical write of any kind, board
  initialization included: `relay-actor-enforcement.md`.

## Open

- Whether `OilBoilerBackup` and `ShortCycleBuffer` are durable House0
  vocabulary or implementation hacks; and whether
  `LoadOverestimationPercent` / `HpTurnOnMinutes` / `HorizonHours` are
  knobs or belong on a curve. Both questions belong to the House0 control
  refactor, not this pass.
- Live ops updates without a reboot (capture tuning above all) are the
  update-path item in `control-strategy-selection.md` "Open".
