# Elm on the Arctic heat pump

Status: Accepted · Pass 1 · Updated 2026-10-27 · Linear: OPS-628

**EDD: yes** the verification is elm heating its buffer from the Arctic
unit under scada command on the production broker: the call relay across
CN33 starts and stops the unit, the secondary pump runs whenever the call
is closed, and the journal shows hp power, buffer temperatures and the
pump relay state agreeing. The local tests (hp-boss on a sieg-less House0
sim layout, the new layout word's axioms) are the reproducer, not the
proof.

> What this is: the plan for bringing elm back as the first House0 home
> with a heat exchanger and an Arctic R32 high-temperature heat pump,
> on the scada line now on `main`. Four build steps (a sieg-less House0
> layout word, the secondary-pump name in the shared vocabulary, an
> Arctic traits row so hp-boss runs the secondary pump from sensing,
> the elm layout itself) and
> the field notes for the dry-contact wiring and the wired controller.
> Modbus control of the unit is later work and is not in scope.

## Do this next

**▶ Do this next.** Elm runs on scada `main` (`f0fa7e3a`) with the
committed tlayouts pair (`1a2a44f`) since 2026-10-28 04:52 ET; the LTN
and elm2 are at `3abba580` and want the same pull. The first night
under local control: seven call cycles, four ended BufferFull, the
compressor follows the call by 66 to 69 s and stops 59 to 71 s after
it opens, `secondary-pump-running` answers each relay change within
3 s, and `gw.scada.commit` reaches the journal DB on every boot. One
fault: from 04:15 to 04:30 the scada crashed eight times in a row
because DistPumpDoctor sent its AnalogDispatch to the scada instead of
`dist-010v` (fixed in `f0fa7e3a`, PR #590); the doctor's dispatch still
names the wrong FromHandle, which drew a `bad_sender` glitch on the fix
branch, and the dist-flow startup limit (50 s) against elm's observed
60 s is open. **Next: step 7's harness on the journal window
2026-10-27 22:49 to 2026-10-28 07:00**, so the pass criteria are a
re-runnable verdict and not a one-off read; then energy metering.
Seen and not yet acted on: `secondary-pump-running` flickers 1, 0, 1
inside 2 s on some pump starts (startup power dips to 1 W against the
5 W threshold; wants persistence); every boot hp-boss closes the pump
pair for about 2 s before hp-watch's first report; the 04:54 call took
6 min to start (a minimum-off timer on the Arctic is the guess); the
persisted contract heartbeat is `001` against `002`, so each boot
starts with no contract; the picos' `code-update` posts draw seven
`unserved-post` warnings per boot.

## The plant at elm

- Four zones (living-kitchen, bedrooms, garage, master-bedrm), a buffer
  and three store tanks on pico tank modules, three hall flow picos on
  soldered breadboards (dist, store, primary), a Hubitat, an eGauge, two
  Krida relay boards and two DFRobot DACs. No Siegenthaler loop; no BTU
  meters.
- New this fall: a plate heat exchanger between the Arctic unit and the
  house, so the house side has a **secondary pump**. The Arctic unit has
  its own 240 VAC circulating-pump output (field terminals 3 and 4), so
  the **primary pump** (unit side of the exchanger) can be the unit's to
  run. That is the reason the primary-pump relays leave the layout.
- The Arctic MAHRW030ZA R32 high-temperature monobloc, controlled today
  through its dry-contact enable and its wired controller. Both
  compressors are outdoors in the monobloc: there is no indoor unit and
  no indoor control box, so the layout has no `hp-idu` node and no
  `hp-idu-pwr` channel, and the no.sieg word names neither (a home with
  a secondary surface has a heat exchanger and one unit beyond it).
  Register map
  and later Modbus plan: `heat-pumps/arctic-high-temp/arctic-high-temp-modbus.md`.

## Step 1: the layout word `gw.house0.no.sieg`

A House0 home with no Siegenthaler loop. Fir and oak are also sieg-less
and are authored today as House0 with a fake sieg surface (a sieg BTU on
a pico that does not exist, disabled with its channels); they move to
this word once elm runs on it.

- Registered at 000 as `staging`, a copy of `gw.house0.layout` 000 with
  the id, title, TypeName const, description and registry summary
  changed. Dependencies identical. Axioms renumbered from 1.
- The sieg surface is gone from the word: no `sieg-loop` command node
  and no node with ActorClass SiegLoop, no SiegManifoldChannels axiom,
  no `hp-loop-on-off-relay` or `hp-loop-keep-send-relay` in
  RequiredActuators or in the handle axiom, and `PrimaryFlowSource` is
  "Measured" (the DerivedSiegSum value has nothing to sum). The word
  stops requiring and mentioning the sieg surface; it does not forbid
  it. Every other axiom keeps the House0 wording verbatim.
- RequiredActuators names "secondary-pump-relay" with ActorClass "Relay",
  and the handle axiom puts it under hp-boss, the way `gw.nolan.layout`
  axiom 5 and axiom 30 do.
- RequiredSensing adds the house side of the exchanger in Nolan's names:
  `secondary-flow`, `secondary-lwt`, `secondary-ewt` (one pico BTU meter,
  `secondary-btu`, as at spruce) and `secondary-pump-pwr`.
- A `SecondaryPumpRunningChannel` axiom requires exactly one
  DerivedChannel `secondary-pump-running`, Strategy `circulator-running`, input
  `["secondary-pump-pwr"]`, Unitless, with `Parameters.ThresholdW`: 1
  while the pump draws more than the threshold, 0 otherwise. It is the
  pump's heat-call: the signal hp-boss reads to know the pump answered
  the relay. The BTU pico's CT (`secondary-pump-ct`) joins as a second
  input once a CT reads correctly on a BTU meter.
- Downstream of the word: the scada's `sema_seed_request.yaml` names it,
  the snapshot is regenerated, a hand-written twin `House0NoSiegLayout`
  mirrors every axiom as `check_axiom_<n>`, the conformance sweep and
  `tests/named_types/test_gw_house0_no_sieg.py` check it (the coverage
  test finds a word's tests by `test_<type_name>_axiom_<n>`, so the file
  and test names follow the TypeName), and the loader pairs the word
  with House0FamilyParams. The test fixture is the hazel sim pair,
  generated by tlayouts `hazel_sim_gen.py` from the orange skeleton in
  elm's shape (no loop, heat pump owns the primary pump, secondary pump
  relay on krida 11, a sim secondary BTU, the eGauge channel surface on
  the sim meter). `has_sieg_loop` on the House0 generator picks the
  word; every gen declares it.
- The runtime layout keeps `is_house0` meaning exactly `gw.house0.layout`
  and adds `is_house0_no_sieg`. Only the relay accessors read either
  flag: the ones elm has (vdc, store pump, tstat-common, hp-failsafe,
  aquastat-ctrl) take both words; the sieg and primary-pump accessors
  stay House0-only. Local control, leaf ally and the state machines
  choose by "is it Nolan", so elm takes the House0 code with no change,
  and the flag is the hook if elm later wants its own.

## Step 2: `secondary-pump-relay` is a shared name

Today `secondary_pump_relay` is on `NolanNodeNames`, and the layout
accessors `has_secondary_pump` and `secondary_pump_relay` in
`hydronic_layout.py` look it up there and refuse a non-Nolan plant. The
pump is a property of a plant with a heat exchanger, not of the Nolan
family, so:

- the constant moves to `HydronicSpaceheatNodeNames`, beside
  `secondary_pump`, and every reader (hp-boss, the nolan twin, the tests
  under `tests/actors/` and `tests/test_misc/`) reads it there;
- `secondary_pump_relay` on the layout drops its `is_nolan` guard and
  returns the node wherever the layout has one;
- `secondary-010v` stays Nolan: elm's secondary pump has no 0-10 V
  speed input in this plan.

## Step 3: hp-boss runs the secondary pump from hp-watch sensing

hp-boss already owns the secondary pump wherever the layout has one, and
runs it from hp-watch sensing: on while the unit is sensed running or
unknown, off while sensed off. Elm runs the pump the same way as spruce.

- The Arctic unit gets an `HP_TRAITS` row in `sensing.py`: on above
  700 W, off below 400 W. The call-open lead is 120 s, the Samsung
  value, until the unit's stop lag is measured.
- The row is keyed by the hp-odu component's DeviceType:
  `ArcticMAHRW030ZA`, in sema's `gw1.device.type` enum (sema `jm/arctic`)
  and to be added to the scada's `DeviceType` twin; elm's `hp-odu`
  component names it (step 4).
- Elm's layout gets an hp-watch node, as spruce has.
- Measured 2026-10-26, three runs on the eGauge `hp-odu-pwr` (300 W
  capture delta): standby 0 to 22 W; the first running sample 1131 to
  2675 W, so both crossings pass the 400 to 700 W band within one
  second; steady state 4.2 to 5.8 kW; start about 65 s after the call
  closes, power below 400 W about 52 s after it opens; no defrost seen.
  Two caveats: the eGauge emits single-sample saturation glitches (odu
  32767 with idu mirrored negative), so sensing should want persistence
  above the on line, and minimum modulation in mild weather is unseen,
  so 700 W is unverified at low load.
- Test: `tests/actors/test_hp_boss.py` runs the existing sensing cases
  on the sieg-less sim layout as well as the Nolan fixture.
- The derived generator gains the `circulator-running` strategy beside
  `heat-call`: one power input, `Parameters.ThresholdW`, emits 1 or 0
  on change and on the period. Test beside the heat-call ones. The
  name says circulator so it is never read as the heat pump; axiom 38
  of the word names it (sema `jm/arctic`).

## Step 4: the elm layout

On tlayouts `main` (the sema-word generators), `elm_gen.py`:

- `TypeName` becomes `gw.house0.no.sieg`; the fake sieg surface (the
  sieg BTU on a pico that does not exist, its channels, the sieg-loop
  node and its two relays) leaves.
- The `hp-idu` node and its `hp-idu-pwr` eGauge channel leave: the
  monobloc has no indoor unit.
- The primary-pump relays (Krida positions 11 and 12, "Primary Pump
  SCADA Ops" and "Primary Pump Failsafe") leave; `primary_pump_owner`
  becomes HeatPump, which the generator already supports.
- A `secondary-pump-relay` node (ActorClass Relay, handle
  `auto.hp-boss.secondary-pump-relay`) on the Krida position the
  primary-pump ops relay held, normally open, with its relay-state
  channel, wired to the secondary pump's contactor.
- hp-scada-ops-relay (Krida 6) is the call: its dry contact goes across
  the Arctic unit's CN33. The hp-failsafe relay (Krida 5, double throw)
  keeps its role of choosing between the scada's contact and the
  aquastat path; what the aquastat path means with the Arctic is a field
  question below.
- `hp-odu` names the Arctic DeviceType, and the layout has an hp-watch
  node, so hp-boss finds the unit's `HP_TRAITS` row at load.
- The hall pico the legacy layout calls `primary-flow` (pico_3e9a28) is
  `secondary-flow`, renamed on the pico itself through the starter-scripts
  API (its `ActorNameByHwUid` map; the scada's own params reply can only
  confirm a name). `hp-lwt` and `hp-ewt` keep ADS terminals 3 and 4,
  live: the thermistors are wired and reading air today, and go back on
  the unit's leaving and entering pipes (George, through Paul,
  2026-10-27). `secondary-lwt` and `secondary-ewt` are ADS terminals 9
  and 10, disabled until their thermistors are wired. `secondary-pump-pwr` is eGauge register 9008
  (the one `hp-idu-pwr` held) with a CT going on; `secondary-pump-running`
  reads it at 20 W. The DAC output on Dfr1 B that drives the house-side
  pump at 3.5 V is `secondary-010v` (the Nolan name, until the shared
  vocabulary has one; axiom 30 forbids `primary-010v` on a unit-owned
  pump).
- The primary flow is measured: the hall pico the legacy layout called
  `store-flow` (pico_5a5127) is on the unit's loop as `primary-flow`.
  The store flow is unmeasured: `store-flow` sits on a hall pico that
  does not exist, disabled with its channels. `primary-pump-pwr` keeps
  register 9002, disabled, until a CT is on the unit's pump conductor.
- The layout is deployed by `scripts/roll.sh`, from the committed
  tlayouts JSON (`output/elm/gw.house0.no.sieg.json` and
  `gw.house0.no.sieg.operational.params.json`), as for every house.

## Step 5: relay 12 stands in for the unwired primary-pump failsafe

At elm Krida 11 is the secondary pump's relay, but the pump's feed still
goes through the contacts of Krida 12, the House0 primary-pump failsafe
(a double-throw relay: de-energized on its heat-pump side, energized on
its scada side). Paul and George have not wired 12 out yet. With 12
de-energized, closing 11 reaches nothing; with 12 energized, 11 runs the
pump. Until the rewire, the scada energizes 12 whenever it closes 11.

- The node is `secondary-pump-hack-relay`, a normally-open relay on
  Krida 12 under hp-boss, so hp-boss sends it the same `ChangeRelayState`
  events as the pump relay. The word "hack" marks it for removal.
- The word `gw.house0.no.sieg` (staging, edited in place) requires it:
  axiom 9a lists it with the plant relays and axiom 32 gives it the
  handle `auto.hp-boss.secondary-pump-hack-relay`. No new axiom. The
  scada's snapshot is regenerated and the twin's `check_axiom_9` and
  `check_axiom_32` follow, with their tests.
- tlayouts: a third no.sieg axis beside `secondary_pump_relay_idx`,
  `secondary_pump_hack_relay_idx` (12 at elm), checked with the other
  two and emitted under hp-boss. Hazel sim and elm regenerate;
  `test_elm_no_sieg.py` asserts the node on Relay12 under hp-boss.
- Scada: `hydronic_layout.py` gains `secondary_pump_hack_relay`, guarded
  by `is_house0_no_sieg`, and `fixed_subtrees` puts it under hp-boss on
  that word alone; Nolan keeps two hp-boss relays. hp-boss's
  `enforce_pump` sends the hack relay the same open or close as the
  pump, each under its own minted id, and its full report goes to the
  scada as the pump's does.
- Tests: on the hazel layout the hack relay is commanded iff the pump
  is, through hp-watch on, off and unknown; the command-tree tests
  (`test_command_tree_prefix_closed`, `test_local_control_tree_by_top_state`,
  `test_admin_row_order`) learn hp-boss's third relay on no.sieg.
- Leaves when 12 is wired out: the node, the axis, the two axiom lines,
  the layout property, in one change.

## Step 6: the layout word and the operational params stay on the box

Elm runs a staging word on the production broker. The scada reads
`gw.house0.no.sieg` and `gw.operational.params` from its config folder
and sends neither to the broker: on the broker it describes itself with
`layout.lite` alone, as every house does. Nothing in steps 1 to 5 adds a
message, report or snapshot field that embeds either word, and the
harness in step 7 reads the journal and the broker without asking a
scada for its layout. The rule is in the scada protocol file; it holds
until the words are published, when the scada sends the published word
and `layout.lite` retires.

## Step 7: the field detection harness

The verification is elm on `main`, watched. One experiments folder,
`experiments/future/elm-arctic-field-check/` (moved to its run date on
the first run), with a README stating the pass criteria and a harness
that reads them off the journal DB (`DB_ANALYST_URL`) for a window, so
that each check is a verdict line, not a transcript:

- hp-boss state transitions and the call relay (`hp-scada-ops-relay`)
  state agree, every command acked.
- `secondary-pump-relay` and `secondary-pump-hack-relay` change state
  together, and `secondary-pump-running` goes to 1 within a bound after
  both close and to 0 after they open: the pump actually runs.
- `hp-watch` goes on after `hp-odu-pwr` crosses 700 W and off after it
  drops below 400 W, with the pump following the watch, not the call.
- Buffer temperatures rise while the unit runs; `hp-lwt` and `hp-ewt`
  agree with the direction of heat.
- No glitch or problem event from elm in the window that the run does
  not explain.

The harness is the reproducer the design's `EDD: yes` names; the
README records each run (date, window, verdict). A failing check gets
its local test first, per the field-bug rule.

## Field notes: the dry contact and the wired controller

What the manual (Rev 2, in `heat-pumps/arctic-high-temp/`) and Arctic
support say, and what we still have to find out on the unit.

- **CN33** on the on/off board is the remote on/off input. Dry contact:
  the unit will not run while it is open and runs within its own
  settings while it is closed (Arctic support, 2026-08-20). The "add
  240 VAC relay to convert to dry contact" note on the wiring page is
  terminals 1 and 2, the unit's backup-heater call output, not an input.
- **Controller on/off.** The controller has its own on/off (long press,
  then OK). Our reading of "runs within its own settings when closed" is
  that CN33 enables a unit the controller has turned on, so the
  controller is left ON and never used to stop the unit. Confirm on the
  bench: with the controller OFF, does closing CN33 start it?
- **Power loss.** Whether the unit comes back ON at the controller after
  a power cut, or back in standby, decides whether a breaker trip at elm
  needs a visit. Test it once by pulling the disconnect.
- **Heating setting temp** (user parameter, factory 47 °C) is the target
  the unit holds while enabled, with **heating system hysteresis**
  (factory 5 °C) as the band below it. Set the target to what the store
  wants (the modbus notes argue for 75 to 80 °C water with the unit
  rated at 75 °C outlet). The target is capped by **max water
  temperature**, installer parameter 17, factory 55 °C: raise that first
  to what the store and pipework are rated for, then the setting.
- **Which sensor the band acts on** (inlet or outlet) is not in the
  manual. Watch inlet and outlet on the controller's main screen against
  the compressor icon on the first runs.
- **Mode** stays Heating. The unit's own outdoor-reset curve mode is
  documented as unstable and we own the setpoint decision anyway.
- **Water pump working way** (user parameter, factory 2) and the pump
  interval and cumulative-run-time parameters govern the unit's own
  circulating-pump output. If the primary pump hangs off terminals 3 and
  4 these decide when it runs; the setting that runs the pump whenever
  the compressor runs and for the post-run period is the one we want.
  Read the parameter's values off the controller and record them here.
- **Timer** off, **Wi-Fi** app not needed; both can fight an external
  enable.
- **Electric backup** (terminals 5 and 6, 10 A) is not wired; the
  "eheat" start under user parameters stays untouched.
- **What elm's legacy layout is wired to (admin run, 2026-10-26 20:08
  to 20:15 ET).** Krida 11 (`primary-pump-scada-ops-relay11`) runs the
  exchanger's house-side pump: closing it took the flow meter named
  `primary-flow` from 0 to 580 GpmTimes100 within one second, so that
  meter is the secondary flow and step 4 names it so. `primary-010v`
  (3.5 V, unchanged all evening) is that pump's speed input and
  5.8 gpm is its flow at 3.5 V. `primary-pump-pwr` read -2 to -12 W
  while the pump ran: the CT is not on the pump's conductor, or is
  reversed. `hp-lwt` and `hp-ewt` read room temperature (17 to 25 °C
  over 2026-10-26 to 27, never following the plant's 76 °C), so they are
  wired to the ADS but not on the pipes. A 3 s call on
  relay6 did not start the unit (it needs about 65 s); `hp-odu-pwr` sat
  at 64 to 66 W, up from 16 W at 19:58 with no call, which looks like a
  crankcase heater or standby mode change and belongs in the traits
  measurement.
- **The failsafe path with relay8 at Boiler keeps the Arctic off.** In
  MonitorOnly (every relay de-energized, 2026-10-26 20:36) relay5 fell
  to BufferTankAquastat and relay8 to Boiler: the oil boiler started
  within a second and `hp-odu-pwr` stayed at 64 W. The aquastat question
  narrows to the other position of relay8: whether the aquastat's call
  reaches CN33 when relay8 is at HeatPump. Not yet observed.
- **Elm's mode is set by `SCADA_SYSTEM_MODE` in the box's .env**
  (`Standby` holds the heat pump and boiler off by energizing relay5
  and relay8 to Scada; `MonitorOnly` de-energizes everything and never
  actuates). `SCADA_MONITOR_ONLY` in the same file is an LTN setting the
  scada ignores. Set to `MonitorOnly` on 2026-10-26 20:36 for an
  overnight boiler charge of the buffer; not yet in the instance-README.
- **Modbus later**: RS-485 at 2400 baud, address by DIP switch SW2;
  register 2000 is on/off, 2003 the heating setpoint. The dry contact
  stays the enable even then, so a scada-side stop never depends on the
  bus.

## Open

- The async capture delta of a tank pico SHALL come from the
  operational word (decided 2026-10-28): the `capture.tuning` of the
  module's micro-volt channels, in microvolts, the pico's own unit.
  Today the scada answers a params post with the component's
  `AsyncCaptureDeltaMicroVolts` and only `CapturePeriodS` from the
  tuning (`api_tank_module.py:224`), so the word's delta is inert; the
  200 on the depth channels is a tlayouts default
  (`hardware/tank_module.py:78`) that nothing reads. The failing test is
  on scada `jm/pico-capture-delta`. The code that moves the setting
  into a pico is not designed yet; the firmware applies the delta it is
  answered with (`tank_module_3_main.py:354`, strictly greater, on
  1000-sample reads averaged 10 or 30 times). The default of 2000 µV
  lives in no word and no twin: in the tlayouts gens and, as 500 µV,
  in the firmware. The tank module's own noise floor is unmeasured; the
  ADS experiments (`experiments/2026-08-06-ads-noise`,
  `2026-08-10-ads-declared-rate`) measured the pi's ADS1115 only.
- The eGauge moves to the first pi in every house (decided 2026-10-28).
  The second pi was given the eGauge to spare the first pi's load; the
  load is not there (every box is a Pi 4B under 0.1 load average with
  the scada at 1 to 7 % CPU), and the hop through the second pi and the
  broker delays `hp-odu-pwr`, the signal hp-watch times the pumps from.
  Elm's `main` layout already reads the eGauge from the first pi; the
  other houses move as each takes its sema-word layout. The second pi
  keeps the Hubitat and the ADS board.
- TODO (next session): a table, from the journal DB, of every pump
  power channel in every house: the lowest power that is plainly "on",
  and what the jitter around zero looks like while the pump is off
  (`secondary-pump-pwr` at elm reads 10 to 15 W running and dips to 1 W
  at start; the `circulator-running` threshold and the eGauge capture
  deltas for the pumps come from this table, not from guesses).
- Energy metering at elm (2026-10-28): the eGauge reports power only
  today; the run wants watt-hours for the heat pump and the pumps so a
  cycle's electricity is a journal fact and not an integral over
  captured deltas.
- The scada should name a pico from the layout by HwUid: answer any
  flow-module params post, look the pico up by HwUid, and reply with the
  layout's node name. The layout is the authority on names, and the
  feature retires the starter-scripts `ActorNameByHwUid` map (the
  `UPDATE LAYOUT!!` hack in `api_flow_module.py` points the same way).
- The word should require that `secondary-pump-running` is not in
  DisabledChannelNames (and its input with it), the way axiom 6 guards
  the transactive channel: a layout that disables it leaves hp-boss
  running the pump open loop with nothing to say so. A sema wave on
  `jm/arctic` after elm runs.
- eGauge single-sample glitches, seen in elm's journal readings on
  2026-10-26: at 11:44:28 every eGauge channel saturated in one sample
  (`hp-odu-pwr` 32767, `hp-idu-pwr` -32768, `oil-boiler-pwr` 32767, the
  pumps about ±2550 W) and at 12:52:16 a smaller one (odu 1820, idu
  -1828, oil boiler 1826); each cleared on the next sample. Found by
  reading the raw `report.event` readings, not from any problem event or
  glitch the scada raised. A threshold read of a single sample would
  call the unit on. The fix is OPS-629: the power meter owns clean
  readings, with a 1.5 times nameplate bound on hp-watch.
- `hp-lwt` and `hp-ewt` go back on the unit's pipes (Paul); until then
  they read air. `primary-pump-pwr` reads near zero while primary flow
  runs: the primary-pump CT wants a field look.
- The aquastat path through hp-failsafe-relay: with the Arctic, is there
  an aquastat at all, or does the failsafe position simply leave CN33
  closed so the unit heats on its own setpoint when the scada is out?
- The Arctic device-type record in sema (`hp.device.type.gt`) and its
  `HP_TRAITS` row, after the start signature is measured. The unit has
  two compressors in one monobloc, so the signature has two steps and
  the record's `CompressorRatedAmps` is a nameplate total; no field on
  the record says monobloc or counts compressors, and none is added: the
  layout's `hp_parts` (odu alone) and the traits row state those facts.
- Whether elm's buffer tank calibration (`TankTempCalibration` on the
  buffer in the legacy generator) survives into the sema-word layout.
