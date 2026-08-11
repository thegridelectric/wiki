# vocabulary — the gw.weather.* words

Status: Accepted · Pass 1 · Updated 2026-08-11 · Linear: OPS-436

What this is: the word set for [stand-up-weather-forecast](primary.md)
— sketches, axioms, naming, units, time formats — and the authoring
gate that closes it. All words are gw-prefixed: the channel/predictor structure
is a GridWorks-specific way of organizing weather semantics (gw does
not mean internal-only; other entities may adopt gw words).

## gw.weather.channel.gt — the observed series

One quantity per channel; the ground-truth series for a place. `.gt`:
coupled bijectively with a table in the gridworks-weather DB. No
Source/Method/SourceLocator: for observed data the acquisition path is
provenance, not identity — one channel's readings arrive by several
methods over its life (live API, archive backfill), with provenance
per-reading via the reading→message link and the service DB. Station
identity anchors in gw.weather.location.

    Name:          left.right.dot   # us.me.millinocket.temperature
    DisplayName:   string
    Quantity:      enum gw1.quantity  # Temperature | WindSpeed (002 adds WindSpeed)
    Unit:          enum gw1.unit    # FahrenheitX100, MilesPerHourX1000
    LocationAlias: left.right.dot   # resolves to gw.weather.location
    EmitPeriodS:   positive.int     # 3600
    EmitOffsetS:   non-negative int # 0 — top of hour; axiom: < EmitPeriodS
    Id:            uuid4.str

## gw.weather.forecast.channel.gt — a named predictor

One observed series, many named predictors. The asymmetry separating
the two words: for observations, acquisition is provenance (the
temperature WAS the temperature); a forecast's producer is
constitutive — "NWS's prediction" and "gw's bias-corrected prediction"
are different claims that legitimately coexist, and better forecasts
for the same location means new predictors competing against the same
observed series. `.gt`, mirrored in the gridworks-weather DB.

    Name:              left.right.dot  # us.me.millinocket.temperature.forecast.nws
    TargetChannelName: left.right.dot  # names a gw.weather.channel.gt (axiom)
    Forecaster:        left.right.dot  # us.nws.gridpoint | gw.bias.corrected.v1
    Method:            left.right.dot  # api.weather.gov.gridpoint.hourly
    SourceLocator:     string          # car.60.114
    TotalSlices:             positive.int   # 48 — declared, axiom-held
    SliceDurationSList:      [positive.int] # [3600] × 48; non-uniform allowed
    ForecastDurationMinutes: positive.int   # 2880 — declared, axiom-held
    EmitPeriodS:             positive.int   # 3600
    EmitOffsetS:             non-negative int # 1800 — the :30 broadcast
    Id:                      uuid4.str

Structure axioms:

1. TotalSlices = len(SliceDurationSList)
2. sum(SliceDurationSList) = ForecastDurationMinutes × 60
3. every element of SliceDurationSList is a positive multiple of 300 s
   — the 5-minute quantum, aligned with the KMLT observation cadence,
   real-time price intervals, and five-minute FLOs; it also makes
   ForecastDurationMinutes always exact.

TotalSlices and ForecastDurationMinutes are deliberately redundant:
channel records are not carted per-message, so declared redundancy is
cheap, consumers read totals without arithmetic, and the axioms carry
the consistency. There is deliberately NO created-before-start axiom —
hindcast channels are legal (a challenger forecaster backtesting
against history emits predictions about the past for skill-scoring),
and consumers read the structure fields instead of assuming
forward-looking.

Changing the time sequence (or any structural fact) is a NEW record
(new Id), never a mutation. Lean: the Name persists when only
structure changes (same target, same forecaster), and records carry a
validity start so an archived message resolves against the record
active at its time (cf. `data.channel.gt.StartS`).

## gw.weather.location.gt — the place anchor

