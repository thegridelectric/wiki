# rmqbot — Broker Operations & Remediation Backlog

> `rmqbot` is GridWorks' deployed production RabbitMQ/MQTT broker
> (`hw1-1.electricity.works`, AWS, docker; vhost `hw1__1`). This domain
> owns the **running broker**: hosting, compose, TLS/certs, ops runbook, and
> the remediation backlog below. It is distinct from:
> - [`../../gridworks-base/`](../../gridworks-base/) — *generates* the
>   exchange/binding definitions (topology).
> - [`../../ear/`](../../ear/) — the audit-tap mechanism.
> - [`../../gridworks-fleet-index-service/`](../../gridworks-fleet-index-service/)
>   — the auth authority the broker calls over HTTP.
>
> Migrated from `gridworks-infra/{rmqbot,authority/tls,authority/certbot}`.
> The faithful deployment spec (corrected TLS/mTLS config, compose, conf)
> will land in `../executor/` once this converges.

## Current state (as documented)

- Single production broker `rmqbot` on AWS, reachable at
  `hw1-1.electricity.works`; management UI `https://hw1-1.electricity.works:15671/`.
- Runs via `docker compose` out of `~/rmq-docker` on the host.
- Self-signed CA lives on a separate `certbot` EC2 instance (elastic IP
  `54.86.184.29`), using `gwcert` (`gridworks-cert`). Certs are minted
  there, copied to where they're used via `getkeys.py` + `rclone`, then
  deleted off certbot. CA + certbot ssh key are in 1Password.

## KNOWN BROKEN — TLS on prod `hw1__1`

