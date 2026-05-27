# GridWorks Wiki

The durable design record and **rebuild specifications** for the GridWorks
system. Code lives in the sibling repos (`gridworks-base`, `gridworks-scada`,
`sema`, …); this wiki holds the *why*, the design intent, and the normative
specs those repos satisfy.

**This README is the entry point — what's here and where to go.** For *how we
work with Claude* and the wiki's conventions, see
[`working-with-llms.md`](working-with-llms.md) (the authoring rules Claude
follows live in [`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md)). New to the repo?
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
| Understand a ratified design that's queued / in flight | that domain's `designs/<slug>.md` (or `wiki/designs/` for cross-cutting); see [`designs-process.md`](designs-process.md) for the lifecycle |
| Understand the conventions / how we work with Claude | [`working-with-llms.md`](working-with-llms.md) (+ [`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md) for the rules) |
| Edit safely while other sessions are running | [`active-claims.md`](active-claims.md) — claim your area, start from a clean tree |
| Look up a term or a legacy→current name | [`glossary.md`](glossary.md) |
| Rebuild / understand gridworks-base | [`gridworks-base/executor/primary.md`](gridworks-base/executor/primary.md) |
| Find / understand the LTN (per-house transactive agent) | [`gridworks-ltn/executor/primary.md`](gridworks-ltn/executor/primary.md) — code currently lives in `gridworks-scada/gw_spaceheat/actors/ltn/`, not a standalone repo |
| Understand Sema | [`sema/primary.md`](sema/primary.md) → the in-repo spec it points to |
| See heating / Polstein lifecycle economics | [`heating-system-design/research/polstein-design.md`](heating-system-design/research/polstein-design.md) |
| Trace *why* a change was made | the domain's `changelog.md` |

## Domain shape

Within each `wiki/<domain>/`:

- `executor/` — the long-lived **rebuild-spec tree** for the domain.
  `executor/primary.md` is the *hub* (≤ ~250–300L: one-line "what this is",
  cross-cutting invariants, glossary, TOC); the substantive content fans out
  into sibling sub-specs (`transport.md`, `codec.md`, `actors.md`, …),
  one concern per file (~300–500L each, 1000L hard cap). The spec is the
  whole tree, not the hub. Authoritative once `Verified`.
- `research/concerns/` — open architectural questions still under investigation.
- `research/` (loose md) — raw notes, pre-spec thinking, principles.
- `designs/<slug>.md` — ratified design-specs that haven't shipped yet
  (lifecycle in [`designs-process.md`](designs-process.md); status tracked by
  Linear once wired).
- `changelog.md` — one entry per commit; *why* + brief *what*, paired with the
  commit title.

Cross-cutting / tooling design-specs live at the wiki root in
[`designs/`](designs/), alongside meta convention docs like
[`designs-process.md`](designs-process.md) and
[`designs/linear-integration.md`](designs/linear-integration.md).

## Domains

Each top-level folder under `wiki/` is a **domain** — a service, mechanism, or
design area.

| Domain | What it is |
| --- | --- |
| [`gridworks-base/`](gridworks-base/) | The rabbit-transport actor framework + sema codec boundary |
| [`gridworks-data/`](gridworks-data/) | The shared postgres+TimescaleDB schema, alembic migrations, and SQLAlchemy mapping (`gw_data`) consumed by app services |
| [`gridworks-ltn/`](gridworks-ltn/) | LeafTransactiveNode — per-house transactive agent (parent of scada). Code currently at `gridworks-scada/gw_spaceheat/actors/ltn/`; runs via tmux; uses private `gridworks-innovations/gridworks-flo/`. Acceptable-minimum spec, lots Open. |
| [`gridworks-weather-forecast/`](gridworks-weather-forecast/) | Weather service. Today: like-for-like port of `gjk/weather_service.py` (publishes `weather` v000). Eventually: forecasts (`weather.forecast`) for LTN forward-looking optimizers + observations under a renamed `gw.weather`-ish type. |
| [`gridworks-proactor/`](gridworks-proactor/) | The MQTT-native "live actor" + monitored-communication infra under the scada (first-pass spec) |
| [`ear/`](ear/) | The universal audit tap / fundamental persistence mechanism |
| [`rmqbot/`](rmqbot/) | The deployed RabbitMQ/MQTT broker: hosting, TLS/certs, ops |
| [`gridworks-fleet-index-service/`](gridworks-fleet-index-service/) | FIS — the connection-authority (mTLS + instance authorization) |
| [`gridworks-scada/`](gridworks-scada/) | The residential heat-pump SCADA — legacy cleanup in discovery (see its `PROCESS.md`) |
| [`sema/`](sema/) | Sema — boundary-infrastructure vocabulary (authority over meaning). **Minimal pointer domain**; canonical spec lives in the `sema` repo. |
| [`heating-system-design/`](heating-system-design/) | Store-under-floor + heating-system engineering & economics |

