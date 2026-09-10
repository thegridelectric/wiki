# mTLS + FIS auth

Status: Accepted · Pass 2 · Updated 2026-09-08 · Linear: OPS-420

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

## TaDeed and the validation plane

Ownership, metering and reality attestation live in a separate authority
plane from transport: validator-signed sema records, not certificates. The
exploration is `wiki/terminalasset-registry/explorations/deeds-and-trading-
rights.md`; this section records what binds the two planes together, settled
2026-09-05.

**Two acts, in order.**

1. **Make the GNode, generate the cert.** A scada's GNode is created in
   status `Pending` (`g.node.status`) with its alias, and its transport cert
   is minted against that alias in the same act. The cert is what admits the
   scada to the broker, and alias pinning means it can only ever speak as
   that alias. This is the state of the whole fleet today.
2. **Validate: issue the TaDeed, the GNode goes `Active`.** A TaValidator
   visits, signs the deed, and activation is the deed landing.

**Pending is the fence.** A `Pending` GNode with a cert connects and
telemeters. Nothing consequential is open to it: no LTN holds rights over it,
FIS's `/auth/topic` gate keeps any dispatch publish toward it from being
routed, and no contract binds. There is no separate holding broker for the
undeeded; the status on the ordinary broker is the holding pen.

**The deed states the validation state of the device.** A deed is not a
yes/no on realness. It carries an attested state that every reader consults
rather than inferring anything from the deed's existence. First pass of the
`ValidationState` enum, one value per thing a validator can vouch for:

- `UnValidated`: no deed. The scada's own default before a validator visits.
- `ValidatedRealAssetAndGps`: physical load drawing electricity where its
  alias and GPS say it is (the Millinocket houses).
- `ValidatedRealAssetIncorrectGps`: physical load drawing real electricity,
  but not at the declared location. Run against Millinocket prices on `hw1`
  from somewhere else (a bench box is the small case).
- `ValidatedSimulatedAsset`: no electricity drawn anywhere.

A simulated asset's deed is a real deed with that state, signed by a
validator, and admits to dev and hybrid universes, never `w`. The universe
guardrail refuses a simulated layout on a `w` broker from the scada side; the
deed refuses it from the validation side.

**Sequencing: the words first, now.** The first-pass TaDeed sema type and the
`ValidationState` enum are authored next, in a sema-claiming session through
the word gate, precisely so the scada reads a real word and not a placeholder.
The scada then gets its first-pass `ValidationState` (the deed's state, or
`UnValidated` with no deed) and the contract gate below. The existing
placeholder `tadeed.json` is replaced by an instance of the word.

**What the scada reads.** Its former `is_simulated` bit (no deed or any sim
component) is replaced by reads of specific facts: which silicon to drive
comes from the layout's board record (scada executor `components.md`
"Hardware backend selection is the layout's job"); whether to listen to a
time coordinator comes from the layout being simulated, a fact about the
plant; whether it may join an LTN contract comes from its `ValidationState`.
**An `UnValidated` scada rejects every LTN contract offer**, on its own side
and tested, whatever FIS routes. The rejection is its own sema word, a
scada-to-LTN message carrying the offered ContractId and the scada's
`ValidationState` as the cause, so the LTN learns why rather than timing out.
It is not a `SlowContractHeartbeat` (a heartbeat presumes a contract the
scada has started) and not a new `SlowDispatchContractStatus` value (that
enum is published). Authored alongside the deed type and the enum. For the simulated fleet the make-imaginary
wand issues Pending GNode, cert and simulated-asset deed in one motion, so
sims are never `UnValidated` for long.

Nothing in this design's rollout gates on the validation plane; the deed
word, the reality-state enum and the registrar home are the exploration's
open items.

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

