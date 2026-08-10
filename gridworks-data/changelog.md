# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-data` code repo**. The matching git commit (in
`gridworks-data`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-08-06 — registry projection tables: drop position_points, add sent_at (`9eea2cc`)

One commit on `jm/remove-position-point-pii` (amended to fold both
changes into the single 0.4.0 migration `c3e8f1a9d2b7`); the sub-entries
keep the working narrative.

### sent_at on the registry projection tables

**What:** nullable `sent_at` (timestamptz) on `g_nodes` and
`connectivity_edges` — the registry's clock (the forest's `SendTimeMs`)
when the row's state was asserted.

**Why:** the per-row memory for the projection's do-not-regress guard
(gjk skips a write whose send time is older than what the row already
holds — the bootstrap-vs-live race and any out-of-order delivery). One
reviewed schema release instead of two back-to-back. (Precondition #2 of
the forest-projection deployment, OPS-386 item 5; the sender-time
design's consumer guard.)

### drop position_points: gw_data holds no position content

**What:** The `position_points` table
and the `g_nodes` FK go — the migration drops the constraint and the
table, keeping the opaque `position_point_id` column verbatim.
`PositionPointSql` and the vendored `position.point.gt` leave the
package; the snapshot regen also picks up `g.node.gt/006`. Version 0.4.0.

**Why:** gw_data is an analytics projection of the registry's bus
interface, and the bus never carries position content — plaintext never,
and ciphertext deliberately not either: the ears' immutable archives
would immortalize every ciphertext version, defeating key rotation, and
a leaked private key with no ciphertext to apply it to yields nothing.
No PII in the analytics database; authority is evident in the
gnr → gjk broadcast and code; the audit trail lives in the persistent
store. The projection keeps only the opaque id.
(Position-point-lifecycle design, OPS-488.)

## 2026-07-16 — Added UserInstallationRole to the index, and removed the lazy loading (#6) (`76cbccf`)

**What:** exports `UserInstallationRoleSql` from the models index; drops
the lazy-loading config on the relationship; 0.3.2. (Landed by PR
without an entry; backfilled from the diff.)

## 2026-07-01 — Support for importing and for hourly data calculation at the DB level (#5) (`0b7ba26`)

**What:** DB-level import support + hourly-data calculation (cached
hourly refresh scripts, visualizer-facing). (Landed by PR without an
entry; backfilled from the diff's shape — see the commit for detail.)

---

## 2026-06-07 — Add Release workflow to publish gw_data to PyPI (`0a41d0c`, merged `29194a1` / PR #4)

**Why:** gw_data had no publish pipeline and had never been on PyPI —
the only consumer (gridworks-journalkeeper) pulled it via a local
`[tool.uv.sources]` path (`../gridworks-data`), which works on a dev
machine but breaks journalkeeper's CI (`uv sync --locked` finds no
sibling checkout). To let downstream repos resolve `gw_data` from PyPI,
we need it published. This adds `.github/workflows/release.yml`, modeled
on gridworks-base's release workflow but trimmed to the PyPI path only
(no TestPyPI dev-release, no release-drafter): on a push to `main`,
`salsify/detect-and-tag` compares the pyproject version against existing
git tags and — only when the version is new — tags `vX.Y.Z`, builds, and
`uv publish`es to PyPI. Requires one repo secret, `PYPI_TOKEN`. First
publish (0.3.0) landed at https://pypi.org/project/gw-data/.

## 2026-06-05 — Bump version to 0.3.0

**Why:** Cut the first published release. 0.3.0 carries the prod-schema
changes below and is the first version pushed to PyPI, so downstream
repos can depend on `gw_data>=0.3.0` instead of a local path source.

## 2026-06-04 — Prod changes: private `gridworks` schema, `tsdb` database, superuser-free setup

**Why:** Make gw_data deployable on a managed Tiger Cloud instance (and
align local dev with prod). Three coupled changes:

- **Private schema.** All tables, enums, indexes, FKs, and the alembic
  version table move from `public` to a dedicated `gridworks` schema
  (`Base.metadata = MetaData(schema="gridworks")`; `alembic/env.py` gains
  `version_table_schema` + an `include_name` filter so autogenerate only
  tracks our schema; the initial migration is rewritten fully
  schema-qualified, with enums marked `inherit_schema=True`). Keeps our
  objects out of `public` on a shared managed server. New migration
  revision `1220f2f941dd` supersedes `fa719a767a1e`.
- **`tsdb` database.** The target DB is renamed `gridworks` → `tsdb`
  (Tiger Cloud's default database name), so the same connection string
  shape works locally and managed.
- **Superuser-free setup.** The single interactive `0_server_init.psql`
  is split into a numbered sequence runnable without superuser: a
  local-only `0_db_create`, then `1_db_user_setup` /
  `2_db_schema_setup` / `3_db_alembic_upgrade.sh` / `4_db_seed` that run
  as `gw_admin` (or Tiger Cloud's `tsdbadmin`). Roles are renamed by
  consumer: `gw_writer` → `gw_journalkeeper`, `gw_reader` →
  `gw_visualizer`. README rewritten to cover both local and Tiger Cloud.

## 2026-05-23 — README: clarify postgres setup walkthrough

**Why:** First end-to-end walkthrough of the setup (during the
gridworks-journalkeeper → base 0.4.2 refactor) exposed several friction
points that stopped a fresh reader cold: typo'd IP and script
filename; no concrete `docker run` example; the two interactive
prompts (`\password` in `0_server_init.psql`, `getpass` in
`1_db_seed.py`) were undocumented and broke `psql -f` / piped
execution; only `gw_admin` was mentioned even though the script also
creates `gw_writer` and `gw_reader`; no verify step and no enumeration
of what `alembic upgrade head` produces. The edits replace abstract
instructions with the concrete commands that actually worked, and
hoist Docker/psql/Python prereqs into a single block so the reader
isn't reverse-engineering them from §1/§2.
