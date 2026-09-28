# tlayouts — spec (primary)

Status: Draft · Pass 0 · Updated 2026-09-18

> What this is: the generators that author every GridWorks hardware layout
> and its paired operational params as validated Sema words, and the repo
> that stands in as the record of those artifacts until the terminal-asset
> registry exists. Acceptable-minimum hub: overview, invariants, glossary;
> the rest is Open and the `tlayouts` repo is the authority.

## Overview

A house's layout is never hand-kept. A per-house **driver** at the repo
root (`beech_gen.py`, `spruce_gen.py`, `orange_sim_gen.py`, …) holds that
house's install facts as a config and hands it to a **family gen**, which
emits two artifacts into `output/<house>/`: the layout word for the
house's family (`gw.house0.layout` or `gw.nolan.layout`) and a
`gw.operational.params` instance carrying that family's params block.
The layouts regenerate for every new install, so the gens are the thing
to get right, not any output file.

- **`src/tlayouts/layout_gen.py`** is the base: `LayoutGen` holds the
  accumulators (GNodes, nodes, channels, derived channels, components,
  device-type records, capture tunings, 0-10 V power-on levels), the id
  helpers and the emitters every family shares. It builds the runtime
  shape, and the two authored artifacts split from it at serialization:
  the static layout with capture params stripped, and the operational
  params (`layout_gen.py:13`, `build_ops_kwargs` `:350`).
- **`house0_sema_gen.py`** and **`nolan_sema_gen.py`** are the family
  gens. Each owns only the plant roster its word requires and its own
  `build()` order. `hydronic_zones()` on the base returns `ZoneCore`
  (`layout_gen.py:420`) and each family gen builds its own `HvacZone`
  from it: House0 takes the zone's ADS `gw-temp` channel when the zone
  has one and the thermostat temp otherwise
  (`house0_sema_gen.py:135`); Nolan always names `gw-temp`
  (`nolan_sema_gen.py:331`).
- **`src/tlayouts/hardware/`** realizes one hardware kind per module
  against the board record, with the spec dataclass beside its emitter:
  board, i2c relay, gpio relay, gpio sensor, DAC output, thermistor,
  tank module, power meter, BTU meter, Hubitat zone.
- **`src/tlayouts/device_types/`** vendors the device-type records the
  gens bind components to (gw108 rev B, the Krida board and its sim twin,
  the Samsung outdoor unit and control box) in wire form, and defines
  `SimDeviceType`.
- **`src/tlayouts/sema/`** is the vendored Sema snapshot, built by
  `scripts/regen_sema_snapshot.sh` from `sema_seed_request.yaml` against
  a sibling `sema` checkout and never hand-edited. The scada repo keeps a
  byte-for-byte copy of its `registry.yaml` as the layout closure its
  conformance test reads, so a snapshot regen and that copy move in the
  same wave.

Drivers run from the scada venv
(`../gridworks-scada/gw_spaceheat/venv/bin/python beech_gen.py`); the
coupling is the `gwsproto.names` constants the gens import. A driver's
`main()` is the validation gate: it serializes both artifacts and decodes
each back through the snapshot codec, which runs the word's axioms,
before anything is written (`oak_gen.py:222`).

The houses today: beech and maple (House0, deployment), spruce and
honeysuckle (Nolan; honeysuckle is the bench), and the sim pairs
orange-sim, willow-sim (House0) and spruce-sim (Nolan), which are the
scada suite's fixtures. Oak, fir and elm have no siegenthaler loop and
are authored as House0 fixtures that are not deployable: each carries a
pretend `sieg` flow meter and `sieg-cold` thermistor so the House0 word
validates (`oak_gen.py:204`), until a sieg-less layout word exists.

## Temporary authority

