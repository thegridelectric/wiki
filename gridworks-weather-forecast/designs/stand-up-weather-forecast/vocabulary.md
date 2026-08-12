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

    Name:              left.right.dot  # us.me.millinocket.temperature.forecast.nws.hourly
    TargetChannelName: left.right.dot  # names a gw.weather.channel.gt (axiom)
    Forecaster:        left.right.dot  # us.nws.gridpoint | gw.bias.corrected.v1
    Method:            left.right.dot  # api.weather.gov.gridpoint.hourly
    SourceLocator:     string          # car.60.114
    TotalSlices:             positive.int   # 48 — declared, axiom-held
    SliceDurationSList:      [positive.int] # [3600] × 48; non-uniform allowed
    ForecastDurationMinutes: positive.int   # 2880 — declared, axiom-held
    EmitPeriodS:             positive.int   # 3600
    EmitOffsetS:             non-negative int # 60 — the :01 broadcast
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
(new Id), never a mutation. Distinct concurrent time-slice SHAPES are
distinct channels — the slug's shape tail discriminates them (decided
2026-08-11: `nws.hourly`; a near-horizon 5-minute product would
coexist as its own channel, e.g. `nws.min5`, not succeed the hourly
one). Within a shape, the Name persists across structural tweaks
(same target, same forecaster, same shape), and records carry a
validity start so an archived message resolves against the record
active at its time (cf. `data.channel.gt.StartS`).

## gw.weather.forecast.bundle.gt — the sign-up object

The curated, subscribable set of forecast channels sharing one
time-slice grid and one emission schedule, together with the observed
channels they target — the unit a consumer designates and receives
(added 2026-08-12). The bundle's Name is, verbatim, the broadcast
radio channel (gwbase's term for the subscription slug — never
"channel" unqualified, which is a data channel), and each message
carries it as BundleName. A record fetched rarely (seed, record
listing), never carted per-message — so it embeds all four channels
as full subtypes (`TempForecastChannel` + `TempObservationChannel`,
`WindSpeedForecastChannel` + `WindSpeedObservationChannel`) plus a
top-level `LocationAlias`: one fetch hands a consumer the whole
contract, and every cross-fact is an in-type axiom — shared grid,
shared schedule, target binding (each forecast channel's
TargetChannelName equals its paired observation channel's Name),
quantity targeting, location consistency, and Name =
LocationAlias + ".forecast." + slug. That last axiom makes the
observation↔forecast link explicit: the bundle slug EXTENDS the
location alias that names the observation broadcasts for the same
place. gwwf additionally enforces the embedded copies' agreement
with its canonical records at seed/boot. Bundles are per-service —
price forecasts get their own word in their own service, and a
shadow challenger stands up its own (its emissions need a bundle to
ride). `.gt`: the weather DB is the canonical seed.

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

One observation message per station observation (hard-coded
quantities since the 2026-08-12 reshape — symmetry of ceremony with
the forecast word):

    { LocationAlias, ObservationTime, Interpolated,
      TempChannelName, TempValue, WindSpeedChannelName, WindSpeedValue? }

Values are integers scaled per the channel's Unit. WindSpeedValue is
optional — KMLT sometimes reports no wind; absence is absence, never
a sentinel. Adding a quantity is a version bump. LocationAlias rides
the payload (the radio channel does not survive archival) and anchors
the LocationNaming axiom: both channel names begin with it —
decode-time protection against field swaps. `gw.weather.reading`
retired with the reshape.

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

The forecast message is the FLO-curated contract (reshaped
2026-08-12): hard-coded quantities, one message per BUNDLE per
emission slot, structure declared on the channel records so the wire
needs no Times list:

    { BundleName, SourceUpdatedTime, MessageCreatedMs, Fidelity,
      FirstSliceStart,
      TempChannelName, TempValues, WindSpeedChannelName, WindSpeedValues }

Hard-coding the quantities (rather than a generic entry list) makes
the type BE the FLO's input contract: adding a quantity is a version
bump — the right ceremony for "the FLO's inputs changed". Axioms:
value lists non-empty and equal length; channel names distinct; all
three names carry "forecast" as an interior segment (decode-time
protection against field swaps — an observed channel name in a
forecast slot fails standalone, no records needed). Slice boundaries
derive from the single FirstSliceStart plus the bundle channels'
shared SliceDurationSList. BundleName rides the payload because the
routing key's radio channel does not survive archival (the eventstore
key grammar drops it) — the archived message stays self-describing,
and it is the join key to the bundle record. Shadow-running a
challenger means standing up its own bundle; skill-scoring reads
per-channel series out of bundle messages (or the API).