- TODO: a `circulator-running`-style derived channel for every "signal" power
  channel across all the layout words (the pumps, the elements, the
  heat pump itself as `hp-running`), each required by its word, so that
  on-or-off is a layout fact the actors read rather than a threshold in
  code. The CT inputs join when a BTU-meter CT reads correctly.
- Proposal: an `hp-running` channel on its own `hp-running` strategy
  (a sibling of `circulator-running`, since the heat pump's signature may need
  more than a threshold), input `hp-odu-pwr`, required by the layout
  words. hp-boss's hp-watch sensing does this job today in code, from
  `hp-odu-pwr` with a per-model `HP_TRAITS` row; as a derived channel it
  becomes a layout fact, and it is the slot the Arctic unit fills once
  its start, defrost and stop signature is measured at elm.
- After elm runs: the runtime layout asks the plant what it has, and
  stops asking which word it is. `hydronic_layout.py` branches on
  `is_house0` / `is_nolan` / `is_house0_no_sieg` in 15 places (the relay
  accessors list the words that have each relay), plus hp-boss's
  `pump_hack` and the loader; `has_sieg_loop`, `has_secondary_pump` and
  `fixed_subtrees` are the other idiom, derived from node presence, and
  the elm boot death was a reader on the first idiom. The move is the
  accessors to `required_node` or `has_<part>` + `required_node`, the
  hack-relay guard to node presence (the next heat-exchanger word has the
  same pump), and the loader keyed by the FamilyParams type. The buffer
  tank is the meaning question under it: `SeasonalStorageMode` is
  `BufferOnly | AllTanks` and the House0 machines read buffer temps
  without asking, so the two no-buffer layouts need a sema answer (a
  storage posture whose name does not say buffer, or a capability the
  machines read) before any machine is written for them.
- The thermostat operating-state channels (`zoneN-<label>-state`,
  Hubitat attribute `thermostatOperatingState`, telemetry
  `ThermostatState`, Unitless, polled at 5 s) are in every legacy House0
  layout and in none of the sema-word ones: the House0 gen's
  `hardware/hubitat_zone.py` emits temperature and setpoint only. They
  stay: add the attribute, its data channel and tuning there, a `state`
  name on the zone channel class in gwsproto, and check that the main
  line's Hubitat poller takes a non-numeric attribute. Every House0 gen
  regenerates.
- The word requires `primary-pump-pwr` whatever `PrimaryPumpOwner`
  says; on a unit-owned pump the channel can only be disabled on a
  register nothing reads. The sema wave after elm runs drops the
  requirement when the owner is `HeatPump`.
