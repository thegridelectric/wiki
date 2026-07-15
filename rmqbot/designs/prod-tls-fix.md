# prod-tls-fix

Status: Accepted · Pass 1 · Updated 2026-07-15 · Linear: OPS-423

**EDD: yes** the broker-contract harness run against the live prod broker *is*
the verification; the design reaches Verified when the four-check experiment
below passes on restart day.

> Revive the expired PKI and turn on encryption-only TLS for the prod broker
> `hw1__1`: fresh CA, fresh broker cert, conf flip to optional client certs,
> default-password rotation. Every client can leave plaintext; passwords stay
> the authentication; mutual TLS is the later track this sets up (OPS-420).

## Why

- Plaintext credentials travel between the houses and the broker over the
  public internet today.
- The PKI is expired end to end: the 2023 CA certificate expired 2025-11-23,
  the broker certs 2025-11-24. Nothing it signed verifies.
- The current conf demands a client certificate (`verify_peer` +
  `fail_if_no_peer_cert = true`) that no client has ever held, so the TLS
  ports (5671, 8883, 15671) were unusable even before the expiry. The whole
  fleet runs plaintext on 5672/1883.
- Encryption-only TLS is the ground floor of the mTLS + FIS auth model
  (OPS-420).

This work runs on the current 3.9.13 broker, decoupled from the RabbitMQ 4.x
upgrade (OPS-424): the exposure is live now, the conf carries into 4.x
unchanged, and the summer window is open. mTLS (OPS-420) runs after 4.x.

## The ratchet — this design is notch 1

The path from plaintext-with-passwords to cert-only authentication has four
independently flippable notches:

1. **Encrypt (this design).** Fresh CA + broker cert; conf serves TLS with
   `ssl_options.verify = verify_peer` and `fail_if_no_peer_cert = false`.
   Client certs are optional: verified when presented, rejected when invalid,
   ignored when absent. Clients move to 5671/8883 with a copy of `ca.crt` and
   a port change; passwords unchanged.
2. **Client certs.** Mint per-client certs and migrate actors one at a time;
   `verify_peer` checks each cert as it appears, so there is no flag day.
   Identity — what goes in each CN — is decided here.
3. **Require certs.** `fail_if_no_peer_cert = true`: a client without a valid
   cert cannot connect. Passwords still do the login.
4. **Cert is the identity.** Enable `rabbitmq_auth_mechanism_ssl`
   (`auth_mechanisms = EXTERNAL`, `mqtt.ssl_cert_login = true`): the cert CN
   becomes the username, each account loses its password
   (`rabbitmqctl clear_password`), PLAIN is dropped, and the plaintext
   listeners 5672/1883 close.

Notches 2–4 belong to OPS-420 and run after the 4.x upgrade (OPS-424). They
turn on per-client identity, which that design owns — including the CN story
for non-GNode principals such as `analytics.ear.reader`. Notches 3 and 4 may
combine into one restart once every client presents a cert and every CN has
its passwordless user; keeping them written as separate notches keeps
handshake failures (TLS layer) distinguishable from auth failures (CN→user
mapping) on cutover day. The management UI (15671) keeps password login over
HTTPS in every era.

## Decisions

### New CA

- `gwcert ca create Gridworks-Self-Signed-CA-2026 --valid-days 3650` on
  certbot. A ten-year root: leaf lifetime is the rotation knob, not the
  root's. The year in the CN keeps any stray 2023 `ca.crt` unmistakable in
  logs and error output.
- The 2023 CA is archived, not deleted: on certbot,
  `~/.local/share/gridworks/ca` → `ca-2023-expired`; the 1Password entry is
  renamed `certbot CA 2023 — EXPIRED, superseded by 2026`. gwcert mints the
  new CA into the default location so existing tooling paths keep working.
- New 1Password entry `certbot CA 2026` holds the new private key + cert.
- **Custody invariant: the CA private key exists on certbot and in 1Password,
  nowhere else — never plaintext anywhere else.** No Drive copy.
- `ca.crt` (the public certificate) is committed to
  `gridworks-infra/authority/`; clients get it by git pull.
- The certbot box gets its own ssh keypair (per-person public keys for the
  people who genuinely need CA access) and the `gridworks-hybrid` line comes
  out of its `~/.ssh/authorized_keys`. The everything-key must not open the
  box the root key lives on. Fleet-wide key cleanup is OPS-448.

### Broker certificate

- One 2-year keypair serves all three TLS listeners (AMQPS 5671, MQTTS 8883,
  management 15671). CN `hw1-1.electricity.works`, and the same name as a DNS
  SAN — modern TLS libraries check the SAN, not the CN.
