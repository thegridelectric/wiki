# build — the gwwf implementation plan

Status: Draft · Pass 0 · Updated 2026-08-11

What this is: the ordered build for
[stand-up-weather-forecast](primary.md)'s gwwf service, each step with
a witnessable done-when. Semantics live in the Accepted spokes
([`vocabulary.md`](vocabulary.md), [`delivery.md`](delivery.md)) — this
spoke is sequencing only. gridworks-journalkeeper work is NOT here; it
gates on
[`journalkeeper-and-history.md`](journalkeeper-and-history.md).

## ▶ DO THIS NOW

**Step 0 — snapshot + gwbase update.** On a `jm/` branch in
`gridworks-weather-forecast`: bring the repo from gwbase 0.4.0 to
latest (0.5.8), and vendor the sema snapshot carrying the
`gw.weather.*` words (staging ⇒ `--allow-staged`) — the snapshot lands
BEFORE the first consumer line, per the sema-boundary maxim.
Done-when: the gwwf suite is green importing the vendored words, and a
`gw.weather.observation` instance round-trips through the vendored
codec in a test.

## Ordered steps

0. **Snapshot + gwbase update** (above).
1. **EDD witness: dev-broker observation round trip.** gwwf publishes
   one `gw.weather.observation` over RabbitJsonBroadcast on
   `gw-dev-rabbit` (channel slug in the routing key); a harness
   consumer binds the slug and decodes through the snapshot.
   Done-when: witnessed decode, harness kept as reproducer.
2. **NWS adapters.** Observation fetch (KMLT, newest-first — the
   legacy oldest-in-window defect is the anti-pattern) and gridpoint
   hourly forecast fetch. Start the `updateTime` logging probe (a day
   or two) that verifies the ForecastCreated binding and the :30
   freshness assumption.
3. **Emission scheduler.** Record-driven schedule (`EmitPeriodS` /
   `EmitOffsetS` — nothing hardcodes 3600): :00 observations
   (latest-only, silence when stale, ≤3 h interpolated replay on
   recovery), :30 forecasts (always emit; Fidelity ladder
   live → stored (+24 h horizon) → seasonal template). Glitches:
   observation >1 h stale at publish; each fidelity downgrade.
4. **gridworks-weather DB.** Locations + channel-record seed tables
   (the canonical `.gt` seed) and the forecast revision store keyed
   `(channel, forecast_created)`.
5. **The API.** Public read-only HTTP: latest observation / latest
   forecast per channel (sema-typed message words), and the record
   listing (channels, forecast channels, locations).
6. **Identity, home, bring-up.** Decide the g-node identity (first:
   establish whether any consumer keys on the legacy `FromGNodeAlias`
   `hw1.isone.ws`), pick the durable deploy home (NOT legacy
   journalmaker), deploy, and witness the prod broadcast.

Consumer-side work (LTN relay + FLO consumption, scada fallback +
fetcher removal) rides its own repos and deploy trains per
[`delivery.md`](delivery.md) "Legacy retirement sequencing".
