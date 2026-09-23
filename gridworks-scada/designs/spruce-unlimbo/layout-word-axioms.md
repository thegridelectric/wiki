# Layout-word axioms (spoke)

Status: Accepted · Pass 1 · Updated 2026-09-22 · Linear: OPS-392

> What this is: the axiom work still open on `gw.house0.layout/000` and
> `gw.nolan.layout/000` before they are promoted. First the required
> channels and nodes for both families, one table each, so the test
> layouts, the sim pairs and the gens carry what the code reads; then
> the heat-pump facts, two structural axioms, the bus list and its
> bus-actor bijection, the sim and nameplate vocabulary gaps, and one
> renumbering. Both words are staging, so every edit is in place.

## Do this next

The required lists come first. "Required channels" and "Required nodes"
are settled and are the first wave: bring both words to the tables,
with reject tests, the regenerated pairs and the mirrors, before any
section below them. The sema word gate (read `sema/spec/primary.md` and
the type spokes, post the summary, wait) comes before the first edit.

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

## Required channels

One table for both families. ✓ means the word requires the Name,
kind-agnostic: it SHALL exist in DataChannels or in DerivedChannels.
— means the word says nothing about it; a house may carry the channel
and nothing depends on it. The word does not name what a house merely
tracks. "Today" names the axiom that already covers the row, so each
edit is a diff against the word rather than a rewrite. The House0 per-row
reasoning is in `scratch/house0-required-guesses.md`.

| Name | House0 | Nolan | Today |
| --- | --- | --- | --- |
| **Power** | | | |
| `hp-odu-pwr` | ✓ | ✓ | House0 via `TransactivePowerChannel` inputs only; Nolan `RequiredSensing` |
| `hp-idu-pwr` | ✓ | — | House0 via `TransactivePowerChannel` inputs only |
| `hp-ctrl-box-pwr` | — | ✓ | Nolan `RequiredSensing` |
| `primary-pump-pwr`, `store-pump-pwr`, `dist-pump-pwr` | ✓ | ✓ | none |
| `secondary-pump-pwr` | — | ✓ | none |
| `buffer-top-elt-pwr`, `buffer-bottom-elt-pwr`, `tank1-top-elt-pwr`, `tank1-bottom-elt-pwr` | — | ✓ | Nolan `RequiredSensing` |
| **Pipe temperatures** | | | |
| `hp-lwt`, `hp-ewt`, `dist-swt`, `dist-rwt`, `store-hot-pipe`, `store-cold-pipe` | ✓ | ✓ | Nolan `RequiredSensing`; House0 none |
| `buffer-hot-pipe` | ✓ | ✓ | none |
| `secondary-lwt`, `secondary-ewt` | — | ✓ | Nolan `RequiredSensing` |
| `fancoil-swt`, `fancoil-rwt`, `floor-swt`, `floor-rwt` | — | ✓ | none; the per-circuit supply and return pairs |
| **Flows** | | | |
| `dist-flow`, `store-flow` | ✓ | ✓ | House0 `RequiredSensing`; Nolan `RequiredSensing` |
| `primary-flow` | ✓ | ✓ | House0 `PrimaryFlowSourceChannelAgreement` (either form); Nolan `RequiredSensing` |
| `secondary-flow` | — | ✓ | Nolan `RequiredSensing` |
| **Sieg surface** | | | |
| `sieg-cold`, `sieg-flow` | ✓ | — | House0 `SiegManifoldChannels` |
| `sieg-hot`, `sieg-send-flow` | ✓ | — | none |
| **Store temperatures** | | | |
| `buffer-depth1..3` | ✓ | ✓ | House0 `BufferTank`; Nolan `RequiredSensing` names the `-device` form |
| `tank{N}-depth1..3`, N in 1..`Hydronic.TotalStoreTanks` | ✓ | ✓ | none; Nolan `RequiredSensing` names `tank1-depth{i}-device` (one tank, `SingleStoreTank`) |
| **Actuator channels** | | | |
| every name `RequiredActuators` lists | ✓ | ✓ | House0 `SiegManifoldChannels` has the two hp-loop relays; the actuator-channel axiom below |
| **Energy and settlement** | | | |
| `transactive-power` | ✓ | ✓ | `TransactivePowerChannel` in both |
| `usable-energy`, `required-energy` | ✓ | ✓ | House0 `SystemModelEnergyChannels`; Nolan none (spruce emits both) |

Nolan drops the six `-device` names from `RequiredSensing` in favour of
the depth names: requiring the `-device` form is what House0 decided
against, and spruce already derives the depth names from it. Where a
depth is derived, `DerivedChannelInputsAcyclic` already requires its
`-device` input to exist.