Per `gridworks-infra/authority/certbot/README.md`: **the broker is not
using TLS correctly.** The fix is to follow the
[gridworks-proactor TLS](https://github.com/SmoothStoneComputing/gridworks-proactor/tree/dev#tls)
setup — there is a sample rabbit config that needs to be copied; the current
one is misconfigured. Today's intent is **encryption only**; there is **no
mutual (2-way) TLS authentication** — broker access is still
password-based.

This is also a **prerequisite for FIS**: the FIS auth model
([`../../gridworks-fleet-index-service/research/lifecycle.md`](../../gridworks-fleet-index-service/research/lifecycle.md))
authenticates durable node identity via mTLS (cert CN = `GNodeId`) and then
authorizes the runtime instance over HTTP. Without working TLS/mTLS, that
model can't stand up.

## Remediation backlog

### Now / blocking
1. **Fix TLS configuration** on `hw1__1` — follow gridworks-proactor TLS;
   copy the correct rabbit config; verify with `mosquitto_pub/sub` on 8883
   (the test in `rmq-docker/README.md`) and the management UI on 15671.
2. **Identities move into the generated definitions (resolved — gridworks-base
   open #5).** User/vhost/permission creation moves out of the conf's
   `default_vhost`/`default_user`/`default_pass`/`default_permissions.*`
   lines and into the *generated* definitions JSON (the single source of
   truth for identity + topology; avoids the `default_*`-vs-`load_definitions`
   import-order ambiguity). RabbitMQ definitions store a `password_hash`, not
   plaintext.
   - **Dev:** the `smqPublic` user + hash is committed in the dev definitions
     — non-secret, fine in the public GHCR dev image.
   - **Prod (`hw1__1`):** do **NOT** bake the prod user/hash into any
     published artifact. Inject it at deploy via
     [docker compose secrets](https://docs.docker.com/compose/use-secrets/) /
     [conf env-variable interpolation](https://www.rabbitmq.com/configure.html#env-variable-interpolation),
     or keep the prod definitions private. This subsumes the old TODOs
     ("remove hardcoded user/pass from `rabbitmq.conf`" — the `THE_PASSWORD`
     placeholder — and "replace username references in
     `rabbit_definitions.json` with something indirect").
3. **Conf reconciliation.** Once identities leave the conf, the two conf
   files (`for_docker/dev_rabbitmq.conf` d1__1 and
   `rabbit/rabbitconfig/rabbitmq.conf` hw1__1) collapse to one minimal,
   parameterized template. The only env-specific line left is `mqtt.vhost`
   (`d1__1` vs `hw1__1`); `management.load_definitions` path is constant.

### Prod upgrade sequencing (deferred, by decision)

The prod rabbit upgrade is **intentionally deferred** until we have
"kicked the tires" with a first gridworks-base actor running against the
**dev** broker. Sequence:

1. Stand up the new dev broker (RabbitMQ **4.x**, GHCR-published image, new
   generated definitions) and validate a first gwbase actor end-to-end.
2. *Then* upgrade prod `hw1__1` to **4.x** (the prod target matches dev, so
   the dev validation de-risks the prod jump).

Until step 2, **dev/prod parity is intentionally suspended** (dev on 4.x,
prod on 3.9.13). The generated definitions are kept **version-agnostic**
(plain exchanges/bindings/queues/identities — no 4.x-only features) so the
*same* topology loads on both old prod and new dev. The prod TLS fix (item
1) and **mTLS + FIS** remain a **separate later track** (see
[`../../gridworks-fleet-index-service/`](../../gridworks-fleet-index-service/));
4.x is the right foundation for that work because 3.x is at/near community
EOL — don't anchor new security-critical auth to an unsupported line.

### Planned security architecture (from `authority/tls/tls-certs.md`)
- **Phase 0 — mTLS.** Password → certificate-based mutual auth. Each SCADA/
  app proves identity to the broker; foundation for FIS.
- **Phase 1 — Broker separation.** Production (real-time grid ops only) vs.
  analytics (read-only mirror) broker, via federation/shovel. **This is the
  same decision reached in [`../../ear/executor/broker-tap.md`](../../ear/executor/broker-tap.md)**:
  passive `ear_tx` tap on the control broker, shovelled to a separate
  analytics broker where journalkeeper/dashboards/partners live. No
  analytics entity connects to the control broker.
- **Phase 2 — Certificate-based granular permissions.** Derive per-actor
  publish/consume rights from the mTLS cert CN
  (e.g. `CN=hw1-keene-beech-scada` → own exchanges only). Source-IP
  allowlisting (Tailscale ranges + known SCADA IPs).
- **Phase 3 — Web admin** on the certificate foundation (OAuth/SAML +
  client cert + Tailscale + SCADA-level command authz; cert lifecycle UI).

### Operating context / constraints
- Admin control is currently via **Tailscale-protected textual interfaces**
  — adequate to ~30 homes; hits Tailscale's ~100-device limit at the
  100-home scale, which is the forcing function for Phases 1–3.
- Local MQTT brokers (Mosquitto on Pis) are **LAN-only**, no auth, not
  internet-exposed.
- Emergency response today: rotate broker passwords, revoke Tailscale
  device access, restart SCADA in local-only (HomeAlone) mode, physical
  site access.

## Cross-references to in-flight decisions

- **gridworks-base open #5 (resolved)** — identities + topology both live in
  the generated definitions; conf becomes one parameterized template; dev
  hash committed, prod hash injected. This *is* the resolution of backlog
  items 2–3 above.
- **gridworks-base open #6 (resolved: deferred)** — FIS HTTP-auth + mTLS is a
  separate later track, gated on the prod TLS fix (item 1) and the prod 4.x
  upgrade. Not in scope for the current dev-broker work.
- **Broker separation (Phase 1) == the ear/analytics split** already
  decided in [`../../ear/executor/broker-tap.md`](../../ear/executor/broker-tap.md).

## Not migrated (operational runbook stays in gridworks-infra)

The ssh/start/stop/test-TLS runbook and certbot setup steps remain useful
operational reference in `gridworks-infra/rmqbot/` and
`gridworks-infra/authority/`. Recommendation: strip the **TODO / planning /
known-broken** sections from those files (now captured here) and leave the
runbook, with a pointer to this doc — but that edit is in the
`gridworks-infra` *code* repo, outside the wiki write boundary, so it's
left for explicit follow-up rather than done here.
