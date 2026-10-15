Status: Draft · Pass 0 · Updated 2026-10-15 · Linear: OPS-597

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

1. `gw1.quantity` 003 adds `SolarIrradiance` (global horizontal, the
   quantity a pyranometer reads).
2. `gw1.unit` 003 adds `WattsPerSquareMeter`. Whole watts suffice; no
   scaling factor. The same version is the chance to add the unscaled
   units the enum lacks, so a reader of a value need not divide:
   candidates `Fahrenheit`, `Celsius`, `Kilowatts`, `KilowattHours`,
   `Gpm`, `MilesPerHour`, `Dollars`, `Percent`. Which of these go in is
   chosen with the human; each needs a row in the projection below.
3. `gw1.unit.quantity.projection` gets a new version whose table has a
   row for every unit added, `WattsPerSquareMeter` to `SolarIrradiance`.
   Its `000` still references `gw1.unit/001` and `gw1.quantity/001`, so
   the new version also rebinds to the current enum versions.
4. `gw.weather.channel.gt` 001 rebinds `Quantity` and `Unit` to the new
   enum versions; a solar observation channel is then an instance of it.
   `gw.weather.forecast.channel.gt` needs no change. The scada
   snapshot's reverse-dependency index shows the rest of the ripple is
   optional: `derived.channel.gt`, the two layout words and
   `data.channel.gt` bind to older enum versions and stay there until
   they want a new unit.
5. `gw.weather.forecast.bundle.gt` 001 and `gw.weather.forecast` 001
   gain the solar pair. Today both words name temperature and wind as
   fixed field pairs. The choice is between a third optional pair
   (`SolarForecastChannel`, `SolarObservationChannel`;
   `SolarChannelName`, `SolarValues`) and a list of channel pairs. The
   optional pair is the smaller change and keeps every existing bundle
   valid; the list is the shape a fourth quantity would want. Decided
   with the human before authoring.

## One bundle

The solar channel joins the Millinocket bundle. A bundle shares one
slice grid and one emission schedule, so the Open-Meteo pull is fitted
to the NWS bundle's grid and slot, not the other way round: the fetcher
runs in the same emission cycle, reads the latest Open-Meteo run
available at that slot, and resamples nothing, since both products are
hourly. How a stale Open-Meteo run is handled at a slot (emit the last
good values with the bundle's fidelity, or hold the slot) is decided in
the fetcher and recorded here.

## Cost of the enum bump

Every referrer of `gw1.unit` and `gw1.quantity` binds to one enum
version and accepts only that version's values, so the bump propagates
exactly as far as the words that must speak the new values, and no
further. Two closures, read from the scada snapshot's reverse-dependency
index and the registry statuses:

- **Solar only.** `gw1.unit` 003, `gw1.quantity` 003,
  `gw.weather.channel.gt` 001, `gw.weather.forecast.bundle.gt` 001,
  `gw.weather.forecast` 001. Five new versions, all weather words, no
  layout touched. `gw1.unit.quantity.projection` stays at 000: the
  weather words do not use it.
- **Friendly units for derived channels.** Adds
  `gw1.unit.quantity.projection` 001 (published, new version), which
  `derived.channel.gt` depends on, so `derived.channel.gt` 003
  (published, new version), which `gw.house0.layout`, `gw.nolan.layout`
  and `layout.lite` depend on. Those three are staging, so they rebind
  in place, but every layout gen, fixture and hand-written twin
  regenerates. The same closure runs from `gw1.quantity` through
  `data.channel.gt` 004 to the layouts and
  `scada.control.capabilities`. This is a layout-stack wave.

The scada twins add a second cost. `gwsproto` holds one `Unit` class and
one `Quantity` class, both at 002, while `derived.channel.gt` 002 binds
unit 001 and quantity 001 and `data.channel.gt` 003 binds quantity 000.
The twin validates every word against the newest enum, so a derived
channel naming a 002-only unit passes the scada and fails sema. The
weather words are the only referrers bound to 002, which is why they
decode correctly at the scada today. A bump to 003 moves the twins to
003 and moves that looseness with it; the generated snapshot already
holds every version (`enums/old_versions/`) and the proactor port is
where the twins become per-version.

## The forecaster record

Open-Meteo is a `Forecaster` with its own forecast channel for the
Millinocket location, `Method` naming the API and model
(`open-meteo.forecast.shortwave_radiation`, model named in
`SourceLocator` with the coordinates). It is not a replacement for NWS
on temperature and wind; those stay NWS until a skill score says
otherwise. The observed series the solar channel targets is open (see
below); until it is settled the channel targets the Old Town series.

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

1. Settle the two vocabulary choices above with the human: the enum
   additions, and optional pair versus list on the bundle and forecast
   words.
2. Author the words, staging, through the sema gate; regenerate the
   service's snapshot.
3. Add the Open-Meteo fetcher beside `nws.py` with the hour-end to
   hour-start shift and a fixture test.
4. Seed the solar observation and forecast channel records and the
   bundle version for the Millinocket bundle in dev; emit on the dev
   broker.
5. Run the last-winter scoring pull; record the result in
   `experiments/`.

## Open

- **The observed series.** Old Town is 82 km away. Whether the fleet's
  solar channel targets that station, an ERA5 series for Millinocket, or
  nothing yet. A pyranometer at one house is the cheap way to a local
  series; a purchase question.
- **Licence.** Open-Meteo's free tier is non-commercial; the commercial
  licence is reported at $29 a month (2026-10-15, not yet confirmed on
  their portal). Dev and the scoring run stay on the free tier.
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
- **Consumers.** The LTN relays the bundle and the scada falls back to
  pulling it (`gw.operational.params` "WeatherBundleName"). Both decode
  the forecast word, so both move to the new version in the same wave;
  neither reads solar until the load model does.
