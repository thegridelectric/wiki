# Weather history archive: history over the bus, into the journal

Status: Draft · Pass 0 · Updated 2026-11-15 · Linear: OPS-603

**EDD: yes** verified when the journal DB holds hourly temperature,
wind speed and irradiance readings for the Open-Meteo Millinocket
gridpoint station from 2024-10-01 to the present, every house's hourly
CSV has its weather columns filled over the same window, and the
spruce slab fit (`experiments/datasets/spruce-radiant-slab/`) runs from
journal readings with its gzipped CSV gone.

## What this is

The weather service keeps every forecast it emits, and JournalKeeper
journals its observation and forecast broadcasts, so from go-live
(2026-10-25) the fleet's own weather record is complete. Nothing holds
what came before: the hourly energy CSVs have no outdoor temperature or
wind before 2025-01-21 and no irradiance ever, and a long pull from an
outside source today ends as a CSV in an experiment folder. This design
fills the record with no new record words. An outside source's long
series enters as a station, and its history is replayed over the bus
as ordinary observation messages, so the ear archives it and
JournalKeeper journals it like everything else. The consumers are the
ones that already read the journal: the hourly functions behind the
CSVs, the visualizer, and experiment pulls.

## Facts the design rests on

- The station and channel words state that the path readings arrive by
  ("live API, archive backfill") is provenance per reading, so the
  record names no source or method (`gw.weather.station.gt` and
  `gw.weather.channel.gt` 002 descriptions). The observation word is
  archive-honest: the claim is that the station observed these values
  at ObservationTime, and publication lateness is provenance
  (`gw.weather.observation` 001). The forecast channel word allows
  hindcast channels for backtesting (`gw.weather.forecast.channel.gt`
  000).
- JournalKeeper's observation persistor fans out on import
  ("Observations are history; a replay fills the readings it missed",
  `gjk/weather_observation_persistor.py`), writing one readings row per
  channel per message, resolved by (weather GNode alias, channel name)
  against the journaled channel record.
- The executor already treats a model cell as an instrument: "an ERA5
  cell is a third instrument. Each is a different channel"
  (gridworks-weather-forecast executor `vocabulary.md` "Open").
- The fleet record has kmlt temperature and wind speed in the journal
  from 2026-10-25 (`hw1.isone.weather`, channels `kmlt-temperature`,
  `kmlt-windspeed`); the kmemilli18 irradiance channel has no
  observation stream (OPS-621).
- Open-Meteo serves an archived series stitched from its most recent
  runs (the Historical Forecast API; shortest-lead values, hourly, from
  2022) and forecasts as issued by lead (Previous Runs API), both free
  tier, non-commercial, CC BY 4.0. Not re-verified this session; read
  the endpoint docs before the first pull.
- The hourly functions (gridworks-data `calc_hourly_data`) fill `oat_f`
  and `ws_mph` from each house's `forecast-oat` and `forecast-ws`
  channels, which begin 2025-01-21 at the earliest house.
- Minting is a human act through `gw.weather.create.cmd` from the
  `<universe>.weatherminter` principal, acked or nacked over the bus
  (executor `record-lifecycle.md`). A cert belongs to one program, so
  nothing but the running actor publishes under the service's alias.

## The gridpoint station

One `gw.weather.station.gt` for the Open-Meteo Millinocket gridpoint:
a one-token alias, Millinocket's coordinates, no network identifiers,
DisplayName saying it is a model gridpoint. Three
`gw.weather.channel.gt` on it: temperature, windspeed, irradiance, each
in the unit the matching kmlt or kmemilli18 channel uses, hourly grid.
Four create commands, no sema change. The actual for irradiance is
this station's series; there is no measured irradiance in reach.

A composite actual is the consumer's, never a message's: the
observation word's axiom 4 keeps one station per message, so the hourly
function takes temperature and wind from kmlt where kmlt has a reading
and from the gridpoint otherwise, and irradiance from the gridpoint.
Each journal reading names its channel, so the composite is explicit.

## The replay

`gw.weather.archive.cmd`: one small command word (StationAlias, channel
Names, Start, End), sent by the minter, executed by the running actor,
answered by the existing ack or nack. On it the actor calls the
Open-Meteo adapter's long pull for the window, shifts irradiance one
hour back as the live adapter does, and publishes one
`gw.weather.observation` per hour on the station's radio channel,
Interpolated false, throttled so the keeper's loop is not swamped. The
ear archives each message under the key grammar; JournalKeeper writes
the readings. A re-run over the same window is idempotent at the
journal (readings conflict on timestamp and channel and are skipped)
and leaves a second copy in the eventstore with its own receipt time.
Two years is about 17,500 messages, one day of fleet traffic.

The live loop also emits the gridpoint station each hour, the
shortest-lead value for the hour just ended, from the same product the
forecast fetch already pulls, so the series stays continuous after the
backfill with no further command.

## The hourly columns

`calc_hourly_data` fills `oat_f` and `ws_mph` from the weather GNode's
rows: kmlt, then the gridpoint, then the house's `forecast-oat` and
`forecast-ws` where no observation exists; a new `ghi_w_m2` column from
the gridpoint. Units come from OPS-630's `unit_scale` join. Every house
binds to the Millinocket station by a constant in the function, with a
note naming the missing word: nothing yet states which station a house's
hourly weather is read from.

## The slab experiment

`pull_irradiance.py` and `irradiance-kmemilli18.csv.gz` go. The fit's
`load_solar` reads the gridpoint irradiance from the journal through
the existing `gw.readings` pull, or the archived observation files from
the eventstore. The README's evidence entry changes from external bytes
to a journal window.

## Later: forecasts as issued

Scoring a forecaster over a winter (OPS-597's deferred step) uses the
same mechanism and no new record word: a hindcast
`gw.weather.forecast.channel.gt` on the gridpoint station per lead,
bundled, and `gw.weather.forecast` messages replayed one per issue
time from the Previous Runs API. JournalKeeper's forecast persistor
keeps them by ForecastUid. Out of scope here.

## Do this next

1. Author `gw.weather.archive.cmd` (staging, through the sema gate,
   with the read-receipt sema-CLAUDE asks for); extend the actor's
   command consumer to execute it.
2. The Open-Meteo adapter's long pull for temperature, wind speed and
   irradiance over a window, and the hourly gridpoint observation in
   the live loop.
3. Mint the station and its three channels on d1, replay one month,
   check the journal; then hw1, replay 2024-10-01 to the present.
4. The hourly function change, tried on `tsdb_tap` then prod with a
   refresh of `cached_hourly_data`.
5. The slab experiment reads the journal; the gz and script go.

## Open

- **Licence.** Confirm the historical endpoints are within the agreed
  non-commercial terms before the bulk pull.
- **Alias.** The station alias is one lowercase token; pick one that
  reads as Open-Meteo at Millinocket.
- **Station word prose.** Whether `gw.weather.station.gt` gains a
  clarifying sentence that a model gridpoint is a station (prose only;
  the word is published).
