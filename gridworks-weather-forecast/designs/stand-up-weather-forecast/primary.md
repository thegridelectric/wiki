# stand-up-weather-forecast

Status: Accepted · Pass 1 · Updated 2026-08-11 · Linear: OPS-436

**EDD: yes** the bar is real-broker delivery in the new vocabulary
consumed in production — JournalKeeper journaling the observed series
and an LTN consuming a designated forecast stream; claims reach
Verified only through experiments against a real broker.

> What this is: stand up gwwf (gridworks-weather-forecast) as the
> fleet's production weather source, providing CURRENT weather and
> forecast weather through a fresh `gw.weather.*` vocabulary (designed
> 2026-08-10; the legacy `weather` and `weather.forecast` words retire,
> never bump — they carry floats on the wire, spaceheat jargon, and
> per-message metadata). The legacy observation service was stopped by
> hand 2026-07-18; the fleet has had no weather source since, an
> accepted gap. gwwf is a gwbase-native cloud GNode (parallel to the
> LTN, FIS, MarketMaker, TimeCoordinator). Early intent:
> [`../../research/design-intent.md`](../../research/design-intent.md)
> — partially superseded here (notably its `gw.weather` namespace
> trajectory and channel-name-encodes-method idea).

**▶ Active spoke: [`build.md`](build.md)**

## System shape

- **gwwf** publishes observation and forecast broadcasts over the
  gwbase RabbitJsonBroadcast mechanism with the channel slug in the
  routing key, so consumers bind per channel. How the LRD channel name
  renders into the slug is pinned against the gwbase spec at the
  round-trip witness ([`build.md`](build.md) step 1).
- It serves a public read-only HTTP API — the single pull path (drop
  recovery, scada fallback, post-hoc reads, record listing), never the
  primary delivery (see [`delivery.md`](delivery.md)).
- It owns the **gridworks-weather DB**: canonical seed for the `.gt`
  channel words, and the forecast revision store.
- **JournalKeeper** journals the messages and projects the observed
  series into its readings tables. Readings hold CURRENT weather only;
  forecasts live in the message payloads and the service DB.

## Source posture

NWS is the v0 access path, not a commitment. The vocabulary holds no
source at the observation layer (acquisition is per-reading
provenance) and holds it as a competing Forecaster at the forecast
layer. Observations: KMLT is the physical instrument near the fleet;
NWS is merely today's free access path to it (alternatives to the same
instrument: Synoptic/MADIS, NCEI). Forecasts: NWS gridpoint is the
free, public-domain baseline forecaster; challengers slot in as
forecast channels and are skill-scored against the observed series
before any consumer switches — model-blend sources (e.g. Open-Meteo's
HRRR/ECMWF blends) typically beat NDFD short-horizon temperature, and
Weather Underground (= The Weather Company; skill historically at or
near the top of accuracy rankings) is a serious candidate whose free
API access is gated on contributing a personal weather station — a
route that may suit us (fleet houses have outdoor sensors; the PWS
network is itself a hyperlocal-observation source, quality varying by
siting). Rural-Maine PWS coverage and current API terms: verify at
evaluation time (background knowledge, 2026-01 cutoff). Choosing wrong
is cheap by construction.

## Deployment dimensions

- **Identity.** Decide gwwf's g-node identity record (sema `g.node.gt`
  naming conventions) — alias, role, where the file lives. Trap from
  the legacy wire: the old messages carried `FromGNodeAlias`
  `hw1.isone.ws`; whether any consumer keys on the alias rather than
  the channel name must be established before the identity decision.
- **gwbase update.** gwwf was ported against gwbase 0.4.0; bring it to
  latest before deploying.
- **Home.** NOT legacy journalmaker (slated for retirement); pick the
  durable home.

## Rough execution allotment

Point-estimate hours for the implementation bits (full scope + 90%
interval in the 2026-08-10 estimate comment on OPS-436; design time
excluded):

- sema authoring — gate, word set, regen, snapshot vendoring: ~3.5 h ✅
- gwwf implementation — gwbase update, NWS adapters, emission
  scheduler, the API, gridworks-weather DB: ~6 h
- JK projection + legacy import (our share; with Joe): ~4 h
- EDD experiments + deploy — round-trip witness, updateTime probe,
  identity, home, bring-up: ~3.5 h

## Already in place

- gwwf consumes canonical `weather_tx` (retarget commit `bae188f`, on
  origin/main); the generated prod topology provides the exchange.
- The dev-broker validation (2026-05-26, gwwf→gjk, 22 messages)
  covered the publish path on the current fabric.
- The broker side is clean: the legacy actor's runtime-declared
  `ws_tx` + `hw1.isone.ws-F258` were removed when the legacy service
  stopped; the prod topology is exactly the generated file. gwwf needs
  no broker-side preparation.

## Spokes

- ✅ DONE [`vocabulary.md`](vocabulary.md) — the `gw.weather.*` words:
  semantics, naming, units, time formats; authored staging in sema.
- ✅ DONE [`delivery.md`](delivery.md) — cadence, the hour phase
  structure, the pull-path API, fleet delivery shape, blessed
  forecast stream.
- **[`build.md`](build.md)** — the gwwf implementation plan and the
  "do this now".
- [`journalkeeper-and-history.md`](journalkeeper-and-history.md) —
  projection into JK pseudo-channels, the legacy S3 import, the Joe
  conversation; the persistence grill. Gates gridworks-journalkeeper
  work only; gwwf implementation proceeds on the Accepted spokes.
- [`evidence.md`](evidence.md) — 2026-08-10 findings from the prod
  journal DB, the JK tree, and the live NWS API; the legacy wire
  contract and fixture.
