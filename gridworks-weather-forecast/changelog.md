# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-weather-forecast` code repo**. The matching git commit
(in `gridworks-weather-forecast`) holds the WHAT (the diff). Each
entry's date and one-line title mirror the corresponding code-repo
commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-10-18 — README to the pattern; legacy weather word out of the seed (`cd36dfd`, `jm/readme`)

**What:** the README rewritten in the README pattern's order: a summary
for a person, what the service speaks, its three processes, the records,
one pointer to gridworks-infra for operation, and one Development
section with install, environment, tests and the CI entrypoint. The
record broadcasts and the glitch word are named for the first time; the
box facts and the schema-drop note leave for gridworks-infra and this
changelog. The seed drops the legacy `weather` word and the snapshot is
regenerated from sema `05a6f1c`; the three tests of that word's
serialization go with it.

**Why:** the executor's Domain Summary is copied from the README, so the
README is finalized before the executor is built (OPS-607). The seed
named a word the actor no longer publishes, which the executor's
seed-versus-Words check would flag on day one.

## 2026-10-18 — The moose bundle: 96-hour NWS temperature and wind for the scada (`21984ae`, PR #11, OPS-597)

**Why.** The scada reads the 48 hours after the current one and the
bobcat and raccoon bundles hold 48 slices from the current hour, one
short, so a scada on either fell to its seasonal template at every
pull. A forecast channel's grid is its identity, so the longer horizon
is three new records in `dev-records/`: `kmlt.temperature` and
`kmlt.windspeed` forecast channels at 96 hourly slices
(`...forecast.nws.hourly96`) and `us.me.millinocket.moose` binding
them, hourly at :01. Moose has no irradiance: the scada's load model
reads temperature and wind, and raccoon stays the LTN's bundle. No
service code changes; the fetchers take the slice count from the
record.

## 2026-10-18 — weather service provides irradiance; major refactor (`47d7adf`, PR #10, OPS-597)

One squashed commit over four steps, newest first.

**Snapshot on the published weather words.**

**What:** the vendored snapshot regenerates from the published registry
and the regen script drops its staging allowance, so the CLI's default
guard refuses any seed whose closure reaches an unpublished word.

**Why:** the ten station words promoted on 2026-10-18; a production
service ships a publication-grade snapshot.

**dev-records and dev-up/dev-down; a station without an ICAO id is forecast only.**

**What:** `dev-records/` holds the dev record set with fixed Ids
(Millinocket, stations `kmlt` and `kmemilli18`, the three observed
channels, three forecast channels, the bobcat and raccoon bundles, the
seasonal template) in referential order; `scripts/dev-up.sh` tears
down any previous dev run, brings the compose Postgres up empty,
migrates it, starts the actor and API as `d1.weather` under
`scripts/dev.env` and `scripts/dev-g.node.gt.json`, and mints the set
over the local broker, retrying the first create until the actor
answers; `scripts/dev-down.sh` stops both and drops the volume. The
actor builds no observation stream for a station with no IcaoId and
logs a warning naming it; a layer-2 test boots the actor with the
default NWS wiring on such a station and sees forecasts with no
observations.

**Why:** the dev loop starts from an empty database every time so the
dev DB can never drift from the migration, and the records still enter
over the bus so the dev run exercises the same path as production. The
same files mint production by hand, so dev and prod share identities.
The first dev mint of raccoon found the scheduler rebuild failing on
`kmemilli18`: every station in a bundle was wired to the NWS feed, and
the personal irradiance station has no ICAO id. Observed irradiance is
an open item in the design, so the station's channels are forecast
only until an observation path exists.

**Service rebuilt on the station words from a fresh db schema.**

