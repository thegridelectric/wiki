# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-base` code repo**. The matching git commit (in
`gridworks-base`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

<!-- pending commit -->
## 2026-06-11 — README: document the MQTT bridge tap

**What:** README "Dev Rabbit Broker" — note that `gwbase.topology` bridges the
TimeCoordinator publish exchange to the MQTT plugin's `amq.topic` (the `rjb.#`
broadcast tap), so an MQTT-native service (scada) subscribed to
`rjb/<tc-alias>/time/sim-timestep` receives `sim.timestep`.

**Why:** the README's "SCADA is MQTT-native, no AMQP exchanges" line predated
the bridge tap (`3139f34`, PR #158); it now correctly reflects that a
MQTT-native scada *can* receive TimeCoordinator broadcasts. Surfaced while
exercising the crossing in the scada sim-time experiment.

## 2026-06-11 — Topology: timemic_tx -> amq.topic MQTT bridge tap (`3139f34`, PR #158)

**What:** One new binding in
`gwbase.topology.exchange_bindings()` — the time coordinator's publish
exchange (`timemic_tx`) binds to `amq.topic` (the MQTT plugin's
exchange) with routing key `rjb.#` (broadcasts only; direct traffic
stays on the AMQP fabric). Topology tests updated (binding-count
formula + explicit assertion); committed dev/prod definitions
regenerated via `gen_definitions.py --write-all` (the drift test
enforces this). Verified live on gw-dev-rabbit: an MQTT subscriber on
`rjb/d1-tc/time/sim-timestep` received the tc-hello timesteps with
advancing TimeUnixS — the first witnessed AMQP→MQTT crossing.

**Why:** the sim-time bridge (scada simulated-test-environment design,
sim-time spoke, OPS-40): MQTT-native actors (scadas) can only hear the
time coordinator's `sim.timestep` broadcasts if they cross to
`amq.topic`. The fabric is the authoritative "who may talk to whom",
so the crossing is declared in the shared topology source, not in
per-experiment harness glue. Rides along: `.pre-commit-config.yaml`
ruff pin v0.5.6 → v0.15.14 — the stale pin could not parse the newer
rule selectors in pyproject.toml and blocked commits.

## 2026-06-10 — version 0.5.2 (bump + uv.lock relock)

**What:** Bump gwbase `0.5.1 → 0.5.2`, plus a `uv lock` relock so CI's
`uv sync --locked` accepts the new version (the bump alone left `uv.lock`
pinning `0.5.1`, failing the locked sync).

**Why:** Cut the release that carries the tolerant routing-key parse +
`on_routing_key_parse_error` hook (`724ea52`, design `must-accept-current-ltn-messages`,
OPS-388) so downstream consumers can adopt it — JournalKeeper's `legacy_hack`
(`2156a31`) and the scada `ltn-sends-gw-wrapped` (OPS-387) both wait on this
publish (OPS-389). Backward-compatible patch: the hook is additive and the
routing-key envelope API is consumed, not constructed, outside gwbase.

## 2026-06-09 — Tolerant routing-key parse: accept short-form class tokens; on_message parse-error hook (`724ea52`)

**Why:** a gwbase consumer was **silently dropping** current-production messages
whose routing-key class slot carries a proactor **short_name** (`s`=scada,
`a`=atn, `ws`=weather) instead of a long-form `RoutingClass`. `parse_routing_key`
ran the class token through the closed `RoutingClass` enum, raised `ValueError`,
and `on_message` (which acks *before* parsing) then `return`ed — ack-then-drop,
silent data loss (48 msgs lost in one 5-min prod run; weather forecasts never
captured). The two namespaces — proactor short_names and gwbase `RoutingClass` —
are independent; their overlap (`ltn`, `scada`) was coincidental, so anything
addressed to `s`/`a`/`ws` died. The proactor grammar can't change, so the fix
lives entirely in gwbase: parse the class slot as an **opaque token**, derive
`from_class`/`to_class` best-effort (`TransportClass | None`, `None` when
unresolvable) — safe because a message already reached *this* consumer's queue,
so its own class is redundant for dispatch (it's never needed for routing nor to
disambiguate partners). Build still emits long forms via `*.from_classes(...)`.
`on_message` now routes a parse failure to an overridable
`on_routing_key_parse_error(routing_key, body, error)` hook (default = log+drop)
instead of an inline silent `return` — the seam a consumer (JournalKeeper) can
override to salvage the body. The parser deliberately does **not** learn the
LTN's legacy `broadcast.*` keys as a category — that is fixed at the source
(scada design `ltn-sends-gw-wrapped`) plus a permanent JK `legacy_hack` for
replay. Design `must-accept-current-ltn-messages`. Not yet distilled into
`executor/transport.md` (lands when this merges).

## 2026-06-09 — Thread-safe ActorBase.send: marshal publishes onto the ioloop (`0f0dc28`)

**Why:** lands as its **own patch release** (`0.5.0 → 0.5.1`), separate from the
0.5.0 non-GNode-actors work — a focused thread-safety fix. `ActorBase.send`
called `basic_publish` on the *caller's* thread, but
pika is not thread-safe and the `SelectConnection` + channel are owned by the
consumer thread's ioloop. So any send off the ioloop thread (an actor's timer /
sensor loop, a Supervisor initiating heartbeats, a main-thread caller) raced the
loop on the shared socket — corrupting the connection under load and breaking
*consuming* too, not just the one publish. The fix routes **every** publish onto
the ioloop via `connection.ioloop.add_callback_threadsafe` (single connection;
canonical pika guidance — the rejected alternative, a second publisher
connection, re-adds the lifecycle surface behind the original instability). The
cheap pre-checks (STOPPED/STOPPING, NO_PUBLISH_EXCHANGE, a sync channel-open
pre-check) stay synchronous; the scheduled callback re-checks open + publishes;
both the schedule call and the callback are guarded so `send` never raises
(invariant #9). `send` is now genuinely fire-and-forget — `MESSAGE_SENT` means
*scheduled*. Distilled into `executor/transport.md` §3.8 + `primary.md`
invariant #9. Design `pika-thread-safe-publish` (Accepted, OPS-383) was ratified off this; its
distillate now lives in the executor spec, so the `designs/` file is deleted when
this fix merges (and OPS-383 moves to Done) per the designs-process.

**Validated** by a throwaway pressure harness (built, run, then deleted in this
same change — never committed, never in CI): on the pre-fix code, 48 non-ioloop
threads × 128 KB–512 KB bodies × a 10 µs GIL switch interval gave **~100 %
delivery loss** with a pika-internal `AttributeError` inside `basic_publish` and
a forced reconnect; the identical concurrency on the fixed code delivered
**72 000 / 72 000** with zero errors / zero reconnects.

**Caveat recorded** (transport.md §3.8): marshaling removes the inline
backpressure synchronous publish gave, so a sustained publish rate above the
ioloop drain rate grows the callback queue (frames buffer in memory). Bounded by
gwbase's low-rate traffic; if it ever bites, the answer is a *bounded* publish
queue, not a different threading model.

## Roadmap — gwbase 0.5.0: support non-GNode actors

> Lands across the five commits below (one PR). Each carries its own dated
> entry; this block is the motivating roadmap. As-built spec distilled into
> `wiki/gridworks-base/executor/` (actors.md §5 + primary.md §2).

## 2026-06-06 — version 0.5.0 (`64bd1ba`)

**Why:** release commit for the support-non-gnode-actors PR — bumps the
package version `0.4.2 → 0.5.0`. Also lands the README's "Actor tiers,
settings & file locations" section (tier table, `GWBASE_` settings, the XDG
path layout incl. the Pi log path, and a runnable `uv run python` snippet) —
standalone, no wiki references.

