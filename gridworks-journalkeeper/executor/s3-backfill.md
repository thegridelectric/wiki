# S3 back-fill — loading the eventstore into the journal DB

Status: Draft · Pass 0 · Updated 2026-09-02

> What this is: how JournalKeeper loads archived eventstore messages into
> `gw_data`, and the rules that keep a load from corrupting the live era.
> The importer is `gjk.s3_message_importer`; the driver is
> `scripts/s3_bulk_load.sh`; the dev-DB harness is
> `experiments/2026-08-25-ops498-load/` (umbrella dir).

## What the journal holds

Status: Verified · Pass 0 · Updated 2026-09-02 · Reviewed 2026-08-25@38bd6e5 (`experiments/2026-08-25-ops498-load/`)

The database is populated from **2024-10-13**, the first full day of the
`report.event` era, through the present. The 2024-10-13 → 2026-01-08 span
was loaded from the S3 eventstore (2026-08-26/27); 2026-01-09 onward is the
live JournalKeeper's own record. Below 2024-10-13 the archive (back to
2022-08-20) carries `gt.sh.status` v110 — readings keyed by node alias and
telemetry name — which JournalKeeper does not accept; loading it would be a
separate decision.

Deliberately **not** loaded from the archive:

- `snapshot.spaceheat` — generates no readings (the channel time-series
  comes from `report.event`) and is ~90% of the eventstore's daily volume.
- `gridworks.event.problem` — its pre-2026 archive is dominated by a
  device-fault flap (2.9M messages in three weeks, Dec 2024 – Jan 2025);
  it feeds no readings and the live history since Jan 2026 suffices.
- The words the importer refuses because they carry no created time
  (`power.watts`, `atn.bid`, `latest.price`, the `gw.weather` cmd/ack/
  observation records); OPS-502 is the fix.
- The version-less proactor shapes that predate versioning
  (`gridworks.event.problem` with `TimeNS`, `snapshot.spaceheat:000`), and
  the proactor comm/lifecycle events (`gridworks.event.startup`,
  `.shutdown`, `.comm.*`, `gridworks.ping`, `gridworks.ack`) — real Sema
  words, not journaled.

The two gaps in the live record that a load did not fill — snapshots
Jan–Jul 2026 and the shorter `scada.params` / `ticklist.hall.report` gaps in
early 2026 — are an open decision, not an oversight.

## Idempotency — what makes a re-import safe

