Status: Draft · Pass 0 · Updated 2026-06-11

# Experiments logbook (gridworks-scada)

Terse, dated ledger of real-condition experiments — why each was run and
what it found. The convention (kept reproducer · verified claim into the
spec · raw data out of git) is the experimentation-tools spoke, "The
record"; the why-it-matters is GridWorks_CLAUDE "The verification bar".
One entry per run, newest at top. The durable claims live in the specs
this points at, not here.

---

## 2026-06-11 — SimSensor outputs exactly what we want (first sim-actor step) · PASS

**Why:** the simulated-actors "DO THIS NEXT" — prove a SimSensor can output
exactly the sensor channels/units we want, witnessed on a broker, before
wiring the full scada loop.

**Found (PASS):** a thin SimSensor, configured **generically** from the
layout's sensor channels (`house0.imaginary`), published a reading per channel
on the sensor broker (mosquitto :1883); an independent observer witnessed
**20/20 expected channels, 0 missing, 0 extra** — 3 Power, 8 Temperature, 9
Voltage, each with the right quantity. The generic-config idea holds: one
publisher, any unit, any `AboutNodeName`, no per-device drivers.

**Not yet (next fidelity rungs):** publish the *real* `SyncedReadings` type on
the *real* channel topics (not a `sim/sensor/...` topic); a separate sensor
*rabbit* broker (so killing it tests a data outage); drive values from a plant
instead of scripted; then wire into the real scada + LTN dashboard.

**Reproducer:** `sim-time-experiment/sim_sensor_experiment.py` (SimSensor +
observer, self-verifying PASS); result in `sim_sensor_out/result.json`.

## 2026-06-11 — Migrating a stale layout: an accidental sema teaching story

**Why (unplanned):** the dashboard experiment needed a loadable House0; the
real `oak.generated.json` (Feb) was stale, so migrating it became an EDD
experiment by accident.

**Found — the whole sema argument in one migration, both sides.**

*Where I DID just use the sema (the actual moment):* oak's data channels
lacked the new `data.channel.gt` `Quantity` field. My first instinct was
archaeology — I started hand-building a `TelemetryName→Quantity` map by
scraping current layouts. It broke on the first uncovered name,
`GpmTimes100`. The fix was to stop scraping and **just use the sema**:
"rather than hand-map it, let me use `UNIT_TO_QUANTITY` (the canonical
projection Axiom 2 itself enforces) to get the Quantity" —
`UNIT_TO_QUANTITY[TelemetryName.GpmTimes100]` → `FlowRate`, authoritative,
never misses a name. Same move for device-type ids
(`CACS_BY_MAKE_MODEL[MakeModel]` → canonical UUID) and every stale `Version`
(the type's own literal names the target). The tell: the moment a migration
makes me *scrape* instead of *look up*, the thing I'm scraping for wants a
sema home.

*Where there was no sema (the gotcha, costly, less sure):* the derived-channel
**strategy names** (`linear-fit`→`affine`, `layer-by-layer`→`system-model`)
have no authoritative record of what became what, so I had to **infer** the
rename by diffing current vs stale layouts.

Same task, two worlds: sema-typed = authoritative migration; dangling =
archaeology. `oak`'s deeper derived-channel rework (new required
`EmissionMethod`/`EmitPeriodS`) is a slice of the layout-augments fold, not
a hand-patch — so we stopped grinding and used a current layout instead.

**Artifact kept:** `make_imaginary_layout.py` — the wand that makes a real
layout imaginary (fresh instance UUIDs; canonical device-type UUIDs;
refreshes stale versions; validates by loading). Proven on
`house0-layout.json` → loadable imaginary House0 (103 instance ids
re-randomized, 6 device-type ids canonicalized). Lives in
`sim-time-experiment/`. The kind of reusable tool EDD throws off.

## 2026-06-11 — Sim-time first bridge run (crossing → scada + LTN stand-in)

**Why:** the sim-time spoke's open "first live bridge run" — does the real
time coordinator's `sim.timestep` actually reach MQTT subscribers through
the gwbase crossing, and do scada-side listeners receive it?

**Found (VERIFIED, scoped):** the crossing works. `tc-hello` (`d1.tc`)
broadcasting `sim.timestep` over AMQP → gwbase topology binding
(TimeCoordinator publish exchange → `amq.topic`, key `rjb.#`) → MQTT topic
`rjb/d1-tc/time/sim-timestep`. A real scada-side `SimTimeListener` received
every step, monotonically; an independent observer recorded all traffic.
11 broadcasts crossed; scada listener got 9, a second stand-in listener 10
(edge-of-window connect timing). Claim landed in the sim-time spoke.

**Not verified (fidelity gaps → next iterations):** the real LTN running
its own sim-time path (used a stand-in `SimTimeListener`); the real
scada↔LTN links driven off coordinator time with the real keepalive (used
harness ping/acks). North stars for "really shines": the LTN's ASCII
dashboard showing live temperatures + relay/heat-pump + power under sim
time, and/or a CSV of an hour of simulated scada telemetry produced under
sped-up coordinator time.

**Reproducer:** `harness.py` + observer, currently at
`/Users/jessica/GridWorks/sim-time-experiment/` — graduates into the scada
repo `experiments/` once it reaches dashboard/CSV fidelity (kept in the
workspace while it is being raised to the bar, to avoid committing a
stand-in). **Raw bundle:** `sim-time-experiment-20260611-1825.zip`
(provenance, out of git). **Broker:** `gw-dev-rabbit` MQTT `:1885`.
