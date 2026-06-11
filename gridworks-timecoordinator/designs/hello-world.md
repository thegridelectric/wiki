# Hello-world timecoordinator

Status: Draft · Pass 0 · Updated 2026-06-11

> What this is: a bite-size design — rebuild `gridworks-timecoordinator`
> from scratch as a uv project on gridworks-base, with a hello-world
> actor that broadcasts `sim.timestep` on the dev rabbit broker. The
> legacy first-pass code (poetry-era, kale/violet vintage) is preserved
> on the `legacy` branch (pushed 2026-06-11); per the legacy-first-pass
> rule it is mined for intent, not carried as implementation. Follows
> the terminalasset hello-world pattern (OPS-404, closed 2026-06-11),
> with its lesson applied: this hello-world's heartbeat must be **seen
> heard**, not just sent.

## Why now

Simulations must operate time correctly: the async-first sim stack runs
on event density, not wall clock, and that requires a time authority.
The scada-on-simulated-time integration is specified separately (the
scada simulated-test-environment design, `sim-time` spoke); this design
is only the repo bring-up and the time source itself.

## Where the time coordinator fits in gwbase (read 2026-06-11)

gwbase already carries the whole orchestration rhythm — the hello
coordinator is filling a seat gwbase built for it:

- **Not a GNode, alias in the GNode tree.** `Orchestrator`'s docstring
  names it: "Used by Supervisor and TimeCoordinator (non-GNode
  orchestration participants, `ServiceSettings`)". So the hello actor
  subclasses **`Orchestrator`** directly — `ServiceSettings`, no
  `g.node.gt.json`, no self-minted identity — with
  `TransportClass.TimeCoordinator` (routing class `time`: `time_tx` /
  `timemic_tx`). Its alias is a `LeftRightDot` address in the tree:
  **`d1.tc`** (decided 2026-06-11 — not the `d1.time` placeholder
  gwbase examples use — anticipating a **tree of time coordinators**
  that work with each other).
- **Every Orchestrator-tier actor already tracks simulated time.**
  `sim.timestep` is a control-plane type (`orchestrator.py:45`):
  reception is built in (`_handle_timestep`, `orchestrator.py:182-188`
  — monotonic guard, repeat-vs-advance), surfacing as the
  `on_simulated_time` hook, and `send_ready()` (`orchestrator.py:232`)
  answers the coordinator with the bundled `Ready` type. The Ready
  barrier is half-built; what's missing is only the coordinator side.
- **Broadcasts are subscriber-bound** (`topology.py` §3.5): the TC
  broadcasts on `timemic_tx`; subscribers bind their own queues to it.
  The witnessed test does exactly what a real child does.
- **Fabric edges today:** `ltn→time`, `mm→time`, `super→time` direct
  edges exist (Ready answers can route); there is **no `ta→time` edge
  yet** — when the simulated terminal asset joins the Ready barrier,
  that is a gwbase `ROUTING_EDGES` addition (broker-enforced reach,
  not actor-side). Noted for the simulation work, not hello-world.
- No new types needed: `SimTimestep` (sema `sim.timestep/000`:
  FromGNodeAlias, FromGNodeInstanceId, TimeUnixS, TimestepCreatedMs,
  MessageId) and `Ready` are bundled in gwbase 0.5.2.

## Scope

1. **Fresh working branch that DELETES EVERYTHING** (decided
   2026-06-11): the new branch starts from scratch — uv scaffold,
   gwbase dependency, nothing of the poetry-era layout survives onto
   it. `legacy` keeps the old code whole. Same shape as terminalasset:
   src layout, hatchling, pytest + ruff, `gridworks-base>=0.5.2` from
   PyPI. Module `gwtc`, console script `tc-hello` (following the
   gwta/ta-hello precedent).
2. **Hello-world actor.** An `Orchestrator` subclass
   (`ServiceSettings`, alias `d1.tc`) with
   `TransportClass.TimeCoordinator` that broadcasts `sim.timestep` at a
   configurable wall-clock cadence (`--beat-seconds`), advancing
   `TimeUnixS` by a configurable step (`--step-seconds`) per beat — so
   hello mode can already run sim time faster than wall time. Existing
   gwbase types only.
3. **Witnessed done-when.** Smoke tests offline; a live-marked test
   that binds an observer queue to `timemic_tx` and **asserts receipt**
   of consecutive `sim.timestep` messages with advancing `TimeUnixS` —
   seen heard, not just sent (the terminalasset hello-world lesson).

## Explicitly out of scope

- New sema types (the Ready-barrier protocol design, pacing
  negotiation) — those ride the simulation work.
- Scada or terminalasset consuming the timesteps — the
  simulated-test-environment `sim-time` spoke.
- The coordinator-side Ready barrier (collecting `Ready`s before
  advancing) — hello mode free-runs.

## Legacy mining list (before the old code is forgotten)

- **The Ready barrier** — the old simulation pattern where supervised
  actors answer a timestep with `Ready` and the coordinator advances
  only when all expected parties have reported: capture the semantics
  (who is "expected", what happens to stragglers) even though hello
  mode does not implement it.
- Pacing modes: as-fast-as-ready vs scaled real-time vs wall-clock.
- Anything else load-bearing in `legacy` `src/` — capture is explicit,
  silence is not capture.

## Open

- The tree of time coordinators (how `d1.tc` relates to coordinator
  children — who advances whom): a simulation-work design question;
  hello-world claims `d1.tc` and stays single.
- Harness wiring note: gwbase examples pass
  `my_time_coordinator_alias="d1.time"`; harness participants must say
  `d1.tc` instead.
