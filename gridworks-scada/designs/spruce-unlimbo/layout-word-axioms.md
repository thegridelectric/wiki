# Layout-word axioms (spoke)

Status: Accepted · Pass 1 · Updated 2026-09-24 · Linear: OPS-392

> What this is: the axiom work still open on `gw.house0.layout/000` and
> `gw.nolan.layout/000` before they are promoted. Both words carry the
> required channel and node tables, the circuit's emitter type, the
> store-tank depths, the `web-server` node, the disabled lists with
> their axioms, the actuator channels, the declared command tree and
> the heat-call–circuit bijection, with runtime and gwsproto tests, and
> `gw.hydronic` states who owns the primary pump and the refrigerant
> cycle. Open: carrying the last sema wave through tlayouts and
> gwsproto, a maple-shaped sim pair, the bus list, the sim and nameplate
> vocabulary gaps, and one renumbering. Both words are staging, so every
> edit is in place.

## Do this next

Where the three repos stand (2026-09-24 evening):

- sema `jm/handles-wave`, clean: `b3c6c54` (`CommandNodeHandles`, House0
  33 / Nolan 30) and `542acba` (`HeatCallChannelBelongsToCircuit`
  House0 34 / Nolan 31, `DisabledNodesAreSensors` and
  `TransactivePowerChannel` restated, `Enabled` off the six pico
  component words, `WebServer.Serve`, `hubitat.poller.gt/001` and
  `maker.api.attribute.gt/001` without `Enabled`).
- tlayouts `jm/handles-wave`, dirty: the snapshot at `b3c6c54` and every
  gen declaring the authored tree (`CommandNodeHandles`), green, not yet
  committed; the pending entry is in `wiki/tlayouts/changelog.md`.
- scada `jm/spruce-unlimbo`, dirty: the `CommandNodeHandles` mirrors,
  closure copy and sim fixtures, green, not yet committed; the pending
  entry is in `wiki/gridworks-scada/changelog.md`. The actors already
  read the disabled lists and no actor reads a pico component's
  `Enabled` (`7f629931`).

1. **Commit the two dirty trees first** (tlayouts, then scada), so the
   `CommandNodeHandles` wave and the `542acba` wave stay two commits per
   repo; both pending changelog entries are written.
2. **Next: carry `542acba` through tlayouts** on `jm/handles-wave`:
   `scripts/regen_sema_snapshot.sh --allow-staged` against sema at
   `542acba`, then the gens follow the words. `Enabled=` leaves the pico
   component constructors (`hardware/btu_meter.py:63`,
   `hardware/tank_module.py:93,161`, `layout_gen.py:698`) and the
   hubitat poller and attribute constructors (`hardware/hubitat_zone.py:81,101`);
   the web server's `Enabled=True` becomes `Serve=True`
   (`layout_gen.py:568`). The spec flags (`FlowSpec.enabled`
   `layout_gen.py:148`, `ExtraTankSpec.enabled` `tank_module.py:65`,
   `BtuSpec.enabled` `btu_meter.py:47`) have one reader each, the
   constructor that goes, and `beech_gen.py:180` (`dist-btu`
   `enabled=False`) and `spruce_sim_gen.py:69` set them: decide whether
   the flag stays as the gen's way of filling `disabled_node_names`
   (`layout_gen.py:265`) or the gens name the disabled lists directly and
   the flag goes with its readers. Spruce's transactive set drops
   `secondary-pump-pwr` (`spruce_gen.py:285`). Every gen regenerates and
   `sema validate` passes each pair; the `ApiFlowModule` sim pair for the
   zero-flow test (orange or willow) rides this regen.
3. **Then scada** on `jm/spruce-unlimbo`: the closure copy follows the
   snapshot; gwsproto twins follow the words — `Enabled` off the six
   pico component twins (`named_types/pico_*_component_gt.py`,
   `sim_pico_*_component_gt.py`), `WebServerComponentGt.Serve`
   (`scada.py:222` reads it), `HubitatPollerGt` and `MakerAPIAttributeGt`
   at `001` without `Enabled` (`named_types/hubitat_poller_gt.py`); the
   hubitat poller's `Poller.enabled` / `attribute.enabled` reads
   (`hubitat_poller.py:217,219,244,285,289`) give way to `node_disabled`
   / `channel_disabled`, which already sit beside them. Mirrors for
   House0 34 / Nolan 31 and the two restated axioms, each with a reject
   test; the conformance test's known-drift sets say what the closure
   still reaches at an older version. Suite green, then the pending
   changelog entry.
