# Layout-word axioms (spoke)

Status: Accepted · Pass 1 · Updated 2026-09-24 · Linear: OPS-392

> What this is: the axiom work still open on `gw.house0.layout/000` and
> `gw.nolan.layout/000` before they are promoted. The required channel
> and node tables, the circuit's emitter type, the store-tank depths,
> the `web-server` node, the disabled lists and the actuator channels
> are in both words, with runtime and gwsproto tests, and every current
> gen generates against them, and `gw.hydronic` states who owns the
> primary pump and the refrigerant cycle. Open: a maple-shaped sim
> pair, the declared command tree, the bus list, the sim
> and nameplate vocabulary gaps, disabled-config behaviour, and one
> renumbering. Both words are staging, so every edit is in place.

## Do this next

The tables are in: sema `2aabe87`, `555e3ca`, `9326dde` (snapshot and
closure copy now at `0cf5f28`; both words at
axioms House0 24–29, Nolan 20–27, `gw1.zone.call.circuit` with
`EmitterType` and `FloorTempChannelName`, `gw.zone.emitter.type`);
tlayouts `e37a2bc` / `f99011d` (snapshot, every gen at the tables,
disabled lists); scada `847d9ca` (closure copy, gwsproto mirrors with a
rejecting test each, sieg and core names). Beta round four (2026-09-23,
`experiments/beta-field-windows/`) booted spruce and beech on the
axiom-table pairs. Not at the tables by design: elm, fir and oak fail
`SiegManifoldChannels` (`sieg-hot`) and wait for `house0-no-sieg-layout.md`;
honeysuckle is the Stoneman microgrid scada, not a house.

1. ✅ `ActuatorChannels` (House0 30, Nolan 28): every `RequiredActuators`
   node has a DataChannel of its own Name, about and captured by it,
   `RelayState` / `VoltsTimesTen` by actor class; `SiegManifoldChannels`
   sheds its two relays. Surfaced one gap for `odds-and-ends.md`: the
   0-10V channel is the commanded voltage, not a readback.
2. ✅ `PrimaryPumpOwner`, `RefrigerantCycle` and the
   `PrimaryPumpRecordAgreement` axiom on `gw.hydronic`: sema `e54adcd`,
   the tlayouts snapshot and every gen, the scada mirrors
   (`executor/hardware-layout.md` "What a layout is"). Left: a
   maple-shaped sim pair in the scada suite (`HeatPump` owner, no
   primary-pump actuators; the willow pair is maple's flow pattern but
   backs the 0-10V tests over all three outputs, so it stays). Maple's
   first window is `beta-field-windows.md`.
3. ✅ `ApiBtuMeter` reports an implausible temperature
   (`open-thermistor`) and a channel that stops arriving while the pico
   posts its siblings (`quiet-channel`), one Warning a day per channel
   (`tests/actors/test_btu_open_thermistor.py`). Spruce's `store-btu`
   pipe thermistors are the case: the pico drops a rail reading before
   the post, so the scada saw an absent channel and never named it. The
   layout's disabled lists do not reach the actors yet, so a disabled
   channel is named the same way; that is the "Required but disabled"
   design question. The tank module keeps its own once-a-day dict for
   the same gate (`open_thermistor_reported_s`); moving it onto
   `GlitchLimit` is a separate small change.
4. **Next: the sema wave in "Required but disabled" step 2**, on
   `jm/disabled-lists-wave` in sema and tlayouts: the six pico words,
   the web-server rename, the two restated axioms, then the snapshot,
   the gens, the closure copy and the gwsproto twins and mirrors with
   reject tests. The sitting that takes it reads `registry/structure.md`
   "Status Field" and `authoring/type-semantics.md` "Axioms" and posts
   the read-receipt.
5. Then `HeatCallChannelBelongsToCircuit` (add it: the gen derives heat
   calls per zone-call circuit only, and the derived generator's
   falling-edge setpoint checks only the Strategy), the runtime-test port
   in "Owned elsewhere" and, last of all, "Axiom order".

## How the sitting works

- New axioms are appended, so the gwsproto `check_axiom_<n>` mirrors and
  the tests hold still until the one renumbering in "Axiom order".
