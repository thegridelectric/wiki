# Stand up FIS

Status: Accepted · Pass 1 · Updated 2026-08-14 · Linear: OPS-422

**EDD: yes** verified by the day-in-the-life handshake
([`../research/lifecycle.md`](../research/lifecycle.md)) run for real on the
staging broker: a client connects with its cert + claims, the broker calls
FIS, and FIS returns allow for a valid active instance; deny for revoked /
suspended / wrong claim / wrong run; a racing second instance supersedes
the first with the predecessor closed before the successor is admitted.

> What this is: build and deploy the Fleet Index Service. The **model is
> specified** in [`../executor/primary.md`](../executor/primary.md) (the
> gate, the invariants, deployment posture, rabbit config, db structure,
> test plan); the auth architecture it implements is OPS-420. This design
> does **not** restate that — it is the **ordered build plan**. The
> `gridworks-fleet-index-service` repo is README-only today, so this is
> from-scratch.

## Build order (each step maps to a section of `executor/primary.md`)

1. **Scaffold the service.** FastAPI + Postgres + `uv` (mirror the
   grid-node-registry stack). Settings via `pydantic-settings` (own
   `FIS_` prefix). Vendor the sema snapshot before the first consumer
   line (the claims word + `g.node.gt` + the auth event).
2. **FIS db.** The `g_node` mirror (strict bijection with `g.node.gt`,
   consuming gnr's on-change messages; serves auth when gnr is down), the
   `principal` table (keyed on cert subject: GNodeId for GNodes, principal
   UUID for services), and the `lease` table keyed **(principal, run)** —
   revoked rows permanent.
3. **`/auth/user` — the gate** (*executor "`/auth/user` — the gate"*).
   Claims arrive as the `claims` sema word (AMQP) or `client_id` + `vhost`
   (MQTT); decode through the snapshot codec, strict. Implement the five
   verdicts exactly: malformed → deny; principal missing/inactive → deny;
   lease match → allow; revoked → deny (forever); never-seen →
   **synchronous supersession before responding** — revoke prior lease,
   `DELETE /api/connections/<id>` via the management API, confirm **no
   connections remain** (empty kill = success), create lease, allow;
   kill unconfirmable → deny (fail closed). For AMQP GNodes, claimed
   alias/class must match the registry mirror.
4. **`/auth/{vhost,resource,topic}`.** vhost: claimed-run ≟ actual-vhost
   cross-check, else allow. resource: v1 allow-all. topic write:
   routing-key segment 2 ≟ wire-form current alias. topic read: allow.
5. **Reconvergence kills.** On a registry rename (mirror update), kill the
   identity's connections — the per-connection topic-verdict cache flushes
   with them.
6. **Auth event.** Publish `runtime.instance.authorization` asynchronously
   after each decision.
7. **Rabbit-side config** (*executor "Rabbit config"*): chained backends
   (`internal` for mgmt UI + break-glass, `http` → FIS on localhost),
   `topic_path`, topic authorization, `validated-user-id`,
   `mqtt.ssl_cert_login`, the GridWorks SASL mechanism plugin. Applied by
   rmqbot; first on the staging box.
8. **Deploy colocated with the broker** (*executor "Deployment"*): same
   box, localhost auth path, FIS before the broker in boot order; staging
   box (`hw1__2`) first, prod after the done-when battery passes.

## v1 scope

The gate with run-scoped leases + synchronous supersession; topic write
rule; vhost cross-check; resource and topic-read allow-all; the auth
event. Service principals are additive rows, no code fork.

## Done-when (the test plan in `executor/primary.md`)

- The lifecycle handshake works end-to-end on the staging broker (allow
  for valid active).
- **Revoked instance**, **suspended principal**, **wrong alias claim**,
  **run-claim ≠ vhost** each → deny.
- **Two instances racing** → ordered supersession: the predecessor's
  connections are closed before the successor is admitted; management API
  down → successor denied (fail closed).
- **Clean restart** (nothing to kill) → admitted without delay.
- A stale-alias node connects but its first publish is denied at
  `/auth/topic`.
- Auth stays fast under ~100 concurrent connects (measure FIS latency;
  pin the auth_http timeout budget).
