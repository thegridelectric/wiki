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
knows what it is. Layouts are authored in Sema and the scada boots from
a layout word, an operational-params word and a deed. Actors read the
layout instead of hard-coded name rosters. Relays, the DAC and
thermistors resolve their pins from device-type records over one I2C
bus, with a simulated backend. One liveness rule covers the pico
actors, liveness is judged per channel, and a lost sensor reads
unknown. The sieg loop is a package and a command node that owns its
two relays. Command nodes ack or nack their boss. Temperature is a
record that carries its unit, and the timezone and on-peak hours come
from the ops word. The weather forecast comes from the weather service,
not from the scada's own pull.

## Numbers, `jm/spruce-unlimbo` from 2026-07-01

| | |
| --- | --- |
| Commits | 214 (Jul 20, Aug 26, Sep 132, Oct 36 to the 7th) |
| Changelog entries | 218 |
| App code `gw_spaceheat/` | +11.5k / −13.4k lines, net smaller |
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
