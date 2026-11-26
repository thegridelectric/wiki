# world — standing up a GridWorks universe

Status: Draft · Pass 0 · Updated 2026-11-25

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
5. **Identity is the alias; the broker is the only address.** A GNode is
   identified by its GNodeAlias and reached on its universe's broker. It
   finds every other GNode by alias on that broker, and the broker's URL
   is the one address it is configured with. A hostname, port or IP is a
   deployment fact of a box and lives in gridworks-infra. It names
   nothing in the universe, so an orchestrator may move it without the
   universe noticing. A GNode's public HTTP route is a façade for readers
   outside the broker, not a way for GNodes to find each other. A GNode
   that holds another GNode's URL is the defect this rules out.

## DNS names

There are two kinds of DNS name, and they follow different rules.

- **An endpoint name follows the universe.** `<universe>-<run>` is the
  broker of that run, the DNS-safe spelling of its vhost
  `<universe>__<run>`: `hw1-1.electricity.works` is the broker whose
  vhost is `hw1__1`. Anything else the universe exposes is named from it
  (`hw1-1-s3-ear`). An endpoint name can be pointed at another machine
  without changing any GNode's settings, which is what lets a broker
  move. This is the only kind of DNS name a universe owns, because the
  broker's URL is the only address a GNode has (invariant 5).
- **A machine name follows the machine's function and names no
  universe.** `rmqbot` is the box the `hw1-1` broker runs on; `ltn` and
  `gjk` are others. A machine outlives the universes it hosts and may
  host several, and under an orchestrator it is a node.

Under Kubernetes a run is a namespace named `<universe>-<run>`, and its
broker is the Service `rabbit` in that namespace. Simulations side by
side are separate namespaces, and they may use the same GNode aliases
because each has its own broker.

A GNode has no DNS name. A `d` universe's broker is inside its own pod or
namespace, so a `d` universe has no public DNS name either.

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
  `simulated-test-environment` design (OPS-40; spoke `experimentation-tools`,
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
- **Tier 3 (100s, far-term):** Kubernetes, reached by the hosting path
  below. The broker's own scaling (a rabbit cluster, fan-out limits) is
  open.

**The hosting path** (decided 2026-11-25). Three stages, each one learned
and documented before the next:

1. **systemd runs podman containers.** Each service is a container
   started by a systemd unit with a restart policy and a health check.
   The simulation host is first; the production boxes follow.
2. **k3s**, on a laptop and on the simulation host, from the same pod
   descriptions. The orchestrator then starts, restarts and moves the
   containers.
3. **Kubernetes that GridWorks hosts itself**, kept to the minimum set of
   add-ons, each added by a team decision. A cloud provider's managed
   service is considered only after this stage is understood.

At every stage one thing owns the processes: systemd, then the
orchestrator. The Supervisor (OPS-695) watches liveness over the broker
and never starts, stops or moves a process. A GNode's alias and the
broker's URL are all a container needs to find the rest of its universe
(invariant 5), so no stage uses the orchestrator's service discovery
between GNodes. The work is OPS-676.

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
