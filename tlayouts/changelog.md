# Changelog

A reverse-chronological log of WHY we made each commit **in the
`tlayouts` code repo**. The matching git commit (in `tlayouts`) holds
the WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-09-24 — every gen declares the primary-pump owner and refrigerant cycle; maple's primary-pump actuators leave (OPS-392, `d38bf49` on jm/spruce)

Snapshot regenerated from sema `e54adcd` (`jm/hp-facts-hydronic`):
`gw.hydronic` requires `PrimaryPumpOwner` and `RefrigerantCycle`, House0
axioms 31 `PrimaryPumpActuators` and 32 `PrimaryPumpRecordAgreement`,
Nolan 29. `LayoutGenConfig` takes `primary_pump_owner` and
`refrigerant_cycle` with no default; the House0 gen emits the
primary-pump relay pair only when the scada owns the pump. Beech, oak,
fir, elm, orange and willow: Scada / Cascade; spruce, honeysuckle: HeatPump
/ Single. Maple: HeatPump / Single, `primary-010v` and the relay pair
gone, `primary-pump-pwr` disabled. Why: maple's heat pump is now a
single-compressor Ecodan whose hydrobox runs the primary pump, so the
scada has nothing to drive there and its CT is off the pump until the next
visit; the facts are declared per home because both scada control paths
and the optimizer's COP model branch on them.

## 2026-09-24 — snapshot carries ActuatorChannels (OPS-392, `8c01ce7` on jm/spruce)

Snapshot regenerated from sema `02490b9` (`jm/actuator-channels`): House0 axiom 30
and Nolan axiom 28, and the trimmed `SiegManifoldChannels`. No gen
changes; every generated pair already carried each actuator's channel.

## 2026-09-24 — snapshot follows sema `0cf5f28` (OPS-392, `01464b1` on jm/spruce)

Snapshot regenerated from sema `0cf5f28` (`jm/flow-hall-params-210`):
the registry `last_updated` stamp and `seed_expanded` generation time
only, since `flow.hall.params` is not in the layout closure. Why: the
scada closure copy is a byte-for-byte copy of this registry, and the
stamp records which sema the snapshot was built from.

## 2026-09-24 — spruce disables its dead thermistors; beech drops the prototype dist2 meter; FlowSpec gains enabled (`f99011d`)

Spruce disables `store-hot-pipe`, `store-cold-pipe` and
`fancoil-depth3-device`: the `store-btu` and `fancoil` picos are live
(2026-09-24 pico census through the starter-scripts API) and post nothing
for these; the store thermistors sit at the 3.3 V rail and at 0 V, fancoil
depth 3 at the rail. Beech loses the `dist2` flow pico (`pico_2a7e22`, the
Omega reed meter on a breadboard with no protection board): it was an
in-series meter on a prototype, it pulled the 5 V bus down on 2026-09-22
and was disconnected, and it never posted in the census. Its node, its two
channels and the `dist-flow2` renames go with it; `dist-btu` stays disabled
awaiting the Rev C board. Beech's ADS pipe channels and Hubitat zone
channels stay enabled: the journal shows the production scada reading every
one of them all day. `FlowSpec` gains `enabled` (default True), carried to the flow component's
`Enabled` the way `BtuSpec` already does, so a fitted-but-dead flow pico can
be taken out of service without leaving the layout; no gen sets it yet. Why:
a layout states what the house can serve today; a prototype meter that is
gone is removed, and a sensor that is fitted but dead is disabled so the
field visit has its list.

## 2026-09-23 — layout words at the axiom tables: snapshot, emitter types, disabled lists (`e37a2bc` on jm/spruce)

