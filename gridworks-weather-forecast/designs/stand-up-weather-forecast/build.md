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

**Step 7 — record creation rides the bus (the gnr write pattern,
2026-08-12).** EVERY record is created by a human act whose request
itself crosses the wire as a sema word — mirroring
`g.node.create.cmd` / `g.node.cmd.ack` / `g.node.cmd.nack`: a create
command carrying the full record + a `Proof` placeholder (authority =
the authenticated connection until the authority substrate lands),
ack/nack as direct replies discriminated by TypeName and correlated
by the command's content hash. `gwwf create <record.json>` is the
SENDER; the actor consumes the command, validates through the
snapshot, inserts (insert-only — records are durable identities,
never upserted), broadcasts the record (radio tail = its own name,
bundle tail-less), and replies. The ear witnesses command, verdict,
and record broadcast into the store — full provenance. `gwwf seed` +
`records.py` retire (no in-code record source); tests carry their own
instances. Word-gate applies (new `gw.weather` cmd/ack/nack words;
open: one command word with a one-of-four record slot vs four
kind-specific commands). ✅ The broadcast mechanics are built +
witnessed (`experiments/2026-08-12-gwwf-record-broadcast/`: bundle
tail-less, location on its alias, byte-equal through the snapshot).
Sequencing: word-gate + implementation next; then the JK MVP; the
prod record tables are wiped and re-created through `gwwf create`
ONLY AFTER the JK MVP journals the new vocabulary.

Slice arithmetic is natively list-driven: every computation walks
`SliceDurationSList` element by element (per-slice lengths may all
differ; the word holds each as a positive multiple of 300 s by
format + axiom). Message values are built ON the channel's slice
grid from the source product — the product's uniformity is declared
at the adapter boundary (`HourlyForecastProduct.period_s`), never
assumed in the scheduler, the message construction, or the recovery
interpolation grid. A uniform-hour shortcut anywhere downstream of
the adapter is the defect this note exists to block.

## Ordered steps

0. ✅ DONE **Snapshot + gwbase update** (branch `jm/gwwf-standup`):
   gwbase 0.5.8, snapshot with the `gw.weather.*` words vendored,
   suite + ruff green, both message words round-trip through the
   vendored codec in tests.
1. ✅ DONE **EDD witness: dev-broker observation round trip**
   (`experiments/2026-08-11-gwwf-obs-roundtrip/` — PASS): slug-bound
   tap decoded the broadcast byte-equal through the snapshot; radio
   channel = location alias, dots preserved in the tail.
2. ✅ DONE **NWS adapters** (`src/gwwf/nws.py`): snapshot-native
   observation fetch (newest-first) + gridpoint hourly product +
   per-forecast-channel message construction; live-API tests
   (`GWWF_LIVE_NWS=1`) green. `updateTime` probe RUNNING
   (`experiments/2026-08-11-nws-updatetime-probe/`) — first poll
   showed updateTime ~7 h behind generatedAt.
3. ✅ DONE **Emission scheduler** — framework-free `scheduler.py` +
   list-driven `grid.py` + `records.py` seed + `weather_actor.py`
   rewired (legacy poller gone; glitch word vendored); EDD witness
   PASS (`experiments/2026-08-11-gwwf-scheduler-witness/`): full
   scenario at second-scale record schedules on the dev broker.
4. ✅ DONE **gridworks-weather DB + actor wiring** — alembic +
   SQLAlchemy on the gnr pattern (own database, gwwf sole accessor):
   record tables mirroring the `.gt` words + revision store +
   source-product cache + last-observation state; actor boots from
   the DB (explicit seed step), persists as it emits, restores on
   boot; `ci.sh` added. Verified by the layer-2 harness
   (`tests/test_layer2_weather.py`): the real actor as `d1.weather`
   on testcontainers rabbit (provisioned gwbase fabric) + migrated
   testcontainers postgres, fast records, RESTART witnessed with
   interpolated replay bridging the outage.
5. ✅ DONE **The API** — the read façade on the house pattern
   (`api-pattern.md`): GNode-alias party segment, sema response
   models byte-identical to broadcasts (DB-free wire pin), OpenAPI
   sema links, `WeatherReads` seam.
5b. ✅ DONE **r2 vocabulary cutover** — per-bundle emission on the
   bundle slug (sema `f9c32d3`): bundle in the seed (decomposed
   tables, axioms fire on load), `ForecastSql` sent-forecast store
   (uuid key, unique on bundle+SourceUpdatedTime+FirstSliceStart),
   API `/bundles` + latest-forecast per bundle, one fresh initial
   migration (pre-launch collapse). Both experiment reproducers
   re-witnessed PASS on the new shapes; ci.sh + layer-2 green.
6. ✅ DONE **Home + bring-up** (2026-08-12): `gw.weather.*` closure
   promoted (sema `c7be5ab`), snapshot re-vendored published-only;
   box `forecast` (Hetzner cpx11, ash, Ubuntu 24.04) at
   178.156.156.57 on a persistent primary IP (`auto-delete=false` —
   survives a rebuild; the cheap alternative to gnr's floating IP),
   `forecast.electricity.works` in Route 53, shared with the future
   price forecaster; service live as `hw1.weather` on the hw1
   broker — first prod broadcasts witnessed at 16:00:01Z
   (observation) and 16:01:00Z (forecast) with byte-identical API
   pulls. Box facts: gridworks-infra `platform-inventory.md` +
   `forecast/instance-README.md`. Phase :01 per the updatetime-probe
   verdict.
7. **Record broadcasts** (above).

Consumer-side work (LTN relay + FLO consumption, scada fallback +
fetcher removal) rides its own repos and deploy trains per
[`delivery.md`](delivery.md) "Legacy retirement sequencing".
