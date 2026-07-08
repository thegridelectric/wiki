# SCADA simulated test environment (hub)

Status: Accepted · Pass 1 · Updated 2026-06-13 · Linear: OPS-40

**EDD: yes** The simulated-test-environment harness *is* the verification; spokes reach Verified only when an experiment runs against it (experiments/logbook.md).

**▶ Active spoke: [`build-plant.md`](build-plant.md)**

> What this is: a robust simulated test environment for the SCADA — extremely
> simple simulated terminal assets plus simulated sensors that exchange data over
> the dev Rabbit broker, the terminal assets built on gridworks-base. Ported from
> Linear **[OPS-40](https://linear.app/gridworks/issue/OPS-40)** (which began as a narrower "run dev scada without crashing /
> `gen_orange` layout" task and is reframed here into the broader goal).

### Spokes

- **[`build-plant.md`](build-plant.md)** — *active.* The construction plan for the
  simulated message-passing loop: gwta plant emits `sim.plant.flux`, the scada
  `SimSensorActor` reads it into `synced.readings`, `SimRelayActor` sends
  `sim.plant.actuation` back. Owns the ordered next-tasks.
- [`self-faking-actors.md`](self-faking-actors.md) — the component-faithful **fidelity
  dial** in its simplest local form: the real device actors (`ApiTankModule` /
  `ApiBtuMeter` / `ApiFlowModule`) self-generate fictitious input on a timer — no plant,
  no broker — so a full-sim House0 layout runs every device code path without crashing.
  The cheap precursor to the coherent plant; unblocks the hardware-layout-pass-one
  `primary-flow` behavior test. Candidate next-active spoke.
- [`simulated-actors.md`](simulated-actors.md) — the sim seam (device boundary, the
  plant pushes), the first-pass plant model, the plant's I/O contract, and the
  sim/real trust boundary. Moved here from spruce-unlimbo 2026-06-11.
- [`sim-time.md`](sim-time.md) — scada on coordinator timesteps: code census, the
  1-minute bridge for the existing proactor stack, the watchdog-pat gate. The
  bridge crossing is Verified (`../../experiments/logbook.md`).
- [`experimentation-tools.md`](experimentation-tools.md) — the replicable
  real-broker experiment toolset; absorbed from world/designs/experimentation-harness
  2026-06-11 (all simulation/experimentation work consolidates here).
- [`new-sema-words-to-review.md`](new-sema-words-to-review.md) — JM sign-off tracker
  for every sema word this design added/bumped (committed under `jm/sim-vocab`, not
  finalized until reviewed).
- [`gleanings.md`](gleanings.md) — parked notes off the build path: the sim-sensor
  groundwork + `sim.plant.flux` rationale, DB-calibration questions, the
  cross-carrier round-trip harness, deferred/queued items.

## Motivation

We have no robust test environment for the SCADA — only real hardware (slow,
physical, one house at a time) or partial unit tests. We can't cheaply stand up a
*whole* heating system — terminal asset + sensors + SCADA control — in software
and exercise it end to end, which is what we need to test control logic, layouts,
and fleet behaviour with confidence, and is the prerequisite for the hybrid
real+simulated fleet vision.

So the simulation harness is the top of the scada work. The big projects ahead
(the AllyLink / proactor-link redo — see `../executor/scada-ltn-link-state.md`)
need testing by experiment, the way we want to test, so the harness comes first —
and we set up the MVP the way it will work when we are really modeling terminal
assets. For now, most of what we want to test is comms infrastructure. The MVP's
"physics" is a **traffic generator with a seam** (construction plan in
`build-plant.md`): a format-correct plant emitting synthetic channels, the value
source being the seam where real modeling lands later. Its comms-test knobs are
first-class — tunable cadence/volume, scriptable silence (to provoke
`awaiting_peer` and the keepalive paths), burst mode, optional poison payloads —
the experiment levers for evaluating the old proactor link against the new
AllyLink on one rig.

**The hybrid scenario.** One dev rabbit broker, two protocol faces: gwbase actors
(terminal assets, LTNs, later aggregators) are AMQP-native on the routing fabric;
scadas — real or simulated — ride the MQTT plugin, exactly as prod does on
gw-dev-rabbit. A sim scada is not a mock: it is the real scada process with an
all-sim layout, connecting the way a house does. Per simulated house: one
terminal-asset GNode + one sim scada + one LTN. Hybrid means real houses' scadas
land on the same broker beside the sim houses. The rig exercises **both AllyLink
tracks at once**: each sim scada is a plain 1:1 child against a real rabbit
broker, while the LTN side has many parents talking to many children —
FULL-AllyLink territory.

**The harness is also the spec-building instrument.** The 2026-06-10 live run
(full ltn/scada on dev rabbit, ~5 minutes, wire capture + both process logs)
produced essentially all the productive material in
`../executor/scada-ltn-link-state.md` — observation-driven spec building. The rig
makes that a one-command cadence: bring up the stack, capture, write what IS, let
divergences drive design.

## Current state — where it's documented

This design generalizes existing scada seams rather than starting fresh. The
**durable as-is facts live in `executor/`** (they outlive this design):

- **The sim DeviceType seam + component model** — `executor/components.md`
  ("DeviceType — and the retirement of MakeModel" / "Sim is just another DeviceType").
- **Sim layout components + the `TerminalAsset` GNode role** —
  `executor/hardware-layout.md` (`simulated_tanks.py` →
  `SimPicoTankModuleComponentGt`; the terminal asset is a GNode *role*, not a
  scada actor).
- **The in-process `ScadaLiveTest` harness** — `executor/testing.md`; the
  real-broker rig — `executor/experimentation-rig.md`.

The two seams this design is **actively changing** stay with the
`simulated-actors.md` spoke, not executor (they move into `executor/` only when
the design ships): the runtime **`is_simulated` flag** ("`is_simulated` is a smell
— simulated until proven real") and the **DeviceType-dispatch** seam ("The sim seam
— decided: device boundary, the plant pushes").

## What's landed (notes)

Short pointers to durable facts; the live plan lives in `build-plant.md`.

- **The sim-time bridge crossing is Verified** — a real `tc-hello` broadcasting
  `sim.timestep` over AMQP reaches MQTT subscribers; a real scada-side
  `SimTimeListener` receives every step. Scoped claim in `sim-time.md`; worked
  example in `../../experiments/logbook.md`.
- **The sim seam is decided** — device boundary via a `Sim*` `DeviceType`, the
  plant pushes on `AsyncCaptureDelta`, one flat actor branch, no driver hierarchy,
  sensors outside the command tree, controls as leaves. Full statement in
  `simulated-actors.md`.
- **The make-imaginary wand** (`sim-time-experiment/make_imaginary_layout.py`) —
  turns a real layout imaginary (fresh instance UUIDs, canonical device-type
  UUIDs); the tool behind a complete simulated layout and the sim/real identity
  boundary. Proven on House0.
- **Executor specs landed** — `executor/components.md` and
  `executor/hardware-layout.md` (the device + layout model as it is today), plus
  the EDD verification bar + experiments-record convention.
- **Shared layout vocabulary landed in sema** (`6f73174` … `ee9d267`); the new
  words await Jessica's sign-off in `new-sema-words-to-review.md`.

**Carried caveats:**

- **Real-house layouts are stale across the layout-augments rework** — experiments
  use the wand on current fixtures until the fold lands (owner: spruce-unlimbo
  Chunk B, the layout pipeline; ~4–6 h hand-reconcile, scout map exists).
- **`gw.nolan.layout` stays draft** — only its refs are reconciled to the
  published words; de-drafting is later.

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
- **New sim `gw1.device.type` values** — exact `Sim*` names per sensor type.

## Implementation notes

- **No code yet.** Per the implementation gate, this design must reach
  `Accepted` (Pass ≥ 1) on every spoke before scada/base edits matching its
  scope begin.
- **Any Sema change** (new `Sim*` `gw1.device.type` values, sim component
  types) goes through `/make-sema-word` — read `sema/CLAUDE.md` and follow it.
- Touch points: `gridworks-scada` (`drivers/`, `actors/` factories, `layout_gen/`,
  `tests/utils/`), `gridworks-base` (simulated terminal asset GNode actor,
  dev-broker test topology), `gridworks-protocol`/`sema` (`gw1.device.type` + sim
  component types).
- Relationship: subsumes [OPS-40](https://linear.app/gridworks/issue/OPS-40)'s original `gen_orange` dev-layout checklist;
  related to **[OPS-118](https://linear.app/gridworks/issue/OPS-118)** (Dev mosquitto in Docker — the dev broker).
- The gridworks-terminalasset side needs the spaceheat node/channel naming vocabulary (today a
  per-repo constants copy, gwsproto + a tlayouts mirror) — encoding it in sema so terminalasset
  consumes it from a snapshot is **[OPS-444](https://linear.app/gridworks/issue/OPS-444)**
  (spaceheat-naming-vocabulary).

## TODO — revert the temporary Claude-protocol directives

Two temporary directives were added 2026-06-12; remove each when its condition
is met:

1. **Plant simplicity** (in `wiki/gridworks-scada/CLAUDE.md`; moved out of
   `GridWorks_CLAUDE.md` 2026-07-04) — "keep the terminalasset plant as simple
   as possible … and no simpler; when in doubt err simpler and leave a
   question." **Remove once the plant MVP (Phase A comms pipe + best-guess
   physics) is working.**
2. **Sema-words commit permission** — Claude may make bounded, test-passing sema
   commits on `jm/sim-vocab`. **Remove once Jessica has reviewed the
   simulated-test-environment sema words** (the words committed under this
   permission are not finalized until then). On removal, **also restore the
   `precheck-no-claude-commits.sh` commit-block hook** in `.claude/settings.json`
   (removed to enable the commits).
