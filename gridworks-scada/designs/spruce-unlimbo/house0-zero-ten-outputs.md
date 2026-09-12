# House0 0-10V per-output components (spoke)

Status: Draft · Pass 0 · Updated 2026-09-12 · Linear: OPS-392

> What this is: House0's three `*-010v` outputs onto per-output
> components on the shape the gw108 DAC output already has
> (`i2c.dac.output.component.gt` + `dac.output.config`,
> `executor/hardware-layout.md` "The 0-10V output actuator"), the
> `zero-ten-multiplexer` actor retired, and the power-on level of every
> 0-10V output (both families) moved out of the layout into the
> operational params. Carved out of the relay decommission
> (`krida-retirement.md` rung 3) on 2026-09-10; it follows that rung
> because both retire a multiplexer actor and the relay one sets the
> shape. Slug is provisional.

## The shape (decided 2026-09-12)

The Krida move, repeated. The relay side turned the vendor panel into
one more `gw1.scada.device.type.gt` record, one
`scada.board.component.gt` instance in the layout carrying the
field-chosen addresses, and one `i2c.relay.component.gt` per relay
naming its board; the vendor word and its actor went away, and the
vendor difference (active-low, PCF8575) lives inside the record. The
0-10V side does the same:

- **Board record.** The DFRobot pair (two GP8403 modules at 0x5e and
  0x5f, two outputs each, 12-bit, output register `0x02`) becomes a
  device-type record whose `Dacs` list holds two `i2c.dac.capability`
  entries. `i2c.dac.type` gains `Gp8403`. The record name is open
  (below).
- **Layout.** One `scada.board.component.gt` for the pair, and each
  `*-010v` node gets an `i2c.dac.output.component.gt` with one
  `dac.output.config`, exactly Nolan's `secondary-010v` shape.
- **Retired.** `dfr.component.gt`, `dfr.config`, the
  `I2cZeroTenMultiplexer` actor and node, and the outputer's
  forwarding arm. The DFR words orphan in place with `replaced_by`,
  as the DAC writer trio did (`layout-word-axioms.md` 7b).
- **One actor arm.** `ZeroTenOutputer` resolves its DAC from the board
  record and drives it through the `I2cBus` single owner; the chip
  branch (MCP4728 vs GP8403 register protocol) is in the driver layer,
  selected by the record's `DacType`.

This supersedes the 2026-09-04 decision to add a second per-output word
(`zero.ten.output.component.gt` with `ModuleComponentId`) and rename
the parent off the vendor name: that route kept two component words and
two actor arms, which is what the relay pattern removed.

## Power-on level → operational params (decided 2026-09-12)

The power-on level is what the pump does with the scada down, a
per-house choice, so it is tunable and belongs in the ops word, not in
the layout's wiring config. The chip-specific fields of
`dac.output.config` split three ways:

- `PowerOnRawValue` → the ops words, as a per-output list on the
  `CaptureTuningList` precedent: one entry per 0-10V output node naming
  the node and its power-on level in **volts times ten** (the unit
  `AnalogDispatch` and the `VoltsTimesTen` channel use). Both ops words
  carry the same field set by rule, so `gw.nolan.operational.params`
  and `gw.house0.operational.params` move together. The DFR
  `InitialVoltsTimes100` (values 20, 40, 0; the name is wrong, they are
  volts times ten) is the same fact and goes there too.
- `PowerOnVref`, `PowerOnGain` and the output-stage scale → the board
  record's `i2c.dac.capability`, next to `DacType` (gw108: internal
  reference, gain 1, times five). Retires the outputer's
  `GW108_OUTPUT_GAIN` constant.
- `dac.output.config` keeps `ChannelName`, `ActorName`, `DacChannel`:
  wiring only, chip-neutral.

**Nolan's secondary pump moves from raw code 3020 (7.55 V) to 76 (7.6 V);**
volts on the terminal is the better unit and the step is immaterial.

The ops word is loaded once at boot (`actors/scada_data.py`
`load_operational_params`; actors read `self.ops`); there is no runtime
ops-change path yet, so a changed level is edit-the-artifact, restart,
and the existing boot verify reprograms the EEPROM (the one
EEPROM-touching path stays where it is).

gw108-side code changes:

1. `resolve_dac` reads reference and gain from the DAC capability, and
   `output_full_scale_volts` from there too.
