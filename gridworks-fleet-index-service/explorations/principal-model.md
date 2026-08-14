# Concern: FIS auth for GNodes and non-GNode services

Status: Draft · Pass 0 · Updated 2026-08-14

> One FIS authorization path serving both GNode actors and non-GNode
> services (journalkeeper, ear, gnr, future analytics consumers), without
> forking the code per actor class. The identity/claims/wire questions this
> exploration originally held are **resolved by the mTLS+FIS design
> (OPS-420)** and specced in [`../executor/primary.md`](../executor/primary.md);
> what remains here is the service-specific tail.

## Resolved (by OPS-420 — the executor spec is the contract)

- **Identity: cert CN = the principal's immutable id.** GNodes:
  `CN=<GNodeId>` — the GNodeId *is* the principal key, no second id.
  Services: `CN=<principal UUID>`, minted with the principal row. The
  mutable `service_alias` is a runtime claim, GNode-style.
- **Claims travel in the handshake, not client_properties** (which never
  reach auth backends): a sema `claims` word via the GridWorks SASL
  mechanism on AMQP; `client_id = instance id` on MQTT. `GNodeClass`
  present in the claims iff the principal is a GNode — still the
  discriminator, now on a channel that actually reaches FIS.
- **`validated-user-id`** — adopted; part of the broker-enforcement
  invariant.
- **Permissions posture** — topic write pinned to the current alias;
  topic read / vhost (after the run cross-check) / resource allow in v1.
  Per-principal permission regexes are NOT part of v1.

## Still open

- **Single-writer for services.** The lease gate is uniform per
  (principal, run). No service runs replicas of one principal today (ear's
  two taps are two principals), so uniform single-writer costs nothing —
  but a future scaled consumer (N parallel readers on one principal) will
  need an explicit N-writer grant or per-replica principals. Decide when
  the first such consumer appears; lean per-replica principals (keeps the
  gate uniform).
- **Permission grammar** — whether a higher-level "role" abstraction
  (e.g., "ear-reader") expanding to rabbit permissions is worth it when
  `/auth/resource` tightens past allow-all. Defer until then.
- **Operator** (cloud admin) auth — a separate principal kind lands with
  the `gridworks-admin` design (OPS-429), including the WebAuthn step-up
  posture. Out of scope here.
