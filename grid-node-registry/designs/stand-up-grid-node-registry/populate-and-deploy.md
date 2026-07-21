# Populate + deploy — the MVP registry on EC2 (spoke)

Status: Accepted · Pass 1 · Updated 2026-07-19 · Linear: OPS-419

**EDD: no** build-out/integration; verified by the deployed registry answering
real forest queries over its live surface (plus the suite staying green), not a
standalone experiment.

> What this is: build step 7 of the standup design — launch the registry on EC2
> and populate it with the real fleet. Everything upstream (handler core, rabbit
> write loop, HTTP read façade, harness, CI) is done; this spoke is the ordered
> path from "green suite" to "deployed registry FIS can query".

## Populate — the fleet enters as commands

The deployed registry's rows must be born through the handler core, never raw
SQL, so `command_log` + the alias ledger hold every row from birth (executor
*Distributed-readiness* #2).

1. **✅ DONE — The create command.** `g.node.create.cmd` v000 authored in sema
   (`status: staging`; the new node as a `g.node.gt` + optional opaque `Proof`)
   and vendored; `AuthoritySource.apply_create` claims the alias, appends to
   `command_log`, validates — one transaction, no edge rows, idempotent
   replay + alias pre-check + universe check; `GnrRabbit` decodes it and
   broadcasts the (single-node) forest on the parent's channel. Layer-1
   proven.
2. **Ingest:** the deployed fleet from `tlayouts/output/*.uploaded.json` — the
   parent copper chain plus each home's LTN/Scada/TA — as `g.node.create.cmd`s
   **published over rabbit**, parents-first, so the ear's capture holds the
   fleet's birth record alongside the command log. Genesis is witnessed by
   the ear, which is live and captures this traffic today; durable backup of
   that capture is OPS-443 strand 2, tracked separately — not a gate on the
   ingest. The ingest is **operator-run, one node per `gnr create`**
   (alias + class in, existence-checked, Pending out, published with the
   write Proof) — the operator sets the cadence; only the per-run command
   sheet stays out of the repo. **Every node enters
   `Pending`**; activation comes with the TaValidator / encryption work — the
   same step that adds the GPS positions — via the status-change command word
   (post-MVP, hub step 2). Sequencing caveat: a Pending node fails
   `assert_active`, so validation/activation must precede or accompany the
   mTLS+FIS enforcement cutover.
3. **Positions stay staged:** opaque random `position_point_id`s in the
   commands; `position_points` stays empty (the staging plan:
   [`../../explorations/positions-staging-and-encryption.md`](../../explorations/positions-staging-and-encryption.md)).

## One universe per registry, as required config

A registry instance is scoped to exactly one universe (executor *Universes*).
Enforce it rather than assume it: a required **`GNR_UNIVERSE`** setting
(`Settings`, no default — the deployer declares it), with the write path
rejecting any command whose aliases don't carry that segment-0,
`validate_registry` checking every row lives in it, and the harness/dev
compose setting `d1`. Hosting a second universe later means a second registry
deployment (its own DB + settings), not a flag on this one.

The MVP registry serves **`hw1`** — the universe of the deployed fleet — so
`GNR_UNIVERSE=hw1` and the ingested aliases keep their `hw1.*` form as-is. Its
rabbit adapter rides the live run's fabric, vhost **`hw1__1`** (the registry is
per-universe and shared across runs; the vhost is broker-connection config, not
registry state). The `w` registry is minted when that universe exists.

## Deploy — Hetzner US (the first service off AWS)

- **Host: a Hetzner US cloud instance** (CPX21-class, 3 vCPU / 4 GB). The
  registry is the first GridWorks service hosted off AWS, part of the move
  away from the big-cloud providers. It is the right first mover: fully
  containerized, rebuildable from the message log, and its only broker
  coupling is an **outbound** AMQP connection, which works the same from any
  provider. FIS is not co-located — it sits on the broker's auth hot path
  and belongs broker-adjacent; it consumes the registry over rabbit forest
  broadcasts, so nothing depends on a shared box. The box fronts a **Hetzner
  Floating IP** (the EIP analog — AWS EIPs cannot leave AWS), so replacing
  the server is an atomic re-point, never a DNS change. The
  `<name>.electricity.works` A record points at the Floating IP and stays in
  the existing Route 53 zone at MVP — one record; moving the zone off
  Route 53 is its own later item, deliberately not riding this deploy.
- **Promote `g.node.create.cmd` to `published` first** (sema promotion PR) and
  drop `--allow-staged` from `build_gnr_snapshot.sh`: staging words are
  dev-broker-only, so a dev-only snapshot cannot ship to `hw1`.
