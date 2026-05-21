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
