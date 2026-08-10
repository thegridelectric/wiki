# Position-point lifecycle + the g.node.gt/006 sweep

Status: Accepted · Pass 1 · Updated 2026-08-06 · Linear: OPS-488

**EDD: no** schema/word migration; verified by the sema suite + registry
validation, the gnr/gjk suites, and a re-run of the dev-rig forest
round-trip (the OPS-443 rig), not a standalone real-world experiment.

> What this is: position-point presence becomes an **activation** invariant
> instead of a creation invariant; gnr's location store takes its
> encrypted-coordinate shape and a real FK; gw_data sheds its
> position-point projection; and the `g.node.gt` referrers are swept once,
> with the forest bump also making `SendTimeMs` required. The decisions
> behind this (encrypted column in gnr, ciphertext never on the bus, the
> pending-first flow) live in
> `wiki/grid-node-registry/explorations/positions-staging-and-encryption.md`
> "Settled direction".

## The word changes (sema)

1. **`g.node.gt/006`** — axiom 2 (*PhysicalGNodeLocations*) becomes:
   "If Status is Active and BaseClass != Logical, PositionPointId SHALL
   NOT be null." A Pending physical GNode may be locationless; Scada and
   forecasting services are `BaseClass = Logical` and were never
   constrained. This ends the registrar's mint-a-UUID-at-creation
   ceremony — a non-null id will mean a `position_points` row exists.
2. **`g.node.forest/002`** — rebinds to `g.node.gt:006` AND makes
   `SendTimeMs` **required**: gnr is the sole emitter and stamps at every
   assembly site (`src/gnr/db/authority.py`), so no unstamped 002 can
   exist. Absorbed from the sender-time design (OPS-472), which keeps the
   fleet-wide naming convergence.
3. **`g.node.create.cmd/001`** — rebinds, and adds the pending-first
   axiom: the carried node SHALL have a null `PositionPointId` (ids exist
   only when a `position_points` row does; creation never mints one).
   Verify at authoring what /000 already constrains about the carried
   node's `Status`. **`g.node.reparent.cmd/002`** — rebind only.
4. **Staging referrers rebind in place** (mutable tier, no bumps):
   `gw.house0.layout/000`, `gw.house0.operational.params/000`,
   `gw.nolan.layout/000`.
5. **Untouched:** `fis.authority.manifest/000` (draft tier, pins
   `g.node.gt:004`; rebinds at its own pace) and `position.point.gt/000`
   (published plaintext-microdegrees word — an encrypted-coordinate word
   belongs to the ingest design, not here).

Regen expectations (known cascade behavior): versionless class refs rebind
and old versions gain explicit `XxxNNN` classes; new-version axiom
validators regen as stubs to port; runtime-test version assertions update;
`created` timestamps are real wall-clock rounded to 5 minutes.

## gnr

- `position_points` drops `latitude_micro_deg`/`longitude_micro_deg` for
  **nullable ciphertext + `key_id` + `alg`** columns — substrate-neutral,
  so the pgcrypto-vs-KMS choice stays open without blocking this.
- `g_nodes.position_point_id` becomes a **nullable FK** into
  `position_points`.
- **Bootstrap migration:** mint an identity row for every
  `position_point_id` already carried by a `g_nodes` row — the existing
  Active fleet stays FK-valid and satisfies the new axiom. An identity
  row holds nothing but the id: the ciphertext columns are NULL because
  no coordinates exist anywhere yet to encrypt (absence, not plaintext).
  It means "location identity registered, coordinates pending"; the
  TaValidator flow fills the ciphertext later.
- **Accepted consequence:** with creation strictly locationless, a NEW
  physical GNode cannot go Active until the HTTPS ciphertext-ingest
  surface exists (deliberate — the surface is small and comes with the
  TaValidator design; the existing fleet is unaffected via the bootstrap
  rows).
- `dev_universe.py` seeding writes the store directly (not via
  create.cmd) and already models the posture — willow Pending with a
  staged id, positions inserted before nodes so FKs resolve; the seeder's
  position rows move to the new shape with the migration.
