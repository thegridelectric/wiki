# The scada renovation, where it stands (2026-10-07)

Status: Draft · Pass 0 · Updated 2026-10-07

> What this is: a dated reading of the renovation on `jm/spruce-unlimbo`
> and of the record that describes it, written for the engineer who
> reviews the `executor/` spec. Numbers are from the git log, the
> changelog and the estimates log on the date above; nothing here is
> normative. The spec that is reviewed against it is `executor/`,
> starting at `executor/primary.md`.

## What the three months were

The plan in June was to get one branch onto the fleet before the
heating season. What happened instead was a rebuild of how the scada
knows what it is. A house is declarations the code reads rather than
assumptions the code makes: its topology in the hardware layout (which
pumps, valves, tanks and sensors exist and what each is for), its
equipment in device-type records (which heat pump, which board, how
each is spoken to), and its tuning in the operational params
(thresholds, power levels, the control strategy). A new manifold, a new
heat pump or a new control strategy is a new set of words to the same
code, which is what lets the fall layouts arrive as layouts rather than
forks.

## Highlights

- **Layouts authored in Sema.** The scada boots from a layout word, an
  operational-params word and a deed; the in-repo layout generator is
  gone to tlayouts. Actors read the layout instead of hard-coded name
  rosters.
- **Layout decoupled from parameters.** What a house is and how it is
  tuned are two words with two lifecycles; a parameter change does not
  regenerate a layout.
- **Function decoupled from hardware.** A relay or a temperature sensor
  is a function the layout declares; a device-type record says how the
  board does it. Relays, the DAC and thermistors resolve their pins from
  their records over one I2C bus with proper management and a simulated
  backend.
- **Thermostats, zones and whitewire circuits handled correctly.** A
  zone's heat call is derived the same way whatever senses it: a
  Hubitat thermostat, a whitewire-power reading beside a stat
  temperature (house0), or an opto input beside a wired thermistor
  (nolan and the sim). The layout composes the two raw inputs per zone
  and the derived generator makes the call; a zone already calling at
  boot is reported at once (`executor/hardware-layout.md`, the zone
  sensing section). Most of the work is in; what remains is in the
  nolan-local-control spoke.
- **Tariffs as an abstraction.** The timezone and the on-peak hours come
  from the tariff in the ops word, not from settings and not from three
  hand-written tables (the old tables are in
  `historical-executor/on-peak-clock.md`).
- **Weather from the weather service.** The scada no longer pulls NWS
  itself; it reads the service's forecast words and falls back to the
  service's seasonal template, and refuses to boot without one
  (`executor/weather-forecast.md`).
- **Simulated time stubbed in.** One clock with wall,
  coordinator-timestep and manual sources behind a single interface.
- **Backup defined.** One judgment of a cold house and one cold-watch
  actor serve every layout family; a cold house stops taking dispatch
  until a person clears it (`executor/cold-house.md`).
- **A command tree with acks.** Command nodes ack or nack their boss,
  with a NotMyBoss nack when a command reaches the wrong handle; one
  rule for who may send; gwadmin renders and drives the tree
  (`executor/control-hierarchy.md`).
- **Liveness per channel.** One liveness rule covers the pico actors,
  liveness is judged per channel, a lost sensor reads unknown, and
  field conditions become daily Warning glitches.
- **The sieg loop as a package.** A command node that owns its two
  relays, runs on the clock, and confirms each move
  (`executor/sieg-loop.md`).
- **Units and provenance carried.** Temperature is a record with its
  unit; `is_simulated` is derived, simulated until proven real; a deed
  with UnValidated status refuses LTN offers.

## Numbers, `jm/spruce-unlimbo` from 2026-07-01

| | |
| --- | --- |
| Commits | 214 (Jul 20, Aug 26, Sep 132, Oct 36 to the 7th) |
| Changelog entries | 218 |
| `gw_spaceheat/` | +11.5k / −13.4k lines; the removals are the in-repo layout generator, the duplicate sieg loop and the old I2C multiplexers |
| Test functions | 102 → 947 |
| Test files | 56 → 161 |
| Files deleted | 75, among them the in-repo layout generator, the 1,510-line old sieg loop, and 26k lines of hand-kept layout JSON |
| Ahead of `main` | 301 commits; 15 small field patches on `main` are not on the branch |
| Hours on the estimates log | 128.5 h finished scada work, 1.31× the point estimates; 22 rows open, about 108 h estimated |

## What the tests and field windows found

Bugs that were running on the fleet's code, each given a failing test
before its fix, with the changelog date:

- Every Hubitat web-listen event dropped silently; a missing import
  behind a bare except (2026-09-02).
- The tank advisory compared kWh with Wh and fired a thousand times too
  readily, all season (2026-09-13).
- No whitewire house ever derived a heat call, and the distribution
  pump monitor read nothing (2026-09-20).
- A GPIO zone already calling at boot went unreported for up to five
  minutes; an open thermistor caused a divide by zero (2026-09-20).
- One dropped tank layer rewrote a whole cold store to 70 F
  (2026-09-15).
- A BTU pico that kept posting flow and dropped a thermistor channel
  was never noticed (2026-09-21).
- Timezone from settings silently beat the ops word on a house outside
  Eastern time (2026-09-18).
- A refused admin connect said connected then dropped, every cycle,
  with no cause (2026-09-05).

And one regression of the renovation's own, caught the same way: the
sieg valve's movement error was swallowed after the actor tier split,
so the valve silently never moved (2026-09-13).

## The record

Strong: the design hub `designs/spruce-unlimbo/primary.md` is current,
the seven finished spokes each name the executor section that absorbed
them, and the changelog carries the why for nearly every commit. Four
section-level Verified stamps exist, each tied to a commit and an
experiment.

Thin: maturity. All 25 files in `executor/` are Draft Pass 0, written
by Claude sessions alongside the code and never given a human review
pass. By the source-precedence rule the code wins every disagreement
with them. That is the review this note exists for.

Known stale points for the reviewer to start from:

- `executor/primary.md` (updated 09-12) still lists the hardware layout
  and the sieg loop as Open sub-specs; `hardware-layout.md` (818 lines)
  and `sieg-loop.md` exist.
- `environment.md`, `experimentation-rig.md` and
  `actor-class-upgrade.md` have not been touched since June.
- Six June designs speak of "this summer" and July: sieg-valve-exercise,
  sieg-semantic-harmonization, harden-dfr-i2c-recovery,
  harden-mqtt-half-open, non-electric-backup-doctor, poison-messages
  (the last has no Linear id).
- Two hubs split the renovation: spruce-unlimbo is the launch,
  spruce-settled (24 Draft spokes) is post-launch.
- "Spruce" names a production branch (`actual-spruce`) and a window
  branch (`jm/spruce-unlimbo`).

## The ask

Read the executor against the code and say where they disagree. For
each sub-spec: does it describe what the code does now; does it say
why; would it let someone rebuild the piece. Divergences are fixed in
the spec when the code is right and filed against the code when the
spec is right. A file that survives the review moves to Pass 1. The
entry point is `executor/primary.md` and its "Map of the spec"; the
files the renovation touched most are `hardware-layout.md`,
`components.md`, `control-hierarchy.md`, `local-control.md`,
`sieg-loop.md` and `scada-ltn-link-state.md`. Files over 300 lines are
read by section, not whole.
