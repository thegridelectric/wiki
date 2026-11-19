# Sim time — running the scada on coordinator timesteps

Status: Accepted · Pass 1 · Updated 2026-09-25 · Linear: OPS-40

> What this is: simulated-test-environment spoke — what it takes for the
> scada to run its time from a time coordinator's `sim.timestep`
> messages instead of the wall clock. Holds the clock survey, the one
> clock the scada gets (three sources behind one interface, decided
> 2026-09-25), the migration of every raw clock read and every
> improvised test clock onto it, the bridge that keeps the existing
> links alive under harness pacing, and the risks of two clocks meeting.
> The time source itself is the gridworks-timecoordinator hello-world
> design (per-domain).

## Survey (2026-09-25): 519 live clock reads and waits, all wall time

Read against `jm/spruce-unlimbo`; the list behind the counts is
`scratch/basic-sieg/clock-survey.md`. Every plant-time clock in the
scada is wall time. `sim_time.py` records the latest timestep and
nothing reads it; the docstring of `is_simulated`
(`scada_app_interface.py:36-46`) says the scada reads the timestep
clock, and nothing does.

| Area | `time.time` | `asyncio.sleep` | `wait_for` | `datetime.now` | `fromtimestamp` | `monotonic` | `time.sleep` | Live |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| actors + app | 261 | 66 | 6 | 30 | 19 | 12 | – | 394 |
| drivers | 2 | – | – | – | – | 2 | 4 | 8 |
| gwsproto | 8 | – | – | – | – | – | – | 8 |
| tests | 47 | 9 | 53 | – | – | – | – | 109 |

Three kinds, mixed inside most files: **stamps** (about 105 sites put
`int(time.time()*1000)` into a `*Ms` field; eight more are gwsproto
`default_factory` stamps on `CreatedMs`-style fields), **durations**
(dwell and timer arithmetic, cadence alignment by `% period`), and
**waits** (the 66 sleeps). The heavy files: `ltn/ltn.py` 48,
`scada.py` 28, `leaf_ally/house0/all_tanks.py` 25,
`derived_generator.py` 22, `hydronic/house0.py` 19 (all stamps),
`pico_cycler.py` 18, `sieg_loop.py` 17, the two contract handlers 31,
`local_control/*` 35.