`messages` is keyed `(timestamp, id)` with `on_conflict_do_nothing`, and the
same holds for `readings`. A message dedupes across the rabbit and S3 paths
only when both halves of the key come from the payload; a path-dependent id
(`uuid5(from_alias | type | persisted_ms)`, where `persisted_ms` is receipt
time on one path and the ear's key time on the other) makes an overlap write
the message twice. So an import range for a type **must end strictly before
that type's earliest live row**, and those floors are captured once, before
anything is loaded (`FLOORS=<file>` in the driver), never re-derived from a
database that already holds back-filled rows. Which words carry an id, a
created time, both, or neither is tabulated in the OPS-502 design.

A back-filled row is indistinguishable from a live one: `timestamp` is the
payload's created time and `persisted_at` the S3 key time, and the read side
(`gridworks-web-backend`) selects on `readings.timestamp` alone.

## The channel-era model — why layouts load first

`reading_channels` rows carry no start date; a `(terminal_asset, name)` has
one active row and any number of retired ones, each identified only by its
`deactivated_date`. A channel's definition changes under one name across
layouts (`buffer-depth1` is a `WaterTempCTimes1000` data channel through 2025
and a `FahrenheitX100` derived channel from 2026), and the front end scales
readings by the row's unit, so a reading must attach to the row of its era.
`reading_channel_eras.channel_ids_at` picks, per name, the row with the
earliest `deactivated_date` after the report time, else the active row.

The live layout sync deactivates every active channel absent from the layout
it is processing. Run on a 2024 layout against prod, that would retire a
house's live channels. So a layout **older than the newest `layout.lite` in
`messages`** for its house syncs **add-only**: nothing active is touched, and
whatever it carries that is not active in the same definition becomes an era
row retired at the earliest newer layout's time.

Both mechanisms assume forward time order. Hence a load is two forward
passes: **pass 1 `layout.lite` only**, over the whole span, so every era row
exists before any report is read (Oct–Nov 2024 reports predate the first
wire layout and still find the Nov 2024 era rows); **pass 2 everything
else**.

## What a load does not do

- **Hourly derivatives do not self-heal.** The `readings_1hr` continuous
  aggregate policy and the `cached_hourly_data` refresh cover only the last
  two days. After a load: `refresh_continuous_aggregate` over the range, then
  a delete-then-insert rebuild of `cached_hourly_data`
  (`refresh_all_cached_hourly_data.py` appends and would double `hp_kwh_el`).
- **The importer fails loud, per message.** Unlike the live path, an
  undecodable message is counted and its S3 key written to `--rejects-log`
  (one JSON line: key, alias, type, persisted_at, error); the eventstore is
  the durable copy, so a reject is re-fetched by key, never stored here.
  Axiom rejections are real (142 `layout.lite:004` messages with a relay
  config whose event semantics contradict its normal state) and stay
  rejected.

## Running it

Per span, the committed entrypoint:

    python -m gjk.s3_message_importer --start <s> --end <e> \
      --message-types '~layout.lite,gridworks.event.problem,snapshot.spaceheat' \
      --alias-prefix hw1. --workers 8 --batch-size 500 --rejects-log <file>

`--workers` is the S3 GET prefetch pool; `--batch-size` rows per DB
transaction, with channel rows cached per session. Measured: S3 GET ~12 ms
prefetched, decode 0.5 ms, so the cost is the readings insert. The ceiling is
**database write concurrency, not CPU or S3**: 8 parallel importers gave zero
lock waits at ~17 msg/s each, 12 a few, 24 a lock-up. Run at most 12
concurrent spans, and watch
`select count(*) from pg_stat_activity where wait_event_type='Lock'`.

Run it from a throw-away box in the bucket's region (us-east-1) with an S3
read instance role and the writer `GJK_DB_URL` in a mode-600 env file outside
the checkout; the box runs a pushed SHA, and run-specific choices ride as
flags, never as edits. Completion check: the union of `Completed messages
for <day>` lines across all span logs equals the day set; a missing day is a
crashed span to relaunch (the load is idempotent, so relaunching re-scans
safely).

## Deleting from the live journal

A bulk delete on `messages` (the ~330k snapshot rows an early run loaded
before the skip decision) runs against the same hypertable the live
JournalKeeper writes to, so it is done as a **guarded batched loop**, never
one statement: 5,000-row batches, each its own transaction, with
`lock_timeout = 5s` and `statement_timeout = 30s` on the session so a batch
that meets the live keeper's locks fails fast instead of queueing behind
them; one printed row/seconds line per batch; stop on the first error rather
than retry, and resume by re-running (the predicate makes it idempotent). At
that batch size prod took 1.2–3 s a batch with the keeper live. The log of
that run is `experiments/2026-08-25-ops498-load/snapshot-cleanup.log`.

## Verification

Status: Verified · Pass 0 · Updated 2026-09-02 · Reviewed 2026-08-25@38bd6e5 (`experiments/2026-08-25-ops498-load/`)

`experiments/2026-08-25-ops498-load/edd_dev_run.sh` seeds the dev DB with
prod's `reading_channels` and newest layout per house — the shape a prod load
meets — then runs both passes over windows crossing every channel era and
asserts: active channel set unchanged; era rows end at each house's newest
layout; every (house, day) with reports has readings; buffer readings sit in
their era with the era's unit through the front end's own queries;
`readings_1hr` empty until the manual refresh; no degraded or enum-fallback
messages. `tests/test_channel_eras_backfill.py` covers the sync in both
orders and the era routing against a real TimescaleDB.
