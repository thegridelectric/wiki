# mTLS + FIS auth

Status: Accepted · Pass 2 · Updated 2026-10-07 · Linear: OPS-420

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

## Canonized

The architecture is in the executor spokes; this design keeps only the
rollout. Where to read each piece:

- **What the broker forwards to an auth backend**, and why the SASL
  response is the only client-controlled channel on AMQP: rmqbot executor
  `auth-path.md` "What the broker forwards to an auth backend".
- **Identity and claims.** The cert CN is the principal key (GNodeId for a
  GNode, principal UUID for a service); the alias is a runtime claim, never
  in the cert; the `fis.connect.claims` word and how it arrives: FIS
  executor `primary.md` "Invariants (normative)" and "How the claims
  arrive". The mechanism plugin: `auth-path.md` "The GridWorks mechanism
  plugin" (built, OPS-496; source `gridworks-infra/rmqbot/auth-mechanism/`).
  The client half: gwbase executor `actors.md` "Connect-time identity".
- **MQTT's one slot**, the dead password field, and why broker-native
  session takeover was rejected: `auth-path.md` "MQTT is asymmetric,
  deliberately".
- **The gate and single-writer.** Allow iff the principal is active and the
  instance id matches or supersedes the (identity, run) lease; synchronous
  kill-before-allow; an empty kill is success; fail closed; a lease ends
  only by supersession; revoked rows are permanent; no verdict caching on
  connect: FIS `auth-endpoints.md` "/auth/user" and "/auth/vhost",
  `primary.md` "Purpose". The kill is
  `DELETE /api/connections/username/<principal-id>`.
- **Alias pinning** at `/auth/topic`, the open read side and its named
  cost, the Service exception, the per-connection verdict cache and the
  rename kill: `auth-endpoints.md` "/auth/topic", `primary.md` "Registry
  changes force reconvergence". Until topic auth is live, a consumer that
  projects state from one authority pins the sender app-side.
- **FIS on the broker box**, loopback-only, one authority per box:
  `auth-path.md` "The authority is colocated on this box", FIS `primary.md`
  "Deployment".
- **Gateways and human principals**: FIS `primary.md` invariant 5; the
  impact ladder is `command-surface.md` rule 8.
- **The TaDeed and the validation plane** are OPS-574. Nothing in this
  rollout gates on them; a `Pending` GNode with a cert connects and
  telemeters, and the fence is the scada's own contract rejection.

## Rollout

Sections in time order; earlier sections finish before later ones start.
Done items are marked ✅, the item in progress ◐.

### Revocation and platform certs (now)

- **tool** ✅ `mint-client-cert.py` on gridworks-infra `main`
  (`0298e35`): "Minting a platform-service cert" below.
- **rig-witness** ✅ revocation refused on both transports with the rig's
  throwaway CA, 2026-09-08, 38/38
  (`experiments/2026-09-05-fis-gate-battery/`).
- **ledger** ✅ the broker cert, five house scadas and six LTNs recorded
  off their boxes, every one issued by the 2026 CA. Elm's scada is the one
  entry still missing (its pi was unreachable; `record elm --kind GNode
  --host elm --path /home/pi/.config/gridworks/scada/certs/gridworks_mqtt/
  gridworks_mqtt.crt`).
- **crl** ✅ the empty CRL `ec0ba799.r0` on rmqbot, `nextUpdate`
  2027-10-07.
- **broker-crl** ✅ the broker checks the CRL at every handshake on 5671
  and 8883 since the 2026-10-07 recreate (`advanced.config` carries the
  whole TLS block, `crl/` mounted; merged `97cd649`). The recipes are in
  gridworks-infra: `rmqbot/rmq-docker/README.md` "Client-cert revocation
  (the CRL)" and `rmqbot/instance-README.md` "Change compose or config (a
  recreate)".
- **prod-check** ✅ 2026-10-07: a throwaway cert
  (`throwaway-crl-check-2026-10-07`, recorded then revoked in the ledger)
  connected on 5671 and 8883 with password auth, and after the revoke was
  refused at the handshake on both ports (`SSLV3_ALERT_CERTIFICATE_REVOKED`;
  broker log `Fatal - Certificate Revoked`) with no broker restart, while
  all 18 fleet connections stayed up. The CRL now carries one revoked
  serial, `nextUpdate` 2027-10-07.
