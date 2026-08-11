# evidence — legacy weather.forecast, JK storage, the legacy wire

Status: Draft · Pass 0 · Updated 2026-08-10

What this is: the evidence base for
[stand-up-weather-forecast](primary.md), gathered 2026-08-10 from the
prod journal DB (Timescale; creds in the gjk box's `.env`), the
gridworks-journalkeeper tree, and the live NWS API. The legacy shapes
are not templates.

- **Scada `weather.forecast` emissions.** ~21,500 messages in
  `gridworks.messages` (2026-01-09 → 2026-08-10), six scada senders —
  the scadas, never the weather service, published `weather.forecast`.
  Every message has exactly 48 hourly slices (`Time[n+1] − Time[n]` =
  3600 without exception; horizon ≈ 47.2 h past creation). `Time[0]`
  is a median 3,567 s in the future at creation (min 10 s, max 3,600):
  the scadas fetch just after the top of the hour and `Time[0]` is the
  next top-of-hour.
- **JournalKeeper stores only index 0.** `weather_forecast_persistor.py`
  writes `round(oat_f[0]*100)` and `round(wind_speed_mph[0]*1000)`
  into per-terminal-asset pseudo channels `forecast-oat`
  (FahrenheitX100) and `forecast-ws` (MilesPerHourX1000) at timestamp
  `Time[0]` — a prediction made about an hour before its own
  timestamp. The insert is `on_conflict_do_nothing` on
  (timestamp, channel): the first prediction for an hour wins and
  later revisions are dropped. Six near-duplicate series exist (every
  house fetches the same NWS gridpoint). The other 47 hours of each
  forecast live only in the message payloads.
- **Pseudo channels are not sema.** The channel table's third
  `channel_type`, `"gjk.pseudo"` (`pseudo_channels.py:33`), is a
  hand-rolled discriminator beside the sema-worded `data.channel.gt` /
  `derived.channel.gt` rows. A PseudoChannel is name + display_name +
  unit + unit_type, registered by persistors and synced per terminal
  asset. 27 names exist; weather is two of them (the rest are prices,
  buffer energy, state enums, zone heat calls).
- **Actual weather was never journaled.** `gridworks.messages` holds
  zero `weather` rows. The observation record was S3-eventstore-only
  and ended 2026-07-18 with the legacy service.
- **The legacy service published ~2-hour-stale observations.** NWS
  returns observations newest-first and KMLT (an AWOS station) reports
  every 5 minutes; `weather_service.py` (gjk @ `47ff87eae`) took
  `features[-1]` — the oldest observation in its trailing 2-hour
  window — so each 10-minute poll found a "new" (old) observation and
  published it. Confirmed by the archived fixture: sent 11:39:59 UTC
  carrying `UnixTimeS` 09:40:00, exactly the window edge. `UnixTimeS`
  carried the true observation time, so the archived data is correctly
  timestamped; it was just recorded ~2 h behind the wall clock. The
  one-per-poll cadence in S3 is a symptom of this defect, not a design
  intent.
- **The legacy wire contract** (the sad-duck import's input). A
  verbatim archived message — the last the legacy service published
  (S3 `gwdev/hw1__1/eventstore/20260718/`, 11:40 UTC on its final
  morning); the byte-exact object is committed as a fixture at
  `gridworks-weather-forecast/tests/hw1.isone.ws-weather-1784374799353-ear.electricity.works.json`:

  ```json
  {
      "TypeName": "weather",
      "Version": "000",
      "FromGNodeAlias": "hw1.isone.ws",
      "WeatherChannelName": "weather.gov.kmlt",
      "UnixTimeS": 1784367600,
      "OutsideAirTempF": 51.8,
      "WindSpeedMph": 0.0
  }
  ```

  Type definition: gjk @ `47ff87eae` `src/gjk/named_types/weather.py`
  (`weather` v000; `wind_speed_mph` optional). The S3 eventstore
  (`gwdev/hw1__1/eventstore/YYYYMMDD/`) holds months of further
  samples.
