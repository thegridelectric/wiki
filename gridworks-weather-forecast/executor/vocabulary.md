# vocabulary — what the service does with the gw.weather.* words

Status: Draft · Pass 0 · Updated 2026-10-18

What this is: the service's own obligations around the `gw.weather.*`
words, for [the hub](primary.md). The words' schemas and axioms are
the sema registry's and are not repeated here; what a word means on
its own is in its definition. This spoke states what takes more than
one instance, a clock or the store to check.

## Records

- **A station belongs to no location.** The bundle that serves a place
  names the stations it draws on through its observed channels.
- **A bundle's embedded channel copies equal the canonical records**,
  checked at creation and at boot; a mismatch refuses the create.
- **Method names the adapter.** The service keeps a table from Method
  to the product it fetches and the quantities that product serves
  (NWS gridpoint hourly: temperature and wind; Open-Meteo
  `gfs_seamless` hourly: irradiance). Forecast channels on one
  acquisition share one fetch and one stored product. SourceLocator is
  the adapter's own encoding of its acquisition fact; nothing else
  reads it.
- **The Unit on a channel is what the adapter scales by.** A new unit
  is a new channel.
- **A later seasonal template for the same location supersedes by
  Start.** The actor takes the latest Start at or before boot.
- **Slice arithmetic derives from the record** (SliceDurationSList,
  EmitPeriodS, EmitOffsetS). A time-varying grid is a record change.

## Observations

- At each emission slot the service publishes the newest available
  station observation with its true ObservationTime. A stale
  observation is never re-published.
- When the station has produced nothing new the slot stays silent.
- On recovery the service replays the missed grid points as ordinary
  observation messages, one per missed time, with values interpolated
  between the bracketing real observations and marked `Interpolated`.
  A channel is interpolated when both bracketing observations report
  it. Gaps up to 3 h are filled; a longer gap stays a gap and raises a
  glitch.
- An observation older than 1 h at publish time raises a glitch.

## Forecasts

- The service always emits on the bundle's schedule, so a missing
  message means a drop.
- Each series' `SourceUpdatedTime` is its source's own data revision
  (for NWS the gridpoint `updateTime`; for Open-Meteo the GFS run time
  from the model metadata endpoint). A stamp may hold unchanged across
  many emissions while a source sits on a package. `MessageCreatedMs`
  is the service's own emission stamp and advances every send.
- `FirstSliceStart` anchors to the next slice boundary; the forward
  horizon never shrinks.
- **Every slice is labelled by its start.** Open-Meteo's hourly
  `shortwave_radiation` (global horizontal irradiance, W/m²) is the
  mean over the preceding hour labelled by the hour's end, so the
  Open-Meteo adapter shifts each value one hour back to the slice it
  describes; a consumer never sees the source's labelling.
- **The degradation ladder** when a source is stale: live product;
  then the stored horizon (the service fetches and keeps 24 slices
  beyond the bundle's grid); then the seasonal template. Each series walks
  the ladder on its own, and series on one acquisition share a rung.
  At the template rung a temperature series takes the template laid on
  the bundle grid, each slice at its UTC month's value scaled to the
  channel's unit; any other quantity is zeros stamped with the
  bundle's Start. A location with no template skips the slot and
  raises a glitch. Each downgrade raises a glitch naming the series.
- **Sent forecasts are store rows**, one per send-distinct message,
  keyed by the bundle name it was sent under and the joined per-series
  source revisions. The read API serves the latest one per bundle.

## Open

- Two checks the markdown spec claimed and the code does not make: that
  a bundle's stations pair with its location, and that the same handle
  at two locations names the same recipe (quantities, units,
  forecasters, grid, schedule). A create today refuses on validation, a
  dangling reference, and an embedded-copy mismatch, and nothing else.
  Either becomes a clause with a test, or the claim is dropped.
- **The observed irradiance series.** The irradiance forecast channel
  targets `kmemilli18`, the Weather Underground station in Millinocket
  with a solar sensor, which has no observation stream (no ICAO id); a
  hobbyist pyranometer behind an HTML scrape is a research series, not
  a fleet source. Old Town's USCRN pyranometer is 82 km away; an ERA5
  cell is a third instrument. Each is a different channel. A
  pyranometer at one house is the cheap way to a local series.
- **Specialist solar forecasters.** Solcast, SolarAnywhere and
  Tomorrow.io sell GHI/DNI/DHI forecasts on quote with no published
  winter validation for the northeastern US. Worth a quote once a
  winter score shows irradiance forecast error dominating the load
  regression. Published evidence favours ECMWF IFS over HRRR under
  cloud, so `ecmwf_ifs025` is the first challenger to score; it is one
  more model name in the same Open-Meteo call.
