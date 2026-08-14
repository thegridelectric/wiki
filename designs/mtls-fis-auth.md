# mTLS + FIS auth

Status: Accepted · Pass 1 · Updated 2026-08-14 · Linear: OPS-420

**EDD: yes** verified by real handshakes against a broker running the full
stack: a client proves identity with its cert and claims, FIS allows a valid
active instance, and each deny case (unknown cert, suspended principal,
revoked instance, stale alias, unentitled publish) is witnessed — not code
review.

> What this is: move the production broker from password auth to
> **certificate-based mutual TLS**, with the **Fleet Index Service (FIS)** as
> the authorization authority. Cross-cutting — it spans **rmqbot** (broker
> conf + the auth-mechanism plugin), **FIS** (the principal model and gate),
> **gwbase** (the claims handshake), **provisioning** (client certs), and the
> **scada/proactor** MQTT side.

## Protocol ground truth (verified 2026-08-14, rabbitmq-server source)

The wire facts the rest of this design stands on, read from the plugin and
broker source rather than assumed:

- `rabbitmq-auth-backend-http` forwards, on `user_path`: `username` plus
  **everything in `AuthProps`** (it filters only internals, sockets, and
  connection context — `extract_other_credentials/1`). The other paths send
  fixed fields; `topic_path` additionally carries the **`routing_key`** of
  every topic publish. Password "may be missing if e.g.
  rabbitmq-auth-mechanism-ssl is used" (plugin README).
- The AMQP 0-9-1 reader **never puts `client_properties` into `AuthProps`**.
  They are stored on the `#connection` record and emitted in the
  `connection_created` event (visible to the management API), but are
  structurally isolated from authentication.
- The MQTT adapter builds
  `AuthProps = [{vhost, VHost}, {client_id, ClientId}, {password, Password}]`
  — so an MQTT client's **`client_id` reaches the auth backend at connect**.
  MQTT 3.1.1 has no client_properties at all.
- The stock `rabbit_auth_mechanism_ssl` (EXTERNAL) **ignores the SASL
  response bytes entirely** and calls `check_user_login(Username, [])`; the
  username comes from the peer cert via `rabbit_ssl:peer_cert_auth_name/1`.

Consequence: the earlier plan — FIS reading `ServiceAlias` /
`ServiceInstanceId` / `GNodeClass` claims out of AMQP `client_properties` at
`/auth/user` — is unimplementable on stock parts, and was never available on
MQTT. The FIS executor's `/validate` input description and
`gridworks-fleet-index-service/research/lifecycle.md` step 4 describe that
plan; both are reconciled when this design is accepted. gwbase's
`_client_properties()` handshake stays (the management API and
`connection_created` event read it — audit and reconciliation value), but it
is no longer the auth channel.

## The target

- **mTLS for every prod-broker connection.** The cert subject is the
  **immutable identity, and it is the principal key**: for a GNode,
  `CN=<GNodeId>` — the GNodeId *is* the principal id, no second id; for a
  service, `CN=<principal UUID>`, minted with the principal row. One
  identity rule for both kinds. The broker derives the username from the
  CN. The **alias is a runtime claim**, checked against the registry's
  current alias — never part of the cert, so a rename never reissues it.