**Why:** `ActorBase` forced *every* gwbase consumer to present a
`g.node.gt`-shaped JSON at construction, even when the service is not a
GNode — so `gridworks-journalkeeper` had to synthesize a fake 3-field
`g_node.json` just to start. The Sema tightening of `Logical` means
journalkeeper et al. cannot be GNodes even in principle. The fix is to stop
requiring the file: split the class hierarchy and the settings shape so
identity scope matches base-class scope, and land four interlocking
sharpenings that touch the same constructor (XDG paths, Sema-validated
`g.node.gt.json`, the FIS handshake, a logging substrate).

## 2026-06-06 — Migrate tests to three-tier API + add tier showcase tests (`41de4a0`)

**Why:** fixtures/stubs move to the new constructor shapes; the Supervisor
and TimeCoordinator stubs become `Orchestrator`-based with `ServiceSettings`
(no `g.node.gt.json` — the exact fake-GNode antipattern this work removes),
while only the real GNode stays a `GridworksActor`. Fixtures now emit
Sema-valid `GNodeGt` files. New `test_tiers.py` documents the three tiers as
runnable examples: a tap built with no GNode file, an Orchestrator
class-routing without GNode identity, and `GridworksActor` validation with
drift / malformed / missing-file all rejected at boot.

## 2026-06-06 — Three-tier actors: ActorBase ear-tap, Orchestrator, GridworksActor sema-validate (`b3fa2c4`)

