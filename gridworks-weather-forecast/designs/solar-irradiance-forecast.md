Status: Draft · Pass 0 · Updated 2026-10-18 · Linear: OPS-597

**EDD: yes** verified when the weather service emits a solar channel for
Millinocket on the dev broker from a live Open-Meteo pull, and the
channel's forecasts can be scored against an observed series by hour
ahead.

# Add a solar irradiance forecast channel

## What this is

The weather service forecasts air temperature and wind speed for one
location from the NWS gridpoint hourly product. The house load model
the LTN is adopting (OPS-531) has a solar irradiance term, and nothing
in the fleet supplies it: the NWS hourly product has no irradiance, and
no GridWorks word names the quantity. This design adds global horizontal
irradiance as a forecast quantity, with Open-Meteo as its first
forecaster, under the service's existing posture that a forecaster is a
competing claim scored against an observed series.

## Facts the design rests on

- **Open-Meteo** publishes hourly `shortwave_radiation` (global
  horizontal irradiance, W/m², the mean over the preceding hour) to 16
  days, from HRRR, GFS, NBM, ECMWF and GEM. Hours are labelled by their
  end, in UTC unless a timezone is asked for. Its Previous Runs API
  returns the day-1 to day-7 forecast as issued for any hour back to
  January 2024, which is what skill scoring needs. The free tier is
  non-commercial; paid plan prices are not published.
- **The regression's `solar_w_m2`** is the same quantity, clipped to
  0..1361 W/m². Rows are keyed by hour start, so slice start is
  Open-Meteo's label minus one hour.
- **No measured irradiance exists near the fleet.** The nearest
  pyranometer is the USCRN station at Old Town, about 82 km south,
  hourly and complete for 2025 and 2026. ERA5 reanalysis covers
  Millinocket but is modelled.
- **NOAA's own archives** (HRRR, GFS, NBM on AWS) include downward
  shortwave radiation for every run, free, in GRIB. This is the
  commercial-grade path if Open-Meteo's terms do not fit, at the cost of
  GRIB decoding.
- The survey behind these facts is in the fit-on-the-box spoke of
  OPS-531 (quote not captured; read before citing).

## Vocabulary

Every word touched is `published`, so each change is a new version. The
sema spec and registry are change-controlled: each item below is
discussed before it is authored.

Done (published 2026-10-15): `gw1.quantity` 003 adds `Irradiance`,
`gw1.unit` 003 adds `WattsPerSquareMeter`, `MilesPerHourX10` and
`FahrenheitX10`, and `gw.weather.channel.gt` 001 binds both. The unit
enum states the scale convention: a scaled unit has one decimal digit
more precision than the accuracy of the best source that produces it.
NWS delivers whole degrees and whole mph, so the weather records move to
FahrenheitX10 and MilesPerHourX10; FahrenheitX100 stays the scada's own
temperature unit.

Authored as staging on sema `jm/weather-station` (2026-10-17; suite
green, uncommitted at session close), on top of the list reshape
committed as `63f9382`:

1. `gw.weather.station.gt` 000, new: the observing instrument at a
   place (Alias, DisplayName, LocationAlias, the ICAO/WBAN/GHCN/COOP
   ids, Start, Id). The instrument is identity; the path readings
   arrive by is provenance. `Alias = LocationAlias + "." + one segment`
   (`us.me.millinocket.kmlt`), the radio channel observations go out on.
2. `gw.weather.channel.gt` 002: `StationAlias` replaces `LocationAlias`;
   `Name = StationAlias + "." + lowercase(Quantity)` plus optional
   variant. New station or new unit, new channel: the X10 reissue is
   `us.me.millinocket.kmlt.temperature` at FahrenheitX10 beside the
   old X100 record under its old name.
3. `gw.weather.location.gt` 001: purely the place; the four station
   ids leave for the station record. Upgrade 000 to 001 drops them.
4. `gw.weather.observation.reading` 000, new (ChannelName, Quantity,
   Value) and `gw.weather.observation` 001: `StationAlias`,
   ObservationTime, Interpolated, `ReadingList`. A quantity the
   station did not report is absent. Upgrades from channel 001 and
   observation 000 refuse: the old record does not name its station.