The durable home for layouts and operational params is the
terminal-asset registry ([OPS-471](https://linear.app/gridworks/issue/OPS-471)),
from which the LTN hands a scada both artifacts
([OPS-531](https://linear.app/gridworks/issue/OPS-531)). Until then this
repo is the record: install facts, ops values and GNode identity live in
the drivers as Python. Once the registry holds a house, that house's gen
runs at commissioning or a rewiring, its output is committed to the
registry, ids come from the record, and the gen is never re-run over a
live record.

## Invariants

- **Ids survive regeneration.** `LayoutIDMap` (`layout_id_map.py`) reads a
  reference layout and keys every UUID by name, so a name present in the
  reference keeps its id. Components key on their attachment (the node
  they bind to, the board binding, or type plus ordinal), never on a
  caption; a caption change SHALL NOT mint a new ComponentId
  (`tests/test_component_id_stability.py`). A renamed node, channel or
  node-bound component keeps its id when the rename is declared per house
  in the config's `renames` (new name, deployed name). Undeclared, the new name is minted and the
  channel's history splits at the id.
- **A deployed house's ids come from its pi, then from the gen's previous
  output.** The spruce, beech and maple drivers fetch the pi's running
  `hardware-layout.json` over rclone into `output/<house>/<house>.uploaded.json`
  (`LayoutIDMap.fetch_or_last_copy`; offline, the last fetched copy) as
  the reference, and pass their own last layout output as `previous`. A
  name the pi lacks keeps the id the previous output gave it, so two
  runs give identical bytes; a previous-output id the pi assigns to
  another name is skipped (`LayoutIDMap.without_ids_of`). `output/` is
  gitignored, so a minted id is durable only on the laptop that minted it
  and on the box the layout was put to.
- **Every component is referenced by exactly one ShNode** (the second
  test in the same file).
- **No assumed defaults.** A fact the word requires and the config does
  not state raises in the gen: heat-pump parts, zone circuits covering
  each zone exactly once, Nolan zone-call circuits, a thermistor for
  every Nolan zone (`nolan_sema_gen.py:325`), a thermistor data rate the
  board's ADC supports (`hardware/thermistor.py:182`), a nameplate on
  every transactive power node (`layout_gen.py:491`).
- **A Nolan layout derives one heat call per zone-call circuit, not per
  zone.** Spruce's fancoil is circuit 5 of the `living-rm` zone: its
  whitewire, opto, relay pair and `-heat-call` carry the pi's ids, and the
  pi's old `zone5-living-rm-fancoil` zone node has no counterpart.
- **The sieg-loop flow identity is structural.** primary-flow =
  sieg-send-flow + sieg-flow; a house measures sieg-flow and one of the
  other two, and `emit_primary_flow` derives the third
  (`layout_gen.py:676`).
- **Async capture deltas are in the channel's encoding.** Temperature
  channels are `CelsiusTimes100`: tank depths and the sieg-cold sim
  sensor capture at 200 (2 °C), ADS pipe temps at 50
  (`hardware/tank_module.py:79`, `hardware/thermistor.py:87`,
  `house0_sema_gen.py:369`).
- **The board is a config axis.** gw108 rev B is the default
  (`layout_gen.py:232`); beech, maple, oak, fir, elm and the House0 sim
  pairs declare the Krida record, the sim pairs with its sim twin.
- **A Nolan zone carries a derived setpoint.** `emit_zone_setpoints`
  emits `zone{i}-{label}-set` per zone, a `FahrenheitX100` DerivedChannel
  over the zone's `gw-temp` and heat call
  (`nolan_sema_gen.py:287`).
- **A zone's heat call is a derived channel** over either the whitewire
  power (`GreaterThanThreshold`, 10 W) or the whitewire opto
  (`DigitalZeroIsActive`), chosen by `heat_call_source`
  (`layout_gen.py:754`). The 10 W value is an unmeasured assumption.

## Config specs

- **`FlowSpec`** — one standalone flow meter at a `position`, an open
  `SpaceheatName` the `<position>-flow` / `-hz` grammar composes
  (`FlowNodeNames` / `FlowChannelNames`): `dist2` → `dist2-flow`, `sieg-send`
  → `sieg-send-flow`. `node_name` is the name a deployed pico posts under
  when it is not the grammar's: its node and flow channel take that name,
  its Hz channel `<node_name>-hz`, and `<position>-flow` is an identity
  DerivedChannel over the flow channel (maple's `sieg-send`; a one-off for
  a pico that cannot be renamed). `kind` picks the pico family: `hall` (the fleet
  default, Saier, `ConstantGallonsPerTick` 0.0009, sets
  `PublishEmptyTicklistAfterS` / `PublishTicklistPeriodS`) or `reed` (keeps
  `PublishAnyTicklistAfterS` / `PublishTicklistLength`); `flow_meter_type`
  overrides the meter type (`SaierFlowSensor` for Hall;
  `OmegaFtb8010FlowMeter` for a second dist meter). `btus` lives on the base
  config and `emit_btu_meters` runs before the standalone flows, so a
  position a BTU pico already measures (beech's `primary-flow`,
  `dist-flow`) skips its bare-flow emit.
- **`TankSpec`** carries asymmetric depth-1/3 calibration and
  `sensor_order`, the pico's physical-sensor → depth mapping.
- **`AdsChannelSpec`** carries a thermistor make-model axis (default Tewa;
  beech's zone air-temps are Amphenol).

## Open

- Maple's `hp-lwt-amph` and `hp-ewt-amph` are optional hand-added nodes
  and channels the House0 word does not require; the maple gen declares
  them and they keep the pi's ids. The pi's ADS config gives both
  `TerminalBlockIdx` 10 and the Tewa make-model despite the `amph` name, so
  their real terminal blocks and thermistor type have to come from the
  house before the gen states them.
- Sub-specs: the base emitters and their order, each `hardware/` module,
  ops-params synthesis, the sim pairs.
- The gens need the scada venv; tlayouts could depend on scada as a
  package once scada is one.
- Minted ids have no durable home: a fresh laptop with no `output/` mints
  every name the pi lacks again. The terminalasset registry is the
  intended id authority ("Temporary authority").
- Nothing checks that a pi name absent from the gen output is retired
  rather than an undeclared rename; the comparison is by hand.
- elm, fir and oak take no reference and mint every id on each run; they
  take the pi-then-previous reference when their layouts go to a box.
- The ADS board component keys on a type key rather than a node
  (`hardware/thermistor.py:60`).
- beech and maple write `hardware-layout.generated.json` and
  `operational-params.generated.json`; every other house writes
  `gw.<word>.json` names.
- `old_gen_beech.py`, `old_gen_maple.py` and `old_gen_spruce.py` are
  fully commented out and state their own delete condition, which beech
  and maple have met.
- `hp_parts`, `zone_circuits` and `zone_call_circuits` are required in
  effect but typed with empty defaults.
- The real beech Krida record carries an older DisplayName than the
  vendored record.
- Guesses authored in the gens, each to confirm: the tariff alias
  `versant.a1.home.eco.bonus` on every gen; beech and maple tank
  modules `PicoWiznetEth2350`, their other picos and all of spruce
  `PicoRaspberryWifi2040`; `MicropythonVersion` absent everywhere.
- `device_types/__init__.py` keeps its own plain-class `SimDeviceType`
  value list instead of the snapshot's `gw1.sim.device.type` enum.
- No `ci.sh`; the gate is the two tests plus each driver's decode.
- Hand-fit tank calibration becomes a `gw1.tank.temp.calibration.map`
  fed to the gen instead of edited into `TankSpec`.

## Glossary

- **driver** — a `<house>_gen.py` at the repo root: one house's config
  and its `main()`.
- **family gen** — the generator for one layout word (`house0_sema_gen`,
  `nolan_sema_gen`), built on `LayoutGen`.
- **reference** — the prior layout a driver reads ids from.
- **sim pair** — a simulated house whose layout and ops files are scada
  test fixtures; every device is a `SimDeviceType`.
- **fixture house** — oak, fir, elm: real houses authored against a word
  that does not fit them, not deployable.