1. **Now:** the issuance tool and the broker-side revocation list
   ("Minting a platform-service cert" and "Cert lifecycle" below), then
   platform-service certs for weather, gnr, ear, gjk through the tool.
   The CN grammar is settled (a FIS-minted principal id) and FIS mints
   the row (OPS-422). Houses are done (notch 2, below). Revocation is
   witnessed on the local battery rig (its throwaway CA, both
   transports) before the CRL is set up on prod; the staging box has
   done its work and is not rebuilt for this.

   **Do this next:** the prod set-up sequence ("Setting up the CRL on
   the broker" below), the rig leg being done (2026-09-08, 38/38 in
   `experiments/2026-09-05-fis-gate-battery/`). Tool built and dry-run
   against weather; ledger bootstrap commands in
   `scratch/cert-ledger-bootstrap.md` (human runs: step 1). Then the
   rmqbot side on a `jm/` branch: `crl/` mount in `rmq-docker/
   compose.yaml`, `rmq-docker/config/advanced.config` carrying the whole
   TLS block, the `ssl_options.*` lines out of the box's `rabbitmq.conf`
   (step 3 and 4; one recreate, quiet hour, human runs), the check
   (step 6), the drift-check line. Then the four service certs.
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

   **Platform-service certs (block notch 4):** weather, gnr, ear, gjk,
   not yet minted; the recipe is "Minting a platform-service cert" below,
   unblocked now that `fis principal create` mints the row.
6. **Validation plane:** separate exploration → design; gates nothing here.
7. **Broker off AWS, last.** Once the fleet is cert-native the move is
   nearly transparent — same hostname, same CA, same client certs, zero
   per-house config; a DNS repoint (human-executed) plus one reconnect
   storm, following the staging recipe. Deliberately NOT combined with the
   mTLS cutover: mixing a DNS/IP move into the per-actor migration would
   re-import the flag day the ratchet engineered out.

## Minting a platform-service cert

One operator command issues any client cert, for a GNode or a Service,
and one revokes one. The tool is
`gridworks-infra/authority/certbot/mint-client-cert.py`, run from a
laptop under `uv run` (inline dependencies, no project setup), in the
shape of the scada repo's `getkeys.py`: ssh to certbot for the CA
operations, ssh pipes for every transfer (every box is a `~/.ssh/config`
host; the material crosses the laptop in memory only), nothing left on
certbot but the ledger. It replaces the by-hand walkthrough that moved cert material
through a laptop in three copies. Custody rules unchanged: certbot opens
to per-person keys only, so the human runs the tool; Claude preps the
invocation, the inventory line, and the confirmation checks.

`mint <name>` does, in order, stopping at the first failure and safe to
rerun:

1. **Resolve the CN.** A GNode (`--g-node <alias>`): the registry's
   GNodeId, read through the public gnr façade, never typed. A Service
   (`--service`): `fis principal create --kind Service` over ssh on the
   FIS that gates the cert, reusing an existing row with that display
   name so a rerun never forks ids. A GNode's row is created the same
   way with `--g-node-id`, on the same FIS. The FIS is named by
   `--fis <ssh host>`; prod is `fis` (hw1-1), staging its own login.
   The row exists before the cert, so the CN is never a hand-picked
   value a row is later back-filled to match.
2. **Cut the cert on certbot** with `gwcert key add --common-name <CN>`
   and the day count from `--expires <date>` (leaf policy, "Cert
   lifecycle"). The serial is read back from the cert and written to
   the ledger with the CN, the name, and the expiry.
3. **Regenerate the CRL** from the ledger and place it on the broker
   box ("Cert lifecycle"), so a rekey and a mint are the same code path.
4. **Transfer** cert, key (mode 600), and `ca.crt` over ssh to
   `--dest <remote>:<certs dir>`; the certs dir is the service's XDG
   config dir (`~/.config/gridworks/<service_name>/certs`) for a gwbase
   service, the scada or LTN certs dir for a house.
5. **Delete the material from certbot.** Only the ledger and the CA
   stay there; a leaf's private key exists on the box it serves and
   nowhere else, and a lost key is re-issued, never restored.
6. **Print what the human does next**: the three `.env` lines for the
   service's prefix (`<PREFIX>_RABBIT__TLS__CA_CERT_PATH`,
   `…__CERT_PATH`, `…__PRIVATE_KEY_PATH`; the URL scheme `amqps`), the
   restart, the confirm command, and the cert-inventory row.

