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

> **Editing?** Read [`active-work.md`](active-work.md) first and **claim your
> area** — multiple Claude sessions run at once. Launch Claude from the
> GridWorks **umbrella directory** (not inside one repo) so project memory +
> this wiki load.

## Getting started / how-to

| I want to… | Go to |
| --- | --- |
| Understand a domain's design / rebuild spec | that domain's `executor/primary.md` (see **Domains** below) |
| Understand the conventions / how we work with Claude | [`working-with-llms.md`](working-with-llms.md) (+ [`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md) for the rules) |
| Edit safely while other sessions are running | [`active-work.md`](active-work.md) — claim your area, start from a clean tree |
| Look up a term or a legacy→current name | [`glossary.md`](glossary.md) |
| Work the SCADA cleanup effort | [`gridworks-scada/PROCESS.md`](gridworks-scada/PROCESS.md) + [`gridworks-scada/research/map.md`](gridworks-scada/research/map.md) |
| Rebuild / understand gridworks-base | [`gridworks-base/executor/primary.md`](gridworks-base/executor/primary.md) |
| Understand Sema | [`sema/primary.md`](sema/primary.md) → the in-repo spec it points to |
| See heating / Polstein lifecycle economics | [`heating-system-design/research/polstein-design.md`](heating-system-design/research/polstein-design.md) |
| Trace *why* a change was made | the domain's `changelog.md` |

## Domains

Each top-level folder is a **domain** — a service, mechanism, or design area.

| Domain | What it is |
| --- | --- |
| [`gridworks-base/`](gridworks-base/) | The rabbit-transport actor framework + sema codec boundary |
| [`gridworks-proactor/`](gridworks-proactor/) | The MQTT-native "live actor" + monitored-communication infra under the scada (first-pass spec) |
| [`ear/`](ear/) | The universal audit tap / fundamental persistence mechanism |
| [`rmqbot/`](rmqbot/) | The deployed RabbitMQ/MQTT broker: hosting, TLS/certs, ops |
| [`gridworks-fleet-index-service/`](gridworks-fleet-index-service/) | FIS — the connection-authority (mTLS + instance authorization) |
| [`gridworks-scada/`](gridworks-scada/) | The residential heat-pump SCADA — legacy cleanup in discovery (see its `PROCESS.md`) |
| [`sema/`](sema/) | Sema — boundary-infrastructure vocabulary (authority over meaning). **Minimal pointer domain**; canonical spec lives in the `sema` repo. |
| [`heating-system-design/`](heating-system-design/) | Store-under-floor + heating-system engineering & economics |

## Cross-cutting

- [`working-with-llms.md`](working-with-llms.md) — how we work with Claude and the wiki conventions: how Claude operates, source precedence, the maturity-stamp dial, signaling vocabulary, the research→executor loop, memory-vs-wiki. The *why* behind the conventions.
- [`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md) — the canonical `CLAUDE.md` for the umbrella directory: the rules Claude follows, incl. the wiki authoring conventions ("Wiki essentials") and source precedence (see Setup).
- [`glossary.md`](glossary.md) — vocabulary + legacy→current naming (`atn`→LTN, `ASL`→Sema); defers to Sema for formal types.
- [`active-work-template.md`](active-work-template.md) — the committed multi-session coordination protocol (your live working copy is the gitignored `active-work.md`).

## Setup

This wiki is designed to live **inside a GridWorks umbrella folder**, alongside
the sibling code repos, with the umbrella as the working root:

```
GridWorks/                      ← umbrella (NOT a git repo); launch Claude here
├── CLAUDE.md                   → symlink to wiki/GridWorks_CLAUDE.md
├── wiki/                       ← this repo (github.com/thegridelectric/wiki)
│   ├── GridWorks_CLAUDE.md     ← canonical umbrella CLAUDE.md (version-controlled)
│   ├── README.md  working-with-llms.md  glossary.md  active-work-template.md
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
3. **Launch Claude from the umbrella dir** — that loads the project memory
   (keyed to the umbrella) and makes the wiki + sibling repos reachable in one
   session. See [`active-work.md`](active-work.md) for the multi-session protocol.

**Why a symlink:** the umbrella folder isn't version-controlled, so its
`CLAUDE.md` can't be shared on its own. Keeping the canonical copy here as
`GridWorks_CLAUDE.md` and symlinking makes it shareable and drift-free. Claude
Code **auto-loads `CLAUDE.md`** every session (walking up parent directories);
it does **not** auto-load `AGENTS.md` — so the canonical file must be a
`CLAUDE.md`. (`GridWorks_CLAUDE.md` is just its version-controlled home; the
symlink gives it the name Claude reads.)
