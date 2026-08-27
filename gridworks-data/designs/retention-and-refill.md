# retention-and-refill

Status: Draft · Pass 0 · Updated 2026-08-26 · Linear: OPS-503

**EDD: yes** verified on the dev DB first, then prod: after the snapshot
table lands, the dashboard's snapshot view still shows current state, the
`snapshots` hypertable holds no chunk older than ~2.5 hours, and `messages`
gains no `snapshot.spaceheat` rows; after the retention policy, one refill of
a dropped window from S3 restores its `messages` rows exactly once.

> What this is: gw_data becomes a rolling window over the S3 eventstore
> instead of forever storage. Each table keeps what its consumers read, for
> as long as they read it; anything older is a refill away.

## Why

Measured on prod, 2026-08-26 (13 houses):

- ~20.4k messages/day, ~963k readings/day. `snapshot.spaceheat` is 17.3k
  of those messages (85%), one per house per minute.
- `readings`: 65 seven-day chunks, compression after 14 days, 32 GB → 1.3
  GB. Cheap, ~5 MB/day compressed.
- `messages`: 93 seven-day chunks, none compressed, no policy, 8.5 GB at
  ~4 KB/row, growing ~80 MB/day. At 100 houses that is ~220 GB/year on a
  managed service billed by storage.

Insert throughput is not the constraint: live is 0.24 msg/s and the back-fill
sustained ~100 msg/s. Storage growth and read cost on uncompressed recent
chunks are.

The S3 eventstore holds every message forever, and the JournalKeeper importer
(OPS-498) can load any window from it, so rows the dashboards no longer read
do not need to stay in the database.

How long a row is worth keeping is a property of its message type, not of
the row: snapshots are current state (minutes), reports and problems are
season-relevant (a heating season), weather is the irreplaceable ground
truth for analytics (forever). The `messages` retention below applies to
whatever a persistor does not route to a typed table, so any type that must
outlive it (weather today) needs its own table, not an exception in the
policy.

## 1. Snapshots get their own table (do first)

`snapshot.spaceheat` exists so near-real-time views have current state. The
web backend reads it only from the last 10 minutes before the requested end
(`gridworks-web-backend/api/backend_api.py:454-455`); readings come from
`readings`, not from snapshots. Nothing reads snapshot history.

- New hypertable `gridworks.snapshots (timestamp, from_alias, payload
  jsonb)`, **30-minute chunk interval**, `add_retention_policy` at **2
  hours**. Timescale drops whole chunks, so the live window floats between
  2 and 2.5 hours; the retention interval must be at least the chunk
  interval, which is why the chunk is small. No compression policy.
- JournalKeeper's persistor routes `snapshot.spaceheat` to `snapshots` and
  writes no `messages` row. Snapshots need no exactly-once identity
  (last-wins is the semantics), so the message-identity work (OPS-502) does
  not apply to them.
- The web backend's snapshot query moves to the new table in the same
  change.

Effect: `messages` loses ~85% of its new rows and ~70 MB/day of growth.

## 2. Compression on `messages`

`add_compression_policy` after 7 days, `compress_segmentby` on
`from_alias, message_type_name`, `compress_orderby` on `timestamp`. No
behavior change; `payload` jsonb compresses well.

## 3. Retention on `messages`, refill from S3

`add_retention_policy` at ~180 days. A consumer that needs an older window
runs the JK S3 importer over that window; with OPS-502 in place the refill
is exactly-once whether or not part of the window is still present. Until
then, refill only windows that are entirely dropped. `readings`, the
continuous aggregate and `cached_hourly_data` keep their current policies.

## 4. The write ceiling, as a number

The 2026-08-26 stress run locked the database at 24 writers and ran at
~100 msg/s with 8. One ramp experiment against the ops498 harness (4 → 8 →
16 → 24 writers, sampling `pg_stat_activity` wait events and connection
count against `max_connections` = 105) names the cause and gives a real
ceiling to plan the fleet against. Expected outcome: the fleet at 100 houses
(~2 msg/s, ~85 readings/s) sits far under it.

## Order

1 → 2 → 3, each landing with a row-level check on the dev DB
(`gw-data-pg`) and then prod; 4 whenever the loader box is free. Joe is in
the loop for the gw_data tables and the web-backend query.

## Open

- Whether `snapshots` keeps the sema payload as jsonb or the persistor
  unpacks `LatestReadingList` into columns the backend can select directly.
- The exact `messages` retention length; 180 days is a starting point
  matching "one heating season in the database".