**What:** the vendored snapshot regenerates onto sema `96c6a2b` with
staging words allowed (`regen_sema_snapshot.sh` passes
`--allow-staged` until the weather words publish), latest versions
only: `gw.weather.station.gt` 000, `gw.weather.channel.gt` 002
(StationAlias), `gw.weather.location.gt` 001, `gw.weather.observation`
001 (ReadingList), `gw.weather.forecast` 001 (SeriesList),
`gw.weather.forecast.bundle.gt` 002 (BindingList) and
`gw.weather.create.cmd` 002; no old version is in the seed. The
migration chain is replaced by one initial migration matching the
models: a `stations` table, a `bundle_bindings` table in place of the
bundle's fixed channel columns, channels and last observations keyed
by station, the forecast archive keyed by bundle name and the joined
per-series source revisions. The scheduler runs one observation
stream per station with a reading list, interpolating every channel
both brackets report, and one forecast stream per bundle whose series
each come off a product source chosen by the forecast channel's
Method (the `ADAPTERS` table in the actor: NWS gridpoint hourly for
temperature and wind, Open-Meteo for irradiance), bindings on one
acquisition sharing one fetch; every series walks its own ladder and
the template rung is the seasonal template for a temperature series
and zeros for any other quantity. The NWS observation adapter scales
each reading by its channel's Unit (`units.py`), so the X10 channels
need no code. The API lists stations and serves the latest
observation per station. Fixtures move to the `kmlt` and `kmemilli18`
stations and the bobcat and raccoon bundles.

**Why:** the instrument is the identity behind an observed series,
and which series a forecast holds is a fact of the bundle a
subscriber designates, not of the schema; a bundle may draw on
stations away from its place, which the irradiance series needs.
Nothing consumed the first words' observations and forecasts, so the
service abandons them instead of converting: an old channel row does
not say which station its readings were, and the record set is
re-minted on a fresh schema. The published first words stay in the
sema registry; a deploy drops and recreates the service DB.

**Weather service provides irradiance** (2026-10-17): Open-Meteo fetcher, per-series fidelity, snapshot on forecast 001 and bundle 002.

**What:** the vendored snapshot regenerates onto sema `48eda7e`, published-only (the three solar words promoted there; `regen_sema_snapshot.sh` drops `--allow-staged`), with
the seed pinning `gw.weather.forecast` at 000 and 001 and
`gw.weather.forecast.bundle.gt` at 001 and 002, so a bundle without
the irradiance pair keeps emitting the 000 message beside the new
one; `gw.weather.create.cmd` 002 and the 003 unit and quantity enums
come with the closure. `open_meteo.py` pulls `shortwave_radiation`
from the pinned `gfs_seamless` model, shifts the hour-end labels to
slice starts, checks coverage against the next hour boundary, and
stamps the series with the GFS 0.13° run from the model metadata
endpoint. The scheduler walks a fidelity ladder per series:
temperature and wind from the NWS product, irradiance from the
Open-Meteo product, each with its own stored product and downgrade
glitch; at the template rung irradiance is zeros stamped with the
bundle's Start. The actor schedules every bundle in the DB (one
forecast stream per bundle, one observation stream per location) and
wires each forecast channel's adapter from its Method and
SourceLocator. A migration adds the bundle's nullable irradiance
columns and the enum values of gw1.quantity and gw1.unit 003; a
bundle row loads at the version its columns fill, a sent forecast
decodes at the version it was sent at, the product cache is generic
over the two product kinds, and the forecasts table's `fidelity` is
the lowest rung among a message's series. The API returns both bundle
and forecast versions. Fixtures gain the irradiance pair and the
`us.me.millinocket.forecast.hourly` bundle beside the NWS one; tests
cover the fetcher against a captured response, the independent
ladders, the 000 path, and the store at both versions.
`tests/test_sema_snapshot_published.py` (gwbase's test, one path changed) fails on `main` if any seed word is not published in the sema registry and only reports elsewhere. A `fidelity.py` module is the one home for the ladder rank and the DB column's rung; `IrradianceSource` groups a stream's irradiance fetch, scale and stored product into one optional field.

**Why:** the LTN's house load model has a solar term with no fleet
source. The series joins the one Millinocket bundle rather than a
second stream, so a consumer decodes one message per slot; the two
upstreams fail independently, so fidelity is declared per series. The
old bundle keeps its 000 message until the scada and LTN move.

## 2026-10-09 — Track gwbase 0.5.15: user_id on every publish, alias self-heal (OPS-579, `cfefc8f`)

gwbase 0.5.15 stamps `user_id` on every publish with the connection
identity, so the broker's validated-user-id check verifies this
service's publishes instead of skipping them; the floor and the lock
move together so the deployed box installs it. gwwf is a GNode, so it
also gains the alias self-heal: with `GWWF_GNR_URL` set the actor
re-reads its alias by GNodeId before each reconnect and adopts a
registry rename; `template.env` carries the line, and the forecast box
`.env` gets it at the deploy. One layer-2 test timed out once under the
full gate on the first run and passed on every rerun; a timing flake,
not the bump.

## 2026-10-09 — The minter connects as its own principal (OPS-392, `0066e01`)

**What:** `GwwfSettings.minter_rabbit`, an optional `RabbitBrokerClient`
the create command connects with; `minter_settings` builds the minter's
service settings from it, falling back to the actor's client when unset.
Two tests pin the choice. The README's record section replaces the
retired `gwwf seed` line: the five record kinds in referential order,
`gwwf create` as the one way in, and the minter identity; `template.env`
carries the commented minter lines. **Why:** under the gated broker the create
command was refused: it reused the actor's cert while claiming the
`weatherminter` alias, which FIS denies as an alias mismatch, and a
matching alias would have been worse, two instances on one principal
superseding each other at every mint. The minter is its own Service
principal with its own cert on the forecast box, and each `gwwf create`
a fresh GNodeInstance on it.

---

## 2026-10-07 — The seasonal template rung (OPS-392, `f4484ed`)

The forecast ladder's third rung is built: when the live product fails
and the stored horizon is absent or exhausted, the scheduler lays the
location's `gw.weather.seasonal.template.gt` on the bundle grid (each
slice at its UTC month's value, scaled to the channel's unit, no wind)
and emits with Fidelity SeasonalTemplate, with the usual downgrade
glitch; a location with no template still glitches and skips. The
template is the fifth record kind: `seasonal_templates` table (alembic
`7d2e9a41c6b3`), insert-only through `create` on `gw.weather.create.cmd`
001, broadcast once on its location alias, listed by the facade at
`/seasonal-templates` (every Start; a consumer takes the latest for its
location, as the actor does at boot). Snapshot regenerated with
`--allow-staged` since the word is staging; the seed is latest-only, so
the vendored create command is 001 and 000 leaves the snapshot. Tests: DB
round trip and
referential order, facade listing, broadcast tail, and three scheduler
cases (no product, stored exhausted, no template).


