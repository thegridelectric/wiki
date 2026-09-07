# DAC output actuator (spoke)

Status: Draft · Pass 0 · Updated 2026-09-05 · Linear: OPS-392

> What this is: the 0-10V output on the gw108 becomes an actuator on the
> relay pattern — one node, one board-resident component, one leaf in the
> command tree — replacing the chip-level `I2cDacWriter`, which holds
> EEPROM defaults but takes no command. Decided 2026-09-02 with Jessica;
> lands BEFORE the command-tree matrix, because the tree cannot be tested
> with an actuator missing from it.

## What exists today

- `actors/i2c_dac_writer.py`: one actor per MCP4728, resolved from the
  layout (component `DacName` → board record DAC → address, mux). Boot
  EEPROM verify against the four declared PowerOn values, 60 s Multi-Write
  heartbeat. No dispatch surface. Bench-verified on honeysuckle
  (`experiments/2026-08-12-dac-bus-bench/`): mux select, Multi-Write, bare
  EEPROM read, both verify paths, all through `I2cBus`.
- The runtime write path has never been exercised: spruce's secondary
  pump runs at the EEPROM power-on speed (`experiments/2026-08-12-
  spruce-witness-window/README.md`, "the DAC write path was not
  exercised"). Relays, by contrast, are witnessed end to end on spruce.
- Nolan fixture: `gw108-dac2-writer` (I2cDacWriter, no handle) and no
  `secondary-010v` node. House0 fixture: `dist-010v` / `primary-010v` /
  `store-010v` as ZeroTenOutputer leaves with no component, bound to the
  DFR multiplexer node through `dfr.config.ChannelName`.

## The shape (mirror relay)

- **Node** `secondary-010v`, ActorClass `ZeroTenOutputer`, handle under
  the boss (`auto.lc.n.secondary-010v`), ComponentId set. Reuse the
  existing class: as with `Relay`, the component type selects the
  mechanism (DFR through the multiplexer on House0; board DAC through
  `I2cBus` on Nolan).
- **Component** `i2c.dac.output.component.gt` (new word, relay analog):
  `BoardComponentId`, `DacName` + `DacChannel` resolved against the board
  record, one `dac.output.config` (new word) carrying `ChannelName`,
  `ActorName`, `PowerOnRawValue`, `PowerOnVref`, `PowerOnGain`. One
  channel per component; unwired channels have no component and their
  EEPROM is never touched (preferred — same as an unwired relay position).
- **Channel** `secondary-010v` DataChannel (VoltsTimesTen, AboutNode the
  output node, CapturedBy the output node) so the commanded level reports.
- **Command**: `AnalogDispatch` from the boss, the message House0's
  ZeroTenOutputer already takes.
- **Actor**: the writer's bus plumbing (`_bus_op`, `_muxed_op`,
  `_write_channel`, the settle-time verify) moves into the output actor
  scoped to its one channel; dispatch sets the target and Multi-Writes it;
  heartbeat re-asserts the LAST COMMANDED value, power-on only until the
  first command.
- **Retired**: `gw108-dac2-writer` node, `i2c.dac.writer.component.gt`,
  `i2c.dac.channel.config`, `sim.dac.writer.component.gt` (all staging —
  orphan in place, `replaced_by` the new words), `actors/i2c_dac_writer.py`.
- **Sim**: `sim.dac.output.component.gt` for the sim pair, riding
  `SimMcp4728` (busy-window model kept).

## Work plan (each its own commit)

1. Sema words (word-gate ritual per word) + gwsproto mirrors + rejecting
   tests; snapshot regen for tlayouts.
2. tlayouts: `emit_dac_output` replaces `emit_dac_writer` in the Nolan
   gen (config axis: list of (channel, name, power-on) — spruce declares
   only C); honeysuckle + spruce + spruce-sim regen; Nolan fixture regen.
3. Actor rebuilt from the writer; `test_i2c_dac_writer.py` becomes
   `test_zero_ten_outputer.py` on the sim chip (boot verify, dispatch →
   Multi-Write, heartbeat re-assert of the commanded value).