- Minted on certbot, transferred with the documented rclone flow
  (`authority/tls/tls-certs.md`), then deleted off certbot.
- Two years, deliberately unsynchronized with the CA: leaves and root must
  never expire together (the 2023 PKI died whole within two days). Renewal is
  mint + copy + container restart.

### Conf

- One parameterized prod conf at
  `gridworks-infra/rmqbot/rmq-docker/config/rabbitmq.conf` using RabbitMQ's
  `$(VAR)` env interpolation (3.9+; prod runs 3.9.13). Ports, cert paths, and
  log level become variables fed by a per-deployment env file.
- The default user's password leaves the conf: a docker compose secret feeds
  the env var (the rmq-docker README's standing TODO).
- TLS block per the ratchet: `verify_peer` + `fail_if_no_peer_cert = false`.
- Conf standard across deployments (the dev conf stays in gridworks-base):
  **every difference between the dev and prod confs is a declared parameter
  or a documented reason** — no silent drift. Definitions get a stronger
  guarantee (generated from gwbase and drift-tested, OPS-425); confs get this
  no-silent-drift standard rather than literal identity.

### smqPublic rotation — same window

The live conf carries the default user's real password in plaintext, and the
password has also appeared in local session transcripts. Rotate it in the
same restart: new password minted into 1Password, broker comes up on the
secret-fed conf, then every client's stored credential is updated (runbook
below). `analytics.ear.reader` has its own credential and is untouched.

## Restart day (runbook)

1. **Pre-stage:** new CA + broker cert on hw1-1; new conf validated; new
   password in 1Password; the current conf + certs copied aside on the box —
   rollback is one compose restart on the old set.
2. **Go/no-go:** ssh reachability confirmed to every client box (SCADAs,
   LTN instances, web-backend). No client may be left holding a dead password
   with no update path.
3. **One restart:** conf + certs + rotation together.
4. **Verify the broker** (experiment below) before touching any client.
5. **Client credential sweep by blast radius:** SCADAs house-by-house, then
   LTN instances, then web-backend. Each client is broker-offline only
   between the rotation and its own update; local control is unaffected.

## Verification — the EDD experiment

The harness: `gridworks-infra/rmqbot/rmq-docker/tests/check-broker-contract.py`
plus the mosquitto one-liners in `rmq-docker/README.md`, kept in the repo as
the re-runnable reproducer. Expectations are hardcoded; OPS-425 may later
generate them from the gwbase topology.

1. **AMQPS 5671 with `ca.crt` only (no client cert):** pika connect,
   declare/bind/consume. Proves the new chain verifies and that client certs
   are optional. No current tooling exercises 5671, yet it is where every
   AMQP client lands.
2. **MQTTS 8883 the same way:** mosquitto_sub/pub with `--cafile` only. The
   old README recipe's `--cert`/`--key` flags are deliberately dropped — the
   old conf demanded a client cert; the new one must not.
3. **A garbage client cert is rejected on both ports:** self-signed junk must
   fail the handshake. This is the `verify_peer` half working, and it catches
   an accidental `verify_none`.
4. **Plaintext 5672/1883 still authenticate with the rotated password** — the
   fleet's lifeline until notch 2, and proof the rotation propagated.

Then fleet health: every SCADA and LTN reconnected and reporting. The
`analytics.ear.reader` permission checks (connect, read `ear_tx`, publish
refused, out-of-prefix queue refused) ride in the same harness.

## Deliverables

- `gridworks-infra/authority/cert-inventory.md` — one row per cert: subject,
  authority, where it lives, expiry, how it renews, owner. Public metadata
  only, never keys.
- `authority/certbot/README.md` rewrite — its "not actually using TLS
  correctly / WORK IN PROGRESS" content becomes false when this ships.
- The harness script (above).

## Follow-ups (out of scope, tracked)

- **rmqbot health + cert-expiry alerting** — OPS-449. A daily
  `openssl -checkend` against the live TLS ports doubles as a broker-up
  probe; the cert inventory lists what to watch.
- **Fleet-wide SSH access audit + re-key** — OPS-448.
- **GNode client-cert lifetime policy** — 2 years while renewal is manual,
  expiries steered to summer and staggered (never the same-day cliff);
  shorter once issuance automates. Final numbers land with OPS-420.

## Open

- Confirm SCADA behavior through a broker outage against the scada spec
  before restart day (expected: local operation continues, reconnect on
  return).
