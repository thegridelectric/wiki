# granular-permissions-and-web-admin (concern)

Status: Draft · Pass 0 · Updated 2026-05-27

> Phases 2–3 of the planned security architecture, kept as a single
> concern because both depend on mTLS landing and both are still
> exploratory.

## Phase 2 — Certificate-based granular permissions

Derive per-actor publish/consume rights from the mTLS cert CN. E.g.
`CN=hw1-keene-beech-scada` → that SCADA can publish to its own
`scada_tx` exchange only, consume from its addressed inbound queue
only. Today permissions are coarse (mostly `.*` regex on each user).

Considerations open:
- How does the broker derive permissions from cert CN at runtime?
  RabbitMQ supports auth-backend plugins — does any existing plugin
  do this, or do we write one?
- How do permissions evolve as a SCADA's role changes? Re-mint cert
  vs. permission-table lookup?
- Source-IP allowlisting (Tailscale ranges + known SCADA IPs) belongs
  here — defense in depth.

## Phase 3 — Web admin on the cert foundation

Replace Tailscale-protected textual interfaces with a proper admin
web app — OAuth/SAML + client cert + Tailscale + SCADA-level command
authz, plus cert lifecycle UI.

The forcing function is scale: Tailscale's ~100-device limit hits at
the 100-home scale. Today's ~30-home fleet doesn't need this.

Considerations open:
- Tech stack — likely whatever the dashboard tier ends up on.
- How web admin and FIS HTTP API relate (one service or two).

## Why this is a concern, not a design

Both phases have direction (cert-derived permissions; web admin on
cert foundation) but the *how* is still wide open. They graduate to
`designs/` when:
- `mtls-fis-auth` has shipped and we know what cert claims are
  available
- the 100-home scale is closer and the forcing function is real

## Cross-refs

- [`mtls-fis-auth.md`](mtls-fis-auth.md) — prerequisite.
- `authority/tls/tls-certs.md` (in `gridworks-infra`) — original
  phase architecture.
