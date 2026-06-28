# Stand up grid node registry

Status: Accepted · Pass 1 · Updated 2026-06-28 · Linear: OPS-419

**EDD: no** build-out — verified by the suite plus a deployed registry that
round-trips GNode I/O and answers FIS's validity queries; not a standalone
experiment.

> What this is: the path from the current `grid-node-registry` repo (models +
> Sema `gt` types + an Alembic scaffold, no running DB or API) to a **deployed
> registry FIS can query**. Current state + entities: see
> [`../executor/primary.md`](../executor/primary.md). The spine of this plan is
> the repo README's "Next steps," made ordered and given a FIS-facing API
> contract.

## Why now

The registry is the **source of truth FIS consults** to authorize a GNode
runtime instance (single-writer per `GNodeId`, cross-check against the registry).
So a running registry **with a query API** is a prerequisite for the 2026-summer
mTLS+FIS auth work — it has to exist before FIS can enforce GNode identity.

## Build order

1. **Dev Postgres + generated schema.** Fix the `docker-compose.yaml` Postgres
   roles (the known blocker — they fail today), then `alembic upgrade head` to
   create the tables. **Done-when:** a `GNodeGt` round-trips
   (`gt → GNodeSql.from_gt → session → to_gt`) against a real Postgres.
2. **History tables.** Append-only history for GNode + edge changes (alias
   changes, status transitions) — the substrate for *alias uniqueness through
   time*.
