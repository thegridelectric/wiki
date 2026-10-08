# Stand up FIS

Status: Accepted · Pass 1 · Updated 2026-10-07 · Linear: OPS-422

**EDD: yes** verified by the day-in-the-life handshake
([`../executor/day-in-the-life.md`](../executor/day-in-the-life.md)) run for real on the
staging broker: a client connects with its cert + claims, the broker calls
FIS, and FIS returns allow for a valid active instance; deny for revoked /
suspended / wrong claim / wrong run; a racing second instance supersedes
the first with the predecessor closed before the successor is admitted.

> What this is: build and deploy the Fleet Index Service. The **model is
> specified** in [`../executor/primary.md`](../executor/primary.md) and
> its three spokes (the gate, the invariants, deployment posture, rabbit
> config, db structure, test plan); the auth architecture it implements is OPS-420. This design
> does **not** restate that — it is the **ordered build plan**.

## Build order (each step maps to a section of `executor/primary.md`)

Steps 1–8 are built (5c, the push accelerator, is not on the path).
The battery is green at every rung: dev (27/27 plus the reconnect
storm), the staging box `hw1-2` on 2026-09-06 (the identities' principal
rows minted on the box, client certs from certbot against the real CA,
FIS under systemd, the management-API-down leg over ssh: 27/27, storm
100/100, `experiments/2026-09-05-fis-gate-battery/battery-2026-09-06-hw1-2.log`),
and the CRL leg on the rig 2026-09-08 (38/38). The staging run is the
done-when; `hw1-2` is dropped (its reproducer rebuilds it). Every word
in the FIS closure is published. Prod step 1 is done: FIS runs on
`hw1-1` with the gate off and the mirror full. Prod step 2's platform
principals and certs are minted and placed (OPS-420, 2026-10-07). **Next
move: the "Before the gate" items below, then the house rows; the gate
itself is OPS-420's rollout item.** The stamps are open: the executor
hub and its three spokes are `Draft · Pass 0`, the green staging run is
their evidence, and the Pass/maturity call (Verified, `Reviewed
2026-09-06@7b00342`) is the human's.

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
   (MQTT); decode through the snapshot codec, strict. The verdicts:
   malformed → deny; principal missing/inactive → deny;
   lease match → allow; revoked → deny (forever); never-seen →
   **synchronous supersession before responding** — revoke prior lease,
   `DELETE /api/connections/username/<principal-id>` via the management
   API, confirm **no connections remain** (empty kill = success), create lease, allow;
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
5d. ✅ **Principal minting — `fis principal`.** The FIS-side primitive
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
   axiom) in sema; the sink is FIS's own
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
   and claims word, the MQTT legs a cert-bearing paho client.

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
   `experiments/2026-09-06-fis-staging-box/`. In order:
   - ✅ Publish `fis.connect.claims` in sema (every FIS word is
     published now).
   - ✅ Build the box from the recipe (hcloud, certbot server cert for
     `hw1-2.electricity.works`, Route 53); FIS up before the gate overlay.
   - ✅ Carry the battery identities' principal rows, minted on the box
     with the registry's ids (`setup-remote.sh`).
   - ✅ The battery's remote rung: rig from the environment (`rig.py`,
     `remote.env`), FIS and the management-API-down leg over ssh, certs
     cut on certbot against the real CA.
   - ✅ Run it: green 2026-09-06 (27/27, storm 100/100). The staging run
     is the done-when; the stamps follow the human's call.
   - Prod, in this order; each step is safe on its own and the gate
     comes last:
     1. ✅ **FIS on `hw1-1`** beside the broker, gate off:
        `gridworks-infra/fis/README.md` "Add FIS to a broker box" with
        `FIS_UNIVERSE=hw1` and the prod broker's management credential;
        the box pulls `main`. Nothing consults FIS yet; done when
        `/ping` answers and the mirror holds the `hw1` nodes. Done
        2026-09-07 at `fbc3262`: ping ok, boot reconcile inserted the
        25 `hw1` nodes from gnr, migrations at `a7c3e1f9b2d4`. The box
        differs from the recipe's Hetzner shape (EC2, one 16 GB root
        disk, no volume), so pgdata is a plain directory on root;
        recorded in the infra README and the platform inventory.
     2. ◐ **Principals and certs.** ✅ The platform rows exist on the prod
        FIS (read 2026-10-07 with `fis principal list`): weather as a
        GNode carrying the registry's GNodeId (`hw1.isone.weather`,
        `2af8a877-…`); gnr, ear, gjk and the alerter as Service
        principals, ids minted on the prod FIS with `fis principal
        create`, never on dev, cert CN = the printed id, a
        cert-inventory row each (OPS-420). The certs are placed and not
        enabled: a gwbase service has no password fallback, so it moves
        to cert plus claims only once the gate is on, with a bounded
        downtime (its restart) and a rollback of removing the three
        `*_RABBIT__TLS__*` lines. ✅ The house rows: eleven GNode
        principals minted 2026-10-07 from the ledger's CNs (five scadas,
        six LTNs, `--kind GNode --g-node-id`); elm's scada row waits on
        its cert being recorded (pi unreachable). Open, and the reason
        the houses stay on their internal password users through the
        gate window: the proactor's MQTT link sets paho's `client_id` to
        a random uuid with its last segment stripped, and FIS requires
        the MQTT `client_id` to be a uuid4 (the GNodeInstanceId) and
        denies anything else as malformed, so at notch 4 every house
        connect over MQTT would be denied. The fix is on the GridWorks
        proactor fork (`gwproactor/links/mqtt.py`): `client_id` = the
        instance id, stable for the process lifetime, with its test and
        a battery leg before the houses move (OPS-420).
     3. **The gate** on `hw1-1`: the overlay recreate (`compose.gate.yaml`,
        host network), re-mint the two internal accounts, then watch
        `auth_events` fill as each service restarts onto its cert. From
        this instant a connection is in or out on cert and claims alone
        and runtime users are wiped, so the four service restarts follow
        in the same window; the live-traffic cutover is the human's to
        run and is OPS-420's rollout item. Same step: rewrite the rmqbot
        README's "Runtime-created users" section and its TODO line to
        the two internal accounts that remain (management login,
        break-glass), each re-minted by recipe after a recreate; every
        fleet password user is deleted, and the declarative-users issue
        is cancelled.

