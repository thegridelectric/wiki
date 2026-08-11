# journalkeeper-and-history — projection + the sad-duck import

Status: Draft · Pass 0 · Updated 2026-08-11

What this is: how weather lands in JournalKeeper and how the legacy
record is preserved, for [stand-up-weather-forecast](primary.md) —
plus the persistence grill. Both halves are designed jointly with Joe.

## Projection into JK pseudo-channels (proposed)

Sema-fy JK's PseudoChannel concept (the queued word gets its design
driver here): the flat format (name, display_name, unit, unit_type —
see [`evidence.md`](evidence.md)) becomes a sema word, and rich
weather channel records declare their own projection down into it.
Most of the projection is mechanically derivable — flat name =
dash-rendering of the LRD Name, unit = the channel's Unit, unit_type =
`gw1.unit` — so the declared knobs are only the genuinely per-channel
choices: JK-facing display name, whether to project at all, and
scoping (a location-scoped channel projects into rows for the TAs
subscribed to that location, making the per-TA duplication declared
rather than accidental). First instances: NEW observed-series
pseudo-channels for Millinocket temperature and windspeed — the
current-weather series JK has never had — with history filled by the
legacy import below.

## Historical actual weather — the legacy import

The fleet has no actual-weather series anywhere today (see
[`evidence.md`](evidence.md)). Import the S3 eventstore's legacy
`weather` messages ONCE into the new vocabulary, then retire the old
word.

- Each legacy observation imports as a plain `gw.weather.observation`
  (ObservationTime = the legacy `UnixTimeS`, which carried the true
  observation time — see the staleness finding in `evidence.md`;
  Interpolated false) into the same Millinocket channels as the live
  series: one clean series, one projection path shared with live
  messages. The legacy publish times survive in the raw archived
  messages; late publication is provenance, not part of the
  observation claim.
- Import mechanism: the same S3 source and importer pattern JK uses
  (`s3_message_importer.py`); the legacy word is decoded only at
  import, no patch service stays alive. The committed fixture (see
  `evidence.md`) is the import's reference input.
- **Backfill from archives** (NWS/NOAA historical, keyed by the
  location word's external ids) remains available for the gaps: legacy
  service-down windows, everything after 2026-07-18, and any station
  outage longer than the 3 h interpolation bound (real readings, so
  the bound does not apply).

## Do next — the persistence grill

1. The Joe conversation: the pseudo-channel word, projection knobs,
   table shape (location-scoped rows vs `reading_channels`),
   deactivating the twelve forecast-oat/-ws rows, JK handling of
   forecast messages (messages table only; readings stay
   current-only).
2. Service DB: revision-store schema; same `gridworks` database vs
   separate; analytics access model (design-intent opens).
3. First EDD witness — likely a dev-broker gwwf→JK round trip: a new
   observation word journaled and projected into the new
   pseudo-channels.