- Forest assembly and the read API move to emitting `g.node.forest/002`.

## gjk / gw_data

- Drop `gw_data.position_points` and the FK on `g_nodes`; the forest
  fan-out stores the opaque id **verbatim** — today
  `g_node_forest_persistor.py` nulls every id because the FK target row
  can never exist, so the projection currently holds less than the forest
  carries.
- Vendored snapshot regen picks up `g.node.gt/006` + `g.node.forest/002`
  (+ the cmd bumps).
- **Coordinate with Joe before the drop.** The argument: keeping
  ciphertext out of the bus archives (which the ears make immutable) is
  what makes a private-key leak harmless on its own; gw_data therefore
  never holds position content, and an FK to a permanently empty table
  only degrades the projection.

## Not in scope

The mTLS HTTPS ciphertext-ingest surface, key management, and the
TaValidator registration flow (their own later design); the sender-time
naming convergence across other words (OPS-472); Kafka/scale concerns.

## Plan (execution order)

1. ✅ (2026-08-06, `jm/position-point-lifecycle`) Sema word-gate reading,
   then author the bumps + staging rebinds; regen; suite green (418
   passed). ✅ Promoted to **published** (hash pins) 2026-08-06 — by
   explicit decision ahead of the gw_data-side review: publishing
   unblocks the consumer-refresh cascade, and review disagreement, if
   any, arrives as new versions (the normal cost, accepted). Also landed: g.node.gt/006 extended description records the
   create.cmd/001 composition (activation requires holding a position
   point; a Pending node may hold one — registration and activation are
   separate acts on separate planes).
2. ✅ (2026-08-06, `jm/forest-send-time` @ `1c45d27` + the ci.sh cluster)
   gnr: migration (shape + FK + identity backfill; ran on the dev DB),
   snapshot regen, forest/002 emission, cli create sends no position id,
   dev seeder mints identity rows / willow born locationless; new `ci.sh`
   (ruff gate + one-time format sweep). Suite 58 passed. **Deployed to
   prod 2026-08-06** (main `a79193f`; migration verified on the box: 16
   identity rows backfilled, 0 orphans, FK present; public API serving
   forest/002 with SendTimeMs, nodes at 006).
3. ✅ (2026-08-06, gjk `jm/forest-snapshot` + gridworks-data
   `jm/position-point-lifecycle`) gjk: snapshot regen, `persist_v002`,
   fan-out stores the opaque id verbatim, pin `gw_data>=0.4.0` (local
   editable until 0.4.0 publishes — `uv run --no-sync`). gridworks-data
   0.4.0: `position_points` table + FK dropped (migration keeps the
   column), `PositionPointSql` and vendored `position.point.gt` removed,
   snapshot regen to 006. Suites green (gjk 31). Also folded into the
   pair (2026-08-06 evening): **`sent_at`** on `g_nodes` +
   `connectivity_edges` (same single 0.4.0 migration) and the
   projection's **do-not-regress guard** — a write whose send time is
   older than the row's stored one is skipped, equal passes (replay
   idempotency); integration-tested (stale forest cannot revert a newer
   alias). Satisfies OPS-386 item 5 precondition #2 (the sender-time
   consumer guard).
