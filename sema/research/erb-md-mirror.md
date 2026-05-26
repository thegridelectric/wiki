# Automated MD ↔ ERB structure-preserving map

Status: Draft · Pass 0 · Updated 2026-05-24

What this is: a proposal for tooling that maintains a wiki-style
hub-and-spoke Markdown mirror of the Effortless Rulebook (ERB) schema —
so the rulebook stays a queryable database for tooling while remaining
a human/LLM-readable artifact for wiki-style review and refactor.

This is a research note, not a spec; the canonical ERB integration
question is still open (see `sema-and-domain-protocols.md` and the
WIP `ej-dev` branch of sema for the upstream pipeline ej is building).

## The problem this targets

Under the working synergy thesis — sema YAML stays canonical,
**ej's ERB acts as a granular bidirectional mirror with YAML-leading,
no degradation** — the rulebook itself becomes a load-bearing artifact
the team and Claude need to reason about. Today the rulebook ships as
**one monolithic JSON file** (`effortless-rulebook/effortless-rulebook.json`
≈ 28K lines, ≈ 40-50K tokens). That shape is fine for the
Effortless transpiler pipeline and admin UI, which consume it
programmatically; it is **catastrophic for Claude reasoning** about the
rulebook schema (table names, calc-field formulas, FK shapes) because a
single Read blows past the file-size discipline that gives the wiki its
LLM-friendliness.

The asymmetry matters operationally because of two distinct workflows:

- **Adding/editing sema words** (the common case): authoring stays in
  YAML; the granular emitter projects to ERB rows; Claude never opens
  the rulebook JSON. **No problem.**
- **Reviewing or refactoring the rulebook schema** (the meta case):
  naming objections, ontology questions, new tables or calc-fields,
  audit of cross-cutting invariants. Claude *must* see the rulebook
  shape to help. **Catastrophic without intervention.**

EJ's design optimizes for the first case — under the working
[[erb-is-an-llm-interpretation]] (interpretation C, rulebook-as-
generative-prior), LLMs are expected to add rows / edit YAML, not to
refactor schema. Schema-refactor is human + admin-UI work in his
implicit model. The wiki/Claude collaboration pattern we use at
GridWorks intentionally pulls that meta-work into the LLM loop, which
puts the file-size wall directly in the path.

## The proposal

Build a small bidirectional tool that emits the rulebook schema as a
wiki-style hub-and-spoke MD tree under `wiki/sema/erb-mirror/` and
accepts schema-level edits back as JSON patches against the rulebook.
**Data rows stay in the JSON; only the schema round-trips.**

Layout:

| Path | Holds | Round-trips? | Authoritative? |
|---|---|---|---|
| `wiki/sema/erb-mirror/primary.md` | Hub: rulebook overview, table TOC, cross-cutting invariants, glossary. ≤ 300 lines. | yes | no — derived |
| `wiki/sema/erb-mirror/<cluster>.md` (e.g. `types-and-versions.md`, `axioms.md`, `upgrades-and-ops.md`, `templates.md`, `formats.md`, `enums.md`, `projections.md`, `governance.md`) | Per-cluster: every field with type/datatype/description, every calc-field formula, FK arrows, a small sampled-data excerpt for orientation. ≤ 500 lines each. | yes for the schema; **no** for the sample data (regenerated each emit) | no — derived |
| `sema/effortless-rulebook/effortless-rulebook.json` | Full data + full schema. | — | **yes — ground truth** |

Two emitters:

1. **`rulebook_to_md.py`** — generates the MD mirror from the JSON.
   Walks every table's `schema`, renders Markdown tables of fields with
   their `type` / `datatype` / `Description`, lifts calc-field
   `formula` strings into fenced blocks, draws `RelatedTo` columns as
   FK arrows, includes a small top-N data excerpt as orientation
   only. Deterministic output; runs as part of `effortless build`.

2. **`md_schema_to_rulebook_patch.py`** — reads the MD mirror,
   extracts a constrained set of schema-level edits (rename field,
   edit description, edit calc-field formula, add calc-field, remove
   field, add/remove table) and produces a JSON patch against the
   rulebook. Refuses freeform edits it can't structurally parse.

