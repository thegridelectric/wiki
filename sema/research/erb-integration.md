# ERB ↔ Sema integration (research)

Status: Draft · Pass 0 · Updated 2026-06-09

> What this is: research notes on integrating ERB (Effortless Rulebook)
> practices and infrastructure with sema development. Currently holds the
> dev-postgres consolidation note (landed 2026-06-09 from a queued stash
> dating to the 2026-05-23 journalkeeper refactor).

## Postgres consolidation with gw_data

During the gridworks-journalkeeper → base 0.4.2 refactor (2026-05-23, session
bright-frost), a second dev postgres container was set up alongside the
existing one:

- `sema-pg` — `postgres:16`, port 5433, used by Sema work.
- (planned) `gw-data-pg` — `timescale/timescaledb-ha:pg18-ts2.25`, used by
  `gridworks-data` (per its README).

Jessica stopped `sema-pg` to free the slot. The note: **pick a single
postgres for dev** rather than running one per domain.

Tensions to resolve:

- Sema's `postgres:16` (vanilla) versus gw_data's `timescaledb-ha:pg18`
  (Timescale extension + PG 18). Timescale is a superset (vanilla PG +
  hypertables/compression); Sema can ride on it without using Timescale
  features. Converging on Timescale-on-PG-18 looks like the obvious pick.
- Database naming: gw_data's template.env uses DB name `gridworks`;
  sema-pg's DB name should be checked and consolidated.
- Users / roles: gw_data uses `gw_admin` per `0_server_init.psql`; Sema may
  use its own. Define a per-app role pattern with `gw_admin` as the
  superuser-equivalent (matches gw_data README §4 best-practices).
- Port: 5433 (the existing sema-pg slot) is reasonable; pick once and stick
  to it across umbrella dev.
