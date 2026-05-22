# gridworks-scada — domain primary

Start here for the `gridworks-scada` domain. Wiki-wide conventions (folder
structure, hub-and-spoke, living-spec discipline) live in
[`../GridWorks_CLAUDE.md`](../GridWorks_CLAUDE.md); how-we-work-with-Claude
(memory-vs-wiki, source precedence) is in
[`../working-with-llms.md`](../working-with-llms.md). This file does not repeat
them.

> **Goal:** continuously clean up the SCADA until it is code that LLMs and
> humans can glean from à la carte, and until it can be rebuilt faithfully from
> `executor/`. We are currently in the **discovery** phase: `executor/` is empty;
> the work is mapping the legacy code and capturing design intent in `research/`.

## How this domain is organized

| Path | What it holds |
|---|---|
| [`PROCESS.md`](PROCESS.md) | The repeatable discovery process for this domain — read before a pass. |
| [`changelog.md`](changelog.md) | WHY of each commit (mirrors git WHAT). |
| [`research/map.md`](research/map.md) | Living inventory + coverage tracker; pick the next pass here. |
| [`research/principles.md`](research/principles.md) | Foundational commitments (customer-not-provider, SLA, liveness). |
| [`research/concerns/`](research/concerns/) | Cross-cutting design questions (liveness/SLA, deeds, transport, sema-style, interfaces). |
| [`research/components/`](research/components/) | One file per subsystem: what it does today, with `file:line` refs. |
| [`research/findings.md`](research/findings.md) | Bug / cleanup / improvement register (`F-NNN`). |
| `executor/` | The faithful-rebuild spec — **empty until research converges**. |

The richer `research/` substructure (components / concerns / findings) is a
domain-specific elaboration of the wiki's freeform `research/`; it suits a long
discovery effort over legacy code.

## Cross-references

- Legacy naming (e.g. `atn`→LTN) is canon in [`../glossary.md`](../glossary.md).
- The rabbit-transport contrast and the LTN migration: [`research/concerns/transport-and-links.md`](research/concerns/transport-and-links.md) ↔ [`../gridworks-base/executor/primary.md`](../gridworks-base/executor/primary.md).
- mTLS / connection authority: [`../gridworks-fleet-index-service/`](../gridworks-fleet-index-service/).