Snapshot regenerated from sema `9326dde` (`jm/layout-word-axioms`, off
`jm/spruce`). The gens follow the words: `ZoneCircuitSpec` /
`ZoneCallCircuitSpec` carry `emitter_type` (`Other` everywhere; spruce
1/2/4 `RadiantSlab` with their `floor_temp_channel_name`, 3 and 5
`FanCoil`); `LayoutGenConfig` carries `disabled_node_names` /
`disabled_channel_names` (beech: `dist-btu` and its three channels plus
`sieg-hot` on ADS terminal 9; oak: `store-cold-pipe` on terminal 6;
spruce: the three pump powers at eGauge 9012/9020/9022 out of the
transactive set, and `buffer-cold-pipe` derived from
`pipes1-depth3-device`, both disabled); the Nolan gen emits `backup` and
`scada-blind`; the House0 sims emit sim sensors for the whole pipe
surface and the sim meter carries the pump powers. Honeysuckle is noted
as the Stoneman microgrid scada, not a house layout. Elm, fir and oak
still fail `SiegManifoldChannels` until the no-sieg word takes them.
Why: the word now states what the code reads, so a layout that lacks a
required name is refused at gen time instead of failing in the field.

## 2026-09-23 — minor: spruce floor and fancoil derived channels return (`c434529` on actual-spruce)

`gen_spruce.py` (actual-spruce) emits the seven identity derived channels
again: fancoil-swt, fancoil-rwt, floor-swt, floor-rwt and the three
zone floor temps, each passing its `*-device` capture through unchanged.
They were commented out on 2026-08-10 when the pipes1 and floor1 picos
were unplugged; the 2026-09-09 commit that brought the picos back
(`9c75b40`) left the list commented, and `spruce.json` carried the seven
as stale content until `91cc434` (2026-09-21) regenerated it and they
vanished from the wire. The comment block naming the floor1 pico says
`pico_27432a`, the WiFi pico fitted on 2026-09-21. Ids come from the
loaded `spruce.json`, so the seven keep their ids.

## 2026-09-23 — patch egauge delta (GRI-6, `be8f37a` on main)

`gen_beech.py` (main) states `AsyncCaptureDelta=1` on dist-pump, primary-pump,
store-pump, oil-boiler and the two whitewire eGauge channels. The box has run
with 1 W since the layout was last placed; the scada `layout_gen` default is
2 W, so a regen silently moved them. Declared, the regen reproduces the
deployed file. Found while regenerating beech's production layout to drop
the dead dist-btu (GRI-6); that regen also exposed the flow-module
ComponentId re-mint fixed in scada `layout_gen/flow.py`.

## 2026-09-22 — beech tank1 is pico_81a436; dist-btu out of service (GRI-6, `f143d02` on jm/spruce, `f1fa3fd` on jm/beech-pico-uids)

On both gens: `beech_gen.py` (jm/spruce, the window gen) and
`gen_beech.py` (main, the production gen, on branch `jm/beech-pico-uids`).

tank1 is `pico_81a436`, not `pico_0efd3c`. The pico was swapped in the
field on 2026-02-14 and the box's production `hardware-layout.json` was
hand-edited that day; `3b7be19` (2026-02-17) carried the swap into
`gen_beech.py` on jm/spruce but never reached main, and the 2026-09-14
rewrite of the window gen (`7c2db53`) started from the old UID again. A
window scada booted from that pair would refuse tank1's posts.

dist-btu (Gw101 Rev B, `pico_47352a`) is dead: 5 V at J1, 0 V at the
protection chip's output after repeated input cycles. A Gw101 Rev C
replacement is on order. `beech_gen.py` keeps the meter with its pico UID
and sets `enabled=False`, so the layout keeps the dist-flow / dist-swt /
dist-rwt channels and the scada neither polls the pico nor cycles for it;
`BtuSpec` gains the `enabled` flag (default True) that `ExtraTankSpec`
already has, and `emit_btu_meters` writes it to the component. The
production gen `gen_beech.py` drops the dist-btu block outright.

## 2026-09-21 — Update the spruce floor1 pico (`e9818b0` on jm/spruce)

floor1's tank-module pico was an ethernet (Wiznet) board, `pico_71156b`,
whose MicroPython firmware was lost (a bench check in Thonny showed no OS) —
it flatlined in the field and sent nothing. It is replaced with a WiFi pico
that registered as `pico_27432a`. Both spruce gens set floor1 to the new UID
and re-enable it: `gen_spruce.py` (the actual-spruce production layout, shipped
in `cd92920`) and `spruce_gen.py` (the jm/spruce beta-field-window gen). The
"out of service / bricked" comment on the window gen is removed — floor1 is
back in service.

