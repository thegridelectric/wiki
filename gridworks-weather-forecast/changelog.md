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

<!-- pending commit -->
## 2026-08-11 — align aliases + logging with the service pattern

Conform to the settings/logging pattern journalkeeper landed on gwbase
0.5.x: `service_alias` gets a dev default (`d1.weather.dev`, matching
the dev identity file) with env override, `service_name` becomes
`weather-forecast` so logs/state land under the service's own XDG
segment instead of the generic `gridworks` one, and the actor logs
through the per-actor rotating logger `ActorBase` builds (bijective
human format, XDG state-home) — `logging.basicConfig` and the
module-level logger leave `__main__`/the actor.

## 2026-08-11 — vendor gw.weather snapshot; gwbase 0.5.8

Step 0 of the stand-up-weather-forecast build: the sema snapshot
carrying the staged `gw.weather.*` words lands BEFORE the first
consumer line (sema-boundary maxim), and the repo moves from gwbase
0.4.0 to 0.5.8 so the service is built once against the current
framework. The seed keeps legacy `weather` alongside the new words —
the actor still publishes it until the emission scheduler lands; it
leaves the seed when the last legacy import goes. Staging words ⇒
`--allow-staged` dev-only snapshot; promotion to published gates the
prod deploy, not the build. The 0.5.8 port surface: `transport_class`
moves from settings to the actor constructor (intrinsic to the role,
not deployment config), `service_alias` is env-declared and boot-bound
to the g.node.gt identity file (gitignored, now sema-validated at
construction). Done-when met: suite + ruff green; both message words
round-trip through the vendored codec in tests.

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