4. **A window on spruce and on beech** boots the pair from both waves
   with the live command tree unchanged; oak or beech shows nothing
   reported for a disabled name (`beta-field-windows.md`).
5. A maple-shaped sim pair in the scada suite (`HeatPump` owner, no
   primary-pump actuators; the willow pair backs the 0-10V tests over
   all three outputs, so it stays).
6. Then the runtime-test port in "Owned elsewhere" and, last of all,
   "Axiom order".

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
`EnabledDerivedChannelsHaveLiveInputs`) and the `TransactivePowerChannel`
clause that no metered input is disabled. Disabling is a sensing concept:
an actuator is wired or absent, so `DisabledNodesAreSensors` excludes
`Relay` and `ZeroTenOutputer` nodes and their channels. The layout's
lists are the one place a missing sensor is declared, so the
per-component `Enabled` flags are gone from the vocabulary; the web
server's flag names a different idea (whether the scada serves HTTP) and
is `Serve`. The why and the plan behind each disabled name are the
service-record word, OPS-558. Canon: `executor/components.md` "A sensor
out of service".

In the scada (`7f629931`): a disabled node's actor is built and idle
(gwproactor builds every child unconditionally, `gwproactor/app.py:259-285`);
a disabled channel is filtered at its actor's channel-discovery step, so
there is no read, no `ChannelFlatlined`, no quiet-channel or
open-thermistor Warning and no i2c broken-input latch; the derived
generator skips a disabled DerivedChannel and `feeds_derived` ignores
it; `unreported_channels` returns the disabled set and the
UnknownChannels line leaves them out; a `disabled-roster` Warning goes
out at start and daily. `test_pico_disabled.py` pins it. Not pinned: the
flow module's zero-flow leak, because no test layout under
`tests/config` carries an `ApiFlowModule` (a sim-gen change, step 2 of
"Do this next").

`I2cRelayMultiplexer` and `I2cZeroTenMultiplexer` stay in
`gw1.actor.class/014`, marked defunct like `I2cRelayBoard`: a value in a
published version is never removed, and a staging version may drop only
values it appended itself (`sema/spec/authoring/enums.md` "Evolution
Rules").

Done when: no gen and no gwsproto twin carries a component `Enabled`,
and oak or beech boots its pair in a window with nothing reported for a
disabled name.

## Declared actuator shape and the command tree

The authored tree is the plant with no one in charge yet. `auto` is the
root; the command nodes and every actuator hang directly under it, the
fixed relays declared under the interior node that owns them; local
control's own nodes (`n`, `backup`, `scada-blind`) hang under `lc`. The
scada's first rewrite hands the actuators to `lc` and local control
hands them to `n`, so the live tree reads `auto.lc.n.<node>` where the
layout reads `auto.<node>`; that difference is what floating means, and
the published `new.command.tree` is the authority on where a node sits
(`executor/control-hierarchy.md` "Fixed sub-trees vs floating
actuators"). `CommandNodeHandles` (House0 33, Nolan 30) pins the handle
of every command node and fixed relay; every other actuator's handle is
`auto.<Name>`.

Built: the word (sema `b3c6c54`), the gens and every pair, the mirrors
with reject tests (both trees uncommitted, "Do this next" step 1). The
scada's two tree builders already produce this shape, so no control code
changed. Left: the window in "Do this next" step 4. The handle table is in
`executor/control-hierarchy.md` "Fixed sub-trees vs floating actuators".

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

- `LayoutLite` carries no disabled lists
  (`named_types/layout_lite.py:39-40`), so the LTN cannot tell disabled
  from missing: `finalize-layout-lite-13.md`.
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
