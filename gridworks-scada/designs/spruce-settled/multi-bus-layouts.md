# Multi-bus layouts (spoke)

Status: Draft · Pass 0 · Updated 2026-09-25 · Linear: OPS-532

> What this is: a layout that declares more than one I²C bus — a board
> with two buses, or a second board (a secondary pi driving a second
> gw108) — expressible in the layout words and driven by the scada,
> with the bus actor bound to its bus by the layout and not by
> convention. Decided shape and the build inventory from an adversarial
> plan review; deferred from spruce-unlimbo's layout-word-axioms
> sitting because it is a scada feature across four actors, the sim
> driver, tlayouts and the secondary scada, none of which the launch
> needs. The seam it replaces: `gw1.scada.device.type.gt` axiom 6
> `SingleBus` holds a board record to one bus.

## Today

One board, one bus, one `I2cBus` actor per layout, bound by
convention: tlayouts emits one node named `i2c-bus`
(`hardware/board.py`), the actor takes the layout's one board through
`HydronicLayout.scada_board()` (raises unless exactly one board) and
opens the adapter the record's single `BusList` entry names. Bus-op
messages carry the actor's node name. `Relay`, `ZeroTenOutputer` and
`I2cThermistorReader` each look up "the one `I2cBus` node" at
construction. All three board records declare one bus, `DefaultBus`,
`BusNumber 1`.

## Decided shape

A bus is a board-resident component, bound like a relay or a DAC
output — not a layout-level table of bus bindings. The layout-table
shape was rejected because the sema rule that an axiom cannot name an
inline object would have made each table entry a word holding nothing
but three foreign keys, and because it would have been a second
binding mechanism beside the one every other board-resident actor
uses.

- New word `i2c.bus.component.gt/000`: `ComponentId`,
  `BoardComponentId`, `BusName` (a `Name` in the board record's bus
  list), `DisplayName`, optional `HwUid` (the loader recognizes board
  residency through `BoardResidentComponentBase`, which carries it).
  No `DeviceType`: the board says sim.
- `gw1.scada.device.type.gt`: `BusList` → `BoardBusList`, `SingleBus`
  retired, and a uniqueness axiom (`Name` and `BusNumber` pairwise unique) so two
  actors can never own one adapter.
- Layout words: the word joins the `Components` union;
  `BoardResolution` gains the bus clause (`BusName` against
  `BoardBusList`); a records-unique-per-`DeviceType` axiom (the loader
  keys records by `DeviceType` and today overwrites duplicates); and a
  bidirectional axiom: every bus component ↔ exactly one uniquely named
  `I2cBus` ShNode, every `I2cBus` ShNode binds a bus component, every
  record bus has exactly one component. `ComponentBinding` alone does
  not give this: it constrains neither the node's ActorClass nor the
  absence of unbound bus actors.

## Build inventory

From the plan review (2026-09-25), each an obligation the build meets:

1. A resolver keyed by (board component, bus name) that `Relay`,
   `ZeroTenOutputer` and `I2cThermistorReader` use in place of "the one
   `I2cBus` node". A relay reaches its bus through `RelayName →
   ExpanderIdx → Expanders[].I2cBus`; DACs and ADCs carry `I2cBus` on
   their record entries. Bus-op `Bus` stays the resolved actor's node
   name.
2. `I2cBus` builds a bus-local view — expanders, muxes, DACs,
   thermistor ADCs and CT ADC filtered by its `BusName` — and one
   isolated `SimI2c` per bus; the same I²C address on two buses must
   not collide. Its relay re-assert list is board- and bus-qualified.
3. `I2cBus` opens `smbus2.SMBus(entry.BusNumber)` for its own entry;
   axiom 6 `SingleBus` and its `check_axiom_6` mirror go.
4. Process ownership: which scada process (`s`, `s2`) drives a bus is
   the bus node's actor hierarchy; (process, `BusNumber`) unique. A
   secondary-scada child actor cannot boot today — every `ShNodeActor`
   reads `ops.Tariff` at construction and `SecondaryScada` does not
   provide it — so that is a prerequisite, or the second board waits.
5. tlayouts: `boards: Sequence[BoardSpec]` in place of the single
   `board_node_name` / `board_record_file`; every board-resident device
   spec selects its board; a deterministic node-naming rule for bus
   nodes that keeps `i2c-bus` for the one-bus case.
6. Contracts: `executor/hardware-layout.md` "Invariants" and
   `executor/components.md` "DeviceType — and the retirement of
   MakeModel" describe the binding; the bus-op words' prose
   (`i2c.write.reg`, `i2c.result`, published) says "bijection against
   BusList" and is corrected as prose clarification or by new version.
7. Sweep: zero readers of `BusList` (the hard-coded Krida record
   `data_classes/device_types/scada_krida.py`, sema runtime and axiom
   templates, fixtures) and of `scada_board()` (the actor and three
   tests) after regeneration.

Done when: a synthetic two-bus board and a two-board `s`/`s2` layout
validate in sema and boot in the scada suite, with device routing,
repeated addresses across buses, per-bus sim isolation and the selected
`BusNumber` each exercised; reject tests cover missing and duplicate
coverage, invalid `BusName`, wrong actor class, extra bus actor,
duplicate bus `Name`/`BusNumber`, and same-process adapter collision.
