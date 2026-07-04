# Scale story — what happens at a million homes

Status: Draft · Pass 0 · Updated 2026-07-04

> What this is: the answer to "what if this takes off — hundreds of thousands or
> millions of homes on the brokers?", worked layer by layer. The punchline: **the
> copper tree is the sharding key for everything**, and nothing canonized in the
> registry standup assumes one broker, one FIS, or one Postgres. Homed here
> because the registry's forest/alias machinery is the partition; it touches
> transport (gwbase), FIS, and the audit plane, with pointers.

Working numbers: 10⁶ homes ≈ **3×10⁶ GNodes** (LTN + TA + Scada each) plus the
copper backbone; steady-state traffic ≈ 10⁶ homes × ~1 msg/30 s ≈ **33k msg/s**,
a few GB/hour raw.

## Registry data: trivial

3M rows is small Postgres. Renames run ~yearly per node ≈ 0.1 writes/s
fleet-wide. The two real items are known: **subtree-scoped write-time
validation** (the whole-registry scan per write is the canonical MVP limit —
queued in the standup design) and a **`varchar_pattern_ops` index** on `alias`
so materialized-path prefix queries stay index-backed at millions of rows.

## The broker is the real constraint — and the tree partitions it

10⁶ connections and 33k msg/s exceed one comfortable RabbitMQ deployment. The
architecture's answer has been latent since "MarketMakers are fractal": the
**alias hierarchy is a natural partition**. Physically: a **tree of brokers
mirroring the copper tree** — each MarketMaker/regional domain runs its own
broker (cluster); homes connect to their subtree's broker; cross-subtree traffic
(market results up the chain, MM↔MM coordination) flows over thin federation
links — thin *because* the tree localizes traffic (a home talks to its LTN/MM,
not across the fleet). One **logical** universe (`w__1`), many **physical**
brokers. Everything already canonized respects the partition:

- **forests are subtree-scoped** (the scaling unit — nothing ever moves the
  whole world in one message);
- **broadcasts are root-keyed** (a rename under a copper node broadcasts on that
  subtree's channel, deliverable entirely within its broker);
- **FIS shards per authority subtree** (bounded `GNodeId ↔ alias` slice each);
- **single-writer is per (GNodeId, run)**.

**The one honestly undesigned piece: cross-broker routing** — how the `rj`/`rjb`
fabric spans federated brokers (key rewriting, federation vs shovel, where the
ear taps). Design it when the fleet approaches ~10⁴ homes; naming it here is the
point.

## Audit at scale: S3-first; Kafka stays deferred

33k msg/s ≈ 25 TB/yr raw. The path that holds: **ear → S3/files keyed
`<vhost>/<subtree>/<date>/…`** (run + partition in the key, per the audit
principle — run context is fabric context), then **columnar** (parquet) for
forensic/batch analytics (DuckDB/Athena); `gw_data.messages` gains
retention/partitioning or goes S3-only with Timescale keeping `readings`
aggregates. The audit workload is batch/forensic-shaped, which this serves
nearly free.

**Kafka remains demoted from "the plan" to "a possible later stage."** Its niche
— many independent consumers replaying ordered high-throughput streams — is
covered on the live side by the bus (RabbitMQ 4.x Streams exist if replayable-log
semantics are ever wanted on-broker) and on the batch side by S3+parquet. The
reactive framing cuts the same way: the bus is already the event plane; Kafka
would be a second bus. If a genuine cross-fleet *stream* consumer materializes
(e.g. ML features at 10⁵ msg/s), Kafka/Redpanda slots in **behind the same
ear→S3 seam** — the seam is the commitment, not the tool.

## The authority layer at scale (already canonized, pointers)

- **On-chain**: gnr's Postgres survives as the **indexer** — the chain is the
  log, the DB a rebuildable materialization with a proof trail; consumers of
  gnr's *interface* (forests, API) never notice the migration. See executor
  *Distributed-readiness*.
- **Downstream projections**: anything holding registry state (`gw_data`'s
  `g_nodes`/`connectivity_edges`, FIS's map) consumes the **interface** — forest
  broadcasts + the forest-request API — never gnr's Postgres directly. DB-level
  syncing would freeze storage internals into a public contract and break at the
  chain migration. A pass-one build of this pattern for the audit taps (gjk
  projecting `g.node.forest` into `gw_data`; a durable ear capture) is in
  flight; its distillate will land in the gjk/gw-data executors.
