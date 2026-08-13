# vocabulary — the gw.weather.* words

Status: Draft · Pass 0 · Updated 2026-08-13

What this is: the current `gw.weather.*` word set for
[gwwf](primary.md) — schemas, axioms, naming, units, time formats.
All words are gw-prefixed: the channel/predictor structure is a
GridWorks-specific way of organizing weather semantics (gw does not
mean internal-only; other entities may adopt gw words).

## gw.weather.location.gt — the place anchor

Resolution target for `LocationAlias`, and the join point for
verifying a good match between a scada's actual (encrypted)
location_id and its weather station — station-level geography is
fine in the persistent store (PII holds at thousands-of-homes
granularity). Carries coordinates, timezone, and the external-id
bundle (ICAO station, WBAN / GHCN / COOP archive ids) that anchors
the observed series and keys archive backfills. `.gt`: the locations
table in the gridworks-weather DB is the seed.

    Alias:                 left.right.dot
    LatitudeMicrodegrees:  integer (×10⁶, ~0.11 m precision)
    LongitudeMicrodegrees: integer
    Timezone:              string (IANA name; hand-validated)
    IcaoId / WbanId / GhcnId / CoopId: string, optional
    Id:                    uuid4.str

Provider-neutral by design: NWS forecasts are gridpoint-native, but
the gridpoint is one forecaster's acquisition detail and lives on the
NWS forecast channel as its `SourceLocator`. Challenger forecasters
on other grids share the location and the observed series — the
skill-scoring join point — precisely because location identity is not
any provider's grid. Location identity is method-scoped even within
one source: observations are station-native (ICAO), forecasts
gridpoint-native, archives use WBAN/GHCN/COOP ids — per-method
locators live on the entity whose acquisition they describe.

## gw.weather.channel.gt — the observed series

One quantity per channel; the ground-truth series for a place. `.gt`:
coupled bijectively with a table in the gridworks-weather DB. No
Source/Method/SourceLocator: for observed data the acquisition path
is provenance, not identity — one channel's readings arrive by
several methods over its life (live API, archive backfill), with
provenance per-reading via the reading→message link and the service
DB. Station identity anchors in `gw.weather.location`.

    Name:          left.right.dot   # us.me.millinocket.temperature
    DisplayName:   string
    Quantity:      enum gw1.quantity  # Temperature | WindSpeed
    Unit:          enum gw1.unit      # FahrenheitX100, MilesPerHourX1000
    LocationAlias: left.right.dot     # resolves to gw.weather.location
    EmitPeriodS:   positive.int       # 3600
    EmitOffsetS:   non-negative int   # 0 — top of hour; axiom: < EmitPeriodS
    Id:            uuid4.str

## gw.weather.forecast.channel.gt — a named predictor

One observed series, many named predictors. The asymmetry separating
this word from the observed channel: for observations, acquisition is
provenance (the temperature WAS the temperature); a forecast's
producer is constitutive — "NWS's prediction" and "gw's bias-corrected
prediction" are different claims that legitimately coexist, and
better forecasts for the same location means new predictors competing
against the same observed series. `.gt`, mirrored in the
gridworks-weather DB.

    Name:              left.right.dot  # us.me.millinocket.temperature.forecast.nws.hourly
    TargetChannelName: left.right.dot  # names a gw.weather.channel.gt (axiom)
    Forecaster:        left.right.dot  # us.nws.gridpoint | gw.bias.corrected.v1
    Method:            left.right.dot  # api.weather.gov.gridpoint.hourly
    SourceLocator:     string          # car.60.114
    TotalSlices:             positive.int   # 48 — declared, axiom-held
    SliceDurationSList:      [positive.int] # [3600] × 48; non-uniform allowed
    ForecastDurationMinutes: positive.int   # 2880 — declared, axiom-held
    EmitPeriodS:             positive.int
    EmitOffsetS:              non-negative int
    Id:                      uuid4.str

Structure axioms:

1. `TotalSlices = len(SliceDurationSList)`
2. `sum(SliceDurationSList) = ForecastDurationMinutes × 60`
3. every element of `SliceDurationSList` is a positive multiple of
   300 s — the 5-minute quantum, aligned with the KMLT observation
   cadence, real-time price intervals, and five-minute FLOs; it also
   makes `ForecastDurationMinutes` always exact.

