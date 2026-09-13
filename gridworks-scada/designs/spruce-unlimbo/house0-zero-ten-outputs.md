# House0 0-10V per-output components (spoke)

Status: Accepted · Pass 1 · Updated 2026-09-13 · Linear: OPS-392

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
`scada.board.component.gt` instance in the layout, and one
`i2c.relay.component.gt` per relay naming its board; the vendor word
and its actor went away, and the vendor difference lives inside the
record. The 0-10V side does the same:

- **The board record is the bus population.** The layout data class
  and the bus actor take exactly one `scada.board.component.gt` per
  layout (`hydronic_layout.py` `scada_board`), so the DFRobot pair is
  not a second board: House0's existing `scada.krida` record gains two
  `i2c.dac.capability` entries (`DacType` `Gp8403`, new enum value;
  addresses 94 and 95, fixed in the record; `Channels` 2, no mux). The
  record now describes the House0 I2C panel, Krida expanders plus the
  GP8403 modules; renaming its device type is optional.
- **Layout.** Each `*-010v` node gets an `i2c.dac.output.component.gt`
  naming the board and its DAC, with one `dac.output.config`, exactly
  Nolan's `secondary-010v` shape.
- **Retired.** `dfr.component.gt`, `dfr.config`, the
  `I2cZeroTenMultiplexer` actor and node, and the outputer's
  forwarding arm. The DFR words orphan in place with `replaced_by`
  and leave both layout words' Components unions, as the DAC writer
  trio did (`layout-word-axioms.md` 7b). The `I2cZeroTenMultiplexer`
  value stays in `gw1.actor.class` (enum values are never removed;
  `I2cRelayMultiplexer` stayed the same way) and in its gwsproto
  mirror; only the actor goes.
- **One actor arm.** `ZeroTenOutputer` resolves its DAC from the board
  record and drives it through the `I2cBus` single owner. The chip
  branch (MCP4728 vs GP8403 register protocol) is in the driver layer,
  selected by the record's `DacType`. The heartbeat is identical on
  both chips: re-assert the target every 60 s, the last commanded
  value, the power-on value until the first command, one reading per
  successful write.

This supersedes the 2026-09-04 decision to add a second per-output word
(`zero.ten.output.component.gt` with `ModuleComponentId`) and rename
the parent off the vendor name: that route kept two component words and
two actor arms, which is what the relay pattern removed.

## Chip and board facts stay in the drivers (decided 2026-09-12)

Sema carries what crosses a boundary or varies per house. Facts fixed
by the choice of device are driver tables in scada, keyed on the
record's `DacType` and the board's `DeviceType`:

- per `DacType` (`drivers/mcp4728.py`, `drivers/gp8403.py`): code span,
  reference and gain semantics, register protocol, and whether the
  chip has a storable power-on value (MCP4728 yes, GP8403 no);
- per board `DeviceType`: the output-stage multiplier that sets
  full-scale terminal volts (five on gw108, 10.24 V; one on the
  DFRobot module, 10 V). Retires the outputer's `GW108_OUTPUT_GAIN`
  constant and its "missing word" note; the MCP4728 reference and
  gain bits become the driver's fixed gw108 choice (internal, gain 1,
  which the outputer already insists on).

`i2c.dac.capability` is untouched.

## Power-on level → operational params (decided 2026-09-12)

The power-on level is what the pump does with the scada down, a
per-house choice, so it is tunable and belongs in the ops word, not in
the layout's wiring config:

- New word `zero.ten.power.on` (node name, `PowerOnVoltsTimesTen`, the
  unit `AnalogDispatch` and the `VoltsTimesTen` channel use; axiom: at
  most 100) and a required `ZeroTenPowerOnList` on both ops words on
  the `CaptureTuningList` precedent, empty allowed. Both ops words
  carry the same field set by rule, so `gw.nolan.operational.params`
  and `gw.house0.operational.params` move together. The DFR
  `InitialVoltsTimes100` (values 20, 40, 0; the name is wrong, they are
  volts times ten) is the same fact and goes there too.
- `dac.output.config` drops `PowerOnRawValue`, `PowerOnVref`,
  `PowerOnGain` and its EEPROM axiom: `ChannelName`, `ActorName`,
  `DacChannel`, wiring only, chip-neutral.

**Nolan's secondary pump moves from raw code 3020 (7.55 V) to 76 (7.6 V);**
volts on the terminal is the better unit and the step is immaterial.

The MCP4728 keeps the boot verify-and-reprogram of its EEPROM against
the ops level, the one EEPROM-touching path, unchanged. The GP8403
stores nothing: the ops level is what the actor asserts at boot and on
every heartbeat, and a scada-down DFR pump sits at the chip's own
default. The DFR prototype is on its way out (gw108 is what deploys at
scale), so its degraded behavior is a driver fact, not something to
work around.