5. `gw.weather.forecast.series` 000 and `gw.weather.forecast` 001
   (`SeriesList`), `gw.weather.forecast.binding` 000 and
   `gw.weather.forecast.bundle.gt` 002 (`BindingList`), per the list
   reshape. Bundle `Name = LocationAlias + "." + exactly one segment`,
   a short memorable handle that encodes nothing; the message drops
   its bundle-naming axiom. One binding per quantity; no quantity is
   mandatory.
6. `gw.weather.create.cmd` 002 binds channel 002, location 001 and the
   station record.

**Names, decided 2026-10-17.** Two Millinocket bundles:
`us.me.millinocket.bobcat` (temperature only, for the scada) and
`us.me.millinocket.raccoon` (temperature, wind, irradiance, for the
LTN). The last segment is a recipe: the same word at another location
means the same quantities, units, forecasters, grid and schedule, with
only the location and channel names differing; new units or a new
forecaster is a new animal. Enforcement is the DB's unique name per
location and the service's cross-record check once a second location
exists; nothing is parsed out of a name. Observation channels name
their station: `us.me.millinocket.kmlt.temperature` and
`.windspeed` at X10; irradiance waits on the station decision below.
Forecast channels keep `target + .forecast. + nws.hourly` /
`openmeteo.hourly`.


## One bundle

The solar channel joins the Millinocket bundle as a new bundle record
named `us.me.millinocket.forecast.hourly`: the bundle is now a
multi-forecaster object, so its name keeps only the shape and each
channel inside it names its own forecaster. The old
`us.me.millinocket.forecast.nws.hourly` record keeps emitting on the 000
message until its consumers move. The forecast channel records are
unchanged and the new bundle embeds them as they are, with the
existing temperature and wind observation records (the X10 reissue is
an open item below). The irradiance pair is `us.me.millinocket.irradiance` (Quantity Irradiance, Unit
WattsPerSquareMeter) and
`us.me.millinocket.irradiance.forecast.openmeteo.hourly`.

A bundle shares one slice grid and one emission schedule, so the
Open-Meteo pull is fitted to the NWS bundle's grid and slot: the fetcher
runs in the same emission cycle, reads the latest Open-Meteo run
available at that slot, and resamples nothing, since both products are
hourly. Each series walks its own fidelity ladder, so an Open-Meteo
outage marks irradiance Stored while temperature and wind stay Live, and
the downgrade glitch is per series.


## The forecaster record

Open-Meteo is a `Forecaster` with its own forecast channel for the
Millinocket location, model pinned rather than `best_match`, which does
not document which model supplies radiation at a US point. The pin is
`gfs_seamless`: HRRR at 3 km for the near hours and GFS beyond, both with
global horizontal irradiance native to the model, hourly updates, and
the full 48-hour horizon at every run (plain HRRR reaches 48 hours only
on the four synoptic runs). Variable `shortwave_radiation`, W/m², the
mean over the preceding hour. `Method` is
`open.meteo.gfs.seamless.hourly`; `SourceLocator` holds the coordinates.
Open-Meteo is not a replacement for NWS on temperature and wind. Those
stay NWS: no published comparison for the Northeast exists, the indirect
evidence favours the forecaster-edited NWS product, and the question is
settled by our own backtest later (Previous Runs API against observed
outdoor temperature in the journal DB).


The `gfs_seamless` splice has no run time of its own, so the series
stamp (`IrradianceSourceUpdatedTime`) is the GFS 0.13° run read from
Open-Meteo's model metadata endpoint
(`/data/ncep_gfs013/static/meta.json`, `last_run_initialisation_time`):
that member serves the splice across the whole 72-hour horizon.

## Time alignment

Bundle slices are labelled by start. Open-Meteo labels by end. The
fetcher subtracts one hour and works in UTC throughout; the alignment is
asserted in the fetcher's test with a fixed fixture, since a naive join
puts solar one hour late and nothing downstream would notice.

## Scoring and the archive

The service keeps every emitted forecast, so from go-live the solar
channel scores like the others. For last winter, the Previous Runs API
supplies the forecasts as issued; the scoring run for OPS-531 pulls
day-1 and day-2 forecasts for November to March at the Old Town
coordinates, scores them against the measured station by lead day, then
checks the ranking holds against ERA5 at Millinocket.

## Do this next

1. ✅ Author the three words, staging, through the sema gate;
   regenerate the runtime and the service's snapshot (sema `26e1456`).
