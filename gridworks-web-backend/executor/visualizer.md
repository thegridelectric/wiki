# The visualizer

Status: Draft · Pass 0 · Updated 2026-11-15

> What this is: the visualizer page of the web-frontend, one section per
> plot, each saying what the plot shows, which word the backend serves it
> from and which route. The plot list and its order are
> `gridworks-web-frontend/src/visualizer/plot-configs.ts:477`
> (`PLOT_CONFIGS`); a section with only "Open" has not been written yet.

## The page

The page is one house over one window (start and end, in the house's
local time). Every plot takes the window from the page; the default plot
layout fixes the x-axis to it
(`gridworks-web-frontend/src/visualizer/DefaultVisualizerPlot.tsx:203`).
Each plot fetches its own data from the api through the session client.

## Heat pump

Open.

## FLO

What the house's FLO recommended for the slot the page's hour-step
buttons select: five panels drawn from the one word (heat pump kW with
load kW, price, store layers with temperature color, state of charge,
stacked penalties). The page opens on the path with the lowest
`PathCostUsd`.

- **Word and route.** `flo.recommendation` 001 as the FLO service
  published it, read from the journal for the house and slot and decoded
  through the vendored snapshot:
  `GET /api/v2/installations/{installation_id}/flo.recommendation`
  (`api/v2/routers/flo_recommendation.py`); `flo.params` for the same
  slot on the sibling route. The box runs no optimizer; the browser
  renders from the generated type (`FloPlot.tsx`) and computes colors,
  bar widths, baselines and axis ranges itself.
- **The re-run, a laptop tool.** The optimizer author's inspection tool
  is to solve an hour again with bruce's penalty tuning changed and look
  at the plot. `POST /api/v2/installations/{installation_id}/flo.rerun`
  (`api/v2/routers/flo_rerun.py`) takes the hour's `flo.params` word with
  its Tuning edited and answers the `flo.recommendation` bruce gives,
  solved in a thread by the bruce package from the backend's `rerun`
  dependency group (a git source at optimal-flexibility `main`). The
  route is mounted only when `BACKEND_FLO_RERUN=in-process`, and the
  mount refuses to start an API whose `BACKEND_RUNNING_LOCALLY` is false,
  so the web box never serves it; the box also never installs the group.
  bruce reads `flo.params` at the version its snapshot vendors, and an
  older journaled hour answers 422 naming both versions. The browser
  probes the route when a house is selected (a GET of the POST-only path:
  405 means mounted, anything else hides the panel) and, where it is,
  shows the thirteen penalty fields of `flo.tuning.bruce` prefilled from
  the hour's request (`FloRerunPanel.tsx`, `flo-rerun-tuning.ts`), sends
  the edited word through the vendored types, and draws the answer with
  the same `FloPlot`; Reset or the hour arrows bring the journaled plot
  back. Forced heat pump steps wait on a sema word (OPS-683).
- **Open.** Which path to draw once the slot has a `flo.previous.run`
  (the cleared pair's; today the page does not read it). A recommendation
  with no penalties word (a 000 row, or alice's) has no `PathCostUsd`, so
  the page opens on its lowest-priced pair; the forecast-cheapest pair for
  such a row needs the forecast price, which `flo.params` states.
  Whether the "normalized" electricity price (price over the horizon's
  mean COP) and the thermal price become a word's fields or stay a
  browser projection from `flo.params`. Whether the x axis shows the
  date at midnight across the two-day horizon. The hour arrow takes
  about 4 s per press against web-api2 while the box is idle; the
  FLO GET logs about 4 s after its CORS preflight; the notes are a comment
  on OPS-665.

## Price forecast

The price the house's FLO was asked to optimize against, as of the
window's first hour, and the price its market then cleared at: one
`gw.price.forecast` word and the market's `latest.price` words, drawn as
two step traces on the page's time axis, with the tariff's on-peak hours
shaded. The panel is titled "Price".

- **Word and route.** `gw.price.forecast` 000, answered in wire form by
  `GET /api/v2/installations/{house}/price-forecast?time=` behind the
  login dependency (`gridworks-web-backend/api/v2/routers/house_price_forecast.py`).
  Two rules, in order: the `PriceForecastId` named by the newest
  `flo.params` 002 the house's LTN journaled for the slot `time` falls
  in, resolved to the journaled forecast with that `ForecastUid`; else
  the journaled forecast with the greatest `CreatedMs` at or before
  `time`, the forecast any bidder had at that moment. Neither is a 404
  with `detail` "No price forecast for this hour", which the panel
  shows as its empty state. The route serves the word alone; which
  rule chose it is in "Open" of `primary.md`. The route never asks the
  price service.
- **Series.** The forecast price, `PriceX1000List` unscaled to USD/MWh
  at render, as a step over the window: the slot in force at the
  window start, the slots that start inside it, and a closing point
  where the last ends or the window does, so a window inside one hour
  draws that hour's price (`gridworks-web-frontend/src/visualizer/pricing-api.ts`
  `forecastSeries`). One y axis that includes zero
  (`PriceForecastPlot.tsx`). The forecast is the full price the LTN
  expects to face; it has no parts to draw.
- **Window.** The panel asks for the forecast at the window's start, on
  the page's x range like every other panel. The series begins where
  the journal does: a window before the service's first journaled
  forecast (2026-11-14 18:29 EST) gets the route's 404, which the fetch
  takes as a response rather than an error, and the panel shows "No
  price forecast in this window".
- **On-peak shading.** Light pink rectangles behind the trace over the
  tariff's recurring on-peak windows laid across the window's range in
  the tariff's zone (`src/visualizer/tou-tariff.ts` `onPeakShapes`,
  shared with the FLO plot). The tariff is the house's own: the
  `Tariff` of its `layout.lite` 014 row, read off the house summary
  the page already has (`tariffForHouse`); a house whose latest layout
  is older than 014 gets the fleet's one tariff from
  `GET /api/v2/tou-tariff/current` (`gw.tou.tariff` 000,
  `api/v2/routers/tou_tariff.py`), a fallback that retires when every
  house's layout states its tariff.
