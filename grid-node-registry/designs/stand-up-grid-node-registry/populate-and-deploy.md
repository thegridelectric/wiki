# Populate + deploy — the MVP registry on EC2 (spoke)

Status: Accepted · Pass 1 · Updated 2026-07-06 · Linear: OPS-419

**EDD: no** build-out/integration; verified by the deployed registry answering
real forest queries over its live surface (plus the suite staying green), not a
standalone experiment.

> What this is: build step 7 of the standup design — launch the registry on EC2
> and populate it with the real fleet. Everything upstream (handler core, rabbit
> write loop, HTTP read façade, harness, CI) is done; this spoke is the ordered
> path from "green suite" to "deployed registry FIS can query".

## Populate — the fleet enters as commands

The deployed registry's rows must be born through the handler core, never raw
SQL, so `command_log` + the alias ledger hold every row from birth (executor
*Distributed-readiness* #2).

1. **The create command is the missing piece — do this first.** The only write
   command today is `g.node.reparent.cmd`; creation has no command path
   (`seed_dev_universe` inserts directly — fine for the ephemeral dev universe,
   not for a deployed registry). Author a **`g.node.create.cmd`** Sema word (the
   new node as a `g.node.gt`, with `position_point_id` carried in the command —
   the carried-id case of determinism rule #1) and an
   `AuthoritySource.apply_create` handler: claim the alias, insert the covering
   edge (id via `gnr.ids.edge_id`; forest roots get none), append to
   `command_log`, validate, one transaction. Idempotent replay + alias
   pre-check, same as re-parent.
2. **Seed data:** the deployed fleet from `tlayouts/output/*.uploaded.json` —
   the parent copper chain plus each home's LTN/Scada/TA (the same source the
   dev-universe seed mirrors), fed through the create command parents-first.
3. **Positions stay staged:** opaque random `position_point_id`s in the
   commands; `position_points` stays empty (the staging plan:
   [`../../explorations/positions-staging-and-encryption.md`](../../explorations/positions-staging-and-encryption.md)).

## One universe per registry, as required config

A registry instance is scoped to exactly one universe (executor *Universes*).
Enforce it rather than assume it: a required **`GNR_UNIVERSE`** setting
(`Settings`, no default — the deployer declares it), with the write path
rejecting any command whose aliases don't carry that segment-0,
`validate_registry` checking every row lives in it, and the harness/dev
compose setting `d1`. Hosting a second universe later means a second registry
deployment (its own DB + settings), not a flag on this one.

The MVP registry serves **`hw1`** — the universe of the deployed fleet — so
`GNR_UNIVERSE=hw1` and the ingested aliases keep their `hw1.*` form as-is. Its
rabbit adapter rides the live run's fabric, vhost **`hw1__1`** (the registry is
per-universe and shared across runs; the vhost is broker-connection config, not
registry state). The `w` registry is minted when that universe exists.

## Deploy — EC2 alongside FIS

- **Surface:** the read-only HTTP API (`gnr.api`) is the open surface —
  internal service API, privacy by the network perimeter. **`gnr_tx` stays
  unreachable from outside until mTLS+FIS lands** (hard requirement).
- **Postgres:** encryption at rest from day one (RDS, or KMS-backed EBS if
  self-managed) — the baseline from the positions exploration.
- **Migrations:** `alembic upgrade head` on deploy, against the single squashed
  FK-free baseline.
- **Config/secrets:** `.env` from `template.env`; broker creds never hardcoded.
- **Snapshot cadence:** a periodic `broadcast_snapshot(root)` driver, cadence
  as deploy config (hub remaining item (b)).
- **README to standalone-adopter grade.** The "Next steps" list is stale — it
  still carries the retired "ConnectivityEdge consistency (ids and aliases
  match)" invariant (edges are ids-only now) and finished steps. Rewrite from
  the executor; READMEs stand alone (no wiki references).
- **Cleanup:** delete `scratch.py` (dead code) before the deploy commit.

## Open decisions

- Postgres: RDS vs a container on the EC2 box.
- Process shape on the box: how FIS runs there (container? systemd?) and
  whether gnr matches it; the repo has no Dockerfile yet.
- Who runs the ingest: a checked-in, re-runnable script publishing create
  commands over rabbit (exercises the deployed write loop), or calling the
  handler core in-process on the box (simpler, still "through the handler
  core"). Either satisfies commands-from-birth.

## Done-when

- The registry runs on EC2 with the real fleet loaded: `validate_registry`
  clean, every `g_nodes` row's birth in `command_log`, every alias in the
  ledger.
- `POST /gnr/g-node-forest-request` for the fleet's root returns the full
  forest; `GET /gnr/g-node-by-alias/...` resolves a home.
- The rabbit write loop is live on the deployed broker and `gnr_tx` is
  unreachable from outside.
- The README stands alone at adopter grade.
