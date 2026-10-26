# observed-irradiance-source

Status: Draft · Pass 0 · Updated 2026-10-26 · Linear: OPS-621

**EDD: yes** verified on hw1: the `kmemilli18-irradiance` row in the
journal gains one reading per hour, each with the station's own
observation time, through a full day that includes a clear noon, and
the LTN house-parameter fit reads them from the journal.

> What this is: the weather service declares an observed irradiance
> channel on the Millinocket station and has never published a value
> for it, because the only observation feed it fetches is the NWS one
> and that station is not an NWS station. The LTN's heat-loss model
> needs observed irradiance to fit its solar term. This design gives the
> channel a measured source.

## What is

- The observed channels the service declares (`gw.weather.channel.gt`
  records of 2026-10-18): `kmlt.temperature`, `kmlt.windspeed` and
  `kmemilli18.irradiance`, all `EmitPeriodS` 3600, so an hourly series
  each. `kmlt` is the Millinocket airport NWS station (`IcaoId`);
  `kmemilli18` is a Wunderground personal weather station (the record
  has a `WundergroundId` and no `IcaoId`).
- The service builds one observation stream per station from the NWS
  feed keyed by `IcaoId`; a station without one gets no stream and a
  log line saying so (`src/gwwf/weather_actor.py`, the stream wiring
  around line 200).
- The production journal as of 2026-10-26 12:00Z: 168
  `gw.weather.observation` messages since 2026-10-18 20:00Z, every one
  from station `kmlt`, with temperature in all 168 and wind in 160;
  five are interpolated. No observation names `kmemilli18` or the
  Irradiance quantity. The observed readings rows (journalkeeper
  `WeatherObservationPersistor`, deployed 2026-10-25 21:28Z) fill
  hourly for `kmlt-temperature` and `kmlt-windspeed` and stay empty for
  `kmemilli18-irradiance`. Readings key on the channel row's `id`
  column.
- The NWS stream raises staleness glitches often: in the two weeks to
  2026-10-25, 22 "no fresh observation at slot", 5 "observation stale
  at publish", 3 "gap not filled".
- Irradiance exists in the service only as a forecast: the Open-Meteo
  hourly product (`src/gwwf/open_meteo.py`), mean W/m² over the hour
  before each label, served in the bundle's forecast channels. The NWS
  station feed has no irradiance.
- The Wunderground dashboard for KMEMILLI18 shows a Solar Radiation
  widget, rendered client-side, so the station appears to have the
  sensor; no value was read. The PWS API (`api.weather.com/v2/pws`)
  answers 401 without a valid key. A free key goes only to the owner of
  a station that uploads to Wunderground, which GridWorks is not.

## Why it matters

The LTN's load model (OPS-531, the automated house parameters) has a
solar term, and the fit wants observed irradiance per hour alongside
observed temperature and wind. Its first pass fits with Open-Meteo's
past hours as the solar column, fetched on the LTN's own path, because
no measurement exists yet. That column is a model output and stays
on the LTN's side; the weather service's observed channel is for
measurements only, so the fit gains a measured solar term the day this
design ships and not before.

## Options

Two sources, both measurements. No modelled series is ever published
on an observed channel: a reanalysis copied one step behind the
forecast would be a forecast under another name, and the LTN can fetch
that itself.

1. **Wunderground as a second observation feed.** The station record
   already names `KMEMILLI18`; the Weather Underground PWS API serves
   current conditions and daily history per station, including
   `solarRadiation` where the station has a sensor. One fetcher per
   source, keyed by the id the record has, which is the shape the
   actor's `fetch_observation` already allows. Gated on a key: either a
   Weather Company API key, or read access through the station's owner.
2. **A GridWorks pyranometer** at a house, reported by the scada as a
   data channel. Real, local, and the fleet's own. A silicon-cell
   sensor with an analog output in the pico's ADC range fits the
   existing sensing path: the Apogee SP-212 (amplified 0 to 2.5 V,
   needs 5 to 24 V supply) or the Davis 6450 (0 to 3 V, used on Davis
   Vantage stations), each in the $200 to $300 range; the Apogee SP-110
   is the same sensor self-powered at 0 to 400 mV and wants an amplifier
   stage. Prices and output ranges from memory, 2026-10-26; confirm on
   the maker's page before ordering. A thermopile class instrument
   (Apogee SP-510 and up) is a later upgrade, not the first unit.

Option 1 is first because it needs no hardware on a roof before winter.
Option 2 is the durable answer and the one the hundred homes want, since
one Millinocket station does not serve a fleet across Maine.

## Do this next

Get a key. Ask the owner of KMEMILLI18 for read access, or price a
Weather Company API key; in parallel, confirm on the station's public
dashboard at a clear noon that the Solar Radiation widget shows a
value. The design waits in Todo until one of the two answers.

## Out

- The forecast irradiance product and its fidelity ladder.
- The LTN fit itself (OPS-531), including its first-pass solar column.
- Observed temperature and wind, which the NWS stream already serves.

## Open

- The observation contract's staleness rule (older than 1 h at publish
  raises a glitch) against a PWS that uploads every few minutes but may
  go dark for a day; whether a PWS stream gets its own `max_fill_s`.
  The NWS stream's own glitch counts above are the baseline to beat.
- Units: the channel is `WattsPerSquareMeter`; Wunderground reports
  W/m² for solar radiation. No conversion.
- For option 2: which house, which pico input, and the channel name the
  station record then points at.

## Plan

1. The key, by one of the two routes above.
2. The fetcher for Wunderground, behind the same `fetch_observation`
   seam as NWS, with a recorded fixture and a test that a station with
   a `WundergroundId` and no `IcaoId` gets a stream.
3. Deploy; the witness is one day of hourly readings on the row.

Estimate at the Plan: about 4 h (2 to 8), most of it the source's
account and its quirks. The pyranometer is a separate issue when it is
taken up.