The ops word is loaded once at boot (`actors/scada_data.py`
`load_operational_params`; actors read `self.ops`); there is no runtime
ops-change path yet, so a changed level is edit-the-artifact, restart,
and the boot verify reprograms the EEPROM where the chip can store it.

gw108-side code changes:

1. `resolve_dac` takes full-scale volts and the store capability from
   the driver tables by `DacType` and board `DeviceType`.
2. The initial `target_code` comes from this node's ops entry through
   `code_from_volts_times_ten`, via a family-neutral accessor in
   `sema_to_dc` on the `use_sieg_loop` pattern; boot fails loudly when a
   DAC-backed output has no ops entry.
3. `read_eeprom_mismatch` compares against that ops-derived code; the
   reprogram warning says "ops", not "layout"; the verify step is
   skipped when the driver says the chip cannot store.
4. Fixtures: Nolan `secondary-010v` config loses its three fields; all
   three ops-params artifacts in `tests/config/` gain the list; the
   outputer tests cover ops-sourced power-on and reprogram-on-mismatch.

## Bus path and sim (decided 2026-09-12)

- **Bus.** Every GP8403 write rides the `I2cBus` single owner through
  the `i2c-bus` node krida rung 3 gave House0: `I2cWriteReg`, two
  bytes, register `0x02` or `0x04` at the module's address; no mux, so
  the outputer's existing `muxed_op` passes straight through
  (`MuxName` None). The multiplexer's direct smbus handle goes with it;
  after this House0 has no I2C writer outside the bus actor.
- **Sim.** No simulated GP8403. The sim House0 record
  `SimKridaDoubleRelayBoard16` gains two `Mcp4728` DAC entries, so the
  sim House0 drives its three outputs through `SimMcp4728` on the
  same outputer arm and the same EEPROM verify path as Nolan. The
  GP8403 arm is covered by a pure unit test of the driver's encoding
  and by the beech witness; five homes on the way out do not earn a
  sim chip.

## Fixture path (decided 2026-09-12)

As krida rung 3 did: the scada fixtures (`gw.house0.layout.json`,
`gw.house0.sim.layout.json`) are hand-patched here; the House0 gen
(`tlayouts/src/tlayouts/house0_sema_gen.py` `emit_dfr`) catches up in
`correct-house0.md`, which carries the note. The two record edits
(`scada.krida` and its sim twin) are tlayouts device-type files and
ride the snapshot regen.

## Retirement blast radius (explicit step)

Surveyed before and after the retirement (`grep -rln
'zero_ten_out_multiplexer\|I2cZeroTenMultiplexer\|zero-ten-multiplexer\|
DfrComponent\|dfr\.config'` over `gw_spaceheat/`, `tests/`,
`packages/`). After: only the `gw1.actor.class` enum value and the
gwsproto DFR twins remain, both by design (below). The pre-survey list
also caught `local_control/house0/tou_base.py` (a dead `DfrComponent`
import) and the gwsproto `data_classes/components/__init__.py` export,
which stays with the twins.

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
- `gwsproto/enums/actor_class.py`: `I2cZeroTenMultiplexer` STAYS (the
  sema enum keeps it); only the actor-class-to-actor mapping drops it
- `gwsproto/data_classes/components/dfr_component.py` and the
  `DfrComponentGt` / `DfrConfig` named types: the orphaned words'
  twins STAY until `correct-house0.md` moves the gen off them (the
  seed keeps the words in the closure until then)
- `tlayouts` `house0_sema_gen.py` `emit_dfr` and
  `sema/types/dfr_*.py`, `sema/samples/dfr.*.json` (the generator half,
  deferred to `correct-house0.md`, listed so the survey there starts
  complete)

## Where it stands

- One 0-10V mechanism: every output in both families is an
  `i2c.dac.output.component.gt` against its board record, driven by
  the one-arm `ZeroTenOutputer` through the bus actor; the chip branch
  (MCP4728 vs GP8403) is in the outputer's write path and boot step,
  fed by the driver tables. The multiplexer actor, node and names are
  gone (scada `17e277d3`); its `ActuatorsReady` duty moved to
  each output (the scada's required actuators are the
  `ZeroTenOutputer` nodes). The House0 fixtures are hand-patched; the
  House0 gen still emits the DFR shape (`correct-house0.md`).
- Sema side is change-controlled. Every word touched is `staging`
  (`dac.output.config`, `i2c.dac.type`, `dfr.component.gt`,
  `dfr.config`, both ops words, both layout words at 000): edits are
  in place. Claims `sema/` and `tlayouts/` while it runs.

## ▶ Do this now: the sim soak, then the House0 binding (step 5)

