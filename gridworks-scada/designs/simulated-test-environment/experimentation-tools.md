# Experimentation tools — replicable real-broker experiments

Status: Draft · Pass 0 · Updated 2026-06-11

> What this is: simulated-test-environment spoke — the toolset that makes
> standing up a multi-actor, real-broker experiment a few lines instead of
> an afternoon of hand-wiring. Absorbed from the cross-cutting
> `world/designs/experimentation-harness.md` (taken down 2026-06-11) when
> all simulation/experimentation work consolidated into this design; the
> concrete driver was the 2026-06-09 LTN→JournalKeeper run on
> `gw-dev-rabbit`, which proved its fixes but took a pile of bespoke glue.
> Most items here are **todo-later** — the hub's increments come first —
> but they are the named backlog, not lost ideas.

**Experiments, not tests.** An experiment routes messages through a
**real broker** — no same-process backdoor — and is often a better
simulation of reality than a test (the 2026-06-09 routing-key bug was
invisible to the in-process `ScadaLiveTest`). The World framing lives in
[`../../../world/primary.md`](../../../world/primary.md); this spoke
keeps its standing requirement: **every repo provides a documented
one-call way to join an experiment** (tool 2 below).

## The friction the LTN→JK run hit (each item ⇒ a tool)

- Hand-set each actor's broker env separately (`GJK_RABBIT__URL`,
  `LTN_SCADA_MQTT__HOST/PORT/TLS__USE_TLS`), with per-actor quirks
  (`service_alias` required; anonymous creds; non-TLS `1885`). ⇒ (1)
- Bootstrapping a real `LtnApp` needs a config dir + hardware layout the
  framework normally builds via pytest fixtures. ⇒ (2)
- Hand-instrumented JK (swap persistor/`_persist_body`, wrap
  `dispatch_message` + `on_routing_key_parse_error`) just to *see* what
  arrived. ⇒ (3)
- No clean way to make an actor emit **one** message of a type without
  its full machinery (FLO, market, timers). ⇒ (4)
- Ran JK against an **unpublished** gwbase branch via
  `uv run --with-editable`. ⇒ (5)

## The tools (backlog; build order below)

1. **World env profile.** One declarative place per World for the broker
   coordinates — AMQP + MQTT URLs, vhost, creds, TLS — that every
   participant reads, so pointing actor X at World B is one reference,
   not N env vars.
2. **Per-repo `participate()` entrypoint.** Each repo exposes a
   documented one-call "bring my actor up against this World's broker"
   (env + layout/config + start in a thread). `LtnApp.get_repl_app` and
   gjk's `point_at_*` scripts are the seeds; normalize across repos.
   The terminal asset (gridworks-terminalasset) should be born with one.
3. **Generic broker observer/tap.** A reusable consumer: bind `#` (or a
   slice), decode the envelope, record by routing-key + parse-outcome
   (PARSED / PARSE-ERR / dropped) — no per-experiment monkeypatching. A
   "recorder persistor" so it runs without a DB. This is also the
   capture half of observation-driven spec building (the hub's
   wire-view/protocol-view discipline).
4. **Single-emit driver.** Inject one typed `Message` into a running
   actor to trigger a specific publish, bypassing the heavy machinery.
5. **Branch-pinning.** Declare, per experiment, that actor X runs with
   sibling repo Y's *branch* editable (the `--with-editable` trick) — so
   cross-repo changes can be exercised before they publish.
6. **Capture / replay.** Record real broker traffic (cf.
   `point_at_prod_observe`) and replay it into an experiment as a
   deterministic stimulus.
7. **One-script orchestration.** Bring up broker + N participants +
   observer as one replicable script — the bottom of the World scale
   trajectory.

## Build order (pre-docker first)

Stay **pre-docker** while an experiment is a handful of actors — the
LTN→JK run proved a 2-actor experiment needs no container for the actors
(venv processes; only broker + postgres are containers). Docker is a
*scale* tool, not an *experiment* tool: it earns its keep when actor
count/variety makes hand-launching the bottleneck.

1. **(1) env profile + (3) observer** — these two would have erased most
   of the LTN→JK run's friction, and (3) is what the hub's comms
   experiments (old proactor link vs new AllyLink) need first.
2. **(4) single-emit + (2) participate() normalization.**
3. **(5) branch-pinning** — exercise unpublished cross-repo changes
   together.
4. **(7) one-script orchestration** — first as a pre-docker script;
   compose only when several actor *types* parameterized by layout +
   identity make hand-launching the bottleneck.
5. **(6) capture/replay** — once live experiments are routine.

## Open

- Whether the World env profile is a file format, a small package, or
  both.
- How much of (2) is already covered by `App.get_repl_app` vs. needs a
  shim.
- The exact actor-count / actor-type threshold where compose replaces
  the pre-docker launcher.
- Whether these tools live in the scada repo, gwbase, or a small
  experiments repo — decide when tool (1)/(3) get built (the fable's
  experiment work will force the question).
