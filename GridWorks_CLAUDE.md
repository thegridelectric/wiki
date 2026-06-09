# GridWorks — working conventions for Claude

Status: Draft · Pass 0 · Updated 2026-05-27

> Canonical at `wiki/GridWorks_CLAUDE.md`; symlink setup in
> [`README.md`](README.md#setup). Paths below are relative to the umbrella dir
> (parent of `wiki/` + the sibling code repos: `gridworks-base`,
> `gridworks-scada`, `sema`, …). The wiki holds the
> durable thinking and the **rebuild specifications** for each domain — start
> at [`wiki/README.md`](wiki/README.md) to find anything (domain map +
> getting-started/how-to). Coordination before editing is under Multi-session.

## Source precedence (when sources conflict)

Resolve conflicts in this order:

1. **Your explicit instruction, now.** Always wins. If it contradicts the
   curated wiki, flag the divergence and offer to update the wiki — never let
   the record silently drift.
2. **Verified wiki specs (`executor/`, marked `verified`) + code/tests.** For a
   `verified` domain the executor spec is the contract; if code disagrees, the
   code is the suspect. For not-yet-verified domains, code/tests win and the
   spec is corrected to match.
3. **Wiki research / `converging` / `inferred` content.** Informative, not
   binding — a hypothesis, not a fact.
4. **Ad-hoc research (web, one-off code reads).** Label provenance; verify
   before relying or canonizing.
5. **My own earlier statements this session.** Lowest — re-derive from the
   above; do not anchor on what I previously said.

## Legacy first-pass code: vision, not how

Several repos hold **first-pass simulation code that never ran in
production and was never tested in reality** — written to prove a vision,
not to be the implementation we ship. Treat such code as a **reservoir of
design intent, not a template.** Mine it for the *what* and *why* (the
market structure, the invariants, the hard-won domain learning); do **not**
carry forward its *how* (its transport, serialization, naming, vendor-specific
plumbing, or simulation shortcuts). When the user's stated vision and the
legacy implementation conflict, the vision wins and the old code is the
suspect. Do not over-design to legacy mechanics just because they exist in a
repo — design the new thing from the vision. **But distinguish a legacy
*implementation* from a durable *principle*:** dropping vendor-specific
plumbing does NOT mean dropping the capability it implemented. (E.g. the
Algorand code is legacy plumbing, but the *cryptographic-veracity / distributed-
trust* principle it served is core vision.)

## Status stamps

Every non-trivial wiki doc carries a one-line stamp at the top.
Applies to **all wiki markdown** except: `README.md`, `changelog.md`,
`DESIGN_INDEX.md`, `glossary.md`, `active-claims*.md`, and files under
`wiki/tests/` and `wiki/tools/`. Enforced by
`wiki/tests/test_doc_health.py`.

`Status: <maturity> · Pass <n> · Updated <date>[ · Reviewed <date>@<commit>]`

**The doc-level stamp is a floor.** No section in the doc may have
*lower* maturity than the doc-level stamp. A `##` section MAY carry
its own stamp *only when it is more mature than the doc-level stamp*
— e.g., a settled glossary or already-`Verified` list of invariants
inside an otherwise-`Draft` design. If a section would be *less*
mature than the doc, demote the doc instead. Section stamps live at
`##`, never deeper.

- **Maturity** `Draft → Accepted → Verified` — `Verified` = validated against
  reality (code, tests, or experiments; the `Reviewed` field records which).
  **The maturity stamp is the authority dial for Source precedence above** —
  raise/lower it to raise/lower how much the wiki binds. Unlike ADRs,
  `Accepted` docs stay **living** — kept current by freshness, not frozen.
- **Pass `n`** — count of meaningful human–LLM back-and-forth passes; `Pass 0` =
  Claude-solo, unreviewed. **Increments only when the user asks** (or I prompt
  and they agree), per `##` section.
- **Freshness** — `Updated` = last substantive edit (≈ commit date); `Reviewed`
  = last checked against code/tests, with the commit. A `Verified`-but-stale
  stamp means re-verify before relying, then bump it.

## Weight signals

- **musing** → not a decision; don't act, don't record.
- **canonize** → durable; I write it to the wiki.

I **proactively ask to canonize** at real decision points; if I can't tell a
decision from a musing, I ask.

## Multi-session coordination

Several Claude sessions edit GridWorks at once. You **MUST** read
[`wiki/active-claims.md`](wiki/active-claims.md) before you edit and again
when extending into a new path or area. The SessionStart hook auto-claims
your session there (friendly name + first-6 hash); the **normative
protocol** lives in that file below the table.

**Focus shorthand — design lookup.** When the user states a Focus as loose
words that read like a design name (e.g. "sema snapshot improvement",
"gridworks-scada relay timing", "linear integration"), resolve it to a design
file before doing anything else. Kebab-case the words and match fuzzily against
file names. Try **both** of these and take whichever hits:

- **Cross-cutting** — the *whole* phrase as the slug in **`wiki/designs/`**
  ("linear integration" → `wiki/designs/linear-integration.md`).
- **Per-domain** — if the first word names a `wiki/` domain folder, treat it as
  `<subfolder>` and the *remaining* words as the slug in
  **`wiki/<subfolder>/designs/`** ("sema snapshot improvement" → domain `sema`,
  slug `snapshot-improvement` → `wiki/sema/designs/snapshot-improvement.md`).
  (`<subfolder>` is the bare domain name; prepend `wiki/`.)

Don't assume the first word is always a domain — for a cross-cutting design the
first word is part of the slug. Open the matched design and treat it as the
session's anchor. If both interpretations miss, list what you found in the
candidate folders and ask rather than guessing.

## Sub-CLAUDE.md protocols

- **Do NOT create a new `CLAUDE.md` in a sub-repo or sub-folder unless
  the human asks.** Sub-CLAUDE.md files are *operative* — they encode
  protocol Claude is expected to follow when working in that area. New
  ones proliferate easily and burden every future session with
  discovery + load. The human decides when one is genuinely warranted.
- **Adding or modifying a sema word** → suggest the user run
  `/make-sema-word`. Before any edit, **Read `sema/CLAUDE.md`** and follow
  its protocol verbatim.

## Commit suggestions

Human does all `git commit`s; I suggest at logical units (path-scoped
`git add` + a one-line message) and never `git add -A` while other sessions
may be live (mirror your active-claims Scope). For Karan-style autonomy
(Claude doing commits/merges with merge-safety guardrails) see
`working-with-llms.md` "Karan's commit rules" — reference, not active.

## Linear issue tags

When creating a Linear issue, **first review the existing label set**
(`list_issue_labels` on the **Ops** team) and reuse a fitting tag; coin a new
one only after a moment's deliberation — tags proliferate easily, and the
**live Linear set (not the wiki) is the source of truth** (the MCP is
create-only for labels, so the wiki deliberately keeps no glossary). Tags
cluster on five axes: house · component/domain · work-kind · cross-cutting ·
effort. Two integration-specific tags: **`design`** ↔ a `wiki/**/designs/`
file (the bijection), and **`nit`** = sub-threshold software not worth a wiki
design (so `nit` and `design` are mutually exclusive); **`bite-size`** is a
small effort that **may** still be a design. Full convention in
[`linear.md`](linear.md).

## Working-tree hygiene

Code-repo edits are organised into **clusters**: one pending changelog
entry (`<!-- pending commit -->`) in `wiki/<domain>/changelog.md` = one
cluster. Wiki changes are not cluster-checked. **Changelogs are a
per-domain artifact only** — cross-cutting wiki folders (`wiki/designs/`,
`wiki/tests/`, `wiki/tools/`, etc.) SHALL NOT have their own
`changelog.md`; wiki-convention changes live in git history only. Enforced structurally by
hooks in `tools/` — `precheck-pending-changelog.sh`,
`precheck-claim-on-dirty.sh`, `precheck-bulk-on-dirty-tree.sh`,
`stop-cluster-coherence.sh`. If a hook fires, cache any in-flight plan
to a scratch note before pivoting and surface the state to the user;
disposition is theirs. Before more than ~5 file edits in one cycle, I
SHALL ask whether to enable `bulk-on` for the burst. The user creates
`~/.claude/.bulk-stop-override(.<session>)` via `bulk-on` to silence
the hooks; I MUST NOT create that file myself.

## Wiki essentials (the wiki's authoring conventions)

**Structure** — each top-level `wiki/<domain>/` is a service/mechanism/design
area. Within a domain: `research/` (pre-spec notes, not normative), `executor/`
(the **faithful-rebuild spec** — complete enough to rebuild the domain from the
docs alone), and `changelog.md` (one entry per commit **in the corresponding
code repo**; code-repo git = the *what*, changelog = the *why*). Wiki edits
live in the wiki repo's own git history, not here.

**Hub-and-spoke** — the hub document of each `executor/` folder is always named
**`primary.md`**. Keep it **short** (≤ ~250–300 lines): overview, cross-cutting
invariants, glossary, TOC. **Sub-specs** sit beside it, one concern each
(~300–500 lines), keeping docs context-cheap for AI and edits localized. (No
doc may exceed **1000 lines** — split it.)

**Living-spec discipline (while coding):**

- After each task, reconcile the relevant sub-spec with what you built —
  resolve "Open" markers, fix divergences; touch the executor `primary.md`
  only for cross-cutting changes.
- **When the user lands a commit, ALWAYS add the matching `changelog.md`
  entry before considering the work done.** See *Commit + changelog
  convention* below for the entry shape and verification requirement.
- A spec may say "Open" and may change — a short, honest, current spec beats
  a long speculative one.
- Holistic consistency pass at milestones.

**Commit + changelog convention:**

- Code-repo git commits SHALL be **title-only** — a single concise
  summary line, no body. The diff is the authoritative *what*.
- The corresponding `wiki/<domain>/changelog.md` entry SHALL contain
  a brief *what* and the *why*. Date + title mirror the code-repo
  commit (`code-repo git = the pointer; changelog = the narrative`).
- **Before writing a changelog entry, you SHALL verify it against
  the actual diff** (`git show <hash>` in the code repo), not your
  memory of the change.
- Pending entries (`<!-- pending commit -->`) get written ONLY when
  the next planned commit is in the **code repo**. Wiki-only edits
  earn no pending entries.

**Where to start** — `executor/` specs are a work in progress across every
domain. When a repo has substantial code but a poor/missing `executor/`, the
highest-value first move is to bring its `executor/primary.md` to an
**acceptable minimum** (overview + invariants + glossary + TOC), marking the
rest "Open." Acceptable-minimum first, depth later.

**Where content lives across designs / explorations / executor / Linear** —
the canonical disambiguation is in [`glossary.md`](glossary.md) "Where
content lives". The discriminator is clarity, not "architectural":
open architectural *questions* live in `explorations/`; settled
architectural *patterns* live in `executor/`; ratified change plans
(full content) live in `designs/`; workflow state (status / owner /
priority) lives in Linear.

**Design-specs (`designs/`)** — ratified design-specs live in
`wiki/<domain>/designs/<slug>.md` (per-domain) or `wiki/designs/<slug>.md`
(cross-cutting / tooling). A single fixed location per design; files do
NOT move between folders as status changes. **Linear is the authority on
status** (backlog / todo / doing / done). Designs are tracked as **Ops-team
issues tagged `design`**. A design **MAY** enter Linear at Draft (sitting in
**Backlog**) and **MUST** be in Linear once **Accepted** (moved to **Todo**);
see [`linear.md`](linear.md). **Create a design issue with its assignee
(default: me), state, and priority set** — a hook blocks a `design` create
that omits them — and **move it to In Progress when you start executing it**.
The focus
**cap-8** is a **personal WIP limit** — at most 8 issues assigned to you in a
*started* state — not a count of designs in "doing". Each design file MUST carry
a status stamp; `Accepted` maturity requires `Pass ≥ 1`, and an Accepted
design's stamp MUST carry its `· Linear: <id>` (all enforced by
[`tests/test_doc_health.py`](tests/test_doc_health.py)). On completion,
the design's durable distillate updates `executor/primary.md` (or a
sub-spec); the `designs/<slug>` file is deleted. **Because designs are
ephemeral — deleted on completion — NOTHING SHALL link to a design** (any
markdown link to a `designs/` file rots into a dangler the moment that design
is deleted); reference a design by name in prose instead. Links are for
durable targets (`executor/`, code, external refs). The sole exception is
[`DESIGN_INDEX.md`](DESIGN_INDEX.md), the aggregator that indexes every
design by definition. Per-domain `findings.md`
registers are legacy and SHALL NOT be created in new domains — items
become Linear issues (if actionable work), become `explorations/`
entries (if there's no clarity yet), or update `executor/primary.md`
(if they're durable facts about the domain). Full convention in
[`designs-process.md`](designs-process.md); Linear interface in
[`linear.md`](linear.md);
live aggregated view in [`DESIGN_INDEX.md`](DESIGN_INDEX.md).

**Implementation gate** — a design SHALL NOT begin implementation
(code-repo edits matching its scope) until **every spoke** of the
design — `primary.md` and all sub-specs in its folder — is at
`Accepted` maturity with `Pass ≥ 1`. The hub-and-spoke pattern
explicitly permits hub > spoke maturity during drafting (e.g. an
Accepted `primary.md` with Draft sub-specs while individual sub-specs
catch up — the doc-level *floor* rule applies within a doc, not
across the hub-spoke relationship); the implementation gate is the
moment everything must converge. Rationale: writing code against a
Draft spec is the antipattern this convention exists to prevent.

**Write boundary** — code repos are authoritative for the *what*; `wiki/` is the
home for *why* + specs. Confirm before editing code repos' non-wiki files when
the task is documentation.

**Standalone READMEs** — a repo's `README.md` MUST stand alone for a human and
SHALL NOT reference the wiki. Exempt: the wiki's own `README.md` and a repo's
`CLAUDE.md` (Claude-facing — it may point to the wiki).

**Authoring** — capture *why* + design intent, not a restatement of code; pin
volatile specifics with `file:line`. Update the one canonical doc, don't
duplicate; delete what's wrong. Open each doc with a one-line "what this is"
for cheap recall.

**Sema-typed JSON files** — on-disk JSON instances of a Sema type SHALL
be named `<sema-type-name>.json`, where `<sema-type-name>` is the Sema
`TypeName` verbatim with dots preserved (e.g. `g.node.gt.json`,
`weather.channel.json`, `synced.readings.bundle.json`). NOT
`g_node_gt.json` (Python-style transformation) and NOT `g_node.json`
(half-snake legacy). The dot↔underscore transformation belongs at the
code boundary only — Python module names for the same type stay
snake-cased per Python convention (`g_node_gt.py`).
