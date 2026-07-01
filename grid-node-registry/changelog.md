# Changelog

A reverse-chronological log of WHY we made each commit **in the
`grid-node-registry` code repo**. The matching git commit holds the WHAT
(the diff). Each entry's date and one-line title mirror the corresponding
code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki repo's
git history.

Newest at the top.

---

## 2026-06-30 — Harness Layer 2: rabbit re-parent loop over a real broker (the EDD experiment) (`80694ef`)

**What:** added `tests/test_layer2_rabbit.py` (the EDD experiment — boot
`GnrRabbit` + a MarketMaker `Orchestrator` stub on a real RabbitMQ, seed the dev
universe into a real Postgres, publish a `g.node.reparent.cmd` **as a MarketMaker**,
and assert the `g.node.topology.broadcast` returns to a real subscriber **and** the
DB reflects the recursive beech-subtree rewrite). Extended `tests/conftest.py` with
the `rabbit_url` fixture (testcontainers `rabbitmq:3.13` by default; `GNR_TEST_RABBIT_URL`
opt-in; self-skip) and an autouse XDG-under-tmp redirect so the gwbase actors' loggers
stay out of `$HOME`. Added the `rabbitmq` testcontainers extra. The test provisions
the gwbase broker fabric from `gwbase.topology` (the `MarketMaker ⇄ GridNodeRegistry`
routing edges + the `gnr_tx`/`gnrmic_tx` pair are already in 0.5.3).