Steps 1–4 are built (below). Before step 5 and before the beech window:
the sim House0 pair must run 10 minutes clean on the dev broker, idle
and then with the sweep driver in front. The dev rung's shutdown traced
to partition residue (scada `bd13a371` moved 82 defs off `ShNodeActor`;
two plain-`ShNodeActor` readers were not repointed), so the queue is:

1. ✅ DONE `SiegLoop` onto `House0Hydronic` (six moved names; its movement
   errors were swallowed by "Error during movement" and the valve
   never moved). Interim: `sieg-command-tree.md` is where it ends.
   Test: one keep-more movement on the sim House0 fixture sends the
   relay commands and logs no movement error.
2. ✅ DONE `DerivedGenerator` reads `self.data.latest_temperatures_f` and the
   required-energy channel directly (lines 755 and 846); it stays on
   tier A, it is a producer outside the command tree. Test: the
   keepalive survives its first main-loop pass after a forecast.
3. ✅ DONE Delete `orig_sieg_loop.py` (signed-off kill list); `sieg_loop.py`
   points at scada `c55fe9eb` for the original.
4. ✅ DONE mypy over `gw_spaceheat/actors/` once (no moved-name read remains); post the attribute-error
   list and close every plain-base read of a moved name it finds.
5. ✅ DONE typing decision: no gate (the `transitions` triggers and
   the hand-derived gwsproto make a gate mostly noise); a periodic
   mypy sweep of `gw_spaceheat/actors/` filtered to attribute errors,
   recorded in GridWorks_CLAUDE's scada renovation section.

Then the soaks (✅ DONE 2026-09-13: idle and with the driver, both 10
minutes clean on scada `3f607f8c`). A fault on a missing channel or node is hand-added to
`tests/config/gw.house0.sim.layout.json` and to the beech window pair
in the witness folder's `instances/` (and to its `derive_layout.py`
so a re-derive keeps it), with a line in `correct-house0.md`. Then on
`jm/spruce-unlimbo`: House0 axiom 10's ComponentId clause and House0's
ComponentBinding (`layout-word-axioms.md` items 6 and 7a); the binding
test is skipped until then. Then the witness.

**Found during step 4, for whoever picks up next:**

- The live-test conftest seeds every proactor config dir with the
  Nolan ops file; a live test on another layout must name its pair's
  ops through `ScadaLiveTest(ops_path=...)`, or the primary scada boots
  the House0 layout with Nolan ops and no pairing check catches it
  (`load_layout` checks the pair; `scada_data.load_operational_params`
  does not). OFI: the pairing check belongs where the ops are loaded.
- `sema validate` on the hand-patched pair: the sim layout is OK; the
  real layout fails on a pre-existing `DataChannels.*.InPowerMetering`
  extra field (unrelated to this step; it failed the same way before).
- The gwsproto conformance sweep reports two pre-existing version
  drifts (`gw1.quantity`, `gw1.unit` at 002 vs snapshot 001).
- The witness rung's dev run (sim House0 on the dev broker, scada
  `17e277d3`) proved the arm end to end through admin and the bus
  actor, then the scada shut itself down on the derived generator's
  missing `latest_temps_f`; the queue above closes it.

**What the step-4 session knew first (kept for the record):**

- `ZeroTenOutputer.resolve_dac` refuses a `Gp8403` DAC with a plain
  message; the GP8403 write path is this step. `drivers/gp8403.py` has
  the register map (`OUTPUT_REG` per channel, `RANGE_REG`/`RANGE_10V`
  written once at init, `encode_word`); the outputer's `DAC_FACTS` table
  already carries its facts. The write is `I2cWriteReg`, two bytes, at
  the module address, no mux; the boot verify is skipped because the
  chip stores nothing.
- `DAC_FACTS` is keyed on `DacType` alone; the MCP4728 entry's 10.24 V
  full scale assumes the gw108 output stage, the only board carrying
  one. If a board ever drives an MCP4728 bare, the table gains a board
  key then, not before.
- `SimI2c` places `SimMcp4728`s behind the mux only (`dac_mux_channels`);
  the sim House0 board record's two `Mcp4728` entries sit directly on
  the bus, so the sim bus needs muxless DAC placement (and the bus actor's
  `SimI2c` construction reads only `record.Dacs[0]`).
- The House0 real fixture's board record is the tlayouts `scada.krida`
  file with the two `Gp8403` entries (`Dfr1` 94, `Dfr2` 95); the sim
  fixture's `SimKridaDoubleRelayBoard16` record is hand-patched in
  `tests/config/gw.house0.sim.layout.json` and gets two `Mcp4728`
  entries there.
- Each `*-010v` node gets an `i2c.dac.output.component.gt`
  (`BoardComponentId` = the House0 board, `DacName` `Dfr1`/`Dfr2`,
  `DacChannel` A/B) with a wiring-only `dac.output.config`; the three
  ops artifacts already carry the levels (20, 40, 0).
