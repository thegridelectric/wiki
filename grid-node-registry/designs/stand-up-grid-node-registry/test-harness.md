# Test harness — a dev-universe layered harness (spoke)

Status: Draft · Pass 0 · Updated 2026-07-06

**EDD: yes** the harness *is* the verification — the registry's behaviour is
proven by a booted gnr talking real Sema over a real broker against a real
Postgres, seeded with a dev universe that mirrors the deployed fleet; the
in-process unit layer is necessary but not sufficient. (The hub is `EDD: no`
build-out; this spoke is where confidence comes from an experiment, so its bar is
`EDD: yes`.)

> What this is: how we test the registry now that it has gwbase interactivity. The
> harness boots gnr as a **dev universe** (`d1.*`) populated with a dev mirror of
> the production systems and the parent GNodes they require, then exercises the
> read + re-parent surface over rabbit + Postgres. Universes are defined in
> [`../../executor/primary.md`](../../executor/primary.md) "Universes".

**This spoke is COMPLETE.** All three layers are green — the EDD experiment
passed — and CI runs the full suite (GitHub Actions, all 30 tests against
Postgres + dev-rabbit service containers). The harness boots the real registry
over a real broker against a real Postgres and proves the re-parent loop end to
end. The design's active work is back in the hub's build order
(populate + deploy).

What landed:

- **Layer 0** — the DB-free unit tests (naming, class-hierarchy, the pure recursive
  re-parent rewrite).
- **Layer 1** (`tests/test_layer1_postgres.py`) — `PostgresAuthority` against a real
  Postgres: reads resolve; a beech-home re-parent rewrites its subtree (aliases +
  edges + ledger) atomically and leaves the registry valid; a generated-alias
  self-collision aborts the whole mutation.
- **Layer 2** (`tests/test_layer2_rabbit.py`) — the experiment: `GnrRabbit` + a
  MarketMaker `Orchestrator` stub on a real RabbitMQ; the MarketMaker publishes a
  `g.node.reparent.cmd`, the fabric forwards it to `gnr_tx`, the registry applies the
  atomic re-parent, and its `g.node.forest` broadcast returns to a real subscriber
  while the DB reflects the rewrite.

Infra is in `tests/conftest.py`: `testcontainers` (`postgres:16` + `rabbitmq:3.13`)
by default, an already-running Postgres/broker via `GNR_TEST_PG_URL` /
`GNR_TEST_RABBIT_URL` (e.g. the dev-compose Postgres on 5435 and `gw-dev-rabbit` on
`d1__1`) for a fast local loop, self-skip when neither is available. The Layer-2 test
provisions the gwbase fabric from `gwbase.topology` (the `MarketMaker ⇄
GridNodeRegistry` routing edges + `gnr_tx`/`gnrmic_tx` ship in gridworks-base 0.5.3).

## Why a dev universe (not mocks)

The registry is the source of truth FIS consults, and the re-parent operation is a
recursive subtree rewrite committed atomically — exactly the kind of thing
in-process mocks pass while reality fails. So the harness runs against a **real
Postgres** (the registry is Postgres-backed; no sqlite stand-in) and, at the top
layer, a **real broker**, with data shaped like production. A dev universe is the
clean way to get production-shaped data without real money: every alias is
re-aliased into `d1.*`, so nothing can reach the production universe or a
real-money MarketMaker (the universe guardrail).

## The dev universe — mirror the fleet

Source of truth for "what's deployed": the generated layouts in sibling
`tlayouts/output/*.uploaded.json`. Each deployed home is three GNodes —
a **LeafTransactiveNode** `hw1.isone.me.versant.keene.<home>`, a **Scada**
`…<home>.scada`, and a **TerminalAsset** `…<home>.ta` — under the parent chain
`hw1.isone.me.versant.keene`. The dev universe re-aliases the whole tree
`hw1 → d1` and seeds the registry with:

- **Parent GNodes** the systems require — a copper backbone of MarketMaker /
  ConnectivityNode: `d1` (root) · `d1.isone` (**MarketMaker**) · `d1.isone.me`
  (**ConnectivityNode**) · `d1.isone.me.versant` (**ConnectivityNode**) ·
  `d1.isone.me.versant.keene` (**MarketMaker**) — physical nodes need a
  `PositionPoint`. This chain validates under the class-hierarchy invariant
  (every MM/CN parent is the root or another MM/CN).
- **Each deployed home** (currently beech, elm, fir, maple, oak, spruce):
  its LTN + Scada + TerminalAsset, re-aliased into `d1.isone.me.versant.keene.<home>`.

A seed fixture builds these from the `tlayouts` outputs (read the
`My{LeafTransactiveNode,Scada,TerminalAsset}GNode` blocks, rewrite the universe
segment, insert through the codec + `GNodeSql`/`claim_alias`). The seed is
re-runnable and the registry must `validate_registry`-clean after it loads.

## The layers

Pattern follows the gridworks-journalkeeper layered-harness approach (`unit` vs
`integration` pytest markers; integration self-skips without docker;
`testcontainers` for ephemeral infra, or the dev `docker-compose` Postgres +
`gw-dev-rabbit` locally):

- **Layer 0 — unit, no infra.** The pure logic: `parent_alias`/`is_root`, the
  lifecycle SMs (`check_status_transition`, `check_base_class_transition`), and the
  class-hierarchy/coverage checks over in-memory fixtures. Fast, always-on.
- **Layer 1 — `AuthoritySource` against real Postgres.** Boot the dev-universe
  seed into a `testcontainers` (or dev-compose) Postgres, then exercise
  `PostgresAuthority`: reads (`get_by_id`/`alias`, `assert_active`, `fetch_edges`)
  and a re-parent on the mirrored tree — assert the subtree alias rewrite, the
  edge retire/create, the ledger claims, and a `validate_registry`-clean result.
- **Layer 2 — the rabbit adapter over a real broker.** Boot the gnr gwbase actor
  on `testcontainers` RabbitMQ (or `gw-dev-rabbit`), with a gwbase test-publisher
  send a request → assert the reply (`assert_active`, `get gnode`), and send a
  `g.node.reparent.cmd` → assert the `g.node.forest` broadcast and the persisted
  rewrite. This is the experiment that moves a spoke to Verified.

## Done-when

- ✅ Layer 0 green for the SMs + structural checks; deliberately breaking an invariant
  makes the right check fail.
- ✅ Layer 1: the dev-universe seed loads `validate_registry`-clean; a re-parent on a
  mirrored home rewrites its subtree and leaves the registry valid.
- ✅ Layer 2: a `g.node.reparent.cmd` over the real broker yields the matching
  `g.node.forest` broadcast and the DB reflects the rewrite.

## Notes

- The seed depends only on `tlayouts/output` + the registry's own codec — it does
  not import scada code.
- Keep the harness re-runnable; it is the evidence behind any `Verified` stamp on
  the registry (per EDD).
- **OFI (surfaced by Layer 1) — resolved:** the explicit alias-collision
  **pre-check** landed (the write path fails with a clear error naming the
  collisions); the mid-rewrite `AliasAlreadyOwned` ledger abort stays as
  defense-in-depth.
- The production universe token (`w…`) is not yet fixed; the dev universe only ever
  uses `d1`, so the harness is unaffected by that decision.
