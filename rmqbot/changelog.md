# Changelog

A reverse-chronological log of WHY we made each commit **in the
rmqbot side of `gridworks-infra`** (the deployed RabbitMQ/MQTT
broker config + ops). The matching git commit holds the WHAT (the
diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

<!-- pending commit -->
## 2026-07-15 — prod-tls-fix pre-stage: conf flip, secret-fed password, contract harness, cert inventory

Branch `jm/prod-tls-fix`, staged ahead of restart day (design: OPS-423,
Accepted Pass 1). `rabbitmq.conf`: TLS flips from demanding client certs
(`fail_if_no_peer_cert=true` — which made the TLS ports unusable) to
encryption-only with optional client certs (`verify_peer` + `false`), the
per-client on-ramp to mTLS; the default user's password moves out of the conf
into env interpolation fed from the box's `.env`; the management UI serves the
same single keypair as the broker listeners (one cert, one expiry).
`compose.yaml` gains the env injection and drops the separate mgmt-cert
mounts, with the no-data-volume recreate warning made explicit.
`tests/check-broker-contract.py` is the EDD harness (TLS both ways, plaintext
auth, the analytics.ear.reader permission contract). `authority/
cert-inventory.md` starts the cert register the November-2025 expiry showed
we were missing. README recipes drop the client-cert flags and record the
password TODO as resolved.

## 2026-07-13 — clarification

New section in `authority/tls/how-tls-works.md`: our private CA vs public CAs
(Let's Encrypt), and the name collision between GridWorks' "certbot" box and
the EFF's certbot. Written after the collision caused real confusion — a
teammate's ask for "certbot on the API server" meant Let's Encrypt for HTTPS,
not our gwcert CA. Rule of thumb captured: internal machine-to-machine uses
our CA; public-facing HTTPS uses Let's Encrypt; neither can do the other's job.

## 2026-07-13 — explaining tls in GridWorks

New `authority/tls/how-tls-works.md`: a plain-language refresher on the TLS
pieces — certbot-the-machine vs the CA files, why the CA certificate expires
while its private key does not, who holds which key and why (one keypair per
named party; `ca.crt` as the fleet-wide trust anchor, not rmqbot's cert), and
how the handshake bootstraps per-connection symmetric session keys (so
`ca.crt` verifies, it never decrypts). Pointers added from
`authority/certbot/README.md` and `authority/tls/tls-certs.md`. Written while
reviving the expired PKI (CA and broker certs expired 2025-11), so the
concepts stay re-learnable next time.