- **Real-time price.** The market the forecast names,
  `e.<ProductName>.<MarketMakerAlias>` (`pricing-api.ts` `marketOf`), is
  the slot-name prefix the browser asks
  `GET /api/v2/markets/{market}/latest-prices?start&end` for
  (`api/v2/routers/latest_price.py`): the maker's `latest.price` rows for
  the slots that start from one slot before the window through its end,
  oldest first, each served as 001 (a 000 row upgraded, its whole price
  one `Unknown` part). The browser draws them as a step, "Real-time",
  from the slot in force at the window start (`realTimeSeries`); the step
  runs across a slot the market did not clear. A window whose house had
  no forecast knows no market and draws no real-time trace. The slot
  length is a constant in both the route and the browser, with a note
  naming the product-name fact that retires it.
- **The FLO plot's price.** `flo.params` is served at the version the
  journal holds, 002 beside 001 (`flo_recommendation.py`
  `JOURNALED_PARAMS`), and the browser reads both through
  `AnyFloParams`; its price per step is the one list at 002 and the LMP
  and distribution lists summed at 001 (`src/sema/types/AnyFloParams.ts`
  `priceUsdMwhList`).

## Secondary loop

Open.

## Distribution

Open.

## Heat calls

Open.

## Zones

Open.

## Floor temperatures

Open.

## Buffer

Open.

## Storage

Open.

## Top state

Open.

## LocalControl state

Open.

## LTN state

Open.

## Weather forecasts

Every temperature forecast run the house's weather bundle emitted over
the window, each drawn from its first slice; the newest run is red, the
older runs fade by age. Admin logins only
(`gridworks-web-frontend/src/visualizer/VisualizerPlot.tsx:48`).

- **Words and routes.** `gw.weather.forecast.bundle.gt` 002, the newest
  record the journal holds under the bundle's name, answered in wire form
  by `GET /api/v2/weather/bundles/{bundle_name}`
  (`gridworks-web-backend/api/v2/routers/weather_forecast.py:38`), and
  `gw.weather.forecast`, the bundle's emissions the journal received in
  the window, oldest first and each in the dict form of its own version
  (001 rows have no ForecastUid and no upgrade path, so both are served
  as journaled), by `GET
  /api/v2/weather/bundles/{bundle_name}/forecasts?start&end`
  (`weather_forecast.py:64`), at most the newest 500
  (`weather_forecast.py:24`). Both behind the login dependency; a bundle
  with no record is a 404.
- **House to bundle.** The bundle a house's scada reads is the
  `WeatherBundleName` of its `gw.operational.params`. The browser holds
  that fact as a table from the installation's alias to the bundle name
  (`gridworks-web-frontend/src/visualizer/house-weather-bundles.ts:8`)
  until the params are journaled and the api resolves it; a house the
  table does not know shows "No weather bundle is known for"
  (`WeatherForecastPlot.tsx:52`).
- **Series.** One quantity, Temperature (`WeatherForecastPlot.tsx:57`).
  The bundle's binding for the quantity names the forecast channel whose
  series the run is and the observed channel whose `Unit` scales its
  values; slice start times are the emission's `FirstSliceStart` walked
  along the forecast channel's `SliceDurationSList`
  (`gridworks-web-frontend/src/visualizer/weather-api.ts:27`). The plot
  converts the scaled values through the shared unit table by that
  `Unit`. A bundle that binds no channel of the quantity shows "forecasts
  no temperature".
- **Window.** The emissions fetched run from a day before the window
  start to its end (`weather-api.ts:63`), so the run in force at the
  window start is drawn.
