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

1. Sema word-gate reading (spec + type-kind spokes, summary, wait), then
   author the bumps + staging rebinds; regen; suite green; promote.
2. gnr: migration (shape + FK + bootstrap rows), snapshot regen,
   forest/002 emission; `ci.sh`.
3. gjk: snapshot regen, drop table + FK, simplify the fan-out; suite.
4. Re-run the dev-rig forest round-trip as the wire check.

Sequencing: land the in-flight OPS-443 branches (`jm/forest-send-time`,
`jm/forest-snapshot`) first — the gjk fan-out this touches lives there.
Implementation gate: no code-repo edits until this design is Accepted at
Pass ≥ 1.