## 2026-09-20 — improved layout testing (OPS-392, `35000c4` on jm/spruce)

Sema `2f7c0d1` gives both layout words `DerivedChannelCreatorResolution`,
`DataChannelNodeResolution`, `DerivedChannelInputsAcyclic` and
`ChannelNameUniqueness`. The snapshot regenerates so every gen's
validation gate runs them. Every house's output already satisfied all
four, so no layout changes.

## 2026-09-20 — spruce floor1 is out of service (OPS-392, `7118622` on jm/spruce)

The spruce floor1 pico was bricked by a remote firmware download and sends
nothing, and the scada rebooted the whole pico bank every ~65 s on its
account. `ExtraTankSpec` takes a required `enabled`, emitted as the
component's `Enabled`; spruce declares floor1 `enabled=False`. The module's
nodes, its six channels and the three zone floor-temp identity deriveds stay
in the layout, so the channel set matches what the Nolan word's axioms will
ask for, and the scada neither watches the pico nor cycles for it. The note
in the gen says the pico needs resuscitating or removing.

## 2026-09-18 — snapshot takes the two circuit channel axioms (OPS-539, `fab0b52` on jm/spruce)

Sema `73d6eb6` gives both layout words `CircuitWhitewireChannelResolution`
and `CircuitHeatCallChannel`, the House0 word's per-zone
`ZoneHeatCallChannel` giving way to the per-circuit statement. The snapshot
regenerates so every gen's validation gate runs them, and the gens rerun
against it.

## 2026-09-18 — a Nolan layout derives one heat call per zone-call circuit (OPS-539, `89db516` on jm/spruce)

The heat-call derived channels were emitted per zone. Spruce's living
room is one zone served by two circuits, each with its own thermostat
and whitewire, so the fancoil circuit's call
(`zone5-living-rm-fancoil-heat-call`, which the pi derives today) had no
derived channel in the generated layout; only its raw opto input was
reported. The Nolan gen names its heat calls from the circuit list. The
other four spruce heat calls and every House0 heat call keep their names
and ids, since those circuits are one to a zone. No word changes:
`gw.house0.layout` states its heat-call axiom per zone and
`gw.nolan.layout` states none.

The same commit sets beech's ops params to Standby. The beech house runs in Standby, and its gen emitted `ActuationAuthority`
`Active` with `SeasonalStorageMode` `AllTanks`, so a scada booted on the
generated pair would have loaded the all-tanks TOU control and actuated.
The gen states what the house runs; the move to local control is a
deliberate ops change, made in the gen when that run happens.

## 2026-09-18 — a house declares its renames; a renamed object keeps the pi's id (OPS-539, `56448a9` on jm/spruce)

The names retirement renamed objects the pis still hold under their old
names, and the gen finds a pi id by name, so each renamed object was
minted a new id: the four spruce heating elements and their power
channels (`elt-buffer-top` to `buffer-top-elt`, `elt-store-top` to
`tank1-top-elt`; the store elements sit in tank 1), spruce
`vdc-relay-gpio-23` to `vdc-relay`, and beech's second dist meter
(`dist-flow2` to `dist2-flow`, with its `-hz`). A channel that changes id
splits its journal history. `LayoutGenConfig.renames` carries a house's
(new name, deployed name) pairs; with the fleet-wide `RENAMED` they now
apply to node ids and node-bound component ids as well as channel ids,
which also moved maple's `sieg-send-flow` component onto the pi's id.

## 2026-09-18 — deployed gens take ids from the pi, then their own previous output (OPS-539, `3cb3f5a` on jm/spruce)

