# journal-db-access — querying the prod journal DB

Status: Draft · Pass 0 · Updated 2026-08-10

> What this is: how to reach and query the production journal DB — the
> immutable store experiments pull from (see
> [`primary.md`](primary.md) "The three-layer data model").

## Where the DB is

The prod journal DB is **Timescale Cloud** (database `tsdb`), not on
the gjk box itself. Access path:

1. `ssh gjk` (journalkeeper.electricity.works; host alias in
   `~/.ssh/config`).
2. Read `GJK_DB_URL` from `~/gridworks-journalkeeper/.env` on the box.
3. `psql` that URL **directly from the laptop** — the DB is
   cloud-reachable (`sslmode=require`); no tunnel needed.

Trap: local repo `.env`s (gridworks-journalkeeper, gridworks-data)
point at `localhost:5433` dev containers that are usually not running.
Those are dev-only; don't chase them for prod data.

## Key tables

All in schema `gridworks`:

- `messages` — journaled wire messages: `message_type_name`,
  `from_alias`, `created_at`, `payload` (jsonb, PascalCase keys — the
  sema wire form).
- `reading_channels` — channel definitions; `channel_type` ∈
  `data.channel.gt` / `derived.channel.gt` / `"gjk.pseudo"` (the
  hand-rolled non-sema discriminator), with `unit`, `unit_type`,
  `terminal_asset_alias`, `deactivated_date`.
- `readings` — values by (`channel_id`, `timestamp`), each row linked
  to its source message via `message_id`.

Read-only SELECTs only; this is the production store.
