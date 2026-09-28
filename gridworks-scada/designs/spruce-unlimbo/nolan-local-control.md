# Nolan local control (spoke)

Status: Draft · Pass 0 · Updated 2026-09-26 · Linear: OPS-392

> What this is: the rework of `NolanLocalControl` into the loop that
> actually runs a Nolan house through a heating season. Today the actor
> is observation-only plus a scripted summer witness; the loop that USES
> predicted setpoints is unwritten. This spoke gathers what the design
> already knows about it (scattered across five spokes until 2026-09-07)
> and is where the work goes now that the node-actor partition is complete
> (`executor/control-hierarchy.md` "The node-actor partition"): the actor
> tiers, the command-tree mechanics, hp-boss and the admin command surface
> this loop sits on are in place.

## Where it sits

- Thread D of the spruce-unlimbo hub (OPS-219 lives there): written
  against the OPS-394 capability surface from day one; the zone slice of
  that surface is settled in `../spruce-settled/thermostat-and-zone-control.md`.
- Partition tier C+D: Nolan plant judgment lives in
  `actors/hydronic/nolan.py`, the loop in `actors/local_control/nolan.py`,
  loaded by `local_control_loader.py` from the ops word
  (`control-strategy-selection.md`: ops chooses the machine, the
  machine owns its state).
- Names: `backup` and `scada-blind` are House0 names for now; they
  return to a shared tier only if this rework needs them
  (`../../executor/hardware-layout.md` "Names — `gwsproto/names/`").

## What the actor does today

`NolanLocalControl` (`690d584e`) boots into Normal running the scripted
witness (fancoil takeover + call with the Caleffi-latency hold, secondary
pump on/off), then segues to Monitor; record-driven off
`Hydronic.ZoneCallCircuits` and the board's RelayNames. The relay path's
EDD gate is met (`experiments/2026-08-12-spruce-witness-window/`). The
summer hack on the box is the behavior the loop replaces at parity
(TOU schedule + sequencing + zone holds + enforcement as scada
behavior; zone holds = `SwitchToOff` on the floor circuits).

## Known defects the rework must close

Each is recorded where it was found; this list is the one place they
are gathered.

- **Mode-blind loop.** The TOU loop has no system-mode gate and
  `gw1.system.mode` has no Cooling value (000 published, so additive
  001); the spruce ops artifact still says Heating. Needed before any
  heating-season deploy.
- **Schedule hardcoded twice.** `local_control/nolan.py` hardcodes
  `ONPEAK_WINDOWS` though ops carries `OnPeakWindows`; the base actor
  holds a second schedule; no `ServiceMode` gate
  (`operational-params-cleanup.md` step 8).
- **ScadaBlind entry crashes on Nolan.** Entry calls the store-pump
  failsafe on a node the Nolan layout lacks; the actor dies at the
  5-min missing-forecast mark. The deployed `actual-spruce` line guards
  the equivalent case; the rework wants the layout-conditional guard
  the hub's axis-3 model gives, not a copy of that guard
.
- **Sequences ignore top-state transitions.** `command_sequence` paces
  steps 15 s apart and never re-checks `top_state`; an admin wake-up
  mid-sequence still lets a command leave the LC, caught today only by
  the relay's rights check. Dormant means commands nothing. The
  partition's `command-tree-matrix` asserts this; the rework makes the
  sequence itself transition-aware.
- **Actuators are not booted.** `initialize_actuators` commands
  nothing ("actuators left at their adopted states"); every node that
  is the direct boss of an actuator boots its actuators at start, once
  they are ready (basic-sieg change 4c states the rule). The test that
  proves it is one parametrized live test over every test layout and
  every strategy selection the ops word allows (`ActuationAuthority`,
  `SeasonalStorageMode`, `SiegLoopStrategy`): boot the scada, wait for
  local control to initialize, and assert every relay has left Unknown
  within seconds (`tests/actors/test_relays_boot.py`, with change 4c).
  Nolan passes that criterion today only because its TCA9555 board
  reads back and the relays adopt the pins; no boss commands a posture.
  The rework's test is the stronger one: every relay receives a boot
  command from its direct boss.
- **Setpoints by channel-name scraping.** LocalControl finds zone
  setpoints with `'zone' in x and 'set' in x` rather than the circuit's
  Thermostat; nothing consumes `Thermostat.ComponentId` or
  `ThermostatKind` yet (`../spruce-settled/thermostat-and-zone-control.md`
  "Thermostat chunk").

## Shape to converge on

The House0 skeleton is the precedent, not the template: one loader
selecting the machine by mode, a `LocalControlTouBase` 60 s loop, and
an FSM whose states name plant conditions (House0: Initializing /
HpOffStoreOff / HpOnStoreOff / HpOnStoreCharge / HpOffStoreDischarge /
Dormant). Nolan's states are its own; the shared bar applies ("every
layout we can imagine has this", so no buffer, iso valve or store tank
assumed). The circuit actor runs two machines with LocalControl as the
boss (`../spruce-settled/thermostat-and-zone-control.md`); no zone-boss actor until
one earns its place. Open: which of the House0 machine set (Standby /
AllTanksTou / BufferOnlyTou) has a Nolan analogue at all, and where the
schedule lives (ops artifact, settled by the ops-params work).

## ▶ Do this next

Nothing yet: the node-actor partition and the House0 hydronic reviews are
complete. First move: grill the Nolan
state machine (states, what each refuses, how predicted setpoints enter)
against the defect list above, and record the result here.
