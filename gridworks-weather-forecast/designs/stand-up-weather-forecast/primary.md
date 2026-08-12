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
  gwbase RabbitJsonBroadcast mechanism with the stream name as the
  routing key's radio-channel tail (dots preserved — the gwbase
  transport spec pins the tail as extra dotted segments):
  observations ride the location alias, forecasts the bundle Name —
  one message per bundle per slot, the bundle being the sign-up
  object (see [`delivery.md`](delivery.md) "Broadcast binding
  shape").
- It serves a public read-only HTTP API — the single pull path (drop
  recovery, scada fallback, post-hoc reads, record listing), never the
  primary delivery (see [`delivery.md`](delivery.md)).
- It owns the **gridworks-weather DB** — its own database, gwwf the
  sole accessor (every other consumer goes through the broadcasts or
  the API): canonical seed for the `.gt` channel words, and the
  forecast revision store.
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

- **Identity (posture settled 2026-08-11).** The alias hangs directly
  under the universe root, topology-neutral: `d1.weather` dev,
  `hw1.weather` on the fleet universe — segment 0 is the universe and
  must match the broker vhost (authority: gnr executor "Universes").
  The legacy trap is cleared: nothing consumes the old `weather`
  stream, so no consumer keys on `hw1.isone.ws`. ✅ Prod `g.node.gt`
  record minted (GNodeClass `weather`, Logical, GNodeId
  `81de47d9-4ef9-4e99-aab0-8e47a1ffadb1`) and placed per the gwbase
  XDG convention.
- ✅ **gwbase update.** gwwf builds on gwbase 0.5.8.
- **Home (decided 2026-08-12): a fresh Hetzner cpx11** (Ashburn)
  shared by the forecasting services — gwwf now, the price forecaster
  when it stands up. Login `weather` (per-service logins as services
  join), per-person keys, on-box Postgres container. NOT legacy
  journalmaker (slated for retirement); not the gnr box (keeps the
  forecast services' availability and public HTTP surfaces uncoupled
  from the registry). Hostname `forecast.electricity.works` (settled
  2026-08-12; DNS A record in Route 53 once the IP exists).
  Provisioning lands at bring-up; box state per the instance-README
  convention. ✅ `sema promote` of the `gw.weather.*` words landed
  (sema `c7be5ab`), clearing the prod deploy.

## Rough execution allotment

Point-estimate hours for the implementation bits (full scope + 90%
interval in the 2026-08-10 estimate comment on OPS-436; design time
excluded):

- sema authoring — gate, word set, regen, snapshot vendoring: ~3.5 h ✅
- gwwf implementation — gwbase update, NWS adapters, emission
  scheduler, the API, gridworks-weather DB: ~6 h ✅ (committed
  `0b928b4`, 2026-08-12)
- JK projection + legacy import (our share; with Joe): ~4 h
- EDD experiments + deploy — round-trip witness ✅, updateTime probe
  ✅ (closed 2026-08-12), scheduler witness ✅, identity + home +
  bring-up ✅ (2026-08-12, service live on the hw1 broker): ~3.5 h

Actuals (2026-08-12, from the day-level scratch rows; design time
4.5 h on 08-10 sits outside the allotment): sema authoring + gwwf
implementation + the three witness experiments ran interleaved
through build steps 0–5 and the r2 cutover — **9.15 h** (7.05 h on
08-11, 2.1 h on 08-12) against their ~9.5 h combined estimate, plus
in-estimate ✅ for the probe. Deploy/bring-up (promote → box → live
witness): **~1.2 h** and closing. JK share: not started. The day
rows never followed bucket lines, so finer sema-vs-implementation
splits are approximate by construction.

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
- [`populate.md`](populate.md) — growing the production record set:
  minting as a human act, mint order, the JK-MVP gate. Runs after
  build and the JK MVP.
- [`journalkeeper-and-history.md`](journalkeeper-and-history.md) —
  the JK MVP (journal ALL the new vocabulary, before populate), then
  projection into JK pseudo-channels, the legacy S3 import, the Joe
  conversation; the persistence grill. Gates gridworks-journalkeeper
  work only; gwwf implementation proceeds on the Accepted spokes.
- [`evidence.md`](evidence.md) — 2026-08-10 findings from the prod
  journal DB, the JK tree, and the live NWS API; the legacy wire
  contract and fixture.