## Before the gate (FIS side, found 2026-10-07 reading code against the executor)

Each goes in before the prod recreate; the first three are required
(two are in), the rest are decisions to make and record in the executor.

**Do this next:** the sema word. Read `sema/spec/primary.md`, then the
registry and authoring spokes for a type version; post the summary and
wait for the go-ahead; then author `fis.instance.authorization.event/001`
per the first bullet, regen, revendor the FIS snapshot, and make the
malformed `/auth/user` path in `api.py` record with reason
`MalformedRequest` (the HTTP test for it first). When that is in, the gate
window in OPS-420 has no FIS-side precondition left open.

- **Malformed denials are not recorded.** `api.py` returns deny on an
  undecodable `/auth/user` body with "No typed request to record
  against", so the executor's "every outcome is recorded" does not hold
  for the malformed path and `USER_REASONS` `Malformed` is unreachable
  from HTTP. The word forbids it: `fis.instance.authorization.event/000`
  requires `InstanceId` and `Run`, which a malformed request lacks.
  Decided 2026-10-07: a new version `001` makes `InstanceId` and `Run`
  optional; `PrincipalId` stays required (the cert CN, which the broker
  always forwards) and the reason-determines-decision axiom is
  unchanged. Then the malformed path records with reason
  `MalformedRequest`. Sema spec change control applies: registry and
  authoring read for a type version, summary back, go-ahead, then the
  edit, regen, and the FIS snapshot revendored.
- **HTTP-level `/auth/*` tests** ✅ `4e7070a` (branch
  `jm/fis-auth-http-tests`): form parsing, the `allow <run>` body, the
  denials and the background recording, through the FastAPI test client.
  The malformed case is added with the `001` word above.
- **`auth_http` request timeout pinned** ✅ `a8a2f02` (gridworks-infra
  `jm/gate-request-timeout`): `auth_http.request_timeout = 9500` in
  `fis-gate.conf`, under the broker's 10 s handshake and over the 9 s a
  full supersession spends. The number still wants recording in the
  executor's budget reasoning.
- **Read-through plus a kill can exceed the handshake budget.** A mirror
  miss costs the gnr timeout (5 s) before a kill's 8 s confirm; the
  executor's budget reasoning counts the kill alone. Decide: shorten one,
  or accept and state it.
- **MQTT GNodes get no read-through on a mirror miss.** `decide_topic`
  has none, so a freshly provisioned scada is admitted and every write is
  denied until the next reconcile (300 s). The executor says a GNodeId
  absent from the mirror is read through. Decide whether `/auth/topic`
  reads through too.
- **Rollback after an unconfirmed kill.** `gate.py` restores the
  predecessor's Active lease when the kill is unconfirmed, though the
  DELETE may already have closed its sockets; the executor says revoke
  and deny with no undo. Pick one and align the other.
- **Topic reads admit any non-write permission** (`permission !=
  "write"`); the executor names `read`. Narrow or restate.
- **Repo prose names the wiki.** `gate.py`, `api.py`, `mirror.py`,
  `settings.py`, `rabbit_admin.py` and `ci.sh` cite "build step", "FIS
  executor" or OPS ids. Rewrite to the code's own meaning.

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
- Auth stays fast under ~100 concurrent connects (witnessed on `hw1-2`);
  the `auth_http` request timeout is pinned (open, above).
- One identity holds simultaneous `hw1__1` and `hw1__2` leases on two
  brokers; the kill is broker-wide for the identity (Finding A), which
  is exact for a one-run broker.
- The executor test plan's remaining cases: wrong class, run outside the
  universe, and suspension alone not closing a live connection.
