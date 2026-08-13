# g-node-alias-scoping

Status: Draft · Pass 0 · Updated 2026-08-13 · Linear: OPS-494

**EDD: no** build-out changes verified by the suites + the reader
sweep re-run against the changed shapes.

> What this is: the JK weather data-shape work that outlives the
> weather standup — the `reading_channels` scoping columns (the
> terminal_asset_alias misnomer and its About/MadeBy successor), and
> the one-time fill of legacy actual-weather data.

## Why

The `reading_channels.terminal_asset_alias` column got its first
non-terminal-asset occupant on 2026-08-13: the observed-weather
pseudo-channels are fleet-scoped and carry the weather GNode's alias
(`hw1.weather`) in this column. The value semantics already
generalized — every terminal asset alias IS a GNode alias — but the
name now lies.

The deeper why: readers across four repos and three live SQL objects
treat this column name as meaning, and no contract governs it — the
database acting as an implicit source of meaning, the failure mode
the sema boundary maxim exists to block (GridWorks_CLAUDE "Sema is
mandatory at every durable-data and inter-app boundary"). The durable
fix is the sema-fied pseudo-channel word (the OPS-436 JK thread),
whose declared scoping the table then merely projects.

## Scoping: AboutAlias + MadeByAlias (proposed 2026-08-13)

The pseudo-channel word's scoping splits in two, superseding both the
single column and the earlier single-`GNodeAlias` sketch:

- **AboutAlias** — what the series is about: the terminal asset for
  the legacy per-TA channels; the location-anchored subject for the
  weather series.
- **MadeByAlias** — the GNode that produces it: the scada;
  `hw1.weather`.

Consequence for the table: today's `terminal_asset_alias` likely
becomes the two columns `about_alias` + `made_by_alias` rather than
one renamed `g_node_alias`. The word-gate settles names and formats;
the migration follows the word.

## Reader inventory (swept 2026-08-13: code grep + live-DB catalog)

- **gridworks-data** (owner): `ReadingChannelSql`, the initial
  migration, and the SQL scripts `create_view_readings_1hr.sql`,
  `create_udf_retrieve_readings_1s.sql`, `create_udf_calc_energy_1hr.sql`,
  `create_udf_calc_hourly_data.sql`, `create_table_cached_hourly_data.sql`,
  `useful-scripts.sql`.
- **Live journal DB**: view `gridworks.readings_1hr` — a Timescale
  CONTINUOUS AGGREGATE, so the change rebuilds the cagg, not just
  ALTER — plus functions `retrieve_readings_1s`, `calc_energy_1hr`,
  `calc_hourly_data`.
- **gridworks-web-backend** (reads the journal DB via
  `journaldb_url`): v2 routers `synced_readings_bundle`,
  `hourly_electricity`, `installation_summaries`, `readings_csv`,
  `hourly_data_download`.
- **gridworks-journalkeeper**: `layout_lite_persistor`,
  `weather_forecast_persistor`, `weather_bundle_persistor`,
  `postgres_views.md`.
- **experiments** (ad-hoc analysis): `pull_readings.py`,
  `2026-08-03-pico-gap-analysis/*`.
- **gridworks-fleet**: `src/gwf/models/data_channel.py` + scripts —
  verify at execution time whether these hit the journal DB or
  fleet's own.

Legacy repos hold the string only in retired vocabulary — excluded.

## Fill legacy weather data (moved here 2026-08-13 from the OPS-436 JK spoke)

The fleet has no actual-weather series anywhere. The legacy `weather`
messages are imported ONCE into the new vocabulary — by **replaying
them through the bus**, not by a JK-side importer.

**The legacy word — TypeName `weather`, Version 000** (published;
sema registry), wire form:

    FromGNodeAlias:     left.right.dot  # hw1.isone.ws (the retired service)
    WeatherChannelName: left.right.dot  # weather.gov.kmlt
    UnixTimeS:          utc.seconds     # the TRUE observation time —
                                        # the legacy staleness was publish
                                        # lag, never a wrong timestamp
    OutsideAirTempF:    number (float °F)
    WindSpeedMph:       number (float mph), optional
    (axiom 1: WindSpeedNonNegative)

Sample: [`hw1.isone.ws-weather-1784374799353-ear.electricity.works.json`](hw1.isone.ws-weather-1784374799353-ear.electricity.works.json)
— an archived eventstore object, byte-identical wire form (the same
capture is committed in the gwwf repo as the conversion's reference
input, `tests/hw1.isone.ws-weather-1784374799353-ear.electricity.works.json`).

**Conversion → `gw.weather.observation/000`:**

- `ObservationTime` = `UnixTimeS` rendered ISO-8601 seconds
- `Interpolated` = false (these are real station observations)
- `LocationAlias` = `us.me.millinocket`
- `TempChannelName` = `us.me.millinocket.temperature`,
  `TempValue` = round(`OutsideAirTempF` × 100)
- `WindSpeedChannelName` = `us.me.millinocket.windspeed`,
  `WindSpeedValue` = round(`WindSpeedMph` × 1000) when present;
  absent stays absent

**The replay:**

1. **Collect locally.** Pull every legacy `weather` message from the
   S3 eventstore into a gitignored local dir (nothing under git).
2. **Convert** per the mapping above; the committed gwwf fixture is
   the reference input.
3. **Populate locally + emit.** The same script loads the converted
   series locally (dev-side verification against a local JK/postgres
   before anything touches prod) and then emits the messages onto the
   bus as ordinary observation broadcasts — the ear archives the
   converted history into the eventstore and JK journals + projects
   it through the exact same path as live messages. One pipeline, no
   import-only side door.
4. **Provenance holds by design.** Replayed messages carry their true
   ObservationTime; publish time = replay time, which the design
   already treats as provenance. Eventstore keys date by capture, so
   the converted history lands under replay-day keys — fine, because
   ObservationTime in the payload is authoritative and JK readings
   key on it.
5. **Idempotent + re-runnable.** JK's readings insert is
   on-conflict-do-nothing on (timestamp, channel); a re-run is safe.
   Pace the replay so it doesn't crowd live traffic.

Backfill from archives (NWS/NOAA historical, keyed by the location
word's external ids) remains available for the gaps: legacy
service-down windows, everything after 2026-07-18, and any station
outage longer than the 3 h interpolation bound.

## Plan

Deferred deliberately: rides the JK table-shape conversation with Joe
(per-TA scoping for the legacy channels, deactivating the legacy
forecast-oat/-ws rows, reader migration to the shared observed
series — see the OPS-436 JK spoke while it lives). When it runs:

1. Word-gate: author `gjk.pseudo.channel.gt` with the About/MadeBy
   scoping; the table becomes the word's projection.
2. gw_data migration per the word (column split/rename; drop +
   rebuild the `readings_1hr` continuous aggregate and the three
   functions).
3. Model + reader sweep per the inventory above, one coordinated
   change train (web-backend and gjk deploy together with the
   migration).
4. The legacy weather fill (above) — after the readings projection
   for observed-series channels exists.
5. Re-run the sweep greps to confirm zero stragglers.

Until then the column keeps its incorrect name and the weather rows
keep writing `hw1.weather` into it.
