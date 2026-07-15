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
## 2026-07-13 — private vs public CA note in how-tls-works

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
