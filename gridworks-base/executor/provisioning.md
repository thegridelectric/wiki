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
  conf's `default_*` lines (which would race `load_definitions` at boot).

**Generator → per-vhost definitions JSON.** A generator
(`for_docker/gen_definitions.py`) renders a RabbitMQ management-plugin
definitions JSON, parameterized by `--vhost` (`d1__1` dev, `hw1__1` prod).
Everything but the vhost (and prod-secret handling) is environment-
invariant. `tests/_stubs.py` derives its exchanges/bindings from the *same*
`gwbase/topology.py`, so test, dev, and prod topologies cannot diverge. A
**CI guard** regenerates the JSON and diffs it against the committed
artifacts, failing on drift.

**Identities & secrets.** Definitions store a `password_hash`, not
plaintext. **Dev** commits the `smqPublic` user + hash (non-secret).
**Prod** never bakes its user/hash into a published artifact — inject at
deploy (compose secrets / conf env interpolation) or keep prod definitions
private. With identities removed, the conf collapses to **one parameterized
template** whose only env-specific line is `mqtt.vhost`;
`management.load_definitions` points at the JSON.

**Delivery — automated bake to GHCR.** CI builds and publishes a dev-broker
image (`ghcr.io/thegridelectric/...`) from the guard-checked JSON on every
change, so the image **cannot lag the repo** — the failure mode of the
prior *manual* bake, which stranded the live image at commit `fee74a3` in
the pre-refactor token namespace. Other repos (gridworks-marketmaker,
gridworks-scada) **pull the image and run a dev broker with no
gridworks-base checkout** — the reason a published image beats a host mount
here. The dev image is **public**; the prod broker never ships baked
secrets. `:latest` tracks current; pin `:<commit>__<date>` for deliberate
upgrades. For gridworks-base's own fast inner loop you may instead mount the
freshly-generated JSON rather than rebuild.

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
