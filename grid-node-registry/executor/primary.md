# grid-node-registry — spec (primary)

Status: Draft · Pass 0 · Updated 2026-06-28

> What this is: the faithful spec of the **Grid Node Registry** (`gnr`) — the
> authoritative record of GridWorks GNodes, their geographic positions, and the
> connectivity (parent/child) edges between them. It is the registry the **Fleet
> Index Service (FIS)** consults to authorize a GNode runtime instance. Current
> state plus the intended invariants; the standup plan is the
> `stand-up-grid-node-registry` design (Linear [OPS-419](https://linear.app/gridworks/issue/OPS-419)).

## What it is

A Postgres-backed service (`grid-node-registry` repo, `src/gnr`). Every SQL row
is a serialized **Sema GT** snapshot; the Sema `gt` types validate (via the
codec) before any insert/update. Three entities (`src/gnr/db/models.py`):

| Table | GT type | Holds |
|---|---|---|
| `g_nodes` | `GNodeGt` | a GNode: `id` (GNodeId), unique `alias` (LeftRightDot), `prev_alias`, `base_class`, `g_node_class`, `status`, optional `position_point_id`, `display_name` |
| `position_points` | `PositionPointGt` | a geographic point: `latitude_micro_deg`, `longitude_micro_deg` (**immutable**; see Mutability model) |
| `connectivity_edges` | `ConnectivityEdgeGt` | a parent→child edge keyed on **immutable ids only**: `from/to_g_node_id` (FK), `status`; unique `(from, to)`. Aliases are **derived on read**, not stored |

Enums (`src/gnr/sema/enums`): **`BaseGNodeClass`** (`ConnectivityNode` /
`MarketMaker` / `Logical` / …) and **`GNodeStatus`**. As of `g.node.gt` v004,
**`GNodeClass` is no longer an enum** — it is an axiom-governed open `str`
(so the open namespace of classes — `TerminalAsset`, `Scada`, … — needn't bump
an enum), held consistent with `base_class` and `alias` by the GT axioms below.

## Universes

A **universe** is the first dotted segment of a GNodeAlias, and its **kind** is
that segment's first letter: **`d`** = dev, **`h`** = hybrid, **`w`** =
production. There are **many** dev/hybrid universes (`d1`, `d2`, `hw1`, …) but
exactly **one** production universe — the only place GridWorks MarketMakers
manage real money. So `universe_of(alias) = alias.split(".")[0]`, and "is this
real money?" ⇔ "is the universe the single production one?" (The full guardrail —
a GNode may only talk on a broker in its own universe, the broker host/vhost
encoding that universe, and the dev rabbit `gw-dev-rabbit` serving `d1__1` on
localhost — lives in the scada `hardware-layout-pass-one` design; what binds
*here* is that every alias the registry holds carries its universe in segment 0.)

A registry instance is **scoped to one universe**: a dev registry holds the `d1`
tree, the production registry holds the `w` tree. This is what lets a **dev
universe** mirror production — the same GNode topology re-aliased into `d1.*` —
without ever touching real money. The test harness (see the standup design) is
exactly such a dev universe: the deployed systems (`hw1.isone.me.versant.keene.*`)
and the parent GNodes they require, re-aliased into `d1`.

**The universe segment is a namespace, not a GNode.** `d1` (the bare universe
token) is **not** a GNode — it is the namespace the registry is scoped to. So the
registry holds a **forest of copper subtrees**, not one rooted tree: the forest
roots are the **top-level copper nodes** (a top-level MarketMaker like `d1.isone`,
whose alias-parent is the bare universe token). This is the natural shape — the
world was only ever a forest of copper subtrees, and a single `Logical` "world
root" GNode was an artifact of forcing it into one tree. A GNode is a **forest
root** iff its alias-parent is the bare universe segment (there is no GNode there).
Consequently `Logical` narrows to what it means — Scada + logical controllers — and
never labels a universe root.

## Per-row Sema axioms (`g.node.gt` v004)

The `GNodeGt` codec enforces five axioms on every row before insert/update:

1. **ClassConsistency** — if `base_class ≠ Logical`, `g_node_class` equals the
   `base_class` value; if `Logical`, `g_node_class` is not any other
   `base.g.node.class` value.
2. **PhysicalGNodeLocations** — `base_class ≠ Logical` ⇒ `position_point_id`
   is not null.
3. **AliasTransitionConsistency** — `prev_alias`, when present, differs from
   `alias`.
4. **GNodeClassNamespacing** — `g_node_class` is non-empty and whitespace-free.
5. **AliasSuffixSemantics** — `alias` ends with `.ta` iff `g_node_class` is
   `TerminalAsset`; ends with `.scada` iff `Scada`.

## Mutability & change model

What is fixed vs. what changes, and how:

- **`GNodeId` — immutable.** The durable identity for messaging, auth, and the
  FIS single-writer lease. The fleet routes by *alias* (`gwbase`
  `transport_encoding`), but identity is the id; this split is what makes a
  rename survivable.
- **`alias` — mutable** via the re-parent operation (recursive **atomic** subtree
  rewrite, one transaction; old value → `prev_alias`, recorded append-only). A
  rename touches only the renamed GNode rows + the structural edges of the actual
  re-parent — **never** edges merely because an endpoint was renamed (edges store
  ids, not aliases).
- **`base_class` + `g_node_class` — constrained-mutable in lockstep.** A
  `ConnectivityNode` MAY become a `MarketMaker` (gaining authority to re-parent its
  sub-topology) when a copper-topology shift becomes a known constraint. Axiom 1
  binds the two, so both change together. A small allowed-transition SM, not a free
  edit.
- **`status` — mutable** per the lifecycle SM below.
- **`PositionPoint` — immutable.** Location anchors the TaDeed / TaTradingRights,
  so it is not edited in place. A location change is a heavyweight **TaValidator
  re-certification** (a new validated `GNodeGt`, audited, with a validator-reputation
  consequence) — that machinery is downstream (the TaDeed/validator plane), not the
  registry's. The type guarantees accuracy by **definition** (a point SHALL fall
  within the footprint of the building it locates); recorded per-fix accuracy (R95)
  is deferred to the TaValidator/deed work (substrate-fit, OPS-391). **The registry
  enforces *nothing* about a position beyond per-row presence (axiom 2)** — no
  distinctness, no accuracy, no premises/PCC boundary; location *trust* is
  TaValidation's job, and residential topology is trusted-by-description. The
  reasoning (and the deferred CIM `ServiceLocation`/`ServiceDeliveryPoint` option)
  is in [`../explorations/position-point-semantics.md`](../explorations/position-point-semantics.md).