- The cross-layout mirror key is the axiom NAME; numbers differ per word.
- Axiom tests mutate the one vanilla fixture in the test (`mutated` /
  `reject` in `test_gw_nolan_layout.py` and `test_gw_house0_layout.py`,
  in both `sema/tests/runtime/` and scada `tests/named_types/`); no JSON
  file per axiom.
- Each word edit travels as one wave: sema word and runtime tests, the
  tlayouts snapshot and regenerated pairs, the vendored closure copy in
  scada, the gwsproto mirror and its test.

## Required but disabled

A house carries a required node or channel it cannot serve as present
and disabled, in preference to a sim stand-in. Disabled means required
by the word, declared in the layout, currently unavailable, and pending
a field visit. Both words carry `DisabledNodeNames` (whole sensing
actors) and `DisabledChannelNames` (single channels) with three axioms
(`DisabledNamesResolve`, `DisabledNodesAreSensors`,
`EnabledDerivedChannelsHaveLiveInputs`), so a consumer reads the channel
list alone and a gen keeps a disabled power channel out of the
transactive-power input set. The gens emit them: beech (`dist-btu`;
`dist-flow`, `dist-swt`, `dist-rwt`, `sieg-hot`), oak
(`store-cold-pipe`), spruce (the three pump powers with no CTs, the
store pipes, `buffer-cold-pipe` and its `pipes1-depth3-device` input,
`fancoil-depth3-device`). Maple's gen disables nothing yet; its
`primary-pump-pwr` has no CT either. Sims disable nothing; tests of
disabled behaviour make their own layouts. The why and the plan behind
each name are the service-record word, OPS-558.

The scada does not read the lists yet. Round four showed the shape of
the gap: the store pipe channels at both houses and beech's buffer pipe
and well never read a value, the BTU actor named a declared-disabled
channel with a quiet-channel Warning, and the UnknownChannels logger
listed beech's declared-disabled channels. The pico components carry an
older per-component `Enabled` boolean that the BTU, tank and flow actors
and the pico cycler read; it is the same idea one level down and it goes.

Decided 2026-09-24, in this order:

1. **Scada first, against the lists already in every gen.** `HydronicLayout`
   keeps the whole word (`data_classes/hydronic_layout.py:623`), so the
   two lists are already at hand; no loader change. The actors stop
   reading `component.gt.Enabled`.
   - **Built but idle.** gwproactor builds every child node with an actor
     unconditionally (`gwproactor/app.py:259-285`); the component flag
     never stopped that, whatever the tlayouts comment says. A disabled
     node's actor is constructed, keeps its web routes and its place in
     the pico cycler's roster, and neither reads, reports nor alerts.
   - **A disabled channel is filtered at its actor's channel-discovery
     step**, before the liveness and warning dicts are built: the tank's
     name list (`api_tank_module.py:130-141`), the BTU's component fields
     (`api_btu_meter.py:118-135`), `ConfigList` for the thermistor reader
     (`i2c_thermistor_reader.py:112-179`, pairing must tolerate one
     disabled half), the power meter (`power_meter.py:153-179`) and the
     multipurpose sensor (`multipurpose_sensor.py:117-122`),
     `CapturedByNodeName` for gpio (`gpio_sensor.py:46-50`) and sim
     (`sim_sensor.py:57-61`), the attribute list for the Hubitat poller
     (`hubitat_poller.py:212-233`). Filtering there closes every leak at
     the source: no read, no `ChannelFlatlined` (never sent for a
     disabled channel), no quiet-channel or open-thermistor Warning, no
     i2c broken-input latch. Two leaks the flag never closed close too: a
     disabled sim pico still posts readings to itself
     (`api_tank_module.py:338-356`, `api_btu_meter.py:361-379`) and a
     disabled slow-turner flow module publishes a made-up zero flow every
     capture period (`api_flow_module.py:226-228, 494-523`).
   - **A disabled DerivedChannel** is skipped by the derived generator at
     `init_derived_channels` (`derived_generator.py:108-124, 204-208`),
     and `feeds_derived` (`hydronic_layout.py:1005-1010`) ignores it so
     device actors stop posting its inputs.
   - **Reporting.** `unreported_channels` (`hydronic_layout.py:1283`,
     returns `set()` today; `ScadaData.my_reported_channels` already
     filters on it) returns the disabled set, and the UnknownChannels
     line (`scada_data.py:231-240`) leaves disabled channels out. The
     rest of the scada reads a disabled channel as None and stays quiet
     (`hydronic/house0.py:804-836`, `store_temps.py:17-40`).
   - **Downstream visibility** is the once-daily Warning glitch in
     `odds-and-ends.md` "Once-daily glitch naming a disabled component's
     silent channels", extended from disabled components to the two
     lists.
   - ✅ In the scada tree (2026-09-24, suite green, 1149 passed):
     `HydronicLayout.disabled_node_names` / `disabled_channel_names`
     with `node_disabled`, `channel_disabled`, `enabled_channel_names`;
     every sensing actor filters at discovery; the scada sends a
     `disabled-roster` Warning at start and daily; `test_pico_disabled.py`
     runs on the lists (`floor1` as a node, plus the layout's own
     disabled channels) and pins the sim-pico read, the BTU pipes, the
     power meter, the derived generator, UnknownChannels, the roster and
     the half-disabled thermistor pair. Not pinned: the flow module's
     zero-flow leak, because no test layout under `tests/config` carries
     an ApiFlowModule; adding one is a tlayouts sim-gen change (orange or
     willow) and rides the next snapshot regen.
   - Open, found by the review: `LayoutLite` carries no disabled lists
     (`named_types/layout_lite.py:39-40`), so the LTN cannot tell
     disabled from missing.
