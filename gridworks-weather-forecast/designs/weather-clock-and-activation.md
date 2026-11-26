# Weather clock and activation: one clock in the actor, one emission when a stream becomes active

Status: Accepted · Pass 1 · Updated 2026-11-26 · Linear: OPS-723

**EDD: yes** verified when a sim-box pod run with an empty weather
database shows each of the three minted bundles' own `latest-forecast`
within seconds of its own create, and a run with the hello time
coordinator shows the actor emitting on simulated hours and answering
each step with `sim.ready`.

## What this is

The weather actor reads plant time from one clock and emits each stream
once when the stream becomes active, then on its grid. The clock is wall
time on the fleet and the time coordinator's steps in a simulation.

## Why

Two gaps, one mechanism.

- **The lost first hour.** The scheduler fires only on the record's grid
  (hourly, one minute past for forecasts). A stream that has never emitted
  waits for its first grid slot like one that has. On the sim box the
  weather database starts empty on every play, so no forecast exists for
  up to an hour after the pod starts (OPS-716 row 27); each plant warns
  every 15 s and the scadas fill from the seasonal template. In prod the
  same hour is lost whenever a bundle is minted.
- **Simulated time.** gwbase delivers `sim.timestep` to every
  GridworksActor through `on_simulated_time` and answers with
  `send_ready`, and the weather actor has read the wall clock in five
  places and ignored the hook. The simulated test environment (OPS-40)
  paces services from a coordinator; the weather actor is ready for it
  when all its plant-time reads go through one clock.

The first build (`8650c01`) put both on main. The sim-box run of
2026-11-26 showed `bobcat` and `raccoon` emitting on activation and
`moose` waiting 29 minutes for the grid, and a review of the commit found
the cause and the other fixes in Plan 2 and Plan 4. The review's full
text, with line citations and rejected hypotheses, is in the OPS-723
comment of 2026-11-26.

## Decided

- **One clock, the scada's shape.** `gwwf/clock.py`: abstract `Clock`
  with `now()` in unix seconds and a blocking `wait(seconds)`;
  `WallClock`; `TimestepClock`, fed by `on_simulated_time`; `ManualClock`
  for tests. `GwwfSettings.clock_source` picks Wall or Timestep; Manual is
  injected in code only, so no env file puts a box on it. Plant-time reads
  (the tick, the gridpoint observation slot, the glitch stamp, the "now"
  an irradiance product is cut from) go through the clock; IO pacing
  (the archive send interval, HTTP retry pauses) stays on the wall.
- **Activation rule.** On the first tick after a scheduler build, a stream
  emits when it has no published state at or before the clock's now: it
  fires the latest grid slot at or before now, and the grid resumes from
  there. State stamped after now is dropped at build, so a clock that
  moved back finds a stream that has never emitted, with no replay toward
  a future slot. A stream with state at or before now waits for the next
  grid slot, which is today's behavior on a prod restart.
- **Published state is the stream's own.** For an observation stream it
  is the station's last published slot. For a forecast stream it is the
  bundle's newest forecast row that `latest-forecast` would serve, with
  `message_created_ms <= now`; the filter on now is applied before the
  max. Source products are the fetch cache and the stored rung. A product
  is shared by every bundle on its acquisition (method + locator), so it
  says nothing about activation. A bundle that emitted on the template
  rung has a row, so a later rebuild in the same period sends nothing
  more.
- **A channel joins at its station's next fresh observation.** An
  observation channel minted on a station that has already published is
  in the station's next message with a newer observation time. Nothing is
  built for this. Re-publishing the last observation with the new channel
  would send an observation time twice, and the stored last observation
  cannot tell a new channel from a channel the source reported no value
  for.
- **The scheduler is built on the main loop's thread.** At the first tick
  and after every accepted create, from the records and the clock's now.
  The create handler marks the scheduler stale instead of rebuilding it on
  the consumer thread, which also removes the cross-thread swap. Under the
  Timestep clock the actor has no time until the first step, so nothing
  can be built in the constructor.