4. **Bench rung on honeysuckle** (EDD): boot verify, one dispatched
   level change read back from the chip, heartbeat holds it. Run 4,
   2026-09-05 late on `ba2c9883`: **PASS on the real MCP4728** (verify
   clean, code 2200 read back 88 s after the dispatch, EEPROM 3020
   untouched). Runs 1-3 had exercised `SimI2c` under the old
   `is_simulated` backend selection. `experiments/2026-09-05-dac-output-
   bench/` "Found", run 4. Unwitnessed: the admin release (the run's
   timeout ended first).
5. **Spruce window**: the real pump, iso valve open and secondary pump
   on, the output swept linearly and in jumps for the speed-versus-
   output curve, with the summer hack and the deployed scada stopped
   and the isolation checklist below satisfied. Folder + on-box driver
   built 2026-09-06 (`experiments/2026-09-06-spruce-pump-speed-sweep/`),
   rehearsed on the sim Nolan scada; the artifact boot-blocker found
   that day is fixed (below). **Ran 2026-09-06:** run 1 PASS on the
   real pump (curve in the experiment README "Found"); run 2 PASS with
   no flow, the secondary BTU pico flatlined under a dormant cycler
   (`pico-cycler-command.md` "Field evidence"); run 3 queued. Then
   `pico-cycler-command.md`, then the command-tree matrix
   (`sh-node-actor-partition.md`).

## Failures found on the bench (2026-09-05) — test first, then retry

The honeysuckle rung (`experiments/2026-09-05-dac-output-bench/`)
surfaced five items. Each got a local test on the Nolan sim fixture
(`tests/config/gw.nolan.*`) before any fix. Status after the 2026-09-05
test-first pass:

1. **The admin link cannot read a Nolan layout.** OPEN, blocked on the
   word. `Scada.control_capabilities` reads
   `self.layout.node(H0N.relay_multiplexer).component.gt`, and
   `scada.control.capabilities/001` REQUIRES that Krida component, so no
   Nolan layout can emit a valid instance and the admin TUI never gets
   its capabilities. Failing test: `tests/actors/test_admin_on_nolan.py::
   test_control_capabilities_on_nolan`. The word edit (staging, in place)
   and the package changes are written up in `admin-for-nolan.md` "What
   the admin tool needs from a scada"; both wait on Jessica.
