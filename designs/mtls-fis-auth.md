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

## Protocol ground truth

**Distilled to [`../rmqbot/executor/auth-path.md`](../rmqbot/executor/auth-path.md)
"What the broker forwards to an auth backend"** — the source-verified facts
about what an auth backend can and cannot see, and why the SASL response is
the only client-controlled channel on AMQP.

Still open here as a migration item: the FIS executor's `/validate` input
description and `gridworks-fleet-index-service/research/lifecycle.md` step 4
still describe the superseded plan (FIS reading claims out of AMQP
`client_properties`), which is unimplementable on stock parts and was never
available on MQTT. Both need reconciling in the FIS domain.

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

**BUILT (OPS-496, closed).** Source, build, and mount recipe:
`gridworks-infra/rmqbot/auth-mechanism/`. Spec distilled to
[`../rmqbot/executor/auth-path.md`](../rmqbot/executor/auth-path.md)
"The GridWorks mechanism plugin"; the client half (gwbase credentials class
and connect claims) to
[`../gridworks-base/executor/actors.md`](../gridworks-base/executor/actors.md)
"Connect-time identity". Not yet enabled on any broker — that is notch 4
below.

## FIS runs on the broker box

**Distilled to [`../rmqbot/executor/auth-path.md`](../rmqbot/executor/auth-path.md)
"The authority is colocated on this box"** — the colocation argument, the
one-authority-per-broker-box scoping, and the designed compound-failure
behavior.

Sizing note retained for the staging build: one indexed lookup per connect,
on a deliberately non-burstable box whose headroom exists for exactly the
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

**Notch-2, all six house scadas: COMPLETE, 2026-08-14** (pilot was beech,
2026-07-17). Each presents a client cert with CN = its own scada GNodeId
(CA-2026; expiries staggered across summer 2028 per the leaf policy);
plaintext 1883 no longer dialed by any house, each confirmed live via a
direct `gridworks.messages` query. Rollout findings: mint with
`gwcert key add --certs-dir <certbot-key-name-dir> --common-name <GNodeId>
gridworks_mqtt` on certbot (stock `getkeys.py` cannot set the CN, and always
names the cert `gridworks_mqtt` inside a per-house dir, never after the
house itself); transfer with getkeys `--copy-only`; the rclone remotes for
each house need key-based auth (`key_file` + `key_use_agent`), not the
fleet's old shared password (which several houses still silently accepted
until closed alongside this rollout). Per-house recipe: mint (with consent)
→ copy → flip → restart → confirm on the pi + a `gridworks.messages` check.

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

   **Notch-2, all six house LTNs: COMPLETE, 2026-08-16.** The six house
   LTNs are MQTT clients (pre-dating the AMQP-native gwbase path this
   design's "gwbase" domain split describes), each its own GNode with its
   own GNodeId distinct from its scada's (`LTN_SCADA_MQTT__TLS__USE_TLS`,
   mirroring the scada's flag). Each now presents a client cert with CN =
   its own LTN GNodeId (CA-2026; expiries staggered across summer 2028).
   Differences from the scada recipe, all resolved: the LTN's `mqtt_name`
   is `scada_mqtt` (not `gridworks_mqtt`), so certs land as `scada_mqtt.*`;
   the LTNs run not on per-house pis but in per-house tmux sessions on two
   shared EC2 boxes (`ltn`, `ltn2`), so cert transfer uses one rclone
   remote per *box* (dest path carries the house). The **restart answer**
   (the open item): no systemd, so restart is in-place — attach the live
   tmux session, stop the REPL (Ctrl-C), and re-boot it by hand with the
   snippet in `gridworks-infra/ltn/README.md`; the per-house `<house>.sh`
   launchers are from-scratch session *creators*, not restarters. **Live
   confirmation is not the scada's `gridworks.messages` query** — an LTN
   alias journals only an hourly `glitch`, so the journal can't date a
   just-restarted node; the per-minute signal is the LTN's `gridworks.ping`
   to `ear`, read from the S3 eventstore (its `ls` LastModified is EDT, so
   sort by the epoch-ms in the object key).

   **Open — platform-service certs (blocks notch 4).** weather, gnr, ear,
   gjk still need certs minted; not yet started. This design's own rule
   for a service principal is `CN=<principal UUID>, minted with the
   principal row` — no principal table exists yet (FIS v1 is still being
   stood up), so minting real certs for these four likely waits on either
   FIS v1 or a human decision to mint an interim UUID now.
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
  `GNodeClass`. Authored 2026-08-14: `fis.connect.claims` is `staging`
  (snapshot-vendorable for FIS v1, mutable in place while it hardens);
  `universe.run` is `published` (formats never stage; the pattern mirrors
  settled vhost canon).
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

The claims channel is built but witnessed only against a **stub** authority
in local Docker (OPS-496, closed as build-out). Everything below still needs
a real stack; the first four carry over from that issue.

- **A real FIS decodes the claims.** The payload rides as an HTTP param from
  `rabbitmq_auth_backend_http` and has only ever been logged as a string,
  never decoded through a vendored snapshot codec at the far side. Mangling
  or truncation here stays invisible until a real decode runs — witness it
  first on staging.
- **The plugin runs on a real broker box.** The mount/enable recipe has only
  run under local `docker compose`; rebuild the `.ez` against the box's own
  image pin.
- **The auth-callback budget holds under real conditions.** Measured
  locally: 2s per-call delay connects, 10s fails (default 10s
  `handshake_timeout` bounds the whole sequence). Re-measure against a real
  FIS doing a real sync-kill, and attribute the failing timer precisely
  (handshake vs auth_http request).
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
  `/auth/vhost`. That deny needs a hand-built client, since gwbase derives
  `Run` from the vhost and an honest actor therefore matches by
  construction (the spike's `client_test.py` is kept for exactly this).
- A publish whose routing-key from-alias is not the connection identity's
  current alias is **denied at `/auth/topic`**; a registry rename kills the
  connection and the reconnect converges on the new alias.
- A publish carries a `user_id` the broker validates against the connection
  identity.
