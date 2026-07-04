# Stand up grid node registry

Status: Accepted · Pass 1 · Updated 2026-06-30 · Linear: OPS-419

**EDD: no** build-out — verified by the suite plus a deployed registry that
round-trips GNode I/O and answers FIS's validity queries; not a standalone
experiment.

> What this is: the path from the current `grid-node-registry` repo (models +
> Sema `gt` types + an Alembic scaffold, no running DB or API) to a **deployed
> registry FIS can query**. Current state + entities: see
> [`../../executor/primary.md`](../../executor/primary.md). The spine of this plan is
> the repo README's "Next steps," made ordered and given a FIS-facing API
> contract.

**▶ Active spoke: [`test-harness.md`](test-harness.md)** — the dev-universe layered test harness.

## Why now

The registry is the **source of truth FIS consults** to authorize a GNode
runtime instance (single-writer per `GNodeId`, cross-check against the registry).
So a running registry **with a query API** is a prerequisite for the 2026-summer
mTLS+FIS auth work — it has to exist before FIS can enforce GNode identity.

## Build order

1. **✅ DONE — Dev Postgres + generated schema.** The blocker was two-fold: a
   stale `gnr_pgdata` volume (old creds, so init was skipped) and a host port
   collision (a host-local Postgres shadows `localhost:5432`); fixed by
   publishing the container on **5435**. `Settings` also wasn't loading `.env`
   (no `env_file`) — fixed, and renamed `gnr.config` → `gnr.settings` to match
   the docs. Initial Alembic migration applied; a `GNodeGt` round-trips against
   the live DB. Details in `executor/primary.md` "Current status".
2. **◐ IN PROGRESS — History tables.** The `alias_assignment` ledger (the
   substrate for *alias uniqueness through time*) is **done + enforced** —
   `gnr.db.models.AliasAssignmentSql` (`alias` PK) + `gnr.db.alias_ledger.claim_alias`
   (`INSERT … ON CONFLICT` + ownership assertion), proven against live Postgres
   (mechanism in `executor/primary.md` "Enforcing alias-uniqueness-through-time").
   **▶ Open branch:** the status/edge change-history — whether GNode status
   transitions and edge retire/create share the ledger's append-only spine or get
   their own tables, ideally authored as a projection of the create/reparent
   command log.