## 2026-09-30 — Move to gwbase 0.5.14 (`ca039fd`, merged `a4913e2`)

Picks up the gwbase release that stops logging the broker password:
`ActorBase.connect_consumer` logged the full AMQP URL at every connect,
so the weather emission actor wrote its broker credential into its file
log and journald. Floor raised and lock refreshed. The layer-2 test
moves its testcontainers broker to vhost `d1__1`: gwbase validates the
URL vhost as `universe.run` since 0.5.12, and the container's default
`/` vhost no longer passes.

## 2026-08-27 — tweak log alias (`03f6be0`, merged to main via PR)

The operator log alias was named for the unit role (`rabbitlog`, after the
`weather-rabbit` actor) rather than the service, which read as a second,
distinct log next to a nonexistent "weather log" — there's only the one
actor file log (`hw1…weather.log`) plus the API's journald stream
(`apilog`). Renamed to `weatherlog` so the alias family is uniform
`<svc>start/stop/restart/status/log`, matching ear (`earlog`) and gnr
(`gnrlog`). Behavior unchanged: `cd` into the log dir, `tail -F *.log`.

## 2026-08-22 — cleaning up sema snapshot info (`4c71c20`)

(Squashed in: the README's Sema note rewritten in the sema README's own
canonical words — vocabulary registry, boundary contracts, mechanically
verifiable, plus the boundary-scoping sentence — and the snapshot refresh
that puts the same language in the generated snapshot README.)

gwwf vendored its Sema snapshot with the seed checked in
(`src/gwwf/sema_seed_request.yaml`) but no regen script — refreshing meant
hand-running the sema CLI from the seed's comment. Adds the standard
`scripts/regen_sema_snapshot.sh` (instance of sema's
`template_regen_snapshot.sh`) so the snapshot regens the same way as in the
other consumer repos. Verified live against sema dev: the run's only
snapshot churn was registry `last_updated` catch-up plus the (new)
generated snapshot README; suite green after. The top-level README gains
the standard Sema pointer (canonical repo, schema-id namespace, vendored
snapshot location + regen path).

## 2026-08-13 — gwbase 0.5.10 pin; g.node.gt fixtures to v006 (`3c00e0b`)

gwbase 0.5.10 rejects `g.node.gt/004` (the same staleness fix
applied there — see its changelog); `test_layer2_weather.py`'s
`g_node_file` fixture still hardcoded `"Version": "004"`, so bumping
the pin alone would have broken the layer-2 suite. Bumped the
fixture to 006 alongside the pin. No functional gwwf change — the
prod identity swap (new alias, registry-sourced `g.node.gt.json`)
is box-side config, not code.

