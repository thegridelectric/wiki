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

## Intended invariants (the registry's reason to exist)

Beyond per-row Sema validation, the registry MUST enforce structure Sema can't —
**not all are implemented yet** (see the standup design):

- **Alias uniqueness through time** (not just live uniqueness).
- **Active GNode tree is parent-closed**; the active *physical* subtree is
  parent-closed.
- **ConnectivityEdge coverage** — for every non-root GNode `A` with parent `P`,
  the registry holds **exactly one** active edge `FromGNodeId = P, ToGNodeId = A`.
  (The legacy "edge consistency" invariant — that an edge's ids and aliases agree —
  is **gone**: edges store ids only, so there is no stored alias to keep consistent.)

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

Models + Sema `gt` types + enums + an Alembic scaffold exist; the vendored Sema
snapshot tracks sema (`g.node.gt` v004), and the `connectivity.edge.gt` ids-only +
`position.point.gt` footprint/immutability edits have landed. **Not yet:** a
working dev Postgres (the `docker-compose` Postgres roles are failing), generated
tables, history tables, enforced invariants, managed lifecycle transitions, the
rabbit/HTTP query surface, or tests/CI. The standup design sequences these.
