# Cold house with a derived setpoint (spoke)

Status: Draft · Pass 0 · Updated 2026-09-18

> What this is: how the scada judges "the house is getting cold" at a house
> whose zone setpoints are derived by the scada instead of read from a
> thermostat, and the tests that hold that judgment through the glitches
> where it matters. Spruce is the first such house and most houses after it
> will be. Part of OPS-539's scada strand; the hub is OPS-392.

## Why this is its own spoke

`is_system_cold` (`actors/hydronic/shared.py`) compares each critical zone's
temperature with its setpoint and calls the house cold when a zone is more
than 1 °F under. At a House0 house the setpoint is a thermostat's own report
and is always there. At spruce it is the output of the derived generator's
`simple-falling-edge-setpoint` strategy, which does not always produce one.
A cold-house judgment that goes quiet when its setpoint input goes quiet
fails in the hours it exists for.

## What the code does today

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
the last `-set` value, so `is_system_cold` judges against a setpoint the
generator itself has withdrawn, with nothing marking it stale.

The layout already says which kind of setpoint a zone has: each
`gw1.zone.call.circuit` carries `SetpointSource`
(`zone.setpoint.source`: `FromThermostat` or `Learned`), and sema holds a
`setpoint.phase` enum beside the generator's own in-code `SetpointPhase`.
Neither is read by `is_system_cold`.

The deployed spruce layout (`tlayouts/output/spruce/spruce.uploaded.json`)
carries the four `zone{i}-{label}-set` DerivedChannels. The sema-native
Nolan gens do not emit them, so the generated spruce layout and the Nolan
sim pair have none and `is_system_cold` finds no setpoint there.

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

## Open decisions

- **What stands in when there is no setpoint.** Candidates, not yet
  weighed: the zone's own heat call is the thermostat saying "I am below
  setpoint", so a critical zone calling continuously for longer than some
  bound while its temperature does not rise is a cold signal that needs no
  setpoint at all; a floor temperature per critical zone from the ops word;
  the last learned setpoint persisted across restarts.
- **Whether a withdrawn setpoint is visible to readers.** Today a reader
  cannot tell a current `-set` from a withdrawn one. The generator could
  report its `SetpointPhase`, or readers could age the value out.
- **Whether the Nolan word requires a `-set` DerivedChannel per zone**, or
  per critical zone.
- **Where the rule lives.** One `is_system_cold` for every family with the
  setpoint source behind it, or a family-tier judgment.

## Do this next

Write scenario 1 as the first test, through the derived generator on the
Nolan sim pair, and let it show what the judgment does today before any of
the decisions above is taken. The Nolan sim fixture carries the per-zone
`-set` DerivedChannels it needs.
