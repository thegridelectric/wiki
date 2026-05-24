# GridWorks — working conventions for Claude

> Canonical at `wiki/GridWorks_CLAUDE.md`; symlink setup in
> [`README.md`](README.md#setup). Paths below are relative to the umbrella dir
> (parent of `wiki/` + the sibling code repos: `gridworks-base`,
> `gridworks-scada`, `gridworks-marketmaker`, `sema`, …). The wiki holds the
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

## Status stamps

Every non-trivial doc carries a one-line stamp; `##` sections carry their own
where they diverge (not deeper). Applies to `research/` and `executor/`:

`Status: <maturity> · Pass <n> · Updated <date>[ · Reviewed <date>@<commit>]`

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

## Sub-CLAUDE.md protocols

- **Adding or modifying a sema word** → suggest the user run
  `/make-sema-word`. Before any edit, **Read `sema/CLAUDE.md`** and follow
  its protocol verbatim.

## Commit suggestions

Human does all `git commit`s; I suggest at logical units (path-scoped
`git add` + a one-line message) and never `git add -A` while other sessions
may be live (mirror your active-claims Scope). For Karan-style autonomy
(Claude doing commits/merges with merge-safety guardrails) see
`working-with-llms.md` "Karan's commit rules" — reference, not active.

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

**Living-spec discipline (while coding):**

- After each task, reconcile the relevant sub-spec with what you built —
  resolve "Open" markers, fix divergences; touch the executor `primary.md`
  only for cross-cutting changes.
- **When the user lands a commit, ALWAYS add the matching `changelog.md`
  entry before considering the work done.** Date + title mirror the commit;
  body is the *why*. See `wiki/sema/changelog.md` for register.
- A spec may say "Open" and may change — a short, honest, current spec beats
  a long speculative one.
- Holistic consistency pass at milestones.

**Where to start** — `executor/` specs are a work in progress across every
domain. When a repo has substantial code but a poor/missing `executor/`, the
highest-value first move is to bring its `executor/primary.md` to an
**acceptable minimum** (overview + invariants + glossary + TOC), marking the
rest "Open." Acceptable-minimum first, depth later.

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
