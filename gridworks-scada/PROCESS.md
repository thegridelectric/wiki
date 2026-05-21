# The SCADA Documentation & Cleanup Process

This is the operating procedure for the long-running effort to understand,
document, and clean up `gridworks-scada`. It is written so that any session
(me, a fresh Claude, or a human) can pick up where the last one left off and
make consistent, additive progress.

## The goal, restated

Two outputs, kept **deliberately separate** because they have different
half-lives and different readers:

1. **Description** — what the code *does today*, faithfully, with no
   editorializing. Lives in `research/components/`. This is the à-la-carte
   reference. It must be trustworthy: a reader should be able to act on it
   without re-reading the source.
2. **Findings** — what *should change*: clear bugs, smells, and improvement
   opportunities. Lives in `research/findings.md`. Opinionated by design.

Mixing the two is the failure mode to avoid. A description doc that editorializes
rots into a stale opinion blog; a findings list padded with description becomes
un-actionable. Keep description timeless and findings opinionated, in separate
files, cross-linked by ID.

A third, slower output — the **`executor/` rebuild spec** — is written only
once a subsystem's description has converged and its findings are resolved or
consciously deferred. Do not start it early.

## The three research artifacts (and keeping them in sync)

`research/` holds three *different* things with one clear owner each — they are
**not redundant**, so there is little to drift if each stays in its lane:

| Artifact | Owns | Size | Example |
|---|---|---|---|
| `components/*.md` | **Description** — what the code does today | — | `contract-handler.md` |
| `concerns/*.md` | **Design epics** — big cross-cutting questions / large refactors | **big** | remove/replace the proactor; modernize Sema |
| `findings.md` | **Actionable backlog** — specific bugs + small/medium cleanups | **small–med** | a typo, an inconsistent field, a dropped-state bug |

The split by *size* is deliberate: **big work is a concern; small work is a
finding.** A concern is a session (or many) of its own; a finding is something
you can knock out — often several at once — in a daily cleanup session.

**Will concerns and findings stay in sync?** They will *if they never copy each
other* — the only coupling is by ID/link:

- A finding tags its parent concern: `Concern: [[transport-and-links]]`. That
  backlink is the single source of truth for the relationship.
- A concern does **not** hand-maintain a list of its findings (that list would
  drift). Instead it says *"open findings: search `findings.md` for
  `Concern: [[this]]`."* Nothing to keep in sync but the tag.
- `findings.md` owns finding **status**; `concerns/` owns the **design
  narrative**. Neither restates the other.
- **Reconciliation checkpoint:** when a pass closes a finding or resolves a
  concern, update the *tag/link*, not a duplicated list. At milestones, grep
  `findings.md` by concern to confirm the backlog matches the narrative.

(`components/*.md` likewise only *links* finding IDs raised against it; it does
not restate them.)

## The unit of work: a discovery pass

A pass is scoped to **one component or one concern** — never "the whole repo."
Bounded scope is what keeps passes finishable and the quality high. Each pass:

1. **Pick a target** from `research/map.md` (lowest-coverage item that unblocks
   the most, or whatever the user steers toward).
2. **Read the source** for that target — the actual code, plus its tests (tests
   are the best evidence of intended behavior). Read callers when behavior
   depends on them.
3. **Write/refresh the description** in `research/components/<target>.md`:
   - WHAT it does, its responsibilities, its collaborators, its state.
   - Ground every non-trivial claim with a `file:line` reference.
   - Mark each behavioral claim's **provenance**: `verified` (traced in code or
     by a named test), `inferred` (read but not proven), or `told` (from the
     user / a design doc). Never present inferred behavior as verified.
4. **Append findings** to `research/findings.md` for anything wrong, fragile,
   confusing, or improvable — one entry per finding, with the conventions below.
5. **Update `research/map.md`**: bump the target's coverage status, note open
   questions, record the date.
6. **Add a `changelog.md` entry** describing the pass (WHY, mirrors the commit).
7. **Link** anything that touches a cross-cutting concern back to the relevant
   `research/concerns/*.md` file (and vice versa).

A pass that produces only findings (no description) or only description (no
findings) is fine — not every component is buggy, not every read is complete.

## Coverage tracking (`research/map.md`)

`map.md` is the source of truth for "what have we looked at." Every source file
or subsystem carries a status:

- `untouched` — not yet read.
- `mapped` — read enough to summarize its role; description stub exists.
- `documented` — description complete and grounded with refs.
- `verified` — description's behavioral claims checked against tests/callers.

Pick the next pass to maximize coverage of load-bearing code, not line count.

## Finding conventions (`research/findings.md`)

One entry per finding. Stable ID so descriptions and concerns can cite it.

```
### F-NNN — <one-line title>
- **Type:** bug | smell | cleanup | design-question | doc-gap
- **Severity:** high | med | low
- **Effort:** small | med | large
- **Location:** path:line (or subsystem)
- **Concern:** [[liveness-and-sla]] / — (link if it touches one)
- **What:** the problem, concretely.
- **Why it matters / fix idea:** optional.
- **Status:** open | deferred | fixed (commit) | wontfix (reason)
```

IDs are append-only and never reused. When a finding is fixed, mark it `fixed`
with the commit rather than deleting it — the register is also a history.
`findings.md` is grouped into **area subsections** (e.g. *contract_handler*,
*docs*) so a session can grab a localized batch.

**`Effort: large`** is the signal that something is really a **concern** (an
epic), not a finding — promote it to `concerns/` and leave the finding as a
pointer, or don't file it as a finding at all.

### Cleanup-session workflow

A "cleanup session" (good for one of Jessica's daily 2–4 parallel sessions) is
distinct from a discovery pass:

1. Pick a batch of `Effort: small` findings **within one area subsection** —
   localized edits keep the session finishable *and* minimize collision with
   other active sessions.
2. **Claim that area** in [`../active-work.md`](../active-work.md) before
   editing code.
3. Fix, then mark each finding `fixed` with the commit; do not delete it.
4. The tighter the area, the safer to run concurrently with other sessions.

## Description doc conventions (`research/components/`)

- One file per component; filename matches the thing
  (`contract-handler.md` for `actors/contract_handler.py`).
- Lead with a one-paragraph "what this is" so a reader can decide in 10 seconds
  whether this is the file they want.
- Prefer tables and short bullets over prose — optimized for à-la-carte gleaning
  by both humans and LLMs.
- Faithful to *current* behavior, including warts. Warts get a description
  (neutral) **and** a finding ID (opinionated). Do not "describe the fix you
  wish existed."
- Every component doc ends with a **Findings** section listing the F-NNN IDs
  raised against it, so the description and the cleanup backlog stay linked.

## When `executor/` work begins

Only when a subsystem's description is `verified`, its high-severity findings
are resolved or explicitly deferred, and the relevant concerns are decided.
The executor spec is the *target* design (possibly different from today's
code), written to the gridworks-base executor standard: language-agnostic,
invariant-first, with a faithful-reimplementation checklist.

## Per-session protocol

1. **Claim your area** in [`../active-work.md`](../active-work.md) and check for
   overlap with another active session (Jessica runs 2–4 at once). If your work
   would expand into another session's claimed area, stop and raise it.
2. Read `research/map.md` (coverage + open questions) and the tail of
   `research/findings.md`.
3. Confirm or take the next target — a **discovery pass** (map a component/
   concern) or a **cleanup session** (batch small findings in one area).
4. Run it (steps above).
5. Update `map.md`, `findings.md`, the component doc, and `changelog.md`.
6. **Do not run git commits** — Jessica handles those. Stage nothing; instead
   summarize the changes and suggest a commit message.
7. Update your `active-work.md` row (`paused`/`done`).

## Wiki-wide conventions

The **agent-memory-vs-wiki** routing rule and the **authoring disciplines**
(don't restate code, update-don't-duplicate, mark provenance/freshness, cheap
recall) live wiki-wide in [`../primary.md`](../primary.md). They apply here;
not repeated.

## Guardrails

- Stay grounded: cite `file:line`; mark provenance; never assert untraced
  behavior as fact.
- Stay bounded: one target per pass.
- Stay additive: append findings, bump coverage; don't silently rewrite history.
- Sema is **boundary infrastructure** (JSON contracts at process edges), not a
  runtime framework — keep that distinction when describing what is "Sema" vs.
  internal runtime. See `gridworks-scada/CLAUDE.md` and `sema/CLAUDE.md`.
- Existing in-repo docs are uneven (`CLAUDE.md` is current; some `docs/` are
  stale — see F-001). Treat them as evidence, not ground truth; verify.