A deployed house's layout carries names the pi's running layout lacks
(spruce's unlimbo nodes, channels and components; the House0 names the
retirement changed), and a name absent from the single reference was
minted with a fresh uuid on every run. A box file checked byte-identical
to the gen output then stopped matching at the next regen. `LayoutGen`
takes a second map, the gen's own previous output, consulted after the
reference and its rename index and before minting; a previous-output id
the reference already assigns to another name is skipped. The spruce,
beech and maple gens fetch the pi's layout over rclone (agent key use
off per call, so the fetch does not depend on the ssh-agent holding the
fleet key) and fall back to the last fetched copy. The test runs a gen
twice against a reference that lacks names and requires identical ids.

## 2026-09-18 — snapshot takes SimDac; SimDeviceType lists every sim value (OPS-539, `0c3a7cd` on jm/spruce)

The snapshot regenerated from sema with `gw1.sim.device.type` carrying
`SimDac`. The generators' own `SimDeviceType` value list
(`device_types/__init__.py`) lacked `SimRelayBank` and gains it with
`SimDac`, so it names every value of the enum.

## 2026-09-18 — snapshot takes the pico BTU component axioms (OPS-539, `146ef3f` on jm/spruce)

The snapshot regenerated from sema with `pico.btu.meter.component.gt` and
`sim.pico.btu.meter.component.gt` carrying `ReadCtVoltageIffCtVoltsDelta`
and `ReadCtVoltageIffCtChannelName`, so every BTU component a gen emits is
checked against them at the driver's decode.

## 2026-09-18 — temperature DataChannels in CelsiusTimes100; Nolan zones carry a derived setpoint (OPS-539, `26badee6` on jm/spruce)

Sema requires `TempChannelName` on every HVAC zone and resolves it in both
layout words (`ZoneTempChannelResolution`), and a temperature DataChannel is
what a sensor measured, encoded `CelsiusTimes100`. Every gen — sim and house
alike — carries the same encoding now; the ADS board's per-channel telemetry
override is gone (`AdsChannelSpec.telemetry` deleted), so there is no lever
left to leave one channel on the old encoding.

- The snapshot regenerated at sema `8bc9fc4`: `gw1.hvac.zone` with
  `TempChannelName` required, `ZoneTempChannelResolution` as
  `gw.house0.layout` axiom 18 and `gw.nolan.layout` axiom 13, `gw.hydronic`
  without its axiom 3.
- Capture deltas scale with the encoding: tank device temperatures 2000 to
  200 (`tank_module.py`, the extra tank modules included), ADS channels 500
  to 50 (`hardware/thermistor.py`), sieg-cold 2000 to 200
  (`house0_sema_gen.py`). The ADS device-type record's `TelemetryNameList`
  is `CelsiusTimes100` alone, which the scada's tsnap driver checks its
  channels against.
- `hydronic_zones()` returns a `ZoneCore` record (`layout_gen.py`) and each
  family gen builds its own `HvacZone` from it, so each names its zone's
  temperature channel. A Nolan zone with no thermistor raises.
