# Stand up FIS

Status: Accepted · Pass 1 · Updated 2026-09-06 · Linear: OPS-422

**EDD: yes** verified by the day-in-the-life handshake
([`../executor/day-in-the-life.md`](../executor/day-in-the-life.md)) run for real on the
staging broker: a client connects with its cert + claims, the broker calls
FIS, and FIS returns allow for a valid active instance; deny for revoked /
suspended / wrong claim / wrong run; a racing second instance supersedes
the first with the predecessor closed before the successor is admitted.

> What this is: build and deploy the Fleet Index Service. The **model is
> specified** in [`../executor/primary.md`](../executor/primary.md) and
> its two spokes (the gate, the invariants, deployment posture, rabbit
> config, db structure, test plan); the auth architecture it implements is OPS-420. This design
> does **not** restate that — it is the **ordered build plan**. The
> `gridworks-fleet-index-service` repo is README-only today, so this is
> from-scratch.

## Build order (each step maps to a section of `executor/primary.md`)

Steps 1–8 are built; the dev battery is green (27/27 verdicts plus the
reconnect storm) with Findings A and B both closed. Step 9's box is
built and live: `hw1-2` serves `hw1__2` with the gate ON and FIS beside
it on the `jm/stand-up-fis` branch (`experiments/2026-09-06-fis-staging-box/`,
two findings fixed there: the broker container needs the host network to
reach FIS on loopback; `fis api` now configures logging). Every word in
the FIS closure is published. **Next move: the battery's remote rung
against `hw1-2` — pull the pushed logging fix onto the box first, then
carry the identities' principal rows there, cut their client certs on
certbot against the real CA, and run `experiments/2026-09-05-fis-gate-battery/`
with the broker host from the environment and the FIS and
management-API-down legs over ssh. That green run is the Verified stamp.** The push
accelerator (5c) is not on that path. Also open: mint the four
platform-service principals (weather, gnr, ear, gjk) with `fis principal
create` and cut their certs — the per-service walkthrough (who runs what,
in which order) lives in the mTLS design, OPS-420, "Minting a
platform-service cert".

1. ✅ **Scaffold the service.** FastAPI + Postgres + `uv` (mirror the
   grid-node-registry stack). Settings via `pydantic-settings` (own
   `FIS_` prefix). Vendor the sema snapshot before the first consumer
   line: the claims word, `g.node.gt`, the lease row, and the two forest
   words the mirror seam consumes; the auth event joined the seed at
   step 6, once its words reached `staging`.
2. ✅ **FIS db.** The `g_node` mirror (strict bijection with `g.node.gt`,
   consuming gnr's on-change messages; serves auth when gnr is down), the
   `principal` table (keyed on cert subject: GNodeId for GNodes, principal
   UUID for services), and the `lease` table keyed **(principal, run)** —
   revoked rows permanent, with single-writer enforced as a partial unique
   index rather than by the gate's care alone.
3. ✅ **`/auth/user` — the gate** (*executor `auth-endpoints.md` "`/auth/user` — the gate"*).
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
5b. ✅ **Mirror seam — pull from gnr over HTTP (Phase A).** The path that
   feeds `mirror.apply_gnode`, keeping FIS off rabbit. `gnr_client` (httpx to
   gnr's read façade: `g.node.forest.request`, `g-node-by-id`, every reply
   decoded strictly through the snapshot codec) plus a reconcile loop (a
   FastAPI-lifespan background task): boot-seed, then re-pull on
   `FIS_GNR_RECONCILE_S`. Two facts settled at build, both narrower than
   first written: the served roots are the universe itself (`[universe]` is
   a valid forest root and a FIS serves one universe, so no roots setting),
   and nothing is marked inactive by absence (a registry node never
   vanishes, so a mirrored id missing from a whole-universe pull is a
   logged anomaly, not a status FIS invents). `decide_user` reads through on
   a mirror miss before the alias/class check. gnr down → serve the
   last-known mirror. Witnessed at the dev rung: a real `fis api` boot
   against a local gnr refilled a cleared mirror with the 29 `d1` nodes.
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
5d. **Principal minting — `fis principal`.** The FIS-side primitive
   provisioning calls when it cuts a cert: `create` mints the principal row
   first and prints its id, which becomes the cert CN (`gwcert key add
   --common-name <id>`). A service principal's id is a fresh uuid4 minted
   here; a GNode principal's id is its GNodeId, given. `list`, `suspend`
   and `activate` complete the emergency-eviction lever the gate already
   honors. Row first, cert second, so a CN is never a hand-picked UUID the
   row is back-filled to match; the four platform-service certs (weather,
   gnr, ear, gjk) mint through this. Rows minted on one FIS database are
   carried to the database that will gate the cert (staging, then prod)
   as records, not re-typed.
6. ✅ **Auth event.** Record a **`fis.instance.authorization.event`** after
   each `/auth/user` verdict. The word and its two enums were reshaped to
   the gate's contract (reason per verdict path, `PrincipalId` not
   `GNodeId`, required `Run`, a Reason → Decision projection with its
   axiom) and flipped `draft → staging` in sema; the sink is FIS's own
   `auth_events` table, bijective with the word, written from a
   background task after the response; the migration was run up and down
   on a fresh database.