`TotalSlices` and `ForecastDurationMinutes` are deliberately
redundant: channel records are not carted per-message, so declared
redundancy is cheap, consumers read totals without arithmetic, and
the axioms carry the consistency. There is deliberately NO
created-before-start axiom — hindcast channels are legal (a
challenger forecaster backtesting against history emits predictions
about the past for skill-scoring), and consumers read the structure
fields instead of assuming forward-looking.

Changing the time sequence (or any structural fact) is a NEW record
(new Id), never a mutation. Distinct concurrent time-slice SHAPES are
distinct channels — the slug's shape tail discriminates them (e.g.
`nws.hourly`; a near-horizon 5-minute product coexists as its own
channel, `nws.min5`, never succeeding the hourly one). Within a
shape, the Name persists across structural tweaks, and records carry
a validity start so an archived message resolves against the record
active at its time (cf. `data.channel.gt.StartS`).

## gw.weather.forecast.bundle.gt — the sign-up object

The curated, subscribable set of forecast channels sharing one
time-slice grid and one emission schedule, together with the observed
channels they target — the unit a consumer designates and receives.
The bundle's Name is, verbatim, the broadcast radio channel (gwbase's
term for the subscription slug — never "channel" unqualified, which
is a data channel), and each message carries it as `BundleName`. A
record fetched rarely (seed, record listing), never carted
per-message — so it embeds all four channels as full subtypes
(`TempForecastChannel` + `TempObservationChannel`,
`WindSpeedForecastChannel` + `WindSpeedObservationChannel`) plus a
top-level `LocationAlias`: one fetch hands a consumer the whole
contract, and every cross-fact is an in-type axiom — shared grid,
shared schedule, target binding (each forecast channel's
`TargetChannelName` equals its paired observation channel's Name),
quantity targeting, location consistency, and
`Name = LocationAlias + ".forecast." + slug`. That last axiom makes
the observation↔forecast link explicit: the bundle slug EXTENDS the
location alias that names the observation broadcasts for the same
place. gwwf additionally enforces the embedded copies' agreement with
its canonical records at creation and at boot. Bundles are
per-service — price forecasts get their own word in their own
service, and a shadow challenger stands up its own (its emissions
need a bundle to ride). `.gt`: the weather DB is the canonical seed.

## The message words

Two message words: `gw.weather.observation` and `gw.weather.forecast`.
"Observation" over "current": the claim is archive-honest — the
station observed these values at ObservationTime — matching NWS's
noun for the product.

One observation message per station observation, hard-coded
quantities:

    { LocationAlias, ObservationTime, Interpolated,
      TempChannelName, TempValue, WindSpeedChannelName, WindSpeedValue? }

Values are integers scaled per the channel's Unit. WindSpeedValue is
optional — KMLT sometimes reports no wind; absence is absence, never
a sentinel. Adding a quantity is a version bump. LocationAlias rides
the payload (the radio channel does not survive archival) and anchors
the LocationNaming axiom: both channel names begin with it —
decode-time protection against field swaps.

**Observation semantics.** At each emission slot gwwf publishes the
newest available station observation with its true ObservationTime; a
stale observation is never re-published (the data serves post-hoc
calculation, and repeats pollute the series). When the station has
produced nothing new, the slot stays silent; on recovery gwwf replays
the missed grid points as ordinary observation messages — one per
missed time — with fabricated values (interpolated between the
bracketing real observations) marked `Interpolated: true`, and real
late-arriving observations unmarked. Interpolation is bounded: gaps up
to 3 h are filled; a longer gap stays a gap (archive backfill with
real readings remains available for those; a nearby-station fallback
is out of scope). An observation older than 1 h (tunable) at publish
time raises a Glitch.

The forecast message is the FLO-curated contract: hard-coded
quantities, one message per BUNDLE per emission slot, structure
declared on the channel records so the wire needs no Times list:

    { BundleName, SourceUpdatedTime, MessageCreatedMs, Fidelity,
      FirstSliceStart,
      TempChannelName, TempValues, WindSpeedChannelName, WindSpeedValues }

Hard-coding the quantities (rather than a generic entry list) makes
the type BE the FLO's input contract: adding a quantity is a version
bump — the right ceremony for "the FLO's inputs changed." Axioms:
value lists non-empty and equal length; channel names distinct; all
three names carry "forecast" as an interior segment (decode-time
protection against field swaps). Slice boundaries derive from the
single FirstSliceStart plus the bundle channels' shared
SliceDurationSList. BundleName rides the payload because the routing
key's radio channel does not survive archival — the archived message
stays self-describing, and it is the join key to the bundle record.
Shadow-running a challenger means standing up its own bundle;
skill-scoring reads per-channel series out of bundle messages (or the
API).

**Forecast emission and degradation.** Consumers always need a
forecast, so gwwf always emits on the bundle's schedule — the
schedule contract is what makes a missing message mean a drop. Two
clocks: `SourceUpdatedTime` is the ingested external service's
underlying data revision (for NWS the gridpoint `updateTime`, not
`generatedAt`, which refreshes per render even when the data is hours
older) and may hold unchanged across many emissions while the source
sits on a package. `MessageCreatedMs` is gwwf's own emission stamp
and advances every send, so re-emissions of a held source revision
are distinguishable sends of the same claim, each with the current
sliding window (FirstSliceStart anchors to the next slice boundary;
the forward horizon never shrinks). The degradation ladder when the
source goes stale: (1) live product; (2) draw down the stored
horizon — the service stores ~24 h beyond the broadcast horizon (NWS
hourly gives ~156 h, so storing 72 costs nothing), keeping
full-length forecasts through a day-long source outage; (3) a
seasonal template. `Fidelity` (enum: live | stored | seasonal.template)
marks the rung per message, keeping the claim honest — template
messages are explicitly declared fill. Each downgrade transition
raises a Glitch.

**Sent forecasts are the store's rows.** Every emitted message lands
in the service DB (surrogate uuid key, never serialized), one row per
send-distinct message; `SourceUpdatedTime` remains how a consumer
asks about the source claim and greps by eye in the archive.

**Implementation note:** slice arithmetic and the recovery
interpolation grid always derive from the channel record
(SliceDurationSList, EmitPeriodS / EmitOffsetS) — nothing hardcodes
3600 — so time-varying slices are a channel-record change, not a code
change.

**Time formats:** human-audited, low-arithmetic fields use
`utc.iso8601.seconds` for archive readability — ObservationTime,
FirstSliceStart, channel validity start — named without the `S`
suffix, which connotes epoch seconds. (NWS `updateTime` is native
ISO8601 — no conversion at the bind.)

## Naming

Observed channels: `<location-alias>.<quantity>[.<variant>]` — place
first, source never in the name. The quantity segment is the
lowercased Quantity value, held by axiom:
`Name = LocationAlias + "." + lowercase(Quantity)` (+ variant). The
variant suffix is reserved for semantically different series (e.g.
tmy), not acquisition detail; interpolated fills live in the base
series, marked on the message. Forecast channels:
`TargetChannelName + ".forecast." + <forecaster-and-shape slug>`
(`nws.hourly`), axiom-derived. Bundles: `location + ".forecast." +
slug` (`us.me.millinocket.forecast.nws.hourly`) — the subscription
unit; every forecast-family name carries "forecast" as an interior
segment by axiom. Names are for humans and routing; facts come from
the record — nothing is parsed out of a name. LRD names give
per-segment wildcard subscription (`us.me.millinocket.#`).

Name format: `left.right.dot` canonical (fleet-scoped identity,
routing-key-ready). `spaceheat.name` and LRD are dash↔dot bijective
(same segment grammar), so a spaceheat.name-shaped slot renders any
channel name mechanically.

## Units and quantities

`gw1.unit`, expanded additively — a scada-pure gw1.unit is
unreachable since it already carries GridWorks-specific
scaled-integer units, so the gw prefix is semantically right.
`gw1.quantity` takes the same posture: one fleet-wide quantity
vocabulary, no weather-scoped enum (Temperature, WindSpeed).
