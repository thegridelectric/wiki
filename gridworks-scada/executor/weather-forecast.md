# The weather forecast at the scada

Status: Draft · Pass 0 · Updated 2026-10-18

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
`GET {weather_api_url}/bundles` and kept. The message is a list of series,
one per quantity; the record is a list of bindings, each a forecast
channel with the observed channel it targets. Slice times and units live
on the record, not the message, so the message is only readable through
the pair:

| The consumer needs | Where it is |
| --- | --- |
| the start of each slice | `FirstSliceStart` walked along the `SliceDurationSList` every binding's forecast channel shares |
| outdoor temperature, °F | the series whose `Quantity` is `Temperature`, unscaled per its binding's observed channel `Unit` (`FahrenheitX10` at Millinocket) |
| wind speed, mph | the series whose `Quantity` is `WindSpeed`, unscaled the same way (`MilesPerHourX10`) |
| the horizon | the forecast channels' `TotalSlices` |
| how good the claim is | each series' own `Fidelity` and `SourceUpdatedTime`; `MessageCreatedMs` on the message |
| the place | the record's `LocationAlias`; the observing station is each observed channel's `StationAlias`; the forecaster's gridpoint is the forecast channel's `SourceLocator` |

**The scada reads temperature and wind** (`CONSUMED_QUANTITIES`) and
ignores every other series the bundle binds, so one bundle can serve the
scada and a consumer that reads more. A message or bundle without a wind
series is a degradation case below; a bundle that binds no temperature
channel cannot be filled and refuses at boot.

Both instances are persisted in the scada's config dir as sema JSON under
the eventstore filename grammar, the version taken from the twin
(`<bundle>-gw.weather.forecast-001.json`,
`<bundle>-gw.weather.forecast.bundle.gt-002.json`), and decoded before
any network call, so a restarted scada holds a forecast before the resume
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

1. A message with a temperature and a wind series covering the next 48
   hours serves, each series at the fidelity it carries.
2. With no message, one that no longer covers the next 48 hours, or one
   without a temperature or wind series, the source fills from the
   location's seasonal template (`gw.weather.seasonal.template.gt`, the
   bundle's LocationAlias): the bundle's whole slice grid from the next
   whole hour, each slice at its UTC month's template temperature,
   marked `SeasonalTemplate`. The template knows no wind: the fill's
   wind series is calm when the bundle binds a wind channel and absent
   when it does not, and the consumers read calm either way. The fill
   lives in memory; it is never persisted or sent. The template is a
   third record kept beside the two
   (`<alias>-gw.weather.seasonal.template.gt-000.json`).
   A fill for a missing series is a fault in the bundle or the service,
   so the source names the quantities it lacked (`missing_quantities`)
   and the derived generator sends the Warning glitch
   `weather-series-missing` with each such fill; a fill for coverage is
   the ordinary outage case and logs only.
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

**A first forecast is not certain.** The weather source answers None
when the bundle on file no longer matches the pulled forecast and a
fresh bundle is unreachable. The derived generator retries until the
first forecast is stored, with the Warning glitch `no-weather-forecast`
per miss, and sets `first_forecast` on `ScadaData` when it is. There is
no bail clock: the seasonal template keeps a forecast the normal case,
and the retry is for the abnormal one (`leaf-ally.md` "The startup
order" for what waits on it).

## Settings and the sim

`weather_source` picks the kind: `Gwwf` (a box) or `Sim` (every test
plant, set by the live-test helper). The sim source returns a steady
forecast on a simulated 96-hour bundle (station `sim`, temperature and
wind, the Millinocket units) from the plant's next whole hour after a
wall-clock delay the test sets, standing in for a slow service.
Tests construct a forecast pair with `sim_forecast(now_s, oat_f,
wind_speed_mph)`.

## Open

- Whether the provisioning sequence places the bundle record and the
  template on a box before its first boot, or the first boot's pull is
  the provisioning.
- The LTN relays the forecast once the LTNs run; the scada's pull path
  is the interim.
