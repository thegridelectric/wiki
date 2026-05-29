# Design: `gw-data-analytics` instance + rolling S3→Postgres import

> Status: Draft · Pass 0 · Updated 2026-05-29

What this is: the plan for standing up a research/analytics PostgreSQL+TimescaleDB
instance for the `gw_data` schema on AWS, backfilling it from the S3 event store,
and keeping it current with a governance-delayed daily importer. On completion the
durable distillate folds into [`../executor/`](../executor/) §7 Operations and
this file is deleted (per `wiki/designs-process.md`); Linear is the authority on status.

## Context

An analytics DB for the `gw_data` schema (`messages`, `readings`,
`reading_channels`, …) populated with historical fleet data. Beyond plain analytics:

- **Dev/prod parity** — runs from the same `timescale/timescaledb-ha` image the
  dev README uses.
- **Governance buffer** — ingests S3 data only once it is **≥ 14 days old**,
  giving Efficiency Maine a window to veto data egress after a catastrophic event.

Outcome: a running DB, a one-time backfill **Feb 1 2026 → (today − 14d)**, and a
**daily rolling job** importing the date that has just aged past the 14-day lag.

## Status

**Done (box `gw-data-analytics`, Ubuntu 24.04 arm64, `t4g.small`):**
- Instance launched; key `gridworks-collaborators`; hostname `gw-data-analytics`.
- 50 GiB EBS gp3 → xfs at `/mnt/data` (fstab by UUID, `nofail`).
- Docker 29.5.2; `timescale/timescaledb-ha:pg18-ts2.25` pulled; `/mnt/data/pgdata` `chown 1000:1000`.
- `gridworks-data` + `gridworks-journalkeeper` cloned as siblings in `/home/ubuntu/`; `uv` installed.
- **IAM instance role `gw-data-analytics-role` attached + verified** (read-only
  `s3:ListBucket`/`GetObject` on `s3://gwdev/hw1__1/eventstore/*`).
- **Importer correctness fixes PR'd to Joe** (base `jds/db_v2`):
  `jm/importer-robustness` (empty-date guard + log-and-continue + tests) and
  `jm/idempotent-msg-id` (deterministic `uuid5` ids + test).

**Remaining:** DB container not up; no roles/migrations; importer not deployed to
the box; no backfill. See the deployment phases below.

## Sequencing (agreed)
1. **Wait for Joe to merge** the two importer PRs into `jds/db_v2`.
2. On the merged base, **add the import tool**: the two-mode loader (explicit
   date-range + rolling) with the **14-day** governance clamp — reference
   implementation on `jm/s3_hack` (`s3_analytics_import.py`), to be brought
   forward and bumped 5→14. *(Functional requirements, not necessarily a wrapper:
   see [`../../gridworks-journalkeeper/designs/s3-importer-improvements.md`](../../gridworks-journalkeeper/designs/s3-importer-improvements.md).)*
3. **(Ideally) add bulk-import speed (G1, batch commits)** — the one *speed*
   (not correctness) item; may slip to post-launch if the basic backfill is fast
   enough. The 14-day-lag tool, by contrast, **must** be in before launch.
4. **Launch**: deploy → backfill → rolling timer.

The importer track (tooling + tests) is owned by the gjk designs
([`s3-importer-improvements.md`](../../gridworks-journalkeeper/designs/s3-importer-improvements.md),
[`layered-test-harness.md`](../../gridworks-journalkeeper/designs/layered-test-harness.md));
this doc owns **deployment**.

## Deployment plan

### Phase A — Postgres up (secret-bearing steps run by the human)
1. `docker run` the container with `/mnt/data/pgdata` persistence,
   `--restart unless-stopped`, `-p 5432:5432`, `POSTGRES_PASSWORD` (→ 1Password).
   Verify `docker ps` + `SELECT version()`.
2. Run `gridworks-data/src/gw_data/db/scripts/0_server_init.psql` interactively →
   `gridworks` DB + roles `gw_admin`/`gw_writer`/`gw_reader` (→ 1Password).
3. In `~/gridworks-data`: `.env` (`GW_DATA_DB_URL` as **gw_admin**); `uv sync`;
   `uv run alembic upgrade head` → 12 tables + `readings` hypertable + compression. Verify `\dt`.
4. `1_db_seed.py` optional (real data comes from the backfill).

### Phase B — Deploy the import tool on the box (after the PRs merge + the tool is added)
- Switch the box clone to the merged base; `git pull`; `uv sync`.
- `~/gridworks-journalkeeper/.env` (mode 600): `GJK_DB_URL` as **gw_writer** @
  `localhost:5432/gridworks`; `GJK_AWS__BUCKET_NAME=gwdev`,
  `GJK_AWS__REGION_NAME=us-east-1`, `GJK_WORLD_INSTANCE_ALIAS=hw1__1`.
- Smoke tests: `Settings()` constructs; boto3 lists a prefix; a `--dry-run` on one date.

### Phase C — Backfill (Feb 1 → today − 14), in `tmux`
Run the date-range mode clamped to `today − 14`; `tee` a log. Then optionally
trigger TimescaleDB compression early (`run_job`).

### Phase D — Steady-state rolling (systemd timer, daily)
A oneshot service (`User=ubuntu`, rolling mode, `After=docker.service`,
pg-readiness `ExecStartPre`) + a daily timer (`OnCalendar`, `Persistent=true`),
`enable --now`; verify `list-timers`. Imports the date that is exactly 14 days old.

### Phase E — Document
Fill `wiki/gridworks-data/executor/` §7 Operations (likely new
`executor/operations.md` off `primary.md`): EC2/Docker/EBS layout, role model,
backfill + rolling runbook, the **14-day** governance invariant, systemd units.
Add the `changelog.md` entry (verify vs diff). Cross-ref the gjk importer.

## Risks / open items
- **Sizing.** `t4g.small` (2 GB) is fine to validate + run the daily rolling job;
  the multi-week backfill / heavy analytics may want a temporary resize.
- **Lag enforcement is load-bearing.** The 14-day clamp is the governance control —
  it MUST be enforced by the import tool before any launch, in both backfill and rolling modes.
- *Resolved:* re-import duplication (deterministic `uuid5`, `7308766` + test `4c437ae`);
  `GNodeSettings` construction (Settings builds cleanly from a minimal `.env`).

## Verification (end-to-end)
With a ≥14-day-old target date D:
1. `Settings` loads; boto3 lists `hw1__1/eventstore/<D>/`.
2. Date-range `--dry-run` on D → object/type counts.
3. Baseline `SELECT count(*) FROM messages WHERE timestamp >= 'D' AND < 'D+1';`
4. Real import; summary errors=0; recount ≈ dry-run minus degraded.
5. **Idempotency**: re-run D; recount **unchanged** (backed by uuid5 + its unit test).
6. Rolling `--dry-run` targets exactly `today − 14`.
7. `systemctl start` once → journald summary; `enable --now` timer; `list-timers` shows next UTC fire.
