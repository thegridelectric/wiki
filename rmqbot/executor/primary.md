# rmqbot — deployment spec (primary)

Status: Draft · Pass 0 · Updated 2026-10-09

> What this is: the faithful spec of GridWorks' **running production
> RabbitMQ/MQTT broker** — what it is, where it runs, how it's secured today.
> This is the *current state*; in-flight changes are tracked as designs
> (`../designs/`) and prioritized in Linear, not here.

## What rmqbot is (and is not)

`rmqbot` owns the **running broker**: hosting, `docker compose`, TLS/certs, and
the ops runbook. It is distinct from:

- [`../../gridworks-base/`](../../gridworks-base/) — *generates* the
  exchange/binding **topology** (the broker definitions).
- [`../../ear/`](../../ear/) — the audit-tap mechanism.
- [`../../gridworks-fleet-index-service/`](../../gridworks-fleet-index-service/)
  — the **auth authority** the broker calls over HTTP (the FIS direction).

Migrated from `gridworks-infra/{rmqbot,authority/tls,authority/certbot}`.

Sub-specs:

| file | holds |
| --- | --- |
| [`auth-path.md`](auth-path.md) | what the broker can carry into an auth decision, the GridWorks SASL mechanism plugin, and the broker-side gate configuration |

## Current deployment

- Single production broker on AWS at **`hw1-1.electricity.works`**, vhost
  **`hw1__1`**; management UI `https://hw1-1.electricity.works:15671/`.
- Runs via `docker compose` out of `~/rmq-docker` on the host; compose,
  conf, and tests deploy as a file copy from
  `gridworks-infra/rmqbot/rmq-docker/`; the definitions file loads from a
  gwbase checkout (see Topology below).
- **RabbitMQ 4.1.8** (`rabbitmq:4.1-management` line, patch-pinned),
  booted from the gwbase-generated definitions.
- **Host:** `m8g.medium`, stock Ubuntu 26.04 LTS arm64, the `RabbitMQ`
  security group. Not burstable by design: the broker's CPU spike is the
  post-outage reconnect storm, when every client re-handshakes TLS at
  once — exactly when a burstable box would be out of credits. **Rebuild
  story is stock image + git + 1Password** — no custom AMI; recipe in the
  rmq-docker README. ssh is a dedicated key pair (private key in
  1Password) plus per-person keys; the fleet key does not open this box.
- **Moving the broker off AWS** is a DNS repoint (human-executed) plus
  one reconnect storm: same hostname, same CA, same client certs, zero
  per-house config, following the staging-box recipe
  (`experiments/2026-09-06-fis-staging-box/`). It is not combined with
  an auth cutover: mixing a DNS/IP move into a per-client migration
  re-imports the flag day the ratchet engineered out.
- **TLS serves on all three listeners** — AMQPS 5671, MQTT-TLS 8883,
  management 15671 — from a single 2-year keypair (CN + DNS SAN
  `hw1-1.electricity.works`, expires 2028-07). Plaintext 5672/1883 remain
  open deliberately (see the ratchet below).
- **All users are runtime-created** from the box's `.env` (mode 600,
  never committed) after boot — 4.x seeds no default vhost or user from
  the conf, and definitions import creates none either; recipes in the
  rmq-docker README. No password lives in the conf or in git.
- **4.x conf idioms:** definitions load via
  `definitions.import_backend = local_filesystem` +
  `definitions.local.path`; MQTT session expiry via
  `mqtt.max_session_expiry_interval_seconds = 86400`;
  `mqtt.allow_anonymous = false` is the require-auth switch. The image
  ships rabbitmqadmin v2 (changed flag syntax; README recipes match).
- **No data volume**: a container recreate wipes runtime state. Topology
  reloads from the box-side definitions file; every user (default
  included, plus `analytics.ear.reader`) must be re-created — recipes in
  the rmq-docker README.
- **QoS-0 MQTT subscriptions** live in the `rabbit_mqtt_qos0_queue`
  pseudo-queue inside the connection process — the management UI shows
  `?` for their depth columns and no per-queue graphs; per-connection
  rates and drop counters remain. QoS-1 would restore real queues and
  stats at the cost of ack/session overhead.

## Topology — generated, never hand-edited

The topology (vhost, exchanges, queues, bindings) is canonical **as code
in gridworks-base**: `for_docker/gen_definitions.py` generates the
definitions JSON (`hybrid_definitions.json` is the `hw1__1` artifact),
guarded by a drift test, a pre-commit hook, and the broker-image
workflow. **No definitions copy exists in git outside gwbase**: the
provisioning recipe loads the artifact from a gwbase checkout onto the
box at the path compose mounts
(`rmqbot/rmq-docker/config/rabbit_definitions.json`), and deliberately no
`.gitignore` entry exists for it — an ignored file could sit stale and
invisible in a checkout, while untracked noise prompts deletion.

