# grid-node-registry — spec (primary)

Status: Draft · Pass 0 · Updated 2026-07-25

> What this is: the faithful spec of the **Grid Node Registry** (`gnr`) — the
> authoritative record of GridWorks GNodes, their geographic positions, and the
> connectivity (parent/child) edges between them. It is the registry the **Fleet
> Index Service (FIS)** consults to authorize a GNode runtime instance. Current
> state plus the intended invariants. Stood up and deployed 2026-07
> ([OPS-419](https://linear.app/gridworks/issue/OPS-419)); operational facts
> (box, credentials, runbooks) live in `gridworks-infra`, not here.

## What it is

A Postgres-backed service (`grid-node-registry` repo, `src/gnr`). Every SQL row
is a serialized **Sema GT** snapshot; the Sema `gt` types validate (via the
codec) before any insert/update. Three entities (`src/gnr/db/models.py`):

| Table | GT type | Holds |
|---|---|---|
| `g_nodes` | `GNodeGt` | a GNode: `id` (GNodeId), unique `alias` (LeftRightDot), `prev_alias`, `base_class`, `g_node_class`, `status`, optional `position_point_id`, `display_name` |
| `position_points` | `PositionPointGt` | a geographic point: `latitude_micro_deg`, `longitude_micro_deg` (**immutable**; see Mutability model) |
| `connectivity_edges` | `ConnectivityEdgeGt` | a **non-tree** copper edge (tie, loop, meshed feed) keyed on **immutable ids only**: `from/to_g_node_id` (FK), `status`; unique `(from, to)`. Parent-child tree edges are **not stored** — the tree is the alias structure, derived on read |

Enums (`src/gnr/sema/enums`): **`BaseGNodeClass`** (`ConnectivityNode` /
`MarketMaker` / `Logical` / …) and **`GNodeStatus`**.
**`GNodeClass` is not an enum** — it is an axiom-governed open `str`
(so the open namespace of classes — `TerminalAsset`, `Scada`, … — needn't bump
an enum), held consistent with `base_class` and `alias` by the GT axioms below.

## Universes

**This section is the authoritative definition of universes** — other docs
(gwbase provisioning, the gnr README, the scada guardrail design) summarize and
point here.

A **universe** is the first dotted segment of a GNodeAlias, and its **kind** is
that segment's first letter. The kinds form a ladder — each step adds a
requirement:

- **`d` — dev: runs locally on a single computer.** The defining property: **all
  comms go through localhost brokers.** That is the isolation guarantee (nothing
  can reach a real system or real money), and why the test harness and CI are dev
  universes — a laptop or a CI runner *is* the single computer.
- **`h` — hybrid: the most flexible.** Distributed comms; real and simulated
  participants mixed in one tree; real hardware allowed; re-runnable
  (`hw1__1`, `hw1__2`, …). Trust is by configuration/mTLS — **no validation-cert
  requirement** — and still no real money.
- **`w` — production: validation required.** Scadas and MarketMakers MUST carry
  **Validation certs** (the TaValidator/TaDeed plane) — the full trust machinery
  — and it is the **only** place GridWorks MarketMakers manage real money.

There are **many** dev/hybrid universes (`d1`, `d2`, `hw1`, …) but exactly
**one** production universe. So `universe_of(alias) = alias.split(".")[0]`, and
"is this real money?" ⇔ "is the universe the single production one?" (The
enforcement guardrail — a GNode may only talk on a broker in its own universe,
the broker host/vhost encoding that universe, `gw-dev-rabbit` serving `d1__1` on
localhost — lives in the scada `hardware-layout-pass-one` design; what binds
*here* is that every alias the registry holds carries its universe in segment 0.)

A registry instance is **scoped to one universe**: a dev registry holds the `d1`
tree, the production registry holds the `w` tree. This is what lets a **dev
universe** mirror production — the same GNode topology re-aliased into `d1.*` —
without ever touching real money. The test harness (see the standup design) is
exactly such a dev universe: the deployed systems (`hw1.isone.me.versant.keene.*`)
and the parent GNodes they require, re-aliased into `d1`.

**Universes are durable; runs are ephemeral.** A broker
vhost is **`<universe>__<run>`**, **uniform across all kinds including
production** (`d1__1`, `hw1__1`, `w__1`): the universe
names a **durable set of GNodes** (the registry's tree — real and simulated
members alike in a hybrid), and a **run** is one execution of time against it —
its own message fabric, sim-clock state, event history, and FIS lease state.
Re-running the same universe (same topology, same recorded weather/price feeds)
under different bidding strategies is `hw1__1` vs `hw1__2`: a controlled
experiment on identical structure. Consequences: **the registry is per-universe
and shared across all its runs** (one `hw1` registry serves every `hw1__n`);
topology-*mutating* experiments belong in their own dev universe (a re-parent in
one run would bleed into sibling runs through the shared registry); **real
hardware may participate in any run whose clock it can physically follow** — a
field device serving a real house lives in the wall-clock ("live") run, while a
bench rig can join a re-run as hardware-in-the-loop (physical hardware always
experiences wall-clock time, so it can't follow a sped-up sim clock); and
single-writer authority is per **(GNodeId, run)**, since the same GNode identity
legitimately runs in several runs at once (a FIS-design consequence,
OPS-420/422). For a real universe the run number doubles as **fabric
generation**: reality executes once, but the message fabric can be rebuilt —
broker migration or disaster recovery mints `w__2` with the same universe, same
registry, same identities. **Which run is "live" is deployment state — a pointer
in provisioning config, never encoded in a name** (state in names goes stale; the
same reason alias ≠ GNodeId). And **no message body carries its run**: the run is
a property of the fabric (the vhost a connection is on), recorded where messages
are *persisted* — the ear's capture keys and the JournalKeeper's storage carry
the vhost — per the audit principle (gwbase `transport.md` "Message properties": delivery
metadata lives in the infrastructure, not the payload).

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

## Per-row Sema axioms (`g.node.gt` v005)

The `GNodeGt` codec enforces six axioms on every row before insert/update:

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
6. **GNodeAliasHasBody** — `alias` (and `prev_alias` when present) has at least
   two dotted words: the universe segment alone is a namespace, not a
   GNodeAlias.

## Mutability & change model

What is fixed vs. what changes, and how:

- **`GNodeId` — immutable.** The durable identity for messaging, auth, and the
  FIS single-writer lease. The fleet routes by *alias* (`gwbase`
  `transport_encoding`), but identity is the id; this split is what makes a
  rename survivable.
- **`alias` — mutable** via the re-parent operation (recursive **atomic** subtree
  rewrite, one transaction; old value → `prev_alias`, recorded append-only). A
  re-parent touches **zero** edge rows: the parent-child structure is the alias
  prefix itself, and `connectivity_edges` holds only non-tree copper (which
  stores ids, not aliases).
- **`base_class` + `g_node_class` — constrained-mutable in lockstep.** A
  `ConnectivityNode` MAY become a `MarketMaker` (gaining authority to re-parent its
  sub-topology) when a copper-topology shift becomes a known constraint. Axiom 1
  binds the two, so both change together. A small allowed-transition SM, not a free
  edit.
- **`status` — mutable** per the lifecycle SM below.
- **An edge's `Id` — immutable for its `(From, To)` pair.** One edge per
  ordered pair (`uq_connectivity_edges_from_to`); lifecycle is carried by
  `Status` on the same `Id` — a suspended edge re-activates under its
  original identity. There is no command that re-creates a pair under a new
  `Id`, and consumers projecting the forest treat a new id claiming a held
  pair as an anomaly to surface, not an identity change to absorb.
- **`display_name` — mutable.** Presentation only; no axiom or invariant binds it.
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
transport-agnostic handler core (the `AuthoritySource` interface) — one core, two
thin adapters, so no transport ever grows its own parallel logic (the legacy
registry's REST api and rabbit actor each had their own). **Writes ride
rabbit** (a MarketMaker is a fleet bus citizen; the change event is genuinely
pub/sub); **reads ride an HTTP/FastAPI façade** — public, read-only,
TLS (Caddy + Let's Encrypt in front), CORS-open. The registry is backbone
infrastructure: anyone may read its topology (FIS, provisioning, analytics,
outside readers alike). Privacy rides on the data shape, not a network
perimeter — topology only, opaque `position_point_id`s, `position_points`
empty until the TaValidator encryption work. Writes never ride HTTP; the
write path stays on rabbit behind its gate. This split is by traffic shape,
not by consumer.

**A write is not a projection.** Two different things put registry-shaped rows
into a database, and they must not be conflated:

- **A command changes truth.** An authorized principal sends a write command
  over the write channel; the registry authorizes it, appends it to
  `command_log`, claims aliases in the ledger, mutates state, and validates —
  one transaction inside the authority boundary. gnr's own tables are the
  materialized projection *of that log*, maintained in the same transaction;
  that is what makes them authoritative.
- **A projection mirrors truth.** Downstream copies of registry state
  (`gw_data.g_nodes` via gjk, FIS's in-memory map) consume the **interface** —
  `g.node.forest` broadcasts + `g.node.forest.request` — never gnr's Postgres
  (the OPS-443 seam). They hold no authority: no authorization beyond bus
  membership, no ledger claims, no invariant enforcement, no write-back —
  idempotent upserts keyed on immutable ids, eventually consistent, healed by
  the snapshot broadcast. A projection can be deleted and rebuilt at any time
  with no loss; the command log cannot — it is the registry's memory.

Populating the registry is a write, not a projection: ingesting the existing
fleet *establishes* truth in the authority, so it enters as authorized
commands — even though the same nodes then flow onward to `gw_data` as
broadcasts, where they land as a projection. Same data, opposite roles.

**The write + its change event:**

- **`g.node.reparent.cmd`** — the write command: the new node `N` (a `g.node.gt`) +
  the moved child `GNodeId`s. The registry computes the recursive descendant alias
  rewrite and applies it in one transaction; no edge rows change.
- **On commit the registry broadcasts a forest** of the affected subtree (see below),
  keyed on a **`radio_channel` = the alias the audience is bound to** — for a
  re-parent introducing N under E, that is **E's alias** (the deepest change-stable
  ancestor, a prefix of every moved node's old alias; `parent_alias(new_node.alias)`
  in `GnrRabbit`); for a pure rename, the top node's `prev_alias`; for a snapshot
  broadcast, the current `alias`. Listener logic is identical in
  all cases: upsert the forest, react if your GNodeId carries a new alias. Listeners
  bind ancestor channels **self-inclusively** (GridworksActor tier, O(depth) exact
  bindings); subtree monitors (FIS) bind one trailing-`#` per authority root.
  Best-effort, **no re-broadcast on old channels** (convergence is by authorization,
  not delivery; durable subscriber queues cover downtime; the FIS deny is the
  backstop). Reasoning in
  [`../explorations/root-keyed-forest-broadcasts.md`](../explorations/root-keyed-forest-broadcasts.md).

**The forest — one payload, three uses.** A **forest** is a set of subtrees, each
rooted at one of a chosen set of nodes and carrying every descendant. It is the
**scaling unit**: the registry never moves the whole world in one message — it
addresses by root-set, so each message is bounded by that slice of topology (this is
what survives a million assets; heritage: legacy `basegnodes.broadcast` =
`TopGNode` + `DescendantGNodeList` + `IncludeAllDescendants`). A single **`g.node.forest`**
payload (`roots: [GNodeId]` + the subtree `g.node.gt`s with current aliases + any
**non-tree** `connectivity.edge.gt`s among them — empty in a purely radial fleet;
parent-child edges are derived from the aliases) is **reused** as:

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

**Until mTLS+FIS lands, a stop-gap proof gate holds the write path**: with
`GNR_WRITE_PROOF_SHA256` configured, `_check_proof` refuses any
create/re-parent whose `Proof` doesn't sha256-hash to it — checked before
anything else, including the idempotent-replay short-circuit, so an unproven
command touches nothing and learns nothing. The secret lives only with the
operator; the deploy holds the hash; rotation is a `.env` edit + restart.
Honest limit: the Proof rides inside commands, so it appears in
`command_log` and the ear capture — the key is exactly as secret as the
capture store. Retired by OPS-420.

## Distributed-readiness (keep the swap a swap, not a rewrite)

The registry's authority is meant to be **swappable** — a single-writer Postgres
today, a more distributed / on-chain authoritative record later (the Algorand-era
*cryptographic-veracity / distributed-trust* principle, without the Algorand
plumbing). Four properties keep that a swap behind the `AuthoritySource` seam. The
first two are **implemented** (`gnr.ids`, `gnr.db.models.CommandLogSql`,
`gnr.db.authority.apply_reparent`) and pay off now (reproducible state + free audit
history + replay safety), so they are not speculative:

1. **Deterministic mutation (implemented).** `apply(command)` is a pure
   `(state, command) → state'` — any consensus/replicated backend re-executes it on
   many validators that must agree byte-for-byte. So an id that lands in authoritative
   state is **either carried in the command** (submitter-assigned, frozen by the
   log/tx — e.g. a `GNodeId`, or a `position_point_id`) **or derived from inputs every
   validator holds** (public data — e.g. `gnr.ids.edge_id` from the two endpoint ids);
   it is **never handler-minted** (a handler-minted `uuid.uuid4()` edge id would be
   that illegal third case) and **never derived from a secret** (deriving `position_point_id` from
   the coordinates would both leak the location *and* be unreproducible by validators
   who correctly can't see the encrypted plaintext). Edge ids serialize into
   `g.node.forest` (authoritative state); the whole dev universe is deterministic too
   (`gnr.ids.deterministic_uuid4`). `created_at` stays wall-clock — it is **not** in any
   Sema type, so it is local audit metadata, not authoritative state (full log-replay
   byte-identity would additionally want a command-carried logical time, deferred).
2. **The command log is the primitive; state is a projection (implemented).** A
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
these are **shape**, not machinery; #4 is a discipline on the interface.

## Durability — the message log is the system of record

The registry requires **no database backups**. Its Postgres is a materialized
view of the logged command stream, and that stream is held in two places
joined by the content hash (`gnr.ids.command_hash`): the in-band
**`command_log`** (every command *applied*, transactional with state) and the
**ear's durable capture** of the bus (every command *published* — including
refused ones, the audit of the registry saying no — plus the `g.node.forest`
broadcasts, the announced results). Deterministic apply (#1 above) is what
makes replay valid: a rebuild replays the captured commands in capture order
through the handler core — refusals re-refuse, applies re-apply
byte-identically — and cross-checks the resulting forests against the
captured broadcasts. Two independent witnesses that must reconcile. Three
conditions carry the posture:

1. **The capture witnesses genesis.** The ear capture consumer runs before
   the registry is populated and lands in durable storage — the capture
   store, not the database, is the crown-jewel copy (capture mechanics,
   including the second non-hyperscaler sink: OPS-443).
2. **The rebuild script is repo code, proven by experiment** — the
   dev-harness EDD run (capture → wipe → replay → `validate_registry`-clean,
   forests matching). An untested restore path is not a restore path.
3. **Replay preserves capture order** (topology commands are rare and
   parents-first, so ordering is unambiguous at fleet scale; a
   command-carried logical time is the deferred backstop, #1 above).

Forest serialization is **deterministic** — `get_forest` orders nodes by
alias and edges by id — which is what makes the byte-identical
broadcast/replay compare possible at all (`gnr.rebuild` is the replay
implementation and `gnr rebuild <capture> [--wipe]` the operator surface —
held on the `jm/gnr-rebuild` branch until OPS-457 lands the true-store
source).
Database snapshots MAY be taken as restore accelerators; they are never the
durability story.

**Proven against the true store** (2026-07-25): the full production
registry rebuilt locally from the B2 `gw-seedstore` capture alone — 149
unique publishes (dual-witnessed objects verified byte-identical), replayed
with the production proof hash so the one refused command re-refused, 102/102
forest checkpoints matching, and the end state node-for-node identical to
the live registry (24-node `hw1.isone` forest + `hw1.time`),
`validate_registry`-clean. The feed was the provisional JSONL form (stream
assembled by hand from the store); the in-repo `--s3` source is OPS-457.

Open: `position_points` ride outside the command stream, so a rebuild
restores them only as far as the stream implies — complete for the
Pending-era registry (proven above), but the activation mechanism must make
positions rebuildable (carried in its command, or restored from the
TaValidator store) before Active-with-positions is the normal state.
Resolves in OPS-457's scope.

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
functions the write handlers call before applying any status/class change,
rejecting an illegal move before the mutation commits. Identity transitions are
no-ops.

## Time coordinators

**TimeCoordinators are GNodes** (`base_class: Logical`, `g_node_class:
TimeCoordinator`), and **TC trees hang off the copper**: `<uni>.time` (e.g.
`d1.time`) is the universe-level clock — a Logical forest root — and a house
clock is a **child of the LTN**, sibling of `.scada`/`.ta`. A regional clock is a
child of a copper node. Which clock a *simulated* GNode marches to is **derived
from registry state alone**:

> Walk **self, then ancestors, nearest first**; the first node with a
> TimeCoordinator child names your clock. If none, `<uni>.time` is the default
> (uniformly: the bare universe token is the virtual top ancestor whose
> "children" are the forest roots).

Lexical scoping for time domains — a simulated house overrides the regional
clock; everything else defaults up the chain. Self-inclusive matters: an LTN with
its own TC child marches to it. Rationale (and why TCs earn registry rows — alias
addressing, FIS-era `CN=GNodeId` identity) in
[`../explorations/root-keyed-forest-broadcasts.md`](../explorations/root-keyed-forest-broadcasts.md).
Supporting invariant, **to be enforced sema-first** (sema enforcement keeps
the future chain lift light): **at most one TimeCoordinator child per GNode** —
as a `g.node.forest` axiom, or structurally via a `.time` ⇔ TimeCoordinator
suffix rule (then alias uniqueness enforces it for free; costs a `g.node.gt`
version step — open at authoring). Likewise **`.ta`/`.scada` are terminal**
(no node's alias-parent is a TerminalAsset or Scada), forest axiom + a
`gnr.db.validate` mirror.

## Intended invariants (the registry's reason to exist)

Beyond per-row Sema validation, the registry MUST enforce structure Sema can't:

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
- **Edges are non-tree only** — the alias hierarchy is a **spanning tree** of
  the grid graph (the Milestone 1 framing), so `connectivity_edges` holds only
  the copper connectivity the tree cannot express: ties, loops, meshed feeds.
  An active edge's endpoints MUST exist and be Active, and an edge MUST NOT
  mirror a tree edge — `from_g_node_id` MUST NOT be the GNode at the
  alias-parent of `to_g_node_id` (and never the reverse either: no stored edge
  may duplicate any parent-child pair in either direction). The tree itself is
  never stored as edges; consumers derive parent-child edges from aliases.
  (Edges store ids only — the legacy invariant that an edge's ids and aliases
  agree has no object to apply to.)
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
- **Active physical GNodes hold their PositionPoint** — a GNode whose
  `base_class` is physical (≠ Logical: TerminalAsset, LeafTransactiveNode,
  ConnectivityNode, MarketMaker) MUST NOT be Active unless its
  `position_point_id` resolves to a `position_points` row. Grid position is
  part of what activation asserts (the TaValidator plane supplies it), so a
  node whose position is still staged stays Pending. Presence only — position
  *content* trust remains TaValidation's concern. Logical nodes carry no
  location requirement.

These structural invariants are enforced by `gnr.db.validate` —
`validate_registry` runs the audit pass, and the write handlers run it at write
time (today a whole-registry scan; scoping to the affected subtree is queued in
the standup design).

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
load-bearing, and the FIS deny needs no rich payload — **and mechanically cannot
carry one**: the `rabbitmq-auth-backend-http` protocol returns only
`allow`/`deny`, so there is no channel to hand the denied client a hint (the
legacy FIS writeup, `gridworks-infra/authority/fleet-index-service/`, maps
`NOT_AUTHORIZED`/`REJECTED` → bare `{"result": "deny"}`). The FIS-side contract
(cert-subject = `GNodeId`, alias-staleness check) lives in the mTLS+FIS auth work
(OPS-420 / OPS-422).

## Stack

Python 3.12, `uv`, `pydantic-settings` (`gnr.settings.Settings` ← `.env`),
SQLAlchemy + **Alembic** migrations, Postgres 16 (`docker-compose.yaml`). Logs to
`~/.local/state/gridworks/gnr/log/` (GridWorks convention). The vendored Sema
snapshot (`src/gnr/sema`) is built by `build_gnr_snapshot.sh` from
`gnr_seed_request.yaml`; the registry's words are `published` in sema.

## Implementation map

Where the spec lives in `src/gnr`, all proven against a real Postgres and (for
the write loop) a real broker by the layered suite:

- **`gnr.settings`** — pydantic-settings `Settings` ← `.env`. `universe` is
  REQUIRED (no default): the one universe this instance serves, validated
  (single lowercase word, kind letter `d`/`h`/`w`); a `w…` universe **refuses
  to boot** while its trust machinery is stubs (`PROD_STUBS` — Proof
  verification, the validation-cert plane, encrypted positions).
- **`gnr.db.session`** — engine/session factory. Dev Postgres: `docker compose
  up`, host port **5435** (5432 is commonly shadowed by a host-local Postgres);
  the Alembic baseline creates all tables.
- **`gnr.db.models`** — `GNodeSql` / `PositionPointSql` / `ConnectivityEdgeSql`
  rows that round-trip their Sema GTs through the codec, plus
  `AliasAssignmentSql` (the through-time ledger) and `CommandLogSql` (the
  append-only command log).
- **`gnr.db.alias_ledger.claim_alias`** — the race-free uniqueness primitive
  (`INSERT … ON CONFLICT` + ownership assertion).
- **`gnr.db.validate.validate_registry`** — the structural-invariant audit pass
  (parent-closed active forest, non-tree-only edge rules, class hierarchy).
- **`gnr.db.lifecycle`** — the `GNodeStatus` + `base_class` SMs (pure functions
  the write handlers call).
- **`gnr.db.authority`** — `AuthoritySource` + `PostgresAuthority` (Sema in /
  Sema out): reads (`get_by_id` / `get_by_alias` / `resolve_alias` — current or
  past alias → the current GNode — / `get_forest`, `assert_active`,
  `fetch_edges`) and the two mutations — `apply_create` (a single node enters:
  parent-first check, ledger claim, command-log append, validation, one
  transaction) and `apply_reparent` (recursive subtree alias rewrite + ledger
  claims + command-log append + validation, one transaction) — each returning
  a `g.node.forest`; edge rows are untouched by both (the tree is the alias
  structure), and both reject an alias outside the configured universe. The
  write path is
  **replay-idempotent** (a duplicate command returns the affected subtree's
  current forest) and **pre-checks alias collisions** (explicit error naming
  the collisions; the mid-rewrite ledger abort kept as defense-in-depth).
- **`gnr.ids`** — the derived ids (`edge_id`, `command_hash`,
  `deterministic_uuid4`).
- **`gnr.gnr_rabbit.GnrRabbit`** — the rabbit write loop (gwbase
  `Orchestrator`, transport class `GridNodeRegistry`, `gnr_tx`/`gnrmic_tx`
  exchanges). Alias convention, deployed and CLI-assumed: the registry
  serves as **`<universe>.gnr`** and the operator CLI speaks as
  **`<universe>.gnregistrar`** — the CLI addresses `<universe>.gnr`, so a
  deployed registry must run that alias (the two are literals in `cli.py`
  and the box `.env`; they drifted once and cost an unrouted command): decodes `g.node.reparent.cmd` → `apply_reparent` → root-keyed
  `g.node.forest` broadcast; `broadcast_snapshot(root)` is the anti-entropy
  path (cadence is deploy config). The `gnrmic_tx → amq.topic` bridge
  (gwbase ≥ 0.5.6) carries broadcasts to MQTT-native listeners.
- **`gnr.api`** — the FastAPI read façade (routes
  `/<service>/<sema-type-with-hyphens>`, no logic of its own):
  `POST /gnr/g-node-forest-request`, `GET /gnr/g-node-by-id/{id}`,
  `GET /gnr/g-node-by-alias/{alias}`.
- **`gnr.cli`** — the operator surface: `gnr rabbit` / `gnr api` /
  `gnr snapshot` runners and `gnr create` (interactive wizard or arg form:
  GNodeClass menu with `BaseGNodeClass` inferred from `g.node.gt` axiom 1;
  existence pre-check over the read API; publishes with the write Proof
  from env or prompt; waits on the typed verdict, then polls the API as the
  visibility proof).
- **`gnr.dev_universe`** — the dev-universe seed (direct inserts through the
  codec + `claim_alias`; see the limits below).
- **`tests/`** — the layered harness (Layer 0 unit / Layer 1 real Postgres /
  Layer 2 real broker; `testcontainers` by default, `GNR_TEST_PG_URL` /
  `GNR_TEST_RABBIT_URL` opt-ins for already-running infra, self-skip
  otherwise). GitHub Actions runs the full suite against Postgres + rabbit
  service containers.

**Known limits** (facts, fine at MVP scale): write-time validation scans the
whole registry per write (subtree scoping queued for scale); the
dev-universe seed inserts directly (bypassing `command_log` — fine for the
ephemeral test universe; the deployed registry's rows are born as
`g.node.create.cmd`s). Queued enforcement: the sema-first axioms
(at-most-one-TimeCoordinator-child; `.ta`/`.scada` terminal — see *Time
coordinators*), and the gwbase `subscribe_ancestors` helper for
GridworksActor-tier listeners.
