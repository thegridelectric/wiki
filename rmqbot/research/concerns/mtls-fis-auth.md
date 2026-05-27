# mtls-fis-auth (concern)

Status: Draft · Pass 0 · Updated 2026-05-27

> Phase 0 of the planned security architecture: move from
> password-based to **certificate-based mutual auth (mTLS)**. Each
> SCADA / app proves identity to the broker via cert. Foundation for
> the FIS (Fleet Index Service) auth model.

## Why this is a concern, not a design

The *direction* is clear — mTLS replaces passwords, cert CN encodes
the GNode identity, FIS authorizes the runtime instance over HTTP —
but the *plan* still has too many open dimensions to be a design:

- **Cert lifecycle.** Mint, rotate, revoke. The `gridworks-cert`
  + certbot-EC2 workflow exists for the broker cert today; how it
  extends to per-SCADA client certs is TBD.
- **FIS protocol details.** The handshake between
  broker-auth-backend ↔ FIS HTTP API is sketched in
  `gridworks-fleet-index-service/research/lifecycle.md` but the wire
  format isn't pinned.
- **Migration story.** Old SCADAs running 3.9-era libraries may not
  speak mTLS cleanly. Cutover sequencing across N homes is non-trivial.

When these resolve, this graduates from `concerns/` to
`designs/mtls-fis-auth.md`.

## Prerequisites

- **`prod-tls-fix`** must land (encryption-only TLS first).
- **`prod-4x-upgrade`** SHOULD land (mTLS work belongs on 4.x).

## Cross-refs

- [`../../designs/prod-tls-fix.md`](../../designs/prod-tls-fix.md).
- [`../../designs/prod-4x-upgrade.md`](../../designs/prod-4x-upgrade.md).
- [`../../../gridworks-fleet-index-service/research/lifecycle.md`](../../../gridworks-fleet-index-service/research/lifecycle.md).
- `authority/tls/tls-certs.md` (in `gridworks-infra`) — the original
  phase architecture.
