# House0 0-10V per-output components (spoke)

Status: Accepted · Pass 1 · Updated 2026-09-12 · Linear: OPS-392

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

- **Board record** `dfrobot.gp8403x2` (device type
  `DfrobotDualAnalogOutX2`): the DFRobot pair, two GP8403 modules,
  two outputs each, 12-bit, output register `0x02` (second output
  `0x04`), no mux. `Dacs` holds two `i2c.dac.capability` entries with
  `DacType` `Gp8403` (new enum value) and, as Krida, addresses are
  field-chosen: `AllowedI2cAddressList` on the record (the GP8403
  address is a solder jumper), the chosen pair (`[94, 95]`) on the
  board component's `I2cAddressList`, index-aligned with `Dacs`.
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
  selected by the record's `DacType`. The heartbeat is identical on
  both chips: re-assert the target every 60 s, the last commanded
  value, the power-on value until the first command, one reading per
  successful write.

This supersedes the 2026-09-04 decision to add a second per-output word
(`zero.ten.output.component.gt` with `ModuleComponentId`) and rename
the parent off the vendor name: that route kept two component words and
two actor arms, which is what the relay pattern removed.

## Power-on level → operational params (decided 2026-09-12)

The power-on level is what the pump does with the scada down, a
per-house choice, so it is tunable and belongs in the ops word, not in
the layout's wiring config. The chip-specific fields of
`dac.output.config` split three ways:

- `PowerOnRawValue` → the ops words, as a list on the
  `CaptureTuningList` precedent: a new word `zero.ten.power.on`, one
  entry per 0-10V output node (node name + `PowerOnVoltsTimesTen`, the
  unit `AnalogDispatch` and the `VoltsTimesTen` channel use); the list
  required on both ops words, empty allowed. Both ops words carry the
  same field set by rule, so `gw.nolan.operational.params` and
  `gw.house0.operational.params` move together. The DFR
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

**Persistence is declared, and the DFR is the degraded case.** A
boolean on `i2c.dac.capability`, `SupportsPowerOnStore` (the
`SupportsPinReadback` precedent, one level down because it is a chip
fact), says whether the chip's power-on value can be set and read
back. MCP4728: true; the actor verifies the EEPROM against the ops
level at boot and reprograms only on a mismatch, the one EEPROM-touching
path, unchanged. GP8403: false; the actor never stores, the ops level
is what it asserts at boot and on every heartbeat, and a scada-down
pump sits at the chip's own default. The DFR prototype is on its way
out (gw108 is what deploys at scale), so its degraded behavior is
declared, not fixed.

The ops word is loaded once at boot (`actors/scada_data.py`
`load_operational_params`; actors read `self.ops`); there is no runtime
ops-change path yet, so a changed level is edit-the-artifact, restart,
and the boot verify reprograms the EEPROM where the chip supports it.

gw108-side code changes:

1. `resolve_dac` reads reference, gain and `SupportsPowerOnStore` from
   the DAC capability, and `output_full_scale_volts` from there too.
2. The initial `target_code` comes from this node's ops entry through
   `code_from_volts_times_ten`, via a family-neutral accessor in
   `sema_to_dc` on the `use_sieg_loop` pattern; boot fails loudly when a
   DAC-backed output has no ops entry.
3. `read_eeprom_mismatch` compares against that ops-derived code; the
   reprogram warning says "ops", not "layout"; the verify step is
   skipped when the capability says no store.
4. Fixtures: Nolan `secondary-010v` config loses its three fields; all
   three ops-params artifacts in `tests/config/` gain the list; the
   outputer tests cover ops-sourced power-on and reprogram-on-mismatch.

## Bus path and sim (proposed 2026-09-12)

- **Bus.** Every GP8403 write rides the `I2cBus` single owner through
  the `i2c-bus` node krida rung 3 gave House0: `I2cWriteReg`, two
  bytes, register `0x02` or `0x04` at the module's address; no mux, so
  the outputer's existing `muxed_op` passes straight through
  (`MuxName` None). The multiplexer's direct smbus handle goes with it;
  after this House0 has no I2C writer outside the bus actor.
- **Sim.** The bus actor picks fake silicon from the board record only
  (`actors/i2c_bus.py`, `board.simulated`), so the sim House0 fixture's
  DFR board carries a `gw1.sim.device.type` record
  `SimDfrobotDualAnalogOutX2` (the `SimKridaDoubleRelayBoard16`
  precedent). `SimI2c` gains a `gp8403_addresses` argument and a
  `SimGp8403` (two output registers, write-only, no EEPROM), beside
  `SimMcp4728`; the sim proves a dispatch reached the register the way
  the relay test reads the port word back from `SimPcf8575`.

## Fixture path (decided 2026-09-12)

