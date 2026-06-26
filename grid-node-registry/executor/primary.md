# grid-node-registry — spec (primary)

Status: Draft · Pass 0 · Updated 2026-06-23

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
| `position_points` | `PositionPointGt` | a geographic point: `latitude_micro_deg`, `longitude_micro_deg` |
| `connectivity_edges` | `ConnectivityEdgeGt` | a parent→child edge: `from/to_g_node_id` (FK), `from/to_g_node_alias`, `status`; unique `(from, to)` |

Enums (`src/gnr/sema/enums`): **`BaseGNodeClass`** (`ConnectivityNode` /
`MarketMaker`), **`GNodeClass`**, **`GNodeStatus`**.

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
- **ConnectivityEdge consistency** — an edge's `GNodeId`s and aliases agree.
- **ConnectivityEdge coverage** — for every non-root GNode with alias `A` and
  parent alias `P`, the registry holds **exactly one** edge with
  `FromGNodeId = UUID(P)` and `ToGNodeId = UUID(A)`.

## Relationship to FIS

FIS authorizes GNode runtime instances against this registry: it enforces
**single-writer per `GNodeId`** and cross-checks the live instance against the
registry (FIS principal-model, Invariant #1). So the registry is the **source of
truth** for GNode identity/validity that FIS queries — which is why standing it
up (with a query API) is a prerequisite for the mTLS+FIS auth work.

## Stack

Python 3.12, `uv`, `pydantic-settings` (`gnr.settings.Settings` ← `.env`),
SQLAlchemy + **Alembic** migrations, Postgres 16 (`docker-compose.yaml`). Logs to
`~/.local/state/gridworks/gnr/log/` (GridWorks convention).

## Current status (2026-06-23)

Models + Sema `gt` types + enums + an Alembic scaffold exist. **Not yet:** a
working dev Postgres (the `docker-compose` Postgres roles are failing), generated
tables, history tables, enforced invariants, managed lifecycle transitions, a
FastAPI query API, or tests/CI. The standup design sequences these.
