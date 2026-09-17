# Pump doctors: full functional tests (spoke)

Status: Draft · Pass 0 · Updated 2026-09-15 · Linear: OPS-532

> What this is: the dist and store pump doctors (`actors/procedural/`)
> exercised end to end, from the monitor's trigger through the doctor's
> recovery attempts to the flow that proves the pump runs, on a plant
> that answers. Today's tests pin only the monitors' reads.

## What exists

- `DistPumpMonitor` decides recovery from three facts: any zone's derived
  heat-call reads calling, `dist-flow` stays below the flow threshold
  through the startup delay, and the doctor is not already running.
  `tests/actors/test_dist_pump_monitor.py` pins the zone-call read on
  both sim House0 pairs, including whitewire power through the derived
  generator (no signal, low power, high power).
- `StorePumpMonitor` decides from the store pump relay closed, the
  charge/discharge relay not charging, and `store-flow` below the
  threshold through the startup delay. No test.
- `DistPumpDoctor` / `StorePumpDoctor` run up to three attempts, each
  cycling the pump's command and waiting up to a bound for flow to
  appear, then reset when flow returns or alert when attempts are
  exhausted. No test on either.

## What a functional test needs

The doctors are judged by flow that follows a command after a delay,
so the test needs a plant that answers: a pump command that produces
`dist-flow` / `store-flow` readings after a startup lag, a failure mode
that produces none, and sped-up time for the startup delay and the
attempt bound. That is the simulated terminal-asset plant, not the
in-process app the suite boots (which has sensors but no physics), so
these tests live with the simulated houses once the plant runs, as the
hub's EDD bar says. Until then, the in-process suite can still pin:

- the store monitor's read (relay states + flow), the twin of the dist
  monitor test;
- each doctor's attempt bookkeeping and exhaustion alert with a stubbed
  `wait_for_*_flow`, so the counting and the reset are pinned before the
  plant exists.

## Do this next

Write the store monitor's in-process test, the twin of the dist one.
The plant-backed runs wait on the simulated houses.