The **live drift check**
(`gridworks-infra/rmqbot/rmq-docker/tests/check_topology_drift.py`)
compares the running broker's vhost/exchanges/bindings against the
canonical artifact over the management API — catching runtime-declared
strays no file diff could see — and, run from a laptop, also catches a
stale box copy (it reads the sibling gwbase checkout). IN SYNC is its
bar.

The binding table remains the authoritative who-may-route-to-whom
([`../../gridworks-base/executor/transport.md`](../../gridworks-base/executor/transport.md)).
Analytics topology belongs to the analytics broker (OPS-426): there is no
`hw1_analytics` vhost on prod; `analytics.ear.reader` reads `ear_tx` on
`hw1__1`.

## PKI

- **Root:** `Gridworks-Self-Signed-CA-2026`, 10-year (to 2036-07), minted
  with plain openssl (gwcert's ownca dependency caps validity at 825 days —
  the flaw that killed the 2023 CA in 27 months). Lives on the `certbot` EC2
  box; **custody invariant: the CA private key exists on certbot and in
  1Password, nowhere else.** The public `ca.crt` is committed at
  `gridworks-infra/authority/ca.crt`; clients get it from git.
- **Leaf policy:** ~2 years; expiries steered to summer and staggered —
  leaves and root never share a cliff, and no cert expires in heating
  season. Leaf lifetime is the rotation knob, not the root's. Renewal
  automation is a follow-on that needs FIS and provisioning built first;
  when it ships, lifetimes drop to 90–180 days.
- **Client-cert CNs carry the immutable identity** (GNodeId for GNodes; a
  uuid4 principal id for a platform service). Leaves are issued only by
  the tool on certbot, which mints the FIS principal row, cuts the cert
  and writes the ledger (gridworks-infra `authority/certbot/README.md`
  "The issuance tool"); a cert cut outside the tool is one the ledger
  cannot revoke.
- **Revocation is a CRL on the broker.** The fleet verifies the broker's
  cert, so revoking that would mean distributing a list to every pi, LTN
  box and service box; it is not done, and the broker cert's lifetime is
  its only rotation. The broker verifies every client cert and is the
  only thing that does, so the client-cert revocation list has one
  reader on one box. The ledger on certbot (one entry per leaf: name, CN,
  serial, expiry, optional revocation) is the source; every mint or
  revoke re-signs the CRL (one-year `nextUpdate`) and places it in the
  broker's certs dir; `crl_check = peer` in `advanced.config` reads it
  at every handshake, so a replaced CRL is live with no restart, on AMQP
  and MQTT alike. This is what closes the two-pi case: a replaced pi's
  predecessor holds a still-valid cert with the same CN, instance ids
  are minted per boot, and the MQTT adapter forwards nothing of the
  cert but the username, so no FIS-side check can tell the two apart;
  the CRL refuses the old serial before FIS is asked. FIS holds no cert
  state. The CRL's own expiry is the one operational commitment: past
  `nextUpdate` the broker refuses every new connection until a fresh
  CRL is placed, so the daily platform-drift check carries it. Setup
  and the post-recreate check: gridworks-infra `rmqbot/rmq-docker/
  README.md` "Client-cert revocation (the CRL)".
- certbot ssh is **per-person keys only**; the fleet key deliberately does
  not open the CA box.
- Registers: certificates in `gridworks-infra/authority/cert-inventory.md`;
  what-runs-where in `gridworks-infra/production-inventory.md`.

## The TLS ratchet (current position: notch 4 for platform services, notch 2 for houses and LTNs)

The path from plaintext-with-passwords to cert-only authentication has four
independently flippable notches:

1. **Encrypt (done, verified 2026-07-17).** `ssl_options.verify =
   verify_peer` + `fail_if_no_peer_cert = false`: client certs optional —
   verified when presented, rejected when invalid, ignored when absent.
   Clients reach encryption with `ca.crt` + a port change; passwords
   unchanged.
2. **Client certs (done for the fleet, 2026-08).** Every house scada
   and every house LTN presents a client cert with CN = its own GNodeId
   (the LTN's GNodeId is distinct from its scada's), verified at the
   handshake; no house dials plaintext 1883. Houses mint with
   `--common-name <GNodeId>` on certbot; the per-house rclone remotes
   use key-based auth. The LTNs run in per-house tmux sessions on two
   shared EC2 boxes with one rclone remote per box; their live
   confirmation is the per-minute `gridworks.ping` in the S3 eventstore,
   not the journal.
3. **Require certs** — `fail_if_no_peer_cert = true` in
   `advanced.config`. Flips once the broker log shows every fleet client
   presenting a cert; a straggler delays it and breaks nothing.
