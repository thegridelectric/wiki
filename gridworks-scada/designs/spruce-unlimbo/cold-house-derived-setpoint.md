# Cold house with a derived setpoint (spoke)

Status: Accepted · Pass 1 · Updated 2026-10-05 · Linear: OPS-392

> What this is: how the scada judges "the house is getting cold" at a house
> whose zone setpoints are derived by the scada instead of read from a
> thermostat, and the tests that hold that judgment through the glitches
> where it matters. Spruce is the first such house and most houses after it
> will be. Part of OPS-539's scada strand; the hub is OPS-392.

## Why this is its own spoke

The cold judgment compares each critical zone's temperature with its
setpoint. At a House0 house the setpoint is a thermostat's own report
and is always there. At spruce it is the output of the derived generator's
`simple-falling-edge-setpoint` strategy, which does not always produce one.
A cold-house judgment that goes quiet when its setpoint input goes quiet
fails in the hours it exists for.

## What the generator does


The strategy (`actors/derived_generator.py`
`handle_simple_falling_edge_setpoint`) learns a zone's setpoint as its
`-gw-temp` at the moment a heat call ends, and emits it on the zone's `-set`
DerivedChannel in `FahrenheitX100`. It holds no setpoint, and emits nothing,
in three situations:

- **From boot until the zone's first heat call ends.** The state is in
  memory and a restart clears it.
- **While a heat call never ends.** No falling edge means nothing is
  learned. A zone that calls for twelve hours straight is the cold-house
  case itself, and after a restart inside that call the zone has no
  setpoint for as long as the call lasts.
- **After a suspected thermostat change.** The zone calling while 2 °F
  (`SetpointThresholdFX100`) above the learned value reads as "raised"
  (`SuspectZoneBelowSetpoint`); not calling while 2 °F below reads as
  "lowered" (`SuspectZoneAboveSetpoint`). Either clears the learned value
  until the next falling edge.

When the strategy stops emitting, `data.latest_channel_values` still holds
the last `-set` value, with nothing marking it withdrawn.

The layout already says which kind of setpoint a zone has: each
`gw1.zone.call.circuit` carries `SetpointSource`
(`zone.setpoint.source`: `FromThermostat` or `Learned`), and sema holds a
`setpoint.phase` enum beside the generator's own in-code `SetpointPhase`.
The cold judgment reads `SetpointSource` and not the phase.

The deployed spruce layout (`tlayouts/output/spruce/spruce.uploaded.json`),
the generated one (`tlayouts/output/spruce/gw.nolan.layout.json`) and the
Nolan sim fixture (`tests/config/gw.nolan.layout.json`) each carry the four
`zone{i}-{label}-set` DerivedChannels. No layout word requires them.

## The scenarios to hold

Each is a test on the Nolan sim pair, driven through the derived generator
and not by injecting a `-set` value, and each ends in the question "did
`is_system_cold` say cold when the house was cold":

1. Steady state: heat calls cycle, a setpoint is learned, a zone drifts
   more than 1 °F under it.
2. Restart inside a long heat call with the zone temperature falling.
3. Heat cannot be delivered: the zone calls without end and its
   temperature falls.
4. The thermostat is raised during on-peak (the House0 rule's protection:
   judge against the lower of the on-peak-start and current setpoints).
5. The thermostat is lowered, then the house cools to the new setting.
6. The generator has withdrawn its setpoint and an old value is still in
   `latest_channel_values`.
7. A critical zone's `-gw-temp` stops reporting.

## Decisions

- **Cold is 2 °F or more under setpoint, every family.** `is_system_cold`
  compares at 1 °F today, and that number only ever worked because the
  Honeywell thermostats reported no temperature until it was more than
  2 °F from setpoint; the judgment was 2 °F in effect. Make it `>= 2 °F`
  in the code so it reads as what it does.
- **One `is_system_cold` for every family,** branching per critical zone
  on its circuit's `SetpointSource`. A `FromThermostat` zone is judged
  against its `-set` channel with the on-peak-start minimum rule, as
  today. A `Learned` zone is judged by the constant-call rule against
  its recorded setpoint. The zone's own circuit is the one at the zone's
  position. The House0 houses with Honeywell thermostats declare
  `FromThermostat`; the two House0 sim pairs author a mechanical dial,
  which is `Learned`, and so run the learned rule on a `-set` channel a
  sim sensor reports.
