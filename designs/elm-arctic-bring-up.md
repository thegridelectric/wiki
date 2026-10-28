# Elm on the Arctic heat pump

Status: Accepted · Pass 1 · Updated 2026-10-28 · Linear: OPS-628

**EDD: yes** the verification is elm heating its buffer from the Arctic
unit under scada command on the production broker: the call relay across
CN33 starts and stops the unit, the secondary pump runs whenever the call
is closed, and the journal shows hp power, buffer temperatures and the
pump relay state agreeing. The local tests (hp-boss on a sieg-less House0
sim layout, the new layout word's axioms) are the reproducer, not the
proof.

> What this is: the plan for bringing elm back as the first House0 home
> with a heat exchanger and an Arctic R32 high-temperature heat pump,
> on the scada line on `main`. The built parts (the sieg-less House0
> word, the secondary pump under hp-boss, the Arctic traits row, the
> hack relay) are in the scada executor; what stays here is elm's own
> layout choices, the field harness that verifies the design, the tank
> capture delta still to build, and what is open. Modbus control of
> the unit is later work and is not in scope.

## Do this next

Elm runs on scada `main` with the committed tlayouts pair since
2026-10-28; the record of every run and observation is
`experiments/2026-10-27-elm-arctic-field-check/`. **Next: run step 7's
harness on the journal window 2026-10-27 22:49 to 2026-10-28 07:00 ET**,
so the pass criteria are a re-runnable verdict and not a one-off read,
and record the run in the folder's README. Then the tank capture delta
below, then energy metering.

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
  through its dry-contact enable and its wired controller: the vendor
  side, its settings and the bench questions are
  `wiki/gridworks-scada/executor/heat-pump-comms/arctic-mahrw030za.md`.

## The elm layout

Elm's own choices on tlayouts `main` (`elm_gen.py`), kept here until fir
and oak move to the word and the choices become the pattern:

- `TypeName` is `gw.house0.no.sieg`; the fake sieg surface (the sieg BTU
  on a pico that does not exist, its channels, the sieg-loop node and
  its two relays) is gone, as are the `hp-idu` node and its `hp-idu-pwr`
  eGauge channel.
- The primary-pump relays (Krida 11 and 12, "Primary Pump SCADA Ops" and
  "Primary Pump Failsafe") are gone; `primary_pump_owner` is HeatPump.
  `secondary-pump-relay` (handle `auto.hp-boss.secondary-pump-relay`,
  normally open) is on Krida 11, wired to the secondary pump's
  contactor; `secondary-pump-hack-relay` is on Krida 12 until 12 is
  wired out.
- hp-scada-ops-relay (Krida 6) is the call across CN33. The hp-failsafe
  relay (Krida 5, double throw) chooses between the scada's contact and
  the aquastat path; what the aquastat path means with the Arctic is
  open below.
- `hp-odu` names DeviceType `ArcticMAHRW030ZA`, and the layout has an
  hp-watch node, so hp-boss finds the unit's `HP_TRAITS` row at load.
- The hall pico the legacy layout called `primary-flow` (pico_3e9a28) is
  `secondary-flow`, renamed on the pico itself through the
  starter-scripts API (its `ActorNameByHwUid` map). The hall pico the
  legacy layout called `store-flow` (pico_5a5127) is on the unit's loop
  as `primary-flow`. The store flow is unmeasured: `store-flow` sits on
  a hall pico that does not exist, disabled with its channels.
- `hp-lwt` and `hp-ewt` keep ADS terminals 3 and 4, live;
  `secondary-lwt` and `secondary-ewt` are ADS terminals 9 and 10,
  disabled until their thermistors are wired. `secondary-pump-pwr` is
  eGauge register 9008 with `secondary-pump-running` reading it at 20 W;
  `primary-pump-pwr` keeps register 9002, disabled, until a CT is on the
  unit's pump conductor. The DAC output on Dfr1 B that drives the
  house-side pump at 3.5 V is `secondary-010v`.
- The layout is deployed by `scripts/roll.sh` from the committed
  tlayouts JSON (`output/elm/gw.house0.no.sieg.json` and
  `gw.house0.no.sieg.operational.params.json`), as for every house.

## The tank capture delta

Decided 2026-10-28; sema `jm/capture-delta` is green and awaits its
commit, the scada side is next. The async capture delta of a tank pico
is authored on the depth's temperature channel (`tankN-depthM-device`,
CelsiusTimes100) in the operational word, and the scada translates it to
the micro-volt threshold the pico compares against: the micro-volt
difference across the delta at 130 °F through the component's beta, so
one authored number means the same thing at the middle of the tank range
on every module. The pair has one trigger: the micro-volt channel's
tuning states no delta, the ops word says so, and the scada refuses one
at assembly. The component word loses `AsyncCaptureDeltaMicroVolts`; the
params word keeps it, since it is what the pico is told. Authored 8
(0.08 °C), which answers 4000 µV, judged above the module's noise; the
pump-power and noise table in Open is the measurement that confirms or
moves it. Temperature rather than microvolts because a human gets a
tenth of a degree right and checks it against a thermometer. The
firmware applies the threshold it is answered with
(`tank_module_3_main.py:354`, strictly greater, on 1000-sample reads
averaged 10 or 30 times) and is unchanged.

