# Changelog

A reverse-chronological log of WHY we made each commit **in the
`tlayouts` code repo**. The matching git commit (in `tlayouts`) holds
the WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-09-04 — Nolan gen emits DAC outputs, not the chip writer <!-- pending commit -->

`emit_dac_output` replaces `emit_dac_writer`: the config axis is a list
of wired outputs (node name, DAC, channel, power-on code), each emitting
one `i2c.dac.output.component.gt` bound to its `ZeroTenOutputer` node
under local control, a `VoltsTimesTen` channel captured by that node,
and its capture tuning. Unwired channels no longer carry EEPROM defaults
in the layout, matching the word (an unwired channel has no component
and its EEPROM is never touched). Spruce and honeysuckle declare only
channel C as `secondary-010v`; spruce, spruce-sim and honeysuckle
regenerate.

---

## 2026-09-03 — snapshot on the layout tree axioms (`447207b`)

Snapshot rebuilt at sema `818fa11` (the vendored layout words gain
PrefixClosedHandles and ActuatorLeaves): `gw.hydronic` gains optional
`HpCommandNodeName` and loses `Strategy` (the family is the layout
word); the vendored layout words carry the CommandableHeatPump axioms;
`new.command.tree` is not in the seed. The sim pairs regenerate
byte-identical to the scada fixtures.

## 2026-09-03 — generators drop Hydronic.Strategy (`541da84`)

The House0 and Nolan gens and every script stop passing a strategy
label; the family is the layout word.

---

## 2026-09-03 — House0 gen emits UseSiegLoop on the ops artifact; snapshot on the sieg split (`1741a26`)

Snapshot rebuilt at sema `7c3e0bd`: `gw.hydronic` without `SiegLoopPlumbed`
and `UseSiegLoop`, `gw.house0.operational.params` with `UseSiegLoop`
(`layout.lite` is not in the tlayouts seed, so its rename does not
appear here). The House0 gen keeps `use_sieg_loop` as
a config axis but emits it on the ops artifact; `sieg_loop_plumbed`
leaves the config (the plumbed sieg surface is what the House0 word
means). The Nolan gen drops both from its hydronic block.

---

## 2026-09-02 — sim-House0 pair authored; House0 gen carries the sieg surface, hp parts and zone circuits (`85e7364`)

`gen_house0_stub_sema.py` becomes `house0_sim_sema_gen.py`: the little
orange house as the all-sim shape of the beech family word, emitting the
scada suite's second House0 pair (`gw.house0.sim.*`). The House0 gen
catches up to `gw.house0.layout` axioms 3, 7, 8, 10 and 11: the
sieg-loop command node, sim sensors (`sim.sensor.component.gt` +
SimSensorActor) behind dist / primary / store / sieg flow and the sieg
cold side, `hp-odu` and `hp-idu` on `device.component.gt` through
`HpPartSpec` (moved here from the Nolan gen, which now imports it), and
per-zone `ZoneCircuitSpec` (actuator, role, setpoint source, thermostat
kind, hub device id) driving both Hydronic.ZoneCallCircuits and the
zone's temperature realization: HoneywellViaHubitat emits the hub
poller, MechanicalDial on a simulated home emits a sim temperature
sensor (`<zone>-temp-sensor`, no name constant yet). Every zone carries
its TempChannelName. `zone_device_ids` retires into the circuit spec;
`minted_gnodes` supplies identity for sema-shaped references; the
thermistor-common relay leaves the table (the fixture dropped it
2026-08-31); the store-pump relay resolves through the hydronic node
tier. Two pre-existing name drifts fixed in passing (backup /
scada-blind moved to the House0 tier). `gen_oak_sema.py` still passes
`zone_device_ids` and stays guarded behind the missing no-sieg word.
The snapshot rebuilt from sema `0496374` rides along so the vendored sim
vocabulary carries `SimHpIdu`.

## 2026-09-02 — snapshot carries gw.house0.layout axioms 10-11 (`cdf531c`)

Snapshot rebuilt from sema `dfe93be`: the vendored `House0Layout` now
enforces `RequiredActuators` and `RequiredHeatpumpEquipment`, so the
House0 stub gen cannot emit a fixture the canonical word rejects. The
gen itself is unchanged and still owes the sieg-surface fold-in (plus
`hp-idu`, the zone circuit and the LG parts the scada fixture now
carries by hand) before its next regen; it currently stops earlier on a
stale `house0-layout.json` diff-and-adopt path.

## 2026-09-02 — sim-spruce pair on the reshaped Nolan word; sim device types (`a36c5ce`)

The Nolan generator emits the per-tank element relays
(`tank1-top-elt-relay` / `tank1-bottom-elt-relay`, board silkscreen
unchanged) and the spruce power channels rename to element-first
(`buffer-top-elt-pwr`, `tank1-top-elt-pwr`, …) with their about-nodes.
Simulated devices come from `gw1.sim.device.type`: the board twin is
`SimGw108`, sim sensors `SimSensor`, the sim meter `SimPowerMeter`, and
the sim-spruce heat-pump parts are `SimHpOdu` (nothing talks to it) and
`SimSamsungAE055FEYMCG` (the control box hp-boss will practise modbus
against), with no device-type records. Snapshot rebuilt to carry the
new words (`i2c.dac.output.component.gt` listed explicitly beside the
writer it replaces; the sim enum listed because nothing $ref-s it).

