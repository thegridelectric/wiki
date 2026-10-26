# observed-irradiance-source

Status: Draft · Pass 0 · Updated 2026-10-25 · Linear: OPS-621

**EDD: yes** verified on hw1: the `kmemilli18-irradiance` row in the
journal gains one reading per hour, each with the station's own
observation time, through a full day that includes a clear noon, and
the LTN house-parameter fit reads them from the journal.

> What this is: the weather service declares an observed irradiance
> channel on the Millinocket station and has never published a value
> for it, because the only observation feed it fetches is the NWS one
> and that station is not an NWS station. The LTN's heat-loss model
> needs observed irradiance to fit its solar term. This design gives the
> channel a source.

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
  around line 200). So `kmemilli18.irradiance` has a journal row, a
  `channel_id`, and no readings: none in the production journal in the
  two days to 2026-10-25, and none in the 2026-10-25 tap run, where the
  21:00 `kmlt` observation wrote temperature and wind and nothing else.
- Irradiance exists in the service only as a forecast: the Open-Meteo
  hourly product (`src/gwwf/open_meteo.py`), mean W/m² over the hour
  before each label, served in the bundle's forecast channels.
- The NWS station feed has no irradiance; the Open-Meteo product is a
  model, not a measurement.

## Why it matters

The LTN's load model (OPS-531, the automated house parameters) has a
solar term, and the fit wants observed irradiance per hour alongside
observed temperature and wind; the estimation work so far used
Open-Meteo for the solar column (`gridworks-house-parameters`
`README.md`, `solar_w_m2`). Its working-store spoke lists observed
weather, irradiance included, as having no source on the LTN's path.
The journal's observed rows are that path: the fit reads them as it
reads any other channel.

## Options

1. **Wunderground as a second observation feed.** The station record
   already names `KMEMILLI18`; the Weather Underground PWS API serves
   current conditions and daily history per station, including
   `solarRadiation` where the station has a sensor. Needs an API key
   (free tier for PWS owners who upload; otherwise a paid key) and a
   check that KMEMILLI18 actually reports solar radiation (many PWS
   have no pyranometer). One fetcher per source, keyed by the id the
   record has, which is the shape the actor's `fetch_observation`
   already allows.
2. **Open-Meteo's past-hours as the observed series.** The same product
   fetched with `past_hours`, labelled observed. It is a reanalysis, not
   a measurement, and it would make the observed channel a copy of the
   forecast channel one step behind. Honest only if the channel's
   display name says it is modelled; better as the fallback rung of
   option 1 than as the source.
3. **A GridWorks pyranometer** at a house, reported by the scada as a
   data channel. Real, local, and a hardware project; out of reach for
   this heating season.

Option 1 first, with its two checks (the key, and whether the station
has the sensor) as the first move. If KMEMILLI18 has no solar sensor,
the station record is wrong for this channel and the design picks
another PWS in range that has one, or falls to option 2 with the name
changed.

## Do this next

Query the Wunderground current-conditions endpoint for KMEMILLI18 once
by hand and record whether `solarRadiation` is present and non-null in
daylight. That decides the source.

## Out

- The forecast irradiance product and its fidelity ladder.
- The LTN fit itself (OPS-531).
- Observed temperature and wind, which the NWS stream already serves.

## Open

- The observation contract's staleness rule (older than 1 h at publish
  raises a glitch) against a PWS that uploads every few minutes but may
  go dark for a day; whether a PWS stream gets its own `max_fill_s`.
- Units: the channel is `WattsPerSquareMeter`; Wunderground reports
  W/m² for solar radiation, Open-Meteo the same. No conversion either
  way.

## Plan

1. The by-hand check above.
2. The fetcher for the chosen source, behind the same
   `fetch_observation` seam as NWS, with a recorded fixture and a test
   that a station with a `WundergroundId` and no `IcaoId` gets a stream.
3. Deploy; the witness is one day of hourly readings on the row.

Estimate at the Plan: about 4 h (2 to 8), most of it the source's
account and its quirks.
