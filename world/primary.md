# world — standing up a GridWorks universe

Status: Draft · Pass 0 · Updated 2026-06-09

> What this is: the hub for **building and running a GridWorks World** — a
> self-contained instance of the ecosystem, at any scale and fidelity (one
> actor on a laptop → hundreds of actors; fully real, fully simulated, or
> hybrid). Acceptable-minimum: the concept + invariants + the recipes/scale
> trajectory, much left "Open." Replaces the earlier "dev-stack" framing,
> which undersold the continuum.

## What a World is

A **World** is the root GNode of a GNode tree — a complete GridWorks universe
with its own registry, its own `TimeCoordinator`, and its own
`NetworkModeler`. Standing up a World means bringing up that universe: a
message broker (the spine), the actors that live on it (scada, LTN,
MarketMaker, weather/price services, journalkeeper, …), and whatever
persistence those actors need.

Running a World is therefore one mechanism across a wide range:

- a **laptop World** — one broker + a couple of actors, for development;
- a **simulated World** — many actors with no physical devices, driven by a
  `TimeCoordinator` (accelerated / replay time);
- a **hybrid World** — some nodes back real metered devices, others are
  digital twins, on the same fabric.

The structure is identical across all three — that sameness is the point. (The
vision frames this as *one fabric, real and simulated*; exercising a simulated
World is itself trust-building, not just QA — see
[`../vision/primary.md`](../vision/primary.md) "Hybrid real + simulated
fleet".)

## Invariants

1. **One broker, many actors.** A World has a single message bus; actors are
   distinguished by identity and bindings, not by separate brokers.
2. **Time is a World service.** Wall-clock for live Worlds; a `TimeCoordinator`
   drives accelerated and replay runs. Actors take time from the World, not
   from the host clock, so a World can be run faster-than-real or re-run.
3. **The same actor code runs real or simulated.** Simulation is a matter of
   what backs an actor (real device vs. twin), not a different actor
   implementation.
4. **MQTT vs AMQP is a transport detail of the broker, not of the World.**
   scada speaks **MQTT** (via the RabbitMQ MQTT plugin); gwbase services speak
   **AMQP**. A World's broker must enable both and the bindings that fan
   between them. A from-scratch broker MUST declare its own exchanges +
   bindings — do not rely on a baked image's fabric.

## Experiments (vs tests)

A core use of a World is the **experiment**: run real actor code against a
**real broker** and watch what happens. The defining rule is the inverse of a
unit test's convenience — **messages MUST traverse the broker, never a
same-process backdoor.** An in-process harness that links proactors directly
(e.g. scada's `ScadaLiveTest`) is a *test*: fast, hermetic, and blind to the
wire. An experiment puts the message on `amq.topic` and lets the fabric route
it.

Experiments are **often a better simulation of reality than tests.** Worked
example (2026-06-09): a patched LTN emitting `gw.<src>.to.s.…` / `to.mm.…` over
`gw-dev-rabbit` into a JournalKeeper proved the
`must-accept-current-ltn-messages` tolerant-parse fix and the `broadcast.*`
`legacy_hack` end to end — a class of routing-key bug the in-process scada test
**could not** see, because it never built a wire key. That is the justification
for the World's "play together" methods: the broker is the point.

Two standing requirements follow:

- **Every repo provides a natural broker-participation harness** — a documented,
  one-call way to bring its actor up against a World's broker (seeds today:
  `LtnApp.get_repl_app`, gjk's `point_at_*` scripts). No repo should require an
  afternoon of bespoke glue to join an experiment.
- **The World provides replicable experiment tooling** — a broker-coordinates
  profile, a generic observer/tap, a single-emit driver, branch-pinning,
  capture/replay, one-script orchestration. The backlog for this lives in the
  scada `simulated-test-environment` design (spoke `experimentation-tools`,
  absorbed from this domain 2026-06-11); the as-is scada rig is in
  [`../gridworks-scada/executor/experimentation-rig.md`](../gridworks-scada/executor/experimentation-rig.md).

Replicability is what makes a simulated World **trust-building** rather than a
one-off demo.

## Recipes (Open)

The concrete "how to run it" recipes (to be written as spokes under
`recipes/`):

- **single-broker** — bring up one RabbitMQ with the MQTT plugin and the
  canonical exchange/binding fabric (extract from `gridworks-base/for_docker/`).
- **scada-simulated** — `SCADA_IS_SIMULATED=true` scada against the dev broker;
  the offline-development path.
- **journalkeeper-persisting** — gjk consuming the World's bus into `gw_data`.
- **smoke-test** — the combined broker + scada(simulated) + journalkeeper +
  postgres flow, end to end.

## Scale trajectory (Open)

Don't build for hundreds now; record the trajectory so we don't accumulate
debt that has to be undone:

- **Today (1–3 actors):** terminals + venvs + `gws run --is-simulated`. No
  orchestration. Sufficient for single-service smoke tests.
- **Tier 1 (1–10, near-term):** multi-service compose (rabbit + postgres +
  scada(s) + journalkeeper), wrapped with a script/Makefile; each actor a full
  venv process.
- **Tier 2 (10–50, mid-term):** container per actor type, parameterised by
  layout file + identity env vars. Validate broker memory; consider a
  non-baked broker.
- **Tier 3 (100s, far-term):** open — candidates: k3s/k8s + rabbit cluster;
  Nomad; a custom process-per-actor supervisor pool. Decision deferred; record
  candidates + criteria (process isolation, broker fan-out limits, experiment
  reproducibility) when it's live.

Journal-DB retention and scale are gridworks-data work (OPS-503).

## Cross-refs

- [`../vision/primary.md`](../vision/primary.md) — the hybrid real+simulated
  fleet as vision; the World is its concrete shape.
- `wiki/gridworks-base/` — the broker fabric (`for_docker/`) and the actor
  framework.
- `wiki/gridworks-scada/` — scada in simulated mode (its simulated-test
  environment is a gridworks-scada design).
- [`../gridworks-marketmaker/research/gnode-taxonomy.md`](../gridworks-marketmaker/research/gnode-taxonomy.md)
  — the GNode roles (World, TimeCoordinator, NetworkModeler) a World is built
  from.
