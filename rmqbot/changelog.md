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

## 2026-07-18 — Rabbit at 4.1

Branch `jm/green-broker-4x` — the flip-day paper trail (the flip itself:
EIP re-associated to the new box at ~07:44 ET, full census in ~90s).

The definitions copy leaves this repo (`git rm`; deliberately no
`.gitignore` entry — an ignored file could sit stale and invisible in a
checkout, while untracked noise prompts deletion): canonical home is
gwbase's generated artifact alone; the provisioning recipe loads it onto
the box at the path compose mounts, so the file exists only there. Not in the repo is not the same as not on the
box — the box always has the file, git never does, and the live broker's
arrangement is already exactly this. The manual diff-before-recreate
ritual is replaced by `tests/check_topology_drift.py`: a loud LIVE check
of the running broker's vhost/exchanges/exchange-bindings against the
canonical artifact over the management API, which also catches
runtime-declared strays (the legacy weather actor's `ws_tx` was the
proven case) — first run on the new broker: IN SYNC.

The README gains the full recreate-the-box recipe (WorldRabbit template →
Docker → code by rsync → 1Password secrets with the uid-999 keyfile
gotcha → boot → users → verify → human-run EIP move), verified end-to-end
by the green-box build it documents; its debug-tap section adopts the
general `debug` queue convention (rebind to the house under
investigation) with the `debug-cap` policy (max-length 1000, drop-oldest)
as the structural backstop alongside the planned OPS-453 alert. The
`WorldRabbit` launch template's new default version (v4) pins the
green-box shape — nothing baked in a custom AMI.

The inventory's hw1-1 row becomes the new box (RabbitMQ 4.1.8,
m8g.medium, Ubuntu 26.04, generated topology, all users runtime-created,
`rmqbot-2026` key only) plus a rollback-standby row for the old 3.9.13
box (terminate after soak, with the AMI + template cleanup per OPS-424);
journalmaker's row drops the weather service (retired by hand on cutover
morning — successor tracked as OPS-454). `how-tls-works.md`'s FAQ gains
the browser-trust entry (why 15671 shows "Not Secure" despite encryption,
and the one-time CA import that fixes it).

## 2026-07-17 — green standup finds: 4.x skips conf user seeding, rabbitmqadmin v2

Branch `jm/green-broker-4x`, from actually booting green (the EDD half of
the staging commit). The big find: with `definitions.local.path` set, 4.x
creates NO vhost or users from conf — green booted with full topology and
an empty user table. The conf drops the now-dead
`default_user`/`default_pass`/`default_vhost`/`default_permissions.*` keys
(no `$(VAR)` interpolation remains); the README gains the
create-the-default-user step after `up -d` (creds stay inside the container
env) and the recreate warning now covers ALL users, default included. The
compose env-injection comment reflects its real remaining consumer (the
in-container recipes). Second find: the 4.x image ships rabbitmqadmin v2
(Rust rewrite) — the debug-queue recipe rewritten in its flag syntax. The
design's conf-migration section records both; its open list shrinks to
restart-day timing.

## 2026-07-17 — green broker staging: 4.1.8, migrated conf, generated definitions

Branch `jm/green-broker-4x` — the green box's config, per the Accepted
Pass-1 designs (OPS-424 blue/green + OPS-425 generated topology).
`compose.yaml` pins `rabbitmq:4.1.8-management` (latest patch of the 4.1
line dev validated; official multi-arch image replaces the arm64v8/ 3.9.13
pin) and drops the 3.x erl-args definitions mechanism for a conf-side
load. `rabbitmq.conf` gains `definitions.import_backend = local_filesystem`
+ `definitions.local.path` (the mounted file carries no users, so
default-user seeding from `.env` still runs); `mqtt.subscription_ttl`
(ms) becomes `mqtt.max_session_expiry_interval_seconds = 86400` (s); the
`mqtt.default_user/pass` anonymous-fallback keys are dropped, not migrated
— with `mqtt.allow_anonymous = false` they had no effect, and 4.x removed
them. `config/rabbit_definitions.json` becomes a byte-identical copy of
gwbase's generated `hybrid_definitions.json` — current-era exchange fabric
(the weather retarget rides the cutover; see the OPS-425 design's cutover
section) — with the README gaining the never-hand-edit rule and the
sibling-checkout drift-diff command. TLS, management, and default-user
conf blocks carry over from OPS-423 unchanged.

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
