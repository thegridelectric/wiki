# DAC output actuator (spoke)

Status: Draft · Pass 0 · Updated 2026-09-02 · Linear: OPS-392

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
   level change read back from the chip, heartbeat holds it. Reproducer
   folder under `experiments/`, logbook line.
5. **Spruce window**: same witness on the real pump, with the summer
   hack and the deployed scada stopped and the isolation checklist below
   satisfied. Then the command-tree matrix (`sh-node-actor-partition.md`).

## Isolation checklist for the spruce window (staging words off prod)

Three layers keep staging vocabulary off the production broker; a
window must hold all three.

1. **Status tier with teeth.** The layout cluster is `staging`, which
   means dev brokers only (OPS-445). Scada checks itself with
   `packages/gridworks-scada-protocol/gwsproto_sema_conformance.py
   --release-gate`: any gwsproto pin whose sema status is not
   `published` fails the exit code. Red on `jm/spruce-unlimbo` by
   design; the branch cannot deploy beyond dev until the words promote.
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

## Open

- Whether the House0 010v nodes migrate to per-output components (DFR
  analog of the new word) now or with the krida retirement. Not needed
  for the matrix: House0's shape already puts them in the tree.
- `AnalogDispatch` semantics for the output actor: percent vs raw code;
  the sema word for it is unverified — check before step 3.