## 2026-09-02 — component's local unique name now comes from ShNode name (`eaecf42`)

Three layouts exist in the field, and gw.house0.layout now means
has-a-siegenthaler-loop, so the three sieg-less homes cannot be authored
under it. New `house0_no_sieg_sema_gen.py` stub raises
NotImplementedError naming the missing word; the commented gen_elm /
gen_fir / gen_oak translation specs call it live at the top, and
gen_oak_sema.py — which was actively authoring oak as gw.house0.layout —
is guarded the same way. gen_house0_stub_sema.py carries a
fold-in-before-regen note: the scada test fixture it emits was
hand-extended with the sieg surface, and a regen without folding that in
would revert it. The Nolan generator gains the hp-boss command node
(HpBoss, auto.lc.n.hp-boss — required in every layout now) and the
sim-spruce pair regenerates with it; house0_sema_gen catches up to the
scada names commit (House0NodeNames is a flat vocabulary class — the
config's `n` property stops instantiating it, tank node helpers come
from Tanks). The vendored snapshot rebuilt from sema `2649929` (new
layout axioms, HpTwin); the sim pair regenerates clean through the new
validators. Found en route: the four sim.sensor BTU components re-mint
ComponentIds on every regen — the id-map key misses them; FIXED (the
sim branch's DisplayName prefix now matches the id-map lookup;
double-regen verified byte-identical). Both generators are sema-fied:
pydantic dataclasses with snapshot property formats (SpaceheatName /
PascalCase / HhMm / MacAddress / LeftRightDot) on every
vocabulary-shaped spec and config field, Literal for local axes,
`ct_channel` an Optional SpaceheatName (absence is absence, not "").
The board record renames with the enum:
`gw108.revb-gw1.scada.device.type.gt-000.json` with DeviceType
Gw108RevB (rev B named now because the next rev diverges
significantly); the snapshot rebuilt clean from sema `99ffd4f`
(Gw108RevB + Gw101 through the vendored words and samples).

Component identity now keys on ATTACHMENT, never caption — built
test-first (tlayouts' first test, `tests/test_component_id_stability.py`:
mangle every DisplayName in the reference, ids must survive; red under
the old keying). `LayoutIDMap` registers each component id under every
derivable key — `node:<referencing-node>`, board bindings
(`relay:`/`gpio:`/`dac:`/`adc:`), and a `type:<TypeName>#<ordinal>`
fallback — and all 22 `component_id` call sites pass attachment keys.
Migration proof: regen against the shipped pair is byte-identical.

The gw108 board joins the node world: the generator emits a `gw108`
equipment node (NoActor, ComponentId → the board record — the hp-odu
pattern), and the board is a DEFAULT hardware choice, not hardwired:
`board_node_name` + `board_record_file` config axes with gw108-revb
defaults (the hardware-decoupling direction; `gen_alt_nolan.py` — the
Nolan plant on House0-style hardware — is the coming N=2 proof, gated
on the krida retirement). The board component's id survived the
nodeless→node-referenced transition via the adoption keys.

The identity key then simplified to ITS ENDPOINT: the referencing
ShNode's bare Name (ComponentBinding — every component HAD by exactly
one node; ComponentId stays as the replaceable instance uuid under the
name). The web server got its node (`web-server`, a new CoreNodeNames
constant), making the Nolan artifact fully 1:1 (85 nodes); legacy
type-keys remain only for adoption and House0's krida trio (marked in
the gen; they dissolve with the retirement). Tests:
`test_emitted_components_are_node_bound` here, ComponentBinding
fixture tests scada-side (House0's skipped until the retirement).

## 2026-08-31 — sim-spruce: the simulated Nolan pair is authored; gens catch up to ops word + names tiers (`316d3ae`)

New sim variant of the spruce home config: same sensed nodes, simulated
drivers — tanks on `sim.pico.tank.module.component.gt`, BTU meters on
`sim.sensor.component.gt` + `SimSensorActor`, the board component on
`GridworksSimGw108` with the register-twin `gw1.scada.device.type.gt`
record copied from the real gw108 record (so address resolution cannot
drift), aliases `d1.isone.me.versant.keene.spruce.*`. The gen also emits
the pair's ops artifact as `gw.nolan.operational.params` (the family gen
had still emitted the house0-named word). The emitted pair replaces the
scada suite's hand-tended `tests/config/gw.nolan.{layout,operational.params}.json`.

