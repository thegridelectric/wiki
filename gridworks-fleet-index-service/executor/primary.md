# Fleet Index Service (FIS) — spec (primary)

Status: Draft · Pass 0 · Updated 2026-06-25

> What this is: the faithful spec of the **Fleet Index Service (FIS)** — the
> authority-plane service that enforces a single authorized `GNodeInstanceId` per
> `GNodeId`. Promoted from `research/design.md`; originally migrated from
> `gridworks-infra/authority/fleet-index-service/`. The build plan is the
> `stand-up-fis` design (tracked in Linear); the non-GNode-services extension is
> [`../explorations/principal-model.md`](../explorations/principal-model.md).

## Purpose

Enforces single authorized `GNodeInstanceId` per `GNodeId`. Lease-based
single-writer authority: a GNode has at most one live instance, and a new
instance implicitly supersedes the old one.

## Scope

- Tracks active instances.
- Determines the authoritative instance.
- Exposes the RabbitMQ HTTP authentication endpoints `/auth/user`, `/auth/vhost`,
  `/auth/resource`:
  - `/auth/vhost` — check the GNode may access the vhost. **v1: always allow `/`.**
  - `/auth/resource` — check publish/consume permissions. **v1: allow all.**

## Authority guarantees

At most one authoritative instance per `GNodeId` at any point in time.

## Invariants (normative)

1. **Single writer** — for each `GNodeId`, at most one `GNodeInstanceId` SHALL be
   authorized at any time.
2. **Explicit authority** — operational publish rights SHALL NOT be inferred from
   naming conventions or network location; authority SHALL be granted explicitly
   via FIS.
3. **Separation of identity and instance** — mTLS SHALL authenticate the durable
   identity `GNodeId`; FIS SHALL authorize the active runtime `GNodeInstanceId`.
4. **Broker enforcement** — the broker SHALL enforce that only the authorized
   `GNodeInstanceId` may publish operational messages for a given `GNodeId`.

## Authorization behavior

### `/validate`

- **Case 1 — malformed query** → REJECTED.
- **Case 2 — InstanceId already in DB:**
  - same `GNodeId`, marked active → AUTHORIZED (idempotent reconnect);
  - same `GNodeId`, marked revoked → NOT_AUTHORIZED;
  - different `GNodeId` → NOT_AUTHORIZED (security violation).
- **Case 3 — InstanceId never seen.** Verify claims:
  1. GNode exists (look up `g.node.gt` in the registry by `GNodeId`);
  2. GNode `Status`;
  3. `registry.Alias == claimed_alias`;
  4. `registry.GNodeClass == claimed_class` (and `registry.BaseClass ==
     claimed_base_class`);
  5. InstanceId structure.

  Then create the record (associate InstanceId with `GNodeId`, mark ACTIVE); if
  another instance is ACTIVE for that `GNodeId`, mark it REVOKED and close its
  connection (see *Revocation*); return AUTHORIZED.

Map: AUTHORIZED → `{"result": "allow"}`; NOT_AUTHORIZED / REJECTED →
`{"result": "deny"}`.

After returning, publish an auth event asynchronously:

```json
{
  "EventId": "4e5a6b1c-2d3e-4f5a-8b9c-1d2e3f4a5b6c",
  "GNodeId": "9cff2689-eadc-4577-94ea-6d86d0d23e9e",
  "GNodeAlias": "d1.isone.me.versant.keene.beech.scada",
  "GNodeInstanceId": "b6d86d0d-23e9-4c3d-8123-89c71f6a21bc",
  "Decision": "Authorized",
  "Reason": "NewInstanceSupersedesPrevious",
  "DecidedAtUnixS": 1771979700,
  "TypeName": "runtime.instance.authorization",
  "Version": "000"
}
```

### Rabbit config

```
auth_mechanisms.1 = external
auth_backends.1 = http
auth_http.user_path = http://fis:8080/auth/user
auth_http.vhost_path = http://fis:8080/auth/vhost
auth_http.resource_path = http://fis:8080/auth/resource
```

Enable the `rabbit_auth_backend_http` plugin. mTLS:

```
listeners.ssl.default = 5671
ssl_options.cacertfile = /etc/rabbitmq/ca.pem
ssl_options.certfile   = /etc/rabbitmq/server_cert.pem
ssl_options.keyfile    = /etc/rabbitmq/server_key.pem
ssl_options.verify = verify_peer
ssl_options.fail_if_no_peer_cert = true
ssl_options.ciphers.1 = ECDHE-ECDSA-AES256-GCM-SHA384
ssl_options.ciphers.2 = ECDHE-RSA-AES256-GCM-SHA384
loopback_users.guest = false
```

…and remove `guest`.

### Publishing operational messages

Once authorized and broker-enforced, a SCADA may publish operational messages.
Include in the messages: `FromGNodeAlias`, `MessageCreatedMs`. **For later** (an
envelope audit trail, requires a proactor change — not immediate):
`FromGNodeInstanceId`, `FromGNodeId`.

### Revocation (Management API)

On supersession: FIS marks the old instance unauthorized, lists rabbit
connections, filters by username (`=GNodeId`), `DELETE /api/connections/<id>` so
rabbit closes the socket immediately, then marks the new instance authorized.

### Shutdown

- **Clean** — SCADA notifies FIS; FIS clears (marks ended) the authorization.
- **Crash / power loss** — no notice; authorization ends via the next instance's
  revocation.

## FIS db structure

The grid-node-registry emits messages on change; FIS consumes them and populates
its own `g_node` table, keeping a **strict bijection with `g.node.gt`** (no
position_point table or foreign key).

## Test plan

Before rolling to the fleet, auth must be fast. Test: valid cert; revoked
instance; suspended GNode; wrong alias claim; two instances racing; and FIS
latency under ~100 concurrent connects.
