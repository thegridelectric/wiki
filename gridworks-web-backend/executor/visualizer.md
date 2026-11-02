# The visualizer

Status: Draft · Pass 0 · Updated 2026-11-01

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

## Price forecast

The forecast the stopgap price service holds at the moment of the
request: the next 48 hours from the next full hour, for one pricing node
under one tariff, the same for every house. It is not the price any
house optimized against; that series, from the journaled FLO params, is
OPS-611's.

- **Word and route.** `gw.stopgap.price.forecast` 000, answered in wire
  form by `GET /api/v2/price-forecast/latest` behind the login
  dependency (`gridworks-web-backend/api/v2/routers/price_forecast.py:20`).
  The api reads the service's latest-forecast route at the URL the
  setting `price_forecast_url` names (`api/config.py:53`) and decodes
  the body through the vendored snapshot (`price_forecast.py:36`). A
  service that cannot be reached, or answers anything but 200, is a 503
  from the route with the reason in `detail` (`price_forecast.py:33`).
- **Series.** LMP and delivery are the word's lists. Total is a display
  sum of the two computed in the browser
  (`gridworks-web-frontend/src/visualizer/pricing-api.ts:46`); no word
  states a total price.
- **Window.** The panel keeps the forecast hours from the window start to
  48 hours past its end (`pricing-api.ts:39`) and its x-axis reaches the
  same point (`PriceForecastPlot.tsx:66`), so a window that ends at now
  shows the forecast ahead. A window with no forecast hour near it shows
  "No price forecast near this window" (`PriceForecastPlot.tsx:46`).
- **Standing.** The stopgap word has two consumers, the LTN's fetch and
  this forward, and both retire with the price-forecast service's own
  word (OPS-437; `../../gridworks-price-forecast/executor/primary.md`
  "The stopgap").

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