2. **A forwarded AnalogDispatch never reaches `ZeroTenOutputer`.** NOT A
   ROUTING FAILURE. `tests/actors/test_admin_on_nolan.py::
   test_admin_analog_dispatch_reaches_outputer` runs the admin client's
   wire shape against a live Nolan scada: admin wakes, the tree rewrites,
   the outputer takes the level and reports it on the channel. On the
   bench the dispatch went through too, to the SIM chip: boot 2's log
   opens with `[scada] SIMULATED` (line 3 after the settings dump), so
   `I2cBus` ran `SimI2c` and the real MCP4728 was never addressed. The
   success path was silent; the outputer now logs an accepted dispatch.
   The `_send_to` final `else` is the legitimate path for actors on the
   LAN (scada2's), not a silent drop, so no `raise` is added there.
3. **`verify_eeprom` reprograms every boot on bytes that match.** SAME
   CAUSE. `test_zero_ten_outputer.py::test_verify_accepts_the_bench_chip_read`
   feeds the verify the 24 bytes from `chip-2026-09-05.txt` and it
   reports no mismatch; the sim chip's EEPROM starts at zero, so every
   sim boot reprograms. The reprogram glitch now names the (code, vref,
   gain) read against the layout's.
4. **Admin link password key.** FIXED in gwproactor (branch
   `jm/connack-reason-code`, commit pending; tag `v4.1.13+jm2` and the
   scada pin bump follow). paho calls `on_connect` on every CONNACK,
   refusals included; the wrapper queued a connect message without
   reading the reason code, so the link moved to
   `awaiting_setup_and_peer`, emitted a `mqtt.connect` event and
   subscribed on a socket the broker was closing. Now a refusal rides
   the existing `connecting -- mqtt_connect_failed --> connecting`
   edge, logged with its reason, and the socket close after a refusal
   is not a disconnect. **Verified against a real broker 2026-09-05:**
   a private mosquitto with a password file on `127.0.0.1:18899`
   (`allow_anonymous false`; the shared test broker on 1883 accepts any
   password), the local scada on `tests/config/gw.nolan.layout.json`
   with `SCADA_ADMIN__PORT/USERNAME/PASSWORD` overridden on the command
   line, the scada venv importing the sibling proactor checkout
   (editable). Wrong password: `admin:  connecting -- mqtt_connect_failed
   --> connecting  CONNACK refused: Not authorized (rc 135)` at 1, 2, 4,
   8, 16 s (paho's reconnect delay; 135 is paho's v5 mapping of CONNACK
   5), mosquitto logging `disconnected, not authorised` each time, no
   connect line. Right password: `mqtt_connected -->
   awaiting_setup_and_peer` then `mqtt_suback --> awaiting_peer` on the
   first attempt. Unit reproducer:
   `gridworks-proactor/tests/test_proactor/test_comm/test_connect_refused.py`.
   **The admin panel has the same flaw on its own side:**
   `gwadmin/watch/clients/constrained_mqtt_client.py` `_on_connect`
   ignores `_rc`; run against the same broker with a wrong password,
   `gwa watch -vv` logged `MQTTClient: connecting -> subscribing` while
   mosquitto refused it every cycle, and never named the cause. Fix
   with the gridworks-admin package changes (item 5).
5. **The admin tool itself assumes House0.** Research done, see
   `admin-for-nolan.md`; package changes wait on item 1's word.

**Why the bench was simulated, and what changed.** Until 2026-09-05 the
backend choice rode `ScadaAppInterface.is_simulated`, which is true
unless the box holds a TaDeed AND the layout has no sim component.
Honeysuckle has no `tadeed.json`, and its layout from
`honeysuckle_sema_gen.py` carries two `sim.pico.tank.module.component.gt`
(Buffer, Tank1; the bench has no picos, and the layout's axioms require
the channels they capture), so `I2cBus` ran `SimI2c` and the MCP4728 was
never addressed. Run 3 (2026-09-05 evening, scada `0f1ff7be`) confirmed
the dispatch leg on the box under that condition: the admin dispatch
reached `ZeroTenOutputer` (`Dispatch from admin: volts x10 55 -> code
2200`), so item 2 holds on real hardware routing, only the chip write
went to the fake. The fix is the rule now in `executor/components.md`
"Hardware backend selection is the layout's job": board-resident actors
take real or fake from the board record's DeviceType, and honeysuckle's
record is a real `Gw108RevB`. The derived bit keeps its system-level
meaning (no deed, not a real terminal asset) and no longer touches the
bus. The runbook's step 8 check for `SIMULATED` still reports that
system-level state; the chip-reached check is the DAC read-back itself.
**Blocker found and fixed 2026-09-06, rehearsing the window harness on
the laptop:** the regenerated spruce pair did not boot on the branch.
`DerivedGenerator` refuses the four affine depth channels because their
`linear.one.dimensional.calibration` carries Version `001` while
gwsproto pins `000`. tlayouts hand-builds that calibration as a dict
literal (`src/tlayouts/house0_sema_gen.py:1578`, shared by the Nolan
gen) with the version sema squashed into 000 on 2026-08-13. Nothing
catches it: `derived.channel.gt/002` types `Parameters` as a bare
object and declares no dependency on the calibration word, so the
word is outside the layout closure and the reverse conformance test
never sees it, the tlayouts snapshot validates the artifact with the
same blind spot, and the Nolan test fixture has no affine channels so
the suite's artifact-boot test is blind too. The gwsproto mirror's
docstring still names `/001` above its `000` Literal. Agreed
2026-09-06: no sema change (the published word keeps its bare-object
`Parameters`); tlayouts seeds the calibration word into its snapshot
and builds the calibration through the snapshot class, so the word
rides the closure copy and the standing scada conformance check covers
it; the sim pair carries its real twin's calibration so the Nolan
fixture boots four affine channels in the suite. Built the same day
(scada + tlayouts commits pending).

**Do this next:** move the dispatch sender onto the box. Run 4's first
dispatch was refused because the laptop's ssh tunnel had died silently;
a spruce window (a validated real system) must not depend on a tunnel.
`bench_dispatch.py` stays in the experiment folder and runs on the pi
from the box's `~/experiments` clone at a pushed SHA (experiments README
"Conventions": the one thing a pi keeps), against `localhost:1883`; the
runbook drops its tunnel step. Then one short
bench boot that witnesses the admin release before the timeout. Then
step 5, the spruce pump-speed window
(`experiments/2026-09-06-spruce-pump-speed-sweep/`).