- **Claims reach FIS at the gate, per protocol:**
  - **AMQP** — a GridWorks SASL mechanism plugin (small fork of
    `rabbit_auth_mechanism_ssl`, see *The mechanism plugin* below): identity
    from the peer cert exactly as stock, plus the SASL response bytes passed
    through **verbatim** as a single `claims` `AuthProps` param — from where
    the **stock** http backend forwards them to FIS. The payload is the
    **`fis.connect.claims`** sema word — `Alias`, `InstanceId`, `Run` (new
    `universe.run` format), and `GNodeClass` iff the principal is a GNode,
    the GNode discriminator — decoded at FIS through its vendored snapshot
    codec. The plugin never parses the payload; claim evolution is a word
    version, not a plugin rebuild.
  - **MQTT** — `client_id = GNodeInstanceId`, stock-forwarded, no sema
    envelope (accepted asymmetry: MQTT's handshake has one slot). The alias
    claim is enforced at first publish instead (see *Alias pinning*); the
    vhost arrives natively in MQTT's `AuthProps`. The CONNECT password
    field is dead as a second claims slot, checked at source: with
    `ssl_cert_login` it arrives as `{password, none}` (filtered), and an
    explicit username+password **takes priority over the cert-derived
    name** (`creds/3`) — using it would bypass CN identity. Alias-at-
    connect on MQTT is closed off; first-publish enforcement is final.
- **FIS gate rule** (`/auth/user`): allow iff the principal is `active`
  **and** the presented instance id is compatible with the lease state —
  matches the active lease (reconnect), or is new (supersession, below).
  The lease is keyed **(identity, run)** — single-writer authority is
  per-run (gnr executor "Universes"), so one GNode identity legitimately
  holds simultaneous leases in `hw1__1` and `hw1__2`. On AMQP the run comes
  from the claims and `/auth/vhost` (which carries the actual vhost)
  cross-checks the claim, denying mismatch; on MQTT the vhost is in
  `AuthProps` directly. A **revoked instance id is denied forever**. No
  claims where claims are required ⇒ deny. FIS unreachable ⇒ no answer ⇒
  no join — this dependence is the point, and there is **no verdict
  caching** (`rabbit_auth_backend_cache` rejected: a cached allow for a
  just-revoked instance id would breach the single-writer invariant inside
  the TTL).
- **Trustworthy publisher identity.** The broker's `validated-user-id`
  enforcement makes `properties.user_id` on every publish match the
  connection's authenticated identity — the audit attribution basis.

## Single-writer: the invariant and its mechanics

> At no point are two broker connections authorized for the same `GNodeId`.
> A connection is admitted only with a claims-carrying handshake whose
> instance id matches FIS's current lease; admission of a successor
> completes only after the predecessor's connections are confirmed closed;
> a revoked instance id is denied forever.

Mechanics: on a never-seen instance id for a leased (identity, run), FIS —
**synchronously, inside the auth callback, before returning `allow`** —
marks the old instance revoked, closes its connections via the management
API (`DELETE /api/connections/<id>`), confirms, and only then allows. The
http backend blocks on FIS's response, so this ordering is enforceable.
**Confirm means "no connections remain for this identity on this run" —
an empty kill is success**: every systemd restart is a supersession (fresh
instance id per boot), and after a clean stop there is nothing to close;
treating the no-op as failure would deny every routine restart. If the
kill cannot be confirmed, FIS returns `deny` (**fail closed**): the new
instance waits rather than coexists.

**A lease ends only by supersession.** There is no goodbye: clean shutdown
and crash are identical (the executor's clean-shutdown notification is
retired), and a decommissioned node's eternal lease is inert — the gate
denies on principal status regardless of lease state. Emergency eviction is
principal suspension + connection kill, independent of leases. "Is an
instance live *now*?" is the parked liveness question
(`gridworks-fleet-index-service/explorations/g-node-instance-and-liveness.md`),
answerable later from connection state without touching the gate.
**Revoked lease rows are permanent**: revoked-forever is a claim about
history, and a TTL cleanup would quietly re-admit an old zombie. Rows are
tiny; they stay.

Why the gate must carry the instance id: an enforcement that reconciles
*after* connect (management-API polling, event listeners) bounds the
two-instances window only by the health of the reconciler — an unbounded
window in the worst case. Two connections representing the same GNode is
not acceptable, so the check lives in the gate. Broker-native MQTT session
takeover (`client_id = GNodeId`) was considered and rejected: it implements
newest-wins with no notion of legitimacy — a hung zombie auto-reconnecting
steals the session back from its rightful successor — and its kick is an
asynchronous cast with FIS out of the loop. With the instance id at the
gate, a superseded zombie presents its own revoked id and is refused.

A claims-bearing connect requires the GNodeId's private key (the claims ride
inside a handshake only the key-holder can complete), so instance-forgery is
key theft — and single-writer then makes the theft loud: thief and rightful
node supersede each other in a visible churn of auth events.

## Alias pinning — enforced where the alias does work

Connect-time auth proves who a client IS; the **routing key's from-alias
segment** is asserted per message. The closure: with RabbitMQ **topic
authorization** enabled, every topic publish triggers `/auth/topic` carrying
the routing key, and FIS enforces

> publish is authorized iff segment 2 of the routing key equals the
> wire-form (hyphenated) of the registry's current alias for the
> connection's identity.

