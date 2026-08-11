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
- **Hour phase structure (proposed):** no FLOs run before :30; the
  forecast broadcasts at :30. The hour becomes :00 observation → :30
  forecast → :30–:57 FLO window (randomness preserved inside it;
  `send_bid_minute` = 57). The value is the ordering contract: a FLO
  in its window KNOWS this hour's forecast should already be there, so
  pull-on-miss has a trivial trigger, and the bid-time forecast is
  ≤27 min old (vs ~56 min under the legacy fetch-at-:01 pattern).
  Notes: the randomness window halves (fine at current fleet size,
  re-check at 100 homes); the structure dissolves under 5-minute FLOs
  (OPS-491's problem); NWS underlying-data freshness at :30 is NOT
  established — one probe (2026-08-10 22:11Z) showed `generatedAt` at
  the top of the hour but `updateTime` (underlying gridpoint data) 2 h
  older. Early EDD probe: log `updateTime` for a day or two.
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
  sync-request prior art retires unused. Record changes are rare
  enough that records are not broadcast; pull-on-miss covers them.
- **Five-minute FLOs rider:** OPS-491 (gwbase port first, OPS-435)
  owns the FLO cadence change; weather and price forecast freshness
  updates ride along with it.

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
fallback pull) MUST name the same forecast channel, so the value
lives where both actors read it, like the layout; a required field,
no default. The exact document shape lands in the scada
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

The consumption grill is resolved (2026-08-11). Next for this spoke:
raise to Accepted (Pass bump is the user's call), then the
persistence grill in
[`journalkeeper-and-history.md`](journalkeeper-and-history.md) — the
Joe conversation — is the remaining Draft spoke before the
implementation gate opens.
