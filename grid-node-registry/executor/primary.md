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
  is deferred to the TaValidator/deed work (substrate-fit, OPS-391).

## Write path & egress

`gnr` is the sole accessor of the backing store; all access goes through a
transport-agnostic handler core (the `AuthoritySource` interface) exposed over
**rabbit (primary)** request-reply + a change broadcast, and a thin **HTTP/FastAPI
façade** for non-rabbit consumers. The read API is an **internal service API** — its
consumers (FIS, provisioning, analytics) run inside the GridWorks infra, so it needs
**no mTLS**: the topology + `position_points` (home-location) privacy is handled by the
**network perimeter** (internal-only, not publicly exposed), and internal services
query it over plain HTTP. Two Sema message types carry a mutation:

- **`g.node.reparent.cmd`** — the write command: the new node `N` (a `g.node.gt`) +
  the moved child `GNodeId`s. The registry computes the recursive descendant alias
  rewrite and the edge retire/create set, and applies them in one transaction.
- **`g.node.topology.broadcast`** — the change event: the affected subtree as updated
  `g.node.gt`s (new aliases) + the edge retire/create set. Best-effort (convergence
  is by authorization, not delivery).

**Write authority = the authenticated connection.** A command arrives over an
mTLS+FIS-authenticated rabbit connection (principal = cert `CN=GNodeId`); the registry
authorizes by checking the principal's `base_class = MarketMaker` and that the
affected subtree is within its authority. A detached signed-command scheme stays
available via the `AuthoritySource` seam for a future distributed/on-chain authority.

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
- **Active GNode tree is parent-closed** — an active non-root GNode's
  alias-parent exists and is Active. The active *physical* subtree is
  parent-closed as a consequence of the class hierarchy below (physical classes
  only parent physical classes, up to the world root).
- **ConnectivityEdge coverage** — for every active non-root GNode `A` with parent
  `P`, the registry holds **exactly one** active edge `FromGNodeId = P,
  ToGNodeId = A` (no missing edge, no extra incoming edge, and the one edge is
  from the alias-parent). (The legacy "edge consistency" invariant — that an
  edge's ids and aliases agree — is **gone**: edges store ids only, so there is
  no stored alias to keep consistent.)
- **Class hierarchy** — each non-root GNode's parent class is legal for its own
  (the new-class form of legacy `g-node-factory` Creation Axiom 5 ROLE). A
  **CopperNode** is a `ConnectivityNode` or a `MarketMaker` — the copper-topology
  backbone (an MM is a CN that also runs a local market). The rules:
  - **CopperNode** (MM/CN) → parent is the world root or another CopperNode (the
    backbone is parent-closed);
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
state). FIS **reads + caches** the registry over **rabbit request-reply** (it is a
gwbase citizen), not HTTP.

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
the dev Postgres. **Not yet:** CI wiring (run Layer 0 always, integration behind
docker), edge change-history (status-history folds into the lifecycle SM; edge-history
is best a projection of the step-5 command log), the read request/reply Sema types +
FastAPI façade, and the explicit re-parent alias-collision pre-check (today it aborts
atomically via the ledger mid-rewrite).