3. **✅ DONE (audit form) — Enforce the invariants** (the registry's reason to
   exist; see executor). `gnr.db.validate.validate_registry` enforces
   alias-uniqueness-through-time (the ledger), parent-closed active tree,
   ConnectivityEdge coverage, and the class-hierarchy parent rule (= "active
   physical subtree parent-closed"), each proven against live Postgres. The
   whole-registry validator pass is the audit form; **write-time** enforcement on
   the affected subtree rides on the step-5 handlers. The `base_class` CTN→MM
   transition is a lifecycle/SM rule → step 4.
4. **✅ DONE — Lifecycle state machine.** `gnr.db.lifecycle` enforces the
   `GNodeStatus` SM (legacy Update Axiom 3) and the `ConnectivityNode →
   MarketMaker` `base_class` SM, proven against live Postgres (legal move
   persists; illegal move rejected, row unchanged). The step-5 handlers call
   these before applying a status/class change.
5. **◐ IN PROGRESS — Egress: handler core + two transports** (see *Write model &
   egress*). **Done:** the two Sema words (`g.node.reparent.cmd/000`,
   `g.node.topology.broadcast/000`) released + vendored; the transport-agnostic
   `gnr.db.authority.AuthoritySource` handler core (read / assert-active /
   fetch-edges / atomic recursive re-parent), proven against live Postgres; and
   the rabbit adapter `gnr.gnr_rabbit.GnrRabbit` (gwbase `Orchestrator`, transport
   class **`GridNodeRegistry`** published in gridworks-base **0.5.3** with its
   `gnr_tx`/`gnrmic_tx` exchanges) — decodes `g.node.reparent.cmd` →
   `apply_reparent` → broadcasts the affected subtree. The live Layer-2 proof of this
   rabbit loop is **done** (step 6 harness). **FIS read path settled (2026-07-02):**
   writes ride rabbit, **reads ride HTTP**, and FIS is a **pure broadcast subscriber**
   (a `ServiceSettings` tap — no transport class), event-sourced from change broadcasts
   and bootstrapped by an API query scoped to **its authority subtrees**. So gwbase
   **0.5.5** forward-reverted the speculative `FleetIndexService` add (dead fabric); gnr
   tracks 0.5.5. **Forest model (settled):** one reused **`g.node.forest`** payload
   (`roots` + subtree `g.node.gt`s + `connectivity.edge.gt`s) is the body of the change
   broadcast, the (chunked) snapshot broadcast, and the **`g.node.forest.request`** API
   response — the scaling unit that never moves the whole world at once (see *Write model
   & egress*). The universe token is a **namespace, not a GNode** — the registry holds a
   **forest of copper subtrees** (see executor *Universes* + invariants). **Done:**
   ✅ the forest words authored in sema (`g.node.gt` **v005** + axiom 6 ≥2-word alias;
   `g.node.forest` with a `Proof` seam field, `g.node.forest.request`; `g.node.topology.broadcast`
   retired), re-vendored into gnr; ✅ `apply_reparent` returns a `g.node.forest` + `GnrRabbit`
   broadcasts it (Layer-2 green); ✅ the **forest-root rework** (`is_forest_root`, `d1` dropped
   from the seed) shipped in the dev_universe cleanup; ✅ **distributed-readiness #1/#2** —
   `apply_reparent` derives edge ids (`gnr.ids`) + appends to an append-only `command_log`
   (content-addressed, replay-safe); ✅ the **HTTP read façade** (`gnr.api`, routes `/<service>/<sema-type-with-hyphens>`):
   `POST /gnr/g-node-forest-request` → `g.node.forest` (`get_forest`), `GET /gnr/g-node-by-id/{id}`,
   `GET /gnr/g-node-by-alias/{alias}` (`resolve_alias` — current **or** past alias → the current
   GNode) for FIS bootstrap + provisioning/analytics. ✅ **root-keyed broadcasts**
   (`radio_channel` = the change-stable parent alias, Layer-2-proven; gwbase **0.5.6**
   bridges `gnrmic_tx → amq.topic` for MQTT-native listeners; channel rule + listener
   pattern in the executor and the root-keyed-forest-broadcasts exploration).
   ✅ write-path hardening (idempotent replay; alias-collision pre-check) and the
   snapshot broadcast (`broadcast_snapshot(root)`, channel = current alias; cadence is
   deploy config). **▶ Remaining:** (a) the queued sema-first axioms
   (at-most-one-TC-child, terminal `.ta`/`.scada` — with a `gnr.db.validate` mirror)
   when the sema claim frees; (b) the gwbase `subscribe_ancestors` helper
   (GridworksActor tier, self-inclusive prefix bindings + rebind-on-rename) + a
   periodic snapshot driver at deploy; (c) scoping write-time validation to the
   affected subtree (whole-registry scan is fine at MVP scale, wrong at 10⁶); (d) the
   reparent command's optional **signature** (#3) + the chain-defined content-address,
   when the auth / distributed-authority model lands. FIS-as-subscriber +
   authority-scoped bootstrap is a FIS-side concern (OPS-422).
6. **✅ Tests + CI** — the dev-universe layered harness (all three layers green; see
   [`test-harness.md`](test-harness.md)) and GitHub Actions running all 30 tests
   against Postgres + dev-rabbit service containers.
7. **Populate + deploy** (the MVP: launch and populate on EC2). **Populate:** ingest
   the real fleet into `g_nodes` **through the handler core as commands** (populating
   `command_log` + the alias ledger from birth, never raw SQL), with opaque
   `position_point_id`s and `position_points` left **empty** (the staging plan —
   see `explorations/positions-staging-and-encryption.md`). **Deploy:** EC2 alongside
   FIS; the open surface is the read-only HTTP API; **`gnr_tx` stays unreachable from
   outside until mTLS+FIS lands** (hard requirement); `.env`/secrets; Alembic on
   deploy; README brought to standalone-adopter grade.

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
node `E`; a **subset (one or more)** of `E`'s children re-parent under `N`. Because the alias
is a dotted **materialized path** (a parent's alias is a prefix of each child's),
re-parenting is a **prefix rewrite of a whole subtree**:

1. The moved children — and **every descendant** of them — get their `alias`
   recursively rewritten (`E.c…` → `E.N.c…`); each old alias → `prev_alias`.
2. Connectivity edges adjust by **retire + recreate** on the immutable ids: `E→N`
   is created once, and **for each moved child `C`** the edge `E→C` retires (status,
   kept for history) and `N→C` is created. A pure rename touches **zero** edges
   (edges store ids, not aliases).
3. The **entire** subtree rewrite + edge changes + history rows commit in **one
   transaction** — atomic, all-or-nothing.
4. **Only after commit**, gnr **broadcasts** the new topology (best-effort). It does
   *not* need a delivery guarantee: convergence is **by authorization, not by
   delivery** — a renamed node carries the same immutable `GNodeId`, and FIS denies
   any connection whose alias is stale. A renamed node is recovered by **provisioning
   redeploy** — provisioning (internal, reads the registry) redeploys it with fresh
   config, triggered by the broadcast, with the **FIS deny as the backstop signal** (a
   missed node fails auth, which is observable → triggers redeploy). The node does not
   self-query; it just gets redeployed (renames run ~yearly, so a restart is fine).
   The fleet routes by alias and an actor only knows its alias at
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

## Write-path & recovery details (decided 2026-06-28)

Durable forms live in `executor/primary.md`; the Sema words are authored at build
step 5.

- **Re-parent command + broadcast — two Sema types.** Command `g.node.reparent.cmd`
  carries the new node `N` (a `g.node.gt`) and the moved child `GNodeId`s; the
  registry computes the recursive descendant rewrite. Broadcast
  `g.node.topology.broadcast` carries the affected subtree — the updated `g.node.gt`s
  (new aliases) + the edge retire/create set (heritage: legacy `basegnodes.broadcast`
  = `TopGNode` + `DescendantGNodeList`).
- **Write authority = the authenticated connection** (no separate signature scheme
  initially). The command arrives over an mTLS+FIS-authenticated rabbit connection
  (principal = cert `CN=GNodeId`); the registry authorizes by checking the
  principal's `base_class = MarketMaker` **and** that the affected subtree is within
  its authority. The detached signed-command option stays open via the
  `AuthoritySource` seam (distributed-authority future).
- **Rename recovery = provisioning redeploy, not a FIS push or a node self-query.**
  The registry broadcasts the topology change; **provisioning** (internal, reads the
  registry over the API) redeploys the affected nodes with fresh config. The FIS deny
  is the **backstop signal** — a node provisioning missed connects with a stale alias,
  fails auth, and that observable failure triggers a redeploy. The node never queries
  the registry itself; it just gets redeployed (~yearly cadence, so a restart is fine).
- **Read API needs no mTLS.** It is an **internal service API** — consumers are FIS,
  provisioning, and analytics (e.g. data analysis) inside the GridWorks infra. The
  topology + `position_points` (home-location) privacy is handled by the **network
  perimeter** (internal-only, not publicly exposed), not per-request client certs —
  so internal services query it over plain HTTP, no mTLS friction. (If remote
  self-service is ever needed, add a separately-exposed authenticated endpoint then.)
- **Snapshot tracking.** The vendored snapshot tracks whichever branch holds the
  registry's words — `jm/sim-vocab` now, `dev` once that merges. The hand-written
  `src/gnr/sema/README.md` is removed (stale boilerplate; provenance lives in
  `build_gnr_snapshot.sh` + `gnr_seed_request.yaml` + this design).
