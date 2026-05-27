# GridWorks glossary & legacy-naming canon

Cross-repo vocabulary that spans more than one project. The **single source of
truth** for informal terminology and legacy→current naming. Collaborators and
agents should treat this file as authoritative; do not keep private copies
(e.g. in an agent's project memory) — point here instead.

**Defers to Sema for formal types.** Anything that is a formal Sema vocabulary
word (a `left.right.dot` type/enum/format) is defined in `sema/` — Sema is the
authority over meaning. This file holds only the *informal* and *transitional*
naming canon that Sema does not govern.

## Legacy → current naming

These terms are **always legacy** wherever they appear in code or in-repo docs.
Read them as their current replacement.

| Legacy term | Read as / replaced by | Notes |
|---|---|---|
| `atn`, `AtomicTNode` | **LeafTransactiveNode (LTN)** | The LTN is being separated out of `gridworks-scada` into a rabbit-native extension of gridworks-base; its presence there (`ltn_app.py`, `actors/ltn/`) is temporary, not a permanent actor subpackage. |
| `ASL`, `Application Shared Language` | **Sema** | Sema is the current boundary-infrastructure language for serialized-JSON contracts. See `sema/CLAUDE.md` and `sema/docs/`. |

## Key GridWorks-specific sema formats

Authoritative format definitions live in
[`sema/definitions/formats/`](../sema/definitions/formats/) (one YAML
file per format word, named `<format>.yaml`) and are surfaced via
[`sema/spec/`](../sema/spec/) (wiki-side: [`sema/`](sema/primary.md)).
The Python validators under `sema/src/sema/runtime/` are **generated
from** the definitions, not the source of truth — never link to them
as the canonical definition.

Soon (~1 week from 2026-05-26) these format words will also be
publishable at `https://schemas.electricity.works/formats/<format>`
so the canonical link can be a stable URL.

Surfaced in this glossary only because they bite at the boundary and
the rule isn't obvious:

| Format word | Pattern | Where it shows up | Why it matters |
|---|---|---|---|
| [`left.right.dot`](../sema/definitions/formats/left.right.dot.yaml) | `^[a-z][a-z0-9]*(\.[a-z0-9]+)*$` | **`GNodeAlias`** and any "addresses" on the grid | This is the grammar of the **collaborative grid coordinate system**. A session-friendly tag like `dev.bright-frost` is rejected because `-` breaks the addressability. Strip hyphens (`dev.brightfrost`) or use bare dotted tokens (`dev`). |
| [`spaceheat.name`](../sema/definitions/formats/spaceheat.name.yaml) | `^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$` | **SCADA channel names** (e.g., `hp-odu-pwr`, `tank1-thermistor-1`); and the `Name` attribute of [`spaceheat.node.gt`](../sema/definitions/types/spaceheat.node.gt/301.yaml) — naming the nodes that are the **primary reference point for binding channels, actors, and control logic** within a SCADA. | Distinct from `left.right.dot` — `spaceheat.name` is the per-installation namespace used inside a SCADA, not the grid-wide addressing space. |

## GridWorks concepts

General GridWorks vocabulary that humans and LLMs new to the ecosystem
will encounter. **Concept names are in bold**; the formal **sema
vocabulary** related to each concept is in the third column, linked
to its canonical YAML. (A token like `left.right.dot` that links to
a sema definition is a sema word; a **bold capitalized** term like
**GNode** is a concept — they're treated as visually distinct
vocabularies throughout the wiki.) Alphabetical.

| Term | Definition | Sema Vocabulary | Repo |
|---|---|---|---|
| **EAR** | Universal audit tap / fundamental persistence mechanism — the broker-side recorder that captures every message crossing the rabbit fabric for later replay, analysis, and proof-of-history. | — | [thegridelectric/gridworks-ear](https://github.com/thegridelectric/gridworks-ear) |
| **FIS** (Fleet Index Service) | Connection authority — issues mTLS certs and authorizes which instance may run as which GNode. The "who-is-allowed-to-be-on-the-bus" gatekeeper. | [`fis.authority.manifest`](../sema/definitions/types/fis.authority.manifest/000.yaml), [`fis.instance.authorization.event`](../sema/definitions/types/fis.instance.authorization.event/000.yaml), [`fis.authorization.decision`](../sema/definitions/enums/fis.authorization.decision/000.yaml), [`fis.authorization.reason`](../sema/definitions/enums/fis.authorization.reason/000.yaml) | [thegridelectric/gridworks-fleet-index-service](https://github.com/thegridelectric/gridworks-fleet-index-service) |
| **GNode** (Grid Node) | The fundamental identity object in the GridWorks ecosystem. Every physical location, metered unit, device, service, or actor is represented as a GNode. Has two classifications: **`BaseClass`** (universal structural ontology, an enum — same 5 values across every organization for interop) and **`GNodeClass`** (free-form string, interpreted in the registering org's namespace — captures functional/role-based meaning that doesn't generalize across orgs). The asymmetry is by design: enum where the world must agree (cross-org topology and market coordination), free-form string where each org names its own roles. | [`g.node.gt`](../sema/definitions/types/g.node.gt/004.yaml), [`base.g.node.class`](../sema/definitions/enums/base.g.node.class/000.yaml), [`left.right.dot`](../sema/definitions/formats/left.right.dot.yaml) (the `Alias` grammar) | — (concept; per-org GNode registries vary) |
| **Layout** (Nolan layout) | Deployable artifact for a single SCADA installation — a self-contained snapshot binding GNodes, ShNodes (the per-installation node graph), DataChannels, hardware components, and actor configs into a structure that the SCADA can boot from without external registry access. | [`gw.nolan.layout`](../sema/definitions/types/gw.nolan.layout/000.yaml) (contains GNodes, ShNodes, channels, components) | consumed by [thegridelectric/gridworks-scada](https://github.com/thegridelectric/gridworks-scada) |
| **LTN** (LeafTransactiveNode) | The atomic metered unit of the grid — the smallest indivisible metering boundary that can participate in markets or enter Dispatch Contracts on behalf of a TerminalAsset. Per-house transactive agent that pairs with a SCADA. Currently a `BaseClass` value `LeafTransactiveNode`; LTN code lives in `gridworks-scada/gw_spaceheat/actors/ltn/` and is being separated into a rabbit-native extension of gridworks-base. | [`base.g.node.class`](../sema/definitions/enums/base.g.node.class/000.yaml) (value: `LeafTransactiveNode`), [`g.node.gt`](../sema/definitions/types/g.node.gt/004.yaml) | (lives inside [thegridelectric/gridworks-scada](https://github.com/thegridelectric/gridworks-scada) for now; moving to a standalone extension of [gridworks-base](https://github.com/thegridelectric/gridworks-base)) |
| **MarketMaker** | (a) The transactive market clearing actor — computes local prices for balancing and constraint compliance. (b) Also a `base.g.node.class` value naming a *physical constraint point* in the conductor topology (feeder constraint, transformer limit) where the market actor operates. | [`base.g.node.class`](../sema/definitions/enums/base.g.node.class/000.yaml) (value: `MarketMaker`) | [thegridelectric/gridworks-marketmaker](https://github.com/thegridelectric/gridworks-marketmaker) |
| **Proactor** | MQTT-native "live actor" + monitored-communication infrastructure that hosts SCADA-side actors. 6 heating systems in the field for 2 years; battle-tested but the internal `Link` concept (single-downstream) and lack of direct-to-`GNodeAlias` addressing are known limitations targeted for refactor. | [`spaceheat.node.gt`](../sema/definitions/types/spaceheat.node.gt/301.yaml) (drives actor identity) | [thegridelectric/gridworks-proactor](https://github.com/thegridelectric/gridworks-proactor) |
| **SCADA** | Residential heat-pump supervisor — the on-site controller managing a single home's transactive heating system. Hosts the actor graph defined by a Nolan layout; communicates upstream via the proactor's MQTT link. | [`spaceheat.node.gt`](../sema/definitions/types/spaceheat.node.gt/301.yaml), [`spaceheat.name`](../sema/definitions/formats/spaceheat.name.yaml), [`gw.nolan.layout`](../sema/definitions/types/gw.nolan.layout/000.yaml) | [thegridelectric/gridworks-scada](https://github.com/thegridelectric/gridworks-scada) |
| **Sema** | The boundary-infrastructure language — vocabulary discipline (formats, types, enums) for what crosses a serialized-JSON boundary between independent systems. Authority over meaning. *Not* runtime architecture, database design, or internal object models. | (itself; canonical sources in [`sema/definitions/`](../sema/definitions/) and [`sema/spec/`](../sema/spec/)) | [thegridelectric/sema](https://github.com/thegridelectric/sema) |
| **ShNode** (Spaceheat node) | A node within a SCADA's actor graph — named by a `spaceheat.name`, *not* a GNode alias. The `Name` field is the primary reference for binding channels, actors, and control logic. One GNode (a SCADA) hosts many ShNodes. Distinct from **GNode** (which is grid-wide identity, `left.right.dot`-aliased). | [`spaceheat.node.gt`](../sema/definitions/types/spaceheat.node.gt/301.yaml), [`spaceheat.name`](../sema/definitions/formats/spaceheat.name.yaml) | (per-installation; defined inside a Nolan layout in [gridworks-scada](https://github.com/thegridelectric/gridworks-scada)) |
| **TerminalAsset** | A physical transactive end-use device (heat pump, hot water heater, residential battery, EV, etc.) located behind an atomic metered boundary. Every TerminalAsset is associated with exactly one **LTN**. | [`base.g.node.class`](../sema/definitions/enums/base.g.node.class/000.yaml) (value: `TerminalAsset`) | — (concept; instantiated per-installation) |

## Where content lives

The four homes for GridWorks content. **Each has a distinct purpose;
don't route content out of one into another just to keep file sizes
down.** This table is the canonical disambiguation.

| Location | What lives here | What does NOT live here |
|---|---|---|
| `wiki/<domain>/executor/` | The **long-lived rebuild spec** for the domain: durable architectural patterns, invariants, glossary, TOC. Hub at `primary.md`, sub-specs beside it. Authoritative once `Verified`. | Time-bounded change plans; open investigations. |
| `wiki/<domain>/research/concerns/` | **Open investigations** — design questions WITHOUT clarity yet. Pure uncertainty surface. May graduate to a design via /grill-me when clarity emerges. | Resolved insights (those distill into `executor/`); ratified plans (those go to `designs/`); workflow state (Linear); work-tracking nits. |
| `wiki/<domain>/designs/` and `wiki/designs/` | **Ratified change plans** (full content): rationale, alternatives, decision tree, classification matrices, sequencing, execution plan — everything about the change stays here. If it grows past ~500L, split into a fractal subfolder; do NOT route content out. | Workflow state (Linear); durable architectural patterns (`executor/`); open investigations (`concerns/`). |
| Linear | **Workflow state**: status (backlog/todo/doing/done), owner, priority, labels, parent/child links, dates. Holds the slug + the wiki path link only. | Design content; vocabulary; rebuild specs; investigations. |

The fixed point that resolves most confusion: **"architectural" is
not the discriminator** — clarity is. An open architectural
*question* lives in `concerns/`; a settled architectural *pattern*
lives in `executor/`. They are opposites on the clarity axis.

## How to extend

Add a row when you find a term in code/docs that has been superseded but still
appears. If the term is a *formal* Sema type, define it in Sema and (optionally)
cross-reference it here rather than redefining it.