2. The initial `target_code` comes from this node's ops entry through
   `code_from_volts_times_ten`, via a family-neutral accessor in
   `sema_to_dc` on the `use_sieg_loop` pattern; boot fails loudly when a
   DAC-backed output has no ops entry.
3. `read_eeprom_mismatch` compares against that ops-derived code; the
   reprogram warning says "ops", not "layout".
4. Fixtures: Nolan `secondary-010v` config loses its three fields; all
   three ops-params artifacts in `tests/config/` gain the list; the
   outputer tests cover ops-sourced power-on and reprogram-on-mismatch.

## Fixture path (decided 2026-09-12)

As krida rung 3 did: the scada fixtures (`gw.house0.layout.json`,
`gw.house0.sim.layout.json`) are hand-patched here; the House0 gen
(`tlayouts/src/tlayouts/house0_sema_gen.py` `emit_dfr`) catches up in
`correct-house0.md`, which carries the note.

## Where it stands

- Two 0-10V mechanisms exist; only the gw108 one has code on the
  per-output pattern. House0's three outputs are driven through the
  `zero-ten-multiplexer` node holding one `dfr.component.gt` with all
  three in its ConfigList (`tests/config/gw.house0.layout.json`;
  `gw_spaceheat/actors/i2c_zero_ten_multiplexer.py`), which writes
  smbus directly and never reports back. The outputer has the two-arm
  shape `relay.py` had before rung 3.
- Sema side is change-controlled. Every word touched is `staging`
  (`dac.output.config`, `i2c.dac.capability`, `i2c.dac.type`,
  `dfr.component.gt`, `dfr.config`, both ops words, `gw.house0.layout`
  at 000): edits are in place. Claims `sema/` and `tlayouts/` when it
  starts.
- Multiplexer references to retire: `actors/__init__.py`,
  `actors/scada.py`, `actors/zero_ten_outputer.py`,
  `actors/hydronic/house0.py`, `actors/leaf_ally/house0/all_tanks.py`,
  `actors/leaf_ally/house0/buffer_only.py`, both House0 fixtures,
  `gwsproto/names/house0/node_names.py`,
  `gwsproto/data_classes/house_0_names.py`,
  `gwsproto/enums/actor_class.py` (`I2cZeroTenMultiplexer`), and the
  `DfrComponent` data class.

## Do this next

1. Sema sitting (discussion first): the ops-word list, the
   `dac.output.config` slimming, the `i2c.dac.capability` additions and
   `Gp8403`, the DFR board record in tlayouts device types, the DFR
   words orphaned. Snapshot regen, closure mirror, gwsproto twins.
2. gw108 side first, on Nolan: items 1–4 above, suite green.
3. House0: fixture surgery (board component, three per-output
   components, ops list), the GP8403 driver arm and its sim chip,
   multiplexer and references gone, a per-output resolution test on
   both House0 fixtures.
4. House0 axiom 10's ComponentId clause and House0's ComponentBinding
   (`layout-word-axioms.md` items 6 and 7a; the binding test is
   skipped until then).

## Open (the grill continues here)

- **DFR record name** and whether its addresses are field-chosen
  (`AllowedI2cAddressList` on the record, `I2cAddressList` on the
  component, as Krida) or fixed in the record: the GP8403 address is
  set by a solder jumper.
- **GP8403 persistence.** Whether the chip can store a power-on value
  (DFRobot's library has a store command); if not, the ops level is
  simply what the actor asserts at boot and on every heartbeat, and
  the verify step is a no-op for that chip.
- **Sim chip.** A simulated GP8403 in the sim driver on the
  `SimPcf8575` precedent; both House0 fixtures run actors in the suite.
- **`ActorClass` enum.** Removing `I2cZeroTenMultiplexer`: whether the
  enum has a sema twin and what its status allows.
- **Heartbeat semantics** (last commanded value; power-on value only
  until the first command) survive unchanged for the GP8403 arm?
- **Witness, gate, definition of done.** Proposed: a pump-speed sweep
  on beech's `dist-010v` in a window scada, mirroring
  `experiments/2026-09-06-spruce-pump-speed-sweep/`, using the beech
  window rig from the krida witness. Gate: suite green on both House0
  fixtures and Nolan; EDD bar before the fleet regen uses any of it.