- The tlayouts env lacks `gwsproto`; run the gens and tlayouts tests
  with `gridworks-scada/gw_spaceheat/venv/bin/python`.
- The gwsproto DFR twins (`DfrComponentGt`, `DfrConfig`,
  `dfr_component.py`) STAY: the seed keeps the words in the closure until
  `correct-house0.md` moves the gen. Retire the multiplexer actor, node
  and references per the blast-radius list, re-surveyed first.
- Spruce and honeysuckle move from 7.55 V to 7.6 V at their next boot
  after the fleet regen: the bench chip bytes now read as a code
  mismatch and the verify reprograms once. Expected.
- The OPS-392 scope comment predates the settled shape (it names a
  SimGp8403 and a separate DFRobot record); this spoke is the authority.

## Do this next

1. ✅ DONE (sema `9cdeec5`, 2026-09-12) the sema sitting:
   `zero.ten.power.on` and the ops-word lists, `dac.output.config`
   slimmed, `Gp8403` appended, the DFR words orphaned and out of the
   House0 union.
2. ✅ DONE (tlayouts `6d28e10` on `jm/spruce`) the snapshot regen,
   the seed keeping `dfr.component.gt`, the gens on `ZeroTenPowerOnList`
   (House0 20/40/0; Nolan spec in volts times ten, spruce and honeysuckle
   at 76), the `scada.krida` record's two GP8403 DAC entries; tlayouts
   tests and the spruce gen green; closure registry mirrored into the
   scada protocol package.
3. ✅ DONE (scada `f9d67f30` on `jm/spruce-unlimbo`) gwsproto twins
   (`ZeroTenPowerOn`, the ops lists and axioms, `DacOutputConfig` wiring
   only, `Gp8403`, `I2cDacVref` deleted), driver facts in
   `drivers/mcp4728.py` and `drivers/gp8403.py`, the outputer on
   `DAC_FACTS` and the ops power-on level, fixtures and tests; suite 526.
4. ✅ DONE (scada `17e277d3` on `jm/spruce-unlimbo`, 2026-09-12)
   fixture surgery on both House0 layouts, the GP8403 arm (`write_register`
   shared, `prepare_chip` sets the range once) and its wire-byte test,
   muxless sim DACs (`SimI2c.muxless_dacs`), the blast-radius list
   re-surveyed and retired, per-output resolution on both House0
   fixtures, the sim pair driving its DACs through the real bus actor,
   each output reporting `ActuatorsReady`; suite green.
5. ✅ DONE (sema `8c21017`, tlayouts `44050b1`, scada `e6d5b39b`) axiom
   10's ComponentId clause c and House0's ComponentBinding as axiom 15
   (`layout-word-axioms.md` items 6 and 7a); the binding test un-skipped,
   the real House0 fixture given its web-server node (the one orphan
   component left after the krida retirement).
6. Witness (below; rung set up 2026-09-12, dev run and both soaks
   done, beech pulled), then the close-down on the krida pattern.

## Witness, gate, definition of done

- **Witness:** `experiments/2026-09-12-beech-dist-010v-sweep/` (set
  up 2026-09-12, beech not yet run): a `dist-010v` sweep on beech in a window
  scada on the krida witness rig, the zone1-down heat call in front so
  the dist pump runs, `dist_sweep.py` on the box; dist flow and the
  reported `VoltsTimesTen` channel at each step, the deployed scada
  back as before. No power cycle: the GP8403 stores nothing. The
  window pair carries beech's deployed power-on levels (dist 35,
  primary 62, store 65 volts times ten, read off the box), not the
  fixture's; beech's own artifacts get them when its layout is
  regenerated on the new shape.
- **Gate:** suite green on both House0 fixtures and Nolan; `sema
  validate` on the hand-patched pair; EDD bar before the fleet regen
  uses any of it. Real House0 boxes stay on their deployed artifacts
  until the coordinated dev-wave regen.
- **Done:** one component word and one actor arm for every 0-10V
  output in both families, power-on levels in the ops words, the
  multiplexer and the DFR words gone, the beech witness Verified.

## Findings

Surfaced by the 2026-09-13 mypy sweep and the residue read; each is a
small fix with a test, or a decision to leave it.

- `scada.py:119,121` read `is_simulated` and `scada.py:1043` reads
  `validation_state` off `AppInterface`, which declares neither; the
  concrete app has them. Either the interface gains them or the reads
  narrow to the concrete type.
- `ltn.py` calls `self.send_threadsafe`, which `Ltn` does not have.
- `derived_generator.py:843` (`evaluate_strategy`): the buffer's usable
  energy in kWh is compared against the required-energy channel in Wh,
  so the "consider all tanks" advisory fires a thousand times too
  readily. Same on `dev`, in the field for the season. Advisory only.
