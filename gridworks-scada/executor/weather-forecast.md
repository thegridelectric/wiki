# The weather forecast at the scada

Status: Draft · Pass 0 · Updated 2026-10-08

> What this is: where the scada's outdoor forecast comes from, what it
> holds, how the derived generator and the LTN read it, and what happens
> when the weather service is slow, down, or never seen. Code:
> `gw_spaceheat/weather_source.py`; tests
> `tests/test_misc/test_weather_source.py`.

## Two records, read as a pair

The scada never reaches a third-party weather API. It pulls the
`gw.weather.forecast` message for the bundle its operational params name
(`WeatherBundleName`) from the GridWorks weather service's read facade,
`GET {weather_api_url}/latest-forecast/{WeatherBundleName}`, and holds it
with the bundle record, `gw.weather.forecast.bundle.gt`, pulled once from
`GET {weather_api_url}/bundles` and kept. Slice times and units live on
the record, not the message, so the message is only readable through the
pair:

| The consumer needs | Where it is |
| --- | --- |
| the start of each slice | `FirstSliceStart` walked along the record's `SliceDurationSList` |
| outdoor temperature, °F | `TempValues` unscaled per the temperature observation channel's `Unit` (`FahrenheitX100`) |
| wind speed, mph | `WindSpeedValues` unscaled per the wind observation channel's `Unit` (`MilesPerHourX1000`) |
| the horizon | the record's `TotalSlices` |
| how good the claim is | `Fidelity`, `SourceUpdatedTime`, `MessageCreatedMs` |
| the place | the record's `LocationAlias`; the forecaster's gridpoint is the forecast channel's `SourceLocator` |

Both instances are persisted in the scada's config dir as sema JSON under
the eventstore filename grammar
(`<bundle>-gw.weather.forecast-000.json`,
`<bundle>-gw.weather.forecast.bundle.gt-000.json`) and decoded before any
network call, so a restarted scada holds a forecast before the resume
wait and a box that loses the internet keeps what it last pulled. Each
request is bounded by `weather_pull_timeout_s`; a failed or slow pull
leaves the stored pair in force.

**The ops word names the bundle and nothing else.** The location is the
station's, never the house's: there is no latitude or longitude in the
scada, and method and station are read off the record, never parsed from
a name.

## What the consumers read

The derived generator and the LTN hold the pair and take the next 48
hourly slices after plant time, unscaled. Plant time comes from
`services.clock`, so a stepped or manual clock moves the forecast window
with the plant; only the pull timeouts are wall time. The derived
generator makes the heating forecast from those slices
([`required-energy.md`](required-energy.md) "The heating forecast behind
both"); the LTN crops them to its FLO horizon. Neither interpolates: the
weather service's adapter verifies a product is contiguous and rejects a
short one, so a forecast that arrives is complete and aligned.

**The 96 hours stay.** The bundle is a 96-hour hourly one though the
consumers read 48: the persisted copy covers the box losing the internet,
an outage the service's Stored rung cannot reach, and 96 h keeps 48 real
hours through a two-day cut-off. A day-old forecast beats a seasonal
constant for the required-energy and supply-temperature sums.

## Degradation

The service always emits on the bundle's schedule and marks each message
`Live`, `Stored` or `SeasonalTemplate`; a consumer never switches
subscription when the source dies. **Fill is a fidelity, not a slug.** At
the scada:

1. A message covering the next 48 hours serves, at the fidelity it
   carries.
2. With no message, or one that no longer covers the next 48 hours, the
   source fills from the location's seasonal template
   (`gw.weather.seasonal.template.gt`, the bundle's LocationAlias): the
   bundle's whole slice grid from the next whole hour, each slice at its
   UTC month's template temperature and no wind, marked
   `SeasonalTemplate`. The fill lives in memory; it is never persisted or
   sent. The template is a third record kept beside the two
   (`<alias>-gw.weather.seasonal.template.gt-000.json`).
3. The bundle record and the template are provisioning. Boot reads both
   from the config dir and pulls whichever is missing from the facade
   (`/bundles`, `/seasonal-templates`, the location's latest Start at or
   before plant time), writing it beside the others; a record neither
   stored nor obtainable raises `WeatherProvisioningError` and the scada
   does not start. A box installed without the service is found out at
   its first boot, not at its first outage. Only the forecast message is
   pulled on the scada's loop.

A fill and a failed pull log at WARNING under the scada's base logger
(`<base>.weather_source`); a successful pull logs at INFO.

## Settings and the sim

`weather_source` picks the kind: `Gwwf` (a box) or `Sim` (every test
plant, set by the live-test helper). The sim source returns a steady
forecast on a simulated 96-hour bundle from the plant's next whole hour
after a wall-clock delay the test sets, standing in for a slow service.
Tests construct a forecast pair with `sim_forecast(now_s, oat_f,
wind_speed_mph)`.

## Open

- Whether the provisioning sequence places the bundle record and the
  template on a box before its first boot, or the first boot's pull is
  the provisioning.
- The LTN relays the forecast once the LTNs run; the scada's pull path
  is the interim.