CI gate: after every rulebook commit, regenerate the MD mirror and
diff against tree; any drift fails the build (same falsifier shape as
[ej's existing `yaml_round_trip_check.py`](../../../sema/rulebook-emitters/yaml/yaml_round_trip_check.py)
on the `definitions/` ↔ `definitions-emitted/` boundary).

## Why this preserves what we care about

- Claude can read `wiki/sema/erb-mirror/<cluster>.md` (~3K tokens)
  instead of the 28K-line JSON. The catastrophic-file-size case
  dissolves for schema reasoning — including the queued naming /
  modeling objections that motivated this note.
- Wiki status-stamp discipline (`Status:` / `Pass:` / `Updated:` /
  `Reviewed:`) applies natively per cluster; reviewer attention is
  steerable per table rather than all-or-nothing.
- Naming-and-modeling objections surface in PR review against MD
  diffs, not against a 28K-line JSON diff that hides intent.
- The MD mirror is hub-and-spoke-disciplined for humans/LLMs; the
  rulebook stays monolithic for tooling that needs it that way. Each
  side keeps the shape it is good at.
- Pattern is a direct sibling of ej's `yaml_to_rulebook` /
  `rulebook_to_yaml` round-trip — same architectural idea applied one
  level up (rulebook schema instead of vocabulary words). Composable
  with everything ej has already built.

## What it does NOT solve

- Data-row edits (new types, new enums, axiom statements) still flow
  through YAML or the admin UI. This tool is about reasoning over the
  rulebook *structure*, not authoring vocabulary words. Different
  concern, intentionally out of scope.
- The L3-with-named-escape-hatches problem in ej's rulebook is
  unchanged: `RawJson` columns at TypeVersions and TypeAttributes
  level still carry the unmodeled JSON-Schema tail (combinators,
  conditionals, oneOf bodies). MD-mirror doesn't make that
  tail queryable.
- Sema axioms remain natural-language Statement strings in ERB; the
  Jinja-template generation question (canonical axiom DSL emitted to
  Python and other languages) is its own thread.

## Downstream extension: Karan-style spec convergence

Once the MD ↔ ERB tooling is proven on sema, the same pattern
generalizes: for any production repo with a CRUD-shaped structural
spine (component catalogs, type inventories, GNode hierarchies,
deployment topologies), an ERB-of-that-repo plus its MD mirror plus
an observe-code-vs-ERB diff gives a Karan-style convergence loop on a
*functional spec* — Claude iteratively closes the gap between
ERB-as-spec and code-as-implemented, with CI gates as the merge
safety. The MD mirror is what lets that loop run *with* Claude
instead of behind a glass wall.

**Important fit caveat**: ERB's relational + calc-field DAG shape
fits the *structural* half of a production repo well (catalogs,
configurations, type registries) and the *behavioral* half poorly
(actor lifecycles, state-machine transitions, async coordination,
real-time message flows). For a repo like `gridworks-scada`, my
rough estimate is 40-60% of the spec content is ERB-shaped; the
rest stays as wiki executor prose. The MD-mirror tooling doesn't
change that fit — it just makes the ERB-shaped portion accessible to
LLM-collaboration in a way the monolithic JSON does not.

## Implementation sketch

- **Day-one pilot scope**: sema's rulebook only. ~28 tables, schema-
  only mirror, sample-data excerpts capped at 5 rows per table. Emit
  side is the easy half; receive side starts with rename-field and
  edit-description only.
- Land `rulebook-emitters/markdown/rulebook_to_md.py` in the sema
  repo, alongside the existing `rulebook-emitters/yaml/` and
  `rulebook-emitters/python|golang|html/` siblings. Output goes to
  `wiki/sema/erb-mirror/` in this wiki repo (cross-repo emit; either
  add a path config or run as a separate step).
- CI gate: a check that fails when the MD mirror is out of date
  with the rulebook (analogous to ej's round-trip check on YAML).
- Authoring direction (MD → rulebook patch) is **phase 2**; phase 1
  is read-only MD mirror, which alone solves the file-size wall.

## Open questions

- Should the MD mirror live in `wiki/sema/erb-mirror/` (wiki repo) or
  in `sema/effortless-rulebook/md/` (sema repo)? Tradeoff: wiki home
  inherits wiki conventions (status stamps, hub-and-spoke) cleanly;
  sema home keeps the mirror co-located with its source. Probably
  wiki, mirroring how `wiki/sema/` already points to `sema/`.
- For the data excerpts: include or omit? Including makes the mirror
  feel concrete; omitting makes the round-trip cleaner (sample data
  is non-load-bearing but produces noisy diffs when it churns).
  Probably include, but mark as `Sample (regenerated, not source)`.
- Naming convention for clusters: one MD per ERB table, or grouped by
  topic? Grouping (e.g., all upgrade-related tables in one MD) reads
  better but couples cluster files to ej's table choices. Probably
  one-MD-per-table with a topic-grouped TOC in `primary.md`.
- Coordination with ej: propose the markdown emitter as a contribution
  to his `rulebook-emitters/` catalog, or maintain it as a wiki-side
  tool. The former gets us multi-tenant reuse; the latter avoids
  blocking on ej's roadmap.

## Status / next step

Proposal only. Not implemented. The decision to build hinges on the
output of the no-degradation audit (`/grill-me` thread "q") for ej's
pipeline as-is — if (q) confirms the file-size wall is the main
blocker to wiki/Claude review, this is the natural response.