3. **Enforce the invariants** (the registry's reason to exist; see executor):
   alias-uniqueness-through-time, parent-closed active tree (and active physical
   subtree), ConnectivityEdge coverage, and the `base_class` CTN→MM transition rule.
   Enforce at write time, with a whole-registry validator pass available for audits.
4. **Lifecycle state machine.** Enforce the `GNodeStatus` transitions
   (Pending→Active, Active→{Suspended, PermanentlyDeactivated}, …) on every
   status change; reject illegal transitions.
5. **Egress: handler core + two transports** (see *Write model & egress*). A
   transport-agnostic handler core behind the `AuthoritySource` interface
   (read / assert-active / fetch-edges / apply the signed re-parent command),
   exposed over **rabbit (primary)** request-reply + a change broadcast and a thin
   **FastAPI façade** for non-rabbit consumers. Minimum read surface: look up a
   GNode by `alias` or `GNodeId`; **assert a `GNodeId` is `Active`**;
   `get gnode by {GNodeId}`; fetch parent/children edges. Pin this contract with FIS
   (OPS-422) — the handshake the auth path depends on; FIS reads it over rabbit.
6. **Tests + CI.**
7. **Deploy.** Where it runs (alongside FIS), how FIS reaches the API, `.env` /
   secrets, running Alembic on deploy.

## Write model & egress (the mutation contract)

Decided (2026-06-27; converged in the 2026-06-28 grill). Heritage: the legacy
Algorand-era `g-node-factory` already implemented this operation — see
*Legacy heritage* below; we canonize the parts that worked and drop the
Algorand plumbing.

- **`gnr` is the sole accessor of the backing store.** No other service reads
  or writes the database directly. Everything goes through gnr's two channels —
  and that indirection is deliberate: it makes the *backing store swappable*,
  so the registry's **authority can later move to a more distributed / on-chain
  record** behind the same surface (see *Preparing for distributed authority*).
- **Rabbit-primary + API = one core, two thin adapters.** A single
  transport-agnostic **handler core** (the `AuthoritySource` + operation handlers,
  Sema commands in / Sema types out) holds all logic. **Rabbit (primary, native):**
  an ActorBase-style consumer maps request messages → handlers → reply messages
  (`reply_to`/`correlation_id` request-reply) and publishes broadcasts (pub/sub) on
  mutation; **FIS reads over rabbit request-reply** (gwbase citizen, no HTTP on the
  hot path). **HTTP API (secondary façade):** FastAPI endpoints translating HTTP →
  the *same* handlers, for non-rabbit consumers + tooling, no logic of its own.
  (This is the fix for the legacy clunk — a `rest_api.py` and an actor with
  *parallel* logic.)
- **Identity vs. mutable state.**
  - `GNodeId` (UUID) — **immutable**; the node's durable identity for messaging
    and auth.
  - `alias` — **mutable** (re-parent); old value → `prev_alias`, change recorded
    append-only (the substrate for *alias-uniqueness-through-time*).
  - `status` — **mutable** (the lifecycle SM).
  - `base_class` — **constrained-mutable**: a `ConnectivityNode` MAY become a
    `MarketMaker` (and so gains authority to re-parent its sub-topology) — this
    happens when a copper-topology shift becomes a known constraint. A small
    allowed-transition SM, like `GNodeStatus`; not a free edit. (Legacy: CTN→MM
    upgrade, Update Axiom 4.)
  - `g_node_class` — **constrained-mutable in lockstep with `base_class`**: axiom 1
    binds them, so the CTN→MM transition changes both together. Otherwise fixed.
  - `display_name` — mutable. `PositionPoint` — **immutable** (location anchors the
    TaDeed; a change is a TaValidator re-certification, downstream — see Open).
- **Write authority is credentialed.** Only outside principals with the right
  credentials (**MarketMaker**) may change an alias. The mutation is a **signed,
  self-describing Sema command** (not an ad-hoc call), so the same message can be
  verified-and-applied centrally today or submitted to a distributed authority
  later. Ties to the FIS principal / mTLS+FIS credential model.

### The re-parent operation (recursive atomic alias rewrite)

The core mutation. A new node `N` is introduced **downstream of** an existing
node `E`; a **subset** of `E`'s children re-parent under `N`. Because the alias
is a dotted **materialized path** (a parent's alias is a prefix of each child's),
re-parenting is a **prefix rewrite of a whole subtree**:

1. The moved children — and **every descendant** of them — get their `alias`
   recursively rewritten (`E.c…` → `E.N.c…`); each old alias → `prev_alias`.
2. Connectivity edges adjust by **retire + recreate** on the immutable ids:
   `E→C` retires (status, kept for history), `E→N` and `N→C` are created. A pure
   rename touches **zero** edges (edges store ids, not aliases).
3. The **entire** subtree rewrite + edge changes + history rows commit in **one
   transaction** — atomic, all-or-nothing.
4. **Only after commit**, gnr **broadcasts** the new topology (best-effort). It does
   *not* need a delivery guarantee: convergence is **by authorization, not by
   delivery** — a renamed node carries the same immutable `GNodeId`, and FIS denies
   any connection whose alias is stale. The node learns its current alias from the
   FIS rejection and/or by re-querying the registry by `GNodeId`, then self-heals
   (re-provision + redeploy; renames run ~yearly). (The `auth-backend-http` deny is a
   bare allow/deny, so the channel that carries `current_alias` back is pinned in the
   FIS build, OPS-422.) The fleet routes by alias and an actor only knows its alias at
   runtime (`gwbase/transport_encoding.py`), so a stale node simply fails to authorize
   until it adopts the new alias. No dual-routing, acks, or `prev_alias` delivery
   bridge — `prev_alias` stays as the registry-internal parent-resolution aid + audit.

### Preparing for distributed authority (stub now, swap later)

A reason to route everything through API + rabbit (never direct DB) is to keep
the registry's **authority** swappable — today a single-writer Postgres owned by
gnr, later a more distributed / on-chain authoritative record. Three seams make
that a swap rather than a rewrite:

1. **An `AuthoritySource` interface** behind the API + rabbit handlers — `read`,
   `assert_active`, `apply(mutation)`, `subscribe`. Postgres is one
   implementation; a ledger/chain gateway is another. Handlers never touch
   SQLAlchemy directly.
2. **Mutations as signed Sema commands** (the re-parent request is a message with
   a MarketMaker signature). Central impl verifies + applies; distributed impl
   submits the same command as a transaction. Same bytes either way.
3. **Verifiable broadcasts** — a topology-change broadcast carries a proof
   (today gnr's signature as single authority; later a chain-inclusion proof).
   Consumers verify a proof regardless of backend. This preserves the
   Algorand-era *cryptographic-veracity / distributed-trust* principle without
   the Algorand plumbing (per GridWorks_CLAUDE legacy stance).

### Legacy heritage (canonize the what, drop the Algorand how)

From `legacy/g-node-factory` (+ `legacy/g-node-registry`, `legacy/old_words`):

- **`recursively_update_alias`** (`gnf_db.py`) — the depth-first subtree alias
  rewrite we are reproducing; computes `new_alias = new_parent_alias + "." +
  final_word`, recurses children before saving self, stashes `prev_alias`.
- **`prev_alias` as the parent-resolution aid** — parent lookup falls back to
  `prev_alias` when the natural parent (from the new alias) is not yet active. This
  is how the legacy avoided deadlock mid-rewrite; we keep it as the registry-internal
  aid (the runtime transition concern is otherwise handled by
  convergence-by-authorization, not by `prev_alias`).
- **`parent_from_alias()`** — parent derived from the alias string (split on `.`,
  drop last word), so topology is self-evident from the alias; no separate parent
  pointer to keep consistent.
- **`basegnodes.broadcast`** (`TopGNode` + `DescendantGNodeList`,
  `IncludeAllDescendants`) — the rabbit pub/sub shape for pushing a changed
  subtree; the registry was itself an `ActorBase` rabbit actor (`gnr_rabbit.py`)
  *and* had a REST api — precedent for rabbit-first + API.
- **Axiom system** — alias-uniqueness (live + history table), parent-closed
  active tree, role/class hierarchy (TA ⊂ ATN ⊂ CTN/MM ⊂ root), status SM.
- **Honest caveat:** legacy committed the DB **then** messaged async (no
  cross-system atomicity — eventual consistency). Our atomicity is *within* the
  registry transaction; fleet convergence is still eventual — and that is
  **accepted**, because FIS authorization (not message delivery) is the
  convergence backstop, so no acks/retries on the broadcast are needed.
- **DROP:** TaDeed/TradingRights **NFTs**, multisig `[GnfAdmin, Validator]`,
  AssetCreate/Transfer txns, algod/algosdk, Algo-address formats, msgpack txn
  signing. Each maps to a non-chain equivalent (cert/JWT, signed command, the
  `AuthoritySource` seam above).

## Resolved (the durable facts now live in `executor/primary.md`)

- **The Sema snapshot** stays in sync via a checked-in seed request
  (`gnr_seed_request.yaml`, targets `g.node.gt` · `connectivity.edge.gt` ·
  `position.point.gt`) + `build_gnr_snapshot.sh` (the gwta pattern, homed in the
  consumer). `g.node.gt` is **v004** (`g.node.class` enum dropped from the closure).
- **The 2026-06-28 grill** settled the mutation model: fleet-convergence is
  **by-authorization, not by-delivery** (broadcast best-effort + FIS-rejection
  backstop + ~yearly redeploy); **edges store ids only, retire+recreate**;
  **`PositionPoint` immutable** (change = TaValidator re-cert, downstream; accuracy
  by definition = within-footprint); **rabbit-primary + API = one core, two thin
  adapters** (FIS reads over rabbit).
- **The sema-type edits landed:** `connectivity.edge.gt` dropped its alias fields
  (`565d9d0`) and `position.point.gt` gained the footprint/immutability semantics;
  the gnr snapshot + models reconciled (`ae3be8f`).

## Open

- **The signed re-parent command + broadcast payload shapes** — the Sema message
  types for the write command and the topology-change broadcast (legacy
  `basegnodes.broadcast` = `TopGNode` + `DescendantGNodeList` is the heritage shape).
- **MarketMaker credential verification on the write path** — how the registry
  authenticates the signed command (ties to the FIS principal / mTLS model, OPS-420).
- **The `current_alias` push channel** for the FIS rejection (bare `auth-backend-http`
  deny can't carry it) — pinned with the FIS build (OPS-422).
- **Snapshot:** regen against sema `dev` once sim-vocab merges; whether the vendored
  `src/gnr/sema/README.md` should move out of the generated tree.
