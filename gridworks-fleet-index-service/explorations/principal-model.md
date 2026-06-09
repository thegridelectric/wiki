# Concern: FIS auth for GNodes and non-GNode services

Status: Draft · Pass 0 · Updated 2026-05-29

> Open architectural question. Today FIS authorizes GNode runtime
> instances against the GNode registry. With gwbase about to ship
> support for non-GNode rabbit+sema actors (journalkeeper, ear's
> actor-side, future analytics consumers), we want **mTLS for ALL
> prod-broker connections** and **one FIS authorization path** that
> serves both kinds — without forking the code per actor class.

## Wire handshake — what every connection sends

```
ServiceAlias       (always; LeftRightDot)
ServiceInstanceId  (always; ephemeral UUID, new every boot)
GNodeClass         (optional; present iff this connection is a GNode)
```

The presence of `GNodeClass` is the discriminator: if it's there,
the principal is a GNode and FIS enforces GNode semantics
(single-writer per `GNodeId`, cross-check against the GNode
registry). If absent, the principal is a service and FIS authorizes
against a static permission grant.

`ServiceAlias` and `ServiceInstanceId` are meaningful for both —
they identify the runtime party for auth, audit, and observability.

## FIS-side data model

A single `principal` table keyed by mTLS cert subject:

```
principal
  ├─ cert_subject       (the subject string the broker sees)
  ├─ service_alias      (LeftRightDot — matches the handshake field)
  ├─ status             (active | suspended | revoked)
  ├─ permissions        (per-vhost: configure / write / read regex)
  ├─ single_writer      (TRUE for gnodes; FALSE by default)
  └─ gnode_id           (nullable; populated iff this principal is a GNode)
```

- **`/auth/user`** — look up `cert_subject`; check `status=active`; return allow.
- **`/auth/vhost`** / **`/auth/resource`** — consult `permissions`.
- **For GNode principals only** — additionally enforce single-writer per
  `gnode_id` against the live `ServiceInstanceId`, against the GNode
  registry, per existing FIS Invariant #1.

The four FIS invariants from [`../design.md`](../research/design.md) all
hold unchanged. Non-GNode auth is additive — services get a
principal row with `gnode_id=NULL` and static permissions; nothing
about GNode handling changes.

## Cert subjects

A predictable subject grammar lets the broker / FIS look up the
principal without ambiguity. Simplest workable form:

```
CN=<service_alias>
```

GNode vs service is determined by whether the principal row has
`gnode_id` populated (not by the cert subject itself). Cert
issuance is handled by provisioning
([`../../../gridworks-provisioning/executor/primary.md`](../../gridworks-provisioning/executor/primary.md)),
which mints a cert + principal row together for both kinds.

## What this means for in-flight work

- **gwbase Wave-1**: `ActorBase` populates `client_properties` with
  `ServiceAlias` + `ServiceInstanceId` always. `GridworksActor`
  additionally adds `GNodeClass`. The handshake is meaningful
  (not informational-only) — FIS reads it.
- **Provisioning**: extends to mint cert + principal row for both
  GNode and service kinds (today mints GNode identity only).
- **rmqbot**: `prod-tls-fix` + `mtls-fis-auth` Phase 0 are
  prerequisites for any non-GNode service migrating onto the prod
  broker — we're committing to mTLS-for-all.

## Open

- **`validated-user-id` broker plugin** — to give consumers a
  trustworthy publisher identity on every message, the prod broker
  should run RabbitMQ's `validated-user-id` plugin (or equivalent),
  which enforces that `properties.user_id` on every publish matches
  the AMQP connection's authenticated identity (cert subject for
  mTLS connections). With it enabled, a SCADA consuming an admin
  routing key can trust `properties.user_id` for audit attribution
  on the fat-client path. **Triggered by:** the admin design's
  audit-attribution requirement
  ([`../../../gridworks-admin/executor/primary.md`](../../gridworks-admin/executor/primary.md)
  "Operator identity for audit"). FIS team + rmqbot team decision.
- **Service `single_writer` defaults** — FALSE by default, but some
  services (e.g., a single canonical ear-actor process) may opt in.
  Per-principal config decision.
- **Cert lifecycle** for service certs — who issues, rotation
  cadence, revocation propagation. Probably mirrors the GNode path
  (FIS-issued or FIS-via-certbot).
- **Permission grammar** — per-vhost regex matches what RabbitMQ
  expects directly; do we want a higher-level "role" abstraction
  (e.g., "ear-reader") that expands to permissions? Probably yes
  for operability; defer.
- **Operator** (cloud admin) auth — a separate principal kind will
  land here when the `gridworks-admin` design begins. Out of scope
  for this concern; tracked in the admin domain.
