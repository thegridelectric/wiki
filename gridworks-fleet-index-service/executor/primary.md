# Fleet Index Service (FIS) — spec (primary)

Status: Draft · Pass 0 · Updated 2026-09-05

> What this is: the faithful spec of the **Fleet Index Service (FIS)** — the
> authority-plane service the broker calls (`rabbitmq-auth-backend-http`) to
> authorize every connection and every topic publish, enforcing a single
> authorized instance per (GNodeId, run). The build plan is the
> `stand-up-fis` design (OPS-422); the auth architecture it implements is
> the mTLS+FIS design (OPS-420); the non-GNode-services extension is
> [`../explorations/principal-model.md`](../explorations/principal-model.md).
> Read this hub first, then the two spokes in the order listed at the end.

## Purpose

Enforces single authorized `GNodeInstanceId` per **(GNodeId, run)**.
Lease-based single-writer authority: a GNode has at most one live instance
per run, and a new instance supersedes the old one — with the predecessor's
connections confirmed closed before the successor is admitted. Why a
fleet needs this, told through one scada's day:
[`day-in-the-life.md`](day-in-the-life.md).

## Deployment

**One FIS per broker box, colocated with the broker**, with its own small
Postgres (principal + lease + registry mirror). The auth path is localhost:
FIS binds the box's loopback only, and the broker container therefore
runs on the host network (a bridged container's `localhost` is itself);
FIS starts before (or with) the broker in the box's boot order; the rebuild
runbook treats broker + FIS as one unit. FIS's only path into the broker
is the management API over localhost, for the supersession kill. FIS is scoped to its box's
fabric(s) and reads only its own universe's registry — a staging box runs
its own FIS, and different universes have disjoint registry + broker + FIS
stacks. FIS being unreachable means no new connections (existing ones
survive): fail closed, by design.

## Scope

- Tracks principals and instance leases. A **principal** is a durable
  identity belonging to a core piece of the GridWorks platform that is
  allowed to connect to the broker: a **GNode** in the grid topology (a
  house's scada, its leaf transactive node, a market maker), whose id is
  its GNodeId; or a **Service** outside the topology (the
  grid-node-registry, the ear, the journalkeeper, the weather forecast
  service), whose id is a UUID FIS mints.
- Determines the authoritative instance per (identity, run).
- Serves the four RabbitMQ HTTP auth endpoints. `/auth/user` is the gate;
  `/auth/vhost` cross-checks the claimed run against the vhost;
  `/auth/resource` is allow-all in v1; `/auth/topic` pins a write's
  from-alias to the identity's current alias and allows every read. The
  contract and each verdict:
  [`auth-endpoints.md`](auth-endpoints.md).
- Keeps a mirror of its universe's registry, its own lease and principal
  tables, and the auth-event record:
  [`mirror-db-cli.md`](mirror-db-cli.md).

## Invariants (normative)

1. **Single writer** — for each (GNodeId, run), at most one
   `GNodeInstanceId` SHALL be authorized at any time; a successor SHALL be
   admitted only after the predecessor's connections are confirmed closed.
2. **Explicit authority** — operational publish rights SHALL NOT be
   inferred from naming conventions or network location; authority SHALL be
   granted explicitly via FIS.
3. **Separation of identity and instance** — mTLS SHALL authenticate the
   durable identity (cert CN = GNodeId for GNodes, principal UUID for
   services); FIS SHALL authorize the active runtime `GNodeInstanceId`.
4. **Broker enforcement** — the broker SHALL enforce that only the
   authorized instance may publish operational messages for a given
   identity, and that every publish's `user_id` and routing-key from-alias
   match the connection's authenticated identity (`validated-user-id` +
   topic authorization).

## How the claims arrive

Status: Verified · Pass 0 · Updated 2026-09-02 · Reviewed 2026-08-14@1e16d79 (`experiments/2026-08-14-sasl-mechanism-spike/`) — AMQP leg only

The broker forwards, per protocol (protocol facts verified at source,
OPS-420 "Protocol ground truth"):

- **AMQP** — `username` (from the cert CN, via the GridWorks SASL
  mechanism) + a single `claims` param: the **`fis.connect.claims`** sema
  word — `Alias`, `InstanceId`, `Run` (`universe.run` format), and
  `GNodeClass` iff the principal is a GNode (the GNode discriminator).
  FIS decodes it through its vendored snapshot codec, strict.
- **MQTT** — `username` (from the cert CN, `ssl_cert_login`) +
  `client_id = GNodeInstanceId` + `vhost`. No alias claim at connect; the
  alias is enforced at first publish via `/auth/topic`.

`client_properties` never reach the auth path — they remain visible in the
management API and `connection_created` events, for audit only.

**The claimed run travels back to the broker as the connection's user
tag.** The backend puts a connection's claims and its vhost in no single
request: AMQP picks the vhost at Connection.Open, after SASL, and the
vhost call carries only `username`, `vhost`, `ip`, and `tags`. The one
piece of per-connection state the backend does carry forward is the tag
list after `allow` in the user verdict, which becomes the connection's
`#auth_user` tags and rides every later vhost, resource, and topic request
as `tags`. So FIS answers `/auth/user` with `allow <run>` and `/auth/vhost`
compares that tag to the vhost it is opening, with no lease lookup. The
tag is the run, never the instance id: the broker interns each distinct
tag as an atom, and runs are a bounded set. A run cannot collide with a
tag the broker reserves (`administrator`, `monitoring`, ...) since it
carries a `__`.

## Registry changes force reconvergence

Because `/auth/topic` verdicts cache per (connection, exchange, routing
key), a mid-connection registry change is invisible to a live connection's
cached keys. So on a **rename** (and any future withdrawal of FIS-checked
authority): FIS — on learning of the change, from gnr's push or the periodic
reconcile as the fallback — kills that identity's connections; the kill
flushes the cache. The killed node then reconnects and **self-heals its
alias**: its durable identity is its cert CN (the GNodeId), so it looks its
own current alias up in gnr by GNodeId and reconnects with it — no
provisioning redeploy. (The self-heal is a client contract, owned by the
mTLS+FIS auth design and gwbase/proactor; FIS's part is only the kill.)
Convergence is immediate under the push, bounded by the reconcile interval
without it.

## Rabbit config (the broker side; conf owned by rmqbot)

The broker-side half is one conf fragment plus a compose overlay in
rmqbot (`gridworks-infra/rmqbot/rmq-docker/gate/`, mounted by
`compose.gate.yaml`): chained backends (`internal` for the management UI
and break-glass, `http` for every fleet principal), the four
`auth_http.*_path`s to FIS on `localhost:8080`, the GridWorks SASL
mechanism, `ssl_cert_login_from = common_name`, and
`mqtt.ssl_cert_login`. The rmqbot auth-path spec holds the broker-side
rationale; what FIS depends on:

- **No verdict caching** (`rabbit_auth_backend_cache` rejected): a cached
  allow for a just-revoked instance breaches invariant 1. FIS being
  reachable is a hard dependency of every connect.
- **Topic authorization** asks `/auth/topic` per publish with the routing
  key; `properties.user_id` is validated against the connection's identity
  by the broker itself.
- **No fleet password users**: on MQTT an explicit username+password
  outranks the cert-derived name, so a live password user is a CN bypass.
- **The `ssl_options` tightening** (`verify_peer`,
  `fail_if_no_peer_cert = true`) is not part of the gate fragment; a box
  carries it in its own `rabbitmq.conf` (prod at notch 3).

## Publishing operational messages

Once authorized, a client publishes with `properties.user_id` = its
authenticated identity (broker-validated) and routing-key segment 2 = its
current alias (FIS-validated per new key). Message bodies include
`FromGNodeAlias`, `MessageCreatedMs`; envelope-level `FromGNodeId` /
`FromGNodeInstanceId` await a proactor change (not immediate).

## Test plan

Before rolling to the fleet, auth must be fast and every deny witnessed,
each verdict twice: by the client's outcome and by the `auth_events` row
FIS recorded for it. The battery is
`experiments/2026-09-05-fis-gate-battery/`: FIS, the rmqbot gate overlay
and the mechanism plugin on a stock 4.1.8 broker, driven by real
claims-bearing clients (gwbase's credentials class and claims word on
AMQP, a cert-bearing paho client on MQTT). It runs twice: on the dev
universe (`d1__1`, localhost brokers, the only place `staging` vocabulary
may run) to catch mechanical failures cheaply, then on the staging box,
the run that verifies.

- Valid cert + claims → allow. Unknown principal, suspended principal,
  revoked instance, wrong alias claim, wrong class claim, a run outside
  the universe → deny.
- Run-claim ≠ vhost → deny at `/auth/vhost`, for a fresh principal and
  for one already live on that vhost.
- Two instances racing → ordered supersession: the predecessor's
  connections are closed before the successor is admitted; management
  API unreachable → the successor is denied.
- Clean restart (nothing to kill) → admitted without delay.
- A stale-alias node connects, and its first publish is denied at
  `/auth/topic`; a forged `user_id` is refused by the broker itself.
- Suspension alone does not close a live connection (eviction is suspend
  plus kill).
- 100 concurrent connects all admitted, every connect inside the
  broker's 10 s handshake budget.

## Glossary

- **Principal** — a durable identity allowed on the broker; its id is the
  cert CN. Two kinds: **GNode** (id = GNodeId, alias and class checked
  against the registry) and **Service** (id = a UUID FIS mints; no
  registry row).
- **Instance** — one running process of a principal, named by a fresh
  `GNodeInstanceId` (uuid4) per boot. Identity is durable; instances come
  and go.
- **Universe** — the first dotted segment of every alias (`d1`, `hw1`,
  `w`); one FIS serves one universe and reads only its registry.
- **Run** — one execution of a universe, `universe__n`. A run is its own
  message fabric: the broker vhost, and the scope of single-writer
  authority.
- **Lease** — the record that an instance holds authority on (principal,
  run). At most one is `Active` per pair; a revoked lease is permanent.
- **Supersession** — how a lease ends: a never-seen instance of the same
  identity on the same run revokes the prior lease and has the
  predecessor's connections closed and confirmed gone before it is
  admitted.
- **Mirror** — FIS's copy of its universe's `g.node.gt` rows, pulled from
  gnr's read façade; what alias and class claims are checked against.
- **Gate** — `/auth/user`, the one verdict that admits or refuses a
  connection.

## Spokes

0. [`day-in-the-life.md`](day-in-the-life.md) — what FIS is for, as a
   narrative for a person; read first, not normative.
1. [`auth-endpoints.md`](auth-endpoints.md) — the HTTP contract, the gate's
   verdicts and the supersession mechanics, the vhost, resource and topic
   rules, the auth event.
2. [`mirror-db-cli.md`](mirror-db-cli.md) — vocabulary, the mirror and its
   three inputs, the tables, the registry façade calls, the `fis` command,
   configuration.