2. ✅ The Open-Meteo fetcher beside `nws.py` with the hour-end to
   hour-start shift and a fixture test; per-series ladder in the
   scheduler; zeros at the template rung; the service schedules every
   bundle it holds, so the NWS bundle keeps emitting 000 beside the
   new one (weather branch `jm/solar-irradiance`, suite green).
3. ✅ The irradiance pair and the `us.me.millinocket.forecast.hourly`
   bundle minted in dev through `gwwf create` (2026-10-16); at the
   14:01 UTC slot `d1.weather` emitted forecast 001 with all three
   series Live (real NWS and Open-Meteo products) and the NWS bundle's
   000 beside it, no glitch. The local dev DB is at migration
   `a7e2c4d9b1f6` and holds both bundles.
4. ✅ The words reshaped as lists (sema `63f9382`) and the station
   record with channel 002, location 001, observation 001 authored
   on sema `jm/weather-station` (2026-10-17, suite green,
   uncommitted).
5. Commit `jm/weather-station`; the pending sema changelog entry is
   owed (its file was claimed by another session at close).
6. Rewire the weather service on `jm/solar-irradiance` to the new
   words: the bundle table's six channel columns become a membership
   join table, a stations table joins locations to channels, the
   observation stream publishes per station as a reading list, the
   scheduler builds `SeriesList` from the bundle's bindings with each
   forecast channel's Method choosing its adapter, and the forecasts
   table keys source revision per series. Fixtures move to the
   bobcat and raccoon names. The snapshot regenerates with
   `--allow-staged` (done for the list reshape; redo for the station
   words).
7. Mint in dev through `gwwf create`: location 001, station `kmlt`,
   the X10 channels and irradiance, the forecast channels, bobcat and
   raccoon; watch one slot emit both bundles. Then the scada's
   `weather_source.py` and the LTN move to forecast 001 and the new
   bundle names in one deploy day, since the old 000 message and the
   new word are mutually unreadable. Drop the old dev bundles after.
8. Publish bottom-up through `sema promote`; the published-only
   snapshot; the no-staging test.
9. The last-winter scoring pull reads from the archive of OPS-603
   (its step 2); record the result in `experiments/`.


## Open

- **The observed series.** Old Town is 82 km away. A closer candidate:
  the Weather Underground personal station KMEMILLI18 in Millinocket has
  a solar sensor, read by the scraper in `gridworks-house-parameters`
  (`weather_scraper.py`: five-minute rows averaged to the hour, gaps of
  up to five hours interpolated and flagged). Sensor quality is unknown;
  a hobbyist pyranometer behind an HTML scrape is a research series, not
  a fleet source. Whether the fleet's solar channel targets that station,
  Old Town, an ERA5 series for Millinocket, or nothing yet is open. A
  pyranometer at one house is the cheap way to a local series; a
  purchase question.
- **Licence.** Open-Meteo's free tier is non-commercial. Confirmed with
  Open-Meteo (2026-10-15): the fleet runs on the free tier until
  GridWorks is commercial, then $30 a month. Free-tier limits (10,000
  calls a day) are far above one location at one call an hour.
- **Specialist solar forecasters to investigate.** Solcast, SolarAnywhere
  and Tomorrow.io sell GHI/DNI/DHI forecasts on quote; none publishes an
  independent winter validation for the northeastern US. Investigate
  each for archive of forecasts as issued, hourly resolution at 48 h,
  price at fleet scale, and a trial we can score against the observed
  series. Worth a quote once the winter score shows GHI forecast error
  dominating the load regression. Published evidence to date favours
  ECMWF IFS over HRRR under cloud, so score `ecmwf_ifs025` against the
  Open-Meteo default first; it is one more model name in the same
  Previous Runs call.
- **The irradiance station.** The observed irradiance channel needs a
  station record before it can be named: the Weather Underground
  station in town (`kmemilli18`), Old Town, or an ERA5 cell are
  different instruments and so different channels. Until one is
  chosen the raccoon bundle's irradiance observation channel is the
  open item; the forecast side does not wait on it.
- **Consumers.** The LTN relays the bundle and the scada falls back to
  pulling it (`gw.operational.params` "WeatherBundleName"). Both decode
  the forecast word, so both move to the new version in the same wave;
  neither reads solar until the load model does.