- **A rebuild fires before it replaces.** `tick` runs the old scheduler's
  `run_pending(now)` first, then builds the new one, then runs it on the
  same now. A slot that fell between two ticks is fired by the old
  scheduler before the new one starts its cursors at now.
- **A failed build is retried.** A build that raises leaves the scheduler
  stale and is tried again on the first tick 30 s later, with a Warning
  glitch for each failed attempt. The previous scheduler, when there is
  one, keeps running in between. A restart while the database is
  unreachable recovers on its own.
- **Ready after the tick.** Under the Timestep clock, each step wakes the
  main loop; the tick rebuilds if stale, fires what is due, then sends
  `sim.ready` for that step. The coordinator paces the actor by waiting
  for it. `wait` returns on any step later than the last step ticked, so
  a step that arrives during a tick, or before the main loop first waits,
  is still ticked and answered. A repeated step (`is_new` false) is
  answered with `sim.ready` again. `send_ready` runs in a `finally`, so a
  tick that raises still answers.
- **Records are unchanged.** "Records broadcast once, at creation" stays
  as written in `delivery.md`; activation is about streams.

## Open

- **What sources a Timestep run uses.** NWS products are wall-time, so
  with sim time away from the wall every forecast falls to the template,
  and the "stamped after now" filter compares wall stamps to plant time.
  A run needs fakes or archive sources, and where they are configured is
  a design of its own. Decide before Plan 5.

## Out of scope

- gwbase's orchestrator drops a timestep earlier than the one it has, so
  a coordinator cannot step backward today and a running actor never sees
  its clock move back. The activation rule is a pure function of state
  and now, so it needs no change when that ships as its own gwbase issue.
- Persistence for the pod's weather database (OPS-716 open list). With
  activation an empty database costs nothing at start.
- A "stale on boot" refetch after a long prod outage. A consumer that
  needs a forecast sooner than the next slot pulls the read API.
- One stream that cannot be wired (a Method with no adapter) fails the
  whole build. No record has hit it.
- Bundles with different horizons on one acquisition overwrite each
  other's stored product. It needs a restart and a failed live fetch
  together, the bundle then falls to the template rung with a glitch, and
  the next live fetch heals it.

## Plan

1. `clock.py`, `clock_source`, the activation rule, the deferred build,
   `on_simulated_time` and `send_ready`, with the scheduler tests for the
   six activation cases and the clock tests. Done 2026-11-25 on
   main as `8650c01` (PR #20).
2. **One PR**, done 2026-11-26 on main as `9a59a24` (PR #21): published state from the bundle's own
   forecast rows, the old scheduler fired before a rebuild, the build
   retry. Tests: (a) two bundles sharing one acquisition, the second
   minted after the first fetched, both emit on their first tick; (b) a
   rebuild on the tick at or after a slot still fires it for existing
   streams; (c) a rebuild after a template-rung activation in the same
   period sends no second message; (d) a build that fails on the first
   tick then recovers, and emission resumes with no create.
3. **Spec.** `delivery.md` "Cadence" gains the activation sentence and
   the channel-join rule; its Open list takes the last two Out of scope
   items; the executor primary names the clock; changelog entry.
4. **Verify the pod clause.** `experiments/dev-sim` pins the new weather
   commit, the pod replays with an empty weather database, and each of
   `bobcat`, `raccoon` and `moose` is read from `weather-api`. The actor's
   log showed no publish lines on the 2026-11-26 run, so it is not the
   evidence.
5. **The Timestep slice**: the three "Ready after the tick" fixes to
   `wait` and `send_ready`, with tests for a step during a tick, a
   repeated step and a raising tick; then a laptop run with
   `GWWF_CLOCK_SOURCE=Timestep` and the hello time coordinator stepping
   hours.

## Do this next

Plan 2 and Plan 3 are on main as `9a59a24` (PR #21). Do Plan 4: with the
pin in `experiments/dev-sim/sources.txt` at that commit and pushed,
rebuild the weather image, replay the pod on the sim box and read the
three bundles from `weather-api`.