2. **Then the next sema wave**, all in place on staging words unless
   noted.
   - `Enabled` comes off the six pico component words
     (`pico.btu.meter.component.gt/000`, `pico.flow.module.component.gt/001`,
     `pico.tank.module.component.gt/012` and their three `sim.pico.*`
     twins), with the tlayouts gens (`FlowSpec.enabled`,
     `ExtraTankSpec.enabled`, `btu_meter.py:47`; `spruce_sim_gen.py:69`
     becomes dead) and snapshot, the closure copy and the gwsproto twins.
   - `hubitat.poller.gt` `Enabled` and `maker.api.attribute.gt` `Enabled`
     are the same two ideas under other names (a node disable and a
     channel disable), so they go too; both words are published, so each
     takes a new version, after the six. `WebPollEnabled` and
     `WebListenEnabled` stay: they name the transport path.
   - `web.server.component.gt/001` `Enabled` is a different thing
     (whether the scada runs its HTTP server) and is renamed, `Serve`,
     so `Enabled` appears nowhere in the vocabulary.
   - `DisabledNodesAreSensors` is restated on both words so that it
     excludes actuators: `ActuatorChannels` gives every relay and 0-10V
     output a DataChannel captured by itself, so today an actuator passes
     the axiom as written (`house0_layout.py:866-872`). Disabling is a
     sensing concept; an actuator is wired or absent. Statement (agreed
     2026-09-24): no name in `DisabledNodeNames` SHALL be the Name of an
     ShNode whose ActorClass is `Relay` or `ZeroTenOutputer`, and no name
     in `DisabledChannelNames` SHALL be the Name of a DataChannel whose
     CapturedByNodeName is such an ShNode. Those two are the actuator
     classes any generated layout carries, the same two `ActuatorChannels`
     names. `I2cRelayMultiplexer` and `I2cZeroTenMultiplexer` survive
     only in the `gw1.actor.class` enum (`014`, staging, so an in-place
     removal), gwsproto's hand-written `enums/actor_class.py` and the
     tlayouts snapshot copy: remove them from all three in this wave.
   - `TransactivePowerChannel` (House0 6) gains a clause: no name in the
     transactive-power channel's InputChannelNames SHALL be in
     `DisabledChannelNames`. The metered boundary is the resistive
     elements, `hp-odu` and `hp-idu` / `hp-ctrl-box`; pump power is never
     in it. The word cannot say "pump" (no node role), so that part is
     gen discipline: spruce's gen lists `secondary-pump-pwr` in the set
     today (`spruce_gen.py:281`) and drops it in this wave; beech, maple
     and oak already meter `hp-odu-pwr` and `hp-idu-pwr` only.

