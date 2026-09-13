# Changelog

A reverse-chronological log of WHY we made each commit **in the
`tlayouts` code repo**. The matching git commit (in `tlayouts`) holds
the WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-09-10 — snapshot regen: RelayEnergizedLevel on the board records (`c4c026a` on jm/spruce)

The vendored snapshot regenerated from sema `7d58bd1`: `gw1.scada.device.type.gt`
with its required `RelayEnergizedLevel` and axiom 5. The two vendored board
records declare their relay drive: `gw108.revb` 1 (NPN low-side driver, a
high pin energizes), `scada.krida` 0 (active-low; power-on all-high leaves
every relay off). The snapshot registry is mirrored into the scada closure
copy in the same wave.

**Why:** the House0 relay decommission drives Krida relays through the same
relay actor as gw108's, and the two boards energize on opposite pin levels;
the relay actor translates from the record instead of hand-mapping by
DeviceType (sema changelog, same date).

## 2026-09-10 — snapshot regen: i2c.expander.type, ExpanderType on board records, SimKridaDoubleRelayBoard16 (`dd7fd0a` on jm/spruce)

The vendored snapshot regenerated from sema `f1e551c`: the new
`i2c.expander.type` enum, `i2c.expander` with its required `ExpanderType`,
and `gw1.sim.device.type` with `SimKridaDoubleRelayBoard16`. The two
vendored board records declare their chip: `gw108.revb` Tca9555, `scada.krida`
Pcf8575. The snapshot registry is mirrored into the scada closure copy in the
same wave.

**Why:** the House0 relay decommission drives Krida relays through the
same bus actor as gw108's, and the two expander chips speak different bus
protocols; the board record now says which (sema changelog, same date).

## 2026-09-12 — snapshot regen: zero.ten.power.on in the ops words, dac.output.config wiring only, Gp8403 DACs on the House0 board record (`6d28e10` on jm/spruce)

The vendored snapshot regenerated from sema `9cdeec5`: `zero.ten.power.on`
arrives, `dac.output.config` loses its EEPROM fields, `i2c.dac.type` gains
`Gp8403`, `i2c.dac.vref` leaves the closure. The seed lists
`dfr.component.gt` explicitly with a note: it is orphaned in sema and out
of `gw.house0.layout`'s union, so closure no longer reaches it, and
`house0_sema_gen.emit_dfr` still emits it until the gen moves to
per-output components. The House0 gen turns its three DFR levels (20, 40,
0 volts times ten; the DFR field name says times 100 and is wrong) into
`ZeroTenPowerOnList` entries; the Nolan gen's `DacOutputSpec` carries
`power_on_volts_times_ten` instead of a raw code and the DAC output config
drops the three fields; spruce and honeysuckle move from code 3020 (7.55 V)
to 76 (7.6 V). The `scada.krida` record gains two `i2c.dac.capability`
entries (`Dfr1`/`Dfr2`, `Gp8403`, 94 and 95, two channels each): the
board record is the bus population, and House0's I2C bus carries the
Krida expanders and the two DFRobot modules. The spruce gen validates
through the snapshot; tlayouts tests pass. The gens import `gwsproto`,
which the tlayouts env lacks: run them with the scada venv's python.

## 2026-09-09 — spruce: egauge port 05 meters the secondary pump (secondary-pump-pwr replaces dist-pump-pwr) (`60d4e11` on jm/spruce, titled "add egauge for secondary-pump-pwr"; actual-spruce commit pending)

The gw108 CT chain could not give a conclusive secondary-pump-on signal
(the 2026-09-07 bench: three of four ADC inputs tied, the CT picking up
the store pump), and the dist flow meter's port on the eGauge had a CT
with nothing useful behind it. George moved the eGauge CT to the
secondary pump, reconfigured port 05 as a 5 A CT named
`05-secondary-pump`. Both lines: the power channel at address 9008 is now
`secondary-pump-pwr` about a `secondary-pump` node (80 W nameplate,
5 W capture delta); `dist-pump-pwr` and its node are gone. Box layouts
replaced from these artifacts in the same window.

## 2026-09-09 — spruce: floor1 tank module is pico_71156b (`91ce50e` on jm/spruce; `e47b4d1` on actual-spruce)

