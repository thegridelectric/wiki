# gridworks-weather-forecast — design intent

Status: Draft · Pass 0 · Updated 2026-05-24

Captures the design context for `gridworks-weather-forecast/` before we
scaffold and run the new service — what it's for, the type-evolution
trajectory, and the open questions we know we want to think about. The
new repo replaces `gridworks-journalkeeper/src/gjk/weather_service.py`
(legacy code, see "Legacy context" below).

> **What ships first vs eventual goals.** The very first cut of this
> service is **a like-for-like port of the existing
> `weather_service.py`** — same `weather` (v000) type, same NWS
> polling, same `weather.gov.kmlt` channel, same cadence. **Only the
> host and framework change** (own repo, gwbase actor). The forecasts
> and the actual-data-rename described in "Goals" and "Type-evolution
> trajectory" below are the **eventual** state, not what hits the
> wire on day one. The repo name reflects the eventual goal.

## Stack + framework facts

- Built on **`gridworks-base` (gwbase)** — the rabbit-transport actor
  framework + sema codec. See `wiki/gridworks-base/executor/primary.md`.
- This is a **GNode service**: `TransportClass.WeatherForecastService`.
  The `WeatherActor` subclasses **`gwbase.GridworksActor`** (not the
  transport-only `ActorBase`) — it participates in the control plane.
- **Routing-class long form** (see
  [`wiki/gridworks-base/designs/routingclass-wire-aliases.md`](../../gridworks-base/designs/routingclass-wire-aliases.md)).
  This service's routing class is `weather` (long form), NOT the
  legacy short `ws`. A regression to `ws` breaks the prod broker
  fabric. The actor's `_consume_exchange = "ws_tx"` override exists
  *only* to match a legacy prod exchange name and SHALL be revisited
  when that fabric is rebuilt — it is not the gwbase-canonical
  routing (canonical is `<rc>mic_tx`; see
  `wiki/gridworks-base/executor/primary.md` §7).

## Goals

**Primary.** Provide **weather forecasts** to the LTNs in the form
their forward-looking optimizers want. The FLO at
`gridworks-scada/gw_spaceheat/actors/ltn/flo.py:55` reads
`flo_params.OatForecastF[0]` to compute the next-hour COP; the
upstream LTN code at `actors/ltn/ltn.py:799-800` populates
`OatForecastF` / `WindSpeedForecastMph` from
`self.weather_forecast["oat"]` / `["ws"]`. The Sema type that crosses
the wire is `weather.forecast` (already registered at
`sema/definitions/types/weather.forecast/000`) with fields
`time: list[UTCSeconds]`, `oat_f: list[StrictFloat]`,
`wind_speed_mph: list[StrictFloat]`, plus `weather_channel_name`,
`weather_uid`, `forecast_created_s`, `from_g_node_alias`.

**Secondary.** Emit observed (actual) weather data so analytics has
ground truth alongside the forecasts. **Goal: give George accurate
real data after the fact, WITHOUT GAPS.** Backfill methods will likely
encode in the `weather_channel_name` — the channel name carries the
collection-method semantics so two channels (live API vs backfill
from station archive vs interpolated) can coexist without colliding
on the same wire-type.

## Type-evolution trajectory

This is the most important early-design choice. Three known evolutions
to plan for:

1. **The legacy `weather` type is realtime observation, not forecast.**
   The current `gjk/named_types/weather.py` (`type_name = "weather"`,
   `version = "000"`) is `unix_time_s` + `outside_air_temp_f` +
   `wind_speed_mph` — a single observation, not a list. The new
   service produces `weather.forecast` (lists, with axioms about
   monotonic `time` and `forecast_created_s < time[0]`). **The
   legacy `weather` type is being retired**, not migrated.

2. **Floats are suspect.** The user dislikes floats — they carry
   extra garbage and hide precision. The current `weather.forecast`
   Sema type uses `StrictFloat` for `oat_f` and `wind_speed_mph`,
   and the legacy weather_service does `round(..., 2)` for temp/wind
   before serializing. Likely future moves: switch to
   integer-tenths (decidegrees F? deci-mph?) or rationals; bump the
   Sema version when we do. **Plan for type churn on the numeric
   fields specifically.** Whatever we ship initially keeps using
   floats so it interoperates with today's LTN code, but the type
   IS expected to evolve.

3. **`weather` namespace will be reserved; actual data moves to
   `gw.weather` (or more descriptive, like `gw.actual.weather`).**
   Once observed data is reliably landing in the ear pipeline for
   long-term storage, the type that names the realtime observation
   stream will move out of the bare `weather` namespace into a
   `gw.*` namespace. The bare `weather` word stays reserved for
   future use (likely something policy-shaped rather than data).

