# Stand up FIS

Status: Draft · Pass 0 · Updated 2026-06-25 · Linear: OPS-422

**EDD: yes** verified by the day-in-the-life handshake
([`../research/lifecycle.md`](../research/lifecycle.md)) run for real: a SCADA
connects with its cert + `client_properties`, the broker calls FIS, and FIS
returns allow for a valid active instance, deny for revoked / suspended / wrong
claim, and a racing second instance supersedes the first.

> What this is: build and deploy the Fleet Index Service. The **model is already
> specified** in [`../executor/primary.md`](../executor/primary.md) (purpose, the
> four normative invariants, the `/validate` state machine, the rabbit config,
> revocation, shutdown, db structure, test plan) and
> [`../research/lifecycle.md`](../research/lifecycle.md) (the connect flow). This
> design does **not** restate that — it is the **ordered build plan** to
> implement it. The `gridworks-fleet-index-service` repo is README-only today, so
> this is from-scratch.

## Build order (each step maps to a section of `executor/primary.md`)

1. **Scaffold the service.** FastAPI + a DB + `uv` (mirror the grid-node-registry
   stack). Settings via `pydantic-settings`.
2. **FIS db = a GNode mirror.** FIS consumes the **grid-node-registry**'s
   on-change messages and maintains its own `g_node` table in **strict bijection
   with `g.node.gt`** (no position_point/edges) — see *FIS db structure*. This is
   what `/validate` checks claims against.
3. **`/validate` — the core state machine** (*`/validate` Endpoint
   Implementation*). Implement the three cases exactly:
   - **Malformed** → REJECTED.
   - **InstanceId already in DB** → same GNode + active → AUTHORIZED (idempotent
     reconnect); revoked → NOT_AUTHORIZED; different GNode → NOT_AUTHORIZED
     (security violation).
   - **InstanceId never seen** → verify GNode exists + Active, alias matches,
     class matches, instance-id structure; create the instance ACTIVE; if another
     instance is ACTIVE for that GNodeId, mark it REVOKED and close its
     connection (step 5); return AUTHORIZED.

   Map AUTHORIZED→`{"result":"allow"}`, NOT_AUTHORIZED/REJECTED→`{"result":"deny"}`.

   *Rename-convergence (from [OPS-419](https://linear.app/gridworks/issue/OPS-419)):*
   the **alias-matches** check above is also the backstop that re-converges a node
   after a GNode rename — a stale-alias claim fails to authorize, forcing the node to
   reconcile to the registry's current alias. The convergence design wants the node
   told its `current_alias`, but the `auth-backend-http` deny is a bare allow/deny —
   it can't carry a rich payload to a not-yet-connected client. So the **push** of
   `current_alias` needs a separate channel (a dedicated FIS reject endpoint the
   client may query, and/or the `runtime.instance.authorization` event), with the
   **registry-API pull** (`get gnode by {GNodeId}`) as the robust fallback. Pin this
   channel with the registry standup.
4. **`/auth/{user,vhost,resource}`.** `/auth/user` returns the `/validate`
   decision; **v1: `/auth/vhost` and `/auth/resource` allow-all**.
5. **Revocation via the Management API** (*Manual Broker Revocation*). On
   supersession, FIS lists connections, filters by username (=GNodeId),
   `DELETE /api/connections/<id>` so rabbit closes the socket immediately.
6. **Auth event.** After deciding, publish `runtime.instance.authorization`
   asynchronously (the audit record).
7. **Shutdown handling** (*SCADA Shutdown*): clean (SCADA notifies FIS → clear
   authorization) vs crash (no notice → authorization ends via the next
   instance's revocation).
8. **Rabbit-side config** (*Rabbit config*): `auth_mechanisms external`,
   `auth_backends http` pointing at the `/auth/*` paths, the mTLS `ssl_options`
   (`verify_peer`, `fail_if_no_peer_cert`), remove `guest`. (Applied on the
   broker; the spec lives in `executor/primary.md`.)
9. **Deploy** alongside the broker, reachable on the auth path; `.env`/secrets;
   migrations on deploy.

## v1 scope

`/auth/user` via `/validate` (claims check + single-writer supersession);
vhost/resource allow-all; the auth event. Non-GNode service principals
(static grant) are additive and can follow.

## Done-when (the test plan in `executor/primary.md`)

- The lifecycle handshake works end-to-end (allow for valid active).
- **Revoked instance**, **suspended GNode**, **wrong alias claim** each → deny.
- **Two instances racing** → the new one supersedes; the old connection is closed
  via the Management API.
- Auth stays fast under ~100 concurrent connects (measure FIS latency).
