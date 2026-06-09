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

The gjk-lens retention/scale seed notes live in
[`../gridworks-journalkeeper/explorations/scale-strategy-starter.md`](../gridworks-journalkeeper/explorations/scale-strategy-starter.md).

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
