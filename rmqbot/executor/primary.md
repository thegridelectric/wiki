# rmqbot — deployment spec (primary)

Status: Draft · Pass 0 · Updated 2026-07-17

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

## Current deployment

- Single production broker on AWS at **`hw1-1.electricity.works`**, vhost
  **`hw1__1`**; management UI `https://hw1-1.electricity.works:15671/`.
- Runs via `docker compose` out of `~/rmq-docker` on the host; deployment is a
  file copy from `gridworks-infra/rmqbot/rmq-docker/`.
- **RabbitMQ 3.9.13** — at/near community EOL; the 4.x upgrade is its own
  design (OPS-424), landing with gwbase-generated topology (OPS-425).
- **TLS serves on all three listeners** — AMQPS 5671, MQTT-TLS 8883,
  management 15671 — from a single 2-year keypair (CN + DNS SAN
  `hw1-1.electricity.works`, expires 2028-07). Plaintext 5672/1883 remain
  open deliberately (see the ratchet below).
- The conf is parameterized: the default user's credentials enter via env
  interpolation from the box's `.env` (mode 600, never committed) — no
  password lives in the conf or in git.
- **No data volume**: a container recreate wipes runtime state. Topology
  reloads from `rabbit_definitions.json` and the default user re-mints from
  `.env`, but runtime-created users must be re-created by hand — recipe in
  the rmq-docker README.

## PKI

- **Root:** `Gridworks-Self-Signed-CA-2026`, 10-year (to 2036-07), minted
  with plain openssl (gwcert's ownca dependency caps validity at 825 days —
  the flaw that killed the 2023 CA in 27 months). Lives on the `certbot` EC2
  box; **custody invariant: the CA private key exists on certbot and in
  1Password, nowhere else.** The public `ca.crt` is committed at
  `gridworks-infra/authority/ca.crt`; clients get it from git.
- **Leaf policy:** ~2 years; expiries steered to summer and staggered —
  leaves and root never share a cliff, and no cert expires in heating
  season. Leaf lifetime is the rotation knob, not the root's.
- **Client-cert CNs carry the immutable identity** (GNodeId for GNodes);
  naming and issuance automation are the mTLS design's to own (OPS-420).
- certbot ssh is **per-person keys only**; the fleet key deliberately does
  not open the CA box.
- Registers: certificates in `gridworks-infra/authority/cert-inventory.md`;
  what-runs-where in `gridworks-infra/production-inventory.md`.

## The TLS ratchet (current position: notch 1, plus one pilot house)

The path from plaintext-with-passwords to cert-only authentication has four
independently flippable notches; notches 2–4 belong to the mTLS design
(OPS-420) and run after the 4.x upgrade:

1. **Encrypt (done, verified 2026-07-17).** `ssl_options.verify =
   verify_peer` + `fail_if_no_peer_cert = false`: client certs optional —
   verified when presented, rejected when invalid, ignored when absent.
   Clients reach encryption with `ca.crt` + a port change; passwords
   unchanged.
2. **Client certs** — mint per-client (CN = immutable identity), migrate one
   client at a time; no flag day. Beech runs this today as the pilot:
   encrypted on 8883, presenting its GNodeId cert, verified at handshake.
3. **Require certs** — `fail_if_no_peer_cert = true`.
4. **Cert is the identity** — `rabbitmq_auth_mechanism_ssl`
   (`auth_mechanisms = EXTERNAL`, `mqtt.ssl_cert_login = true`): CN becomes
   the username, accounts lose passwords, PLAIN drops, plaintext listeners
   close. The management UI keeps password login over HTTPS in every era.

Notches 3–4 may combine into one restart once every client presents a cert
and every CN has its passwordless user; written separately, handshake
failures stay distinguishable from auth failures on cutover day.

## Security posture today

- **Auth is password-based** (the rotated shared default user), now inside
  TLS for clients that have moved to 5671/8883, still plaintext for the
  rest. Cert-based identity arrives with the ratchet.
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
- **Emergency response today:** rotate broker passwords, revoke Tailscale device
  access, restart SCADA in local-only (HomeAlone) mode, physical site access.

## Verification

The broker contract is checked by a re-runnable harness:
`gridworks-infra/rmqbot/rmq-docker/tests/check-broker-contract.py` (run
instructions in the rmq-docker README). Six checks: TLS-without-client-cert
on 5671, garbage-cert rejection, plaintext auth, and the analytics
permission contract in both directions. Run it after any conf change; 6/6
is the bar.

## Ops runbook

ssh / start / stop / recreate-warning / user-recipes / harness instructions
live in `gridworks-infra/rmqbot/rmq-docker/README.md`; certbot and cert
recipes in `gridworks-infra/authority/` (outside the wiki write boundary).

## In-flight changes

Tracked as designs in [`../designs/`](../designs/) and explorations in
[`../explorations/`](../explorations/); execution **order/priority lives in
Linear**, not here.