The tests already improvise clocks five ways: a test-local `Clock`
monkeypatched over a module's `time`
(`test_pico_channel_liveness.py:27`, `test_btu_open_thermistor.py:58`),
the global `time.time` patched (`test_pico_post_refusal.py:108`,
`test_temperature_producers.py:116`, `test_field_glitches.py:105`,
which also moves gwproactor's watchdog), and `datetime` patched
(`test_derived_generator_house0.py:86`, `test_hydronic_shared.py:255`).

gwproactor, upstream and not ours to change, has 33 clock lines, all
wall time: the watchdog, the io-loop and sync-thread pats, the link ping
and keepalive timing, persisted-event file names, log stamps. gwproto
defaults every event's `TimeCreatedMs` to wall time.

## The one clock (decided 2026-09-25)

One clock in the scada, `gw_spaceheat/clock.py`, abstract `Clock` with
three sources behind one interface; `sim_time` named one source and goes,
its paho listener becoming the transport inside `TimestepClock`.

- **Interface.** `now()` float unix seconds, the drop-in for `time.time()`;
  `now_ms()` returning the `UTCMilliseconds` format type, for every stamp;
  `local_now(tz)` for the TOU and hour-of-day reads; `async sleep(s)`. No
  `monotonic()`: IO durations are not plant time and stay outside the
  clock.
- **`WallClock`**: `time.time`, `asyncio.sleep`. The default and the fleet.
- **`TimestepClock`**: `now()` is the latest coordinator step and holds
  until the next; `sleep(s)` waits on a condition the listener thread
  signals until `now()` reaches the target. No interpolation with wall
  time between steps. `now()` before the first step raises; no fall-back.
- **`ManualClock`**: a stored value the test moves with `advance(s)`,
  waking sleepers whose target has passed. Never touches wall time.
- **Selection.** `ScadaSettings.clock_source`, an enum `Wall | Timestep`,
  default `Wall` from a names constant. `Manual` is not a settings value:
  it is injected only in code, so no env file can put a box on it.
  `Timestep` refuses to start on a layout with no simulated component;
  `is_simulated` is a precondition, not the switch. The source is logged
  at startup.
- **Hook-up.** An abstract `clock` on `ScadaAppInterface`, implemented by
  the scada apps and, through a small shared interface, the LTN app.
  Actors read `self.services.clock`; none keeps a copy. The app takes an
  optional `clock` for tests: `ManualClock(start_s=…)`, `advance(…)`,
  then yield to the loop. `ShNodeActor.await_with_watchdog` becomes the
  one place that waits with pats: the deadline on the clock, the pat
  interval on wall time.
- **Stamps.** Every wire and journal stamp goes through `now_ms()` so the
  journal lines up with the harness. The eight gwsproto `default_factory`
  stamps stay wall unless the defaults are removed and the fields made
  required (a gwsproto decision). gwproto's `TimeCreatedMs` and
  gwproactor's file names stay wall time as transport metadata.

## Migration, in order, whole files at a time

1. ✅ `clock.py`, the interface property, `ManualClock`, `tests/test_clock.py`
   (from `test_sim_time.py`); the keepalive ping is an `on_step`
   callback of `TimestepClock`. The LTN app is not on the interface yet.
2. The sieg package, during its rewrite (spruce-unlimbo `basic-sieg.md`
   change 2): all 17 sites. Valve travel computes from `now()` at relay
   transitions, not from one-second sleep slices, which would each wait a
   full step.
3. Stamps only, about 105 mechanical sites: `hydronic/house0.py`,
   `hydronic/shared.py`, `command_node`, `command_reply`, `five_v_boss`,
   `hp_boss`, `scada_data`, the stamp lines in `relay`, `pico_cycler` and
   the sensors.
4. Control dwells: `leaf_ally/*`, `local_control/*`, `derived_generator`.
   Dwells, TOU and loop sleeps convert together per file.
5. Scada cadence and contracts: `scada.py`, both contract handlers,
   `ltn.py`, both processes in one change.
6. Liveness and freshness last (`api_*_module`, `pico_liveness`,
   `glitch_limit`, `power_meter`, `scada_data.py:225`), with the stamps
   that feed them.
7. The five improvised test clocks replaced by `ManualClock`.
8. Never: gwproactor; device and bus waits (`relay.py:517,722`,
   `zero_ten_outputer.py:261,426`, `i2c_thermistor_reader.py:237`,
   settle sleeps, driver `time.sleep`); read-latency measurements; the
   LTN's child-process deadline and solve timing; all 53 test `wait_for`
   timeouts; dashboard formatting.
9. Then a `ci.sh` check forbidding bare `time.time(` and `datetime.now(`
   under `actors/`, with the IO files listed as exceptions.

## Where two clocks meet

- **A stamp on one clock against a dwell on the other.** Channel
  freshness is `time.time() - stamp` (`scada_data.py:225`,
  `power_meter.py:392`, `multipurpose_sensor.py:265`, the flow module's
  flatline): with simulated stamps and a wall comparison every channel is
  stale by the offset, or fresh in the future. Each converts with the
  stamps that feed it.
- **Contract times cross processes.** The LTN builds contract ends, the
  scada compares against them (`contract_handler.py:90,118`,
  `scada.py:1138`). Both apps on one source, from one setting, in one
  change.
- **The watchdog against simulated sleeps.** The watchdog pats on wall
  time (`gwproactor/watchdog.py:113`). A `clock.sleep(900)` in a paused
  simulation lasts as long as the pause, so a bare clock sleep in a
  monitored actor trips the watchdog; `await_with_watchdog` is the only
  wait a monitored actor makes.
- **Coarse steps.** Under one-minute steps every sub-minute cadence
  rounds up to the step: the sieg tick, the sim-pico ticks, the cadence
  hiccups in `scada.py:1381` and `ltn.py:1614`. Each loop's period is
  checked against the step.
- **A half-converted file** (a dwell started on one clock, checked on the
  other: `all_tanks.py:337/453`, `all_tanks_tou.py:221/293` today) gives a
  wrong dwell and no error. Whole files, each pinned by a `ManualClock`
  test that advances past its dwell.

## The bridge (Jessica, 2026-06-11): existing scada/LTN in the harness

The links stay on wall clock whatever the plant-time source: gwproactor's
ping, keepalive and watchdog timing never converts. Under harness pacing
they are kept happy this way:

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

## The bridge listener (built 2026-06-11, branch `jm/sim-time-bridge`)

The timestep→ping trigger lives in a **small scada-side hook** (the
open question, resolved): `gw_spaceheat/sim_time.py`, a minimal paho
listener created behind `is_simulated` in the Scada actor. It
subscribes to the MQTT form of the broadcast key
(`rjb/d1-tc/time/sim-timestep`), parses the JSON by hand (OFI
docstring: deliberately bypasses the gwsproto codec; dies in the
uv/AllyLink rebuild), keeps a monotonic latest-sim-time, and pings
upstream on each timestep. Broker-less unit tests cover advance /
monotonic-guard / garbage paths.

**The crossing needs one harness-owned broker binding:**
`timemic_tx → amq.topic` (the MQTT plugin's exchange) — without it the
TC's AMQP broadcasts never reach the MQTT side. That binding is
harness provisioning glue (experimentation-tools territory), not scada
code. Not yet wired into `ScadaLiveTest`; first live bridge run =
tc-hello + the binding + a sim scada, watching the link stay active.

## Verified (2026-06-11): the crossing reaches MQTT

Verified · Pass 1 · Updated 2026-06-11 · Reviewed 2026-06-11 (experiment
`sim-time-first-bridge-run`, `experiments/logbook.md`)

The first live bridge run confirmed, against `gw-dev-rabbit`: `tc-hello`
(`d1.tc`) broadcasting `sim.timestep` over AMQP crosses to MQTT via the
gwbase topology binding (TimeCoordinator publish exchange → `amq.topic`,
key `rjb.#`) and arrives on `rjb/d1-tc/time/sim-timestep`; a real
scada-side `SimTimeListener` receives every step and tracks it
monotonically. The crossing and the scada receive path are proven end to
end on a real broker. **Scoped:** this does NOT yet cover the real LTN's
own sim-time path, nor the real scada↔LTN links driven off coordinator
time — the run used a stand-in LTN listener and harness ping/acks. Those
stay open below.

## Open

- First live bridge run: **DONE for the crossing** (Verified above). What
  remains is fidelity — wire tc-hello + the crossing into `ScadaLiveTest`
  so the run is repeatable with the *real* scada/LTN apps (not stand-ins),
  climbing toward the outcomes that would make it shine: the LTN's ASCII
  dashboard showing live temps + relay/heat-pump + power under sim time,
  and/or a CSV of an hour of simulated scada telemetry under sped-up
  coordinator time (or both).
- The LTN side of "ping/ack in both directions" (the hack MQTT LTN
  needs the symmetric trigger, or its own keepalive suffices — observe
  first).
- Ready-barrier pacing (actors confirm processing before time
  advances) — gwbase bundles `Ready`; semantics to mine from the
  timecoordinator `legacy` branch.

## Do this next

Step 2 of the migration with the sieg package, on the spruce-unlimbo
branch, since that package is being rewritten now and its tests are the
first on `ManualClock`. Then the experiment this spoke is
verified by: the scada on `Timestep` against the time coordinator on the
dev broker, its journal stamps advancing with the steps and a sieg dwell
elapsing in coordinator time, kept under `experiments/` as the
reproducer.
