# delivery — cadence, phase structure, fleet distribution

Status: Draft · Pass 0 · Updated 2026-08-13

What this is: how weather reaches consumers from [gwwf](primary.md)
— broadcast cadence, the hour phase structure, the pull path, and the
fleet delivery shape.

## Cadence

- **Observations broadcast at the top of each hour**, keeping the JK
  series a clean hourly grid. Cadence is schema (EmitPeriodS /
  EmitOffsetS on the channel words, see [`vocabulary.md`](vocabulary.md)),
  so raising it to match the station's true update rate is a
  channel-record change, not a code change.
- **Forecasts broadcast at :01** — as soon as "next hour" changes.
  NWS underlying-data freshness is issuance-driven (2–4 revisions a
  day) and phase-independent, so no emission minute beats another for
  freshness. The hour runs :00 observation → :01 forecast → the FLO's
  window over the rest of the hour: a FLO anywhere in its window knows
  this hour's forecast already arrived, so pull-on-miss has a trivial
  trigger.
- **Pull path = the gwwf HTTP API.** Consumers passively wait for
  broadcasts; the emission schedule on the channel record makes
  "expected" a mechanical timeout contract, and every pull goes
  through one public read-only HTTP API returning sema-typed message
  words. The one API serves all pull consumers: LTN drop recovery,
  scada fallback when its LTN relay goes quiet, and post-hoc/analytics
  reads. It also lists the active channel, forecast-channel, and
  location records (consumers cache; pull again on decode-miss;
  Start-scoped history resolves archived messages). There is no
  broker request/response vocabulary — pull is HTTP-only.
- **Records broadcast once at creation.** Each new record — bundle,
  forecast-channel, channel, location — is broadcast a single time
  when minted, so it enters the immutable store through the universal
  audit tap and an archived message resolves against the record
  active at its time (the bundle word's Start exists for exactly
  this; the forecast message carries no slice grid, so the archive is
  self-contained only with the records in it). No re-broadcast and no
  boot re-emission. Consumer delivery is unchanged by this — nobody
  binds a record stream; consumers cache records and pull-on-miss
  through the API.

## Broadcast binding shape

The radio-channel tail of the `rjb` routing key names the stream
(gwbase transport spec pins the tail as one or more extra **dotted**
segments, appended verbatim — dots preserved, so per-segment wildcard
subscription works):

- **Observations:** radio channel = the location alias
  (`us.me.millinocket`) — the message is per-station and bundles all
  quantities; consumers bind the location, quantities live in the
  payload.
- **Forecasts:** radio channel = the bundle Name, verbatim
  (`us.me.millinocket.forecast.nws.hourly`), one message per BUNDLE
  per emission — the bundle is the sign-up object. The LTN binds
  exactly its designated bundle and receives its whole aligned FLO
  input set atomically.
- **Records:** location, channel, and forecast-channel record
  broadcasts carry the record's own name as the radio tail
  (`us.me.millinocket`, `us.me.millinocket.temperature`, …) — the same
  convention as the streams. The BUNDLE record alone broadcasts with
  NO radio tail. In every case the TypeName segment separates record
  broadcasts from stream messages; nothing binds record
  broadcasts — they exist for the audit tap.

## Fleet delivery shape

- **LTN relay is primary.** Weather rides the existing LTN→scada
  pipe; the scada's comms model stays "my LTN pair is my world" — no
  per-house broker bindings.
- **The scada persists the last-received forecast** (the
  `weather.json` cache pattern, re-sourced from the relay). A cached
  48 h horizon stays useful across a day of LTN silence; staleness is
  visible in the forecast's own timestamps; past the horizon the
  consumer falls back to conservative defaults.
- **Fallback is a pull from the gwwf API** when the expected relay is
  quiet past the schedule contract — the same public endpoint every
  pull consumer uses, not a second broker subscription.
- DerivedGenerator (`gw_spaceheat/actors/derived_generator.py`) is a
  direct local consumer of the 48 h OAT forecast, outside the FLO
  path, for on-peak storage preparation.

## Blessed forecast stream

Which predictor a house consumes is house-level shared operational
config — the LTN (FLO consumption, relay) and the scada (API
fallback pull) MUST name the same forecast BUNDLE, so the value lives
where both actors read it, like the layout; a required field, no
default. A service-published designation record (the fleet-wide
one-flip cutover lever) is minted when a challenger first wins a
shadow season, not before.

## Legacy retirement

Nothing consumes the legacy `weather` / `weather.forecast` words
today (the legacy observation service is stopped). Once the scada
side drops its own weather fetchers and adopts LTN-relay consumption
+ API fallback, the legacy words get `frozen_at` + `replaced_by` in
the sema registry.