- **Every critical zone has a `-set` channel, whatever its source.** At
  a `Learned` zone it is the DerivedChannel the generator emits on. An
  axiom on both layout words says so (word gate), which turns today's
  silently skipped "Could not find setpoint" into a layout that does
  not load.
- **A learned-setpoint house keeps its last recorded setpoint,** across
  restarts too, and declares cold when a critical zone has been in a
  constant heat call AND its temperature is 2 °F or more under that last
  recorded setpoint. The heat call is the thermostat saying "below
  setpoint"; the recorded setpoint says by how much. This is the
  stand-in for scenarios 2 and 3 above, where the generator holds no
  setpoint.
- **The record is the last value the zone's `-set` channel carried.**
  The cold module keeps it per critical `Learned` zone and judges
  against the record, never the channel's latest value, so a setpoint
  the generator has withdrawn needs no marking for this reader.
- **The record persists as a sema-shaped type in gwsproto only:** a
  named type with a TypeName, a version, the PascalCase wire form and
  property formats, with no registry word: `gw.recorded.setpoints`, a
  `ScadaAlias` and a list of `single.reading`. The file is
  `recorded-setpoints.json` in the scada's data directory, beside the
  dispatch contract file, where the scada already keeps what it writes
  itself. Its docstring names the missing word that retires it.
- **Constant call means calling through the whole five-minute latch.**
  No second timer: a zone 2 °F under its record has already been
  falling for a while.

### The constant-call rule against every way the setpoint is lost

Read off `handle_simple_falling_edge_setpoint` (`actors/derived_generator.py:530-650`)
and `is_system_cold` (`actors/hydronic/shared.py:60-97`). The rule fires
when a critical zone is calling without a break and its temperature is
2 °F or more under the last recorded setpoint; it must fire in the cold
cases and stay quiet in the thermostat-change cases the strategy exists
to tell apart.

| How the setpoint is lost | What the strategy does | Constant-call rule |
| --- | --- | --- |
| Restart, or first boot: `setpoint_f` is `None`, phase `Unknown`; the first reading sets the phase to a Suspect value with nothing learned | Emits nothing until a falling edge; `is_system_cold` logs "Could not find setpoint" and skips the zone, so a restart inside a long call never reads cold | Fires, given the persisted last recorded setpoint; with no record ever (new house, state file absent) there is still nothing to judge against |
| Falling edge with no `-gw-temp` seen yet | Logs "no gw-temp available", learns nothing | Same as above |
| Zone calling at or above setpoint + 2 °F (`SuspectZoneBelowSetpoint`: thermostat raised) | Clears `setpoint_f`, stops emitting; the old value stays in `latest_channel_values` unmarked | Stays quiet: the zone is warmer than the record, not colder |
| Zone not calling at or below setpoint − 2 °F (`SuspectZoneAboveSetpoint`: thermostat lowered) | Clears `setpoint_f`, stops emitting | Stays quiet: no call, so the house cooling to the new setting is not read as cold |
| Long call that never ends, with the setpoint learned before it | Keeps the learned value and emits it; today's judgment already works here | Fires once the zone falls 2 °F under it |

Two cases neither the strategy nor the rule covers, named so they are
not mistaken for covered:

- **Cold with no call.** A thermostat or wire failure leaves a critical
  zone cold and silent; the strategy reads it as "lowered". At a House0
  house the thermostat still reports a setpoint and the judgment
  catches it; at a learned-setpoint house nothing does. A floor
  temperature per critical zone (ops word) is the candidate.
- **No record ever.** The rule needs a last recorded setpoint; before
  the first falling edge at a house there is none. The same floor
  temperature is the stand-in.

The on-peak-start minimum rule (a thermostat raised during on-peak does
not trip the judgment) needs no twin at a `Learned` zone: a raised
thermostat leaves the zone warmer than the record.

## What a cold house says

