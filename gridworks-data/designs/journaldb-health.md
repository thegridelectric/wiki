# journaldb-health

Status: Draft · Pass 0 · Updated 2026-08-26 · Linear: OPS-504

**EDD: no** build-out; verified when the gjk timer and the laptop
SessionStart line both report on the live `tsdb`, a deliberately abandoned
long query is killed by the server within the configured timeout, and one
restore from backup has been performed and checked.

> What this is: the checks and server-side guards that tell us the journal
> DB is healthy, where they run, and what they alert on. Today there are
> none.

## Why

On 2026-08-26 two full-hypertable scans (`readings ⋈ messages` counts)
outlived the psql clients that started them and ran for 8.4 hours on the
one-core service, alongside nine sessions left `idle in transaction`.
Nothing noticed; they were found by a session that happened to look at
`pg_stat_activity`. The same day the S3 loaders locked the service at
12–24 writers. Baseline numbers and the tier are in
`gridworks-infra/databases/journaldb.md` "Sizing".

The database is a rebuildable cache over the S3 eventstore, so the checks
are about *availability and freshness*, not about losing the record.

## 1. Server-side guards (migrations in gridworks-data)

A client-side timeout only ends the client; Timescale keeps the backend
running. The guards live in the database, as alembic migrations so a
rebuild re-applies them:

- `idle_in_transaction_session_timeout = '5min'` at the database level.
  A `with` block closes a transaction on exit but cannot shorten the idle
  gaps *between* statements inside it (an S3 fetch mid-batch, a hung
  call, a request-scoped ORM session after its first SELECT); this
  timeout is what ends those.
- `ALTER ROLE ... SET statement_timeout`, short by default: `'10s'` on
  `gw_visualizer` and `gw_journalkeeper`, `'2min'` on a new read-only
  `gw_analyst`. Code that legitimately runs longer (the channel-data
  download, a bulk-load batch) raises its own cap inside the transaction
  with `SET LOCAL statement_timeout = '5min'`; the role default stays
  tight so a stray scan dies in seconds whichever credential ran it.
  (`gw_visualizer` keeps write access: the web backend updates
  `users.last_login`.)
- Laptops hold only the `gw_analyst` credential (`GJK_DB_URL` in
  `experiments/.env`); the writer credential lives on gjk and the loader
  box. Which role a session's queries run as is then decided by the
  environment, not by remembering to pick the right one.
- Application names on every connection (`application_name` in the JK
  and loader DSNs) so `pg_stat_activity` says who a session is.

## 2. The checker

One read-only script in gridworks-data (`scripts/db_health.py`; the
schema owner is where the invariants belong), exit 0 / non-zero, one
summary line first, details after. Checks and starting thresholds:

| check | query | alert when |
|---|---|---|
| freshness per house | max `readings.timestamp` per house over non-forecast channels (forecast channels carry future timestamps and would mask staleness); live houses from the registry, not a hand list | any house > 15 min stale |
| long queries | `pg_stat_activity` client backends, `state='active'` | any > 15 min |
| idle in transaction | same, `state='idle in transaction'` | any > 5 min (should be impossible after §1; a hit means the guard is missing) |
| connections | `count(*)` vs `max_connections` (105) | > 70 |
| policy jobs | `timescaledb_information.job_stats.last_run_status` for every compression / retention job present (today the `readings` compression policy; the `messages` / `snapshots` policies as they land) | any failed, or last success > 2 × schedule |
| compression lag | uncompressed chunks with `range_end` older than the policy's `compress_after` | any |
| growth | `pg_database_size` and per-hypertable size, compared with the previous run's stored value | > 2 × the trailing weekly rate |

Thresholds are constants at the top of the script, not arguments; the
script takes only the DSN (from the environment, the same `GJK_DB_URL`
convention the experiments repo uses).

## 3. Where it runs

Same script, two callers:

- **gjk, systemd timer**, every 15 minutes, from the repo at a pushed SHA
  (box scripts come from the service repo, never scp'd). Failure posts to
  the existing Telegram dispatcher; until OPS-449 gives alerting a
  non-legacy home, `journalctl -u db-health` on gjk is the record.
  Recorded in `gridworks-infra/gjk/instance-README.md`.
- **Laptop, SessionStart hook**, printing the summary line next to the
  spruce-health and platform-drift lines. This is the surface a person
  actually looks at every day.

Not in gridworks-alerts (house-condition alerting for humans, mid-move off
the legacy journaldb box), not in JK (the keeper being down is one of the
things measured).

## 4. Backups and access

- Nobody holds console credentials for the Tiger project, and the
  backup / point-in-time-recovery setting is unknown. Every item above
  needs the `gw_admin` role or the console (§1 for `ALTER DATABASE`,
  policies for §2's job checks, resize for growth).
- One restore test: restore the latest backup to a scratch service,
  run the checker against it, drop it. Record the date and what was
  found in `journaldb.md`.

## Order

4 (console access) → 1 → 2 → 3, each step verified against the live
`tsdb`. §1 alone would have ended the 2026-08-26 orphans in five
minutes.

## Open

- Whether freshness reads the live-house list from the registry (gnr) or
  from `reading_channels` activity; the registry is the authority, the
  activity list needs no dependency.
- Threshold for freshness on a house that is legitimately offline
  (summer shutdown): probably a per-house allow-list in the same constants
  block, revisited when the registry carries an operational state.
