# Fleet Index Service (FIS) — spec (primary)

Status: Draft · Pass 0 · Updated 2026-08-14

> What this is: the faithful spec of the **Fleet Index Service (FIS)** — the
> authority-plane service the broker calls (`rabbitmq-auth-backend-http`) to
> authorize every connection and every topic publish, enforcing a single
> authorized instance per (GNodeId, run). The build plan is the
> `stand-up-fis` design (OPS-422); the auth architecture it implements is
> the mTLS+FIS design (OPS-420); the non-GNode-services extension is
> [`../explorations/principal-model.md`](../explorations/principal-model.md).

## Purpose

Enforces single authorized `GNodeInstanceId` per **(GNodeId, run)**.
Lease-based single-writer authority: a GNode has at most one live instance
per run, and a new instance supersedes the old one — with the predecessor's
connections confirmed closed before the successor is admitted.

## Deployment

**One FIS per broker box, colocated with the broker**, with its own small
Postgres (principal + lease + registry mirror). The auth path is localhost;
FIS starts before (or with) the broker in the box's boot order; the rebuild
runbook treats broker + FIS as one unit. FIS is scoped to its box's
fabric(s) and reads only its own universe's registry — a staging box runs
its own FIS, and different universes have disjoint registry + broker + FIS
stacks. FIS being unreachable means no new connections (existing ones
survive): fail closed, by design.

## Scope

- Tracks principals (GNode and service kinds) and instance leases.
- Determines the authoritative instance per (identity, run).
- Exposes the RabbitMQ HTTP auth endpoints:
  - `/auth/user` — the gate (below).
  - `/auth/vhost` — cross-checks the claimed run against the actual vhost;
    deny on mismatch. Otherwise allow.
  - `/auth/resource` — **v1: allow all.**
  - `/auth/topic` — `permission: write`: allow iff routing-key segment 2
    equals the wire-form (hyphenated) current alias of the connection's
    identity. `permission: read` (fired by MQTT subscribes): **allow** —
    authorization is about authority, not visibility (OPS-420).

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

## `/auth/user` — the gate

- **Malformed or missing required claims** → deny.
- **Principal not found or not `active`** → deny.
- **Instance id matches the (identity, run) active lease** → allow
  (idempotent reconnect).
- **Instance id previously revoked** → deny. Forever — revoked lease rows
  are permanent (a TTL cleanup would re-admit an old zombie).
- **Instance id never seen** (AMQP also: claimed alias/class must match the
  registry's current values — deny on mismatch) → supersession,
  synchronously, before responding: mark the prior lease revoked; close its
  connections via the management API (`DELETE /api/connections/<id>`);
  confirm **no connections remain for this identity on this run** (an empty
  kill is success — every restart is a supersession and a clean stop leaves
  nothing to close); create the new lease ACTIVE; return allow. If the kill
  cannot be confirmed (management API unreachable) → deny, fail closed.

Map: allow → the plain-text body `allow`; every deny → the plain-text body
`deny`. The stock `rabbitmq_auth_backend_http` backend expects an `allow` /
`deny` text body (the user path also accepts `allow <tags>`, unused here — no
fleet principal carries broker tags), not JSON; the protocol carries no hint
channel besides, and none is needed.

**A lease ends only by supersession.** There is no shutdown notification:
clean stop and crash are identical, and a decommissioned node's eternal
lease is inert (the gate denies on principal status regardless). Emergency
eviction is principal suspension + connection kill, independent of leases.
Instance liveness ("is one running *now*?") is deliberately out of the
gate — see
[`../explorations/g-node-instance-and-liveness.md`](../explorations/g-node-instance-and-liveness.md).

After responding, publish the auth event asynchronously. The event is
**`fis.instance.authorization.event`** with the
`fis.authorization.decision` / `fis.authorization.reason` enums — all
three still `draft`, so all three need promoting to `staging` (and
revising to match this contract) before the first consumer line. The
durable lease row is **`g.node.instance.gt/001`** (`staging`), which
carries `Run`: the lease is keyed (principal, run), so the run belongs in
the row. `000` keys on GNodeId alone and does not upgrade — a run cannot
be recovered from a standalone instance.

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

```
auth_backends.1 = internal          # mgmt UI + break-glass only
auth_backends.2 = http
auth_http.user_path     = http://localhost:8080/auth/user
auth_http.vhost_path    = http://localhost:8080/auth/vhost
auth_http.resource_path = http://localhost:8080/auth/resource
auth_http.topic_path    = http://localhost:8080/auth/topic
mqtt.ssl_cert_login = true
```

plus the GridWorks SASL mechanism plugin (AMQP claims), topic
authorization, `validated-user-id`, and the notch-3/4 `ssl_options`
(`verify_peer`, `fail_if_no_peer_cert = true`). No verdict caching
(`rabbit_auth_backend_cache` rejected — a cached allow for a just-revoked
instance breaches invariant 1). No fleet password users: on MQTT an
explicit username+password outranks the cert-derived name, so a live
password user is a CN bypass.

## Publishing operational messages

Once authorized, a client publishes with `properties.user_id` = its
authenticated identity (broker-validated) and routing-key segment 2 = its
current alias (FIS-validated per new key). Message bodies include
`FromGNodeAlias`, `MessageCreatedMs`; envelope-level `FromGNodeId` /
`FromGNodeInstanceId` await a proactor change (not immediate).

## FIS db structure

FIS maintains its own `g_node` mirror table in **strict bijection with
`g.node.gt`** (no position_point table or foreign key). The mirror consumes
the registry over **HTTP, never gnr's Postgres and never rabbit** — FIS is a
pure HTTP service and joins no broker. Three inputs keep it current, all over
gnr's read façade:

- **Boot seed + periodic pull-reconcile.** FIS pulls a forest snapshot
  (`g.node.forest.request`) for its served roots at startup, and re-pulls on
  an interval. The reconcile is the correctness backstop: it heals a mirror
  that missed an update.
- **gnr push, for immediacy.** gnr additionally pushes each change to a FIS
  mirror-update endpoint so a rename converges without waiting for the next
  reconcile. The push is **best-effort** — it never blocks gnr, the authority
  — which is why the reconcile above must exist.
- **Read-through on miss.** An auth for a GNodeId absent from the mirror (a
  freshly provisioned node connecting before its push/reconcile) is read
  through by id (`g-node-by-id`) on the spot and cached.

gnr being down never stops auth: FIS serves from the last-known mirror. The
registry is run-agnostic — runs are a fabric/FIS concern. The `principal`
table keys on the cert subject (GNodeId for GNodes — no second id; principal
UUID for services); the lease table keys on (principal, run).

**Invariant 1 is enforced in the schema**, not only in the gate: a partial
unique index on (principal_id, run) where status is Active. Supersession is
what keeps that index satisfiable; the index is what makes a bug in the
supersession path fail loudly instead of admitting two writers. No sema word
covers the principal model yet, so that table alone is hand-built — a
`fis.principal.gt` word retires the hand-building.

## Test plan

Before rolling to the fleet, auth must be fast and every deny witnessed:
valid cert + claims → allow; unknown principal, suspended principal,
revoked instance, wrong alias claim, run-claim ≠ vhost → deny; two
instances racing → ordered supersession (predecessor closed before
successor admitted); clean restart → admitted without delay; FIS latency
under ~100 concurrent connects.
