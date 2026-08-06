# Registry projection + ear raw capture (audit taps, pass one)

Status: Accepted · Pass 1 · Updated 2026-08-05 · Linear: OPS-443

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
gwbase `executor/transport.md` "Message properties".)

Consequences for `gw_data`:

- `g_nodes` / `connectivity_edges` become **projections** — written only by the
  gjk fan-out below, never independently.
- `gw_data` holds **no position content**: OPS-488 drops the
  `gw_data.position_points` table and FK (ciphertext never rides the bus, so
  there is nothing for the projection to hold); the fan-out stores the opaque
  `position_point_id` verbatim — see
  `wiki/grid-node-registry/explorations/positions-staging-and-encryption.md`.

## Strand 1 — gjk projects `g.node.forest`

gjk's central commitment already fits: `all_known_message_types()` is the single
source of truth for what it binds and persists. So:

1. ✅ (2026-07-28, `jm/forest-snapshot`) Add `g.node.forest` to gjk's
   vendored snapshot + known-types set → the message is captured into
   `messages` like any other Sema type (zero new transport code; gjk binds
   the broadcast alongside its existing slices). `g.node.forest.request`
   vendored too for step 3. Side condition hit: the sema staging tier makes
   published-only snapshots the default, so `layout.lite` is pinned to
   published `["007","012"]` until 013+ promote.
2. ✅ (2026-07-28, `jm/forest-snapshot`) A **fan-out step** (the `readings`
   precedent) upserts the forest's nodes and edges into `gw_data.g_nodes` /
   `connectivity_edges` keyed on immutable ids — idempotent, so deltas,
   snapshots, and replays all converge the same way. Grounding that held:
   gnr's reparent never touches edge rows (the tree is the alias prefix)
   and the alias ledger forbids cross-node alias collisions, so pure upsert
   converges; missing-endpoint edges skip until a forest carries them; an
   edge id is immutable for its (from,to) pair — lifecycle rides Status on
   the same id, so a new id claiming a held pair is skipped as an anomaly,
   never absorbed. Dev-rig verified end-to-end 2026-07-29 (real dev broker:
   gnr snapshot broadcast → 28 nodes + edge projected, SendTimeMs →
   created_at, replay idempotent) — the rig caught a binding gap the
   in-code tests could not (channel-tailed rjb keys). The projection
   currently NULLs `position_point_id` (FK target rows can never exist);
   OPS-488 removes the table + FK so the id projects verbatim.
3. ✅ (2026-08-05, `jm/forest-snapshot`) Bootstrap/resync: one
   `g.node.forest.request` per requested root against gnr's read API
   (`POST /gnr/g-node-forest-request`) — `src/gjk/forest_bootstrap.py`,
   projecting through the same fan-out as live broadcasts
   (`project_forest`), projection only, no `messages` row. Rig-verified
   (28/28 nodes); the prod bootstrap runs after the branches land and
   deploy. The periodic snapshot broadcast is the ongoing anti-entropy.

## Strand 2 — the seed ear (registry raw capture; settled 2026-07-21)

The registry's meaning-bearing stream gets its own small store, so the seed
data that recreates "where meaning lives" is findable at a glance instead of
drowned in the telemetry torrent. Five pieces, first three shipped:

1. ✅ **The slice is fabric-defined** — `gnr_ear_tx` (gwbase 0.5.7): an
   internal exchange fed by `gnr_tx → gnr_ear_tx` and `gnrmic_tx →
   gnr_ear_tx` (`#` both), i.e. everything said TO the registry and BY it —
   commands, forest broadcasts, and the ack/nack write verdicts (refusals
   included, since every actor publishes via its own mic). The slice lives
   in git and boots with the broker; broker updates are **definitions-only**
   (update the boot file, restart to converge — never hand-declared
   entities).
2. ✅ **The capture is the proven ear, re-pointed** — gridworks-ear's
   consume exchange is configuration (`EAR_CONSUME_EXCHANGE`, default
   `ear_tx` so the universal ear is untouched). The **seed ear** is a second
   instance: `gnr_ear_tx` in, bucket `gw-seedstore` out. No new capture
   code; identical key grammar (`<vhost>/eventstore/<date>/<from>-<type>-<ms>-<source>`),
   so every reader works by swapping the bucket name.
3. ✅ **The store** — S3 bucket `gw-seedstore`, versioned, its own tight
   policy; deliberately NOT the misnamed `gwdev` (which stays the untouched
   universal archive). Holds the maiden genesis (2026-07-21) including a
   hand-backfilled copy of the genesis objects, kept by explicit decision.
