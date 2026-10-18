# gridworks-weather-forecast — rebuild spec

Status: Draft · Pass 0 · Updated 2026-10-18

> Faithful-rebuild hub for the weather service: observation and
> forecast delivery through the `gw.weather.*` vocabulary. Read this
> hub, then the spoke for the concern you are touching. The repo README
> says what the service is and what it speaks; this hub does not repeat
> it.

## Identity

A gwbase cloud GNode, role `WeatherForecastService`, Logical, one per
universe, hanging directly under the universe root (`d1.weather`,
`hw1.weather`). It owns the weather database and is its only accessor.
Where it runs and how it is operated is
`gridworks-infra/forecast/instance-README.md`.

## Source posture

The vocabulary holds no source at the observation layer and holds it
as a competing Forecaster at the forecast layer. A station is a
physical instrument; the path its readings arrive by is provenance per
reading. A forecaster is one claim about the future among several that
coexist; a challenger enters as its own forecast channel and its own
bundle, and is skill-scored against the observed series before any
consumer switches. NWS gridpoint is the free, public-domain baseline;
Open-Meteo serves irradiance. Open-Meteo's free tier is non-commercial:
agreed with Open-Meteo (2026-10-15), the fleet runs on it until
GridWorks is commercial, then on the $30-a-month plan. One location at
one call an hour is far under the free tier's 10,000 calls a day.

## Cross-cutting invariants

1. **Records are durable identities.** Every location, station,
   channel, forecast channel, bundle and template enters the world
   once, by the create command, and is never changed in place; a
   change is a new record ([`record-lifecycle.md`](record-lifecycle.md)).
2. **Sema is the boundary.** Every message in or out is a listed word
   at its listed version, encoded and decoded through the vendored
   snapshot; a body the snapshot refuses is refused as the clause says.
3. **Source is provenance for observations and identity for
   forecasts.** An observed value belongs to its channel whatever
   method fetched it; a forecast belongs to its forecaster.
4. **The bundle is the subscription unit.** A consumer designates a
   bundle. A bundle's embedded channel copies equal the canonical
   records, checked at creation and at boot, and the service emits
   exactly the series the bundle binds.
5. **The service boots and runs on an empty record set.** No records
   means an idle scheduler and a running create consumer.
6. **Names encode nothing a reader parses out.** Every fact is a
   record field; names are for people and routing.

## Glossary

Terms the service uses beyond the words' own definitions.

| Term | Meaning |
|---|---|
| **radio channel** | gwbase's name for the dotted tail of a broadcast routing key, the stream a consumer binds. Never "channel" unqualified, which is a data channel. |
| **emission slot** | one instant on a record's grid (EmitPeriodS, EmitOffsetS) at which the service publishes. |
| **fidelity** | the rung a forecast series was built at: live, stored, or seasonal.template. |
| **the stored horizon** | the forecast rows the service keeps beyond the broadcast horizon, drawn down when a source is stale. |
| **acquisition** | one Method plus one SourceLocator: one fetch, one stored product, shared by every forecast channel on it. |

## Spokes

- [`vocabulary.md`](vocabulary.md): what the service does with the
  `gw.weather.*` words beyond what the words themselves state.
- [`delivery.md`](delivery.md): cadence, broadcast binding shape, the
  pull path.
- [`record-lifecycle.md`](record-lifecycle.md): how a record enters.
