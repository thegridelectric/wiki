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
## 2026-07-17 — rabbit 4x prep: LTN boxes, debug tap, queue-depth alert note

Branch `jm/rabbit-4x-prep`, from the pre-upgrade broker audit. The
production inventory gains the two LTN boxes (`atn/ltn` 34.194.147.127
elastic, `atn2/ltn2` 3.83.88.118 not elastic — found from the broker's
connection list, not yet walked; the name/connection-count mismatch and
spruce's unaccounted LTN go to the known-gaps queue). The orphaned
consumer-less `ear` queue on the prod broker (579 messages, silently
growing) was renamed live to `debug.beech-scada` — declared new + rebound +
old deleted after it drained; contents were duplicates of the ear→S3 and
JournalKeeper archives. The rmq-docker README's runtime-created section
grows a queues half with the re-creation recipe; the scada-alerts register
gains the planned broker queue-depth alert (any `hw1__1` queue > 1000,
management API — a new data source for the alerter) that backstops the
standing tap.

## 2026-07-17 — certbot README rewrite

`authority/certbot/README.md` rewritten to present truth: the box's job,
CA-2026 custody, the mint recipes (and the 825-day trap), leaf policy,
per-person ssh, and a rebuild-from-1Password section — replacing the
2023-era "TLS is not working / WORK IN PROGRESS" content the prod-tls-fix
design retired.

## 2026-07-17 — update alertsmanager info; include test recipe for hw1-1 rmqbot

The inventory's alert-manager entry gains what a rebuild would need: the
repo home (github.com/thdfw/alert-manager — personal GitHub, not the org),
the run form (`uv run alert-manager`), and the existing-but-idle
`alert-manager-sheet` entrypoint. The rmq-docker README gains the
from-a-laptop harness run recipe (throwaway venv, both password
placeholders, and the ACCESS_REFUSED-from-a-placeholder gotcha that looks
exactly like a broken rotation) — added right after the 6/6 verification
run that stamped the prod-tls-fix design Verified.

## 2026-07-17 — production inventory update

Two corrections from looking closer at the alerting path: the old
journalkeeper on journalmaker is not merely superseded — it is what keeps
journaldb fresh for gwalert's detection and the web dashboard, so the
decommission ordering is alerting-off-journaldb first. And the journaldb
row now records the post-OPS-451 alerting reality: gwalert re-enabled under
`MemoryMax=512M` (unit canonical in the gridworks-alerts repo), the
alert-manager Telegram dispatcher in tmux and not reboot-safe.

## 2026-07-17 — various

New top-level `production-inventory.md`: every production box, its services,
and which broker credential it holds — mapped by walking the boxes during
the prod-TLS restart sweep, which surfaced a nameless JournalKeeper box, a
weather service nobody had listed, and a still-running old journalkeeper.
Known-gaps section doubles as the follow-up queue (DNS name for the JK box,
scoped credentials via OPS-420); the ssh-access audit (OPS-448) extends it
with the authorized-keys map. The rmq-docker README gains the
runtime-created-users recipe (`analytics.ear.reader` add_user +
set_permissions) next to the recreate warning that makes it necessary —
deliberately a runbook snippet, not a script, since the analytics
arrangement moves with the broker separation.

## 2026-07-17 — tls explanations

`how-tls-works.md` gains a FAQ: how the password is protected — the encrypted
tunnel is fully established (cert verify, key agreement, symmetric session
keys) before AMQP's PLAIN auth ever runs, so "plain" means plain within the
channel. Written when the question came up live during the restart-day
sweep. `tls-certs.md`'s 1Password section now records the certbot ssh
posture: per-person keys only, the fleet key deliberately removed.

## 2026-07-15 — prod-tls-fix pre-stage: conf flip, env-fed password, contract harness, CA mint recipe, new ca.crt

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
password TODO as resolved. `authority/tls/tls-certs.md` replaces the
`gwcert ca create` recipe with the openssl root-mint recipe (gwcert's ownca
dependency caps certs at 825 days — the flaw that killed the 2023 CA) and
records the year-stamped 1Password custody entries. `authority/ca.crt` is
the new root's public certificate, committed for client distribution
(CN `Gridworks-Self-Signed-CA-2026`, valid to 2036-07-13).

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