Not required in either word: `primary-010v`, `buffer-cold-pipe` (handy
where it exists, could not be installed everywhere), `buffer-well`,
`oat`, `oil-boiler-pwr`, the zone `-gw-temp` channels, `dist2-flow`,
every `-hz` channel, every `-device` and `-micro-v` channel, and the
slab temperatures and third depths of spruce's extra picos.

The four Nolan circuit pairs are derived on spruce from its
free-standing tank-module picos: `fancoil-swt` / `-rwt` from
`fancoil-depth1` / `-depth2`, `floor-swt` / `-rwt` from `pipes1-depth1`
/ `-depth2` (`spruce_gen.py` `extra_identity_deriveds`). The word
requires the circuit names, not the pico names; how another Nolan house
meets them is its generator's business. `spruce_gen.py` emits the four
under the required names already.

Done when: both words state the table, a reject test per family shows
the word refusing a layout that lacks a required name, every generated
pair decodes, and the beta round after it boots spruce and beech.

## Required nodes

Same reading as the channel table. Equipment and sensing nodes are not
named: `DataChannelNodeResolution` already requires every DataChannel's
AboutNodeName to be an ShNode, so requiring `store-pump-pwr` brings a
`store-pump` node with it. That clause covers DataChannels only: a
required name met by a DerivedChannel has a creating node
(`DerivedChannelCreatorResolution`) but no about-node, which is why the
heat-pump units are named outright, since the component binding needs
them whatever form the channels take. `buffer` is not required in either
word: House0 `BufferTank` sheds the node and keeps its three depths,
which the channel table carries.

| Node | House0 | Nolan | Today |
| --- | --- | --- | --- |
| **Core** | | | |
| `s`, `s2`, `power-meter`, `ltn`, `admin`, `auto`, `la`, `lc`, `derived-generator` | ✓ | ✓ | `CoreShNodesExistenceAndActorClass` in both |
| `web-server` | ✓ | ✓ | none; the registry key every pico and Hubitat actor posts through |
| **Command** | | | |
| `n`, `five-v-boss`, `pico-cycler`, `hp-boss` | ✓ | ✓ | `CommandNodesExistenceAndActorClass` in both |
| `backup`, `scada-blind` | ✓ | ✓ | House0 `CommandNodesExistenceAndActorClass`; Nolan none |
| `sieg-loop` | ✓ | — | House0 `CommandNodesExistenceAndActorClass` |
| **Actuators** (relays with ActorClass `Relay`, 0-10V outputs with ActorClass `ZeroTenOutputer`, in both words) | | | |
| `vdc-relay`, `hp-scada-ops-relay`, `store-pump-relay` | ✓ | ✓ | `RequiredActuators` in both; Nolan lacks `vdc-relay` |
| `tstat-common-relay`, `charge-discharge-relay`, `hp-failsafe-relay`, `aquastat-ctrl-relay`, `hp-loop-on-off-relay`, `hp-loop-keep-send-relay` | ✓ | — | House0 `RequiredActuators` |
| `dist-010v`, `store-010v` | ✓ | — | House0 `RequiredActuators` |
| `primary-010v`, `primary-pump-failsafe-relay`, `primary-pump-scada-ops-relay` | by the primary-pump fact | — | House0 `RequiredActuators` names them; shed, see "Heat-pump facts" |
| `iso-valve-relay`, `secondary-pump-relay`, `charge-valve-relay`, `buffer-top-elt-relay`, `buffer-bottom-elt-relay`, `tank1-top-elt-relay`, `tank1-bottom-elt-relay` | — | ✓ | Nolan `RequiredActuators` |
| `secondary-010v` | — | ✓ | Nolan `RequiredActuators` |
| each circuit's `FailsafeRelayNode` and `OpsRelayNode` | ✓ | ✓ | `RequiredActuators` b in both |
| **Equipment** | | | |
| `hp-odu` | ✓ | ✓ | `RequiredHeatpumpEquipment` in both |
| `hp-idu` | ✓ | — | House0 `RequiredHeatpumpEquipment`; by the boundary fact once "Heat-pump facts" is in |
| `hp-ctrl-box` | — | ✓ | Nolan `RequiredHeatpumpEquipment`; by the boundary fact once "Heat-pump facts" is in |

Done when: both words state the table, a reject test per family for
`web-server` and for the Nolan additions, every generated pair decodes,
and the beta round after it boots spruce and beech.

## Circuit emitter type and floor temperature

The zone-call circuit says what it heats with, and a radiant circuit
names its floor temperature. On `gw1.zone.call.circuit/000` (staging,
edited in place):

- **`ActuatorKind` becomes `EmitterType`**, the enum `zone.emitter.type`
  with the values `Unknown`, `FinTube`, `CastIronBaseboard`,
  `CastIronRadiator`, `FanCoil`, `RadiantSlab`, `StoreUnderFloor`.
  `Unknown` is the default so a later value decodes on old code as
  "drop, do not act", never as fin tube. The circuit's cooling axiom
  becomes `OnlyFanCoilsCool`: if `EmitterType` is not `FanCoil`,
  `CanCool` SHALL be false.