**Why:** refactor into `ActorBase → Orchestrator → GridworksActor` so
non-GNode rabbit+sema consumers ride the base deliberately. `ActorBase` is
now a passive ear-tap (consumes `ear_tx`, no auto-bind — subclass binds its
slice, no `mic_tx`, `ServiceSettings`, no GNode file read); it sends wrapped
to `amq.topic` but returns the new `NO_PUBLISH_EXCHANGE` diagnostic for a
Direct/Broadcast it cannot class-route. `Orchestrator` adds class-routing
(`transport_class` as an `__init__` param → `<rc>_tx`/`<rc>mic_tx` + a
direct-to-me bind) plus the heartbeat / sim-timestep rhythm moved down from
`GridworksActor`. `GridworksActor` loads + **Sema-validates** its
`g.node.gt.json` as a `GNodeGt` at boot (axioms fire) and asserts
`GNodeGt.alias == service_alias` (provisioning-drift guard). FIS handshake
renamed: `ServiceAlias` + `ServiceInstanceId` always, `GNodeClass` iff GNode.

## 2026-06-06 — Add per-actor logging substrate (`f6f1ea8`)

**Why:** `ActorBase` gains a contextualized `RotatingFileHandler` logger
that writes a bijective human-readable format to the XDG state-home,
designed to map 1:1 onto a future `observability.log-entry/000` Sema type so
a downstream broker-forwarding handler can attach without any actor-side
code change. Substrate only — no broker forwarding, no verbosity hooks
(downstream concern).

## 2026-06-06 — Split settings (ServiceSettings/GNodeSettings) + XDG paths + transport_format (`c2a6cca`)

**Why:** identity scope now matches base-class scope. New `ServiceSettings`
holds the generic rabbit+sema fields (`service_alias`, `instance_id`,
`service_name`, `log_*`); `GNodeSettings` extends it adding only
`g_node_path`. One unified `GWBASE_` env prefix for every service. Default
file locations move from system `/etc/gridworks/...` to per-service XDG
directories via a small inline `config/paths.py` helper (the `g_node_path`
default derives from it) — provisioning no longer needs root.
`transport_class` is removed from settings — it is intrinsic to an actor's
role, not deployment config, and becomes an `Orchestrator` `__init__` param.
New `transport_format` provides `LeftRightDot` / `UUID4Str` so the
config/transport layer types aliases without importing the sema codec
(mirrors `property_format`; sema stays the authority). Adds the `xdg`
dependency.

## 2026-05-22 — release 0.4.2: fix CI publish step + bump version (`50633e8`)

**Why:** the release CI was wedged. `pypa/gh-action-pypi-publish@v1.10.0`'s
bundled twine cannot parse the Metadata-Version 2.4 that `uv build` now
emits (`"Metadata is missing required fields: Name, Version"`), which
is why both 0.4.0 and 0.4.1 CI publishes failed — 0.4.0 had to be
published by hand, 0.4.1 was tagged but never reached PyPI. Swapping
publish from the gh-action to `uv publish` lands on a path that
handles 2.4 natively. Bumped to 0.4.2 (skipping 0.4.1's unreached
slot).

## Roadmap — Drift-proof generated rabbit topology; infra owns the exchange fabric

> Lands across several commits (the `uv` migration below was the first).
> Each commit gets its own dated entry as it merges; this block is the
> motivating roadmap.

