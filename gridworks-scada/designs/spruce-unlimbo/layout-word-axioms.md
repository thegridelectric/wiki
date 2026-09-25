# Layout-word axioms (spoke)

Status: Accepted · Pass 1 · Updated 2026-09-25 · Linear: OPS-392

> What this is: the axiom work still open on `gw.house0.layout/000` and
> `gw.nolan.layout/000` before they are promoted, the `gw.house0.no.sieg`
> word that completes the family set, and the windows that close the
> spoke. Both staging words carry the required channel and node tables,
> the circuit's emitter type, the store-tank depths, the `web-server`
> node, the disabled lists, the actuator channels, the declared command
> tree and the heat-call–circuit bijection, with runtime and gwsproto
> tests, and `gw.hydronic` states who owns the primary pump and the
> refrigerant cycle. Open: the nameplate vocabulary gap, the sema generator's enum names, the renumbering, the no-sieg
> word, and the closing windows. Staging words are edited in place.

## Do this next

Every axiom wave to date is committed: sema `c6c23ab`, tlayouts
`204aca9`, scada `41dbb647` (all three on their layout branches). The
four gens that fail are elm, fir and oak on `SiegManifoldChannels`
(they wait for `gw.house0.no.sieg`, below) and honeysuckle on
`RequiredSensing` (not a house).

1. **Next: "Heat-pump nameplate records for beech and maple".**
2. "Generator follow-up: enum class names in axiom templates" (sema
   generator), then the runtime-test port in "Owned elsewhere".
3. A maple-shaped sim pair in the scada suite (`HeatPump` owner, no
   primary-pump actuators; the willow pair backs the 0-10V tests over all
   three outputs, so it stays), and an `ApiFlowModule` sim pair (orange
   or willow) for the flow module's zero-flow test.
4. "Axiom order": the one renumbering, both words.
5. "The `gw.house0.no.sieg` word": the third family, with oak and fir.
6. **Last: "The closing windows"** on spruce, beech and maple.

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

## Owned elsewhere

- `LayoutLite` carries no disabled lists
  (`named_types/layout_lite.py:39-40`), so the LTN cannot tell disabled
  from missing: `finalize-layout-lite-13.md`.
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

## The `gw.house0.no.sieg` word

There are three in-field layout families. `gw.house0.layout` means
has-a-siegenthaler-loop (maple, beech); `gw.nolan.layout` is spruce; oak,
fir and elm are the sieg-less House0 topology, the same core plant with
no siegenthaler loop: no sieg-loop actor, no `sieg-cold` / `sieg-flow` /
`sieg-hot` sensing, no hp-loop valve relays. A sieg loop is a topology
change, a family, not a variant: whether the loop is used is
`UseSiegLoop` on `gw.house0.operational.params`; having it at all is the
family split. Three of the six boxes are this family and cannot take the
branch without the word.

The word is flat (sema words do not inherit): the `gw.house0.layout`
schema with the sieg surface removed. Relative to House0:

- the sieg-loop node leaves `RequiredCommandNodes` and `CommandNodeHandles`
  loses its three sieg rows;
- `SiegManifoldChannels` goes, and `sieg-cold`, `sieg-flow`, `sieg-hot`
  and `sieg-send-flow` leave `RequiredSensing`; no `-hz` channel;
- the two hp-loop relays leave `RequiredActuators`;
- everything else House0 has stays, `store-pump-relay` included (an
  every-hydronic-plant name). Oak and fir keep the buffer tank, the iso
  valve and the store tanks; the three fall installs with no iso valve,
  no buffer or no water tanks are further layouts (OPS-532).

Every other axiom mirrors House0's by NAME, numbered for this word, so
the renumbering in "Axiom order" is done first and the new word takes
the settled order. The sema authoring gate applies: read the registry and
authoring spokes for types, post the read-receipt, and discuss the
addition before the registry edit.

Generators: `house0_no_sieg_sema_gen.py` is the family gen (today a
`NotImplementedError` stub), built from `house0_sema_gen.py` with the
sieg surface deleted; `oak_gen.py` and `fir_gen.py` repoint to it (they
emit `gw.house0.layout` today and fail `SiegManifoldChannels`), and
`elm_gen.py` follows. A sim pair ships in the same wave as the word, so
the scada suite has a fixture of this family; the tlayouts snapshot, the
scada closure copy and a gwsproto `House0NoSiegLayout` with its
`check_axiom_<n>` mirrors and reject tests travel as one wave, as every
word edit does.

Done when: the word is staging with `sema validate` green on every oak,
fir and elm pair and the sim pair; the gwsproto twin and its tests are
in; the scada suite boots the sim pair. Open: real oak / fir / elm
instance filenames, distinct from the fixture.

## The closing windows

The spoke ends with a window on spruce, beech and maple
(`beta-field-windows.md`, `experiments/field-window-recipe.md`): each
boots its regenerated pair with the live command tree unchanged, and
beech, with `dist-btu` in its disabled lists, shows nothing reported for
a disabled name and one `disabled-roster` Warning. Spruce's window
layout comes from `spruce_gen.py` on tlayouts `jm/spruce`, so that
branch takes the gen edits of every wave above first. Maple's first
window is also its first boot on the renovation branch. Three clean
windows close the spoke; the durable content is already in
`executor/hardware-layout.md`, `executor/components.md` and
`executor/control-hierarchy.md`, and what remains is deleted with the
file.
