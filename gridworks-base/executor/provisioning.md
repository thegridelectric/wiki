# gridworks-base — Provisioning & delivery

Status: Draft · Pass 0 · Updated 2026-09-02

Sub-spec of the gridworks-base rebuild spec — **start at
[`primary.md`](primary.md)**. This file holds the broker's dev/hybrid home:
how the fabric is generated, named, and delivered. The topology it
provisions is described in [`transport.md`](transport.md) `transport.md`
"AMQP topology".

---

## Provisioning & delivery

The exchange set, the routing fabric, and the broker identities are **not**
created by application code (`transport.md` "AMQP topology"). They are a generated artifact, derived
from one declarative source so they cannot drift from the code that depends
on them.

**Single source of truth — `gwbase/topology.py`:**

- `AMQP_ACTOR_CLASSES` — the opt-in set of `RoutingClass` values that run
  as rabbit AMQP actors and therefore get `<rc>_tx` + `<rc>mic_tx`:
  `{ta, ltn, mm, price, weather, time, super, gnr}`. **`scada` is excluded**
  (MQTT-only, reached via `amq.topic`); **`cn` is excluded** (passive /
  non-runtime — opt it in if it ever becomes a GNodeActor). A newly-added
  `RoutingClass` gets **no** exchanges until explicitly opted in.
- `ROUTING_EDGES` — the direct-only `(src, dst)` list (`transport.md` "AMQP topology"), with
  `direct_binding_key(src, dst)` deriving the 6-token pattern from the
  routing-key grammar (`transport.md` "Routing-key grammar").
- `exchange_bindings()` also declares the ear taps, the registry's scoped
  audit tap (`gnr_ear_tx`), and the two `rjb.#` bridges to `amq.topic`;
  `queues()` / `policies()` declare the standing `debug` queue and its cap
  policy. The definitions builder emits all of them, so a container
  recreate reproduces the whole fabric from files.
- **Identities** — users, vhost, and permissions live *here*, not in the
  conf's `default_*` lines (which would race the definitions import at boot).

**Vhost = `<universe>__<run>`.** A vhost names one
**run** of a universe — the universe is the durable GNode set, a run is one
execution of time against it, with its own message fabric / sim-clock / event
history / FIS leases. The grammar is **uniform across all kinds, including
production** (`d1__1`, `hw1__1`, `w__1`): for a real universe the run number is
the **fabric generation** (broker migration/DR mints `w__2`, same universe and
identities), and which run is "live" is deployment state — a provisioning
pointer, never a name. The `__` separator cannot collide with alias content
(aliases are dot-separated words). **The authoritative definition of universes
(the `d`/`h`/`w` ladder: dev = all-localhost, hybrid = distributed + flexible,
production = validation certs + real money) and of runs lives in
`wiki/grid-node-registry/executor/primary.md` "Universes"** — this doc owns only
the vhost grammar and the definitions artifacts.

**Generator → per-vhost definitions JSON.** The build logic lives in the
package (`gwbase.rabbit_definitions.build_definitions`, unit-tested);
`for_docker/gen_definitions.py` is the thin CLI the broker-image build and
the CI guard call. It renders a RabbitMQ management-plugin definitions JSON,
parameterized by `--vhost` (`d1__1` dev, `hw1__1` hybrid run 1; the committed
artifacts are `dev_definitions.json` / `hybrid_definitions.json` — provisioning
a further run regenerates with that run's vhost). Output is
**deterministic** (fixed dev-password salt + sorted keys) so it can be
regenerated-and-diffed. The **drift guard** is
`tests/test_definitions_drift.py` (runs in the normal `uv run pytest` / CI),
plus a pre-commit hook and `gen_definitions.py --check` — all single-sourced
via `rendered_artifacts()` / `DEFINITION_ARTIFACTS`. Everything but the
vhost (and prod-secret handling) is environment-invariant. `tests/_stubs.py`
derives its exchanges/bindings from the *same* `gwbase.topology`, so test,
dev, and prod topologies cannot diverge.

**Identities & secrets.** Definitions store a `password_hash`, not
plaintext. **Dev** commits the `smqPublic` user + hash (non-secret).
**Hybrid (and the eventual prod universe)** never bakes a user/hash into a
published artifact — inject at deploy (compose secrets / conf env
interpolation) or keep those definitions private. With identities removed, the conf collapses to **one parameterized
template** whose only env-specific line is `mqtt.vhost`. The conf points the
broker at the definitions with the RabbitMQ 4.x keys
`definitions.import_backend = local_filesystem` +
`definitions.local.path = /etc/rabbitmq/definitions.json` (3.x used
`management.load_definitions`). For the dev image, **both the conf and
`dev_definitions.json` are baked into the image** (next), not mounted.

**Delivery — automated bake to GHCR.** `rabbit/Dockerfile` bakes
`enabled_plugins` + `dev_rabbitmq.conf` + `dev_definitions.json` onto the
official **multi-arch `rabbitmq:4.1-management`** base — one image serves
arm64 + amd64, retiring the old per-arch `jessmillar/dev-rabbit-*` images
and their `build-dev-broker-*.sh` scripts. CI
(`.github/workflows/broker-image.yml`) builds and pushes it to
`ghcr.io/thegridelectric/dev-rabbit`, **gated by `gen_definitions.py
--check`** so a stale image can't ship (the failure mode of the prior
*manual* bake, which stranded the live image at commit `fee74a3` in the
pre-refactor token namespace). `arm.sh` / `x86.sh` both pull the same
`:latest` image (refresh via `docker compose pull`); other repos
(gridworks-marketmaker, gridworks-scada) pull it too and run a dev broker
with **no gridworks-base checkout** — the reason a published image beats a
host mount here. gridworks-base's **own CI test suite**
(`.github/workflows/tests.yml`) also runs against this image as a service
container, retiring the standalone RabbitMQ 3.9.13 test broker (the
`namoshek` action + `.ci/rabbitmq.conf`) it replaced — so unit tests and
dev exercise one topology+broker build (prod joins once its 4.x upgrade
lands; see parity note below). The dev image is
**public**; the prod broker never ships baked secrets. Tags: `:latest` plus a commit-pinned
`:chaos__<short-sha>__<date>` for traceability. For gridworks-base's own
fast inner loop you may instead mount the freshly-generated JSON rather than
rebuild.

**Dev/hybrid parity & versions.** Dev and the hybrid broker run the same
RabbitMQ 4.1 line (the hybrid box is patch-pinned by rmqbot,
[`../../rmqbot/executor/primary.md`](../../rmqbot/executor/primary.md)) and
load the same generated topology, differing only by vhost and by how
identities arrive. The generated definitions stay **version-agnostic**
(plain exchanges/bindings/queues/policies/identities) so one artifact shape
serves every rung of the ladder. The broker-side auth gate (mTLS + the
`GRIDWORKS` claims mechanism + FIS) is a separate track
([`../../gridworks-fleet-index-service/`](../../gridworks-fleet-index-service/));
gwbase's client half is `actors.md` "Connect-time identity".