**Why:** the test-harness spoke's Layer 2 — the experiment that proves the whole
step-5 rabbit write loop end to end against reality (a real broker + the atomic
recursive subtree rewrite, the failure mode in-process mocks can't see). **Verified:**
green on a testcontainers RabbitMQ (~6.7s) and again via the `GNR_TEST_RABBIT_URL`
opt-in against the shared `gw-dev-rabbit` on its `d1__1` vhost (~0.55s); full suite
22 passed, unit-only deselects the 5 integration tests.

## 2026-06-30 — Harness Layer 1: AuthoritySource against a real Postgres (`7023969`)

**What:** added `tests/conftest.py` (the harness Postgres fixtures —
testcontainers `postgres:16` by default, an already-running Postgres via
`GNR_TEST_PG_URL` opt-in, self-skip when neither is available; schema via
`Base.metadata.create_all`) and `tests/test_layer1_postgres.py` (the `integration`
tier: seed the `d1` dev universe, assert `validate_registry`-clean, reads resolve
through `PostgresAuthority`, a re-parent of the beech home rewrites its whole
subtree — aliases + edges + ledger — atomically and leaves the registry valid,
and a generated-alias self-collision aborts the whole mutation). Added
`testcontainers[postgres]` to the dev group.

**Why:** the test-harness spoke's Layer 1 — the cheap, broker-free integration
tier beneath the Layer-2 rabbit experiment. Proves the seeded `AuthoritySource`
re-parent against a real Postgres (mocks pass where the atomic recursive subtree
rewrite fails). **Verified:** 4 integration tests green on a testcontainers
Postgres and again via the `GNR_TEST_PG_URL` opt-in against the dev-compose
Postgres on 5435; full suite 21 passed, unit-only run deselects the 4.

## 2026-06-30 — Depend on published gridworks-base 0.5.3 (drop editable path) (`39ffcd5`)

**What (planned):** in `pyproject.toml`, `gridworks-base` → `gridworks-base>=0.5.3`
and removed the `[tool.uv.sources]` editable path to `../gridworks-base`; relocked.

**Why:** the `GridNodeRegistry` transport class merged to gridworks-base `dev`/`main`
(PR #159) and published to PyPI as **0.5.3**, so gnr no longer needs the local
editable checkout — it must not ship depending on a path. **Verified:** `uv sync`
resolves 0.5.3 from PyPI, `GnrRabbit` imports, unit suite green (17).

## 2026-06-29 — Add rabbit transport adapter (GnrRabbit) (`1850f90`)

**What (planned):** `src/gnr/gnr_rabbit.py` — `GnrRabbit`, a thin gwbase
`Orchestrator` (transport class `GridNodeRegistry`) wrapping `AuthoritySource`:
`process_message` decodes a `g.node.reparent.cmd`, calls `apply_reparent`, and
broadcasts the resulting `g.node.topology.broadcast` on the registry's mic
exchange. Added `gridworks-base` as a dependency (editable path to the sibling
`../gridworks-base` so it carries the new `GridNodeRegistry` class).

**Why:** the design's rabbit adapter — one of the two thin transports over the
handler core (build step 5). First cut is the write loop (command in → broadcast
out); the read request/reply surface lands with its Sema request types. **Verified
so far:** imports + constructs against the branched gwbase; the live boot-and-
broadcast proof is harness Layer 2 (next). The read surface + the live Layer-2
experiment are the remaining step-5/6 work.

## 2026-06-29 — Dev-universe seed (mirror the fleet into d1) (`fcefa9d`)

**What (planned):** `src/gnr/dev_universe.py` — `build_dev_universe()` /
`seed_dev_universe(session)`: the copper-backbone parent chain
(`d1` · `d1.isone` MM · `d1.isone.me` CN · `d1.isone.me.versant` CN ·
`d1.isone.me.versant.keene` MM) plus each deployed home's LTN/Scada/TerminalAsset
read from sibling `tlayouts/output/*.uploaded.json`, re-aliased `hw1 → d1`, with
fresh GNodeIds and a shared placeholder PositionPoint, seeded with covering edges.
The `fir` layout lacks an LTN block, so its LTN alias is derived from the Scada
alias. Path overridable via `GNR_TLAYOUTS_DIR`.

**Why:** the dev-universe substrate for the harness (test-harness spoke) — a
production-shaped registry that never touches real money. **Verified:** seeds a
clean `validate_registry` against live Postgres.

## 2026-06-29 — DB-free unit tests + pytest setup (`99ca7e8`)

**What (planned):** added `pytest` (dev group) + `[tool.pytest.ini_options]`
(testpaths, an `integration` marker for the future DB/broker layers) and a
`tests/` suite that needs no infra — `test_g_node_naming.py` (axiom 5: `.ta`/`.scada`
suffix iff), `test_class_hierarchy.py` (CopperNode backbone, LTN/TA/Scada parent
rules), `test_reparent_rewrite.py` (the pure recursive prefix-rewrite). Extracted
the rewrite's pure core (`in_subtree`/`rewrite_alias`/`moved_child_new_prefix`/
`subtree_rewrite_map`) out of the session-coupled path in `authority.py` so it is
unit-testable.

**Why:** start the Layer-0 (unit, no-DB) tier of the dev-universe harness; the
naming + copper-sub-tree + reparent logic are pure and worth pinning before the
Postgres/broker layers. **Verified:** `pytest` green (17 passed).

## 2026-06-29 — Enforce Scada parent + CopperNode; bidirectional CopperNode SM (`78fcd92`)

**What (planned):** `gnr.db.validate` — named the `{ConnectivityNode, MarketMaker}`
set **`COPPER_CLASSES`** ("CopperNode" = the copper-topology backbone) and added the
**Scada parent rule** (a `g_node_class == "Scada"`, Logical-classed node must parent
a LeafTransactiveNode). `gnr.db.lifecycle` — the `base_class` SM now allows
**ConnectivityNode ⇄ MarketMaker both directions** (a constraint is relieved → an MM
demotes to a CN), per legacy Update Axiom 5. Plus a universe note in `README.md`.

**Why:** the GNode class rules Jessica named — the copper sub-tree is parent-closed,
a Scada hangs off its home LTN, and a CopperNode can lose its market role when grid
constraints relax. The `.ta`/`.scada` suffixes are already per-row `g.node.gt`
axiom 5, so they are not re-checked here. **Verified:** the new unit tests +
the live-Postgres validator proof both green.

## 2026-06-29 — Add transport-agnostic AuthoritySource handler core (`ef5a705`)

**What (planned):** `src/gnr/db/authority.py` — the `AuthoritySource` interface
(read by id/alias, `assert_active`, `fetch_edges`, `apply_reparent`) + a
`PostgresAuthority` implementation over `SessionLocal`. Sema types in/out
(`GNodeGt`, `ConnectivityEdgeGt`, `GNodeReparentCmd` → `GNodeTopologyBroadcast`).
The re-parent applies the recursive descendant alias rewrite + edge retire/create
+ alias-ledger claims + lifecycle, all in one transaction, and returns the
topology broadcast.

**Why:** build step 5 — the registry's logic lives in one transport-agnostic core
(the design's "one core, two thin adapters"); the rabbit consumer + FastAPI façade
are thin adapters that translate messages → these handlers. Building the core
first keeps it provable against Postgres before any transport. **Verified:**
against live Postgres (read/assert/edges; a re-parent rewrites a subtree and emits
the broadcast).

## 2026-06-29 — Vendor g.node.reparent.cmd + g.node.topology.broadcast into the snapshot (`ad6ead0`)

**What:** added `g.node.reparent.cmd` + `g.node.topology.broadcast` to
`gnr_seed_request.yaml` `initial_targets.types` (committed `3cb21c9`) and rebuilt
the vendored Sema snapshot (`build_gnr_snapshot.sh`), regenerating `src/gnr/sema/`
with the two new types' runtime classes (`g_node_reparent_cmd.py`,
`g_node_topology_broadcast.py`) + samples.

**Why:** build step 5 — the registry's runtime needs to decode/encode the
re-parent command and the topology broadcast. The words were released in `sema`
(branch `jm/gnr-commands`) so the snapshot could include them. **Verified:**
snapshot round-trip OK on all 5 samples, and both new types decode + re-encode
identically through gnr's codec (`GNodeReparentCmd`, `GNodeTopologyBroadcast`).

**What:** Added `src/gnr/db/lifecycle.py` — `check_status_transition` /
`check_base_class_transition` plus their `Illegal*Transition` errors and the
`ALLOWED_STATUS_TRANSITIONS` / `ALLOWED_BASE_CLASS_TRANSITIONS` maps. Pure
functions over the enums (no DB), to be called by the step-5 write handlers
before applying a status/class change.

**Why:** build step 4 — managed lifecycle. The status SM is legacy
`g-node-factory` Update Axiom 3 (`Pending→Active`, `Active→{Suspended,
PermanentlyDeactivated}`, `Suspended→{Active, PermanentlyDeactivated}`,
`PermanentlyDeactivated` terminal; identity is a no-op). The `base_class` SM is
the one sanctioned constrained-mutable upgrade `ConnectivityNode → MarketMaker`
(a CTN gaining authority to re-parent its sub-topology). **Verified:** pure-move
checks plus a live-Postgres apply path — a legal `Pending→Active` persists, and
an illegal `Active→Pending` is rejected with the row left unchanged.

## 2026-06-29 — Add whole-registry structural validator (`b18db84`)

**What:** Added `src/gnr/db/validate.py` — `validate_registry(session)` plus the
`Violation` record and three checks: `check_parent_closed_active` (active
non-root ⇒ active alias-parent), `check_edge_coverage` (active non-root ⇒ exactly
one active edge from its alias-parent), and `check_class_hierarchy` (parent class
legal for the node's class). Topology is derived from the dotted alias
(`parent_alias`).

**Why:** these are the registry's row-spanning invariants Sema can't express
per-row (build step 3). The class-hierarchy check is the new-class form of legacy
`g-node-factory` Creation Axiom 5 (ROLE), with the mapping `ConductorTopologyNode
→ ConnectivityNode`, `AtomicTNode`/`AtomicMeteringNode → LeafTransactiveNode`,
`Scada`/`Other → Logical` (confirmed by the `base.g.node.class` value-
descriptions); enforcing it also yields "active physical subtree parent-closed."
`validate_registry` is the audit pass; the step-5 write handlers will run the
relevant check on the affected subtree at write time. **Verified:** a live-
Postgres scenario — a clean 5-node tree (root→MM→CTN→LTN→TA) passes, and a
suspended parent, a missing edge, a wrong-source extra edge, and a TerminalAsset
under a ConnectivityNode are each caught.

## 2026-06-29 — Add alias_assignment ledger enforcing alias-uniqueness-through-time (`8960b6f`)

**What:** Added `AliasAssignmentSql` (`alias` PRIMARY KEY, `g_node_id` FK,
`first_assigned_at`) in `src/gnr/db/models.py`, the `claim_alias` write primitive
+ `AliasAlreadyOwned` error in new `src/gnr/db/alias_ledger.py`, and the
autogenerated Alembic migration creating the table.

**Why:** `g_nodes.alias UNIQUE` enforces only *live* uniqueness — a rename frees
the old value in that row, so a different `GNodeId` could later claim a vacated
alias. The registry's core invariant is stronger: an alias, once held, is
**permanently owned** by that `GNodeId` and must never rebind to another (the
alias is the routing handle for money + physical grid control). The ledger's
`alias` PK makes that permanent; `claim_alias` does `INSERT … ON CONFLICT
(alias) DO NOTHING` then asserts ownership (race-free via the unique index), so
the three cases — new alias claimed, same owner re-acquiring, different owner
rejected — are enforced in the same transaction as the GNode write. Build
step 2 (ledger half) of OPS-419; status/edge change-history is still open.
**Verified:** a live-Postgres scenario (create → rename → a different `GNodeId`
rejected with `AliasAlreadyOwned`, the original owner re-acquires, bindings stay
permanent).

## 2026-06-29 — Stand up dev Postgres + initial schema; load .env (`685ab81`)

**What:** Brought the registry to a working dev Postgres with the schema
generated (standup build step 1). Renamed `gnr.config` → `gnr.settings` and
switched it to `SettingsConfigDict(env_file=".env")` so `Settings()` actually
reads `.env` (it previously had no `env_file`, silently falling back to the
hardcoded default URL). Added `gnr.db.session` (engine + `SessionLocal` from
`Settings`). Repointed `docker-compose.yaml` to publish host port **5435** and
fixed `template.env` to the `+psycopg` (v3) driver. Committed the autogenerated
initial Alembic migration (all three tables). Updated `README.md` (dev
quickstart + step 0 marked done) and `alembic/env.py`'s import.

**Why:** the standup design's step 1 was blocked by three real defects, not one:
(1) a stale `gnr_pgdata` volume meant Postgres skipped `initdb`, so the `gnr`
role was never created; (2) a host-local Postgres holds `localhost:5432` and
macOS prefers `::1`, shadowing the container's `5432:5432` publish — hence "role
gnr does not exist" from the host while `docker exec` worked; (3) `Settings`
never loaded `.env`, so alembic connected to the default `:5432` regardless. Fix
unblocks history tables, invariants, lifecycle, and the query surface — and the
registry is the source of truth FIS needs for the summer mTLS+FIS auth work
(OPS-419). **Verified:** a `GNodeGt` round-trips against the live DB
(`gt → from_gt → commit → fresh-session → to_gt`, identical bytes); the sema
snapshot self-check stays green.

## 2026-06-28 — Drop vendored sema README; remove its rsync exclude (`77c876a`)

**What:** Removed `src/gnr/sema/README.md` (stale "Sema Module" boilerplate with
already-done integration steps) and dropped the now-unneeded `--exclude='README.md'`
from `build_gnr_snapshot.sh`.

**Why:** the snapshot's provenance lives in `build_gnr_snapshot.sh` +
`gnr_seed_request.yaml` + the design; a hand-written doc inside a regenerated tree
just rots. Decided with the OPS-419 open-question cleanup.

## 2026-06-28 — Reconcile to ids-only connectivity edges + regenerate snapshot (`ae3be8f`)

**What:** Regenerated the vendored Sema snapshot against the edited
`connectivity.edge.gt` (alias fields dropped) and `position.point.gt`, and dropped
the `from_g_node_alias` / `to_g_node_alias` columns and their `to_gt`/`from_gt`
references from `ConnectivityEdgeSql` (`src/gnr/db/models.py`). Imports clean;
snapshot round-trip green.

**Why:** the standup grill ([OPS-419](https://linear.app/gridworks/issue/OPS-419))
settled that edges store **immutable ids only** — alias is derived on read, so a
rename touches zero edges. Mirrors the matching sema edit (see `wiki/sema/changelog.md`).

## 2026-06-27 — Regenerate gnr Sema snapshot off sim-vocab (g.node.gt v004); add seed request + build script (`8402df2`)

**What:** Regenerated the vendored `src/gnr/sema/` snapshot from the sema
repo's `jm/sim-vocab` branch, and added the reproducible regen path:
`gnr_seed_request.yaml` (targets `g.node.gt` · `connectivity.edge.gt` ·
`position.point.gt`; enums by closure) + `build_gnr_snapshot.sh` (drives
`sema snapshot prepare|build --package-name gnr`, rsyncs `output/sema/`
into `src/gnr/sema/`). `g.node.gt` is now **v004**: `GNodeClass` changed
from a closed enum to an axiom-governed open `str`, so the `g.node.class`
enum word dropped out of the closure. The snapshot is now self-describing —
it gained vendored `definitions/`, `indexes/`, `samples/`, `roundtrip.py`.

**Why:** The vendored snapshot dated to Feb and sema's vocabulary had moved
substantially since. Regenerating gives a clean baseline to build the
registry against, and checking in the seed request + build script settles
the "how does the vendored snapshot stay in sync" question (the gwta
pattern, homed in the consumer so the only sema-side write is its gitignored
scratch). Verified: the snapshot round-trip gate passed (3 samples), the
`gnr.sema` package imports cleanly, and no repo code referenced the dropped
enum. To redo once sema settles on `dev`.
