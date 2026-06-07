# Design: Custom persistors — deterministic (uuid5) message ids

> Status: Accepted · Pass 1 · Updated 2026-06-07

What this is: a plan to close the re-import idempotency gap that the
`flo.params.house0` and `weather.forecast` custom persistors reintroduced by
minting their `messages.id` with `uuid4()` instead of the deterministic `uuid5`
that the default persist path adopted in `7308766`.

## Context

Commit `7308766` made `persist_message_default` derive the `messages.id` as
`uuid5(MESSAGE_ID_NAMESPACE, f"{from_alias}|{type_name}|{persisted_ms}")`, so a
re-imported S3 date is a true no-op: the `(timestamp, id)` PK +
`on_conflict_do_nothing` dedupes the row. (See
[`s3-importer-improvements.md`](s3-importer-improvements.md) — idempotent re-runs
are a stated steady-state requirement.)

`57f5340` then added two **custom** persistors — `FloParamsHouse0Persistor` and
`WeatherForecastPersistor` — that bypass `persist_message_default` and mint the
id themselves with `uuid.uuid4()`:

- `src/gjk/weather_forecast_persistor.py:114` — `message_id = uuid.uuid4()`
- `src/gjk/flo_params_house0_persistor.py:114` — `message_id = uuid.uuid4()`

**Impact.** Re-importing the same flo/weather message gets a fresh random id,
which dodges the `(timestamp, id)` dedupe and **duplicates the `messages` row**.
The derived `readings` are unaffected (deduped by `(timestamp, channel_id)`), and
provenance still resolves (`reading.message_id → messages.id`) — so this is a
duplicate-message-rows-on-backfill bug, not data loss or a provenance break. It
lands the moment a date range is re-run, which the bounded-backfill /
rolling-load model in `s3-importer-improvements.md` will do routinely.

**This is on `dev`** (the db_v2 line), **not `legacy`.**

## The complication: custom persistors don't get `time_received`

The fix is *not* a one-line `uuid4 → uuid5` swap. `SemaMessagePersistor.persist_message`
dispatches custom persistors as:

```python
custom_fn = getattr(custom_persistor, f"persist_v{payload.version}", None)
persistence_info = custom_fn(from_alias, payload)   # no time_received!
```

`persisted_ms` is derived from `time_received`, which the custom `persist_vNNN`
signature never receives — only `persist_message_default` does. So the dispatch
seam has to change too.

## The change

1. **Single id helper.** Extract the id derivation into one place — e.g.
   `default_message_id(from_alias, type_name, time_received) -> str` on
   `SemaMessagePersistor` (or a module function) — so the default path and every
   custom persistor compute the id identically and a future third custom
   persistor can't reintroduce the gap.
2. **Thread `time_received` to custom persistors.** Change the custom dispatch to
   `custom_fn(from_alias, time_received, payload)` and update
   `persist_v000` (weather) / `persist_v007` (flo) signatures accordingly.
3. **Use the helper.** Replace the `uuid.uuid4()` lines in both custom persistors
   with the shared `default_message_id(...)`. Keep passing that same id into
   `add_readings` so the `reading.message_id → messages.id` link stays intact —
   now deterministic, so a re-imported reading maps back to the same message row.

No schema or model change. No version bump on any sema type.

## Verification

- Unit test mirroring `tests/test_uuid5_message_id.py`: same
  `(from_alias, type, persisted_ms)` → same id for a `weather.forecast` and a
  `flo.params.house0` payload; different `persisted_ms` → different id.
- Re-import the same date range twice against a real Postgres+TimescaleDB
  (per the test-harness design) and assert the `messages` row count for these two
  types is identical after the second run.

## Status / workflow

Tracked in Linear (status / owner / priority live there). On implementation,
the durable distillate folds into `executor/primary.md` (the persist path's
idempotency invariant) and this design file is deleted per
[`../../designs-process.md`](../../designs-process.md).
