# GridWorks — working conventions for Claude

Status: Draft · Pass 0 · Updated 2026-06-10

> Canonical at `wiki/GridWorks_CLAUDE.md`; symlink setup in
> [`README.md`](README.md#setup). Paths below are relative to the umbrella dir
> (parent of `wiki/` + the sibling code repos: `gridworks-base`,
> `gridworks-scada`, `sema`, …). The wiki holds the
> durable thinking and the **rebuild specifications** for each domain — start
> at [`wiki/README.md`](wiki/README.md) to find anything (domain map +
> getting-started/how-to). Coordination before editing is under Multi-session.

## Bearings (held at every altitude)

True in every session, whatever the Focus. One line each; the full text
lives at the pointer — don't restate it here, keep this block short.

- **The ambition:** a codebase that carries the vision by next winter
  (2026–27); 6 → 20 → 100 homes; none of it about expected outcome or
  accruing money or power. Full statement + the clear-and-present gates:
  [`wiki/vision/primary.md`](wiki/vision/primary.md) "The ambition".
- **Clear and present:** launch the **MarketMaker** and **Sema** before the
  next heating season; **teammates' gates first** — the flexible loads
  (thermal storage, SCADA, FLO) are the ground floor of everything.
- **Operating stance:** align to the ambition; push back when the focus runs
  too small; plain working prose — the deep river runs underneath, unquoted.
  See [`wiki/vision/claude/primary.md`](wiki/vision/claude/primary.md).
- **Session mix:** gate-work · larger-picture · outside world — pick the
  lane consciously at session open, with the Focus ask.

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

## Engineering maxims

- **If it flaps, skip the acks** — never report on a comm path with messages that demand acks on that path.
- **No phantom references** — never cite a task number, id, or handle the user can't open and see verbatim. Ephemeral session task-list numbers (`#11`, `#14`) are phantom: they mean nothing to the user and vanish with the session. Point only at durable, openable things — file paths, real Linear ids, commit hashes.

## Experiment-Driven Design (EDD) — the verification bar

**Experiment-Driven Design** is how we reach confidence — the evolution of
test-driven design. Where TDD writes an in-process test first, EDD runs an
**experiment in close-to-real-world conditions** — a real broker, real
timing (optionally sped up) — and lets that experiment be what verifies the
design. Confidence comes first from experiments, not from code analysis and
not from in-process unit tests. In-code tests are necessary, not sufficient:
they share a backdoor transport and a wall clock, and they go green while
gating real-world behavior stays invisible (the 2026-06-09 routing-key bug
`ScadaLiveTest` could not see; the ~15-minute broker-access blackhole no unit
test would catch). A spec reaches **`Verified`** only when an experiment
tests it against reality — the `experiments` entry in the
`Draft → Accepted → Verified` ladder. Keep the harness as a re-runnable
reproducer (it is the evidence behind the stamp); distill findings into
scoped Verified claims, `Reviewed` pointing at the experiment. Lineage:
Karan's verify ethic — build the experiment before calling a design
verified. The framework and conventions live in the simulated-test-environment
design (`wiki/gridworks-scada/`, experimentation-tools spoke).

**When starting a design, use EDD when appropriate** — the
capture → refactor → re-orient working rhythm is in
[`working-with-llms.md`](working-with-llms.md#the-edd-working-rhythm--capture-refactor-re-orient).

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

**Reflect on labels on *every* issue create — not from memory.** I call
`list_issue_labels` (Ops) each time and tag across the **relevant axes** — at
minimum a **component/domain** tag *and* a **work-kind** tag, not just one. A
`design` also gets its component (`gwbase` / `scada` / `ltn` / …); a `nit` also
gets component + work-kind (`testing` / `ci-cd` / …). Tagging on a single axis
(e.g. just `design`) is the defect this rule exists to prevent.

**No issue-to-issue relations.** I **SHALL NOT** add Linear issue relations —
not `blocks`/`blockedBy`, not `relatedTo`, not `duplicateOf`, nor any other
issue-to-issue link — via the MCP or otherwise. These links proliferate and
tangle the graph; the human curates relations by hand. I MAY *remove* a
relation when asked. Dependencies and context belong in the issue **description
prose** (e.g. "blocked from merge until gridworks-base 0.5.x publishes"), not in
a relation edge.

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
sub-spec); the `designs/<slug>` file is deleted. **The same completion step
SHALL finalize the Linear issue:** (1) **strip the now-dangling design
hyperlink** from the issue description (the file is gone — the link would rot,
per the no-links rule below), (2) **add a short final-writeup comment** — what
shipped, where the distillate now lives (`executor/…`), and any carried-forward
caveat (e.g. an interim hack's revert condition) — so the issue stays the
durable workflow record after the file is gone, and (3) move it to **Done**.
**Because designs are
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

**Voice** — wiki prose is Jessica's voice: plain sentences she can align
to. DO NOT use the AI-cadence drumroll — an em-dash setup resolved by a
punchy verdict fragment ("there are only two honest options — X, or Y.
No incremental third path."). Same family, also banned: ", full stop",
"— X edition", one-fragment verdict sentences, antithesis flourishes
("saves bytes, never trust"). Say the thing as an ordinary sentence.
Her verbatim phrases stay verbatim.

**Sema-typed JSON files** — on-disk JSON instances of a Sema type SHALL
be named `<sema-type-name>.json`, where `<sema-type-name>` is the Sema
`TypeName` verbatim with dots preserved (e.g. `g.node.gt.json`,
`weather.channel.json`, `synced.readings.bundle.json`). NOT
`g_node_gt.json` (Python-style transformation) and NOT `g_node.json`
(half-snake legacy). The dot↔underscore transformation belongs at the
code boundary only — Python module names for the same type stay
snake-cased per Python convention (`g_node_gt.py`).
