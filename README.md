# GridWorks Wiki

The durable design record and **rebuild specifications** for the GridWorks
system. Code lives in the sibling repos (`gridworks-base`, `gridworks-scada`,
`sema`, …); this wiki holds the *why*, the design intent, and the normative
specs those repos satisfy.

> **Reference for humans — not a Claude read-path.** A Claude session is **not**
> expected to read this README to do its work (it starts from `CLAUDE.md` /
> [`base-CLAUDE.md`](conventions/base-CLAUDE.md) + [`active-claims.md`](active-claims.md)).
> So this file is human onboarding + a map of pointers — **nothing load-bearing
> for Claude's behavior may live only here**; the operative rules live in
> `base-CLAUDE.md` and [`designs-process.md`](conventions/designs-process.md). Because it
> is unread by sessions, it drifts silently — when a pointer here goes stale, fix
> it at the source and re-point.

**This README is a human entry point — what's here and where to go.** For *how we
work with Claude* and the wiki's conventions, see
[`working-with-llms.md`](conventions/working-with-llms.md) (the authoring rules Claude
follows live in [`base-CLAUDE.md`](conventions/base-CLAUDE.md)). New to the repo?
See [Setup](#setup) for how this wiki is meant to sit in a GridWorks umbrella
folder next to the code repos.

> **Looking for what's actively being worked on?** Go to
> [`DESIGN_INDEX.md`](DESIGN_INDEX.md) — the L0 hub aggregating current designs across
> domains. README is for structure / setup; DESIGN_INDEX is for live work.

> **Editing?** Read [`active-claims.md`](active-claims.md) first and **claim your
> area** — multiple Claude sessions run at once. Launch Claude from the
> GridWorks **umbrella directory** (not inside one repo) so project memory +
> this wiki load.

## Getting started / how-to

| I want to… | Go to |
| --- | --- |
| See what's actively being worked on across GridWorks | [`DESIGN_INDEX.md`](DESIGN_INDEX.md) |
| Understand a domain's design / rebuild spec | that domain's `executor/primary.md` (see **Domains** below) |
| **Run / spin up a service** (not just read about it) | that domain's `executor/` how-to sub-specs — e.g. run an LTN + SCADA: [`gridworks-scada/executor/running.md`](gridworks-scada/executor/running.md) |
| Understand a ratified design that's queued / in flight | that domain's `designs/<slug>.md` (or `wiki/designs/` for cross-cutting); see [`designs-process.md`](conventions/designs-process.md) for the lifecycle |
| Understand the conventions / how we work with Claude | [`working-with-llms.md`](conventions/working-with-llms.md) (+ [`base-CLAUDE.md`](conventions/base-CLAUDE.md) for the rules) |
| Edit safely while other sessions are running | [`active-claims.md`](active-claims.md) — claim your area, start from a clean tree |
| Look up a term or a legacy→current name | [`glossary.md`](conventions/glossary.md) |
| Rebuild / understand gridworks-base | [`gridworks-base/executor/primary.md`](gridworks-base/executor/primary.md) |
| Find / understand the LTN (per-house transactive agent) | [`gridworks-ltn/executor/primary.md`](gridworks-ltn/executor/primary.md) — code currently lives in `gridworks-scada/gw_spaceheat/actors/ltn/`, not a standalone repo |
| Understand Sema | [`sema/primary.md`](sema/primary.md) → the in-repo spec it points to |
| Trace *why* a change was made | the domain's `changelog.md` |

## Domain shape

Within each `wiki/<domain>/`:

- `executor/` — the long-lived **rebuild-spec tree** for the domain.
  `executor/primary.md` is the *hub* (≤ ~250–300L: one-line "what this is",
  cross-cutting invariants, glossary, TOC); the substantive content fans out
  into sibling sub-specs (`transport.md`, `codec.md`, `actors.md`, …),
  one concern per file (~300–500L each, 1000L hard cap). The spec is the
  whole tree, not the hub. Authoritative once `Verified`.
- `explorations/` — open architectural questions still under investigation.
- `research/` (loose md) — raw notes, pre-spec thinking, principles.
- `designs/<slug>.md` — ratified design-specs that haven't shipped yet
  (lifecycle in [`designs-process.md`](conventions/designs-process.md); status tracked by
  Linear once wired).
- `changelog.md` — one entry per commit; *why* + brief *what*, paired with the
  commit title.

Cross-cutting / tooling design-specs live at the wiki root in
[`designs/`](designs/), alongside meta convention docs like
[`designs-process.md`](conventions/designs-process.md) and
[`linear.md`](conventions/linear.md).

## Domains

Each top-level folder under `wiki/` is a **domain** — a service, mechanism, or
design area.

| Domain | What it is |
| --- | --- |
| [`gridworks-base/`](gridworks-base/) | The rabbit-transport actor framework + sema codec boundary |
| [`gridworks-data/`](gridworks-data/) | The shared postgres+TimescaleDB schema, alembic migrations, and SQLAlchemy mapping (`gw_data`) consumed by app services |
| [`gridworks-ltn/`](gridworks-ltn/) | LeafTransactiveNode — per-house transactive agent (parent of scada). Code currently at `gridworks-scada/gw_spaceheat/actors/ltn/`; runs via tmux; uses private `gridworks-innovations/gridworks-flo/`. Acceptable-minimum spec, lots Open. |
| [`flo/`](flo/) | FLO — the per-house bid optimizer (`gridflo`, private `gridworks-innovations/gridworks-flo/`); runs in-process in each LTN today, becoming its own service (OPS-514). Executor hub stub only. |
| [`gridworks-weather-forecast/`](gridworks-weather-forecast/) | Weather service. Today: like-for-like port of `gjk/weather_service.py` (publishes `weather` v000). Eventually: forecasts (`weather.forecast`) for LTN forward-looking optimizers + observations under a renamed `gw.weather`-ish type. |
| [`gridworks-web-backend/`](gridworks-web-backend/) | The fleet web page's two services: the read API over the journal DB and the realtime WebSocket gateway from the tap broker. |
| [`gridworks-web-frontend/`](gridworks-web-frontend/) | The fleet dashboard in the browser, a GitHub Pages app over the web-backend API and gateway. Changelog only so far. |
| [`gridworks-proactor/`](gridworks-proactor/) | The MQTT-native "live actor" + monitored-communication infra under the scada (first-pass spec) |
| [`ear/`](ear/) | The universal audit tap / fundamental persistence mechanism |
| [`shovel/`](shovel/) | Mirrors the audit tap onto the analytics broker, one way |
| [`rmqbot/`](rmqbot/) | The deployed RabbitMQ/MQTT broker: hosting, TLS/certs, ops |
| [`gridworks-fleet-index-service/`](gridworks-fleet-index-service/) | FIS — the connection-authority (mTLS + instance authorization) |
| [`gridworks-scada/`](gridworks-scada/) | The residential heat-pump SCADA — legacy cleanup in discovery (see its `PROCESS.md`) |
| [`sema/`](sema/) | Sema — boundary-infrastructure vocabulary (authority over meaning). **Minimal pointer domain**; canonical spec lives in the `sema` repo. |
| [`heating-system-design/`](heating-system-design/) | Store-under-floor + heating-system engineering & economics |
| [`awhp-launch/`](awhp-launch/) | Roadmap for launching transactive air-to-water heat pumps in the US: education, installers, manufacturers, the muni business model |
| [`world/`](world/) | Standing up a GridWorks World — running the ecosystem at any scale/fidelity (laptop → hundreds of actors; real / simulated / hybrid) |

## Cross-cutting

- [`DESIGN_INDEX.md`](DESIGN_INDEX.md) — L0 hub of active work: current `designs/` entries across all domains, open explorations, conventions. Read this every session.
- [`designs-process.md`](conventions/designs-process.md) — the `designs/` lifecycle (status stamps, Pass discipline, fractal expansion, when to ship/distill to `executor/`).
- [`linear.md`](conventions/linear.md) — how GridWorks uses Linear: the split, labels, the design↔issue bijection, Projects, cap-8.
- [`working-with-llms.md`](conventions/working-with-llms.md) — how we work with Claude and the wiki conventions: how Claude operates, source precedence, the maturity-stamp dial, signaling vocabulary, the research→executor loop, memory-vs-wiki. The *why* behind the conventions.
- [`base-CLAUDE.md`](conventions/base-CLAUDE.md) — the canonical `CLAUDE.md` for the umbrella directory: the rules Claude follows, incl. the wiki authoring conventions ("Wiki essentials") and source precedence (see Setup).
- [`glossary.md`](conventions/glossary.md) — vocabulary + legacy→current naming (`atn`→LTN, `ASL`→Sema); defers to Sema for formal types.
- [`active-claims-template.md`](conventions/active-claims-template.md) — the committed multi-session coordination protocol (your live working copy is the gitignored `active-claims.md`).

## Setup

This wiki is designed to live **inside a GridWorks umbrella folder**, alongside
the sibling code repos, with the umbrella as the working root:

```
GridWorks/                      ← umbrella (NOT a git repo); launch Claude here
├── CLAUDE.md                   → symlink to wiki/conventions/base-CLAUDE.md
├── base.sh  scada.sh  build-executor.sh  → symlinks to wiki/tools/ (session launchers)
├── wiki/                       ← this repo (github.com/thegridelectric/wiki)
│   ├── README.md  DESIGN_INDEX.md  active-claims.md
│   ├── conventions/            ← base-CLAUDE.md (the umbrella CLAUDE.md, version-controlled),
│   │                             executor-CLAUDE.md, glossary, designs process, Linear, patterns
│   ├── rulebook/               ← the no-code half: reasoning behind the executors
│   └── <domain>/ …
├── gridworks-base/             ← sibling code repo
├── gridworks-scada/            ← sibling code repo
├── sema/                       ← sibling code repo
└── …
```

To set up a machine:

1. Make the umbrella folder; clone the sibling repos **and this wiki** into it.
2. Point the umbrella's `CLAUDE.md` at this repo's canonical copy:
   `cd GridWorks && ln -s wiki/conventions/base-CLAUDE.md CLAUDE.md` (symlink preferred;
   copy works too).
   Optionally link the session launchers beside it:
   `for s in base scada build-executor; do ln -s wiki/tools/$s.sh $s.sh; done`.
   Each starts Claude with that kind's protocol file appended
   (`conventions/<kind>-CLAUDE.md`) and permissions skipped; add
   `--include-sema` to append the sema protocol too (`build-executor.sh`
   always includes it).
3. **Wire up the hooks.** All ship as scripts under
   [`tools/`](tools/); each script's top-of-file comment explains what
   it does and why. Add to your `~/.claude/settings.json`
   (replace `<your-umbrella>` with your GridWorks path; all require
   `jq` on PATH):

   ```json
   {
     "hooks": {
       "SessionStart": [{
         "hooks": [{
           "type": "command",
           "command": "<your-umbrella>/wiki/tools/gridworks-session-init.sh",
           "statusMessage": "GridWorks session init"
         }]
       }],
       "UserPromptSubmit": [{
         "hooks": [{
           "type": "command",
           "command": "<your-umbrella>/wiki/tools/check-changelog.sh",
           "statusMessage": "Checking changelog discipline"
         }]
       }],
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             {
               "type": "command",
               "command": "<your-umbrella>/wiki/tools/precheck-claims-on-branch.sh",
               "statusMessage": "Branch-create re-check (active-claims)"
             },
             {
               "type": "command",
               "command": "<your-umbrella>/wiki/tools/precheck-bulk-on-dirty-tree.sh",
               "statusMessage": "Bulk-op on dirty tree re-check"
             }
           ]
         },
         {
           "matcher": "Edit|Write|NotebookEdit",
           "hooks": [
             {
               "type": "command",
               "command": "<your-umbrella>/wiki/tools/precheck-pending-changelog.sh",
               "statusMessage": "Code-repo edit needs a pending changelog entry"
             },
             {
               "type": "command",
               "command": "<your-umbrella>/wiki/tools/precheck-claim-on-dirty.sh",
               "statusMessage": "Active-claim adding dirty repo re-check"
             }
           ]
         }
       ],
       "Stop": [{
         "hooks": [
           {
             "type": "command",
             "command": "<your-umbrella>/wiki/tools/stop-cluster-coherence.sh",
             "statusMessage": "End-of-turn cluster-coherence check"
           },
           {
             "type": "command",
             "command": "<your-umbrella>/wiki/tools/stop-context-size.sh",
             "statusMessage": "End-of-turn context-size check"
           }
         ]
       }]
     }
   }
   ```
4. **Source the bulk-mode aliases.** Add this line to your
   `~/.bash_profile` (or `~/.zshrc`):

   ```sh
   source <your-umbrella>/wiki/tools/bulk-aliases.sh
   ```

   Then `bulk-on <session-name>` creates a per-session override that
   silences the cluster-coherence hooks when you genuinely need a
   large diff burst; `bulk-on --global` is the unscoped form;
   `bulk-status` shows which overrides are active; `bulk-off` clears
   them. Claude MUST NOT touch the override files itself — they're
   the user's signal.

5. **Launch Claude from the umbrella dir** — that loads the project memory
   (keyed to the umbrella) and makes the wiki + sibling repos reachable in one
   session. See [`active-claims.md`](active-claims.md) for the multi-session protocol.

**Why a symlink:** the umbrella folder isn't version-controlled, so its
`CLAUDE.md` can't be shared on its own. Keeping the canonical copy here as
`base-CLAUDE.md` and symlinking makes it shareable and drift-free. Claude
Code **auto-loads `CLAUDE.md`** every session (walking up parent directories);
it does **not** auto-load `AGENTS.md` — so the canonical file must be a
`CLAUDE.md`. (`base-CLAUDE.md` is just its version-controlled home; the
symlink gives it the name Claude reads.)
