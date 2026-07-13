# Populate + deploy — the MVP registry on EC2 (spoke)

Status: Accepted · Pass 1 · Updated 2026-07-08 · Linear: OPS-419

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
   fleet's birth record alongside the command log. **Prerequisite: the
   durable ear capture (OPS-443, strand 2) is deployed first** — genesis must
   be witnessed, since the capture is the registry's durability story. The ingest script is
   operator-run and deliberately **not checked in** (a one-shot; the command
   log + ear capture are the record, not the tool). **Every node enters
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

## Deploy — EC2 alongside FIS

- **Promote `g.node.create.cmd` to `published` first** (sema promotion PR) and
  drop `--allow-staged` from `build_gnr_snapshot.sh`: staging words are
  dev-broker-only, so a dev-only snapshot cannot ship to `hw1`.
- **Surface:** the read-only HTTP API (`gnr.api`) is the open surface —
  internal service API, privacy by the network perimeter. **`gnr_tx` stays
  unreachable from outside until mTLS+FIS lands** (hard requirement).
- **Postgres: a container on the box.** Chosen for infra-awareness and
  portability (a likely move off AWS once the stack is clear; the broker is
  already a container). The data directory lives on a **KMS-encrypted EBS
  volume**. **Durability is message-log-first, not database-backup-first**
  (see *Rebuild from the message log* below): Postgres is a materialized view
  of the logged commands. EBS snapshots MAY be taken as a restore
  accelerator; they are not the durability story and are not required.
- **gnr runs as a container too** (matching the broker and the direction of
  travel; write the `Dockerfile` in this step). `.env` injected at run;
  logs/state on a mounted volume.
- **Security: minimum new build only.** A purpose-built `gnr` security group —
  SSH from admin, the HTTP façade reachable only inside the perimeter,
  Postgres not exposed at all. The estate-wide cleanup is its own design
  (`ec2-security-group-cleanup`), deliberately decoupled because it may
  impact existing services.
- **Migrations:** `alembic upgrade head` on deploy, against the single squashed
  FK-free baseline.
- **Config/secrets:** `.env` from `template.env`; broker creds never hardcoded.
- **Snapshot cadence:** a periodic `broadcast_snapshot(root)` driver, cadence
  as deploy config (hub remaining item (b)).
- **README to standalone-adopter grade.** The "Next steps" list is stale — it
  still carries the retired "ConnectivityEdge consistency (ids and aliases
  match)" invariant (edges are ids-only now) and finished steps. Rewrite from
  the executor; READMEs stand alone (no wiki references).
- **Cleanup:** delete `scratch.py` (dead code) before the deploy commit.

## Rebuild from the message log (the durability story)

The ear's capture and gnr's `command_log` are the same stream seen from two
places, joined by the content hash (`gnr.ids.command_hash`): the command log
holds every command *applied*; the ear also holds the *refused* commands (the
audit of the registry saying no) and the `g.node.forest` broadcasts (the
announced results). Deterministic apply (executor *Distributed-readiness* #1)
is what makes replay valid: a rebuild replays the captured commands in capture
order through the handler core — refusals re-refuse, applies re-apply
byte-identically — and cross-checks the resulting forests against the captured
broadcasts. Two independent witnesses that must reconcile. This rests on:

- the ear capture running **before ingest** (above) and landing somewhere
  durable (S3, versioning on) — the capture bucket, not the database, is the
  crown-jewel store;
- replay preserving capture order (topology commands are rare and
  parents-first, so ordering is unambiguous at this scale; a command-carried
  logical time stays the deferred backstop, per the executor);
- **the rebuild script existing and being exercised** — an EDD experiment in
  the dev harness: capture a seed + mutations, wipe the DB, rebuild, assert
  `validate_registry`-clean and forests matching the captured broadcasts. An
  untested restore path is not a restore path.

Unlike the one-shot ingest script (operator-run, not checked in), the rebuild
script IS repo code: it is the durability mechanism, so it is checked in and
tested.

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