`revoke <name>` marks the ledger entry revoked with a date and reason,
regenerates the CRL, and places it. The scada repo's `getkeys.py` is
retired once the tool has issued a house cert: a cert cut outside the
tool is one the ledger cannot revoke; its removal (and a README pointer at
the tool) is a scada-claiming session's change. Replacing a house pi is `revoke`
then `mint` for the same GNode: the old cert is refused at the next
handshake, the new one carries the same CN, and FIS sees the principal
it always did. `--dry-run` prints every command without running one.

Confirmation, with the gate off: the broker does not offer the GridWorks
mechanism, so the client presents its cert and falls back to password
auth, and the service's own log cannot tell the two paths apart. The
witness is the broker's connection list, which shows the presented
cert's subject:

    sudo docker exec rmq1 rabbitmqctl list_connections user ssl peer_cert_subject auth_mechanism

Once notch 4 is on, the FIS `auth_events` row for the principal is the
confirmation.

Order across the four platform services: weather first (already on
amqps, a GNode, lowest blast radius), then gnr, ear, gjk. Expiries
steered to summer 2028 and staggered a fortnight apart.

## Cert lifecycle

Leaves follow the **manual 2-year policy** proven at beech: expiries
steered to summer and staggered so the fleet never shares a cliff;
minted on certbot by the tool above, alongside the `principal` row.
**Renewal automation is a follow-on design**, not this one's blocker; it
needs FIS and provisioning built first, and when it ships, lifetimes
drop hard (90–180 days).

**Revocation is a CRL on the broker.** Verification runs in two
directions, and they differ completely in cost. The fleet verifies the
*broker's* cert, so revoking that would mean distributing a list to
every pi, LTN box, and service box and keeping it fresh there; that is
not done, and the broker cert's lifetime is its only rotation. The
broker verifies every *client* cert, and it is the only thing that
does, so a client-cert revocation list has one reader on one box we
already operate. That is what the two-pi case needs: a replaced pi's
predecessor holds a still-valid cert with the same CN, and the gate
cannot tell them apart (instance ids are minted per boot, so the
predecessor rejoins as a fresh instance and the two supersede each
other in turn). No FIS-side check can close this on MQTT, since the
MQTT adapter forwards nothing of the cert but the username
(rmqbot executor "What the broker forwards to an auth backend"). The
CRL closes it on both transports, at the TLS handshake, before FIS is
asked.

Mechanics:

- **The ledger** lives on certbot beside the CA: one entry per issued
  leaf (name, CN, serial, expiry) with an optional revocation (date,
  reason). Public metadata, mirrored into
  `gridworks-infra/authority/cert-inventory.md`.
- **The CRL** is built from the ledger on every mint or revoke, signed
  by the CA, with a one-year `nextUpdate`, and placed on the broker box
  in the broker's certs dir under the hash-dir name Erlang expects
  (`<issuer hash>.r0`). An empty CRL is placed before `crl_check` is
  turned on; with no CRL for the issuer, `peer` refuses every
  handshake.
- **The broker** carries its whole `ssl_options` block, `crl_check =
  peer` and the hash-dir cache included, in `advanced.config`: the cache
  option has no conf-schema key, and a list there replaces the conf
  file's keys outright rather than merging. The cache reads the file
  from disk at every handshake, so a replaced CRL is live at once; no
  restart, no per-rekey config.
- **The CRL's own expiry** is the one operational commitment: past
  `nextUpdate`, `peer` refuses every new connection until a fresh CRL is
  placed. Every mint or revoke re-signs it, and the daily platform-drift
  check carries its expiry with a warning weeks ahead.
- **FIS holds no cert state.** A revoked cert never reaches it; the
  broker log records the refusal, the ledger the reason. A "current
  serial" column at FIS would be a second ledger to keep in step, on one
  transport only, and enforce nothing; it is not built.

