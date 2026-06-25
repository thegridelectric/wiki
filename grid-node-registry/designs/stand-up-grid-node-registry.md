# Stand up grid node registry

Status: Draft · Pass 0 · Updated 2026-06-23 · Linear: OPS-419

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
   subtree), ConnectivityEdge consistency, ConnectivityEdge coverage. Enforce at
   write time, with a whole-registry validator pass available for audits.
4. **Lifecycle state machine.** Enforce the `GNodeStatus` transitions
   (Pending→Active, Active→{Suspended, PermanentlyDeactivated}, …) on every
   status change; reject illegal transitions.
5. **Query API (FastAPI) — the FIS contract.** Minimum surface FIS needs:
   look up a GNode by `alias` or `GNodeId`; **assert a `GNodeId` is `Active`**;
   fetch a node's parent/children edges. Pin this contract with FIS — it is the
   handshake the auth path depends on.
6. **Tests + CI.**
7. **Deploy.** Where it runs (alongside FIS), how FIS reaches the API, `.env` /
   secrets, running Alembic on deploy.

## Open

- **Sema snapshot coupling.** `gnr` vendors its own Sema snapshot
  (`src/gnr/sema`); decide how it stays in sync with sema `dev` (a regen step,
  like JK's restricted snapshot).
- **Writer/authority.** Who writes the registry (provisioning mints GNode +
  registry row?), and the auth on the write path vs the read path FIS uses.
- **The API contract details** — settle with the FIS team alongside the
  mTLS+FIS auth work.