**Forecast emission and degradation.** Consumers always need a
forecast, so gwwf always emits on the bundle's schedule — the
schedule contract is what makes a missing message mean a drop. Two
clocks (split 2026-08-12, replacing the ambiguous ForecastCreated):
`SourceUpdatedTime` is the ingested external service's underlying
data revision (for NWS the gridpoint `updateTime`, not `generatedAt`,
which refreshes per render even when the data is hours older) and may
hold unchanged across many emissions while the source sits on a
package — the 2026-08-11 probe watched one NWS package hold 7.4 h.
`MessageCreatedMs` is gwwf's own emission stamp and advances every
send, so re-emissions of a held source revision are distinguishable
sends of the same claim, each with the current sliding window
(FirstSliceStart anchors to the next slice boundary; the forward
horizon never shrinks). The degradation ladder when the source goes
stale: (1) live product; (2) draw down the stored horizon — the
service stores ~24 h beyond the broadcast horizon (NWS hourly gives
~156 h, so storing 72 costs nothing), keeping full-length forecasts
through a day-long source outage; (3) a seasonal template. `Fidelity`
(enum: live | stored | seasonal.template) marks the rung per message,
keeping the claim honest: template messages are explicitly declared
fill. Each downgrade transition raises a Glitch.

**Sent forecasts are the store's rows.** Every emitted message lands
in the service DB (surrogate uuid key, never serialized), one row per
send-distinct message; `SourceUpdatedTime` remains how a consumer
asks about the source claim ("the forecast made from the 14:00
revision") and greps by eye in the archive.

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
interpolated fills live in the base series, marked on the message.
Forecast channels: TargetChannelName + ".forecast." + a
forecaster-and-shape slug (`nws.hourly`), axiom-derived. Bundles:
location + ".forecast." + slug (`us.me.millinocket.forecast.nws.hourly`)
— the subscription unit; per-channel wildcards left the wire when
emission became per-bundle (2026-08-12), and every forecast-family
name carries "forecast" as an interior segment by axiom. Names are
for humans and routing; facts come from the record — nothing is
parsed out of a name. LRD names give per-segment wildcard
subscription (`us.me.millinocket.#`).

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

The word set is authored (staging; r2 reshape 2026-08-12 on sema
branch `jm/weather-words-r2`): `gw1.quantity` 002 (adds WindSpeed);
`gw.weather.forecast.fidelity` (Unknown default as the enum-coercion
target; Live | Stored | SeasonalTemplate); the record words
`gw.weather.channel.gt`, `gw.weather.forecast.channel.gt`,
`gw.weather.forecast.bundle.gt`, `gw.weather.location.gt`; the
message words `gw.weather.observation` and `gw.weather.forecast`
(both hard-coded quantities; `gw.weather.reading` and
`gw.weather.forecast.entry` retired with the r2 reshape). Axiom
validators implemented with counterexample fixtures; suite green.
Missing-word note carried in the location record: an IANA-timezone
format would retire the hand-validated Timezone field. gwwf still
runs on the r1 snapshot — the cutover (regen + scheduler/store/API)
is the next build move.

The snapshot is vendored into gridworks-weather-forecast
([`build.md`](build.md) step 0).
