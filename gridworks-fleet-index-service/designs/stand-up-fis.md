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

Steps 1–5 are built. With the mechanism plugin and the gwbase credentials
class both delivered, every non-FIS piece the dev battery needs now exists,
so **FIS step 6 is the last decision path before step 8**, alongside the
mirror seam (steps 5b–5c) — the critical path is this repo, not the broker
side.

1. ✅ **Scaffold the service.** FastAPI + Postgres + `uv` (mirror the
   grid-node-registry stack). Settings via `pydantic-settings` (own
   `FIS_` prefix). Vendor the sema snapshot before the first consumer
   line: the claims word, `g.node.gt`, the lease row, and the two forest
   words the mirror seam consumes. **Not** the auth event — it and its
   two enums are `draft`, which is excluded from runtime generation, so
   they cannot be vendored until promoted (see step 6).
2. ✅ **FIS db.** The `g_node` mirror (strict bijection with `g.node.gt`,
   consuming gnr's on-change messages; serves auth when gnr is down), the
   `principal` table (keyed on cert subject: GNodeId for GNodes, principal
   UUID for services), and the `lease` table keyed **(principal, run)** —
   revoked rows permanent, with single-writer enforced as a partial unique
   index rather than by the gate's care alone.
3. ✅ **`/auth/user` — the gate** (*executor "`/auth/user` — the gate"*).
   Claims arrive as the `claims` sema word (AMQP) or `client_id` + `vhost`
   (MQTT); decode through the snapshot codec, strict. Implement the five
   verdicts exactly: malformed → deny; principal missing/inactive → deny;
   lease match → allow; revoked → deny (forever); never-seen →
   **synchronous supersession before responding** — revoke prior lease,
   `DELETE /api/connections/<id>` via the management API, confirm **no
   connections remain** (empty kill = success), create lease, allow;
   kill unconfirmable → deny (fail closed). For AMQP GNodes, claimed
   alias/class must match the registry mirror.
4. ✅ **`/auth/{vhost,resource,topic}`.** vhost: claimed-run ≟ actual-vhost
   cross-check, else allow. resource: v1 allow-all. topic write:
   routing-key segment 2 ≟ wire-form current alias. topic read: allow.
5. ✅ **Reconvergence kills.** On a registry rename (mirror update), kill the
   identity's connections — the per-connection topic-verdict cache flushes
   with them. The apply step (`mirror.apply_gnode`: upsert a `g.node.gt`,
   detect rename, flush the identity) is built and tested against a fake
   killer.
5b. **Mirror seam — pull from gnr over HTTP (Phase A).** The path that feeds
   `mirror.apply_gnode`, keeping FIS off rabbit. A `gnr_client` (httpx to
   gnr's read façade: `g.node.forest.request`, `g-node-by-id`) plus a
   reconcile loop (a FastAPI-lifespan background task): boot-seed a forest
   snapshot for the served roots, then re-pull on an interval. `apply_forest`
   loops `apply_gnode` over `forest.nodes` and marks a node gone from the
   active forest inactive (exact rule confirmed against `g.node.gt` status at
   build). `decide_user` reads-through on a mirror miss — an unknown GNodeId
   is fetched by id and cached rather than denied outright. gnr down → serve
   the last-known mirror. Reuses `apply_gnode` / `kill_identity` and the
   vendored `GNodeForest` / `GNodeForestRequest`; **no gwbase, no rabbit**.
5c. **Mirror seam — gnr push accelerator (Phase B, coordinated with gnr).** A
   FIS mirror-update endpoint receives gnr's pushed change →
   `apply_forest` / `apply_gnode`; a rename delta fires `kill_identity` at
   once. It is a non-localhost ingress, so **mTLS-authenticated to gnr's
   principal** (OPS-420 plane). The gnr side (OPS-419 follow-up) tracks FIS
   endpoints and POSTs best-effort on change; the 5b reconcile is the heal
   for a missed push. The **node self-heal** (a renamed node re-fetching its
   alias from gnr by GNodeId on reconnect) is the client half — OPS-420 /
   gwbase-proactor, not this issue. The ~1s pre-rename courtesy note is
   deferred to a v2 gnr refinement.
6. **Auth event.** Publish **`fis.instance.authorization.event`**
   asynchronously after each decision. It and its two enums
   (`fis.authorization.decision`, `fis.authorization.reason`) are `draft`
   and therefore unusable: promote all three to `staging` and revise them
   to match the gate's contract, then re-run the snapshot build, before
   the first line that emits one.
7. **Rabbit-side config** (*executor "Rabbit config"*): chained backends
   (`internal` for mgmt UI + break-glass, `http` → FIS on localhost),
   `topic_path`, topic authorization, `validated-user-id`,
   `mqtt.ssl_cert_login`, and mounting the GridWorks SASL mechanism
   plugin. Applied by rmqbot; first on the staging box. The plugin itself
   is **built** — it ships as a mountable `.ez` against the pinned 4.1
   image, with the gwbase pika credentials class that supplies the claims
   payload, so this step configures and mounts rather than builds.
8. **Run the whole battery locally first, on the dev universe.** The full
   stack — FIS, broker conf, mechanism plugin, a claims-bearing client —
   against `gw-dev-rabbit` on `d1__1` before any remote box. A dev
   universe is defined by all comms going through localhost brokers, which
   is also the only place `staging` vocabulary may run: `fis.connect.claims`
   and `g.node.instance.gt/001` stay mutable through this stage and harden
   against real handshakes rather than against review.
9. **Deploy colocated with the broker** (*executor "Deployment"*): same
   box, localhost auth path, FIS before the broker in boot order; staging
   box (`hw1__2`) first, prod after the done-when battery passes.
   `fis.connect.claims` publishes before the box serves `hw1__2` — it
   crosses the wire, and staging vocabulary is dev-brokers-only. The lease
   row may stay `staging` longer: it is a row in FIS's own Postgres and
   never crosses a broker.

## v1 scope

The gate with run-scoped leases + synchronous supersession; topic write
rule; vhost cross-check; resource and topic-read allow-all; the auth
event. Service principals are additive rows, no code fork.

## Done-when (the test plan in `executor/primary.md`)

The battery runs twice: first on `d1__1` against the local dev broker,
then for real on the staging box. Dev catches the mechanical failures
cheaply; only the staging run counts as verification.

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