4. **Cert + FIS are the identity and the gate (live for the platform
   services since 2026-10).** The GridWorks SASL mechanism plugin (AMQP;
   built from `gridworks-infra/rmqbot/auth-mechanism/` into the mounted
   `.ez` — [`auth-path.md`](auth-path.md)) and `mqtt.ssl_cert_login =
   true`: CN becomes the username, with **chained backends**
   (`auth_backends.1 = internal` for the management UI and the default
   break-glass login; `.2 = http` → FIS, colocated on this box). Chaining
   is a decision, not a deferral: dropping `internal` would cost the
   management UI and the break-glass path for no security gain. On MQTT
   an explicit username+password outranks the cert-derived name, so any
   client still sending a password is a CN bypass; the MQTT fleet
   authorizes on `client_id = GNodeInstanceId` + `ssl_cert_login`
   (proactor). The management UI keeps password login over HTTPS in
   every era. The FIS contract: the FIS executor spec.

The houses and LTNs still send the default user's password inside TLS,
so they authorize on `internal` today; moving them to their cert-derived
names, notch 3, and closing 5672 and 1883 are OPS-578. Notches 3 and 4
are written separately so that handshake failures stay distinguishable
from auth failures on cutover day.

## Security posture today

- **Platform services authorize on cert plus claims through FIS**; a
  revoked cert is refused at the handshake by the CRL. **Houses and LTNs
  present their certs but still log in as the default user** (password
  inside TLS), so they authorize on `internal`; the broker holds exactly
  two password users, the default login and `analytics.ear.reader`
  (gridworks-infra `rmqbot/rmq-docker/README.md` "Runtime-created
  users"). Closing that path is OPS-578.
- **Audit-tap consumers get a dedicated read-only user.** `analytics.ear.reader`
  (no tags; password in 1Password) is scoped so a leaked cred cannot touch the
  control plane: configure/write `^analytics\..*$`, read `^(analytics\..*|ear_tx)$`
  — it can declare its own `analytics.*` queues and bind them to `ear_tx`, and
  can publish nowhere (no exchange matches its write pattern; the write regex
  is bind-plumbing, not publish rights). Consumers use non-durable auto-delete
  queues per the deferred-shovel arrangement
  (`../designs/analytics-broker-shovel.md`). The user lives in the broker's
  data store, not `rabbit_definitions.json` — re-create after any container
  recreate (recipe in the rmq-docker README).
- Admin control is via **Tailscale-protected textual interfaces** — adequate to
  ~30 homes; it hits Tailscale's ~100-device limit at the 100-home scale, which
  is the forcing function for the later security phases.
- Local MQTT brokers (Mosquitto on the Pis) are **LAN-only**, no auth, not
  internet-exposed.
- **Emergency response today:** revoke a client cert on certbot (`revoke`,
  the CRL is live at the next handshake) or suspend its FIS principal;
  rotate the default user's password; revoke Tailscale device access;
  restart SCADA in local-only (HomeAlone) mode; physical site access.

## Verification

The broker contract is checked by a re-runnable harness:
`gridworks-infra/rmqbot/rmq-docker/tests/check-broker-contract.py` (run
instructions in the rmq-docker README). Six checks: TLS-without-client-cert
on 5671, garbage-cert rejection, plaintext auth, and the analytics
permission contract in both directions. Run it after any conf change; 6/6
is the bar. The topology drift check (see Topology above) is the second
harness.

The SASL mechanism plugin has its own witness, since nothing on the running
broker exercises it yet: `experiments/2026-08-14-sasl-mechanism-spike/` mounts
the built `.ez` into a pinned broker image and drives a real client cert plus
a claims payload into a stub authority. It passes when the authority's
`/auth/user` call carries the cert's CN as `username` and the claims
byte-for-byte. Because it mounts the shipped artifact rather than a copy of
the source, a plugin change that fails to build or load fails the harness.

Fleet-ops note for broker moves: a proactor client publishes
`gridworks-event-*` only while its upstream link is peer-ACTIVE
(`gwproactor/links/link_manager.py:329`) — otherwise events persist
on disk and upload at link activation. An event-silent house during a
move is the persister working, not a broker fault; moving a house's
SCADA and LTN together avoids the state entirely.

## Ops runbook

ssh / start / stop / recreate-warning / user-recipes / harness instructions
live in `gridworks-infra/rmqbot/rmq-docker/README.md`; certbot and cert
recipes in `gridworks-infra/authority/` (outside the wiki write boundary).

## In-flight changes

Tracked as designs in [`../designs/`](../designs/) and explorations in
[`../explorations/`](../explorations/); execution **order/priority lives in
Linear**, not here.