- **`position_point_id` is an opaque location *identity*, not an FK.** It is a
  random `UUID4Str` carried in the command (satisfies axiom 2, deterministic-by-record,
  leaks nothing — never derived from the coordinates). The **coordinate data** is a
  separate, later, encrypted, **TaValidator-owned** artifact — so `g_nodes.position_point_id`
  is a plain column, **not** a foreign key into `position_points`. This is what lets the
  MVP **populate `g_nodes` with an open API while `position_points` stays empty +
  private**: topology open, geography behind an opaque id, encrypted when TaValidator
  populates it. Plan (encryption at rest + asymmetric app-encryption, gnr write-only;
  the `position_points` shape change; DB-column vs vault) in
  [`../explorations/positions-staging-and-encryption.md`](../explorations/positions-staging-and-encryption.md).

## Write path & egress

`gnr` is the sole accessor of the backing store; all access goes through a
transport-agnostic handler core (the `AuthoritySource` interface). **Writes ride
rabbit** (a MarketMaker is a fleet bus citizen; the change event is genuinely
pub/sub); **reads ride an HTTP/FastAPI façade** (point/forest queries — internal
service API, no mTLS, privacy by the network perimeter). This split is by traffic
shape, not by consumer.

**The write + its change event:**

- **`g.node.reparent.cmd`** — the write command: the new node `N` (a `g.node.gt`) +
  the moved child `GNodeId`s. The registry computes the recursive descendant alias
  rewrite and the edge retire/create set, and applies them in one transaction.