Resolution target for LocationAlias, and the join point for verifying
a good match between a scada's actual (encrypted) location_id and its
weather station — station-level geography is fine in the persistent
store (PII holds at thousands-of-homes granularity). Carries
coordinates, timezone, and the external-id bundle (ICAO station,
WBAN / GHCN / COOP archive ids) that anchors the observed series and
keys archive backfills. `.gt`: the locations table in the
gridworks-weather DB is the seed. Record: Alias (left.right.dot),
latitude/longitude as integer microdegrees (×10⁶, ~0.11 m precision —
the vocabulary carries no floats; decimal degrees render only at API
boundaries), timezone, external ids, Id.

The place-anchored word is provider-neutral by design: NWS forecasts
are gridpoint-native, but the gridpoint is one forecaster's
acquisition detail and lives on the NWS forecast channel as its
SourceLocator. Challenger forecasters on other grids (Open-Meteo,
PWS-sited) share the location and the observed series — the
skill-scoring join point — precisely because location identity is not
any provider's grid.

Rationale: location identity is method-scoped even within one source
(NWS live-probed 2026-08-10: observations are station-native — ICAO
KMLT, airport coords; forecasts gridpoint-native — CAR 60,114; alerts
zone-native — MEZ005; archives use WBAN / GHCN / COOP ids, specifics
to verify before canonizing). Per-method locators therefore live on
the entity whose acquisition they describe: forecast channels carry
the gridpoint, the location word carries the station bundle.

## The message words

Two message words: `gw.weather.observation` and `gw.weather.forecast`.
"Observation" over "current": the claim is archive-honest — the
station observed these values at ObservationTime — and matches NWS's
noun for the product.

One observation message per station observation:

    { ObservationTime, Interpolated, Readings: [ {ChannelName, Value}, ... ] }

Values are integers scaled per the channel's Unit. The quantity set is
open — a new quantity is a new channel row and list entry, no type
churn; a missing quantity is an omitted entry, not an optional field.

**Observation semantics.** At each emission slot gwwf publishes the
newest available station observation with its true ObservationTime;
a stale observation is never re-published (the data serves post-hoc
calculation, and repeats pollute the series). When the station has
produced nothing new, the slot stays silent; on recovery gwwf replays
the missed grid points as ordinary observation messages — one per
missed time — with fabricated values (interpolated between the
bracketing real observations) marked `Interpolated: true` and real
late-arriving observations unmarked. Interpolation is bounded: gaps
up to 3 h are filled; a longer gap stays a gap — no fill at all
(archive backfill with real readings remains available for those,
and a nearby-station fallback is explicitly out of standup scope).
One gap-free-where-credible series for post-hoc use; fabrication is
explicit per message; provenance rides the reading→message link. An
observation older than 1 h (tunable) at publish time raises a Glitch.

Forecast messages mirror the skeleton; with structure declared on the
channel, the wire needs no Times list:

    { ForecastCreated, Fidelity, Forecasts: [ {ChannelName, FirstSliceStart, Values}, ... ] }

Axiom: len(Values) = the channel's TotalSlices; slice start times
derive from FirstSliceStart plus the cumulative sum of
SliceDurationSList. One message per model emission. This is what
enables shadow-running a challenger model and skill-scoring it against
the observed series without disturbing consumers; the LTN consumes a
designated stream.

**Forecast emission and degradation.** Consumers always need a
forecast, so gwwf always emits on the channel's schedule — the
schedule contract is what makes a missing message mean a drop.
ForecastCreated is the forecaster's own data stamp (for NWS the
gridpoint `updateTime`, not `generatedAt`, which refreshes per render
even when the data is hours older), so an unchanged product re-emits
identically: consumers see "same revision, still alive" and stores
stay idempotent. The degradation ladder when the source goes stale:
(1) live product; (2) draw down the stored horizon — the service
stores ~24 h beyond the broadcast horizon (NWS hourly gives ~156 h,
so storing 72 costs nothing), keeping full-length forecasts through a
day-long source outage; (3) a seasonal template. `Fidelity` (enum:
live | stored | seasonal.template; enum word named at authoring —
weather-specific, no fleet-wide analog) marks the rung per message,
keeping the channel's constitutive Forecaster claim honest: template
messages are explicitly declared fill. Each downgrade transition
raises a Glitch.

