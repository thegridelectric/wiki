# Nolan local control (hub)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

**EDD: yes** the loop is verified by spruce windows and honeysuckle bench
boots against the real bus; the suite is necessary, not sufficient.

> What this is: the rework of `NolanLocalControl` into the loop that
> actually runs a Nolan house through a heating season. Today the actor
> is observation-only plus a scripted summer witness; the loop that USES
> predicted setpoints is unwritten. This folder gathers what the design
> already knows about it (scattered across five spokes until 2026-09-07)
> and is where the work goes **after `sh-node-actor-partition/`**: the
> rope settles the actor tiers, the command-tree mechanics, hp-boss and
> the admin command surface that this loop sits on. Do not start here
> until the rope's queue is clear.

## Where it sits

- Thread D of the spruce-unlimbo hub (OPS-219 lives there): written
  against the OPS-394 capability surface from day one; the zone slice of
  that surface is settled in `../zone-relays-and-thermostat-model.md`.
- Partition tier C+D: Nolan plant judgment lives in
  `actors/hydronic/nolan.py`, the loop in `actors/local_control/nolan.py`,
  loaded by `local_control_loader.py` from the ops word
  (`../control-strategy-selection.md`: ops chooses the machine, the
  machine owns its state).
- Names: `backup` and `scada-blind` are House0 names for now; they
  return to a shared tier only if this rework needs them
  (`../sh-node-actor-partition/primary.md` "Names grilling decisions").

## What the actor does today

`NolanLocalControl` (`690d584e`) boots into Normal running the scripted
witness (fancoil takeover + call with the Caleffi-latency hold, secondary
pump on/off), then segues to Monitor; record-driven off
`Hydronic.ZoneCallCircuits` and the board's RelayNames. The relay path's
EDD gate is met (`experiments/2026-08-12-spruce-witness-window/`). The
summer hack on the box is the behavior the loop replaces at parity
(`../summer-local-control.md` build step 7: TOU schedule + sequencing +
zone holds + enforcement as scada behavior; zone holds = `SwitchToOff`
on the floor circuits).

## Known defects the rework must close

Each is recorded where it was found; this list is the one place they
are gathered.

- **Mode-blind loop.** The TOU loop has no system-mode gate and
  `gw1.system.mode` has no Cooling value (000 published, so additive
  001); the spruce ops artifact still says Heating. Needed before any
  heating-season deploy (`../summer-local-control.md` "Open").
- **Schedule hardcoded twice.** `local_control/nolan.py` hardcodes
  `ONPEAK_WINDOWS` though ops carries `OnPeakWindows`; the base actor
  holds a second schedule; no `ServiceMode` gate
  (`../operational-params-cleanup.md` step 8).
- **ScadaBlind entry crashes on Nolan.** Entry calls the store-pump
  failsafe on a node the Nolan layout lacks; the actor dies at the
  5-min missing-forecast mark. The deployed `actual-spruce` line guards
  the equivalent case; the rework wants the layout-conditional guard
  the hub's axis-3 model gives, not a copy of that guard
  (`../summer-local-control.md` step 7).
- **Sequences ignore top-state transitions.** `command_sequence` paces
  steps 15 s apart and never re-checks `top_state`; an admin wake-up
  mid-sequence still lets a command leave the LC, caught today only by
  the relay's rights check. Dormant means commands nothing. The
  partition's `command-tree-matrix` asserts this; the rework makes the
  sequence itself transition-aware.
- **Setpoints by channel-name scraping.** LocalControl finds zone
  setpoints with `'zone' in x and 'set' in x` rather than the circuit's
  Thermostat; nothing consumes `Thermostat.ComponentId` or
  `ThermostatKind` yet (`thermostat-chunk.md`).

## Shape to converge on

The House0 skeleton is the precedent, not the template: one loader
selecting the machine by mode, a `LocalControlTouBase` 60 s loop, and
an FSM whose states name plant conditions (House0: Initializing /
HpOffStoreOff / HpOnStoreOff / HpOnStoreCharge / HpOffStoreDischarge /
Dormant). Nolan's states are its own; the shared bar applies ("every
layout we can imagine has this", so no buffer, iso valve or store tank
assumed). The circuit actor runs two machines with LocalControl as the
boss (`../zone-relays-and-thermostat-model.md`); no zone-boss actor until
one earns its place. Open: which of the House0 machine set (Standby /
AllTanksTou / BufferOnlyTou) has a Nolan analogue at all, and where the
schedule lives (ops artifact, settled by the ops-params work).

## Spokes

- [`thermostat-chunk.md`](thermostat-chunk.md) — sim thermostat, setpoint
  discovery through the circuit's Thermostat, first Hubitat/Honeywell
  tests, web-listen EDD

## ▶ Do this next

Nothing yet: this folder opens when the `sh-node-actor-partition/` queue
is clear. First move then: grill the Nolan state machine (states, what
each refuses, how predicted setpoints enter) against the defect list
above, and split the result into spokes.