- `nolan_sema_gen.py` `emit_zone_setpoints` writes one DerivedChannel per
  zone (`zone{i}-{label}-set`, strategy `simple-falling-edge-setpoint` over
  the zone's gw-temp and heat-call, `FahrenheitX100`). Spruce has no
  thermostat the scada can read, so the setpoint the cold-house judgment
  compares against is inferred from where the temperature stands when a
  heat call ends.

## 2026-09-18 — Simulated BTU meters emit the sim pico BTU word (OPS-539, `6b3d8c5` on jm/spruce)

A simulated home's BTU meters were the generic sim sensor, so no sim pair
booted the scada's `ApiBtuMeter`. The emitter now gives a simulated home
`sim.pico.btu.meter.component.gt` under an `ApiBtuMeter` node, with the
home's `SimLifeS` / `SimRebootS` and a `sim-<node>-pico` HwUid, the way the
tank emitter does; the component fields are shared between the two words.

## 2026-09-17 — Snapshot regen: one ops word with a family block and a tariff; pico boards authored; oak, fir and elm as House0 fixtures (OPS-539, `472fee6` on jm/spruce)

- Snapshot regenerated from sema `7928618`: `gw.operational.params` with
  `FamilyParams` replaces the two family ops words (the seed now targets
  it; the orphaned `dfr.component.gt` leaves the seed, no gen builds it);
  `gw.tou.tariff`, `iana.timezone.str`, `gw.primary.flow.source`,
  `pico.board.variant`, the two sim pico words, and the three pico
  component words with `PicoBoardVariant` + `MicropythonVersion`.
- `OpsSpec` carries `keep_buffer_full` and a `TariffSpec` (alias, display
  name, tz zone, on-peak windows); `build_ops_kwargs` emits the shared
  block and each family gen adds its `FamilyParams`
  (`UseSiegLoop`/`KeepBufferFull`/`SeasonalStorageMode` for House0,
  the latter two for Nolan). Every gen names the Versant TOU rate from
  the tariff word's example; the alias is a guess to confirm.
- `TankSpec`, `ExtraTankSpec`, `BtuSpec`, `FlowSpec` take a required
  keyword `board` (`PicoBoardVariant`), authored per pico like the
  HwUid. First pass: beech and maple tank modules are Wiznet Pico 2
  boards on the `gridworks-pico/firmware` build, their other picos Pico
  W; spruce is all Pico W until the window says which tank module is the
  Wiznet; oak, fir, elm and the bench sims are `Unknown`.
  `MicropythonVersion` is left absent everywhere: not yet known.
- `ZoneCallCircuits` is required on `gw.hydronic`, so the base gen
  returns the zones (`hydronic_zones`) and each family builds `Hydronic`
  with its circuits; a gen with none declared raises.
- Oak, fir and elm are sema-authored as House0 fixtures on purpose
  (no sieg loop in the houses; the word requires the sieg surface, so
  each carries a pretend sieg flow pico `pico_000000` and a `sieg-cold`
  ADS channel, marked PRETEND). They run with no reference layout
  (`reference=None` mints ids; g-nodes authored in the gen) and beech's
  LG pair standing in for unrecorded heat-pump make/model. The commented
  `old_gen_{oak,fir,elm}.py` specs and the `house0_no_sieg_sema_gen.py`
  stub are deleted: translated, nothing imports them.
- A House0 sim zone's sim sensor emits the zone's `-set` channel beside
  `-temp` (`AirTempFTimes1000`), so the hydronic actors' setpoint memory
  has a channel behind it on the orange and willow pairs. The Nolan sim
  pair emits none: what the Nolan cold-house rule reads is undecided.

## 2026-09-17 — Tank name helpers by index; House0ChannelNames is constants only (`99b6f4d` on jm/spruce)

The scada retired `helpers.Tanks` and the `House0ChannelNames` instance
part (a layout now answers its own tanks). The tank-module and
calibration emitters build `TankNodeNames(i)` / `TankChannelNames(i)`
for `1 .. total_store_tanks` directly, and the base gen's `cn` is the
class. Both sim pairs regenerate byte-identical.

## 2026-09-15 — House0ChannelNames takes the tank count only (`584121b` on jm/spruce)

The gwsproto `House0ChannelNames` lost its `zones` instance part with
the scada's zone-roster retirement; the base gen's `cn` property passes
the tank count alone. No output changes.

## 2026-09-15 — House0 zone failsafe relays emit ZoneCallSource; hubitat node from the hydronic tier (`634c159` on jm/spruce)

The House0 gen realized each zone's failsafe relay with the
`heatcall.source` pair while the Nolan gen used `zone.call.source`; one
relay kind now serves both families and the heat-call kind is deleted.
The hubitat emitter read `hubitat` off the family names class, which
broke `beech_gen` and `maple_gen` once the scada moved that name to the
hydronic tier (`65262e85`); it reads the hydronic tier now. All four
House0 layouts regenerate; the sim pair is copied into the scada
fixtures, the beech and maple outputs are box artifacts. The import
alias for `HydronicSpaceheatNodeNames` / `HydronicSpaceheatChannelNames`
is `HSNN` / `HCN` throughout, matching the scada repo (`Hyd` / `HydC`
retired); no output changes.

## 2026-09-15 — sim gens emit sim extra tank modules; secondary pump through its names (`6126a44` on jm/spruce)

`emit_extra_tank_modules` ignored `tank_kind` and emitted real
`pico.tank.module` components for fancoil, floor1 and pipes1 even in the
spruce sim gen, so the scada's sim pico tests could not take the fresh
fixture. It now branches like the buffer and tank emitter: sim config,
`sim.pico.tank.module` with a `sim-<name>-pico` uid. The real spruce
output is unchanged. `spruce_gen.py` names the secondary pump's power
channel through `HydronicSpaceheatChannelNames.secondary_pump_pwr` and
its node through `HydronicSpaceheatNodeNames.secondary_pump`, both new in
gwsproto, instead
of bare strings.

## 2026-09-15 — gens declare every actuator flat under auto (`c1772e6` on jm/spruce)

The scada rewrites the command tree at boot (`set_command_tree(n)` in
`Scada.__init__`) and reparents every actuator under the live boss, so a
layout's declared actuator handle is a placeholder. The House0 gen declared
relays under `auto.lc.n` and 0-10V outputs under `auto`; the Nolan gen
declared both under `auto.lc.n`. Both now declare every relay and output
flat under `auto` (`i2c_relay.declared_handle`), the shape the deployed
beech and fir layouts already had for their outputs; vdc-relay keeps its
place in the five-v-boss subtree. Every output regenerated, handle lines
only; the spruce and honeysuckle box copies need republishing to stay
byte-identical to the gen.

## 2026-09-15 — beech, maple, oak gens: ShortCycleBuffer true (`684d956` on jm/spruce)

The three House0 field houses run the leaf ally with `ShortCycleBuffer`
true, as the control design intends: the buffer cycles on its bottom
sensor and the LTN counts none of it as storage, so the FLO plans on the
store alone. The sim pairs and the Nolan houses stay false. Oak's gen
still raises at the `gw.house0.no.sieg` stub, so its stale output keeps
false until that word exists; beech and maple regenerated (ops params
only, one field). The box copies need republishing.

## 2026-09-15 — willow: the second simulated House0 pair, derived primary-flow (`26401c5` on jm/spruce)

The scada suite gets a House0 fixture per sieg-flow pattern. `orange_sim_gen.py`
(was `house0_sim_gen.py`; the little orange house) measures `primary-flow` and
derives `sieg-send-flow` by difference, beech's pattern. New `willow_sim_gen.py`
is the same all-simulated skeleton with `DerivedSiegSum`: a sim flow sensor on
the sieg send line, `primary-flow` derived as the sum, maple's pattern. Willow
is a second little house with its own GNode identity, and its ids are minted
from an empty reference on the first run so none collide with orange's; each
driver's stable-id reference is its scada fixture copy, since `output/` is not
committed. `emit_sim_plant_sensors` places the sim sensor on the identity's
measured addend (primary when Measured, sieg-send when DerivedSiegSum). Fixed
on the way: `emit_sim_power_meter` minted its component id twice, which held
only while a reference layout already carried the id and failed
ComponentBinding on a first run. Rung 4 of correct-house0 (OPS-539).

## 2026-09-15 — sieg-send-flow and the derived sieg flows; maple gen (`155d4e0` on jm/spruce)

The sieg send line's flow meter takes the `<position>-flow` grammar every
other flow meter follows: position `sieg-send` → `sieg-send-flow` /
`sieg-send-flow-hz`, replacing the deployed bare `sieg-send`; a `RENAMED`
table (new → old) lets a regenerated layout inherit the deployed UUIDs, the
way the relay-idx rename does. `FlowSpec.position` opens from a closed
`Literal` to a `SpaceheatName` — a position is any name the grammar
composes, not a closed set — and `primary_flow_source` is typed as the sema
enum `House0PrimaryFlowSource` instead of a bare string.

`emit_primary_flow` now carries the sieg-loop flow identity
`primary-flow = sieg-send-flow + sieg-flow`: a house that measures
primary-flow and has a sieg-flow channel derives `sieg-send-flow` by
`difference` (beech); a house on `DerivedSiegSum` derives `primary-flow` by
`sum` (maple). The difference branch keys on the sieg-flow channel's
presence, so non-sieg families regenerate unchanged.

`maple_gen.py` authors the real Keene Maple `gw.house0.layout` (Mitsubishi
Ecodan WUZ-SA48NMZ + ERSF-NM6E hydrobox, sieg-btu and store-btu, dist and
sieg-send Hall picos, an outdoor air temp on the ADS) as a deployment
artifact, mined from `old_gen_maple.py`; `sema validate` green, id-preserving
against the deployed layout. The vendored snapshot regenerates on sema
`8e56c4e` (House0 axiom 8 no longer requires `sieg-flow-hz`, which maple's
BTU-sourced sieg-flow cannot produce). Rung 4 of correct-house0 (OPS-392).

## 2026-09-14 — beech real deployment layout from the sema House0 gen (`7c2db53` on jm/spruce)

`beech_gen.py` authors the real Keene Beech `gw.house0.layout` — a sieg-loop
House0 home with two Honeywell-via-Hubitat zones, an LG Multi V split heat pump,
an eGauge, four pico tank modules, two BTU picos, three standalone flow picos, and
an ADS analog-temp board — as a deployment artifact (`output/beech/`), id-preserving
against the deployed layout and `sema validate` green. It replaces the hand-kept
beech real shape that `gw.house0.layout.json` used to carry.

Getting there needed the House0 real path built out on the shared gen, all with
spruce + sim output byte-identical:
- `btus` moves to `LayoutGenConfig` and `emit_btu_meters` runs in the House0 build
  before `emit_flow`, so a BTU pico's flow channel satisfies the bare-flow emit.
- `DeviceType` is now the gwsproto enum (the local name), replacing tlayouts' partial
  hand-kept mirror — the words still type the field as a string; the enum supplies it.
- `FlowSpec` gains a Hall/Reed `kind` axis (Saier default; Ekm/Omega reed) and the
  `dist2` position, fixing the Reed-hardcode; names route through FlowNodeNames/
  FlowChannelNames.
- `AdsChannelSpec` gains a thermistor make/model axis (Tewa default, Amphenol for the
  zone air-temps); a House0 zone's temperature reads the ADS `gw-temp` where one exists
  and falls back to the Honeywell temp otherwise.
- `TankSpec` gains asymmetric depth-1/depth-3 calibration and a sensor order, matching
  beech's tank3 (B −108/−481) and tank2/tank3 reverse order.

## 2026-09-14 — Family-neutral base generator and the hardware modules (`5347f3c` on jm/spruce)

`NolanSemaGen` subclassed `House0SemaGen`, so a Nolan driver imported
its DAC spec and board emitter from a module named for another family,
and every hardware realization (relays, DAC outputs, the meter, tank
modules, thermistor readers) lived in whichever family wrote it first.
Now `layout_gen.py` holds what every family shares (`LayoutGen`,
`LayoutGenConfig`: the id map, the accumulators, the stable-id helpers,
the ops kwargs, and the emitters no layout word varies: GNodes, web
server, heat-pump parts, pico flow meters, primary flow, derived
channels, the hydronic core), and `hardware/` holds one module per
kind with its spec beside its realizer (`board`, `i2c_relay`,
`dac_output`, `thermistor`, `tank_module`, `power_meter`, `gpio_relay`,
`gpio_sensor`, `btu_meter`, `hubitat_zone`), each a function that
appends to a gen. House0 and Nolan are siblings on
`LayoutGen` and own only their plant roster. The two families' i2c
relay and DAC emitters collapse into one each, the family fact (the
node's handle, the channel caption) a parameter; the relay wiring and
event/state bundles are typed `RelayKind` constants. `DeviceType` and
`SimDeviceType` move to `tlayouts.device_types`, the vocabulary home.
Nolan's redundant `__init__`, `emit_gnodes`, `emit_heat_pump_parts` and
duplicated config fields go. Drivers repoint their imports. A move, not
a redesign: spruce, spruce-sim, spruce-async1, honeysuckle (both
variants) and house0-sim regenerate byte-identical. Rung 3 of
correct-house0 (OPS-539).

## 2026-09-14 — beech's house0 layout generates automatically (`400e858` on jm/spruce)

`House0SemaGenConfig` now carries the board (equipment node name,
device-type record file, its simulated twin, bus addresses, display)
and the 0-10V outputs as `DacOutputSpec`s against that board, with
gw108 rev B as the default; `emit_board` and `DacOutputSpec` move from
the Nolan gen to the base, and the Nolan subclass loses its copies
(spruce, spruce-sim, spruce-async1 and honeysuckle regenerate
byte-identical). The two existing House0 homes declare their krida
panel and DFRobot outputs in their drivers (the sim, oak). Why gw108
is the default: it is what every install from here on uses, no new
krida or DFRobot panel will be built, and beech's panel may itself be
replaced by a gw108. "Which board" is now a one-axis swap, the
hardware-decoupling shape. The sim House0 pair's three 0-10V captions
take the Nolan form (`Dist Pump 010V`, channel `… Level`) in place of
the hardware-named `Dist DFR`; ids unchanged. Rung 2 of correct-house0
(OPS-539).
The board axis is the change the title names: House0's real layout can
now be generated on its own board declaration. Also: the six commented-out legacy generators renamed `old_gen_<house>.py`,
contents untouched; the live drivers renamed to `<house>_gen.py` (`spruce_gen`,
`spruce_sim_gen`, `honeysuckle_gen`, `house0_sim_gen`, `oak_gen`; sema is
implied for every live generator), with the drivers' and the component-id
test's imports following the rename.

## 2026-09-14 — House0 gen: relays and 0-10V outputs on the board record; the DFR multiplexer gone (`06368c7` on jm/spruce)

`house0_sema_gen.py` had fallen two retirements behind the scada
fixtures it is meant to emit: it still read the deleted
`relay_multiplexer` name (the sim gen would not run) and emitted the
orphaned `dfr.component.gt` / `dfr.config` pair with the
`zero-ten-multiplexer` node. `emit_relays` now emits the shape krida
rung 3 hand-patched in: the board record and its
`scada.board.component.gt` anchor bound to the `krida` node, the
`i2c-bus` actor node, and one `i2c.relay.component.gt` per relay
against the record's RelayName, each relay-state channel captured by
its own node. `emit_dfr` becomes `emit_dac_outputs`: one
`i2c.dac.output.component.gt` per output (Dfr1 A/B, Dfr2 A) with a
wiring-only `dac.output.config`, the power-on level in
`ZeroTenPowerOnList` (config field renamed
`zero_ten_power_on_volts_times_ten`, the old name was volts times a
hundred in name only). The simulated board record
`SimKridaDoubleRelayBoard16` is vendored as a device-type file
(`sim.krida-…`) beside the real one, since its DACs are `Mcp4728`
twins rather than an identity swap. The sim gen's output is now
semantically identical to the scada sim fixture pair with every id
preserved; the fixtures are replaced by the gen's output in the same
wave (scada). Rung 1 of correct-house0 (OPS-539).

## 2026-09-13 — Snapshot regen: House0 layout axiom 10 clause c and axiom 15 ComponentBinding (`44050b1` on jm/spruce)

The vendored snapshot follows the sema commit that adds the 0-10V
component binding clause and `ComponentBinding` to `gw.house0.layout`;
no generator change, the sim House0 gen already emits per-output
components and the web-server node.

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

## 2026-09-18 — drop hubitat zone state (OPS-539, `905eb5e` on jm/spruce)

The Hubitat `thermostatOperatingState` reading has unstable values, no names
class carries it, and nothing reads it for heat call or control; a zone's
heat call is its derived `heat-call` channel. `hardware/hubitat_zone.py`
emits temp and setpoint only, so beech, maple, oak, fir and elm lose one
`zone{i}-{label}-state` channel, poller attribute and capture tuning per
zone. A deployed house takes the regenerated layout only after the web
frontend's thermostat table stops reading `-state`.

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