4. **Home: the gnr box** — the seed ear runs as a systemd unit per the gwbase service-deployment pattern on the
   registry's own box (modern tooling, deploy discipline, off-hyperscaler
   direction). Witness *independence* is carried by the universal ear in
   `gwdev`, so colocation costs only capture continuity, recoverable by
   key-filtered copy.
5. **The compact store lives on Backblaze B2 — not AWS.** The seed ear
   writes directly to B2's `gw-seedstore` bucket (S3-compatible; the ear's
   `AwsClient` gains an optional `endpoint_url`, provider-agnostic). No AWS
   seedstore bucket: `gwdev` already holds the seed slice losslessly
   (key-filterable — proven by the genesis backfill), so a second AWS
   bucket added findability, not safety — and findability moved to B2.
   Chosen over Hetzner Object Storage (EU-only; ~€5/mo minimum; and the
   box already being Hetzner would concentrate custody, not spread it) and
   Wasabi (1 TB + 90-day minimums). B2: no minimum, first 10 GB free,
   versioned by default, Object Lock enabled at bucket creation. Operator
   setup: B2 account + bucket + bucket-scoped Read/Write app key
   (hard-expires under B2's <1000-day cap — rotation is OPS-460's yearly
   beat).

   The custody map is deliberately three copies in three ownership
   domains, nothing redundant: `gwdev` (AWS — the full torrent),
   B2 `gw-seedstore` (the compact primary), and the box's own Postgres
   `command_log` on the LUKS volume (every applied command, no cloud
   needed). A same-disk file mirror of the bucket was considered and
   dropped: `command_log` already owns that failure domain. Likewise
   parked: a gnr-owned on-box refusal log — the registry testifying about
   itself is a diary, not a witness; refusals are dual-cloud-witnessed by
   the ears and operationally visible in the box journal. If forensics
   ever want it locally, it is a small additive table.

No decoding, no filtering, lossless; parquet/columnar stays a later batch
step (scale-story). The full-torrent capture of `ear_tx` itself (beyond the
registry slice) remains open — the universal ear already persists to S3, so
its second-custodian copy can follow the same B2 pattern when wanted.

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

## Strand 2 execution runway (in order)

1. ✅ **Land the commit stack** — sema (`g.node.cmd.ack`/`nack`), gnr (typed
   verdicts + CA scoping), gridworks-ear (configurable exchange), gwbase
   0.5.8 (gnr_ear_tx + debug queue/policy in definitions).
2. ✅ **Broker definitions restart** — executed; the fleet reconnected and
   `gnr_ear_tx` + the debug queue are live. Procedure recorded as the
   standing rule in `gridworks-infra/rmqbot/instance-README.md`.
   (Original runbook kept for reference; the standing rule:
   **definitions-only, never hand-declared entities** — live state converges
   to the boot file by restarting, and the fleet's clients all reconnect on
   their own backoff):
   1. On the rmqbot box: `grep -r definitions ~/rmq-docker/` to confirm the
      mounted filename; back it up
      (`cp <file>.json <file>.json.bak-pre-057`); fetch the pushed artifact
      (`curl -fsSL https://raw.githubusercontent.com/thegridelectric/gridworks-base/main/rabbit/rabbitconfig/hybrid_definitions.json -o <mounted-file>.json`);
      sanity `grep -c gnr_ear_tx` → 3.
   2. Baseline `docker exec rmq1 rabbitmqctl list_connections | wc -l`, then
      `docker restart rmq1`. Durable queues + persisted messages survive.
   3. Watch: connections back to baseline (~1–5 min); `list_exchanges`/
      `list_bindings -p hw1__1 | grep gnr_ear_tx` (1 exchange + 2 bindings);
      gnr box `gnrstatus` green; a fresh scada message landing in the ear's
      S3. Rollback = restore `.bak`, restart again.
   4. Known limit: boot-loading is additive — it never deletes live
      entities missing from the file; delete-direction drift wants an
      occasional diff.)
3. ✅ **Operator credentials** — Backblaze B2 bucket + bucket-scoped app
   key (1Password "Backblaze B2 — gw-seedstore writer"; endpoint
   `s3.us-east-005.backblazeb2.com`); broker users for both ear logins
   live (`hw1.ear`, `hw1.gnr.ear` — recorded in
   `gridworks-infra/persistent-store.md`). No AWS credential for the seed
   store — it is B2.