- **Surface: public read-only HTTPS.** The registry is backbone
  infrastructure and its topology is readable by anyone, not rabbit-only:
  the read façade (`gnr.api`) is served publicly over TLS (Caddy +
  Let's Encrypt in front; a DNS name created at deploy — DNS changes are
  operator-run), CORS-open, strictly read-only. Privacy rides on the data
  shape, not a network perimeter: topology only, opaque
  `position_point_id`s, `position_points` empty (the staging plan). Writes
  never ride HTTP; **`gnr_tx` stays unreachable from outside until mTLS+FIS
  lands** (hard requirement).
- **Postgres: a container on the box.** The data directory lives on a
  **LUKS-encrypted volume** (OS-level, provider-agnostic). **Durability is
  message-log-first, not database-backup-first** (see *Rebuild from the
  message log* below): Postgres is a materialized view of the logged
  commands. Volume snapshots MAY be taken as a restore accelerator; they are
  not the durability story and are not required.
- **gnr runs native under systemd** — the flattened service pattern
  (canonical: `wiki/gridworks-base/executor/service-deployment.md`):
  `gnr-rabbit.service` + `gnr-api.service` run the repo venv's `gnr` binary
  as the `gnr` login user; the repo is cloned in the homedir with `.env`
  beside it; a homedir README says what runs, where the logs are
  (`~/.local/state/gridworks/gnr/log/`), and the systemctl commands. No
  wrapper scripts, no image flow — Postgres is the box's only container.
  (Self-hosted rather than managed-RDS on purpose: the registry's Postgres is
  a materialized view of the message log, so the choice is cheaply
  reversible, and maintaining our own infrastructure stays a kept ability.)
- **Security: minimum new build only.** The provider firewall opens SSH and
  443 and nothing else; Postgres is not exposed at all. SSH access is by
  **individual per-person keys** (the certbot/rmqbot precedent); a shared
  key exists only as an **automation role key** (e.g. a future provisioning
  role) — never as a stand-in for multiple humans. The AWS estate-wide
  cleanup stays its own design (`ec2-security-group-cleanup`), unaffected.
- **Migrations:** `alembic upgrade head` on deploy, against the single squashed
  FK-free baseline.
- **Config/secrets:** `.env` from `template.env`; broker creds never hardcoded.
- ✅ DONE — **Snapshot cadence:** `gnr snapshot` (one-shot: broadcasts every
  forest root, or the roots given) driven by `service/gnr-snapshot.timer` →
  `.service`; the cadence lives in the timer file (deploy config: edit,
  re-copy, daemon-reload).
- ✅ DONE — **README to standalone-adopter grade**: rewritten from the
  executor (what the registry is, universes, invariants, one-prefix config,
  local dev, the public read API, running as a service, tests); the stale
  "Next steps" list is gone; no wiki references.
- ✅ DONE — **Cleanup:** `scratch.py` deleted (it was empty and untracked).

## Rebuild from the message log (the durability story)

Canonical: executor *Durability — the message log is the system of record*
(no required DB backups; `command_log` + the ear capture are one stream
joined by the content hash; rebuild = ordered replay through the handler
core + forest cross-check). What this step must deliver:

- the ear witnessing the ingest (it is live and captures this traffic;
  durable backup of its capture is OPS-443 strand 2, tracked separately);
- ✅ DONE (the replay core) — `gnr.rebuild.replay` + the
  `gnr rebuild <capture> [--wipe]` CLI, proven by the dev-harness EDD
  experiment (`tests/test_rebuild_layer2.py`: a real ear tap on a real
  broker captures genesis + a re-parent to JSONL → wipe → rebuild →
  identical `validate_registry`-clean forest, every broadcast checkpoint
  matching; checkpoints pair FIFO with replay-produced forests, with
  current-state equality as the snapshot fallback). The JSONL feed is
  provisional and the rebuild surface stays **off dev**: rebuilding from
  the TRUE persistent store (the ear's S3 eventstore) is its own gated
  design — OPS-457 (gates: the store's durable backup, and TaValidator
  activation making positions rebuildable).

## Done-when

- The registry runs on EC2 with the real fleet loaded: `validate_registry`
  clean, every `g_nodes` row's birth in `command_log`, every alias in the
  ledger, and the ear capture holding the full genesis stream.
- The rebuild-from-capture path is proven by the dev-harness experiment
  (wipe → replay → equivalent registry).
- `POST /gnr/g-node-forest-request` for the fleet's root returns the full
  forest; `GET /gnr/g-node-by-alias/...` resolves a home.
- The rabbit write loop is live on the deployed broker and `gnr_tx` is
  unreachable from outside.
- The README stands alone at adopter grade.
