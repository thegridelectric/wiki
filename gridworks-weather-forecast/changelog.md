# Changelog

A reverse-chronological log of WHY we made each commit. The matching git
commit holds the WHAT (the diff). Each entry's date and one-line title
should mirror the corresponding commit so the two can be cross-referenced.

Format:

```
## YYYY-MM-DD — <commit subject line>

**Why:** <the motivation — what problem, constraint, or decision drove
this change; what alternatives were considered; what this unblocks>
```

Newest at the top.

---

## 2026-05-24 — scaffold gwwf with WeatherActor + sema snapshot + dev-rabbit CI

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
snapshot at `src/gwwf/sema/` driven by `sema_seed_request.yaml` at
the repo root. No vendored `named_types` in this repo — boundary
types belong to sema; consumers consume snapshots.

The `_consume_exchange = "ws_tx"` override is a deliberate concession
to the prod broker (its exchange fabric uses short forms; F-007
captures the drift) so the new service slots in without a broker
config change.

CI uses the same `ghcr.io/thegridelectric/dev-rabbit:latest` image as
gridworks-base's own CI and developers' local `arm.sh`/`x86.sh` — what
runs in CI is exactly what runs on a developer's box. The README
documents the solo-dev rabbit boot for the same reason.