Done when: the suite boots a sim layout with a disabled required channel
and a disabled node and shows nothing reported for either, no actor
reads `component.gt.Enabled`, and oak or beech boots its pair in a
window.

## Candidate: `HeatCallChannelBelongsToCircuit`

Both words. The converse of `CircuitHeatCallChannel` (House0 axiom 4,
Nolan axiom 15): every channel in DerivedChannels with Strategy
"heat-call" SHALL have InputChannelNames equal to [the
WhitewireChannelName of exactly one circuit in
Hydronic.ZoneCallCircuits]. `CircuitHeatCallChannel` keeps a circuit from
lacking its heat call; a heat-call channel whose input is no circuit's
whitewire still decodes. With both directions the heat-call channels and
the circuits are one to one. To settle: whether a layout may derive a
heat call for something that is not a zone-call circuit.

Done when: the question is settled here and, if the axiom goes in, all
six house pairs and the sim pairs decode under it.

## Declared actuator shape and the command tree

Settled 2026-09-24: the fixed relays are declared under the node that
owns them, and axioms pin the fixed sub-tree. Today the layout declares
every relay flat under `auto` except the vdc relay, and the scada's boot
rewrite owns the live tree (`executor/control-hierarchy.md` "Fixed
sub-trees vs floating actuators"). The executor names three relays as
fixed, owned by an interior node whoever holds the tree: the vdc relay
under the pico-cycler, `hp-scada-ops-relay` under hp-boss, and the two
loop relays under sieg-loop. Only the first is declared that way; the
other three read `auto.<relay>` in every generated layout while their
live handles are `<boss>.hp-boss.hp-scada-ops-relay` and
`<boss>.sieg-loop.<relay>`. The authored handles are the initial command
tree, so the tree the LTN and the panel see before the scada's first
rewrite disagrees with the one they see after it.

The axioms, in both words unless noted:

- `CommandNodeHandles`: the command-node axiom (House0 3, Nolan 4) pins
  every handle in its list as it does for `n`:

  | Node | Declared handle | Words |
  | --- | --- | --- |
  | `five-v-boss` | `auto.five-v-boss` | both |
  | `pico-cycler` | `auto.five-v-boss.pico-cycler` | both |
  | `lc` | `auto.lc` | both |
  | `hp-boss` | `auto.lc.n.hp-boss` | both |
  | `backup` | `auto.lc.backup` | both |
  | `scada-blind` | `auto.lc.scada-blind` | both |
  | `sieg-loop` | `auto.lc.n.sieg-loop` | House0 (sieg word) |

- `FixedRelayHandles`: the vdc relay's handle is
  `auto.five-v-boss.pico-cycler.vdc-relay`; `hp-scada-ops-relay` is
  `auto.lc.n.hp-boss.hp-scada-ops-relay`; in the sieg word the two loop
  relays are `auto.lc.n.sieg-loop.hp-loop-on-off-relay` and
  `auto.lc.n.sieg-loop.hp-loop-keep-send-relay`. Every other actuator
  stays flat under `auto`, which is what floating means.

Build order: the tlayouts gens (`house0_sema_gen.py`, `nolan_sema_gen.py`)
declare the three relays nested and every pair regenerates; the two
axioms go into both words with reject tests; the scada mirrors follow
with the closure copy. The scada's two tree builders already produce
this shape, so no scada control code changes.

Done when: both axioms are in, reject tests exist, every generated pair
decodes, and a window on spruce and on beech boots the pair with the
live tree unchanged from before the edit.

## Sim 0-10V output has no sim vocabulary

The orange, willow and spruce sim layouts realize their 0-10V outputs
with `i2c.dac.output.component.gt` and no DeviceType, so a simulated
output is indistinguishable from a real one under the rule that scada
tells sim from real by `gw1.sim.device.type` membership
(`executor/components.md` "DeviceType — and the retirement of
MakeModel"). No `sim.dac.output.component.gt` exists; the earlier
`sim.dac.writer.component.gt/000` (staging) is marked `replaced_by:
i2c.dac.output.component.gt` in the registry and is in no snapshot. To
settle: a sim component word, or a sim DeviceType on the real word.

Done when: the sim pairs regenerate with the chosen form and the suite
boots them with the sim output actor selected by membership.

## Heat-pump nameplate records for beech and maple

`tlayouts/src/tlayouts/device_types/` holds `hp.device.type.gt` records
for the Samsung at spruce only (`samsung.ae055.odu`, and its control
box as `hp.control.box.device.type.gt`). Beech (LG) and maple
(Mitsubishi) need theirs, authored from the Drive nameplate photos, so
that House0 `RequiredHeatpumpEquipment` components resolve to a real
record. Maple's Ecodan hydrobox has no compressor, so it gets no
`hp.device.type.gt`; the outdoor unit's record carries the package's
primary-pump facts.

Done when: both records validate under `sema validate` and the beech and
maple gens reference them.

## BoardBusList / layout-wide BusList

The bus list lives on `gw1.scada.device.type.gt` as `BusList`
(`000.yaml:28`), a board-scoped fact with a layout-scoped job; its
`BusMembership` axiom ties expanders, muxes, adcs and dacs to it and says
nothing about bus actors. Direction: rename the device-type field
`BoardBusList`, add a `BusList` to the layout words, and an axiom that
the layout's BusList lines up with the union of its board device-types'
BoardBusLists. The bus-actor↔board bijection, required in every non-sim
layout word, pairs bus actors with layout BusList entries and so follows
this. Every relay is a thin component against a board record on both
families, so "which board" is one config axis
(`layout_gen.py:234` `board_node_name`, `board_record_file`).

Done when: the field rename, the layout `BusList` and the bijection axiom
regenerate through every gen with reject tests for each, and a window on
one house per family boots the pair.

## Owned elsewhere

- The `gw.house0.no.sieg` word and the oak / fir gens:
  `house0-no-sieg-layout.md`.
- Porting the older axioms to sema runtime tests:
  `beta-field-windows.md` "Do this next".
- The pico params words with `FirmwareCommit` (`async.btu.params/110`,
  `tank.module.params/210`, `flow.hall.params/210`) are staged ahead of
  the firmware; gwsproto stays at the field's 100 / 200 / 200 and the
  scada conformance test records the three as known drift until the
  firmware posts them: OPS-556.

## Generator follow-up: enum class names in axiom templates

Sema axiom templates name enum classes literally
(`ZoneSetpointSource.FromThermostat` in
`gw1_zone_call_circuit_000.py.jinja2`), but a snapshot renders enums
under the seed's local names (tlayouts strips `gw.`/`gw1.`, so
`GwZoneEmitterType` is `ZoneEmitterType` there) and the snapshot build
fails with `NameError`. The circuit's axiom 1 and the layout words'
`FloorLoopCircuitTemp` compare as strings (`str(x) == "FanCoil"`) to get
past this; `ZoneSetpointSource` survives only because it has no prefix
to strip. The right fix is in the sema generator
(`sema/src/sema/tools/runtime_generation/`): expose each field enum's
local class name to the template, as `{{ <type>_class_name }}` already
does for the type itself, and put the enum comparisons back.

## Beech's Hubitat

Not yet looked into. Round four (2026-09-23) ended with beech's two
Hubitat zone channels never populated: `zone1-down-temp`,
`zone1-down-set`, `zone2-up-temp` and `zone2-up-set` had no value for
the whole window while the heat-call channels carried values from the
power meter. Look into the beech Hubitat: whether the hub is reachable
from the box, whether its Maker API still posts to the scada's web
server on port 8000, and whether the window layout's Hubitat component
carries the hub's current address and token. Not a layout-word
question, so it waits for the items above.

## Axiom order

The axiom list is also how a human or an LLM first meets a layout word,
so its order should run from what matters most. Channels are how people,
applications and LLMs make meaning from what happens in the field, and
their axioms belong near the top: `ChannelNameUniqueness` should be among
the first and sits at House0 23, Nolan 19, with the table axioms
appended after it.

Renumber both words once, after every axiom above is in and while the
words are still staging, with the gwsproto mirrors and the sema and scada
tests moving in the same change. This has to precede the promote of
`gw.nolan.layout` in `finalize-layout-lite-13.md`, because a published
word's axiom numbers are immutable.

Done when: both words are renumbered, `sema validate` passes every
generated pair, the scada suite is green, and the beta round after it
boots spruce and beech.
