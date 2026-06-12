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
   **Hello-world counterpart (Jessica, 2026-06-11):** the terminalasset
   hello-world shipped with nothing watching it — its "done" was a send
   with no witnessed receive. Future hello-worlds (every new repo gets
   one) need a one-command counterpart to spin up: this observer at
   minimum, ideally plus a minimal echo ally, so a hello-world's first
   heartbeat is *seen heard*, not just sent.
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

## The record: logbook, kept reproducer, verified claim (decided 2026-06-11)

An experiment that characterizes repeatable real-world behavior is durable
evidence, not a throwaway (the distinction Jessica drew: steady-state
behavior is repeatable, not "evidence for a moment"). Three things are
kept, each in its right home:

- **A terse logbook** — `experiments/logbook.md`, per domain: one dated
  entry per run — why we ran it, what we found (the verified claim in a
  line), pointers to the reproducer + raw bundle. An index, not a write-up;
  terse by design so it doesn't become the `findings.md` graveyard the
  conventions outlawed.
- **The reproducer package** — the harness (re-runnable) plus its summary,
  kept together so the claim can be re-checked. It IS the evidence behind a
  `Verified` stamp, so it lives as code (scada repo / `experiments/`), not
  as wiki prose.
- **The verified claim** — distilled UP into the relevant spec (`executor/`
  or the design), maturity raised, **scoped honestly to what was actually
  exercised**, naming the experiment that validated it. This is the
  `experiments` arm of the `Draft → Accepted → Verified` ladder
  (GridWorks_CLAUDE "The verification bar").

Raw `jsonl`/logs stay **out of wiki git** — provenance, kept or GC'd,
pointed at from the logbook. Draw the line at *repeatable characterization*:
a one-off plumbing smoke-test may resolve an open "does it work" item but
does not earn a standing logbook entry or a Verified claim.

## Simulated layout builders — the arc (learned 2026-06-11)

Running an experiment needs a way to build a *simulated* layout. The
progression this session made concrete:

- **Start with the script we have.** `make_imaginary_layout.py` (the wand:
  real → imaginary — fresh instance ids, canonical device-type ids, plus a
  stale-version refresh). Available now; it's how the dashboard experiment
  gets its House0.
- **OFI — make it easy.** A layout's shape is *mostly specified by the sema
  layout type* (`gw.house0.layout` / `gw.nolan.layout`), and once
  `layout_gen` lands the clean `core`/`builders`/`subsystems` form from the
  layout-augments rework, building one is near-declarative: the sema type
  says *what a layout is*, a clean `layout_gen` *builds one*, and a
  *simulated* one is just choosing `Sim*` device types. (Depends on the
  spruce-unlimbo `layout-augments-fold` and `nolan-layout-sema` spokes.)
- **Eventually — a docker fleet.** Simulated houses with **randomized tank
  counts** (and other varied parameters), spun up as a fleet for scaled
  experiments — the top of the World scale trajectory, where docker finally
  earns its keep (tool 7). The randomized layouts are exactly what the
  easy-builder above makes cheap.

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
