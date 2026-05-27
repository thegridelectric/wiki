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

<!-- pending commit -->
## 2026-05-27 — wiki: retire research/findings.md; split into 5 designs (1 fractal)

**Why:** the per-domain `research/findings.md` register was legacy
(replaced GridWorks-wide by the `designs/` lifecycle in
`wiki/designs-process.md`). Converted the 7 `F-NNN` entries into
discrete design-specs under `wiki/gridworks-base/designs/`, each at
`Status: Draft · Pass 0`:

- `decouple-amq-topic.md` (was F-001)
- `neutral-message-metadata.md` (was F-002; also folds in the
  "explicitly NOT recommended" notes about full `MessageTransport` ABC
  / speculative second-transport adapters)
- `mock-transport-for-tests.md` (was F-003)
- `routingclass-wire-aliases.md` (was F-007)
- `support-non-gnode-actors/` — **fractal subfolder** combining
  F-004 + F-005 + F-006 into one design with three sub-specs
  (`service-settings.md`, `xdg-paths.md`, `init-json-validation.md`)
  plus a `primary.md` hub. The three were always interlocking and
  ship as one.

Deleted `wiki/gridworks-base/research/findings.md` (the
`research/` dir is now empty; left in place for future use). The
XDG-paths sub-spec was sharpened on review: we want the XDG
*convention*, not proactor's full `Paths` class abstraction.

All five new designs registered in `wiki/DESIGN_INDEX.md` "Designs"
section.

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