Getting there took two catch-ups the gens owed: the snapshot re-vendored
with `gw.nolan.operational.params` (+ `gw.tou.window` closure) and the ops
assembly rebuilt to the post-08-13 word shape (`OpsSpec` gains
actuation_authority / service_mode / hp_max_kw_el / on_peak_windows;
system_mode and lat/long leave; all four home configs updated — the
house0-family stub/oak configs compile but their gens still point at a
deleted id-reference file); and the committed names tiers
(`local_control_normal` → Core, `vdc_relay` → HydronicSpaceheat). Gens run
against gwsproto at scada HEAD. Also per no-assumed-defaults:
`thermistor_zone_idxs`, `setpoint_source`, `thermostat_kind` are now
required per home/circuit. Entry to be reconciled against the diff at
commit time.

## 2026-08-31 — required Nolan surface: full plant relay set, HP parts, core sensing (`4be7fdc`)

Snapshot re-vendored on sema `44937ad`. `emit_plant_relays` emits the nine
relays axiom 3 forces (charge valve on the "DischargeValve" silkscreen;
store pump; four element relays); the Nolan system-actor skeleton drops
hp-boss / backup / scada-blind (return with the Nolan state-machine and
hp-boss-modbus waves); `emit_heat_pump_parts` + the `HpPartSpec` config
axis put the monobloc and control box into the layout as
`device.component.gt` components (nameplate serial on spruce's ODU) with
their hp device-type records (authored in `device_types/` from the
nameplate photos); the MIM-B19N rides the ctrl-box Description. The bench
carries the full sensing surface: four placeholder-uid BTUs and the new
`power_meter_kind="sim-egauge"` (spruce's channel list, imported from the
spruce config so it cannot drift, on the sim meter driver). All three
homes regenerate and validate; axioms proven to fire on isolated
counterexamples.

## 2026-08-22 — comment out old gen files (`687bfd4`)

The pre-sema per-house generators (`gen_almond.py`, `gen_beachrose.py`,
`gen_beech.py`, `gen_elm.py`, …) are commented out: the sema gens
(`house0_sema_gen` / `nolan_sema_gen`) are the live path, and the old files
no longer run against the current vocabulary. Kept in-tree, inert, as
reference for house-specific facts not yet re-encoded.

## 2026-08-23 — sema scripts and clear descriptions (`13831a1`)

tlayouts vendored its Sema snapshot with no seed or regen script in-repo —
refreshing meant hand-running the sema CLI. Adds the standard
`scripts/regen_sema_snapshot.sh` (instance of sema's
`template_regen_snapshot.sh`, `--allow-staged` while the layout closure
stages) and a **minimal seed**: the two layout words plus
`gw.house0.operational.params` — everything else the repo touches
(components, channels, `g.node.gt`, enums) arrives through dependency
closure. Drops the previously-seeded heads (`gw1.simple.sim.layout`,
component words) as direct targets; any still referenced by the layouts
re-enter via closure, the rest leave the snapshot. The repo also gains its
first README — what tlayouts is, the `./output` destination, the standard
Sema paragraph (canonical language + boundary-scoping sentence), and the
remaining-scada-coupling note. That coupling shrinks in the same commit:
the two board descriptors (`krida_double_relay_board_16_device_type`,
`gw108_device_type`) stop importing from gwsproto python constants and
become vendored `gw1.scada.device.type.gt` instances under
`src/tlayouts/device_types/`, decoded through the snapshot at import — so
what remains of the scada-venv dependency is the `gwsproto.names`
constants only (tracked against the scada renovation's names outcome).

## 2026-08-14 — minor (`635cf57`): honeysuckle carries the full plant surface

Landed under the title "minor" (verified against the diff: 24 lines in
`honeysuckle_sema_gen.py` — zone-call circuits + plant relays + the
sim-uid `primary-btu` — plus deleting the superseded `-16sps-2hz`
variant artifacts). Original entry:

The bench layout satisfies `gw.nolan.layout` axiom 3
(LocalControlPlant) and runs the TOU cooling loop against the real
board with zero stakes: four floor circuits at positions 1–4
(mirroring the spruce held-zone shape), the plant relays their gate
emits, and a `primary-btu` with a sim placeholder pico id —
`layout.lite` axiom 1 rejects a NoActor-captured channel, and the
bare `emit_primary_flow` fallback produced exactly that (a
bench-only conflict the new suite fixture surfaced; spruce provides
primary-flow from its real BTU). The regenerated artifact doubles
as the scada suite's pinned Nolan fixture, replacing the
legacy-format one.

## 2026-08-12 — DAC writer node emission: dac_channel_power_on_raw axis; snapshot on actor.class 013 (`355045e`)

The tlayouts side of the DAC leg (scada `e551c2e1`/`12d6a1bc`; sema
`1883372`/`91385fe`). The gen gains a `dac_channel_power_on_raw`
config axis — the per-channel EEPROM power-on values become the
house config's declaration instead of values hard-coded in the
emitter — and `emit_dac_writer` emits the actor node beside the
component, gated on that axis rather than on zone circuits (so a
bench layout can carry the DAC path alone). The vendored sema
snapshot rebuilds on actor.class 013 (possible once the partition
correction put node.gt/303 back in staging); both artifacts regen
with the `gw108-dac2-writer` node native.