## Cross-cutting

- [`DESIGN_INDEX.md`](DESIGN_INDEX.md) — L0 hub of active work: current `designs/` entries across all domains, open concerns, conventions. Read this every session.
- [`designs-process.md`](designs-process.md) — the `designs/` lifecycle (status stamps, Pass discipline, fractal expansion, when to ship/distill to `executor/`).
- [`designs/linear-integration.md`](designs/linear-integration.md) — Linear ↔ wiki interface (epic + sub-issue templates, port/pull recipes, status-flow).
- [`working-with-llms.md`](working-with-llms.md) — how we work with Claude and the wiki conventions: how Claude operates, source precedence, the maturity-stamp dial, signaling vocabulary, the research→executor loop, memory-vs-wiki. The *why* behind the conventions.
- [`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md) — the canonical `CLAUDE.md` for the umbrella directory: the rules Claude follows, incl. the wiki authoring conventions ("Wiki essentials") and source precedence (see Setup).
- [`glossary.md`](glossary.md) — vocabulary + legacy→current naming (`atn`→LTN, `ASL`→Sema); defers to Sema for formal types.
- [`active-claims-template.md`](active-claims-template.md) — the committed multi-session coordination protocol (your live working copy is the gitignored `active-claims.md`).

## Setup

This wiki is designed to live **inside a GridWorks umbrella folder**, alongside
the sibling code repos, with the umbrella as the working root:

```
GridWorks/                      ← umbrella (NOT a git repo); launch Claude here
├── CLAUDE.md                   → symlink to wiki/GridWorks_CLAUDE.md
├── wiki/                       ← this repo (github.com/thegridelectric/wiki)
│   ├── GridWorks_CLAUDE.md     ← canonical umbrella CLAUDE.md (version-controlled)
│   ├── README.md  working-with-llms.md  glossary.md  active-claims-template.md
│   └── <domain>/ …
├── gridworks-base/             ← sibling code repo
├── gridworks-scada/            ← sibling code repo
├── sema/                       ← sibling code repo
└── …
```

To set up a machine:

1. Make the umbrella folder; clone the sibling repos **and this wiki** into it.
2. Point the umbrella's `CLAUDE.md` at this repo's canonical copy:
   `cd GridWorks && ln -s wiki/GridWorks_CLAUDE.md CLAUDE.md` (symlink preferred;
   copy works too).
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
         "hooks": [{
           "type": "command",
           "command": "<your-umbrella>/wiki/tools/stop-cluster-coherence.sh",
           "statusMessage": "End-of-turn cluster-coherence check"
         }]
       }]
     }
   }
   ```
4. **Install the wiki's slash commands.** Symlink each `.md` in
   [`tools/claude-commands/`](tools/claude-commands/) into your
   `~/.claude/commands/`:

   ```sh
   for f in <your-umbrella>/wiki/tools/claude-commands/*.md; do
     ln -sf "$f" ~/.claude/commands/"$(basename "$f")"
   done
   ```

   These ritualize sub-CLAUDE.md loading (e.g. `/make-sema-word`) so cross-repo
   sessions don't skip domain-specific protocols. See
   [`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md) "Sub-CLAUDE.md protocols".
5. **Source the bulk-mode aliases.** Add this line to your
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

6. **Launch Claude from the umbrella dir** — that loads the project memory
   (keyed to the umbrella) and makes the wiki + sibling repos reachable in one
   session. See [`active-claims.md`](active-claims.md) for the multi-session protocol.

**Why a symlink:** the umbrella folder isn't version-controlled, so its
`CLAUDE.md` can't be shared on its own. Keeping the canonical copy here as
`GridWorks_CLAUDE.md` and symlinking makes it shareable and drift-free. Claude
Code **auto-loads `CLAUDE.md`** every session (walking up parent directories);
it does **not** auto-load `AGENTS.md` — so the canonical file must be a
`CLAUDE.md`. (`GridWorks_CLAUDE.md` is just its version-controlled home; the
symlink gives it the name Claude reads.)