Today a cold house produces no glitch on either branch: the local
control moves to backup after five minutes cold and reports a
`SingleMachineState` with cause `SystemCold`, the ally raises an Info
glitch only inside a dispatch contract with the stores also empty, and
a critical zone with no setpoint or temperature is skipped silently.
Neither branch has a freeze threshold; gridworks-alerts carries one
(40 °F, hardcoded in `check_zone_freezing`, `docs/alerts.md` "Zone
Freezing"), so the scada raises none and the alert lives off the box.

Three glitches, each its own `Summary` (`critical-zone-cold`,
`still-cold-in-backup`, `zone-freezing`; a glitch's `Type` is its log
level), so on-call can tell them apart and so the later ones are not
re-pages of the first:

1. **Critical zone cold.** Critical, at every house, when the cold
   judgment has held for five minutes on a critical zone alone, whatever
   the stores hold, once per cold spell. The same latch asks the scada
   to set `AcceptsDispatch` false with `ServiceContractBroken`
   (`executor/local-control.md` "The dispatch refusal"). A scada that already refuses dispatch (`NoAggregator`)
   keeps its params and its reason; the glitch is raised all the same.
   The heating local control makes the check on every pass of its loop
   in every top state, Dormant under a dispatch contract and under
   admin included: a house that goes cold under a contract ends the
   contract, through the same termination the leaf ally's own give-up
   uses. A House0 house also moves to backup as it always has, on its
   own five minutes of cold with its stores empty (buffer empty, and at
   an all-tanks house the store too); the switch itself is the
   `SingleMachineState` report, not a second glitch.
2. **Still cold in backup.** Critical. The machine has been in
   `UsingBackup` for more than an hour and `is_system_cold` still holds.
   Only a house with an available backup can raise it.
3. **Zone freezing.** Critical. Any zone, critical or not, reads below
   the freeze threshold (40 °F, the gridworks-alerts number, to become
   a named constant beside the cold delta). Raised at any top state,
   at most once a day per zone.

A cleared latch raises no glitch. The scada reports it as
`gw.house.operating.status` carrying `AcceptsDispatch` true, sent after
the restart that clears it.

Spruce this winter raises glitch 1 the first time a critical zone is
cold and stays in Normal (`executor/local-control.md` "The top
state"); with no backup it never raises glitch 2.

**One shared home for the cold machinery.** Judging whether a critical
zone is cold, the constant-call rule, the recorded setpoint, the freeze
check and the three glitches are one module every family imports
(`actors/hydronic/shared.py` holds `is_system_cold` today; the judgment
grows enough to earn a file of its own). The 2 °F delta and the freeze
threshold are named constants at the top of that file, never literals
in the comparisons.

## Not in this spoke

- The per-zone floor temperature for the two uncovered cases above
  waits.
- The `UsingBackup` rename, the layout `Backup` chunk and
  `BackupAvailable` (`nolan-local-control.md` "Backup"). House0's move to backup is untouched by this spoke.
- Standby and the cooling machine make no cold check.

## Open

- **The `-set` axiom** on both layout words is not written (word gate).
  Until it is, a critical zone with no setpoint channel is logged and
  skipped.
- **Axiom candidate:** a circuit that says `FromThermostat` has a
  reported (data) `-set` channel, and one that says `Learned` at a real
  house has a derived one. Nothing checks that the two agree.
- **The elm, oak and fir gens** declare `FromThermostat` in source and
  are not regenerated: each fails layout axiom 8 before reaching its
  output.

## Built

- `actors/hydronic/cold.py`: the `ColdJudgmentNode` tier under both
  family tiers with the judgment, and the `ColdWatch` actor with the
  record, the latch and the three glitches; the named constants at its
  top.
- The scada's `BreakServiceContract` handler: the refusal in the
  running params and in the params file, the operating status, the
  contract's end.
- `tests/actors/test_cold_handling.py` (in-process, both families) and
  `tests/actors/test_cold_handling_live.py` (a running Nolan scada
  stays in Normal; a running House0 scada under a contract ends it).

## Do this next

The word gate for the `-set` axiom on `gw.house0.layout` and
`gw.nolan.layout`.
