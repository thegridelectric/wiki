# stand-up-weather-forecast

Status: Draft · Pass 0 · Updated 2026-07-18 · Linear: OPS-436

**EDD: yes** the near-term bar is real-broker `weather` delivery consumed
in production (JournalKeeper capture + an LTN) with the legacy source
retired; the forecast-service phase adds real-broker forecast delivery to
a consuming LTN.

> What this is: stand up gwwf (gridworks-weather-forecast) as the fleet's
> production weather source. The legacy `run_weather` on journalmaker was
> stopped by hand 2026-07-18 (it rode through the rabbit-4.x flip
> working, then was retired) — **the fleet has no weather source until
> this lands**, an accepted July gap. The longer arc is the
> weather-forecast service as a gwbase-native cloud GNode (parallel to
> the LTN, FIS, MarketMaker, TimeCoordinator), whose forecasts the LTN's
> FLO consumes — intent thought through in
> [`../research/design-intent.md`](../research/design-intent.md).

## First step — replicate the legacy behavior (SHALL come first)

The reference implementation is what actually ran on journalmaker until
2026-07-18: **gridworks-journalkeeper @ `47ff87eae`** ("Update tests") —
entrypoint `run_weather.py` (repo root), service
`src/gjk/weather_service.py`, wire type `src/gjk/named_types/weather.py`.
Behavior to replicate before anything else: poll NWS for the latest KMLT
observation every 600 s and publish a `weather` message on channel
`weather.gov.kmlt` (the legacy consume side, `ws_tx`, is dead-era and not
part of the contract). Step one of execution is demonstrating gwwf
producing the same wire output that service produced — same type +
version, channel, field semantics, cadence — with the JournalKeeper's
capture and the LTN FLO as the consumers of record. Everything below
builds on that parity being shown, not assumed.

## The legacy wire contract — production evidence

A verbatim archived message (S3
`gwdev/hw1__1/eventstore/20260718/hw1.isone.ws-weather-1784374799353-ear.electricity.works.json`
— the last one the legacy service ever published, 11:40 UTC on its final
morning):

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

Type definition it matches: gjk @ `47ff87eae`
`src/gjk/named_types/weather.py` (`weather` v000; `wind_speed_mph`
optional). Cadence check: 70 messages in the 20260718 UTC-day folder
through 11:40 UTC — exactly one per 10-minute poll. The S3 eventstore
(`gwdev/hw1__1/eventstore/YYYYMMDD/`) holds months of further samples.
The byte-exact object is committed as a fixture at
`gridworks-weather-forecast/tests/hw1.isone.ws-weather-1784374799353-ear.electricity.works.json`
— the parity test's reference input.

Note the parity trap in `FromGNodeAlias`: the wire carries
`hw1.isone.ws`. If gwwf gets a new GNode identity (dimension 2), this
field — and the message's routing key — changes with it; whether any
consumer keys on the alias rather than `WeatherChannelName` must be
established before the identity decision is made.

## The decision dimensions

1. **Wire parity** — the first step above, held as the gate: no home /
   identity / deploy work counts until the replicated output is verified.
   Scope note, settled from the S3 eventstore: `weather.forecast`
   messages are published by the house SCADAs (hourly, per house — e.g.
   `hw1.isone.me.versant.keene.beech.scada-weather.forecast-…`), never by
   the weather service. The replication step covers only the `weather`
   observation broadcast; the scada-side forecast duplication is the
   follow-on below.
2. **The GNode json file.** Decide gwwf's g-node identity record (sema
   `g.node.gt.json` naming conventions) — alias, role, and where the file
   lives.
3. **gwbase update.** Bring gwwf to the latest gwbase before deploying
   (it was ported against 0.4.0).
4. **Home.** NOT legacy journalmaker — the box is slated for retirement.
   Pick the durable home here.

## Follow-on — fleet weather distribution (grill to come)

The S3 evidence shows every house SCADA attaching to weather services
itself and posting its own hourly `weather.forecast` — six duplicate
fetchers, six versions of truth, each house depending on its own outbound
internet fetch. This design's follow-on removes that: **take the weather
fetch OUT of the scada** and replace it with pipes that deliver weather
TO the scada. This is where the gwbase-native forecast-service intent
(`../research/design-intent.md`) lands. The delivery shape is
deliberately left for its own grill; the candidate tree:

- **Through the LTN only** — the LTN is the scada's single upstream; one
  more thing it relays.
- **Through a broadcast service only** — every house subscribes to the
  same fleet-wide weather broadcast; no per-house relay dependence.
- **Through the LTN unless it has been offline** — LTN as primary, with a
  fallback to the broadcast (or a direct API fetch) so a house whose LTN
  link is down still has weather for local control.

The scada-side removal touches gridworks-scada and is coordinated with
the scada world when it executes; what the fallback choice implies for
local-control autonomy is the heart of the grill.

## Already in place

- gwwf consumes canonical `weather_tx` (retarget commit `bae188f`, on
  origin/main); the generated prod topology provides the exchange.
- The dev-broker validation (2026-05-26, gwwf→gjk, 22 messages) covered
  the publish path on the current fabric.
- The broker side is clean: the legacy actor's runtime-declared `ws_tx` +
  `hw1.isone.ws-F258` were removed when the legacy service stopped; the
  prod topology is exactly the generated file. gwwf needs no broker-side
  preparation.