The eGauge component booted against the real meter with no errors,
and the isolation held, so neither needs a test.

## Isolation checklist for the spruce window (staging words off prod)

Three layers keep staging vocabulary off the production broker; a
window must hold all three.

1. **Status tier with teeth.** The layout cluster is `staging`, which
   means dev brokers only (OPS-445). The check is by hand today: every
   gwsproto schema pin and every word in the closure copy
   (`sema_closure/registry.yaml`) against the sema registry's status;
   `gwsproto_sema_conformance.py` has no release-gate flag. On
   2026-09-06 the branch pins 95 non-published words (74 layout-closure
   words in five dependency layers plus 21 wire words, `layout.lite/013`
   among them, and `report.event/004` still draft) and 52 gwsproto
   names with no sema word at all. Red by design; the branch cannot
   deploy beyond dev until the words promote.
2. **Credential-structural isolation.** The window scada keeps the real
   spruce identity but boots from `~/envs/dev.env`: dev-broker
   credentials only, upstream host the localhost tunnel
   (`ssh -f -N -R 1885:localhost:1885 spruce`), never `hw1` creds. The
   staging-typed payloads (snapshots, layout.lite) physically cannot
   reach the prod broker. The universe guardrail would refuse an hw1
   identity on localhost at a real boot; the harness runs inside its
   test-boot exemption.
3. **Paths-structural isolation.** Boot through the window harness
   (`WindowScadaApp`, `experiments/2026-08-10-ads-declared-rate/
   window_boot.py`): its `paths_name()` override is the ONLY paths-root
   override that survives app construction, and it refuses to boot if
   event or log dirs resolve outside `~/.config/gridworks/
   scada-experiment/`. Env-only overrides (`SCADA_PATHS__NAME`) are
   silently discarded. This is the layer that keeps the window's
   un-acked events out of the deployed scada's persister (next bullets).

Window protocol on top of the three layers:

- Stop everything on the bus: `gwspaceheat-restart.timer`,
  `gwspaceheat`, `spruce-summer-hack` (hack exits to failsafe; the
  transient timer restores both).
- **Before restarting the deployed scada:** the persister replays every
  un-acked event in its event dir to whatever broker it connects to
  (`start_reupload` on link-up). With the experiment paths root
  separated, the window's events sit under `scada-experiment/` and the
  deployed scada never sees them; still verify the deployed event dir
  (`~/.local/share/gridworks/scada/event/`) holds nothing window-born
  before restart, and archive-then-delete anything that is. The 08-12
  window #1 leak happened exactly here: shared paths root, one shutdown
  event rode the deployed scada's startup reupload to prod and S3.
- Stopping services, placing env files and restarting are JM's to run;
  the session preps commands and the watch-list.

## Decided 2026-09-04

- **The House0 010v nodes migrate to per-output components with the
  krida shift, not now.** Two 0-10V mechanisms exist and only the gw108
  one has code: the DFR modules are driven through the
  `zero-ten-multiplexer` node holding one `dfr.component.gt` with all
  three outputs in its ConfigList. Per-output components there need the
  outputer to resolve its own module and the multiplexer actor retired,
  the same shape as the relay side, so the per-output word (vendor-free
  name, `zero.ten.output.component.gt` proposed, linking field
  `ModuleComponentId`), the parent rename off the vendor name, the
  fixture surgery, House0 axiom 10's ComponentId clause and House0's
  ComponentBinding all land in the krida shift together. Not needed for
  the matrix: House0's shape already puts the nodes in the tree.
- **`i2c.dac.output.component.gt` keeps its ConfigList.** The rule is
  canonized in `executor/components.md` "The config list — when a
  component carries one": a list stays if and only if the device has
  core configuration beyond its binding, and the DAC output has it
  (channel, power-on code, reference, gain), as the relay does.
- `AnalogDispatch.Value` is volts times ten, 0 to 100 (landed with the
  actor, scada `341c99de`).
