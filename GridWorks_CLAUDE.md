# GridWorks — working conventions for Claude

> Canonical umbrella `CLAUDE.md` (source of truth: `wiki/GridWorks_CLAUDE.md`;
> machine setup / symlink in [`README.md`](README.md#setup)). Paths below are
> relative to the umbrella dir — the parent of `wiki/` and the sibling code repos.

This directory holds the GridWorks system: sibling code repos
(`gridworks-base`, `gridworks-scada`, `gridworks-marketmaker`, `sema`, …)
plus a `wiki/` that holds the durable thinking and the **rebuild
specifications** for each domain.

Before writing any code, analyze the current code/module and produce a plan covering: files affected, dependencies, risk level of each change, and execution order

Git merge rules: * *Default rule: never delete code or files in a merge.* If either side has content the other lacks, KEEP it. The only deletions allowed are ones BOTH sides explicitly made via real commits — and even then, surface them for confirmation first.

If anything is suspicious, `git merge --abort` and re-resolve. Never seal a merge whose deletions you cannot explain.
* **Tag pre-merge state on risky merges:** `git tag pre-merge-$(date +%Y%m%d-%H%M)` so recovery is intentional, not luck.
* **Never trust the merge commit message — only trust the diff.** Past incidents had messages like "keeping research additions" that did the opposite.

## Documentation lookup

The wiki is the canonical project reference. To find anything — a domain, a
design, a term — **start at [`wiki/README.md`](wiki/README.md)**, the index
(domain map + getting-started/how-to). Coordination before editing is in
Multi-session below.

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

Authority rises with a domain's maturity stamp (`Draft → Accepted →
Verified`) — the stamp is the dial (defined under Status stamps below).

## Status stamps

Every non-trivial doc carries a one-line stamp; `##` sections carry their own
where they diverge (not deeper). Applies to `research/` and `executor/`:

`Status: <maturity> · Pass <n> · Updated <date>[ · Reviewed <date>@<commit>]`

- **Maturity** `Draft → Accepted → Verified` — `Verified` = validated against
  reality (code, tests, or experiments; the `Reviewed` field records which).
  Sets authority (Source precedence). Unlike ADRs, `Accepted` docs stay
  **living** — kept current by freshness, not frozen.
- **Pass `n`** — count of meaningful human–LLM back-and-forth passes; `Pass 0` =
  Claude-solo, unreviewed. **Increments only when the user asks** (or I prompt
  and they agree), per `##` section.
- **Freshness** — `Updated` = last substantive edit (≈ commit date); `Reviewed`
  = last checked against code/tests, with the commit. A `Verified`-but-stale
  stamp means re-verify before relying, then bump it.

## Weight signals

What the user signals about how much a statement counts. The **weight ladder**:

- **musing** → low weight; not a decision; don't record.
- **workshop** → serious candidate; engage critically and refine (a pass); not
  locked yet.
- **canonize** → durable; I write it to the wiki.

Two **record ops**:

- **override** → act against the wiki this once; I flag the divergence.
- **retract** → undo a prior canon.

I **proactively ask to canonize** at real decision points (never on
musings/routine); if I can't tell a decision from a musing, I ask.

## Multi-session coordination — `active-work.md`

Several Claude sessions edit the GridWorks repos at the same time. **Before you
edit anything, read [`wiki/active-work.md`](wiki/active-work.md), then:**

- **Start from a clean tree.** If `git status` shows changes you don't
  recognize, stop and raise it — do not edit or regenerate over foreign WIP.
- **Claim your area** — add/update a row (your session label, repo/domain, the
  path globs you'll touch); keep scope tight and mark it `done`/`paused` when
  finished.
- If your work would expand into **another active session's** claimed area,
  **stop and raise it** instead of editing across the boundary.
- **Stage only your own paths** when committing — never `git add -A` while other
  sessions are live.

## Wiki essentials (the wiki's authoring conventions)

**Structure** — each top-level `wiki/<domain>/` is a service/mechanism/design
area. Within a domain: `research/` (pre-spec notes, not normative), `executor/`
(the **faithful-rebuild spec** — complete enough to rebuild the domain from the
docs alone), and `changelog.md` (one entry per commit; date + one-line title
mirror the actual git commit; git = the *what*, changelog = the *why*).

**Hub-and-spoke** — the hub document of each `executor/` folder is always named
**`primary.md`**. Keep it **short** (≤ ~250–300 lines): overview, cross-cutting
invariants, glossary, TOC. **Sub-specs** sit beside it, one concern each
(~300–500 lines), keeping docs context-cheap for AI and edits localized. (No
doc may exceed **1000 lines** — split it.)

**Living-spec discipline (while coding)** — (1) after each task, reconcile the
relevant sub-spec with what you built (resolve "Open" markers, fix divergences;
touch the executor `primary.md` only for cross-cutting changes); (2) per commit, add a
changelog entry; (3) the spec may say "Open" and may change — a short, honest,
current spec beats a long speculative one; (4) holistic consistency pass at
milestones. A spec that drifts from code is worse than none.

**Where to start** — `executor/` specs are a work in progress across every
domain. When a repo has substantial code but a poor/missing `executor/`, the
highest-value first move is to bring its `executor/primary.md` to an
**acceptable minimum** (overview + invariants + glossary + TOC), marking the
rest "Open." Acceptable-minimum first, depth later.

**Write boundary** — code repos are authoritative for the *what*; `wiki/` is the
home for *why* + specs. Confirm before editing code repos' non-wiki files when
the task is documentation.

**Standalone READMEs** — a repo's `README.md` MUST stand alone for a human and
**SHALL NOT reference the wiki**: the wiki is a supportive wrapper, never a
prerequisite to using the repo. Put any needed architecture orientation *inline*
in the README. Exempt: the wiki's own `README.md`, and a repo's `CLAUDE.md`
(Claude-facing — it MAY point to the wiki).

**Authoring** — capture *why* + design intent, not a restatement of code; pin
volatile specifics with `file:line`. Update the one canonical doc, don't
duplicate; delete what's wrong. Mark provenance/freshness
(`verified`/`inferred`/`told`); open each doc with a one-line "what this is" for
cheap recall.
