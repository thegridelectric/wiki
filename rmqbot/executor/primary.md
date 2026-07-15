# rmqbot — deployment spec (primary)

Status: Draft · Pass 0 · Updated 2026-06-23

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
- Runs via `docker compose` out of `~/rmq-docker` on the host.
- **RabbitMQ 3.9.13** — at/near community EOL.
- **TLS is currently broken** (the intent is encryption-only; the config is
  misconfigured).
- **CA / certs:** self-signed CA on a separate `certbot` EC2 instance (elastic IP
  `54.86.184.29`), using `gwcert` (`gridworks-cert`). Certs are minted there,
  copied via `getkeys.py` + `rclone`, then deleted off certbot. The CA + the
  certbot ssh key live in 1Password.

## Security posture today

- **Auth is password-based** over the public internet (SCADAs ↔ broker) — a
  current exposure given TLS is broken. The committed direction is encryption
  TLS, then **mTLS with FIS authorization** (cert subject → FIS `principal`).
- **Audit-tap consumers get a dedicated read-only user.** `analytics.ear.reader`
  (no tags; password in 1Password) is scoped so a leaked cred cannot touch the
  control plane: configure/write `^analytics\..*$`, read `^(analytics\..*|ear_tx)$`
  — it can declare its own `analytics.*` queues and bind them to `ear_tx`, and
  can publish nowhere (no exchange matches its write pattern). Consumers use
  non-durable auto-delete queues per the deferred-shovel arrangement
  (`../designs/analytics-broker-shovel.md`). Note: the user lives in the
  broker's data store, not `rabbit_definitions.json` — recreate (or fold into
  the definitions file) if the container is ever recreated.
- Admin control is via **Tailscale-protected textual interfaces** — adequate to
  ~30 homes; it hits Tailscale's ~100-device limit at the 100-home scale, which
  is the forcing function for the later security phases.
- Local MQTT brokers (Mosquitto on the Pis) are **LAN-only**, no auth, not
  internet-exposed.
- **Emergency response today:** rotate broker passwords, revoke Tailscale device
  access, restart SCADA in local-only (HomeAlone) mode, physical site access.

## Not migrated

The ssh / start / stop / test-TLS **runbook** and the certbot setup steps remain
operational reference in `gridworks-infra/rmqbot/` and
`gridworks-infra/authority/` (outside the wiki write boundary).

## In-flight changes

Tracked as designs in [`../designs/`](../designs/) and explorations in
[`../explorations/`](../explorations/); execution **order/priority lives in
Linear**, not here.