7. ✅ **Rabbit-side config** (*executor "Rabbit config"*). Landed as an
   overlay in rmqbot (`rmq-docker/gate/` + `compose.gate.yaml`): the
   conf fragment rides `conf.d` on top of any box's `rabbitmq.conf`, so
   one file serves the dev harness, staging, and prod; the plugin list
   adds the http backend and the mechanism; the `.ez` mounts from
   `auth-mechanism/`. Witnessed on the stock 4.1.8 image: both plugins
   `[E*]`, backends `[internal, http]`, mechanisms
   `[GRIDWORKS, PLAIN, AMQPLAIN]`, bare-CN usernames, MQTT cert login on.
   Not in the fragment by design: the `ssl_options` tightening (prod's
   notch 3) and any verdict cache.
8. ✅ **Run the whole battery locally first, on the dev universe.** The full
   stack — FIS, the broker gate overlay, the mechanism plugin, real
   claims-bearing clients — against a stock 4.1.8 broker on `d1__1`. Built and
   run: `experiments/2026-09-05-fis-gate-battery/`. 27/27 verdicts pass,
   including ordered supersession of an idle predecessor, a clean restart
   admitted in under half a second, fail-closed with the management API
   unreachable, and a 100-connection reconnect storm inside the
   10 s handshake budget; the AMQP legs use gwbase's own credentials class
   and claims word, the MQTT legs a cert-bearing paho client. A dev universe
   is defined by all comms going through localhost brokers, which is also
   the only place `staging` vocabulary may run: `fis.connect.claims` and
   `g.node.instance.gt/001` stay mutable through this stage.

## Findings (step 8, dev battery)

**A — supersession is not authoritative (closed).** The kill found and
confirmed the predecessor's connections through the management listing,
which is stats-backed and lags, so a young predecessor survived beside its
successor and a clean restart read as unconfirmed. The shipped shape is in
the executor's "`/auth/user` — the gate": close-by-username on the
management API, confirm through the management API's by-username view
(served from the broker's connection-tracking table, not the stats
database), a two-phase close for a predecessor that never answers the
broker's Connection.Close, and an 8 s confirm budget that covers the
broker's 5 s TLS close wait for a peer that is not reading. The decided
`rabbitmqctl` confirm was built and measured first and dropped, with the
box wiring it needed: `list_connections` deadlocks with the gate (it asks
the successor's own blocked reader), and an `eval` on the tracking table
costs an Erlang VM per call, which the reconnect storm turned into 9 s
connects. close-by-username is broker-wide for the identity — exact for a
one-run broker, witnessed on the dev broker's `d1__2` leg as a logged
limit; a vhost-scoped kill, if a broker ever multiplexes runs, would read
the tracking table's per-connection vhost and pid.

**B — `/auth/vhost` could not see the claimed run (closed).** The vhost
call carries no claims (AMQP picks the vhost at Connection.Open, after
SASL), so FIS had answered it from the lease table, "does this principal
hold an active lease on this vhost", which admits a connection that
claimed another run whenever the identity is legitimately live there. The
shipped shape is in the executor's "How the claims arrive": the user
verdict is `allow <run>`, the broker makes the run the connection's user
tag and forwards it as `tags` on the vhost call, and the vhost check
compares tag to vhost with no lease lookup. The battery scores it as
`run_claim_vs_vhost_deny_with_live_lease`; the broker-wide kill from A
is unchanged.

9. **Deploy colocated with the broker** (*executor "Deployment"*): same
   box, localhost auth path, FIS before the broker in boot order; staging
   box (`hw1-2`, serving `hw1__2`) first, prod after the done-when
   battery passes. The staging box is its own Hetzner server, not the
   prod broker box: the battery kills connections and takes the
   management API down, and wiring the gate into prod is a container
   recreate that wipes runtime users, which is the rehearsal this box
   exists for. Repo half ✅: `service/fis-api.service`, `bash_aliases`,
   `deploy.sh`, README "Deploying" in the FIS repo; `gridworks-infra/fis/`
   (FIS on any broker box, plus the homedir README); the ephemeral box's
   build with its staging `rabbitmq.conf` (TLS-only,
   `fail_if_no_peer_cert`, vhost `hw1__2`) as the reproducer
   `experiments/2026-09-06-fis-staging-box/`. Remaining,
   in order:
   - Publish `fis.connect.claims` in sema: it crosses the wire and
     staging vocabulary is dev-brokers-only. The lease row and the auth
     event may stay `staging` longer: rows in FIS's own Postgres.
   - Build the box from the recipe (hcloud, certbot server cert for
     `hw1-2.electricity.works`, Route 53); FIS up before the gate overlay.
   - Carry the principal rows: the battery identities and the four
     platform services, minted on the box with the same ids.
   - Adapt the battery for a remote rung: broker host and ports from the
     environment, FIS started and stopped over ssh (it starts FIS itself
     today), the management-API-down leg through ssh, certs cut on certbot
     against the real CA instead of the throwaway one.
   - Run it; the green staging run is the Verified stamp.

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
