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

**Primary concern: the proactor's watchdog pats.** The proactor has
internal watchdog/"pat" machinery on wall-clock timers; a harness that
pauses, steps, or outruns wall time can starve a watchdog and kill a
process that is perfectly healthy in sim terms. The pat semantics are
explicitly on the full-proactor-analysis capture list
(`../../executor/scada-ltn-link-state.md` "DO THIS NEXT") — map every
watchdog (what pats it, what timeout, what happens on starvation)
BEFORE the harness runs the old stack on coordinated time. Open until
that analysis lands.

## Open

- The watchdog/pat map (above) — the gating item for the bridge.
- Whether the bridge's timestep→ping trigger lives in harness glue or
  a small scada-side hook.
- Ready-barrier pacing (actors confirm processing before time
  advances) — gwbase bundles `Ready`; semantics to mine from the
  timecoordinator `legacy` branch.