**Revision identity is the natural key** (forecast channel,
ForecastCreated) — no wire uid. gwwf is the single producer, so the
pair names a revision globally; it is how consumers actually ask for
one ("the forecast for this channel made at 14:00"), it stays
idempotent under repeats, and it greps by eye in the archive. The DB
keys on the composite (or an internal surrogate — implementation
choice, never serialized).

**Implementation note:** slice arithmetic and the recovery
interpolation grid always derive from the channel record
(SliceDurationSList, EmitPeriodS / EmitOffsetS) — nothing hardcodes
3600 — so time-varying slices are a channel-record change, not a code
change.

**Time formats:** human-audited, low-arithmetic fields use
`utc.iso8601.seconds` for archive readability — ObservationTime,
ForecastCreated, FirstSliceStart, channel validity start — named
without the `S` suffix, which connotes epoch seconds. Arithmetic
parses once; the S3 record is greppable by eye. (NWS `updateTime` is
native ISO8601 — no conversion at the bind.)

## Naming

Observed channels: `<location-alias>.<quantity>[.<variant>]` — place
first, source never in the name (source/method are record fields
where they exist at all). The quantity segment is the lowercased
Quantity value, held by axiom: Name = LocationAlias + "." +
lowercase(Quantity) (+ variant). The variant suffix is reserved for
semantically different series (e.g. tmy), not acquisition detail;
interpolated fills live in the base series, marked on the message. Forecast channels: TargetChannelName + ".forecast." +
forecaster slug, axiom-derived; `<target>.forecast.#` subscribes every
predictor of a series. Names are for humans and routing; facts come
from the record — nothing is parsed out of a name. LRD names give
per-segment wildcard subscription (`us.me.millinocket.#`).

Name format: `left.right.dot` canonical (fleet-scoped identity,
routing-key-ready). `spaceheat.name` and LRD are dash↔dot bijective
(same segment grammar; the eventstore filename grammar already uses
the swap), so a spaceheat.name-shaped slot renders any channel name
mechanically.

## Units and quantities

`gw1.unit`, expanded additively. It already carries MilesPerHourX1000
and DollarsX1000 (JK's pseudo channels), values a versioned enum
cannot retract, so a scada-pure gw1.unit is unreachable; and
scaled-integer-units is a GridWorks-specific approach, so the gw
prefix is semantically right. Current weather needs no new values.
Quantity takes the same posture: `gw1.quantity`, expanded additively
— one fleet-wide quantity vocabulary, no weather-scoped enum. 002
adds WindSpeed (Temperature is already present; "WindSpeed" over
dimension-pure "Speed" — the enum admits logical interpretations, and
the channel-name segment derives from it: `…millinocket.windspeed`).

## Authoring state

The word set is authored (staging, on sema `dev` at `origin/dev`):
`gw1.quantity` 002 (adds WindSpeed);
`gw.weather.forecast.fidelity` (Unknown default as the enum-coercion
target; Live | Stored | SeasonalTemplate); the record words
`gw.weather.channel.gt`, `gw.weather.forecast.channel.gt`,
`gw.weather.location.gt`; the message words `gw.weather.observation`
(+ `gw.weather.reading` list item) and `gw.weather.forecast`
(+ `gw.weather.forecast.entry` list item — items promoted to named
types so the channel-uniqueness axioms are expressible). Axiom
validators implemented with counterexample fixtures; suite green.
Missing-word note carried in the location record: an IANA-timezone
format would retire the hand-validated Timezone field.

The snapshot is vendored into gridworks-weather-forecast
([`build.md`](build.md) step 0).