The scada side, on `jm/tank-capture-delta` with bulk-on: regenerate the
snapshot, drop the field from the two twins and four fixture pairs,
author 8 on the temperature tunings and no delta on the micro-volt ones,
add the translation in `api_tank_module.py` and the assembly checks in
`sema_to_dc.py` (no micro-volt delta; the three temperature deltas
present and equal), with their tests. tlayouts the same on a branch once
its `jm/beech-main` tree is dealt with.

The ops word has no structure that groups a pico's six channels, so
every rule about the group is an assembly check. A per-component tuning
the per-channel ones hang under would make the three-depth rule an axiom
on the word; a sema wave after elm runs.

## The field detection harness

The verification is elm on `main`, watched. The folder is
`experiments/2026-10-27-elm-arctic-field-check/`: a README stating the
pass criteria and recording each run (date, window, verdict), and
`field_check.py`, which reads the criteria off the journal DB
(`DB_ANALYST_URL`) for a window so that each check is a verdict line,
not a transcript:

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

The harness is the reproducer the design's `EDD: yes` names. A failing
check gets its local test first, per the field-bug rule.

## Open

Field work at elm:

- `hp-lwt` and `hp-ewt` go back on the unit's leaving and entering pipes
  (George, through Paul, 2026-10-27); until then they read air.
  `primary-pump-pwr` reads near zero while primary flow runs: the
  primary-pump CT wants a field look.
- The aquastat path through hp-failsafe-relay: with the Arctic, is there
  an aquastat at all, or does the failsafe position simply leave CN33
  closed so the unit heats on its own setpoint when the scada is out?
  With relay8 at Boiler the Arctic stays off (observed 2026-10-26); the
  other position of relay8 is not yet observed.
- Elm's `SCADA_SYSTEM_MODE` in the box's .env is not yet in the
  instance-README.
- Whether elm's buffer tank calibration (`TankTempCalibration` on the
  buffer in the legacy generator) survives into the sema-word layout.

Measurement and build still to do:

- A table, from the journal DB, of every pump power channel in every
  house: the lowest power that is plainly "on", and the jitter around
  zero while the pump is off. The `circulator-running` threshold, the
  eGauge capture deltas for the pumps and the tank capture delta's
  noise margin come from this table.
- Energy metering at elm: the eGauge reports power only today; the run
  wants watt-hours for the heat pump and the pumps so a cycle's
  electricity is a journal fact and not an integral over captured
  deltas.
- The Arctic device-type record in sema (`hp.device.type.gt`) and its
  `HP_TRAITS` row, after the start signature is measured. The unit has
  two compressors in one monobloc, so the signature has two steps and
  the record's `CompressorRatedAmps` is a nameplate total; no field on
  the record says monobloc or counts compressors, and none is added: the
  layout's `hp_parts` (odu alone) and the traits row state those facts.
- The pump doctors' AnalogDispatch still names the command node as its
  FromHandle, which the 0-10 V actor refuses as a `bad_sender` glitch;
  the dist-flow startup limit (50 s) against elm's observed 60 s.
- The persisted contract heartbeat is `001` against `002`, so each boot
  starts with no contract; the picos' `code-update` posts draw seven
  `unserved-post` warnings per boot.
- eGauge single-sample glitches at elm: OPS-629.
