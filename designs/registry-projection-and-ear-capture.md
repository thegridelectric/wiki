# Registry projection + ear raw capture (audit taps, pass one)

Status: Draft · Pass 0 · Updated 2026-07-13 · Linear: OPS-443

**EDD: yes** the verification is a local multi-service dev-universe experiment —
gnr + gjk + an ear capture consumer + broker + both Postgres instances on one
machine (a dev universe *by definition*: all comms through localhost brokers); a
re-parent published on the bus must land in the `gw_data` projection and in the
raw capture, unprompted.

> What this is: the two audit taps catch up with the registry's new surface.
> **gjk** learns `g.node.forest` and projects it into `gw_data`'s registry
> tables; the **ear** gains a durable raw-capture consumer. Multi-repo
> (gridworks-journalkeeper, gridworks-data, ear tooling), hence cross-cutting.
> Coordinate with the gw_data/gjk maintainer before implementing — the **seam**
> is the decision here; the code is small.

## The seam (the actual decision)

Anything holding registry state consumes the registry's **interface** — the
`g.node.forest` broadcasts (deltas + periodic snapshots) and the
`g.node.forest.request` API — **never gnr's Postgres directly**. A DB-level sync
(FDW / dump / daily replication) would freeze gnr's storage internals into a
public contract, serve up-to-24h-stale topology, and break outright when
authority moves on-chain. Consuming the interface is chain-proof: broadcasts
later carry proofs; the consumer code never changes. (Scale + chain context:
`wiki/grid-node-registry/explorations/scale-story.md`; the audit principle:
gwbase `executor/transport.md` §3.7.)

Consequences for `gw_data`:

- `g_nodes` / `connectivity_edges` become **projections** — written only by the
  gjk fan-out below, never independently.
- `position_points` inherits the registry's privacy staging: **empty** (opaque
  `position_point_id`s only) until the TaValidator encryption mechanism lands —
  see `wiki/grid-node-registry/explorations/positions-staging-and-encryption.md`.

## Strand 1 — gjk projects `g.node.forest`

gjk's central commitment already fits: `all_known_message_types()` is the single
source of truth for what it binds and persists. So:

1. Add `g.node.forest` to gjk's vendored snapshot + known-types set → the
   message is captured into `messages` like any other Sema type (zero new
   transport code; gjk binds the broadcast alongside its existing slices).
2. A **fan-out step** (the `readings` precedent) upserts the forest's nodes and
   edges into `gw_data.g_nodes` / `connectivity_edges` keyed on immutable ids —
   idempotent, so deltas, snapshots, and replays all converge the same way.
3. Bootstrap/resync: one `g.node.forest.request` per configured root against
   gnr's read API (`POST /gnr/g-node-forest-request`); the periodic snapshot
   broadcast is the ongoing anti-entropy.

## Strand 2 — ear raw capture

Today `ear_tx` is a tap with no durable consumer — the raw comms trail
evaporates. Add a thin consumer (an `ActorBase` tap, the tier built for exactly
this) that binds its slice of `ear_tx` and appends raw messages to
files/S3 keyed **`<vhost>/<date>/…`** — the run in the key per "run context is
fabric context", never in bodies. No decoding, no filtering: the point is
lossless capture; parquet/columnar is a later batch step (scale-story).

**Two sinks, two custodians.** The consumer is a plain bus subscriber, so a
second capture path is just a **second independent instance with a different
sink**: one writes S3 (durability by replication), one writes plain files on
GridWorks-owned hardware outside any hyperscaler — the system's memory must
not depend on one corporation's continued goodwill, and this capture is the
grid-node-registry's durability store (executor *Durability*), so a
sovereignty-aligned copy matters beyond ops. Same stream, same content
hashes: the two stores reconcile by hash-set comparison, and divergence
detection doubles as the capture's own anti-entropy check. The non-AWS box
is deliberately the *second* copy — weaker operations are acceptable because
independent failure domains are the point — with disk encryption and clear
physical custody. Neither sink is ever on the write path: capture is
best-effort per consumer; durability is the union. This second-sink pattern
is also the near-term, honest step toward the decentralized record — the
full answer for the *registry* specifically is the chain seam
(gnr executor *Distributed-readiness*), which this does not replace.

## The experiment (what Verified means here)

A **local multi-service dev harness** — the first fleet-level dev-universe
experiment, and a template for more:

1. Boot broker (`gw-dev-rabbit` or testcontainers), gnr + its Postgres (seeded
   dev universe), gjk + `gw_data` Postgres, the ear capture consumer — all
   localhost (`d1__1`).
2. Bootstrap: gjk pulls the forest under the dev roots → `gw_data.g_nodes`
   matches the seed.
3. Publish a `g.node.reparent.cmd` as a MarketMaker → gnr broadcasts the forest
   → **gjk's projection updates** (beech re-aliased in `gw_data`) and **the ear
   capture holds the raw command + broadcast** under `d1__1/…`, with no direct
   coupling anywhere.
4. `broadcast_snapshot` → a deliberately-corrupted projection row heals
   (anti-entropy).

## The channel corollary (canonized here; the same seam, one level down)

**Channel declarations have one home: the layout sema words** (generated from
per-home seed config by the hardware-layout gen pipeline; the axioms — e.g.
house0 Axiom 3 ZoneHeatCallChannel — are the bijection). `gw_data.reading_channels`
is a **projection** of layout broadcasts (gjk's `LayoutLitePersistor` already
implements this seam); channels are never hand-authored in consumer code. gjk's
pseudo-channels are a **legacy backfill tier, marked for sunset** as layouts
complete. A separate channel registry would be a dual authority — don't. (The
terminalasset-registry's natural role is holding/serving **layout identity per
TA**, not duplicating channels — that call belongs to its own design.)

## Parked until spruce-unlimbo lands: heat-call in gw_data

The field produces no useful heat-call data yet, so this waits — parked, not
forgotten. PR #169's gjk-side heat-call synthesis (pseudo-channel + thresholded
whitewire readings) is a backfill for the stale-fixture era. When the
regenerated layouts ship heat-call as a **DerivedChannel** and the SCADA
publishes the readings itself, two known interactions need the fix below first:
(a) `get_pseudo_channels` guards only `data_channels`, so a derived heat-call
channel yields a **duplicate channel row** (the shared sync map `del`s the name
before the pseudo pass); (b) the synthesis write-path has no guard, so real +
synthetic readings interleave. **The self-sunsetting fix:** creation guard on
`data_channels ∪ derived_channels`, and synthesis per-message only when the
report carries whitewire readings and **no** heat-call readings — historical
backfills keep working, upgraded scadas pass through untouched, no flag day.
Per-site wattage thresholds eventually ride the layout's DerivedChannel
declaration, not a dict in the persistor.

## Not in scope

Kafka (deferred behind the ear→S3 seam — scale-story); the chain itself; FIS
(same pattern, its own design, OPS-420/422); gw_data retention/partitioning.
