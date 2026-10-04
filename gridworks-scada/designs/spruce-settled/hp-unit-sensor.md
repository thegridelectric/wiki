# HP unit sensor (spoke)

Status: Draft · Pass 0 · Updated 2026-10-02 · Linear: OPS-532

> What this is: a first sensed machine of what the heat pump unit is
> doing, Off, Charging, Defrost, Unknown, told from the power meter's
> channels by rules written per kind of heat pump, one file each. It is
> practice, deliberately heuristic, and not likely the machine the fleet
> ends up running: the point is to get the shape right (shared states,
> per-unit transitions, pure and tested, a switch by device type) and to
> learn what the real units do before a machine is asked to carry
> control. After the spruce launch; nothing on the launch path reads it.

## Why heuristic, and why now

The scada's heat-pump knowledge sits in hand-kept tables keyed by the
hp-odu `DeviceType` (`actors/hp_boss/sensing.py`: the Nolan pump
thresholds and the House0 defrost signatures) and in the sieg loop's
own idle-draw line. Each was written against one house's evidence and
none handles defrost. The signatures work
(`executor/heat-pump-signatures/`) shows the units differ in kind, not
only in numbers: the LG and the Ecodan show a defrost as a stop on
power, the Samsung's defrost is unmeasured, and elm's Arctic has two
compressors. So the first machine is written to be replaced: per-unit
rules with the evidence in the file's docstring, measured numbers only,
and no transition the evidence does not support. What it teaches goes
into the device-type record and the machine that follows.

## The shape (drafted 2026-10-01, not yet in the tree)

In the `actors/hp_boss/` package:

- `sensing.py` holds the shared vocabulary: the unit state enum (Off,
  Charging, Defrost, Unknown; hand-coded until the sema enum exists), a
  power sample record (outdoor and indoor draw, `None` where a channel
  is not live), and the `HpUnitSensor` base, which holds its state
  between samples and leaves `transition` to the unit's file.
- One file per kind of heat pump with that unit's transitions and the
  evidence behind each line. `samsung_ae055.py` is written; the sim
  unit mirrors it by subclassing.
- The package `__init__` holds the switch from device type to sensor
  class; an unknown device type fails naming it.
- `tests/actors/test_hp_unit_sensor.py`: pure tests fed samples, one
  per transition and one per thing the unit must ignore.

The Samsung rules, from the spruce journal 2026-09-21 to -24: running
above 500 W (above the 168 to 318 W idle pulses), stopped below 80 W
(below the 64 to 70 W upper standby), everything between holds the state
(idle pulses, the unit's own water-pump runs at 62 to 232 W, a dip while
running). The indoor draw is ignored. No Defrost: a Samsung defrost is
unmeasured at spruce, so a defrost reads as a stop until it is.

Nothing reads a sensor yet. The pump posture and the defrost judgment
stay on the tables until the machine has run beside them for a season's
worth of starts and defrosts and the comparison is in the journal.

## What it is not

- Not what the Nolan machine uses for the pump: that is the threshold
  machine hp-boss runs, which this machine retires
  (`../spruce-unlimbo/nolan-local-control.md` "The heat-pump
  threshold machine").
- Not reported. Reporting it as a machine state needs the state enum
  as a sema word and the layout's machine declaration
  (`../spruce-unlimbo/report-all-machine-states.md`); both wait.
- Not a judge of the commanded call. It never reads hp-boss's commanded
  machine; comparing the two is a doctor's job.

## Done when

- The drafted files are in the tree with the tests green, and the
  Samsung sensor runs beside the pump posture at spruce, logging its
  transitions, for a bounded window.
- One known beech defrost is replayed from the journal readings through
  an LG sensor file, offline, and the file's rules are set from it.
- The comparison (sensor state against the hack's pump line and the
  House0 defrost judgment) is written up as what the next machine
  should carry, and this spoke names its successor or closes.

## Open

- Whether the machine hangs on `hp-odu` (the node the state is about)
  or `hp-boss` (the node that reports it) when it is declared.
- A cooling word: Charging is the heating name, and the Nolan cooling
  layout will show the gap.
