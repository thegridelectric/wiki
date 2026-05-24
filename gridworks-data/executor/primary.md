# gridworks-data — Rebuild Specification (primary)

This is the **faithful-rebuild specification** for `gridworks-data`: the
authoritative account of GridWorks's shared PostgreSQL+TimescaleDB schema,
the roles that access it, the alembic-managed migration story, and the
boundary application services see (a database URL + a small set of
SQLAlchemy model classes).

> Status: Draft · Pass 0 · Updated 2026-05-23
>
> Acceptable-minimum bootstrap. Items marked "Open" are unwritten on
> purpose; raise them when a real decision arrives.

This is the **hub** document — short by design. Sub-specs sit beside it
as concerns surface; for now most depth is "Open".

## Map of the spec

| Sections | File | Covers |
| --- | --- | --- |
| §1–§4 | **primary.md** (this file) | What this is, central commitment, role in fleet, invariants, glossary |
| §5 | _Open_ | Schema reference — table-by-table contract (today: read `src/gw_data/db/models/`) |
| §6 | _Open_ | Migration workflow — alembic conventions, branch strategy, breaking-change rules |
| §7 | _Open_ | Operations — backups, restore, point-in-time recovery, compression-policy tuning |

## §1 — What this is

`gridworks-data` (module `gw_data`) is the **single source of truth for
the GridWorks postgres database**: schema definitions, alembic
migrations, the role-grant model, and a thin SQLAlchemy mapping that
application services import as a dependency.

It owns:

- The `gridworks` database itself.
- Three roles: `gw_admin` (full ownership, migrations only),
  `gw_writer` (insert/update/delete on tables; granted to app services),
  `gw_reader` (select-only; for analytics tools).
- 12 tables today: `alembic_version`, `connectivity_edges`, `customers`,
  `g_nodes`, `installations`, `installers`, `messages`,
  `position_points`, `reading_channels`, `readings`,
  `user_installation_roles`, `users`. See
  `src/gw_data/db/models/` for the authoritative definitions.
- TimescaleDB hypertable + compression policy on `readings` (2-week
  threshold, segmented by channel ID).

It does NOT own:

- Application logic that reads or writes the schema (lives in
  `gridworks-journalkeeper`, the LTN, etc.).
- Sema codec / message-type definitions (lives in `sema` + per-service
  `sema/types/`).
- Operational deployment of the postgres instance (Open §7).

## §2 — Central commitment

There is **one shared schema**, defined in one place (`gw_data`), and
every application service consumes it as a dependency. Application code
SHALL NOT define its own SQLAlchemy models for tables in this schema —
they import from `gw_data.db.models`.

The corollary (drives Stage 2 of the journalkeeper refactor): per-service
"models.py" files that mirror these tables are a code smell. Either the
service is wrong to have them, or `gw_data` is missing a table the
service legitimately needs — surface that gap explicitly and add it
here.

## §3 — Role in the GridWorks fleet

Consumers today:

- **gridworks-journalkeeper** — writes `messages` rows via
  `gw_data.db.models.MessageSql` (see
  `gridworks-journalkeeper/src/gjk/sema_message_persistor.py:6`).
- (Open) other services as they migrate off bespoke postgres deployments.

The dev/local pattern (one container, one database, multiple app users)
is documented in `README.md` of this repo and will be cross-linked from
the `wiki/dev-stack/` recipes once that domain exists.

## §4 — Cross-cutting invariants

1. **Primary keys are UUIDs**, stored as the DB-native UUID type.
2. **Date/time columns are `TIMESTAMPTZ`** — never naive timestamps.
3. **Each app gets a dedicated role** with the minimal privileges it
   needs. `postgres` is never used by app code; `gw_admin` is used only
   for migrations.
4. **Migrations are frequent and forward-only by default.** Schema is
   always temporary; treat alembic as the source of truth and the
   models as derived.
5. **TimescaleDB-specific features** (hypertable, compression) are
   declared in alembic migrations, not in the SQLAlchemy model
   metadata. (Open: codify this as a migration pattern.)
6. **Init scripts that prompt** (`0_server_init.psql` uses `\password`,
   `1_db_seed.py` uses `getpass()`) are documented as interactive in
   the README. For CI/automation, apply equivalent SQL with explicit
   passwords. (Open: provide a non-interactive bootstrap path.)
7. **DB URL form** is `postgresql+psycopg://<user>:<pw>@<host>:<port>/gridworks`
   using the psycopg3 driver (not psycopg2).

## §5 — Schema reference (Open)

Until this section exists, the canonical reference is
`src/gw_data/db/models/__init__.py` and the per-table modules beside it.
Notable today:

- `MessageSql` (`message.py`) — `(id UUID, timestamp, from_alias,
  created_at, persisted_at, message_type_name, payload jsonb)` with
  primary key `(id, timestamp)` and indexes on
  `(from_alias, message_type_name, persisted_at)` + `timestamp`.
- `ReadingChannelSql` (`reading_channel.py`) — `(id UUID, name,
  terminal_asset_alias, display_name, unit, unit_type, channel_type,
  deactivated_date)`. Note: schema differs from the legacy
  `gridworks-journalkeeper/src/gjk/models/data_channel.py`
  (`DataChannelSql`) — `about_node_name`, `captured_by_node_name`,
  `telemetry_name`, `start_s`, `in_power_metering` do not survive here.
  Open: are those fields needed and missing, or genuinely obsolete?

## §6 — Migration workflow (Open)

For now, `uv run alembic upgrade head` after `uv sync` and a populated
`.env`. Migration authoring conventions, branching strategy, and
breaking-change rules: not yet written.

## §7 — Operations (Open)

Deployment of the postgres instance (image, backups, restore,
compression-job tuning): not yet documented here. Today the only
guidance is the README's local-docker recipe.

## Glossary

- **gw_admin / gw_writer / gw_reader** — the three postgres roles; see
  `src/gw_data/db/scripts/0_server_init.psql`.
- **hypertable** — TimescaleDB concept; a table partitioned on a time
  column into chunks. `readings` is the only hypertable today.
- **chunk** — a TimescaleDB partition of a hypertable, covering a
  specific time range; can be individually compressed.
- **MessageSql / ReadingChannelSql / etc.** — SQLAlchemy mapped classes
  in `gw_data.db.models`; these names are the wire between this repo
  and consumers.
