# Speed up the scada tests

Status: Draft · Pass 0 · Updated 2026-10-28 · Linear: OPS-635

**EDD: no** build-out of the test suite itself, verified by the suite's
wall clock on the laptop and on GitHub CI.

> What this is: why the scada suite takes as long as it does, the cuts
> that bring it down, and the longer-run move to hybrid universes as the
> harness that takes over from part of the in-process suite. Also the
> team's branch-strategy reasoning, which belongs with the testing plan.

## The measurement

Measured 2026-10-28 on the laptop, before the roll tests were removed:

| | |
|---|---|
| tests collected | 1801 |
| wall clock | 5 min 28 s |
| slowest 25 tests | 164 s, half the run |
| GitHub CI, last five runs | 8 to 9 min each |

The slow tail is tests that wait on real timers, each a bound the code
reads from a constant or a setting:

- `test_roll_ltn.py`, six tests at about 10 s each. Removed 2026-10-28:
  tests of the temporary `scripts/roll.sh`, which leaves when the layout
  words are published.
- `test_ally_initialize.py`, the announcement waiting for the first
  forecast (about 10 s) and the ally judging once its inputs are in
  (about 5 s each).
- `test_relays_boot.py`, standby posture and every relay leaving
  Unknown (about 9 s each).
- `test_system_cold_live.py`, the cold house handing itself to the
  boiler or the heat pump (8 to 9 s each).
- `test_startup_contract_load.py`, a resumed or stored contract after a
  restart (5 to 7 s each).
- `test_power_meter.py`, a short gap in meter reads (7 s).
- `test_weather_source.py`, a slow service bounded by the timeout (5 s).

The other 1750 or so tests run in about two and a half minutes. CI adds
about three minutes of container and cert setup before pytest starts.

## The cuts

In order of payoff for effort:

1. **Settable timing bounds.** Each timer-bound test waits on a bound the
   code reads from a constant or a setting. Making the bound settable
   from the test (the field-bug rule's settable sim pin) cuts a 10 s wait
   to under a second without changing what the test asserts.
2. **Shared app fixtures.** Several files boot a full `ScadaApp` per fact
   (`test_pico_disabled.py` boots it eleven times for one layout). A
   per-module fixture, or one test with several asserts, keeps the
   coverage and drops the boots.
3. **Larger functional tests.** Combine runs of small tests on one
   actor into one test that walks the actor through its states and
   asserts along the way. Fewer boots, and a failure names the step.
4. **Randomized tests on the words and the assembly step.** Hypothesis
   over the sema snapshot classes: fuzz an ops word against a layout and
   expect either a clean load or a named refusal. Cheap to add and it
   finds what hand-written fixtures do not. Less payoff on the actors,
   where a random walk mostly rediscovers timing races.
5. **CI setup.** The two mosquitto containers and the cert setup cost
   about three minutes per run; the hybrid-universe harness below would
   absorb them by running against a dev broker instead.

## Hybrid universes as the harness

The direction: several hybrid universes designed to put the code through
its paces against simulated terminal assets under various conditions.
The EDD bar already says confidence comes from a real broker and real
timing; the in-process suite is where the wall clock and the backdoor
transport are faked. A simulated terminal asset under a scripted set of
conditions is the scada's equivalent of the field-check harness: one
verdict line per criterion, read off a window. Once two or three
universes exist, whole families of today's actor tests (hp-boss states,
the pump doctors, the pico cycler) become assertions on a journal
window, and the unit tests that remain are the fast ones about words
and assembly. The harness takes over from part of the existing suite as
it matures.

## Branch strategy

Decided at the team meeting before 2026-10-28: for now the team
standardizes on a single long-standing branch, `main`. Once a
beta-testing arena exists and the code on `main` is more mature, the
`dev` branch may well be introduced again. The testing plan above is
part of what makes that arena possible.

## Plan

- Done 2026-10-28: the roll tests removed.
- Next: the settable bounds, starting with `test_ally_initialize.py` and
  `test_relays_boot.py`, each with a before-and-after wall clock in this
  file.
- Then the shared fixtures, then the functional and randomized tests.
- The hybrid universes are their own design once the first simulated
  terminal asset exists.

## Open

- Whether `pytest-xdist` on CI is worth it before the cuts above; it
  hides the slow tail rather than removing it.
- Which of the timer-bound tests are EDD experiments in disguise and
  belong in the harness rather than the suite.
