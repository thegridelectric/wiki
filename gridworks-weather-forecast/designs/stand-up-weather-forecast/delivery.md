# delivery — cadence, phase structure, fleet distribution

Status: Accepted · Pass 1 · Updated 2026-08-11 · Linear: OPS-436

What this is: how weather reaches consumers for
[stand-up-weather-forecast](primary.md) — broadcast cadence, the hour
phase structure, the pull path, and the fleet delivery shape.

## Cadence

The FLO consumes the full forecast horizon — flo_params carries 48 h
of OatForecastF / WindSpeedForecastMph
(`gw_spaceheat/actors/ltn/ltn.py:1041-1042`, capped by
`flo_horizon_hours`) — and today runs once an hour at a settings-driven
minute (historically randomized to spread processing load,
`ltn.py:516`).

- **Observations broadcast at the top of each hour** (for now),
  keeping the JK series a clean hourly grid. The cadence rises when
  OPS-491 needs it (the station updates every 5 min) — a
  channel-record update, since cadence is schema (EmitPeriodS /
  EmitOffsetS on the channel words, see
  [`vocabulary.md`](vocabulary.md)).
- **Hour phase structure (settled 2026-08-12):** the forecast
  broadcasts at :01 — as soon as "next hour" changes. The probe
  (`experiments/2026-08-11-nws-updatetime-probe/`) established that
  NWS underlying-data freshness is issuance-driven (2–4 revisions a
  day) and phase-independent — no emission minute beats another — so
  the earlier :30 idea bought nothing and cost half the FLO
  randomness window. The hour becomes :00 observation → :01 forecast
  → FLO window over the rest of the hour (randomness preserved;
  `send_bid_minute` = 57). The ordering contract survives intact: a
  FLO anywhere in its window KNOWS this hour's forecast is already
  there, so pull-on-miss has a trivial trigger, and each window's
  forecast arrives 29 minutes earlier than under :30. The structure
  dissolves under 5-minute FLOs (OPS-491's problem).
- **Pull path = the gwwf HTTP API (decided).** Consumers passively
  wait for broadcasts; the emission schedule on the channel record
  makes "expected" a mechanical timeout contract, and every pull goes
  through one public read-only HTTP API on gwwf returning sema-typed
  message words. The one API serves all pull consumers: LTN drop
  recovery, scada fallback when its LTN relay goes quiet, and
  post-hoc/analytics reads. It also lists the active channel,
  forecast-channel, and location records (consumers cache; pull again
  on decode-miss; Start-scoped history resolves archived messages).
  There is NO broker request/response vocabulary — the legacy
  sync-request prior art retires unused.
- **Records broadcast once at creation (2026-08-12).** Each new
  record — bundle, forecast-channel, channel, location — is broadcast
  a single time when minted, so it enters the immutable store through
  the universal audit tap and an archived message resolves against
  the record active at its time (the bundle word's `Start` exists for
  exactly this; the forecast message deliberately carries no slice
  grid, so the archive is self-contained only with the records in
  it). No re-broadcast and no boot re-emission: capture is the ear's
  job, and finding records in the store is JournalKeeper's. Consumer
  delivery is unchanged — nobody binds a record stream; consumers
  cache records and pull-on-miss through the API. No sema change:
  the record words are the messages, carried as-is.
- **Five-minute FLOs rider:** OPS-491 (gwbase port first, OPS-435)
  owns the FLO cadence change; weather and price forecast freshness
  updates ride along with it.

## Broadcast binding shape

The radio-channel tail of the `rjb` routing key names the stream
(decided 2026-08-11; gwbase transport spec pins the tail as one or
more extra **dotted** segments, appended verbatim — dots preserved,
so per-segment wildcards work):

- **Observations:** radio channel = the location alias
  (`us.me.millinocket`) — the message is per-station and bundles all
  quantities; consumers bind the location, quantities live in the
  payload.
- **Forecasts:** radio channel = the bundle Name, verbatim
  (`us.me.millinocket.forecast.nws.hourly`), one message per BUNDLE
  per emission (2026-08-12 — the bundle is the sign-up object; see
  [`vocabulary.md`](vocabulary.md) "gw.weather.forecast.bundle.gt").
  The LTN binds exactly its designated bundle and receives its whole
  aligned FLO input set atomically; per-channel wildcards left the
  wire with per-channel messages.
- **Records (2026-08-12):** location, channel, and forecast-channel
  record broadcasts carry the record's own name as the radio tail
  (`us.me.millinocket`, `us.me.millinocket.temperature`, …) — the
  same convention as the streams. The BUNDLE record alone broadcasts
  with NO radio tail
  (`rjb.hw1-weather.weather.gw-weather-forecast-bundle-gt`). In every
  case the TypeName segment separates record broadcasts from stream
  messages and stream binders bind their full key; nothing binds
  record broadcasts — they exist for the audit tap.

## Fleet delivery shape

The S3 evidence shows every house SCADA fetching weather itself and
posting its own hourly `weather.forecast` — six duplicate fetchers,
six versions of truth, each house depending on its own outbound
internet fetch. This design's follow-on removes that: the weather
fetch leaves the scada; pipes deliver weather TO it.

- **LTN relay is primary.** Weather rides the existing LTN→scada
  pipe; the scada's comms model stays "my LTN pair is my world" — no
  per-house broker bindings.
- **The scada persists the last-received forecast** (the existing
  `weather.json` cache pattern, re-sourced from the relay). A cached
  48 h horizon stays useful across a day of LTN silence; staleness is
  visible in ForecastCreated; past the horizon the consumer falls
  back to conservative defaults.
- **Fallback is a pull from the gwwf API** when the expected relay is
  quiet past the schedule contract — the same public endpoint every
  pull consumer uses, not a second broker subscription.
- The autonomy ground truth: the scada consumes forecasts locally
  outside the FLO path — DerivedGenerator
  (`gw_spaceheat/actors/derived_generator.py:63`) uses the 48 h OAT
  forecast for on-peak storage preparation (midday OAT → COP →
  required storage energy) and is one of the six legacy fetchers. The
  failsafe floor (wall-thermostat heat calls) needs no weather.

## Blessed forecast stream

Which predictor a house consumes is **house-level shared operational
config** — the LTN (FLO consumption, relay) and the scada (API
fallback pull) MUST name the same forecast BUNDLE (the sign-up
object, 2026-08-12), so the value lives where both actors read it,
like the layout; a required field, no default. The exact document shape lands in the scada
operational-config design, along with the related observation that
house-physics parameters (COP curve, HpMaxKwEl) are today duplicated
between flo-params and DerivedGenerator params — shared facts want
one home. A service-published designation record (the fleet-wide
one-flip cutover lever) is minted when a challenger first wins a
shadow season, not before.

## Legacy retirement sequencing

gwwf ships and runs first — nothing consumes the legacy words today
(the legacy observation service is already stopped). The scada change
(delete the `get_weather` fetchers and legacy `weather.forecast`
publish; add LTN-relay consumption + API fallback) rides the next
scada deploy train, coordinated with the scada world. After the last
emitter stops, the legacy `weather` / `weather.forecast` words get
`frozen_at` + `replaced_by` in the sema registry.

## Do next

The record-broadcast emission is a build item
([`build.md`](build.md)); the persistence grill in
[`journalkeeper-and-history.md`](journalkeeper-and-history.md) — the
Joe conversation — is the remaining Draft spoke.