**Why:** The broker topology was hand-maintained
(`rabbit/rabbitconfig/rabbit_definitions_dev.json`) and baked into a
*manually* rebuilt image — so it drifted badly: the live image was stuck at
commit `fee74a3` with the pre-refactor token namespace (`atomictnode`,
`gnode`, `timecoordinator`, …) while the code had moved to `RoutingClass`
(`ltn`, `mm`, `super`, `time`, …). Actors also declared their own exchanges
— a second source of truth that risks `PRECONDITION_FAILED` mismatches. This
work makes the topology code-derived and drift-proof:

- **Single source of truth** in `gwbase/topology.py`: the exchange set is
  derived from `RoutingClass` (an opt-in `AMQP_ACTOR_CLASSES` set), and a
  direct-only `ROUTING_EDGES` list + `direct_binding_key` drives the
  cross-class bindings. A generator renders per-vhost definitions JSON
  (`d1__1` dev, `hw1__1` prod); the broker *and* `tests/_stubs.py` consume
  the same source, so they can't diverge.
- **Infra owns the fabric.** Actors only *passively* assert their consume
  exchange exists and declare their own ephemeral queue + direct binding;
  they never declare `mic_tx` or cross-class bindings — killing the
  dual-source mismatch.
- **Identities in the definitions** (users/vhosts/permissions), not
  `default_*` conf lines: dev hash committed (non-secret), prod hash
  injected at deploy.
- **`scada` is MQTT-only** (reached via `amq.topic`, no AMQP exchanges);
  `cn` is passive (opt in later). Broadcasts stay subscriber-bound (not in
  the static fabric); reserve an AMQP↔MQTT bridge so a simulated `ta` can
  talk to scada.
- **Delivery:** CI regenerates-and-diffs the JSON and builds/publishes a
  **GHCR** dev-broker image, so other repos (marketmaker, scada) can run a
  dev broker with no gridworks-base checkout, and the image can't lag the
  repo.
- **Dev rabbit → 4.x** (prod upgrade deferred until a first gwbase actor is
  "tire-kicked" in dev; prod target is also 4.x). mTLS + FIS are a separate
  later track.

See `wiki/gridworks-base/executor/transport.md` §3.5 +
`provisioning.md` §3.6 (hub: `primary.md`),
`wiki/ear/executor/broker-tap.md`, and
`wiki/rmqbot/research/broker-todos.md`.

## 2026-05-22 — fix dev broker conf for RabbitMQ 4.x; document GHCR image (`aa2a368`)

**Why:** The first 4.x dev-broker boot crashed
(`failed_to_prepare_configuration`) — `dev_rabbitmq.conf` still carried 3.x
MQTT keys that 4.x removed:

- `mqtt.default_user` / `mqtt.default_pass` → replaced by the global
  `anonymous_login_user` / `anonymous_login_pass`.
- `mqtt.subscription_ttl` (ms) → `mqtt.max_session_expiry_interval_seconds`
  (s).

Validated by mounting the conf on `rabbitmq:4.1-management` (boots clean;
definitions import into `d1__1`). Also documents the GHCR build/publish flow
and a corrected `rabbitmqctl … -p d1__1` verify step in the README, and
removes the stale cookiecutter footer. **Lesson:** `docker build` only
`COPY`s the conf, so a bad conf surfaces at *container boot*, not build —
always run the image after pushing. (A follow-up fixes `arm.sh`/`x86.sh` to
pull the moving `:latest` and start from a fresh data volume.)

## 2026-05-21 — dev broker: official 4.x + baked GHCR image; retire jessmillar build infra (`4d3f414`)

**Why:** Topology-roadmap commit #6 (final) — replace the hand-built,
drift-prone per-arch broker images with one generated, CI-built artifact.

