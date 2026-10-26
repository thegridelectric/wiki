# Elm on the Arctic heat pump

Status: Accepted · Pass 1 · Updated 2026-10-26 · Linear: OPS-628

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

**▶ Do this next.** Step 1 is built on scada `jm/arctic` and tlayouts
`jm/arctic` (uncommitted 2026-10-26 evening): the snapshot, the
`House0NoSiegLayout` twin, `tests/named_types/test_gw_house0_no_sieg.py`
on the hazel sim pair, the per-word command classes, the shared
secondary names (step 2's constant move came with it), the loader
pairing and the runtime layout's `is_house0_no_sieg`. The hazel pair
decodes through the twin and is refused by the runtime layout at load:
`circulator-running` is not a derived-generator strategy. Next is that
part of step 3: the strategy in `derived_generator.py` beside
`heat-call` and in the runtime layout's strategy check
(`hydronic_layout.py` `validate_derived_channels`), with a test beside
the heat-call ones; then `tests/actors/test_hp_boss.py` on the hazel
pair, then the Arctic `HP_TRAITS` row.

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
  `hp-idu-pwr` channel. Register map
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
- The layout is deployed by `scripts/roll.sh`, from the committed
  tlayouts JSON, as for every house.

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
- **Modbus later**: RS-485 at 2400 baud, address by DIP switch SW2;
  register 2000 is on/off, 2003 the heating setpoint. The dry contact
  stays the enable even then, so a scada-side stop never depends on the
  bus.

## Open

- The word's RequiredSensing (axiom 7) still lists `hp-idu-pwr`, and
  step 4 drops elm's `hp-idu` node and channel because the monobloc has
  no indoor unit. One of them gives: the word takes `hp-idu-pwr` out of
  the required set (a sema change on `jm/arctic`, snapshot and twin
  regenerated), or elm keeps a disabled `hp-idu-pwr`. The hazel sim pair
  keeps hp-idu for now.
- eGauge single-sample glitches, seen in elm's journal readings on
  2026-10-26: at 11:44:28 every eGauge channel saturated in one sample
  (`hp-odu-pwr` 32767, `hp-idu-pwr` -32768, `oil-boiler-pwr` 32767, the
  pumps about ±2550 W) and at 12:52:16 a smaller one (odu 1820, idu
  -1828, oil boiler 1826); each cleared on the next sample. Found by
  reading the raw `report.event` readings, not from any problem event or
  glitch the scada raised. A threshold read of a single sample would
  call the unit on. The fix is OPS-629: the power meter owns clean
  readings, with a 1.5 times nameplate bound on hp-watch.
- Elm's `hp-ewt` read above `hp-lwt` through the first runs with no rise
  from 4 to 5 kW of compressor input, and `primary-pump-pwr` reads near
  zero while primary flow runs: the HP temperature sensors and the
  primary-pump CT want a field look.
- The aquastat path through hp-failsafe-relay: with the Arctic, is there
  an aquastat at all, or does the failsafe position simply leave CN33
  closed so the unit heats on its own setpoint when the scada is out?
- The Arctic device-type record in sema (`hp.device.type.gt`) and its
  `HP_TRAITS` row, after the start signature is measured.
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
