# The visualizer

Status: Draft · Pass 0 · Updated 2026-10-26

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

Open.
