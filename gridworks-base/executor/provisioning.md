# gridworks-base — Provisioning & delivery (§3.6)

Sub-spec of the gridworks-base rebuild spec — **start at
[`primary.md`](primary.md)**. Section numbers are global; this file holds
§3.6 (the broker's dev/prod home). The topology it provisions is described
in [`transport.md`](transport.md) §3.5.

---

## 3.6 Provisioning & delivery — the broker's dev/prod home

The exchange set, the routing fabric, and the broker identities are **not**
created by application code (§3.5). They are a generated artifact, derived
from one declarative source so they cannot drift from the code that depends
on them.

**Single source of truth — `gwbase/topology.py`:**

- `AMQP_ACTOR_CLASSES` — the opt-in set of `RoutingClass` values that run
  as rabbit AMQP actors and therefore get `<rc>_tx` + `<rc>mic_tx`:
  `{ta, ltn, mm, price, weather, time, super}`. **`scada` is excluded**
  (MQTT-only, reached via `amq.topic`); **`cn` is excluded** (passive /
  non-runtime — opt it in if it ever becomes a GNodeActor). A newly-added
  `RoutingClass` gets **no** exchanges until explicitly opted in.
- `ROUTING_EDGES` — the direct-only `(src, dst)` list (§3.5), with
  `direct_binding_key(src, dst)` deriving the 6-token pattern from the
  routing-key grammar (§3.3).
- **Identities** — users, vhost, and permissions live *here*, not in the
  conf's `default_*` lines (which would race the definitions import at boot).

**Generator → per-vhost definitions JSON.** The build logic lives in the
package (`gwbase.rabbit_definitions.build_definitions`, unit-tested);
`for_docker/gen_definitions.py` is the thin CLI the broker-image build and
the CI guard call. It renders a RabbitMQ management-plugin definitions JSON,
parameterized by `--vhost` (`d1__1` dev, `hw1__1` prod). Output is
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
**Prod** never bakes its user/hash into a published artifact — inject at
deploy (compose secrets / conf env interpolation) or keep prod definitions
private. With identities removed, the conf collapses to **one parameterized
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
host mount here. The dev image is **public**; the prod broker never ships
baked secrets. Tags: `:latest` plus a commit-pinned
`:chaos__<short-sha>__<date>` for traceability. For gridworks-base's own
fast inner loop you may instead mount the freshly-generated JSON rather than
rebuild.

**Dev/prod parity & versions.** Dev and prod run the **same** CI-built image
and differ **only by vhost**. **Dev is bumped to RabbitMQ 4.x now; the prod
upgrade is deferred** until a first gwbase actor is validated in dev — so
parity is *intentionally suspended* (dev 4.x, prod 3.9.13) until then. The
generated definitions are kept **version-agnostic** (plain
exchanges/bindings/queues/identities, no 4.x-only features) so the *same*
topology loads on both. The eventual prod target is also **4.x** — 3.x is
at/near community EOL, and 4.x is the right foundation for the deferred
**mTLS + FIS** auth work, a separate track (see
[`../../gridworks-fleet-index-service/`](../../gridworks-fleet-index-service/)
and [`../../rmqbot/research/broker-todos.md`](../../rmqbot/research/broker-todos.md)).
