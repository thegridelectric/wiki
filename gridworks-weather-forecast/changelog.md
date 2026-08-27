# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-weather-forecast` code repo**. The matching git commit
(in `gridworks-weather-forecast`) holds the WHAT (the diff). Each
entry's date and one-line title mirror the corresponding code-repo
commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

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

**Read API** (house pattern, canon [`api-pattern.md`](../api-pattern.md)).
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
