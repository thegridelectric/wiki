# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-fleet-index-service` code repo**. The matching git commit
holds the WHAT (the diff). Each entry's date and one-line title
mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-08-14 — Vendor the sema snapshot and build the schema (`5040613`)

Step 2. The vendored snapshot carries five words: the lease row
(`g.node.instance.gt/001`), the mirror's word (`g.node.gt`), the two
forest words the mirror seam consumes, and the connect claims the gate
will decode. Built with `--allow-staged`, so it is a **dev-only**
snapshot — two words are still staging, which is correct while the build
runs on `d1` and is the reason `fis.connect.claims` must publish before
the staging box serves `hw1__2`.

Three tables. `g_nodes` and `leases` are bijective with their words and
carry `to_gt`/`from_gt`; `principals` is hand-built because **no sema
word covers the principal model** — the registry was searched, not
assumed, and a `fis.principal.gt` word retires the hand-building along
with the two hand-coded enums beside it.

The single-writer invariant is a **partial unique index** on
(principal_id, run) where status is Active, not just care in the gate.
The gate's sync-kill supersession is what keeps it satisfiable; the index
is what makes a bug in that path fail loudly instead of quietly admitting
two writers. Tests prove all three faces of run-scoping: a second Active
lease on the same run is rejected, the same identity holds Active leases
on `hw1__1` and `hw1__2` at once, and a revoked row never blocks its
successor.

Alembic reads `FIS_DB_URL` from the same Settings the service uses, so
the connection string has one home. The compose Postgres is on 5437 —
5435 is gnr's and 5436 is already taken by weather-forecast.

## 2026-08-14 — Default to the dev universe (`0c1ebb8`)

`FIS_UNIVERSE` and `FIS_DB_URL` now default to `d1` and the local
Postgres, so a fresh clone runs in the dev universe with no `.env` at
all. Dev is where the build is exercised first — the whole done-when
battery runs on `d1__1` against the local broker before any remote box —
and a required-field wall in front of the primary workflow is friction
paid on every run to guard a case that only arises on a deployed box.

The deployed case is covered where deployment already is: a prod or
staging box has an `.env`, and provisioning writes it. Note this differs
from grid-node-registry, which defaults `db_url` but requires
`universe`; FIS is the service run locally far more often, so the
ergonomic default is worth more here.

The universe is still validated for shape and kind letter, so a
malformed value fails at boot rather than mirroring nothing.

## 2026-08-14 — Scaffold the service (`5f7bb51`)

Step 1 of the build: FastAPI + Postgres + `uv`, mirroring the
grid-node-registry stack so the two authority-plane services are one
shape to operate — same layout, same `ci.sh` gate, same
`pydantic-settings` pattern under the service's own `FIS_` prefix.

`universe` is validated at boot for shape and kind letter. A FIS
instance is scoped to one universe: its `g_node` mirror is a bijection
with one registry, and a registry serves exactly one universe. Runs
partition *inside* that scope — the lease key is (principal, run) — so
one FIS serves every run its broker hosts.

No sema consumer lines yet: the snapshot is vendored before the db
models land, which is the first code that means anything in sema terms.

## 2026-03-04 — Initial commit (`4686986`)

**What:** Repo genesis — `.gitignore` (standard Python ignore set),
`LICENSE`, and a 2-line `README.md`. No application code yet.

**Why:** Stands the `gridworks-fleet-index-service` repository up as an
empty scaffold so subsequent work has a home. Logged only to mark the
repo's starting point; the first substantive code commit will carry the
real *why*.