- **`Role` is removed** for now. No scada actor reads it.
- `zone.actuator.kind` and `zone.circuit.role` are deleted from the
  registry: staging ideas that did not make it out of the gate.
- **`FloorTempChannelName`** (spaceheat.name, optional) names the
  circuit's floor temperature channel.

Both words, axiom `FloorLoopCircuitTemp`: every circuit whose `EmitterType` is
`RadiantSlab` or `StoreUnderFloor` SHALL carry `FloorTempChannelName`,
and it SHALL resolve to a channel in DataChannels or DerivedChannels
whose quantity is Temperature. Spruce meets it on zones 1, 2 and 4
(`zone1-bedrooms-floor-temp`, `zone2-living-rm-floor-temp`,
`zone4-garage-floor-temp`); its upstairs zone is a `FanCoil`, not a
floor loop, which the gen states once the enum exists.

Done when: the three word edits are in, a reject test per family shows
the word refusing a radiant circuit without its floor temperature, and every
generated pair decodes with its circuits' emitter types stated.

## Names that no longer match

`gwsproto/names/` states the family tiers, and two claims in it are now
wrong. Both travel with the word edits, not before them.

- `HydronicSpaceheatNodeNames` holds `sieg-flow`, `sieg-cold`,
  `sieg-loop` and `sieg-send-flow` as names every hydronic plant has.
  They are House0's: a House0 house always has the sieg loop, and a Nolan
  house never does. They move to `House0NodeNames`.
- The `hp_idu` comment reads "when it carries its own refrigerant
  cycle/compressor stage". An indoor unit always exchanges refrigerant
  with water and may or may not have a compressor; maple's Ecodan indoor
  unit has none. House0 axiom 11's parenthetical needs the same wording.

## Heat-pump facts on `gw.hydronic`

The layout states what kind of heat pump the house has, and each family
word constrains it. Three facts, on the shared `gw.hydronic/000`
(staging, edited in place):

- **Refrigerant boundary**: `Monobloc` (all refrigerant outside) or
  `Split` (refrigerant comes inside).
- **Refrigerant cycle**: `Single` (one compressor) or `Cascade` (two
  compressors on two refrigerant circuits in series). To confirm with
  the installer before the enum is named: whether the fact wanted is the
  series topology or only the compressor count.
- **Primary pump**: internal to the heat pump, or field-supplied and
  under scada relays.

| House | Boundary | Cycle | Primary pump |
| --- | --- | --- | --- |
| spruce (Samsung) | Monobloc | Single | internal |
| maple (Mitsubishi Ecodan) | Split | Single | internal |
| beech, oak, fir (LG) | Split | Cascade | field-supplied |
| elm (Arctic high temp; not a House0 house, its own fall layout) | Monobloc | Cascade | field-supplied |

Axioms that follow:

- `gw.nolan.layout`: boundary SHALL be `Monobloc`. `gw.house0.layout`
  and `gw.house0.no.sieg`: boundary SHALL be `Split`.
- `RequiredHeatpumpEquipment` reads the boundary instead of hard-coding
  the parts: `Split` ⇒ `hp-odu` and `hp-idu`; `Monobloc` ⇒ `hp-odu` and
  `hp-ctrl-box`, no `hp-idu`.
- House0: `primary-010v`, `primary-pump-failsafe-relay` and
  `primary-pump-scada-ops-relay` (nodes and channels) SHALL all exist
  when the primary pump is field-supplied and SHALL all be absent when it
  is internal. `RequiredActuators` sheds the three names.

Open:

- `hp.device.type.gt/000` already carries `PrimaryPumpFactoryInstalled`,
  `PrimaryPumpOverridable` and `PrimaryPumpAlwaysOn`, per unit record.
  The record covers units with their own refrigerant cycle, so maple's
  Ecodan indoor unit, a plain exchanger where the internal pump lives,
  has none. Decide whether the layout fact restates the record, or an
  agreement axiom ties the two wherever a record exists.
- Boundary and cycle are model facts too. A cascade split is two unit
  records (outdoor and indoor, a compressor each); the system-level fact
  is stated once on the layout.

Done when: the facts are on `gw.hydronic`, every gen emits them, reject
tests cover each family rule and the primary-pump agreement, a
maple-shaped sim layout with no primary-pump relays boots in the suite,
and maple boots its regenerated pair in a window.

## Every required actuator has its channel