4. ✅ (shipped: `ear@ear` + `ear@gnr-ear` live on `ear.electricity.works`,
   Hetzner cpx11, per-person keys; recorded in
   `gridworks-infra/ear/instance-README.md`, `platform-inventory.md`, and
   `persistent-store.md`; no EC2 ear remains in the platform inventory.)
   **Both ears deploy to a new Hetzner ear box** (committed code only) —
   its own instance, deliberately NOT the gnr box: the registry box stays
   registry-only, so an instance freeze takes out one function, never the
   authority plus both witnesses together. (An earlier draft colocated
   the ears on the gnr box; the blast-radius argument won.) The universal
   ear leaves EC2 in the same redeploy: the machine moves now, any gwdev
   store port is a separate later decision. The gridworks-ear repo
   follows the gwbase service-deployment pattern: `service/` holds one
   generic template unit `ear@.service` — instance name = login —
   run as `ear@ear` (exchange `ear_tx`, `gwdev` on AWS) and `ear@gnr-ear`
   (exchange `gnr_ear_tx`, `gw-seedstore` on B2), with per-login aliases
   and one generic env template; the
   env wire is `EAR_S3__*` (renamed from `EAR_AWS__*` — allowed because
   both instances get fresh `.env`s). The box needs no inbound surface
   beyond ssh — outbound AMQP to the broker and HTTPS to the stores.
   Bring-up order avoids an audit gap: the new universal ear is up and
   landing objects **before** the EC2 ear stops — a brief overlap means a
   few duplicate keys (distinct receipt-ms, harmless); a gap means
   unwitnessed messages. Then the EC2 ear box retires. New-box
   instance-README, `production-inventory.md`, and
   `persistent-storage/ear.md` updated (gridworks-infra is with another
   session — coordinate the docs handoff).
5. ✅ **Proof**: a `gnr create` appears in B2's `gw-seedstore` seconds later —
   one command, three custodians (gwdev, B2, the box's `command_log`), zero
   hunting. (Confirmed 2026-08-05.)
6. ✅ (2026-08-05) **After the proof**: set the B2 bucket's default retention (Object Lock
   was enabled at creation, deliberately without retention during bring-up;
   governance mode, ~1 year — then even a compromised app key can't
   rewrite the audit trail). And **credential rotation is scheduled, not
   aspirational**: the B2 app key hard-expires (B2 caps duration < 1000
   days); a yearly Linear recurring issue (OPS-460) rotates it, with the
   seed-ear broker user on the same beat. The daily
   rabbit-definitions-vs-broker check shipped inside step 9's
   `check-drift.sh`.
7. **Post-launch (clock stopped before here) — gridworks-base cleanup**:
   the treatment the ear repo got — conform to the service-deployment
   template where applicable, clean up the README, and remove the old
   poetry cruft generally. Its own small work item, not part of this
   launch's hours.
8. **Post-launch — design ↔ Linear reconciliation**: the bijection sweep
   the session hooks keep flagging (wiki designs without `design`-labeled
   issues, labeled issues whose design files were deleted on completion
   but kept the label). Routine per `linear.md` "Keeping in sync". The
   checker fix shipped 2026-07-27 — `precheck-design-bijection.sh` skips
   closed issues on the issue→wiki side, clearing the 19 false alarms.
   Triage done 2026-07-27: 8 Backlog issues created (OPS-464–471), 3
   designs deleted (web-app-words-to-types + both gridworks-data). One
   deliberate remainder: `layered-test-harness` flags until the OPS-386
   block distills-and-deletes it (the harness shipped).
9. ✅ **Verify platform services match pushed main** — `check-drift.sh`
   installed in `wiki/tools/` and registered as a SessionStart hook
   (2026-07-27), self-throttled to once per calendar day — live ssh
   checks (checkout == origin/main + clean; every service process newer
   than the checkout's last commit; ear retry caches empty; the
   rabbit-definitions-vs-broker diff from step 6's wish, via the rmqbot
   ssh entry), printing only problems. Chosen over a box-side cron or a
   recurring Linear issue: the check only matters when an operator is
   present to act, and this way needs no new secrets, no box machinery,
   no issue ceremony. Maiden runs found real drift (gnr-api running
   pre-pull code — fixed; the gjk host-key change — with Joe). The
   loop-watcher (`check-loops.sh`) and dep-staleness advisory hooks
   installed alongside it.

### Forward note — terminalasset-registry seed capture

The terminalasset-registry, when it arrives, emits seed data too — and
likely more of it than gnr does. Keep the slices separate: its own tap
exchange (`tar_ear_tx`), its own ear instance (a third login + unit per
the pattern), its own store. Mixing it into `gw-seedstore` would bury the
most precious stream inside a bigger one, which is the failure the seed
ear exists to prevent. The marginal cost of another instance is one login,
one unit, one `.env`.

## The experiment (what Verified means here)

✅ Run 2026-08-05, all four legs PASS — reproducer + full findings in
`experiments/2026-08-05-registry-projection-rig/`. Not wire-exercised:
edge projection (no seeded edge; unit-covered).

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
