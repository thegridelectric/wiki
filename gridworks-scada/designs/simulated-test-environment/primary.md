# SCADA simulated test environment (hub)

Status: Accepted · Pass 1 · Updated 2026-06-11 · Linear: OPS-40

**▶ Active spoke: `simulated-actors.md`.** SimSensor experiment **step 1
passed** (a SimSensor output exactly the 20 sensor channels/units, witnessed).
The **plant I/O contract is now specified** (2026-06-12): the closed loop with
LocalControl — channels the plant emits, relay commands it consumes, the
`usable`/`required` energy DAG. Two settled decisions: the plant's source word
is **`sim.plant.flux`** (`sim-sensor-words` spoke — the plant emits, the sensor
reads; SimSensorActor converts it to `synced.readings`), and the forecast inputs
are **a secret weather file + `flo.params.house0.json`** (`heating_forecast` is
derived from them, not supplied). Current move: mint `sim.plant.flux`
(`/make-sema-word`), build the plant + SimSensor in gwta, then the
10-min-no-watchdog scada + dashboard run. Detail in that spoke's "DO THIS NEXT".
(Convention: while a design is active, its active spoke is highlighted here at
the top of the hub, so it can't get lost across files.)

> What this is: a design for a robust simulated test environment for the SCADA —
> simple simulated terminal assets plus simulated sensor drivers (with a "cheat"
> mode for direct value injection) that otherwise exchange data over the dev
> Rabbit broker, with the simulated terminal assets built on gridworks-base.
> Ported from Linear **OPS-40** (which began as a narrower "run dev scada
> without crashing / `gen_orange` layout" task — mostly done — and is reframed
> here into the broader goal). Spokes: `simulated-actors.md` (simulated relays
> + i2c thermistor reader; moved here from spruce-unlimbo 2026-06-11, where it
> had been executing for momentum — this design now leads) and
> `experimentation-tools.md` (replicable real-broker experiment toolset;
> absorbed from world/designs/experimentation-harness 2026-06-11 — all
> simulation/experimentation work consolidates here);
> `sim-sensor-words.md` (the sema vocabulary for simulated sensor data —
> joint session pending; moved from the closed hello-world design); and
> `sim-time.md` (scada on coordinator timesteps — code census, the
> 1-minute bridge for the existing proactor stack, watchdog-pat gate).

## Elevated to the top — comms-first (Jessica, 2026-06-11)

The simulation harness is now the top of the scada work. The reason: the
big projects ahead (the AllyLink / proactor-link redo — see
`../executor/scada-ltn-link-state.md`) need testing by experiment, the way
we want to test, so the harness comes first. And we might as well set up
the MVP the way it will work when we are really modeling terminal assets.
For now, most of what we will want to test is comms infrastructure.

**Start: a terminal asset on gwbase emitting to the dev rabbit broker.**
The MVP's "physics" is a traffic generator with a seam:

- A `GridworksActor`-based GNode (GNodeClass `TerminalAsset`) that connects
  to dev rabbit and emits a couple of synthetic channels at a fixed cadence
  — constant or sawtooth, no thermodynamics. The value source is the seam
  where real modeling lands later.
- The comms-test knobs are first-class features, not extras: tunable
  cadence/volume, scriptable silence (provoke `awaiting_peer` and the
  keepalive paths), burst mode, optionally deliberate poison payloads.
  These are the experiment levers for evaluating the old proactor link
  against the new AllyLink, on the same rig.
- Harness wiring: `ScadaLiveTest` already brings up LTN + SCADA on a real
  rabbit broker; the terminal asset joins as the third participant.

**The hybrid scenario.** One dev rabbit broker, two protocol faces: gwbase
actors (terminal assets, LTNs, later aggregators) are AMQP-native on the
routing fabric; scadas — real or simulated — ride the MQTT plugin, exactly
as prod does on gw-dev-rabbit. A sim scada is not a mock: it is the real
scada process with an all-sim layout, connecting the way a house does. Per
simulated house: one terminal-asset GNode + one sim scada + one LTN. Hybrid
means real houses' scadas land on the same broker beside the sim houses.
Note the rig exercises **both AllyLink tracks at once**: each sim scada is
a plain 1:1 child against a real rabbit broker, while the LTN side of the
same broker has many parents talking to many children — FULL-AllyLink
territory.

**The harness is also the spec-building instrument.** The 2026-06-10 live
run (full ltn/scada on dev rabbit, ~5 minutes, wire capture + both process
logs) produced essentially all the productive material in
`../executor/scada-ltn-link-state.md` — observation-driven spec building.
The rig makes that a one-command cadence: bring up the stack, capture,
write what IS, let divergences drive design.

**Deferred canonization (todo — NOT before the harness works):** after
this simulation sprint ships, add one or two lines to `GridWorks_CLAUDE.md`
defining **Verified as run against the test harness**, with a longer
document elsewhere about what full test-harness runs actually mean.
Canonize only after the sprint finishes.

## Problem

We do not have a robust test environment for the SCADA. Today's options are
the real hardware (slow, physical, one-house-at-a-time) or partial unit tests.
We can't cheaply stand up a *whole* heating system — terminal asset + sensors +
SCADA control — in software and exercise it end to end, which is what we need
to test control logic, layouts, and fleet behaviour with confidence (and is a
prerequisite for the hybrid real+simulated fleet vision).

The target: **extremely simple simulations of the terminal asset** plus
**simulated drivers** that read "sensor" data, where a simulated driver either
(a) listens over the **dev Rabbit broker** used in testing, or (b) has a
**cheat option** to supply its own values directly (no broker round-trip). The
simulated terminal assets are built on **gridworks-base**.

## Current state — scaffolding already exists (2026-06-07)

This design generalizes existing seams rather than starting fresh.

- **`is_simulated` flag** — `ScadaSettings.is_simulated`
  (`gw_spaceheat/actors/config.py:62`), read across actors to skip real
  hardware: `i2c_relay_multiplexer.py:68,94` swaps in `SimulatedPin` objects;
  `i2c_zero_ten_multiplexer.py:173,199` branches the 0–10 V output;
  `sh_node_actor.py:98,114` skips setpoint/temperature reads; `ltn/ltn.py:219,269`
  injects a hardcoded 60 °F tank temp.
- **Driver abstraction + MakeModel-dispatch factory** — abstract bases
  `MultipurposeSensorDriver` (`drivers/multipurpose_sensor/…:15-32`) and
  `PowerMeterDriver` (`drivers/power_meter/…:19-60`); factories dispatch on
  `component.cac.MakeModel` (`actors/power_meter.py:93-109`,
  `actors/multipurpose_sensor.py:61-90`). **A simulated driver already exists:**
  `GridworksSimPm1_PowerMeterDriver` (MakeModel `GRIDWORKS__SIMPM1`) returns
  fake values — the precedent for both "simulated driver" and "cheat" modes.
- **Simulated layout components** — `layout_gen/simulated_tanks.py` builds tank
  modules from `SimPicoTankModuleComponentGt`; `api_tank_module.py:42-44`
  accepts the sim component.
- **Integration harness** — `tests/utils/scada_live_test_helper.py` `ScadaLiveTest`
  (extends `TreeLiveTest` from `gwproactor_test`) already starts LTN + SCADA
  over a **real Rabbit broker** with `child1_simulated=True`, and polls async
  predicates. The dev broker is provisioned via gridworks-base
  (`tests/_stubs.py` `provision_topology`/`declare_topology`; SCADA rides the
  Rabbit MQTT plugin, base is AMQP/pika).
- **gridworks-base simulation primitives** — `GridworksActor` (GNode actor base),
  and test stubs `GNodeStubRecorder` / `TimeCoordinatorStubRecorder`
  (`tests/_stubs.py`) that already act as synthetic GNodes; `make_g_node_json`
  factory (`tests/conftest.py:34-71`).

**Terminal asset** is a GNode *role* ("avatar for a real-world transactive
device"), not a scada actor; the SCADA reports on its behalf via
`terminal_asset_alias` (`layout_gen/layout_db.py:232-233`). A *simulated*
terminal asset is therefore a GNode actor (built on gridworks-base) that
publishes synthetic telemetry.

## What's missing (the design's scope)

The gaps between today and a full sim environment:

### 1. Simulated drivers for every sensor type (with cheat mode)
- Generalize the `GRIDWORKS__SIMPM1` precedent: a simulated driver for each
  abstraction (multipurpose/thermistor, power, flow, relay, 0–10 V).
- Each simulated driver supports two modes:
  - **broker mode** — subscribe to synthetic telemetry on the dev Rabbit broker
    (values produced by the simulated terminal asset), or
  - **cheat mode** — return caller-supplied values directly (no broker), for
    fast deterministic unit tests.
- Plug in via the existing MakeModel dispatch (add `GRIDWORKS__SIM*` values via
  the Sema word process) — no new factory machinery.
- **Sharpened (2026-06-11):** the MakeModel-dispatch mechanism here stands,
  but the seam is now decided at the **device boundary with the plant
  *pushing*** (not actors polling drivers, and not a driver-class hierarchy)
  — see the `simulated-actors` spoke. Read "simulated driver" below as the
  older framing of the same MakeModel seam.

### 2. Simulated terminal asset on gridworks-base
- A `GridworksActor`-based synthetic GNode (GNodeClass `TerminalAsset`) that
  models an *extremely simple* heating system and **publishes synthetic sensor
  telemetry** over AMQP/the dev broker for the simulated drivers to read.
- "Extremely simple" first: plausible tank temps, flows, power that respond
  coarsely to SCADA relay/voltage commands — enough to exercise control paths,
  not a thermodynamic model. Richer physics is a later iteration.
- Reuse the `GNodeStubRecorder` / `make_g_node_json` patterns.

### 3. A complete simulated layout
- Extend `simulated_tanks.py` into a full **all-simulated hardware layout**
  (every component a `Sim*`/`GRIDWORKS__SIM*`), so `ScadaLiveTest` can bring up
  a whole simulated house in one call.

### 4. Harness wiring
- Add the simulated terminal asset as a participant in `ScadaLiveTest`
  alongside LTN + SCADA, and expose the cheat-injection seam to tests.

## Increments (reordered 2026-06-11)

1. **Terminal-asset comms rig** — the comms-first MVP above (gwbase GNode
   emitting to dev rabbit; comms-test knobs; `ScadaLiveTest` third
   participant). This is the start.
2. **Simulated actors** — simulated relays + i2c thermistor reader +
   scriptable heat-call, so the Nolan scada (then House0) runs fully
   locally and the falling-edge setpoint evaluation can be exercised.
   Full slice in the `simulated-actors.md` spoke (moved from
   spruce-unlimbo 2026-06-11; still serves that design's merge gate —
   "testing green for BOTH layouts" — which now rides this harness).

## Where this stands & what's next (2026-06-11)

A working session moved this design from scaffolding toward a first real
experiment. Captured here so the open work is durable, not a phantom list.

**Delivered (this session):**
- **First live bridge run — the crossing is Verified.** A real `tc-hello`
  broadcasting `sim.timestep` over AMQP reaches MQTT subscribers and a real
  scada-side `SimTimeListener` receives every step. Scoped Verified claim in
  the `sim-time` spoke; worked example in `../../experiments/logbook.md`.
- **The sim seam is decided** — device boundary via a `Sim*` `MakeModel`, the
  plant pushes on `AsyncCaptureDelta`, one flat actor branch, no driver
  hierarchy, sensors outside the command tree, controls as leaves. Full
  statement in the `simulated-actors` spoke.
- **The make-imaginary wand** (`sim-time-experiment/make_imaginary_layout.py`)
  — turns a real layout imaginary (fresh instance UUIDs, canonical
  device-type UUIDs). This is the tool behind "a complete simulated layout"
  (#3) and the sim/real identity boundary. Proven on House0.
- **Executor specs landed:** `executor/components.md` and
  `executor/hardware-layout.md` (the device + layout model as it is today,
  warts surfaced). And the **EDD** verification bar + the experiments-record
  convention (`GridWorks_CLAUDE.md`, the `experimentation-tools` spoke).

**Active next — the EDD worked example in progress:**
- **The dashboard experiment.** Real `ScadaApp(is_simulated)` + `LtnApp` on
  the dev rabbit, a tanks-only plant pushing temps, the LTN ASCII dashboard
  rendering live. **Done-when: 10 minutes with zero watchdog-pat deaths**
  (which also Verifies the `sim-time` spoke's "bridge is watchdog-safe"
  claim). Run on the wanded current House0 fixture
  (`house0.imaginary.json`) for now. Then the fidelity ladder — an hour of
  CSV under *sped-up* time needs cadence-decoupling, which is the comms
  redo, not the bridge.

**Dependencies / blocked work (owned elsewhere — recorded so they don't get
lost):**
- **The real-house layouts are stale across the layout-augments rework.**
  Migrating `oak` hit strategy renames + new derived-channel fields that are
  a slice of the fold, not a hand-patch — so experiments use the wand on
  current fixtures until the fold lands. Owner: **spruce-unlimbo Chunk B**
  (the layout pipeline) — folding `jm/layout-augments` into
  `jm/spruce-unlimbo` is a ~4–6 h hand-reconcile (relay.py moved+modified,
  `layout_db` architectural, `RelayActorConfig`/`SpaceheatNodeGt` both
  extend); a scout map exists.
- **Sema:** close `gw.nolan.layout` (draft-but-complete at
  `sema/definitions/types/gw.nolan.layout/000.yaml` → finalize + codegen +
  validate, after the fold); and **the derived-channel strategy names need a
  sema home** — they dangle, and the migration showed the inference cost of
  that. New `Sim*` MakeModels are also sema words (`/make-sema-word`).
- **Future:** a DB backfill of real `gw.house0.layout`s **respecting
  uniqueness** — the wand is the seed tooling (instance ids unique,
  device-type ids canonical/shared).

## Open questions

- **Cheat vs broker as the default.** Is the common case direct value injection
  (fast, deterministic, no broker) with broker-mode reserved for true
  end-to-end tests? Likely yes — confirm and make cheat the unit-test default.
- ~~Where the simulated terminal asset lives~~ — **decided (2026-06-11): its
  own repo, `gridworks-terminalasset`**, built on gridworks-base, now scaffolded
  (a hello terminal asset connecting to dev rabbit, on the `gwta` GNode pattern
  that mirrors `gridworks-timecoordinator`'s `gwtc`). gwbase stays the base
  library; domain GNode actors live in their own repos (the MarketMaker
  pattern); the terminal asset is the seed of the live simulated fleet, not a
  test utility. Alternative rejected: inside gridworks-base proper (would couple
  gwbase releases to sim iteration).
- **Telemetry namespace.** The terminal asset's synthetic sensor stream is rig
  plumbing, not parent/child contract traffic — lean toward a distinct sim
  routing class on the fabric rather than the `gw/<src>/to/<dst>/<type>`
  grammar, so rig wiring never masquerades as contract traffic (same principle
  as keeping internal telemetry off the contract stream).
- **How synthetic physics is specified** — hardcoded curves vs a small
  declarative model vs scripted scenarios (for chaos testing). Start hardcoded;
  design the seam for scenarios.
- **Domain placement of this design** — kept under `gridworks-scada/` because the
  goal is testing SCADA, but the simulated-terminal-asset half is gridworks-base
  work; if the base simulation framework grows it may graduate to a cross-cutting
  `wiki/designs/` design. Flag at ratification.
- **New MakeModel sim values** — exact `GRIDWORKS__SIM*` names per sensor type.

## Implementation notes

- **No code yet.** Per the implementation gate, this design must reach
  `Accepted` (Pass ≥ 1) on every spoke before scada/base edits matching its
  scope begin.
- **Any Sema change** (new `GRIDWORKS__SIM*` MakeModel values, sim component
  types) goes through `/make-sema-word` — read `sema/CLAUDE.md` and follow it.
- Touch points: `gridworks-scada` (`drivers/`, `actors/` factories, `layout_gen/`,
  `tests/utils/`), `gridworks-base` (simulated terminal asset GNode actor,
  dev-broker test topology), `gridworks-protocol`/`sema` (MakeModel + sim
  component types).
- Relationship: subsumes OPS-40's original `gen_orange` dev-layout checklist;
  related to **OPS-118** (Dev mosquitto in Docker — the dev broker).

## TODO — revert the temporary `GridWorks_CLAUDE.md` directives

Two temporary directives were added to `GridWorks_CLAUDE.md` (2026-06-12); remove
each when its condition is met:

1. **Plant simplicity** — "keep the terminalasset plant as simple as possible …
   and no simpler; when in doubt err simpler and leave a question." **Remove once
   the plant MVP (Phase A comms pipe + best-guess physics) is working.**
2. **Sema-words commit permission** — Claude may make bounded, test-passing sema
   commits on `jm/sim-vocab`. **Remove once Jessica has reviewed the
   simulated-test-environment sema words** (the words committed under this
   permission are not finalized until then). On removal, **also restore the
   `precheck-no-claude-commits.sh` commit-block hook** in `.claude/settings.json`
   (removed to enable the commits).