- **no-password-fallback** (decided 2026-10-07) A gwbase actor with a
  `rabbit.tls` block offers only the GRIDWORKS SASL mechanism at login;
  with the gate off the prod broker lists only PLAIN and AMQPLAIN, so the
  actor answers "no mechanism" and never connects (witnessed on weather:
  `connection open failed: GRIDWORKS`, reverted within a minute). The
  house scadas are unaffected: MQTT has no mechanism list, so cert at the
  TLS layer and password at login. No fallback is built. Service certs
  are minted and placed now and the `rabbit.tls` block is set at notch 4,
  when the broker offers GRIDWORKS; the gwbase executor notes the absence.
- **service-certs** ✅ 2026-10-07, minted and placed, not enabled:
  weather (GNode), gnr, ear, gjk (Services, CN = the FIS principal id),
  serials and paths in `gridworks-infra/authority/cert-inventory.md`.
  Each box holds its cert, key and `ca.crt` with no `*_RABBIT__TLS__*`
  lines until notch 4, when the three lines and a restart put each
  service on cert-plus-claims (ear's URL also moves to `amqps`).
- **alerter-cert** ✅ 2026-10-07, minted and placed under the alerts
  box's `alerts` login; the broker-alerter (OPS-545) runs as the
  `alerter` login with prefix `GWALERTER` and alias `hw1.alerts`, which
  does not exist yet, so root moves the three files there at that build.
- **notch-4 prep, do this next:** FIS v1 on the broker box (OPS-422),
  then the mechanism plugin enabled with chained backends; the five
  placed certs go live one service at a time with their `*_RABBIT__TLS__*`
  lines (ear's URL to `amqps`) and a restart each. The
  gridworks-alerter joins the list when it becomes a broker client
  (OPS-545); today it reads the journal DB and holds no connection.
- **elm-ledger** record elm's scada cert when its pi is reachable.

### FIS v1 (OPS-422)

Its build plan matches the executor: claims from `AuthProps`, run-scoped
leases, `/auth/topic` alias pinning, sync-kill-before-allow, no
client_properties parsing.

### Staging box: broker + FIS on Hetzner, serving `hw1__2`

A run is its own fabric with its own FIS lease state, and single-writer is
per (identity, run), so real identities (a bench pi, beech's) join staging
experiments without disturbing `hw1__1`, against the same registry. The
full done-when battery runs here in real conditions (real TLS, real
network, real boot order). The box is ephemeral, dropped when done; the
recipe is the durable artifact, and it doubles as the dress rehearsal for
the broker move. Sizing: the driver is the TLS reconnect storm, so the
dedicated-vCPU Hetzner line, not shared.

- **real-decode** a real FIS decodes the claims through its vendored
  snapshot codec (only ever logged as a string so far).
- **plugin-on-box** the `.ez` rebuilt against the box's own image pin
  and mounted by the recipe.
- **callback-budget** re-measured against a real FIS doing a real
  sync-kill; attribute the failing timer (handshake vs auth_http request).
- **alias-self-heal** the client contract gwbase/proactor owe: a killed
  node reconnects, looks its current alias up in gnr by its GNodeId and
  reconnects with it, no provisioning redeploy (FIS `primary.md` "Registry
  changes force reconvergence"). Not built.

### Prod cutover: the TLS ratchet, notches 2 to 4

OPS-423 shipped notch 1 (encryption-only TLS; client certs optional,
verified when presented). This design owns the rest.

- **notch-2 houses** ✅ all six house scadas, 2026-08-14 (pilot beech,
  2026-07-17): each presents a client cert with CN = its scada GNodeId
  (CA-2026, expiries staggered across summer 2028); plaintext 1883 no
  longer dialed by any house. Findings: mint with `gwcert key add
  --certs-dir <certbot-key-name-dir> --common-name <GNodeId> gridworks_mqtt`
  on certbot (stock `getkeys.py` cannot set the CN and always names the
  cert `gridworks_mqtt` inside a per-house dir); transfer with getkeys
  `--copy-only`; the per-house rclone remotes need key-based auth
  (`key_file` + `key_use_agent`), not the old shared password.
- **notch-2 ltns** ✅ all six house LTNs, 2026-08-16: MQTT clients, each
  its own GNode with its own GNodeId distinct from its scada's
  (`LTN_SCADA_MQTT__TLS__USE_TLS`); CN = the LTN GNodeId. The LTN's
  `mqtt_name` is `scada_mqtt`, so certs land as `scada_mqtt.*`; the LTNs
  run in per-house tmux sessions on two shared EC2 boxes (`ltn`, `ltn2`),
  one rclone remote per box, restart in place by the snippet in
  `gridworks-infra/ltn/README.md`. Live confirmation is the LTN's
  per-minute `gridworks.ping` to `ear` in the S3 eventstore (sort by the
  epoch-ms in the key), not the journal.
- **notch-2 services** the four platform services, through the tool
  ("Revocation and platform certs" above). Migrate one at a time:
  weather, then ear, gjk, gnr.
- **notch-3 require-certs** `fail_if_no_peer_cert = true` in
  `advanced.config`: no valid cert, no connection; passwords still do the
  login. Flips only when the broker log shows every fleet client
  presenting a cert; a straggler delays it and breaks nothing.
- **notch-4 cert+fis** the GridWorks mechanism (AMQP) and
  `mqtt.ssl_cert_login` (MQTT) with chained backends, `auth_backends.1 =
  internal, .2 = http`. The management UI (15671) and one break-glass
  account stay on internal permanently; every fleet principal authorizes
  through FIS; fleet password users are deleted as they migrate, a real
  deletion: on MQTT an explicit username+password outranks the
  cert-derived name, so a live password user is a CN bypass. Chaining is a
  decision, not a deferral: dropping internal would cost the management UI
  and the break-glass path for no security gain. The MQTT fleet moves to
  `client_id = GNodeInstanceId` + `ssl_cert_login` (proactor).
- **close-plaintext** 5672 and 1883 close when the last password user is
  gone.

### Broker off AWS (last)

Once the fleet is cert-native the move is nearly transparent: same
hostname, same CA, same client certs, zero per-house config; a DNS repoint
(human-executed) plus one reconnect storm, following the staging recipe.
Deliberately not combined with the mTLS cutover: mixing a DNS/IP move into
the per-actor migration would re-import the flag day the ratchet
engineered out.

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

`mint <name>` does the following, in order, stopping at the first
failure and safe to rerun:

- **resolve-cn** A GNode (`--g-node <alias>`): the registry's
   GNodeId, read through the public gnr façade, never typed. A Service
   (`--service`): `fis principal create --kind Service` over ssh on the
   FIS that gates the cert, reusing an existing row with that display
   name so a rerun never forks ids. A GNode's row is created the same
   way with `--g-node-id`, on the same FIS. The FIS is named by
   `--fis <ssh host>`; prod is `fis` (hw1-1), staging its own login.
   The row exists before the cert, so the CN is never a hand-picked
   value a row is later back-filled to match.
- **cut** the cert on certbot with `gwcert key add --common-name <CN>`
   and the day count from `--expires <date>` (leaf policy, "Cert
   lifecycle"). The serial is read back from the cert and written to
   the ledger with the CN, the name, and the expiry.
- **crl** regenerate the CRL from the ledger and place it on the broker
   box ("Cert lifecycle"), so a rekey and a mint are the same code path.
- **transfer** cert, key (mode 600), and `ca.crt` over ssh to
   `--dest <remote>:<certs dir>`; the certs dir is the service's XDG
   config dir (`~/.config/gridworks/<service_name>/certs`) for a gwbase
   service, the scada or LTN certs dir for a house.
- **delete** the material from certbot. Only the ledger and the CA
   stay there; a leaf's private key exists on the box it serves and
   nowhere else, and a lost key is re-issued, never restored.
- **print** what the human does next: the three `.env` lines for the
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

**The broker side is live** since 2026-10-07: the CRL is mounted and
checked at every handshake; the set-up and the post-recreate check are
recorded in gridworks-infra (`rmqbot/rmq-docker/README.md` "Client-cert
revocation (the CRL)"; the recreate recipe in `rmqbot/instance-README.md`).
The MQTT listener shares `ssl_options` with AMQP on this broker
(`mqtt.listeners.ssl` takes the global block), so one setting covers both;
the rig run confirmed it, since it is the assumption the two-pi case rests
on.

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
  **Witnessed on prod 2026-10-07** (the prod-check bullet in
  "Revocation and platform certs").