- **On commit the registry broadcasts a forest** of the affected subtree (see below).
  Best-effort (convergence is by authorization, not delivery).

**The forest — one payload, three uses.** A **forest** is a set of subtrees, each
rooted at one of a chosen set of nodes and carrying every descendant. It is the
**scaling unit**: the registry never moves the whole world in one message — it
addresses by root-set, so each message is bounded by that slice of topology (this is
what survives a million assets; heritage: legacy `basegnodes.broadcast` =
`TopGNode` + `DescendantGNodeList` + `IncludeAllDescendants`). A single **`g.node.forest`**
payload (`roots: [GNodeId]` + the subtree `g.node.gt`s with current aliases + the
`connectivity.edge.gt`s) is **reused** as:

1. the **change-delta broadcast** — the forest under the re-parented root(s);
2. a **snapshot broadcast** — a forest under the world root, **chunked** by root-set at
   scale (never one unbounded message);
3. the **API forest-response** to a **`g.node.forest.request`** (`roots: [GNodeId|Alias]`
   + an app-level `RequestId`) — a caller names a root-set and gets their forest back.

**FIS is a pure broadcast subscriber, scoped to its authority.** FIS is a
`ServiceSettings` bus tap (subscribing needs **no** transport class) that maintains an
in-memory `GNodeId ↔ alias` map, **event-sourced** from `g.node.forest` change
broadcasts. It bootstraps/resyncs with a **`g.node.forest.request` scoped to just the
subtrees it authorizes** (its MarketMakers/roots) — so each FIS holds a **bounded
slice**, not the whole fleet, and the million-asset case dissolves. Steady-state auth
is then an in-memory lookup fed over the mutually-authenticated mTLS bus — no separate
secure GNR→FIS channel to build, and no direct GNR→FIS message (the broadcast carries
the re-aliasing payload; a durable subscriber queue delivers it reliably). Provisioning
and analytics use the same `g.node.forest.request` over HTTP, scoped to what they need.

**Write authority = the authenticated connection.** A command arrives over an
mTLS+FIS-authenticated rabbit connection (principal = cert `CN=GNodeId`); the registry
authorizes by checking the principal's `base_class = MarketMaker` and that the
affected subtree is within its authority. A detached signed-command scheme stays
available via the `AuthoritySource` seam for a future distributed/on-chain authority.

## Distributed-readiness (keep the swap a swap, not a rewrite)

The registry's authority is meant to be **swappable** — a single-writer Postgres
today, a more distributed / on-chain authoritative record later (the Algorand-era
*cryptographic-veracity / distributed-trust* principle, without the Algorand
plumbing). Four properties keep that a swap behind the `AuthoritySource` seam. The
first two are **implemented** (`gnr.ids`, `gnr.db.models.CommandLogSql`,
`gnr.db.authority.apply_reparent`) and pay off now (reproducible state + free audit
history + replay safety), so they are not speculative:

1. **Deterministic mutation — ✅ done.** `apply(command)` is a pure
   `(state, command) → state'` — any consensus/replicated backend re-executes it on
   many validators that must agree byte-for-byte. So an id that lands in authoritative
   state is **either carried in the command** (submitter-assigned, frozen by the
   log/tx — e.g. a `GNodeId`, or a `position_point_id`) **or derived from inputs every
   validator holds** (public data — e.g. `gnr.ids.edge_id` from the two endpoint ids);
   it is **never handler-minted** (the old `uuid.uuid4()` edge id was that illegal
   third case) and **never derived from a secret** (deriving `position_point_id` from
   the coordinates would both leak the location *and* be unreproducible by validators
   who correctly can't see the encrypted plaintext). Edge ids serialize into
   `g.node.forest` (authoritative state); the whole dev universe is deterministic too
   (`gnr.ids.deterministic_uuid4`). `created_at` stays wall-clock — it is **not** in any
   Sema type, so it is local audit metadata, not authoritative state (full log-replay
   byte-identity would additionally want a command-carried logical time, deferred).
2. **The command log is the primitive; state is a projection — ✅ done.** A
   ledger/chain is an ordered log of signed commands with state derived from it. Every
   mutation is appended to an **append-only `command_log`** (`CommandLogSql`) in the
   same transaction as the state change, keyed by a **content hash** of the command's
   canonical bytes (`gnr.ids.command_hash`); the `g_nodes`/edge rows are a
   **materialized projection** rebuildable from the log. **The `alias_ledger` is not
   dropped — it is reframed:** it becomes one such projection (`alias → first-owner`)
   that *also* serves as the through-time uniqueness **enforcement index** (its `alias`
   PK is the race-free constraint). Idempotency is free: a command whose hash is
   already in the log is rejected (replay-safe). On-chain later = the log moves to the
   chain and the local Postgres becomes an **indexer**; the uniqueness invariant moves
   into consensus rules. **The content-address stays gnr-internal, NOT a Sema format:**
   transaction hashes are chain-specific (Algorand SHA-512/256/base32 vs Ethereum
   Keccak-256/hex), so the canonical public content-address is **machinery of the
   chosen chain**, adopted behind the seam later — see
   [`../explorations/content-address-and-deterministic-ids.md`](../explorations/content-address-and-deterministic-ids.md).
3. **Self-verifying commands + proof-carrying broadcasts.** A mutation is a
   **signed, self-describing Sema command** (an optional MarketMaker signature on
   `g.node.reparent.cmd`), and a `g.node.forest` broadcast carries a **proof** field
   (today gnr's signature as single authority; later a chain-inclusion proof).
   Consumers (FIS) verify a proof regardless of backend — the *same bytes* are
   verified-and-applied centrally today or submitted to a chain later.
4. **Reads are a projection, distinct from authority.** The read surface (forest
   queries, the FIS subscription) reads a **materialized projection** that could be
   rebuilt from the log/chain — it never reaches into the write backend's internals.
   Keep `read`/`subscribe` conceptually separate from `apply(command)` on
   `AuthoritySource`, so reads stay a local indexer even when authority moves off
   single-writer Postgres.

Not building the chain, a real signature scheme, or pure event-sourced state now —
these are **shape**, not machinery. #1–#3 fold into the forest rework; #4 is a
discipline on the interface.

## Lifecycle — `GNodeStatus`

```
Pending  → Active
Active   → {Suspended, PermanentlyDeactivated}
Suspended→ {Active, PermanentlyDeactivated}
PermanentlyDeactivated → (terminal)
```

Plus the constrained-mutable **`base_class`** SM: a **CopperNode** may switch
between its two forms **both directions** — **`ConnectivityNode ⇄ MarketMaker`**
(a copper constraint emerges → a local market is needed; the constraint is
relieved → it isn't); `g_node_class` moves in lockstep (per-row axiom 1). Both SMs live in
`gnr.db.lifecycle` (`check_status_transition` / `check_base_class_transition`,
grounded in legacy `g-node-factory` Update Axiom 3 + the role-change rule) — pure
functions the step-5 write handlers call before applying any status/class change,
rejecting an illegal move before the mutation commits. Identity transitions are
no-ops.

## Intended invariants (the registry's reason to exist)

Beyond per-row Sema validation, the registry MUST enforce structure Sema can't —
**not all are implemented yet** (see the standup design):

- **Alias uniqueness through time** — an alias, once held by a `GNodeId`, is
  **permanently owned by that `GNodeId`** and MUST NOT ever bind to a different
  one, even after the original node renames away from it. The binding
  `alias → GNodeId` is a function frozen the first time it is defined. This is
  stronger than live uniqueness and stronger than temporal-non-overlap: an alias
  is never recycled across identities. (Why: the alias is the routing/addressing
  handle for money and physical grid control, so a stale message, replayed
  command, historical reading, or TaDeed reference addressed to a recycled alias
  would silently bind the wrong physical entity.) Enforcement below.
- **Active GNode forest is parent-closed** — a **forest root** (alias-parent is the
  bare universe token, so no GNode parent) is a top; every **other** active GNode's
  alias-parent exists and is Active. The active *physical* subtree is parent-closed as
  a consequence of the class hierarchy below (physical classes only parent physical
  classes, up to a forest root).
- **ConnectivityEdge coverage** — for every active GNode `A` **that is not a forest
  root**, with parent `P`, the registry holds **exactly one** active edge
  `FromGNodeId = P, ToGNodeId = A` (no missing edge, no extra incoming edge, and the
  one edge is from the alias-parent). A **forest root has no incoming edge** (its
  alias-parent is the namespace, not a GNode). (The legacy "edge consistency"
  invariant — that an edge's ids and aliases agree — is **gone**: edges store ids
  only, so there is no stored alias to keep consistent.)
- **Class hierarchy** — each non-root GNode's parent class is legal for its own
  (the new-class form of legacy `g-node-factory` Creation Axiom 5 ROLE). A
  **CopperNode** is a `ConnectivityNode` or a `MarketMaker` — the copper-topology
  backbone (an MM is a CN that also runs a local market). The rules:
  - **CopperNode** (MM/CN) → it is a **forest root** (alias-parent is the bare
    universe token) or its parent is another CopperNode (the backbone is
    parent-closed; a top-level MarketMaker is a forest root);
  - **LeafTransactiveNode** → parent is a CopperNode;
  - **TerminalAsset** → parent is a LeafTransactiveNode (behind an atomic-metered
    point); its alias ends `.ta` (per-row axiom 5);
  - **Scada** (`g_node_class == "Scada"`, Logical base_class) → parent is a
    LeafTransactiveNode (its metered unit's controller); its alias ends `.scada`
    (per-row axiom 5);
  - other **Logical** → unconstrained.

  Legacy→new mapping: `ConductorTopologyNode → ConnectivityNode`,
  `AtomicTNode`/`AtomicMeteringNode → LeafTransactiveNode`, `Scada`/`Other → Logical`.

These three structural invariants are enforced by `gnr.db.validate` —
`validate_registry` runs the audit pass; the step-5 write handlers will run the
relevant check on the affected subtree at write time.

### Enforcing alias-uniqueness-through-time

`g_nodes.alias UNIQUE` enforces only *live* uniqueness — it cannot carry the
through-time invariant, because a rename legitimately frees the old value in that
row (X renames `A→B`, then a new Y taking `A` passes live-unique but violates the
invariant). The permanent binding lives in a **separate append-only ledger**:

```
alias_assignment(
    alias              TEXT PRIMARY KEY,             -- one owner per alias, forever
    g_node_id          UUID NOT NULL REFERENCES g_nodes(id),
    first_assigned_at  timestamptz NOT NULL
)
```

The `PRIMARY KEY (alias)` is the guarantee: at most one row per alias for all
time. Every create and every rename writes the new alias here **inside the same
transaction** as the GNode write, via `INSERT … ON CONFLICT (alias) DO NOTHING`
followed by an ownership assertion (the existing row's `g_node_id` MUST equal the
intended owner, else raise `AliasAlreadyOwned` and roll back the whole
transaction). The unique index serializes concurrent inserts, so this is
race-free with no app-level check-then-insert window. The three outcomes:
brand-new alias is claimed; the same owner re-acquiring its own former alias is
allowed; a *different* owner is rejected. A `BEFORE INSERT OR UPDATE OF alias`
trigger on `g_nodes` running the same check is recommended defense-in-depth —
gnr is the sole writer, but money + grid control warrant the belt-and-braces.

Two consequences for the write path:

- **Re-parent can self-collide.** The recursive subtree rewrite generates new
  aliases (`E.c… → E.N.c…`); if a generated alias equals one any *other* (even
  long-retired) node once owned, the ledger PK fires and the whole atomic
  re-parent aborts — correct, but a real operational failure mode. The re-parent
  handler SHALL pre-check the full target alias set against the ledger and fail
  with an explicit alias-collision error, not a raw constraint violation.
- **The ledger, not `prev_alias`, is the authority.** Every alias a node ever
  held gets a ledger row (the original at create, each new alias at rename), so
  the ledger answers the through-time question across arbitrarily many renames.
  `prev_alias` on the live row stays only as the one-hop-back parent-resolution
  aid. The ledger is naturally a **projection of the create/reparent command
  log**, so it slots into the `AuthoritySource` seam if authority ever moves off
  single-writer Postgres.

## Relationship to FIS

FIS authorizes GNode runtime instances against this registry: it enforces
**single-writer per `GNodeId`** and cross-checks the live instance against the
registry (FIS principal-model, Invariant #1). So the registry is the **source of
truth** for GNode identity/validity that FIS queries — which is why standing it
up (with a query interface) is a prerequisite for the mTLS+FIS auth work.

**They are separate services** (registry = slow-changing system of record,
swappable/on-chain later; FIS = hot-path per-connection authorizer holding lease
state). FIS **reads + caches** the registry over the **HTTP read façade** (`gnr.api`:
a `g.node.forest.request` scoped to its authority roots → a `g.node.forest`), and
**subscribes** to `g.node.forest` change broadcasts on the bus for cache invalidation
— it does not do rabbit request-reply.

**Convergence-by-authorization.** Because the cert/principal binds the **immutable
`GNodeId`** (not the alias), a node carrying a stale alias after a rename **cannot
be authorized**: FIS resolves cert→`GNodeId`, finds the current alias here, and
denies on mismatch. Recovery is by **provisioning redeploy** — provisioning (internal,
reads the registry) redeploys a renamed node with fresh config, triggered by the
broadcast; the FIS deny is the **backstop signal** (a missed node fails auth, which is
observable → triggers redeploy). The node never self-queries; it just gets redeployed
(~yearly, so a restart is fine). So broadcast delivery is best-effort, not
load-bearing, and the FIS deny needs no rich payload. The FIS-side contract
(cert-subject = `GNodeId`, alias-staleness check) lives in the mTLS+FIS auth work
(OPS-420 / OPS-422).

## Stack

Python 3.12, `uv`, `pydantic-settings` (`gnr.settings.Settings` ← `.env`),
SQLAlchemy + **Alembic** migrations, Postgres 16 (`docker-compose.yaml`). Logs to
`~/.local/state/gridworks/gnr/log/` (GridWorks convention).

## Current status (2026-06-28)

Models + Sema `gt` types + enums exist; the vendored Sema snapshot tracks sema
(`g.node.gt` v004), and the `connectivity.edge.gt` ids-only +
`position.point.gt` footprint/immutability edits have landed. **Build step 1 is
done:** a dev Postgres runs (`docker compose up`, host port **5435** — 5432 is
shadowed by a host-local Postgres on macOS), the initial Alembic migration
creates all three tables, and a `GNodeGt` round-trips against the live DB
(`gt → GNodeSql.from_gt → session → to_gt`, identical bytes back). `Settings`
now loads `.env` (it didn't before — `gnr.settings`, was `gnr.config`), and the
engine/session factory lives in `gnr.db.session`. **Build step 2 (partial):**
the `alias_assignment` ledger (`gnr.db.models.AliasAssignmentSql`, `alias` PK)
and its enforcement primitive `gnr.db.alias_ledger.claim_alias` have landed and
are proven against the live DB — a different `GNodeId` cannot claim a vacated
alias (`AliasAlreadyOwned`), the original owner may re-acquire it, and bindings
stay permanent. **Build step 3 (structural invariants done):**
`gnr.db.validate.validate_registry` is a whole-registry audit pass enforcing
**parent-closed active tree** (active non-root ⇒ active alias-parent),
**ConnectivityEdge coverage** (active non-root ⇒ exactly one active edge from its
alias-parent), and the **class-hierarchy** parent rule (the new-class form of
legacy Creation Axiom 5 — which also yields "active physical subtree
parent-closed"). All proven against live Postgres (clean 5-node tree passes; a
suspended parent, a missing edge, a wrong-source extra edge, and a
TerminalAsset under a ConnectivityNode are each caught). **Build step 4 done:**
`gnr.db.lifecycle` enforces the `GNodeStatus` SM and the `ConnectivityNode →
MarketMaker` `base_class` SM, proven against live Postgres (a legal Pending→Active
applies and persists; an illegal Active→Pending is rejected and the row is left
unchanged). **Build step 5 (handler core done):** `gnr.db.authority` — the
`AuthoritySource` interface + `PostgresAuthority` (Sema in / Sema out):
`get_by_id`/`get_by_alias`, `assert_active`, `fetch_edges`, and `apply_reparent`
(the atomic re-parent — recursive subtree alias rewrite + edge retire/create +
ledger claims + `validate_registry`, one transaction, returns a
`GNodeTopologyBroadcast`). Proven against live Postgres. The rabbit adapter
`GnrRabbit` (the write loop) also exists. **Harness (build step 6) — all three
layers green:** `tests/conftest.py` provisions the infra (testcontainers
`postgres:16` + `rabbitmq:3.13` by default; `GNR_TEST_PG_URL` / `GNR_TEST_RABBIT_URL`
opt-ins for already-running instances; self-skip otherwise). Layer 0 (DB-free unit
tier), Layer 1 (`tests/test_layer1_postgres.py` — `AuthoritySource` against a real
Postgres: seed loads `validate_registry`-clean, reads resolve, a beech-home re-parent
rewrites its subtree atomically), and **Layer 2** (`tests/test_layer2_rabbit.py` —
the EDD experiment: `GnrRabbit` + a MarketMaker stub on a real RabbitMQ; a published
`g.node.reparent.cmd` yields the `g.node.topology.broadcast` to a real subscriber and
the DB reflects the rewrite). Proven on testcontainers and against `gw-dev-rabbit` +
the dev Postgres. **FIS read path settled (2026-07-02):** writes ride rabbit, reads
ride HTTP, and FIS is a **pure `g.node.forest` broadcast subscriber** (a `ServiceSettings`
tap — no transport class), event-sourced and authority-scoped (see *Write path & egress*).
gwbase **0.5.5** forward-reverted the speculative `FleetIndexService` add; gnr stays on
0.5.3. **Not yet (read/egress):** author the two forest Sema words `g.node.forest` +
`g.node.forest.request` in sema + re-vendor the snapshot; replace the flat
`g.node.topology.broadcast` with the forest payload; rework `apply_reparent` to return a
`g.node.forest` + update `GnrRabbit`/the Layer-2 test; the **FastAPI read façade**
(`g.node.forest.request` → forest); and **root-keyed broadcasts** (`radio_channel` = the
affected copper root) so a FIS subscribes only to the subtrees it authorizes. **Forest-root rework (root = namespace decision, 2026-07-02):** `gnr.db.validate` +
`gnr.dev_universe` currently seed `d1` as a `Logical` root GNode; rework them so the
universe token is **not** a GNode — a `is_forest_root(alias)` helper (alias-parent is
the bare universe segment), the three structural checks exempt forest roots (no parent
GNode, no incoming edge), and the dev seed drops the `d1` node so `d1.isone` (MM) is a
forest root. **Not yet (other):** CI wiring (run Layer 0 always, integration behind
docker), edge change-history (status-history folds into the lifecycle SM; edge-history
is best a projection of the step-5 command log), and the explicit re-parent
alias-collision pre-check (today it aborts atomically via the ledger mid-rewrite).