## 2026-08-13 — service/bash_aliases (`933fdda`)

gwwf never got the ear/gnr/gjk service-template's convenience
aliases (`service/bash_aliases`, sourced from the box login's
`~/.bashrc`) — every start/stop/status/log during the step-7 deploy
was hand-typed `systemctl`, and the gaps showed: a bare (non-sudo)
`systemctl enable --now` triggered an interactive polkit password
prompt, and `enable --now` doesn't match the sudoers drop-in's
per-verb exact-argv grants anyway. Adds `weatherstart` / `weatherstop`
/ `weatherrestart` / `weatherstatus` (one unit's worth of sudo calls
each, chained — sudoers matches exact argv, so a single call naming
both units would silently fall through to a password prompt) plus
`rabbitlog` / `apilog`, split because the two units log differently:
`weather-rabbit` is a gwbase actor with the bijective file logger,
`weather-api` is a plain FastAPI process with journald-only output.

## 2026-08-12 — words published (`1dc08ba`)

The three command-round words are published (sema promote), so the
dev-only staging snapshot (`--allow-staged`, staging banner +
`indexes/staging.yaml`) retires: the vendored snapshot regenerates
published-only from the promote commit, clearing the prod deploy.
No runtime behavior changes — the wire bytes were already final.

## 2026-08-12 — records enter by create command over the bus (`4cb9add`)