The floor1 board on site is a fresh WIZnet (ethernet) pico, `pico_71156b`;
the layouts still named `pico_586e36`. `jm/spruce`: `spruce_sema_gen.py`
takes the new HwUid (commit titled "update pipes1"; the diff is the floor1
id). `actual-spruce`: `spruce.json` and the commented `gen_spruce.py` block
take the same HwUid. Both box layouts were replaced from these artifacts in
the same window. The board still has no ethernet cable, and when a pico with this id first
posted (after the 11:51 unlimbo restart) it identified itself as
store-btu, so it is being reprogrammed as floor1 before it can post.

## 2026-09-09 — spruce: fancoil, floor1 and pipes1 tank modules back in both lines (`b326578` on jm/spruce; `9c75b40` + merge `138c28e` on actual-spruce)

Two commits, one per branch, plus a merge on actual-spruce that only absorbs a re-authored duplicate of the July CT-notes commit. `jm/spruce`: `spruce_sema_gen.py` restores
the three `ExtraTankSpec` entries and their seven identity deriveds.
`actual-spruce`: `gen_spruce.py` restores the three `add_tank3` blocks,
drops the duplicate second registration of the pipes1/floor1 pair, and
takes the secondary-btu HwUid to `pico_108a2b` (the swap the box already
ran with, hand-edited there on 2026-08-10 and recorded on `jm/spruce` in
`50cf8df`, never on this branch); `spruce.json` is the pre-removal
artifact with that one HwUid fix, checked equal to the running box file
plus the three modules.

**Why:** the three wifi picos were physically disconnected on 2026-08-10
and are being re-powered; both scadas on spruce need to see them at
their next restart. The jm/spruce regeneration used the running
scada-experiment layout as its id reference, extended with the three
modules' ids from the actual line, so every existing node, channel and
component keeps its id and the restored channels carry the ids they had
before August in both lines.

## 2026-09-08 — one seed, one regen script (`3118aa7`)

**What:** `src/tlayouts/sema_seed_request.yaml` is the only seed: the nine
targets and the `local_names` rule moved in from the root-level
`tlayouts_seed_request.yaml`, which is deleted together with
`build_tlayouts_snapshot.sh`. The snapshot is rebuilt through
`scripts/regen_sema_snapshot.sh`; only its seed-copy indexes change.

**Why:** two seeds and two build scripts had drifted apart: the root pair
was the one recent commits used, while the README and the snapshot's own
banner pointed at the pair every other consumer has, sema's template
(`scripts/regen_sema_snapshot.sh` reading `src/<pkg>/sema_seed_request.yaml`).
One seed, one path, the one an LLM is pointed at from inside any snapshot.

## 2026-09-08 — five-v-boss in both sim gens; snapshot at sema a241693

**What:** both gens (`house0_sema_gen.py`, `nolan_sema_gen.py`) emit a
`five-v-boss` node (ActorClass `FiveVBoss`, handle `auto.five-v-boss`) and
reparent the pico cycler under it: `auto.five-v-boss.pico-cycler` and
`auto.five-v-boss.pico-cycler.<vdc relay>`. Snapshot rebuilt at sema
`a241693`: `gw1.actor.class/014`, `spaceheat.node.gt/303`, and both layout
words' command-node axiom name `FiveVBoss` as an interior node.

**Why:** the pico-cycler-command chunk of the `sh_node_actor` partition
puts a command node between the cycler and the 5 V relay, so admin asks the
boss to hold the picos' supply off instead of seizing the relay while the
cycler keeps running. The layouts have to carry the node before the scada
side can be tested on either sim fixture.

## 2026-09-08 — swap out spruce secondary btu pico

**What:** `spruce_sema_gen.py` names `pico_108a2b` as the secondary-btu
BTU meter's HwUid (was `pico_1c3c31`).

**Why:** the secondary BTU pico was replaced on site on 2026-09-08. The
scada accepts a pico's params only when its HwUid matches the layout,
so the uid has to change at the source. The two layout files on the
spruce box (the deployed scada's legacy file and the window scada's
`gw.nolan.layout` copy) were patched by hand the same afternoon; the
regenerated pair supersedes them at the next layout upload.

## 2026-09-07 — sim tank picos carry a liveness script; snapshot at sema fc741c2