4. ✅ (2026-08-06) Dev-rig re-run on current code, all four legs PASS:
   bootstrap 28/28 via the forest/002 API (willow locationless);
   MarketMaker re-parent → broadcast 002/006, projection re-aliased with
   verbatim position ids, `created_at == SendTimeMs` exactly, ear slice
   captured cmd + ack + forest; snapshot healed a corrupted row.
   (Reproducer in `experiments/2026-08-05-registry-projection-rig/`
   needs its one-line `DEV_POSITION_ID` rename + an 08-06 note —
   deferred, the folder is under another session's claim.)
5. **After `sema promote`: refresh the other g.node.gt consumers.** Every
   repo carrying the word re-vendors or re-validates at its own pace —
   known carriers beyond gnr/gjk: **gridworks-scada** (gwsproto's
   hand-written `GNodeGt` — update by hand, prove with `sema validate`
   per the scada protocol) and **gridworks-terminalasset** (vendored
   snapshot + `g.node.gt.json` identity files), plus any service reading
   a `g.node.gt.json` (gwbase-actor identity files decode 005 fine — old
   versions stay decodable; refresh when each repo next regens). Sweep
   the umbrella for vendored `g.node.gt` copies at promote time rather
   than trusting this list.

Sequencing: land the in-flight OPS-443 branches (`jm/forest-send-time`,
`jm/forest-snapshot`) first — the gjk fan-out this touches lives there.
Implementation gate: no code-repo edits until this design is Accepted at
Pass ≥ 1.

## PR-notes drafts (Jessica's to edit; delete after posting)

Both branches: `jm/remove-position-point-pii`. Review together.

**gridworks-data — opening (ownership stance):**

> The registry tables in gw_data (g_nodes, connectivity_edges) are
> projections of registry state: the grid node registry is the authority
> on topology and location, the audit trail lives in the persistent
> store, and these tables carry current state for analytics. 
> Home coordinates are resident-physical-security data. They will
> only ever exist encrypted, in the registry's own store, and the
> ciphertext stays off the bus deliberately: the ears archive the bus
> immutably, so an archived ciphertext could never be retired by a key
> rotation. So no position content, plaintext or encrypted, can ever
> legitimately reach these tables. A position_points table here is a
> slot nothing is ever allowed to fill. This PR removes the table and
> its foreign key, and keeps only the opaque position_point_id on
> g_nodes, a random identifier that joins fine and reveals nothing.

**gridworks-data — why not a database-native copy (preempts "sync it
from the seed"):**

> The obvious alternative is a database-native copy — logical
> replication from the registry's Postgres. It would be less code. We're
> not doing it because the registry is a trust boundary: nothing but gnr
> touches its database, the privacy property has to live in the
> interface (the forest word carries no coordinates, structurally)
> rather than in replication config, and DB-level sync couples our
> migrations to theirs — this very PR pair is deploying days apart
> precisely because the seam allows it. The registry's Postgres is also
> itself a projection of the command log, so a replica would copy the
> wrong layer of authority.

**gridworks-data — mechanics + blast radius:** PositionPointSql + FK
dropped; nullable `sent_at` (timestamptz) added to `g_nodes` +
`connectivity_edges` (the registry's SendTimeMs when the row's state was
asserted — per-row memory for gjk's do-not-regress guard); one migration
`c3e8f1a9d2b7` carries all of it (constraint + table out, id column
kept, sent_at in); snapshot regen (g.node.gt/006; position.point.gt no
longer vendored); version 0.4.0. web-backend pre-checked: imports
GNodeSql/InstallationSql/MessageSql/UserSql/UserInstallationRoleSql,
never PositionPointSql — 0.3.2 runs through the table drop untouched;
its eventual 0.4.0 bump is a no-op.

**gjk — opening (the mechanism, stated from the side that owns it):**

> gjk is the thing that projects what the registry says over rabbit into
> gw_data's registry tables. This PR moves that projection to the
> registry's current interface (g.node.gt/006, g.node.forest/002,
> already live in prod) and stores the opaque position_point_id
> verbatim, per the paired gridworks-data PR.

**gjk — evidence + deploy notes:** suite 31 green (incl. the
do-not-regress leg: an older forest cannot revert a newer row — the
bootstrap-vs-live race is dead; equal send times pass, so replays stay
idempotent); dev-rig end-to-end on current code (bootstrap 28/28 via the
read API, re-parent → re-aliased projection with verbatim ids,
created_at == SendTimeMs exact, ear slice capture, snapshot heal). Deploy order: `hack_reid_g_nodes.py --execute`
before the first live projection (alias-collision precondition,
dry-run-verified); then the journaldb migration; then restart + one-time
bootstrap. Lock note: "uv.lock still resolves gw-data 0.3.1 — 0.4.0
isn't on PyPI until the paired PR merges; a lock-refresh commit lands
here after publish, before merge."
