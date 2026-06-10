Status: Draft · Pass 0 · Updated 2026-06-09

# Experimentation harness — tooling to make broker experiments easy + replicable

What this is: the toolset a **World** needs so that standing up a multi-actor,
real-broker **experiment** is a few lines, not an afternoon of hand-wiring. The
concrete driver is the 2026-06-09 LTN→JournalKeeper run (scada
`executor/experimentation-rig.md`), which proved the
`must-accept-current-ltn-messages` + `legacy_hack` fixes on `gw-dev-rabbit` — but
took a pile of bespoke glue. This design is the wishlist that glue should become.

> **Experiments, not tests.** An experiment routes messages through a **real
> broker** — no same-process backdoor — and is often a better simulation of
> reality than a test (this routing-key bug was invisible to the in-process
> `ScadaLiveTest`). See [`../primary.md`](../primary.md) "what a World is".

## The friction this run hit (each item ⇒ a tool below)

- Hand-set each actor's broker env separately (`GJK_RABBIT__URL`,
  `LTN_SCADA_MQTT__HOST/PORT/TLS__USE_TLS`), with per-actor quirks
  (`service_alias` required; anonymous creds; non-TLS `1885`). ⇒ (1)
- Bootstrapping a real `LtnApp` needs a config dir + hardware layout the
  framework normally builds via pytest fixtures. ⇒ (2)
- Hand-instrumented JK (swap persistor/`_persist_body`, wrap `dispatch_message`
  + `on_routing_key_parse_error`) just to *see* what arrived. ⇒ (3)
- No clean way to make an actor emit **one** message of a type without its full
  machinery (FLO, market, timers). ⇒ (4)
- Ran JK against an **unpublished** gwbase branch via `uv run --with-editable`. ⇒ (5)

## The tools

1. **World env profile.** One declarative place (per World) for the broker
   coordinates — AMQP + MQTT URLs, vhost, creds, TLS — that every participant
   reads, so pointing actor X at World B is one reference, not N env vars.
2. **Per-repo `participate()` entrypoint.** Each repo exposes a documented,
   one-call "bring my actor up against this World's broker" (env + layout/config
   + start in a thread). `LtnApp.get_repl_app` and gjk's `point_at_*` scripts are
   the seeds; normalize them across repos. **This is the per-repo harness the
   World methodology asks every repo to provide.**
3. **Generic broker observer/tap.** A reusable consumer: bind `#` (or a slice),
   decode the envelope, and record by routing-key + parse-outcome
   (PARSED / PARSE-ERR / dropped) — no per-experiment monkeypatching. A
   "recorder persistor" so it runs without a DB.
4. **Single-emit driver.** Inject one typed `Message` into a running actor to
   trigger a specific publish, bypassing the heavy machinery.
5. **Branch-pinning.** Declare, per experiment, that actor X runs with sibling
   repo Y's *branch* editable (the `--with-editable` trick) — so cross-repo
   changes can be exercised before they publish.
6. **Capture / replay.** Record real broker traffic (cf. `point_at_prod_observe`)
   and replay it into an experiment as a deterministic stimulus.
7. **One-script orchestration.** Bring up broker + N participants + observer as a
   single replicable script — the concrete form of the World "recipes" and the
   bottom of the scale trajectory.

## Why this belongs to `world/`

Per-repo harnesses (2) are a **standing requirement** the World places on every
repo; (1)(3)–(7) are World-level tools. Together they make experiments
**replicable** — the property that lets a simulated World be trust-building, not
just a one-off demo. This design is the backlog for that toolset.

## Recommended build order (pre-docker first)

Build the cheap, high-payoff pieces first and stay **pre-docker** while a World
is a handful of actors — the LTN→JK run proved a 2-actor experiment needs **no
container for the actors** (they are venv processes; only the broker + postgres
are containers). That is the `world/` scale-trajectory "Today (1–3 actors)" rung:
terminals/venvs + a launcher, no orchestration.

1. **(1) env profile + (3) observer + (8) experimental-actor/CLI** — together
   these turn a 2-actor experiment into one command and would have erased most of
   this run's friction (per-actor env, hand-instrumented JK, hand-copied layout).
2. **(4) single-emit + (2) participate() normalization** — drive a chosen code
   path; make every repo joinable the same way.
3. **(5) branch-pinning** — exercise unpublished cross-repo changes together.
4. **(7) one-script orchestration** — first as a **pre-docker** script (venv
   processes); add docker/compose only at the Tier-1 boundary (several actor
   *types* parameterized by layout + identity, when hand-launching becomes the
   bottleneck — roughly when you cross a handful of actors, not a hard count).
5. **(6) capture/replay** — once live experiments are routine.

Docker is a *scale* tool, not an *experiment* tool: it earns its keep when actor
count/variety makes hand-launching the bottleneck, not before. See `world/`
"Scale trajectory".

## Open

- Whether the World env profile is a file format, a small package, or both.
- How much of (2) is already covered by `App.get_repl_app` vs. needs a shim.
- The exact actor-count / actor-type threshold where compose replaces the
  pre-docker launcher.