**What:** `House0SemaGenConfig` gains `sim_pico_life_s` / `sim_pico_reboot_s`
(None = absent on the word); the sim tank emission passes them as
`SimLifeS` / `SimRebootS`. Both sim configs (house0-sim, spruce-sim) set
120 / 20. Snapshot rebuilt from `tlayouts_seed_request.yaml` at sema
`fc741c2`; the only vocabulary change is the two fields on
`sim.pico.tank.module.component.gt/001`.

**Why:** the sim picos have to die and reboot for the scada's pico-cycler
loop to be witnessed on a sim layout; 120 s life puts a flatline and a
cycle inside the five-minute dev-broker rung. `scripts/regen_sema_snapshot.sh`
and `src/tlayouts/sema_seed_request.yaml` are a stale pair (that seed drops
six words the gens use); `build_tlayouts_snapshot.sh` with the root seed is
what reproduces the committed tree.

---

## 2026-09-06 — patch linear.one.dimensional.calibration snafu (`0a051f9`)

The affine depth calibration in `house0_sema_gen.py` was a hand-built
dict pinned at `linear.one.dimensional.calibration/001`, a version sema
squashed away on 2026-08-13; every real-tank artifact since (spruce,
oak) failed to boot on the scada, unseen because the word sits outside
the layout closure (the derived-channel word types `Parameters` as a
bare object). Now the word is seeded into the tlayouts snapshot
(`tlayouts_seed_request.yaml`, with the reason) and the gen builds the
calibration through `LinearOneDimensionalCalibration(...).to_dict()`,
so its version is the snapshot's and the closure registry carries it
for the scada mirror check. The `tank_kind == "real"` gate on the
calibration is gone: a tank with a spec calibrates whether real or sim,
so the spruce sim pair (the scada's Nolan fixture) exercises the affine
path the real artifact boots with. Honeysuckle declares no tanks and is
unchanged. Snapshot rebuilt at sema `d6f59e7`.

---

## 2026-09-04 — correct power meter for honeysuckle (`56dbcd1`)

`honeysuckle_sema_gen.py` set `power_meter_kind="sim-egauge"`, a value
the config's `Literal["sim", "egauge"]` refuses, so the layout had not
generated since the config annotation landed. Honeysuckle is the pi on
a real gw108 at the Stoneman microgrid, not a simulated home, and the
site has a real eGauge (`eGauge14875.local`, hardware id `GC14050323`,
read off input register 100 the way `starter-scripts/egauge.py` does),
so the meter is `egauge` with that identity. The channel surface stays
the spruce twin: the eGauge's own register configuration ("Boost Power",
"Pump Power") is stale and its CTs are attached to nothing, so the nine
spruce registers read zero until the meter is reconfigured; the gen
docstring says so. The `sim-egauge` branches in `house0_sema_gen.py`
had no other caller and are gone.

---

## 2026-09-04 — snapshot at sema d6f59e7: writer trio out of the closure (`335e946`)

Snapshot rebuild after the sema layout-word edit (`d6f59e7`): the two
layout words dropped `i2c.dac.writer.component.gt` and
`sim.dac.writer.component.gt` from their Components unions, so those and
`i2c.dac.channel.config` leave the closure; Nolan axiom 5 gains the
`secondary-010v` clause. The seed request drops its explicit
`i2c.dac.writer.component.gt` line, listed before any layout referenced
the writer; with it gone nothing keeps the trio in the closure. The
Nolan sim pair regenerates byte-identical to the scada fixture, which
already carried the node.

## 2026-09-04 — Nolan gen emits DAC outputs, not the chip writer (`d6a995e`)

`emit_dac_output` replaces `emit_dac_writer`: the config axis is a list
of wired outputs (node name, DAC, channel, power-on code), each emitting
one `i2c.dac.output.component.gt` bound to its `ZeroTenOutputer` node
under local control, a `VoltsTimesTen` channel captured by that node,
and its capture tuning. Unwired channels no longer carry EEPROM defaults
in the layout, matching the word (an unwired channel has no component
and its EEPROM is never touched). Spruce and honeysuckle declare only
channel C as `secondary-010v`; spruce, spruce-sim and honeysuckle
regenerate. Honeysuckle does not: its config value `power_meter_kind=
"sim-egauge"` fails the generator's `Literal["sim", "egauge"]` (the code
paths handle the value; only the annotation refuses it), a pre-existing
break; a TODO on the config records it with the home's real identity
(the pi on a gw108 at the Stoneman microgrid, eGauge on site — the fix
is the egauge kind with that meter's identity, not a sim knob).

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
