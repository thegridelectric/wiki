# GridWorks — working conventions for Claude

> **This is the canonical `CLAUDE.md` for the GridWorks _umbrella_ directory.**
> It is version-controlled here in the wiki repo as `GridWorks_CLAUDE.md`. Put it
> at the umbrella parent (the folder that holds `wiki/` and the sibling code
> repos) as `CLAUDE.md` — **symlink** it so it stays in sync:
> `ln -s wiki/GridWorks_CLAUDE.md CLAUDE.md` (or copy it). Paths below are
> relative to that umbrella dir. See [`README.md`](README.md#setup) for the
> folder layout.

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

When answering questions about a domain, design, component, or decision,
**start with the wiki** — it is the canonical project reference, curated for
efficient Claude lookups:

1. **[`wiki/README.md`](wiki/README.md)** — entry point (GitHub renders it on
   the repo home). The "Getting started / how-to" table covers the most common
   starting points; the domain map sits below it.
2. **[`wiki/primary.md`](wiki/primary.md)** — the wiki's purpose, structure, and
   process (hub-and-spoke, living-spec discipline, research→executor workflow,
   authoring rules). Condensed below.
3. **[`wiki/glossary.md`](wiki/glossary.md)** — cross-repo vocabulary and
   legacy→current naming (`atn`→LTN, `ASL`→Sema); defers to Sema for formal types.
4. **[`wiki/active-work.md`](wiki/active-work.md)** — who is editing what right
   now (see next).

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

## Wiki essentials (condensed from `wiki/primary.md`)

**Structure** — each top-level `wiki/<domain>/` is a service/mechanism/design
area. Within a domain: `research/` (pre-spec notes, not normative), `executor/`
(the **faithful-rebuild spec** — complete enough to rebuild the domain from the
docs alone), and `changelog.md` (one entry per commit; date + one-line title
mirror the actual git commit; git = the *what*, changelog = the *why*).

**Hub-and-spoke** — the primary document is always named **`primary.md`** (wiki
root and each `executor/`). Keep it **short** (≤ ~250–300 lines): overview,
cross-cutting invariants, glossary, TOC. **Sub-specs** sit beside it, one
concern each (~300–500 lines), keeping docs context-cheap for AI and edits
localized.

**Living-spec discipline (while coding)** — (1) after each task, reconcile the
relevant sub-spec with what you built (resolve "Open" markers, fix divergences;
touch `primary.md` only for cross-cutting changes); (2) per commit, add a
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