Both words. For every node `RequiredActuators` names (relay or 0-10V
output), a channel with the same Name SHALL exist in DataChannels. House0
`SiegManifoldChannels` then drops its two relay names. With it go the
tank depths: for each N in 1..`Hydronic.TotalStoreTanks` and each depth
i in 1..3, a channel named `tank{N}-depth{i}` SHALL exist in DataChannels
or DerivedChannels.

Done when: both clauses have reject tests in sema and scada and every
generated pair decodes.

## Required but disabled, per channel

A house carries a required node or channel it cannot serve as present
and disabled, in preference to a sim stand-in: `sieg-hot` at beech until
its sensor is installed, `store-cold-pipe` at oak, `primary-pump-pwr` at
maple and at spruce until the CT is fitted (an internal primary pump's
power is as measurable as a field-supplied one's), `store-pump-pwr`,
`dist-pump-pwr` and `buffer-hot-pipe` at spruce. The only switch today
is `Enabled` on a component (a disabled component keeps its node and
channels, the resolution axioms pass, nothing reports).
`store-cold-pipe` is one channel config on the shared ADS component and
`primary-pump-pwr` one config on the electric meter, so the switch has
to reach the channel. To design: where it sits (the channel
config words are the candidate), what the capturing actor does with a
disabled config (no read, no report, no alert), and how a disabled
required channel shows downstream so a consumer can tell "house cannot
serve this" from "sensor is down".

Done when: the cases above are emitted disabled by their gens, the
suite boots a sim layout with a disabled required channel and shows
nothing reported for it, and oak or beech boots its pair in a window.

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

## Declared actuator shape

The layout declares actuators flat under `auto` and the scada's boot
rewrite owns the live tree (`executor/control-hierarchy.md` "Fixed
sub-trees vs floating actuators"). No axiom states it: the nearest are
`PrefixClosedHandles` and `ActuatorLeaves`, which constrain handles, not
the declared shape. Still to write, in both words: an axiom that keeps
the declared shape flat, and ActorHierarchyName closure.

The command nodes are the other half of the declared shape. Both words
require them by Name and ActorClass (House0 axiom 3, Nolan axiom 4) and
pin one handle, `n` at `auto.lc.n`. Every layout declares the rest of the
fixed sub-tree the same way, and no axiom says so:

| Node | Declared handle | Words |
| --- | --- | --- |
| `five-v-boss` | `auto.five-v-boss` | both |
| `pico-cycler` | `auto.five-v-boss.pico-cycler` | both |
| `lc` | `auto.lc` | both |
| `hp-boss` | `auto.lc.n.hp-boss` | both |
| `backup` | `auto.lc.backup` | House0 |
| `scada-blind` | `auto.lc.scada-blind` | House0 |
| `sieg-loop` | `auto.lc.n.sieg-loop` | House0 (sieg word) |

Candidate: the command-node axiom pins every handle in its list, as it
does for `n`.

Done when: both axioms have reject tests, every generated pair decodes,
and a window on spruce and on beech boots the pair with the live tree
unchanged from before the edit.

## Sim 0-10V output has no sim vocabulary

The orange, willow and spruce sim layouts realize their 0-10V outputs
with `i2c.dac.output.component.gt` and no DeviceType, so a simulated
output is indistinguishable from a real one under the rule that scada
tells sim from real by `gw1.sim.device.type` membership
(`executor/components.md` "DeviceType — and the retirement of
MakeModel"). No `sim.dac.output.component.gt` exists. To settle: a sim
component word, or a sim DeviceType on the real word.

Done when: the sim pairs regenerate with the chosen form and the suite
boots them with the sim output actor selected by membership.

## Heat-pump nameplate records for beech and maple

`tlayouts/src/tlayouts/device_types/` holds `hp.device.type.gt` records
for the Samsung at spruce only. Beech (LG) and maple (Mitsubishi) need
theirs, authored from the Drive nameplate photos, so that House0
`RequiredHeatpumpEquipment` components resolve to a real record.

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

## Axiom order

The axiom list is also how a human or an LLM first meets a layout word,
so its order should run from what matters most. Channels are how people,
applications and LLMs make meaning from what happens in the field, and
their axioms belong near the top: `ChannelNameUniqueness` should be among
the first and sits last (House0 23, Nolan 19).

Renumber both words once, after every axiom above is in and while the
words are still staging, with the gwsproto mirrors and the sema and scada
tests moving in the same change. This has to precede the promote of
`gw.nolan.layout` in `finalize-layout-lite-13.md`, because a published
word's axiom numbers are immutable.

Done when: both words are renumbered, `sema validate` passes every
generated pair, the scada suite is green, and the beta round after it
boots spruce and beech.

## Owned elsewhere

- The `gw.house0.no.sieg` word and the oak / fir gens:
  `house0-no-sieg-layout.md`.
- Porting the older axioms to sema runtime tests:
  `beta-field-windows.md` "Do this next".