- **`rabbit/Dockerfile`** bakes `enabled_plugins` + `dev_rabbitmq.conf` +
  `dev_definitions.json` onto the official **multi-arch
  `rabbitmq:4.1-management`** (one image serves arm64 + amd64; Docker
  auto-selects the host's arch on pull).
- **`for_docker/{arm,x86}.yml`** pull `ghcr.io/thegridelectric/dev-rabbit:latest`
  (definitions baked in, no mounts). `dev_rabbitmq.conf` switches to the 4.x
  `definitions.import_backend` / `definitions.local.path` keys and drops the
  `default_*` identity lines (identities come from the baked definitions).
- **`.github/workflows/broker-image.yml`** + **`rabbit/build-and-push.sh`**
  build and push the image (CI gated by `gen_definitions.py --check`; both
  tag `:latest` and `:chaos__<short-sha>__<date>`).
- **Deleted** the superseded dev build infra: `DevRabbit{Arm,X86}Dockerfile`,
  `build-dev-broker-{arm,x86}.sh`, stale `rabbit_definitions_dev.json`. Prod
  track (`broker_arm.yml`, prod `rabbitmq.conf`, hybrid/analytics defs) left
  untouched — prod upgrade is deferred.

Remaining (TODO.md): one-time GHCR push + public visibility, and the
multi-arch smoke test (arm64 local; x86 deferred) before the prod upgrade.

## 2026-05-21 — add definitions drift guard (test + pre-commit + CLI --check) (`232b063`)

**Why:** Topology-roadmap commit #5 — keep the committed broker-definitions
JSON from silently drifting away from `gwbase.topology` (the artifacts are
hand-committed but generator-produced, so they could go stale).

- `gwbase.rabbit_definitions`: add `DEFINITION_ARTIFACTS` (the canonical
  render set), `dumps()` (one canonical serializer), and
  `rendered_artifacts()` — a single source the generator and the guard both
  use, so they can't disagree on form.
- `for_docker/gen_definitions.py`: `--write-all` (render the artifacts) and
  `--check` (exit 1 on drift) modes.
- `tests/test_definitions_drift.py`: the guard, parametrized over the
  artifacts — runs in the normal `uv run pytest` / CI, so an un-rendered
  topology change fails the build.
- `.pre-commit-config.yaml`: a drift hook scoped to the topology/definitions
  files.

## 2026-05-21 — generate rabbit definitions from topology; render dev + prod JSON (`575681f`)

**Why:** Topology-roadmap commit #4 — the broker fabric becomes a
*generated* artifact instead of the hand-maintained
`rabbit_definitions_dev.json`.

- **`gwbase.rabbit_definitions.build_definitions`** renders a RabbitMQ
  management-plugin definitions dict from `gwbase.topology` (exchanges +
  bindings), parameterized by vhost. **Dev** includes the non-secret
  `smqPublic` user with a deterministic (fixed-salt) sha256 password hash +
  full permissions; **prod** omits users/permissions (injected at deploy,
  never baked). Output is deterministic (sorted keys) so CI can
  regenerate-and-diff.
- **`for_docker/gen_definitions.py`** — the thin CLI the image build / CI
  guard call.
- Rendered **`rabbit/rabbitconfig/{dev,prod}_definitions.json`** (`d1__1` /
  `hw1__1`; 15 exchanges, 17 bindings each).

The stale multi-vhost `rabbit_definitions_dev.json` (+ hybrid/analytics
files) are left in place for the docker rework (next), which repoints the
build off them.

## 2026-05-21 — infra owns the exchange fabric (passive declare + provisioned tests) (`ce9b79f`)

**Why:** Topology-roadmap commit #3. Actors stop creating the routing
fabric — it is provisioned out-of-band from the shared `gwbase.topology`
source; the actor only owns its ephemeral endpoint.

- **`actor_base`:** assert the consume exchange with a *passive*
  `Exchange.Declare` (existence check, fail-fast) instead of defining it;
  still never declares `mic_tx` or cross-class bindings. Adds
  `subscribe_broadcast` (bind own queue to a publisher's `mic_tx`) and
  `subscribe_amq_topic` (the AMQP↔MQTT/scada seam). Drops the
  `LeafTransactiveNode` gate on `GridworksWrapped` sends — any actor may
  send wrapped (e.g. a simulated `ta` reaching scada).
- **`gridworks_actor`:** a `heartbeat.a` from `my_super_alias` is still
  handled internally (pong + `on_supervisor_heartbeat`); a `heartbeat.a`
  from any *other* sender now falls through to `process_message`, so a
  supervisor can observe its subordinates' heartbeats.
- **tests:** `_stubs` gains `declare_topology` / `provision_topology`
  derived from `gwbase.topology` (replacing the hand-coded bindings);
  `test_actor_base` and `test_hello` provision the fabric *before* starting
  actors and use a `LeafTransactiveNode` actor (`scada` is MQTT-only, has
  no AMQP exchanges). Full suite green against a live broker.

## 2026-05-21 — add shared broker topology source (`dd2faf8`)

**Why:** Topology-roadmap commit #2 — the single source of truth the rest
of the work derives from. Adds `gwbase/topology.py`:

- `AMQP_ACTOR_CLASSES` — the opt-in set of routing classes that get
  `<rc>_tx` (internal) + `<rc>mic_tx` exchanges (`scada` excluded as
  MQTT-only, `cn` excluded as passive; a new class gets nothing until
  added).
- `ROUTING_EDGES` — the direct-only cross-class routing edges (broadcasts
  are subscriber-bound, not here).
- `direct_binding_key(src, dst)` + `exchanges()` / `exchange_bindings()`
  derivations that the definitions generator *and* `tests/_stubs.py` will
  both consume, so test / dev / prod topologies can't diverge.

`tests/test_topology.py` locks the invariants — and caught a spec typo:
the MarketMaker publish exchange is `mmmic_tx` (`mm` + `mic_tx`), not
`mmic_tx`; the transport spec is corrected to match.

## 2026-05-21 — poetry -> uv (`a64b3c0`)

**Why:** First commit of the topology roadmap above — the toolchain
foundation, since the upcoming definitions generator, CI drift-guard, and
GHCR image build all run under `uv`. Migrated packaging/deps/CI off poetry
to `uv` (matching the `sema` sibling): `[tool.poetry]` → PEP 621
`[project]` + `[dependency-groups]` + hatchling build backend;
`poetry.lock` → `uv.lock`; the `nox-poetry` noxfile became a lean
uv-backed one (`venv_backend="none"`, sessions shell to `uv run`); both
GitHub workflows now use `astral-sh/setup-uv` + `uv run` / `uv build` /
`uv version` (dropping the pip-constraints + nox-poetry machinery and the
dead `constraints.txt`). Behavior preserved: `uv sync` resolves, the full
non-broker suite passes, the package builds.

## 2026-05-19 — WIP decouple transport from codec (`00f96b54`)

**Why:** `ActorBase` mixed RabbitMQ plumbing with Sema type-handling — it
imported message types, encoded/decoded inside its receive loop, and
exposed typed-message send helpers. That blocked reusing the transport with
a different codec, reusing Sema over a different transport, and
per-application codec ownership (a shared global codec forced every actor to
know every type). This single WIP commit bundled three connected changes
toward a clean transport/codec boundary (separated here for the record):

1. **Decouple codec from transport.** Introduce a `RoutingEnvelope` value
   object (a discriminated record whose `routing_key`/`category` are
   derived, not stored) as the single boundary artifact. `ActorBase` now
   deals only in `(RoutingEnvelope, bytes)`; the application owns its own
   `SemaCodec`.

2. **Disambiguate routing vs. application envelopes; add wrap helpers.**
   The transport `Envelope` collided with `gw`, which is *also* an envelope
   (the application-layer wrapper carrying `GridworksHeader` + `Payload`
   across hops). Renamed the transport classes to `RoutingEnvelope` /
   `DirectRoutingEnvelope` / `BroadcastRoutingEnvelope` /
   `WrappedRoutingEnvelope`; restored the convention that a wrapped routing
   key's `type_name` slot carries the **inner** type (enforced in
   `WrappedRoutingEnvelope.__post_init__`); added `gwbase.sema.wrapped` with
   pure `wrap_bytes` / `unwrap_bytes` that depend only on `GridworksHeader`
   / `Gw` (no codec registry), so apps build/parse `gw` envelopes without
   the private codec in scope.

3. **Collapse `ActorApplication`; rename `SupervisableActor` →
   `GridworksActor`.** Dropped the one-method `ActorApplication` ABC
   (`ActorBase` already enforced the contract). Renamed
   `SupervisableActor` → `GridworksActor` (it talks to both a supervisor
   *and* a time coordinator — the canonical default actor). The transport
   hook is now `dispatch_message` (on `ActorBase`); the application hook is
   `process_message` (on `GridworksActor`, was `process_app_message`).

See `wiki/gridworks-base/executor/` — `transport.md` §3.4, `codec.md`
§4.7, `actors.md` §5.1–§5.2 (hub: `primary.md`).
