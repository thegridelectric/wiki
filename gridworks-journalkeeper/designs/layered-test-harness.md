# Design: Layered test harness for gridworks-journalkeeper

> Status: Draft · Pass 0 · Updated 2026-05-29

What this is: a plan to test gjk's two ingest paths — the **S3 message importer**
(backfill) and **`journal_keeper.py`** (live AMQP) — which share a decode+persist
core, so most of the value comes from testing that core once and adding thin
per-transport tests on top.

## Context

gjk ingests fleet messages two ways:
- **`s3_message_importer`** — backfill from the ear S3 event store.
- **`journal_keeper.dispatch`** — the live RabbitMQ / gwbase path.

Both converge on **`SemaCodec`** (decode) + **`SemaMessagePersistor`** (persist →
`gw_data` `messages`/`readings`). There is currently almost no automated test of
decode/persist — which is *why* the `atn.bid` closure bug shipped: nothing
exercised each seeded type against the restricted gjk snapshot. Note the persist
targets (`messages`, `readings`) are **TimescaleDB hypertables**, so tests need a
real Postgres+TimescaleDB — **not** sqlite.

## The layers 

### Layer 1 — S3 importer against local JSON
Mock S3 with **`moto`**: upload each sample wrapped in the ear envelope
(`{"Payload": <sample>}`) under a realistic key
`hw1__1/eventstore/YYYYMMDD/{alias}-{type}-{ms}-{src}.json`, then run
`S3MessageImporter` end-to-end against a **`testcontainers`** TimescaleDB (after
`gw_data` `alembic upgrade head`); assert rows land. **Also assert idempotency:**
import the same date twice → row count unchanged (guards the `uuid5` fix).

### Layer 2 — `journal_keeper` AMQP path
**`testcontainers`** RabbitMQ + TimescaleDB. A gwbase-compatible publisher sends
the samples to the exchange/routing-key the consumer expects (mimicking
`ear_tx`/scada); run the `journal_keeper` consumer; poll the DB until the
expected rows land. Verifies the live-transport plumbing (the codec itself is
already covered by Layer 0).

## Shared core
Both transports call `SemaCodec` + `SemaMessagePersistor`. Test that core once
(Layer 0 + the persist assertions in Layer 1); Layers 1–2 then only verify their
transport adapters, not the codec.

## Infra / mechanics
- **`testcontainers`** (`timescaledb-ha` + `rabbitmq`) for local/CI parity (or GH
  Actions `services:`).
- **`moto`** for fake S3 (Layer 1).
- A `gw_data` alembic-migration step against the test DB.
- **TimescaleDB required** (hypertables) — no sqlite.
- `pytest` markers: `unit` (Layer 0, always) vs `integration` (Layers 1–2, slower/gated).
- Fixtures = the sema `samples/` (generated from `examples:`); only types with an
  example get a sample, which is fine — Layer 0 covers what exists.
- A small gwbase test-publisher helper for Layer 2 (the fiddly bit: correct
  exchange/routing/envelope).

## Rollout
1. **Layer 0 now** — tiny, no infra, catches the `atn.bid` class.
2. Wire the sema `samples/` emission (depends on the sema snapshot-improvement work).
3. Layer 1 (`moto` + `testcontainers`), incl. the idempotency assertion.
4. Layer 2 (rabbit).

## Verification / done
- Layer 0 green for every seeded type; deliberately removing a needed enum from
  the seed makes it **fail** (proves it guards the closure-gap bug).
- Layer 1: importing a date twice yields **equal** row counts (idempotent);
  an empty/missing date folder does **not** crash.
- Layer 2: a published sample lands as a `messages` row.

## Cross-refs
- `sema/spec/snapshot.md` — samples emission + build-time round-trip (design folded here, OPS-380).
- `sema/spec/authoring/formats.md` (the format→enum closure rule) — the bug class Layer 0 guards (design folded, OPS-378).