### Setting up the CRL on the broker

Once, per broker box, in this order; each step is safe on its own and
the check is last. Witnessed first on the local battery rig with the
same conf fragment and the rig's throwaway CA.

1. **Start the ledger on certbot** from the certs already issued: the
   broker cert, the six house scadas, the six LTNs, beech's pilot
   material. Serials are read from the issued certs where they still sit
   in `~/.local/share/gridworks/ca/certs`; a cert that was deleted from
   certbot after transfer is read from its box
   (`openssl x509 -noout -serial`). Nothing is revoked yet.
2. **Build and place the first CRL.** `mint-client-cert.py crl` builds
   it from the ledger (empty revocation set, one-year `nextUpdate`),
   names it `<issuer hash>.r0` (the hash is OpenSSL's `-subject_hash`
   of the CA name, what Erlang's `short_name_hash` computes), and
   rclones it into `$RMQ1_CERTS/crl/` on the box. The file is placed
   BEFORE the broker is told to check it.
3. **Mount the directory** in `rmq-docker/compose.yaml`:
   `${RMQ1_CERTS}/crl:/etc/rabbitmq/crl:ro`. A directory mount, not a
   file mount, so a replaced file is seen without a container recreate.
4. **Move the whole TLS block** into a new
   `rmq-docker/config/advanced.config` mounted at
   `/etc/rabbitmq/advanced.config`, and delete every `ssl_options.*`
   line from `rabbitmq.conf`. An `ssl_options` list in `advanced.config`
   REPLACES the conf file's keys rather than merging with them
   (witnessed on 4.1.8: a cache-only list left both TLS listeners with
   no cert and the broker crashed at boot), and the cache option has no
   conf-schema key, so the block has one home:

       [{rabbit, [{ssl_options, [
           {cacertfile, "/etc/rabbitmq/rmq-cacert.crt"},
           {certfile,   "/etc/rabbitmq/rmq-cert.crt"},
           {keyfile,    "/etc/rabbitmq/rmq-key.pem"},
           {verify, verify_peer},
           {fail_if_no_peer_cert, false},
           {crl_check, peer},
           {crl_cache, {ssl_crl_hash_dir, {internal, [{dir, "/etc/rabbitmq/crl"}]}}}
       ]}]}].

   Paths and values as the box's `rabbitmq.conf` has them today;
   `fail_if_no_peer_cert` flips to `true` in this list at notch 3.
5. **Recreate the container** (steps 3 and 4 are one recreate, at a
   quiet hour: every client reconnects). The listeners now check the
   CRL.
6. **Check.** Every fleet client is back (the connection list, the
   journal); then a throwaway cert cut for the purpose is revoked, the
   CRL replaced, and its connect refused at the handshake on 5671 and
   8883 with the broker log naming the CRL, while an unrevoked client
   still connects. Then the drift-check line for the CRL's `nextUpdate`.

The MQTT listener shares `ssl_options` with AMQP on this broker
(`mqtt.listeners.ssl` takes the global block), so one setting covers
both; the rig run confirmed it (a revoked cert refused on 8883 as on
5671), since it is the assumption the two-pi case rests on.

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
  service kinds. Until a provisioning service exists, the operator tool
  in `gridworks-infra/authority/certbot/` is that capability, and the
  ledger and CRL live with the CA on certbot.

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
- **Revocation holds on both transports.** Two certs with the same CN
  supersede each other in turn on the current conf (the flaw, witnessed
  first); once the older serial is listed and the CRL placed, that cert
  is refused at the handshake on AMQP and on MQTT with no broker restart,
  and the newer one is admitted. An expired CRL refuses every new
  connection, witnessed so the drift check's line is known to matter.
  **Witnessed on the rig 2026-09-08** (throwaway CA, both transports,
  FIS never asked for a revoked cert, `StartedAt` unchanged:
  `experiments/2026-09-05-fis-gate-battery/`, run `20260908T1619`).
  Prod remains: the set-up sequence above.