Record creation becomes a human act whose request crosses the wire
as a sema word, on the gnr write pattern (`g.node.create.cmd` +
ack/nack twins): `gwwf create <record.json>` sends
`gw.weather.create.cmd/000` (ONE command word — the Record slot is a
closed oneOf over the four record words; a fifth kind is a version
bump, not a fifth word); the actor validates through the snapshot,
inserts (insert-only — records are durable identities, never
upserted; a bundle's embedded channel copies must equal the
canonical rows), broadcasts the record once (radio tail = its own
name; the bundle tail-less — the TypeName segment discriminates),
replies ack/nack correlated by the command's content hash, and
rebuilds the scheduler from the DB so minted records start emitting
without a restart. The sender is a weather-class operator identity
(`<universe>.weatherminter`), never the service alias — the verdict
is addressed to the command envelope's from_alias; command and
verdict ride the fabric's new (weather, weather) self-edge (gwbase
0.5.9; pin bump + lock follow its release). The ear witnesses
command, verdict, and record into the immutable store — full
provenance, and archived forecast messages can resolve the bundle
active at their time (the forecast message carries no slice grid by
design). `gwwf seed` + `records.py` + `names.py` are removed: no
in-code record source; tests carry their own instances
(`tests/records.py`). An EMPTY record set is a legal boot state —
the actor is the create command's consumer, so it runs before any
records exist; no records means an idle scheduler, never a boot
failure. Authority = the authenticated connection, with a `Proof`
placeholder field reserved (gnr's posture). A broadcast-stamp column
was considered and rejected: the DB rebuilds from code and the
store, and a stamp is state rebuildable from nowhere.

Snapshot local names drop the gw ceremony (`local_names:
strip_prefixes: [gw1, gw]` in the seed request — WeatherObservation,
Unit, Quantity; wire TypeNames untouched), and the SQL enum types
renamed to match (quantity, unit, weather_forecast_fidelity) in the
collapsed initial migration — deploy drops + re-migrates the box DB.

Witnessed: broadcast mechanics on the dev broker
(`experiments/2026-08-12-gwwf-record-broadcast/`), and the full
round in the layer-2 suite (empty boot → out-of-order nack → six
acks → duplicate nack → record broadcasts on the wire → emissions
begin, no restart).

## 2026-08-12 — stand up the weather service (`0b928b4`, merged to main via `4bdca5e`)

The whole OPS-436 standup, squashed to one commit before first push
(2026-08-12) — the granular build history never ran anywhere, so the
service arrives as a single unit on top of the pre-standup scaffold.
The build's why, in build order:

**Foundation.** The sema snapshot carrying the staged `gw.weather.*`
words landed BEFORE the first consumer line (sema-boundary maxim);
gwbase moved 0.4.0 → 0.5.8 so the service is built once against the
current framework (`transport_class` to the actor constructor,
`service_alias` env-declared and boot-bound to the gitignored
`g.node.gt` identity file). Settings/logging conform to the pattern
journalkeeper landed on gwbase 0.5.x: `service_name`
`weather-forecast` (own XDG segment), per-actor rotating logger. Dev
alias is `d1.weather` — the universe prefix already declares dev.
Staging words mean an `--allow-staged` dev-only snapshot; `sema
promote` gates the prod deploy, not the build.

**NWS adapters.** The two pulls (KMLT observations, CAR/60,114
gridpoint hourly) return validated snapshot instances — no dicts
escape the fetch layer. Observation fetch walks newest-first: the
legacy service took `features[-1]`, the OLDEST in its 2-hour window,
and published ~2-hour-stale observations for its whole life (pinned
by the archived fixture). `SourceUpdatedTime` binds the product's
`updateTime` (the underlying-data stamp) — never `generatedAt`,
which refreshes per render. Live-API tests are env-gated
(`GWWF_LIVE_NWS=1`).

**Emission scheduler.** Framework-free (`scheduler.py` + pure slice
arithmetic in `grid.py`) with injected clock, fetchers, and publish
hook; cadence comes entirely from the seed records, so a fast-record
witness runs the same code at second-scale periods — nothing
hardcodes an hour. Slice arithmetic walks `SliceDurationSList`
natively (per-slice lengths may differ; NWS hourly uniformity stops
at the adapter boundary). Observations: latest-only, silence when
stale, ≤3 h linear interpolated replay on recovery
(`Interpolated: true`). Forecasts: fidelity ladder live → stored;
the seasonal-template rung is declared but unbuilt — reaching it
glitches and skips (Open deviation from always-emit until a template
source is chosen). Glitches broadcast the published `glitch` word:
stale observation at publish, each fidelity downgrade. The legacy
NWS poller and `weather` v000 publish are gone; the `weather` word
stays vendored solely as the JK import's reference contract.

**Vocabulary r2** (sema `f9c32d3`, `91b43f6` — see
wiki/sema/changelog.md). Both message words hard-code temperature +
wind speed; one observation message per location per slot
(LocationAlias the radio channel, wind optional when the station
reports none); one forecast message per BUNDLE per slot (BundleName
the radio channel and the sign-up object; SourceUpdatedTime /
MessageCreatedMs two-clock split). The bundle is the emission unit,
so EmitPeriodS/EmitOffsetS live on it — forecast channels slim to
series identity + slice structure. Forecast-channel slugs carry a
shape tail (`…temperature.forecast.nws.hourly`): concurrent
time-slice shapes are distinct channels; a future 5-minute product
coexists rather than succeeds. Emission phase settled at :01 from
the updatetime-probe verdict
(`experiments/2026-08-11-nws-updatetime-probe/`): NWS freshness is
issuance-driven (2–4 revisions/day) and phase-independent, so :30
bought nothing and cost half the FLO randomness window; the hour is
:00 observation → :01 forecast → FLO window.

**Own database** (gnr pattern). SQLAlchemy 2.x rows mirror the sema
GT records and load back AS validated records (bundle axioms fire on
load — the service-side half of the bundle's consistency); alembic
with a single collapsed pre-launch initial migration; compose dev
postgres (gwwf-postgres, host 5436); testcontainers tests. gwwf is
the DB's sole accessor — every other consumer goes through
broadcasts or the API. Seeding is an explicit operator step; an
unseeded DB refuses to boot; `records.py` is seed-source only.
`ForecastSql` keeps every send-distinct message (uuid surrogate key,
natural uniqueness on bundle + SourceUpdatedTime + FirstSliceStart);
last-observation state survives a restart, so latest-only and
recovery interpolation resume across deploys — witnessed by the
layer-2 test that boots the real actor as `d1.weather` on a vanilla
testcontainers rabbit + migrated postgres, then restarts it and
watches interpolated replay bridge the outage.

**Read API** (house pattern, canon [`api-pattern.md`](../conventions/api-pattern.md)).
Public, read-only, thin over a `WeatherReads` seam: record listings
+ latest observation per location + latest forecast per bundle.
Routes return the sema types themselves — byte-identical to
`to_dict()` wire form (pinned by the DB-free `test_api_wire.py`);
pulls serve stored wire payloads so they match broadcasts exactly.
Party segment is the hyphenated GNodeAlias (`/d1-weather/…`); point
lookups are GETs with format-typed LRD path params; no request words
minted (broker sync-request prior art retired by design).

**Deployment prep.** One `gwwf` console script (`rabbit` / `api` /
`seed`); two systemd units in `service/` on the single-service-login
convention; standalone human-facing README; API binds loopback by
default (TLS is the fronting proxy's job). Home is Hetzner (decided
2026-08-11); the box is provisioned in step 6.

**Published snapshot** (re-squashed in before the push, after the
`gw.weather.*` closure + `gw1.quantity/002` were promoted to
published in sema `c7be5ab`). The vendored snapshot regenerates
without the staging index or dev-only README banner — the artifact
that clears the service for the prod broker (staging snapshots are
dev-only by spec). Also fixes a stale seed-file comment that still
described the pre-r2 closure (`gw.weather.reading` /
`gw.weather.forecast.entry` list-item words that no longer exist —
r2 hard-coded the quantities into the message words).

## 2026-07-18 — add sample weather json from legacy weather

Adds
`tests/hw1.isone.ws-weather-1784374799353-ear.electricity.works.json` —
the byte-exact S3 eventstore object (filename = the S3 key basename, for
provenance), which is the LAST message the legacy weather service on
journalmaker ever published (11:40 UTC 2026-07-18, retired that morning).
This is the wire-parity target for the gwwf standup (OPS-454): the design
requires gwwf to demonstrably reproduce this exact shape before any
deploy work. Fixture only — the parity test itself waits for the OPS-454
design to reach Accepted (implementation gate).
## 2026-07-18 — weather actor uses modern exchange

Deletes the `_consume_exchange = "ws_tx"` override (and its F-007 drift
comment): the prod broker runs the gwbase-generated fabric since the 4.x
upgrade (OPS-424/OPS-425), so the base class's canonical resolution —
`TransportClass.WeatherForecastService` → routing code `weather` →
`weather_tx` — is now correct on prod too, and the compat pin would break
instead of help. The consume path was idle in practice on the legacy
fabric (0 messages at the 2026-07-17 audit), so the change is behaviorally
safe either side of the cutover; deploys on journalmaker at the flip.

## 2026-05-26 — port actual weather out of journalkeeper

**Why:** The legacy `weather_service.py` lived inside
`gridworks-journalkeeper` — wrong home (journalkeeper is a persistence
service, not a producer), built against the pre-0.4.0 gwbase API, and
running via tmux on the LTN host. The journalkeeper-on-base-0.4.0
refactor (`wiki/gridworks-journalkeeper/research/refactor-to-base-0.4.2.md`)
flagged the spin-out, and the production-broker integration test
surfaced that the legacy was already dropping its messages at the
ActorBase routing-class parser (F-007 — `ws` short form not in the
enum). Standing the new service up on its own repo unblocks four
things at once: removes a producer responsibility from journalkeeper
(prerequisite to Stage 2's cruft deletion); puts the actor on a gwbase
0.4.0 framework whose `TransportClass.WeatherForecastService` routes
as the long-form `weather` (cleanly parsed by ActorBase); creates a
landing site for the eventual forecast work (`weather.forecast` for
LTN forward-looking optimizers — see
`research/design-intent.md`); and gives weather its own DB story
distinct from `gw_data`'s `messages` (forecast revisions need
content-addressed history, not the append-only log shape).

What's on the wire is **like-for-like with the legacy service**: same
`weather` v000 type, same NWS-KMLT polling at 10-minute cadence, same
`weather.gov.kmlt` channel name. The type definition lives in sema
(added in the same session via `/make-sema-word` — `weather` v000 with
axiom WindSpeedNonNegative) and the runtime is consumed via a sema
snapshot at `src/gwwf/sema/` driven by
`src/gwwf/sema_seed_request.yaml` (the seed file is package-bound,
snapshot-adjacent — proposed as a sema-wide convention so consumers
don't litter their repo roots with regen ingredients). No vendored
`named_types` in this repo — boundary types belong to sema; consumers
consume snapshots.

The `_consume_exchange = "ws_tx"` override is a deliberate concession
to the prod broker (its exchange fabric uses short forms; F-007
captures the drift) so the new service slots in without a broker
config change.

CI uses the same `ghcr.io/thegridelectric/dev-rabbit:latest` image as
gridworks-base's own CI and developers' local `arm.sh`/`x86.sh` — what
runs in CI is exactly what runs on a developer's box. The README
documents the solo-dev rabbit boot for the same reason.
