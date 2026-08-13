# gridworks-weather-forecast — rebuild spec

Status: Draft · Pass 0 · Updated 2026-08-13

> Faithful-rebuild hub for gwwf, the fleet's production weather
> source: current-observation and forecast delivery through the
> `gw.weather.*` vocabulary. Read this hub, then the spoke for the
> concern you're touching.

## What gwwf is

gwwf (gridworks-weather-forecast) is a gwbase-native cloud GNode
(parallel to the LTN, FIS, MarketMaker, TimeCoordinator) that:

- publishes station-observed weather and forecast weather as
  broadcasts over the gwbase RabbitJsonBroadcast mechanism
  ([`delivery.md`](delivery.md))
- serves a public read-only HTTP API as the single pull path — drop
  recovery, scada fallback, post-hoc reads, record listing — never
  the primary delivery
- owns the gridworks-weather DB, the sole accessor: canonical seed
  for the `.gt` channel words and the forecast revision store
- grows its production record set only by a human minting act over
  the bus ([`record-lifecycle.md`](record-lifecycle.md))

Deployment and box-level operational facts (login, aliases, ports,
sudoers, DNS) live in
[`gridworks-infra/forecast/instance-README.md`](../../../gridworks-infra/forecast/instance-README.md)
— this executor does not duplicate them. GNode identity:
`hw1.isone.weather`, `WeatherForecastService`, Logical.

## Source posture

NWS is the v0 access path, not a commitment. The vocabulary holds no
source at the observation layer (acquisition is per-reading
provenance) and holds it as a competing Forecaster at the forecast
layer. Observations: KMLT is the physical instrument near the fleet;
NWS is one access path to it (alternatives: Synoptic/MADIS, NCEI).
Forecasts: NWS gridpoint is the free, public-domain baseline
forecaster; challenger forecasters slot in as their own forecast
channels and are skill-scored against the observed series before any
consumer switches.

## Cross-cutting invariants

1. **Records are durable identities, never upserted.** Every
   location / channel / forecast-channel / bundle enters the world
   exactly once, via `gwwf create` — see
   [`record-lifecycle.md`](record-lifecycle.md).
2. **Sema is the boundary.** No hand-built dicts cross the wire; the
   vendored snapshot is regenerated from `sema`, never hand-edited.
3. **Source is provenance, not identity, for observations** — the
   observed value belongs to the channel regardless of which
   acquisition method produced it. Source IS constitutive for
   forecasts — different forecasters are different claims that
   legitimately coexist. See [`vocabulary.md`](vocabulary.md).
4. **The bundle is the subscription unit.** Consumers designate a
   bundle, not individual channels; a bundle's embedded channel
   copies must agree with the canonical records (enforced at
   creation and at boot).
5. **gwwf boots and runs on an empty record set** — the create
   command's consumer necessarily starts before any records exist;
   no records means an idle scheduler, never a boot failure.
6. **Names carry no meaning a reader should parse out.** Every fact
   lives in a record field; names exist for humans and routing.

## Glossary

| Term | Meaning |
|---|---|
| **channel** | `gw.weather.channel.gt` — one observed quantity at one place; the ground-truth series forecasters are scored against. |
| **forecast channel** | `gw.weather.forecast.channel.gt` — one named predictor of one channel; declares its own time-slice shape. |
| **bundle** | `gw.weather.forecast.bundle.gt` — the subscribable sign-up object: a shared time-slice grid + emission schedule across a quantity's forecast-channel/channel pair; its Name is the broadcast radio channel. |
| **location** | `gw.weather.location.gt` — the place anchor; provider-neutral coordinates + external station ids. |
| **observation** | `gw.weather.observation` — the message word carrying a station's real-time reading. |
| **forecast** | `gw.weather.forecast` — the message word carrying one bundle's predicted values for one emission slot. |
| **Fidelity** | the degradation rung a forecast message was built at: live / stored / seasonal.template. |

## Spokes

- [`vocabulary.md`](vocabulary.md) — the `gw.weather.*` word set:
  schemas, axioms, naming, units.
- [`delivery.md`](delivery.md) — cadence, broadcast binding shape,
  the pull-path API, fleet delivery shape.
- [`record-lifecycle.md`](record-lifecycle.md) — how records enter
  and grow the production set; the GNode-registration procedure.