As krida rung 3 did: the scada fixtures (`gw.house0.layout.json`,
`gw.house0.sim.layout.json`) are hand-patched here; the House0 gen
(`tlayouts/src/tlayouts/house0_sema_gen.py` `emit_dfr`) catches up in
`correct-house0.md`, which carries the note.

## Retirement blast radius (explicit step)

Filled now from a survey of the working tree; **re-run the survey when
the retirement is done** and reconcile this list against it before
anything is deleted (`grep -rln 'zero_ten_out_multiplexer\|
I2cZeroTenMultiplexer\|zero-ten-multiplexer\|DfrComponent\|dfr\.config'`
over `gw_spaceheat/`, `tests/`, `packages/`).

- `gw_spaceheat/actors/i2c_zero_ten_multiplexer.py` (delete)
- `gw_spaceheat/actors/__init__.py` (import + `__all__`)
- `gw_spaceheat/actors/scada.py`
- `gw_spaceheat/actors/zero_ten_outputer.py` (forwarding arm, `H0N`
  import)
- `gw_spaceheat/actors/hydronic/house0.py`
- `gw_spaceheat/actors/leaf_ally/house0/all_tanks.py`
- `gw_spaceheat/actors/leaf_ally/house0/buffer_only.py`
- `tests/config/gw.house0.layout.json`,
  `tests/config/gw.house0.sim.layout.json`
- `gwsproto/names/house0/node_names.py`,
  `gwsproto/data_classes/house_0_names.py`
  (`zero_ten_out_multiplexer`)
- `gwsproto/enums/actor_class.py` (`I2cZeroTenMultiplexer`; sema
  `gw1.actor.class` 014 is staging, so the value drops in place)
- `gwsproto/data_classes/components/dfr_component.py` and the
  `DfrComponentGt` / `DfrConfig` named types (the orphaned words'
  twins)
- `tlayouts` `house0_sema_gen.py` `emit_dfr` and
  `sema/types/dfr_*.py`, `sema/samples/dfr.*.json` (the generator half,
  deferred to `correct-house0.md`, listed so the survey there starts
  complete)

## Where it stands

- Two 0-10V mechanisms exist; only the gw108 one has code on the
  per-output pattern. House0's three outputs are driven through the
  `zero-ten-multiplexer` node holding one `dfr.component.gt` with all
  three in its ConfigList, which writes smbus directly and never
  reports back. The outputer has the two-arm shape `relay.py` had
  before rung 3.
- Sema side is change-controlled. Every word touched is `staging`
  (`dac.output.config`, `i2c.dac.capability`, `i2c.dac.type`,
  `gw1.actor.class` 014, `gw1.scada.device.type.gt`,
  `dfr.component.gt`, `dfr.config`, both ops words, `gw.house0.layout`
  000): edits are in place. Claims `sema/` and `tlayouts/` when it
  starts.

## Do this next

1. Sema sitting (discussion first): `zero.ten.power.on` and the ops-word
   lists, the `dac.output.config` slimming, the `i2c.dac.capability`
   additions (reference, gain, scale, `SupportsPowerOnStore`) and
   `Gp8403`, the DFR board record and its sim twin in tlayouts device
   types, the DFR words orphaned. Snapshot regen, closure mirror,
   gwsproto twins.
2. gw108 side first, on Nolan: code items 1–4 above, suite green.
3. House0: fixture surgery (board component, three per-output
   components, ops list), the GP8403 driver arm and `SimGp8403`,
   the blast-radius list re-surveyed and retired, a per-output
   resolution test on both House0 fixtures.
4. House0 axiom 10's ComponentId clause and House0's ComponentBinding
   (`layout-word-axioms.md` items 6 and 7a; the binding test is
   skipped until then).
5. Witness (below), then the close-down on the krida pattern.

## Witness, gate, definition of done

- **Witness:** a `dist-010v` sweep on beech in a window scada on the
  krida witness rig (`experiments/2026-09-10-beech-krida-witness/`),
  mirroring `experiments/2026-09-06-spruce-pump-speed-sweep/`: dist
  flow and the reported `VoltsTimesTen` channel at each step, the
  deployed scada back as before. No power cycle: the GP8403 stores
  nothing.
- **Gate:** suite green on both House0 fixtures and Nolan; `sema
  validate` on the hand-patched pair; EDD bar before the fleet regen
  uses any of it. Real House0 boxes stay on their deployed artifacts
  until the coordinated dev-wave regen.
- **Done:** one component word and one actor arm for every 0-10V
  output in both families, power-on levels in the ops words, the
  multiplexer and the DFR words gone, the beech witness Verified.

## Open

- Whether `SupportsPowerOnStore` sits on `i2c.dac.capability` (chosen
  here, chip fact) or board-level beside `SupportsPinReadback`.