## Goals tension to resolve

**Should analytics query the weather service directly, or only the
ear-fed long-term store?**

- Argument *for* analytics querying the service directly: it has its
  own database (see below) — easy access, fewer hops.
- Argument *against*: the weather service is part of the
  **production** path (forecasts feed live LTN scheduling). Direct
  analytics queries against a production service is a contamination
  pattern — analytics queries can spike load and the production
  path shouldn't share a DB with analytics workloads.
- **Open** — leaning toward "no, analytics goes through ear-fed
  long-term store" but not decided. The service WILL have its own
  database (next section) so it can serve both purposes if we
  choose.

## Persistence: the weather service has its own DB

Distinct from `gw_data`'s `messages`. The weather service stores
**its own forecast history** — every forecast it produces, with
`weather_uid` as the identity. Two reasons:

1. **Forecast revisions.** A forecast at T=10:00 differs from the
   one at T=10:30 even if both cover hours 11:00–14:00. The service
   stores BOTH so we can audit "what did we know at T=10:00?" The
   `weather_uid` provides the de-duplication / lookup key.
2. **Backfill source.** When the live API misses a window, the
   service can backfill from station archives (e.g., NOAA's daily
   data dumps). The backfill source is encoded in the channel name
   (see Goals above); the unified storage lets consumers see "this
   hour came from live API, this hour came from backfill" without
   the consumer needing to know.

The DB layer probably uses gw_data conventions (UUID PKs,
TIMESTAMPTZ, per-app `gw_writer` role) — see
`../gridworks-data/executor/primary.md`. **Open** — does the weather
DB live as additional tables in the same `gridworks` database, or as
a separate database? Separate would isolate operationally; same
makes cross-joins easier for analytics. Decide when we actually
build the schema.

## Channel naming as the design boundary

The `weather_channel_name: LeftRightDot` field on `weather.forecast`
is the most flexible knob we have. Likely conventions to consider:

- **Source**: `weather.gov.kmlt` (current), `noaa.archive.kmlt`,
  `interpolated.kmlt`, `manual.kmlt` (operator-supplied).
- **Backfill flag**: `weather.gov.kmlt.backfill` for archive-sourced
  fills.
- **Granularity / horizon**: `weather.gov.kmlt.hourly`,
  `weather.gov.kmlt.daily`.

The channel name is **versioning by content, not by type-version** —
it lets a consumer subscribe to exactly what they want without
needing a new Sema type for each variation. The Sema type stays
stable; the channels proliferate as collection methods evolve.

## Legacy context — what we're replacing

`gridworks-journalkeeper/src/gjk/weather_service.py` today:

- Polls NWS at `https://api.weather.gov/stations/KMLT/observations`
  every 10 minutes (operator-confirmed cadence).
- Emits a `weather` (singular) message — realtime observation, not
  a forecast.
- Single hardcoded channel: `weather.gov.kmlt` (Millinocket).
- Single hardcoded GNode identity (whatever's in its tmux env).
- Runs via tmux on the LTN host; logs to stdout.
- Rounds temp/wind to 2 decimal places before serializing.

The new service:

- Is its own repo `gridworks-weather-forecast/` (package `gwwf`).
- Inherits `GridworksActor` from gwbase 0.4.0 (it IS a GNode
  service per `TransportClass.WeatherForecastService`).
- Publishes `weather.forecast` (the Sema-registered type, not the
  legacy bare `weather`), so journalkeeper consumes it via
  SemaCodec on its existing live AMQP path. Solves the F-007
  routing-class-drop in passing — TransportClass routing code is
  `weather` (long form), which ActorBase 0.4.0 already accepts.
- Has its own database (forecast history + observation backfill).
- Migrates the polling logic with cleanup (extract NWS adapter,
  parameterize station, support multi-channel).

## Open / known-to-decide

1. Analytics access model — direct query vs ear-pipeline only?
2. Weather DB — additional tables in `gridworks`, or separate DB?
3. Float vs integer-tenths for `oat_f` / `wind_speed_mph` — when do
   we bump `weather.forecast` to v001 with integer fields?
4. Channel naming convention — what does the canonical set look
   like once backfill is in?
5. Multi-station support — what's the per-station configuration
   shape? Layout JSON? Sema type listing channels?
6. Forecast horizon — how far ahead does the FLO actually consume?
   (Today the FLO reads `OatForecastF[0]` — index 0 only — but the
   forecast type carries N hours; flesh out the horizon contract.)
7. Are forecasts the only thing on the wire, or do observations
   also publish (e.g. as `gw.actual.weather` later)? Goes hand in
   hand with the `weather` namespace reservation question.