One rule covers all three transport grammars — `rj`, `rjb`, and `gw` all put
the from-alias at segment 2 (the `gw` grammar's *destination* segment is a
short spaceheat-node name, local to the house and never FIS's business).
The from-alias becomes broker-authenticated for every consumer at once:
consumers do no crypto and hold no identity state (the one-authz-layer
principle). Together with `validated-user-id`, header and key cannot
disagree by construction. On AMQP the alias is *additionally* checked at
connect (it rides the claims payload); on MQTT the stale-alias deny lands
at first publish — functionally equivalent, different surface.

**The read side is open.** `/auth/topic` with `permission: read` (fired on
every MQTT subscribe, since a subscription creates a binding) returns
allow, as do `/auth/vhost` and `/auth/resource` in v1. Deliberate:
authorization here is about **authority, not visibility** — the write rule
carries the integrity weight, while a read rule would make every future
consumer (admin console, analytics tap, debugging session) need grant
plumbing before it could listen. The accepted cost, named: a stolen fleet
cert can passively read fleet traffic until its principal is suspended.
Telemetry and prices are not secrets; if a payload class ever becomes
confidential, the remedy is encrypting that payload (the positions
precedent), not broker read ACLs. Which counterparty a scada *acts on*
remains application-level discipline (the proactor link config pins its
LTN).

**Verdicts are cached per (connection, exchange, routing key)** — accepted
deliberately: FIS latency is a boot cost, not a steady-state publish cost;
a connection lifetime costs a handful of FIS calls. The consequence is that
a mid-connection registry change is invisible to cached keys, so:

> **Registry rename ⇒ FIS kills that identity's connections.** The cache is
> per-connection; the kill flushes it, and the reconnect re-runs every check
> against the new alias.

Rename convergence thereby stops being "eventually, at next redeploy" and
becomes "immediately, by forced reconnect" — the provisioning redeploy
remains the recovery path for the killed node's config. The same kill-flush
move serves any future FIS-checked authority that can be withdrawn (e.g. a
trading-rights clawback, per the validation plane below).

Until topic auth lands, consumers that project current state from a specific
authority pin the sender app-side (e.g. a registry projection accepts only
its universe's `<universe>.gnr`) — correct under the honor-system broker
today and redundant-but-harmless afterwards.

## The mechanism plugin (the one custom Erlang artifact)

Scope, sized against the stock module it forks: `rabbit_auth_mechanism_ssl`
is ~100 lines, near-frozen, and does two things this design keeps — refuse
when no usable peer cert, derive the username from it. The fork changes two
things: parse the SASL response bytes as the claims payload instead of
ignoring them, and pass the parsed claims as `AuthProps` instead of `[]`.
Everything downstream (http backend → FIS) is stock. It ships as a plugin
archive mounted into the stock `rabbitmq:4.1-management` image — a plugin,
not a broker fork — rebuilt when the broker line bumps. The rmqbot domain
owns it. Client side: a pika credentials class in gwbase advertising the
mechanism and supplying the payload; MQTT needs nothing (client_id covers
it). Alternatives considered: a custom auth *backend* sees the same
`AuthProps` and unlocks nothing; an upstream patch (reader appends
client_properties to `AuthProps`) is worth filing but not worth waiting on.

## FIS runs on the broker box

FIS is **colocated on the rmqbot broker box**, with its own small Postgres
(principal + lease + registry mirror). **One FIS per broker box, scoped to
that box's fabric(s), reading only its own universe's registry** — the
staging box runs its own FIS holding `hw1__2` lease state, and prod FIS
never learns staging exists; a different universe (`w`) gets its own
registry, broker, and FIS entirely. The decisive argument: the broker
box dying already takes the fabric with it, so colocation adds **no new
single point of failure**, while a separate box would create one — a live
broker that can admit nobody because a different box or the path to it is
down. Colocation makes the auth path localhost, and broker + FIS restart
and recover as one unit: **FIS starts before (or with) the broker in the
box's boot order**, and the rebuild runbook treats them as one. gnr being
down never stops auth — FIS serves from its mirror. The compound event
(broker restart while FIS is down ⇒ fleet denied until FIS returns, houses
in HomeAlone) is **designed behavior**, the architecture keeping its own
promise, not an outage bug. FIS sizing is one indexed lookup per connect on
a deliberately non-burstable box whose headroom exists for exactly the
reconnect storm.

## Gateway boundary — a web login is not enough

Certificates onto the prod broker are GridWorks' **single core security
mechanism, by design.** A web gateway that bridges a browser session onto
the broker (admin — [OPS-429](https://linear.app/gridworks/issue/OPS-429);
customer app-comms —
[OPS-408](https://linear.app/gridworks/issue/OPS-408)) **SHALL NOT**
collapse that to the strength of a web session. A login (password / OIDC
session) alone is never authority to issue a control command:

- the human presents a **phishing-resistant, hardware-bound credential**
  (WebAuthn/FIDO2 passkey) registered to their FIS Principal — not a
  password or bearer token;
- **high-impact commands require a fresh step-up assertion**; a stolen
  session cannot actuate;
- the gateway **forwards** that assertion to FIS and holds **no standing
  authority** to issue commands on a session's behalf — it is a transport
  bridge, not an authority;
- authority **scales with impact** (read < low-impact preference < mode
  change < relay/actuator) — the strongest proof gates the strongest action.

## Relationship to the validation plane (TaDeed / TaTradingRights)

Ownership and metering attestation live in a separate authority plane —
validator-signed records, not certificates; the exploration is
`wiki/terminalasset-registry/explorations/deeds-and-trading-rights.md`. What
binds here: the ordering is **cert before deed** (commissioning needs comms
before a validator visits — a freshly certed, undeeded scada can connect and
telemeter, but no LTN holds rights over it, so nothing can dispatch it); and
FIS's `/auth/topic` gate is the enforcement point that keeps an unentitled
LTN's dispatch publish from ever being routed. Nothing in this design's
rollout gates on the validation plane.

## The on-ramp — notches 2–4 of the TLS ratchet

OPS-423 shipped notch 1 (encryption-only TLS; client certs optional,
verified when presented). This design owns the rest:

2. **Client certs** — mint per-client certs and migrate actors one at a
   time; `verify_peer` checks each cert as it appears, so there is no flag
   day.
3. **Require certs** — `fail_if_no_peer_cert = true`: no valid cert, no
   connection. Passwords still do the login.
4. **Cert + FIS are the identity and the gate** — the GridWorks mechanism
   (AMQP) / `mqtt.ssl_cert_login` (MQTT), with **chained backends**:
   `auth_backends.1 = internal, .2 = http`. The management UI (15671, HTTPS)
   and one break-glass account stay on internal permanently; every fleet
   principal authorizes through FIS; fleet password users are deleted as
   they migrate — a real deletion, not hygiene: on MQTT an explicit
   username+password outranks the cert-derived name, so a live password
   user is a CN bypass. The plaintext listeners 5672/1883 close when the
   last one has. **Notch 3 flips only when the broker log shows every fleet
   client presenting a cert** — a straggler house (e.g. an old-scada
   holdout awaiting its update) delays notch 3 and breaks nothing; there is
   no separate cutover problem to solve.

Chaining is a decision, not a deferral: an "internal loses all accounts"
cutover was the alternative, and it costs the management UI and the
break-glass path for no security gain — FIS gates every fleet principal
either way.

**Notch-2 pilot (beech): COMPLETE, 2026-07-17.** Beech presents a client
cert with CN = `19ee09df-80ba-437b-b6c1-1eebe9d34801` (the scada GNodeId;
CA-2026; expires 2028-06-06 per the summer-stagger leaf policy); plaintext
1883 closed for the house, accepted on 8883, telemetry continuous. Rollout
findings: mint with `gwcert key add --common-name <GNodeId>` on certbot
(stock `getkeys.py` cannot set the CN), transfer with getkeys `--copy-only`;
the laptop rclone `certbot` remote needs `key_use_agent = true`; the
proactor needed only `SCADA_GRIDWORKS_MQTT__TLS__USE_TLS=true`. Per-house
recipe: mint (with consent) → copy → flip → restart → confirm the 8883
accept. **Fleet rollout waits for this design's grill and
Accepted · Pass ≥ 1.**

## Rollout order

1. **Now, FIS-independent:** settle the service-principal CN grammar (open
   below); continue notch-2 cert minting — platform boxes (weather, gnr
   already on amqps; ear, gjk) and houses. Minting is the long pole; it
   never waits on software.
2. **FIS v1** (OPS-422; its build plan is revised to match this design:
   claims from `AuthProps`, run-scoped leases, `/auth/topic` alias pinning,
   sync-kill-before-allow, no client_properties parsing).
3. **Mechanism-plugin spike, in parallel:** claims proven to arrive at a
   stub FIS through a local 4.1 broker — the first experiment.
4. **Staging box: broker + FIS on Hetzner, serving `hw1__2`.** A run is its
   own fabric with its own FIS lease state, and single-writer is per
   (identity, run) — so real identities (a bench pi, beech's) join staging
   experiments without disturbing `hw1__1`, against the same registry. The
   full done-when battery runs here, in real conditions (real TLS, real
   network, real boot order). The box is **ephemeral — dropped when done;
   the recipe is the durable artifact**, and it doubles as the dress
   rehearsal for step 7. Sizing note for that rehearsal: the driver is the
   TLS reconnect storm, so the dedicated-vCPU Hetzner line, not shared.
5. **Prod cutover, chained backends:** migrate AMQP actors one at a time —
   **weather first** (a GNode, already on amqps, lowest blast radius; it
   exercises every transport-plane mechanism and none of the validation
   plane) — then ear, gjk, gnr; then the MQTT fleet (proactor
   `client_id = GNodeInstanceId` + `ssl_cert_login`); then notch 3; then
   close plaintext (notch 4 complete).
6. **Validation plane:** separate exploration → design; gates nothing here.
7. **Broker off AWS, last.** Once the fleet is cert-native the move is
   nearly transparent — same hostname, same CA, same client certs, zero
   per-house config; a DNS repoint (human-executed) plus one reconnect
   storm, following the staging recipe. Deliberately NOT combined with the
   mTLS cutover: mixing a DNS/IP move into the per-actor migration would
   re-import the flag day the ratchet engineered out.

## Cert lifecycle

The rollout proceeds on the **manual 2-year policy** proven at beech:
expiries steered to summer and staggered so the fleet never shares a cliff;
minted on certbot (`gwcert key add --common-name <id>`), by provisioning
alongside the `principal` row for new principals. **Renewal automation is a
follow-on design**, not this one's blocker — it needs FIS and provisioning
built first, and when it lands, lifetimes drop hard (90–180 days):
short-lived certs are also the practical revocation story, since no
realistic CRL/OCSP distribution to the fleet exists.

## Build-time artifacts (no open decisions)

- **The claims word** — `fis.connect.claims` (confirmed 2026-08-14):
  `Alias` (`left.right.dot`), `InstanceId` (`uuid4.str`; the general name —
  services aren't GNodes; FIS maps it onto the GNode lease row's
  `GNodeInstanceId`), `Run` (new `universe.run` format), optional
  `GNodeClass`. Remaining work is authoring it in the sema registry (born
  `draft`, owner jessica-millar) alongside the `universe.run` format.
- **Auth-callback timeout budget** — first-measured 2026-08-14 (spike
  reproducer, `experiments/2026-08-14-sasl-mechanism-spike/`): a 2s
  per-call FIS delay connects; 10s fails — consistent with the broker's
  default 10s `handshake_timeout` bounding the whole auth sequence
  (user + vhost calls combined, sync-kill included). Localhost sync-kill
  is milliseconds, so headroom is ample; pin `handshake_timeout`
  explicitly if supersession ever needs more, and attribute the exact
  failing timer (handshake vs auth_http request) during FIS staging work.

## Domain split

- **rmqbot** — broker conf (require + verify client certs, chained
  `auth_backends`, topic authorization, `validated-user-id`) + the
  GridWorks auth-mechanism plugin.
- **FIS** — the `principal` table, lease state, `/auth/{user,vhost,resource,
  topic}`, sync-kill supersession, rename/clawback connection kills, auth
  events; the authoritative auth spec (FIS `principal-model`).
- **gwbase** — the pika credentials class carrying the claims payload;
  `_client_properties()` retained for audit visibility.
- **scada/proactor** — `client_id = GNodeInstanceId` + `ssl_cert_login`
  migration for the MQTT fleet.
- **provisioning** — mint client cert + `principal` row for both GNode and
  service kinds.

## Done-when

- A SCADA connects to the prod broker with its client cert; FIS returns
  allow; an unknown or `suspended` principal is denied.
- A **revoked instance id** is denied at the gate — a superseded zombie
  cannot rejoin.
- **Supersession is ordered**: the successor's admission completes only
  after the predecessor's connections are closed; with the management API
  unavailable, the successor is denied (fail closed); a **clean restart**
  (nothing to kill) is admitted without delay.
- **Leases are run-scoped**: one identity holds simultaneous `hw1__1` and
  `hw1__2` leases; a run-claim ≠ vhost mismatch is denied at
  `/auth/vhost`.
- A publish whose routing-key from-alias is not the connection identity's
  current alias is **denied at `/auth/topic`**; a registry rename kills the
  connection and the reconnect converges on the new alias.
- A publish carries a `user_id` the broker validates against the connection
  identity.
