# Working with LLMs — guiding principles

> For humans (Jessica + collaborators) to understand *how* we work with Claude on
> GridWorks and *why* the wiki is built the way it is. This is the **rationale**;
> the operative rules Claude follows live in
> [`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md). Written as Claude's own honest
> self-reflection on its operation — kept here so the reasoning is shared, not
> tribal.

## How Claude actually works (the honest mechanism)

- **There is no attention "weight" knob.** Claude can't be told to weight one
  source 1.4×; attention is a property of the model's forward pass, not a
  setting. "Pay more attention to the wiki" is *not* achieved by tuning weights.
- **What's in context wins.** The reliable levers are: (1) *what gets loaded* —
  `CLAUDE.md` is carried every turn, the wiki enters context only when read; and
  (2) *explicit rules Claude executes as logic* when sources conflict. Get the
  authoritative material in-context and give clear precedence rules, and
  behavior follows.
- **`CLAUDE.md` is the highest-priority standing input.** Its instructions shape
  behavior reliably because Claude *follows* them — not because they re-weight
  tokens.
- **Honest caveat:** instructions strongly shape but do not *deterministically
  guarantee* what Claude attends to. The hard guarantees come from what is
  loaded and from rules expressible as logic.

## Failure modes we design against

- **Anchoring on its own prior output.** Claude tends to build on what it has
  already said this session, which can compound an early wrong assumption. We
  treat Claude's own earlier statements as the **lowest**-authority source — it
  re-derives from the record rather than citing itself.
- **Casual musing treated as a decision.** Humans think out loud; not every
  sentence is canon. We use explicit signals (below) to separate decisions from
  musings.
- **Unverified research treated as fact.** Web results and one-off code reads
  carry provenance and must be verified before they are canonized.
- **Staleness.** A doc that has drifted from reality is worse than none. We fight
  it with single-sourcing, freshness/maturity stamps, and (planned) automated
  detection.

## How we steer it

**Source precedence.** When sources conflict, Claude resolves them by an explicit
hierarchy in [`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md) ("Source precedence").
In short: *your explicit instruction now* > *verified wiki specs + code/tests* >
*converging/inferred wiki research* > *ad-hoc research* > *Claude's own earlier
statements*.

**The dial is the maturity stamp.** A doc/section carries a status stamp —
maturity (`Draft → Accepted → Verified`), pass count (`Pass N`), and freshness
(`Updated` / `Reviewed`); the operative definition is in
[`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md) ("Status stamps"). A domain's
authority rises as its maturity climbs; to make Claude trust the wiki more for a
domain, mark it `Verified`; to demote a claim, mark it `Draft`. As the wiki earns
semantic clarity you flip stamps and it *automatically* climbs the precedence —
no separate config. **This is how "weight the wiki more and more over time"
actually happens.** (Lineage: ADR maturity + epistemic-status headers +
docs-as-code freshness; the pass count is ours — see Prior art below.)

**In-conversation signaling.** Lightweight verbs to tell Claude how much a
statement should weigh (the operative list lives in
[`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md)):

- **canonize** ("for the record", "ratify") → durable; Claude writes it into the
  wiki.
- **workshop** ("pressure-test", "float") → a serious candidate: engage
  critically, refine it together (a pass); not locked yet. *This is the mode
  most design happens in.*
- **musing** ("thinking out loud", "scratch") → low weight, not a decision.
- **override** ("do Y despite the wiki") → your call wins now; Claude flags the
  divergence and offers to reconcile.
- **retract** ("scratch that") → undo a prior canon.

Claude also **proactively asks to canonize** at genuine decision points (not
musings/routine), and asks when it can't tell a decision from a musing — so
durable choices get captured while fresh instead of slipping by.

## Converging research → executor (the design loop)

A spec is only as good as the thinking behind it. Before promoting `research/`
into an `executor/` sub-spec, stress-test the design until shared understanding
is reached — don't draft around unresolved branches. The loop (Claude Code):

1. Work in **plan mode** and run **`/grill-me`** — it interviews you relentlessly
   about the design, resolving each branch of the decision tree.
2. Run the proposal **past a fresh agent**, and/or have an agent run
   **experiments** to validate it.
3. Iterate (typically 3–5 cycles) until the tree is resolved.
4. **Only then** draft the `executor/` spec and start coding from it.

Articulation pressure surfaces design flaws before code; "hard to specify
cleanly" is a code smell caught early.

## Where new facts go: memory vs. the wiki

An agent's project memory is **per-machine and private** — a teammate's agent
has a different, empty memory. So a new durable fact is routed:

1. **Needed by a collaborator or another agent?** (terminology, design,
   architecture) → **wiki only**, single-sourced (cross-repo vocabulary →
   `glossary.md`; project facts → the domain's `research/`).
2. **About how the agent should work, not what the project is?** → the agent's
   **memory only**.
3. **Just a breadcrumb to find the wiki fast?** → a **pointer** in memory, never
   a copy.

Memory routes to the wiki; it never holds the only — or a second — copy of a
collaboration fact.

## Looking for trouble — the coherence crawl

> Status: **Draft · Pass 0** · Updated 2026-05-22 — *the practice itself is
> unproven; this is Claude's solo first draft, not yet validated by a real walk
> or reviewed in a joint pass.*

A continuous patrol that hunts **bugs and semantic misalignments** — places
where the same concept is named, defined, or used inconsistently across a
boundary — and fixes them. It is **not** a one-shot review of a file; it is a
route that is walked repeatedly and resumed across sessions.

**Two modes**

- **Area walk** — take one module / repo / domain; check its internal
  consistency and its agreement with the contracts it declares.
- **Thread walk** (cross-cutting) — pick a seed and follow it everywhere it
  appears.

**The path is edges, not files.** Walk the graph along the *seams* where two
components must agree: a concept/term, a Sema type, a message's
producer→consumer, an import edge, a spec↔code pair. Semantic misalignment
hides at seams.

**What counts as trouble**

- *term drift* — same thing, two names (`atn`/LTN); or one name, two meanings
- *definition disagreement* — a type/field/invariant defined differently across
  sema / gwbase / a service / the wiki
- *spec↔code drift* — the executor spec says X, the code does Y
- *boundary mismatch* — a message's producer and consumer disagree on its shape
  or meaning
- *stale reference* — a link / `file:line` / pointer that no longer resolves
- *broken invariant* — asserted here, violated there

**Per hit:** record the seed, the disagreeing locations, the kind and severity;
**fix if safe and in scope**; otherwise log it; if it falls in another session's
claimed area, hand it off via `active-work.md`.

**Continuity (the frontier).** Keep a small ledger — seeds walked, seeds queued,
open hits — so the patrol *resumes* instead of restarting. It is a route, not a
report.

**Open (Draft):**

- Where the frontier ledger + cross-cutting findings live (a dedicated tracker
  vs. per-domain `findings.md`).
- Whether "looking for trouble" stays the name.
- Validate by running one real walk before promoting past Draft.

## Why this matters

The wiki is the **only shared source of truth** — the agent's memory isn't
shared, and the conversation is ephemeral. The more the wiki earns semantic
clarity and `verified` status, the more authority it carries, **by design**.
Concretely, the apparatus pays off because:

- **Articulation pressure surfaces design flaws before code** — forcing a
  normative account is a design review.
- **Invariants written down become testable contracts.**
- **Reconstructibility is part of the GridWorks product** (the sema premise —
  cross-language faithfulness, simulators, eventual rewrites), not overhead.

The payoff is conditional on keeping specs in sync (the living-spec discipline
in [`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md)) — a drifted spec is worse than
none.

## Repos stand alone; the wiki is a supportive wrapper

A repo's `README.md` must be **self-sufficient for a human** — it explains the
repo *inline* and **does not reference the wiki**. The wiki is a *supportive
wrapper*: it carries the larger context (the *why*, cross-repo design, rebuild
specs) for Claude and for deep design work, but someone using a repo should
never need to read the wiki to understand that repo. The operative rule and its
two exemptions — the wiki's own `README.md`, and a repo's `CLAUDE.md` (which is
Claude-facing and *may* point to the wiki) — are in
[`GridWorks_CLAUDE.md`](GridWorks_CLAUDE.md) under "Write boundary."

## Prior art & lineage — we're on a known path

These conventions aren't invented from scratch; most map to established
practice (validated by a 2026 survey of practitioner accounts). Worth knowing so
the approach reads as grounded, not bespoke.

**The core loop is spec-driven development (SDD)** — the proven high-gain
practice of 2025–26 ([Thoughtworks](https://www.thoughtworks.com/en-us/insights/blog/agile-engineering-practices/spec-driven-development-unpacking-2025-new-engineering-practices),
[Addy Osmani](https://addyosmani.com/blog/ai-coding-workflow/)): *specify → plan
→ implement → validate*. Our research → executor → code pipeline is an instance
of it, and `/grill-me` + a fresh validating agent is the widely-reported
"interview, then execute in a clean session" pattern. SDD's headline insight is
**ours exactly**: *it isn't about generating better code — it's about forcing
yourself to think clearly about what you actually want.* (At Anthropic, ~90% of
Claude Code is now written by Claude Code — these workflows are load-bearing,
not theoretical.)

**What we align with (others do this too):**

- **Lean carried context file** — the community caps `CLAUDE.md` well under a few
  hundred lines (some say <150); ours is ~120.
- **2–5 parallel agents** as the sweet spot, coordinated by a shared file —
  exactly our [`active-work.md`](active-work.md) layer. (`AGENTS.md` is the
  cross-tool variant of that shared file, but Claude Code only *auto-loads*
  `CLAUDE.md`.)
- **Freshness** via "last reviewed" stamps + git-commit dates + flag-stale review
  cycles ([docs-as-code](https://www.writethedocs.org/guide/docs-as-code/)); the
  field agrees "stale docs are worse than none."
- **Maturity markers** trace to Architecture Decision Records
  ([ADR](https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/adr-process.html):
  `Proposed/Accepted/Superseded`); the one-line **trust header** is the
  "epistemic status" convention ([Gwern](https://gwern.net/about), via Muflax /
  LessWrong / digital gardens).

**What's ours (ahead of the published practice):** the **pass count**
(human–LLM joint iterations); keeping specs **living + stamped** (most SDD
*discards* the spec once code exists); the **"looking for trouble" coherence
crawl**; and **source precedence + weight signals** (canonize / workshop /
musing). No published equivalents found.
