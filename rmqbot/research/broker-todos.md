# rmqbot — operational context + design index

> `rmqbot` is GridWorks' deployed production RabbitMQ/MQTT broker
> (`hw1-1.electricity.works`, AWS, docker; vhost `hw1__1`). This domain
> owns the **running broker**: hosting, compose, TLS/certs, ops runbook.
> Distinct from:
> - [`../../gridworks-base/`](../../gridworks-base/) — *generates* the
>   exchange/binding definitions (topology).
> - [`../../ear/`](../../ear/) — the audit-tap mechanism.
> - [`../../gridworks-fleet-index-service/`](../../gridworks-fleet-index-service/)
>   — the auth authority the broker calls over HTTP.
>
> Migrated from `gridworks-infra/{rmqbot,authority/tls,authority/certbot}`.
> The faithful deployment spec lands in `../executor/` once the designs
> below converge.

## Current state

- Single production broker `rmqbot` on AWS at
  `hw1-1.electricity.works`; management UI
  `https://hw1-1.electricity.works:15671/`.
- Runs via `docker compose` out of `~/rmq-docker` on the host.
- Self-signed CA on a separate `certbot` EC2 instance (elastic IP
  `54.86.184.29`), using `gwcert` (`gridworks-cert`). Certs minted
  there, copied via `getkeys.py` + `rclone`, then deleted off certbot.
  CA + certbot ssh key in 1Password.
- RabbitMQ **3.9.13** (EOL; upgrade tracked in
  [`../designs/prod-4x-upgrade.md`](../designs/prod-4x-upgrade.md)).
- TLS configuration **currently broken** (encryption-only intent;
  tracked in [`../designs/prod-tls-fix.md`](../designs/prod-tls-fix.md)).

## Designs (clear solution direction — `../designs/`)

| Design | Topic |
|---|---|
| [`prod-tls-fix`](../designs/prod-tls-fix.md) | Fix the broken TLS config on prod (encryption-only); blocks FIS + analytics shovel. |
| [`identities-in-definitions`](../designs/identities-in-definitions.md) | Move users/vhosts/permissions out of conf, into generated definitions JSON. |
| [`conf-template`](../designs/conf-template.md) | Collapse two near-identical conf files into one parameterized template (depends on `identities-in-definitions`). |
| [`prod-4x-upgrade`](../designs/prod-4x-upgrade.md) | Upgrade prod broker 3.9→4.x after dev validation. |
| [`analytics-broker-shovel`](../designs/analytics-broker-shovel.md) | Stand up analytics broker; shovel `ear_tx` from prod; migrate analytics consumers (incl. gridworks-journalkeeper). |

## Concerns (still investigating — `./concerns/`)

| Concern | Topic |
|---|---|
| [`mtls-fis-auth`](./concerns/mtls-fis-auth.md) | Phase 0 — password → mTLS migration; foundation for FIS auth. |
| [`granular-permissions-and-web-admin`](./concerns/granular-permissions-and-web-admin.md) | Phases 2–3 — cert-derived publish/consume rights, web admin UI. |

## Sequence (read top → bottom)

```
prod-tls-fix
  ├─► mtls-fis-auth (concern, later)
  └─► analytics-broker-shovel ──┐
                                │ (also depends on)
identities-in-definitions ──────┤
  └─► conf-template             │
                                │
prod-4x-upgrade ────────────────┘
  └─► granular-permissions-and-web-admin (concern, much later)
```

## Operating context / constraints

- Admin control today is via **Tailscale-protected textual interfaces**
  — adequate to ~30 homes; hits Tailscale's ~100-device limit at the
  100-home scale, which is the forcing function for the later phases.
- Local MQTT brokers (Mosquitto on Pis) are **LAN-only**, no auth, not
  internet-exposed.
- Emergency response today: rotate broker passwords, revoke Tailscale
  device access, restart SCADA in local-only (HomeAlone) mode, physical
  site access.

## Not migrated (operational runbook stays in `gridworks-infra`)

The ssh/start/stop/test-TLS runbook and certbot setup steps remain
operational reference in `gridworks-infra/rmqbot/` and
`gridworks-infra/authority/`. Recommendation: strip the
TODO/planning/known-broken sections from those files (now captured
across designs/concerns above) and leave the runbook with a pointer
back here — but that edit is in the `gridworks-infra` code repo,
outside the wiki write boundary, so it's left for explicit follow-up.
