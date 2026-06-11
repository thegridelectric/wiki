# Sim time — running the scada on coordinator timesteps

Status: Draft · Pass 0 · Updated 2026-06-11

> What this is: simulated-test-environment spoke — what it takes for the
> scada to run its time from a time coordinator's `sim.timestep`
> messages instead of the wall clock. Holds the 2026-06-11 code census
> (investigation against gridworks-scada) and the two-track strategy:
> a pragmatic bridge for the existing proactor scada/LTN, and the real
> conversion for the redo. The time source itself is the
> gridworks-timecoordinator hello-world design (per-domain).

## Census (verified 2026-06-11): the scada reads the clock raw, everywhere

**345 clock reads** (317 `time.time()`, 20 `datetime.now()`, 7
`time.monotonic()`), 94% in `gw_spaceheat/actors/`. **No clock seam
exists**: no injected time provider, no `now()` helper, nothing on
`ScadaAppInterface`; tests run on the system clock (freezegun installed
but unused). Periodic work is 71 `asyncio.sleep` while-loops whose
sleep durations are computed FROM `time.time()` (e.g.
`scada.py:1404,1414` report/snapshot cadences). No trace of any time
coordinator, `sim.timestep`, or simulated-time concept in scada or
gwsproto. By purpose: ~120 telemetry timestamps · ~95 cadence
calculations · ~70 timeouts/deadlines (`ltn/ltn.py:495-497`,
FSM/watchdog timers) · ~60 calendar/TOU logic
(`datetime.now(tz).hour` peak windows, `buffer_only_tou.py:213-227`,
contract boundaries `ltn/ltn.py:932-937`) · ~15 perf instrumentation.

## Full conversion: five mechanisms (for the redo, not the bridge)

1. **Clock seam** — a `Clock` on the app interface; replace ~300 raw
   reads mechanically. Cheap, and worthless alone (sleeps still wall).
2. **Timestep-driven advance** — subscribe to `sim.timestep`
   (`SimTimestep` is already bundled in gwbase 0.5.2), update the
   clock state on receipt.
3. **Cadence decoupling** — the 71 sleep-loops become event-driven:
   on each timestep, fire whatever `next_*_second` has come due. The
   structural piece.
4. **Timeout/deadline rewrite** — deadlines computed and checked in
   sim time; some patterns ride the clock seam, watchdog-adjacent ones
   do not (below).
5. **Calendar re-anchoring** — TOU hours, contract windows derived
   from sim unix-ms + timezone, not `datetime.now()`. ~20 sites.

Verdict: full conversion of the EXISTING scada is a rewrite-scale
intervention (~40-50% of actor files for full fidelity). It lands
naturally in the AllyLink/comms redo, where the two small machines and
the new keepalive are being built anyway — not as a retrofit of
Andy's proactor.

## The bridge (Jessica, 2026-06-11): existing scada/LTN in the harness

For the existing proactor scada + LTN, do not convert time. Run them
at wall clock, paced so the links stay happy:

- **Snapshot frequency to 1 minute** for the simulation harness, and
- **1-minute timesteps** from the time coordinator **trigger the
  ping/ack sequence in both directions**, keeping each side's
  link-state machinery fed at the cadence it expects.

This accepts the link-state doc's finding that snapshot cadence is
unwittingly load-bearing for liveness, and makes the harness drive
liveness *deliberately* at the same cadence — the timestep doubles as
the keepalive trigger.

## The watchdog/pat map (verified 2026-06-11, gwproactor v4.1.13+jm1 — the installed stack both scada and the hack MQTT LTN run)

- **WatchdogManager** (`gwproactor/watchdog.py:132-145`): each
  monitored actor/thread registers its own `timeout_seconds`
  (convention: 2.1 × its loop interval — e.g. a 40 s loop gets an
  84 s deadline); pats are `PatInternalWatchdogMessage`s stamped with
  `time.time()`; the manager samples every `_seconds_per_pat` (9 s;
  monitored timeouts must exceed half that). **One expired name shuts
  down the whole process** (`InternalShutdownMessage`). ~45 pat call
  sites across scada actors (i2c bus 40 s, gpio/thermistor 120 s,
  relay ~80 s, api modules 30 s).
- **IOLoop + sync threads** (`io_loop.py:171-185`,
  `sync_thread.py:233-271`): pat every `PAT_TIMEOUT/2` (10 s) from
  their own run loops; 20 s timeout.
- **External watchdog** (`external_watchdog.py:44-53`): every clean
  `_check_pats` cycle also pats systemd (`systemd-notify WATCHDOG=1`)
  — only active under `<NAME>_RUNNING_AS_SERVICE=1`; not in the
  harness.
- **Traffic-coupled timers** (not process-killing): 5 s ack timeout
  per AckRequired send (`links/acks.py:38-73`) — unacked → re-send
  loop (the poison-flap mechanism); 60 s MQTT link ping
  (`link_manager.py:662-675`); 60 s LTN `SlowContractHeartbeat`
  (`contract_handler.py:324`, hardcoded).

**Verdict for the bridge: the internal watchdogs are loop-driven, not
traffic-driven — so the bridge as proposed is watchdog-safe.** Actor
loops keep iterating on their own wall-clock `asyncio.sleep` timers
regardless of how the harness paces message traffic; pats keep
flowing. What the bridge MUST NOT do: pause/SIGSTOP/step the
processes (any monitored deadline blown kills the process), and it
must keep both ends responsive enough that 5 s acks succeed (a dead
or slow LTN turns AckRequired sends into the reupload flap). The
1-minute timesteps then only need to do what Jessica's note says:
trigger ping/ack both directions and align with the 1-minute snapshot
cadence so link state and contract heartbeat stay fed.

**Where the danger actually lives: the full conversion, not the
bridge.** The moment cadence decoupling (mechanism 3) converts actor
loops from `asyncio.sleep` to timestep-driven iteration, pats stop
flowing on wall clock while WatchdogManager keeps judging on
`time.time()` — process suicide by design. Watchdog conversion is
therefore part of mechanism 3, not an afterthought: either pats and
the manager's clock both move to sim time, or sim mode inflates
monitored timeouts.

## Open

- Whether the bridge's timestep→ping trigger lives in harness glue or
  a small scada-side hook.
- Ready-barrier pacing (actors confirm processing before time
  advances) — gwbase bundles `Ready`; semantics to mine from the
  timecoordinator `legacy` branch.
