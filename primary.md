# GridWorks Wiki — Purpose & Conventions

This wiki holds the **durable thinking** and the **rebuild specifications**
for the GridWorks system. Code lives in the sibling repos
(`gridworks-base`, `gridworks-scada`, `gridworks-marketmaker`, `sema`, …);
this wiki holds the *why*, the *design intent*, and the normative specs that
those repos are built to satisfy.

This is the wiki's own primary document — start here.

> **Launch from the GridWorks umbrella directory** (the parent that holds all
> the repos + this `wiki/`), not from inside a single repo — that is what loads
> the shared project memory and makes this wiki + `active-work.md` reachable.
>
> **Before you edit anything (multiple agents run at once):** Jessica typically
> has 2–4 Claude sessions active across the GridWorks repos. Read
> [`active-work.md`](active-work.md) first, **claim your edit area**, and check
> for overlap with another session. If your work would expand into an area
> another active session has claimed, **stop and raise it to Jessica** rather
> than editing across the boundary. Entry points: this file (index +
> conventions), [`active-work.md`](active-work.md) (who's editing what),
> [`glossary.md`](glossary.md) (vocabulary).

## Domains

Each top-level folder is a **domain** — a service, mechanism, or design
area. Current domains:

| Domain | What it is |
| --- | --- |
| [`gridworks-base/`](gridworks-base/) | The rabbit-transport actor framework + sema codec boundary |
| [`gridworks-proactor/`](gridworks-proactor/) | The MQTT-native "live actor" + monitored-communication infra under the scada (first-pass spec) |
| [`ear/`](ear/) | The universal audit tap / fundamental persistence mechanism |
| [`rmqbot/`](rmqbot/) | The deployed RabbitMQ/MQTT broker: hosting, TLS/certs, ops |
| [`gridworks-fleet-index-service/`](gridworks-fleet-index-service/) | FIS — the connection-authority (mTLS + instance authorization) |
| [`gridworks-scada/`](gridworks-scada/) | The residential heat-pump SCADA — legacy cleanup in discovery (see its `PROCESS.md`) |
| [`heating-system-design/`](heating-system-design/) | Store-under-floor + heating-system engineering & economics |

Cross-cutting: [`glossary.md`](glossary.md) holds the GridWorks-wide informal
vocabulary and legacy→current naming canon (e.g. `atn`→LTN, `ASL`→Sema),
deferring to Sema for formal types.

## Folder structure within a domain

```
<domain>/
  PROCESS.md     (recommended) how to work this domain — read before a session
  research/      pre-spec working notes, brainstorming, open questions
  executor/      the faithful-rebuild specification (see below)
  changelog.md   reverse-chronological WHY, one entry per commit
```

- **`PROCESS.md`** *(recommended, especially for legacy-cleanup domains)* — the
  domain's operating procedure: how a session picks work, what it produces, the
  per-session protocol. Open it first so a discovery/cleanup session is
  reminded to **converge before drafting** (see the research→executor workflow
  above) and to **claim its area** in [`active-work.md`](active-work.md).
  `gridworks-scada/PROCESS.md` is the worked example.
- **`research/`** — exploration. Not normative. Where a design is still
  converging, where we capture problem statements and partial conclusions.
- **`executor/`** — the **faithful-rebuild spec**: intended to be complete
  enough that someone (or Claude) could rebuild the entire domain, with all
  its intended features, *from these docs alone*. The `executor/` folder is
  the buildable contract; `research/` graduates into it once it converges.
- **`changelog.md`** — one entry per commit. The **date and one-line title
  mirror the actual git commit** (so the two cross-reference); git holds the
  *what* (the diff), the changelog holds the *why*. Include the commit hash
  / tag once the commit exists.

## Hub-and-spoke: `primary.md` + sub-specs

Documents are kept **context-friendly for AI** (tokens are precious) and
**localized for editing** (less drift). So:

- The **primary document is always named `primary.md`** — both this wiki
  root and each `executor/` folder. Keep it **short** (target ≤ ~250–300
  lines): the architecture overview, the cross-cutting invariants, a
  key-terms glossary, and a **table of contents pointing to the sub-specs**.
  An AI should be able to hold `primary.md` in context cheaply and load only
  the one sub-spec it needs.
- **Sub-specs** sit beside `primary.md`, each owning one concern
  (target ≤ ~400–500 lines). Aim for ~4–6 per domain, not 15 — over-
  fragmentation is its own navigation cost.
- The primary owns the *cross-cutting* story (e.g. a boundary that spans two
  sub-specs); the sub-specs own depth.

## Converging research → executor (recommended workflow)

A spec is only as good as the thinking behind it. Before promoting `research/`
into an `executor/` sub-spec, **stress-test the design until shared
understanding is reached** — don't draft a spec around unresolved branches.

The recommended loop (Claude Code users):

1. Work in **plan mode** and run the **`/grill-me`** skill — it interviews you
   relentlessly about the design, resolving each branch of the decision tree
   rather than letting ambiguity slide into the spec.
2. Run the resulting proposal **past a fresh agent**, and/or have an agent run
   **experiments** to validate it.
3. Iterate (typically **3–5 cycles**) until the decision tree is resolved.
4. **Only then** draft the `executor/` spec, and start coding from it.

This is the front half of the same principle as the living-spec discipline
below: articulation pressure surfaces design flaws before code. `/grill-me` is
tooling that applies that pressure deliberately; the workflow stands without it,
but it makes the convergence faster and more honest.

## The living-spec discipline

A spec that drifts from the code is **worse than none** — it gives false
confidence. So the spec is a *living contract*, not a one-time artifact:

1. **After each implementation task**, reconcile the **relevant sub-spec
   section** with what was actually built — resolve "Open" markers, fix any
   divergence between intent and reality. Touch `primary.md` only if the
   change is cross-cutting (an invariant, a new sub-spec, the TOC).
2. **At milestones**, do a holistic consistency pass across the domain's
   docs.
3. **Per commit**, add the changelog entry (date + title mirroring the
   commit; the commit holds the *what*).
4. **The spec is allowed to say "Open," and allowed to change.** Mark
   anything unresolved or unbuilt as "Open" rather than writing an
   exhaustive tome that chases every detail. A short, honest, current spec
   beats a long speculative one — the spec is a living artifact, not a
   monument.

## Current status & where to start

Right now the `executor/` specs are **a work in progress across every
domain** — most are partial or absent even where mature code already
exists. Do not treat any `executor/` folder as complete or authoritative
yet; that is the work in flight.

When you start a session on a repo:

- If the repo has substantial code but a **poor or missing `executor/`**,
  the highest-value first move is to bring its `executor/primary.md` to an
  **acceptable minimum** — the architecture overview, the cross-cutting
  invariants, a glossary, and a TOC — rather than perfecting one corner.
- **"Acceptable minimum" first, depth later.** Capture the load-bearing
  structure, point to sub-specs that may not exist yet, and mark everything
  else "Open." A thin-but-true `primary.md` is the goal for a first pass.

## Agent project memory vs. the wiki

An AI agent (e.g. Claude) has a private, **per-machine** project memory that
auto-loads each session. It is *not* shared with collaborators and is *not* the
wiki — a teammate running an agent on their own machine gets a different,
empty memory. Therefore **the wiki is the only shared source of truth**, and a
new durable fact is routed by:

1. **Needed by a collaborator or another agent?** (terminology, design,
   architecture) → **wiki only**, single-sourced. Cross-repo vocabulary →
   `glossary.md`; project facts → the domain's `research/`.
2. **About how the agent should work, not what the project is?** (commit
   handling, review style) → the agent's **memory only**.
3. **Just a breadcrumb to find the wiki fast?** → a **pointer** in memory
   (`"truth lives in wiki/<domain>; start at primary.md"`), never a copy.

Memory routes to the wiki; it never holds the only — or a second — copy of a
collaboration fact.

## Authoring disciplines

Beyond the living-spec discipline above (which guards against drift):

- **Don't restate the code or a repo's `CLAUDE.md`.** Capture *why*, design
  intent, and non-obvious behavior; pin volatile specifics with `file:line`
  pointers rather than transcribing code that will drift.
- **Update, don't duplicate; delete what's wrong.** Correct the one canonical
  doc; check for an existing doc before creating a new one.
- **Mark provenance & freshness.** Behavioral claims carry `verified` /
  `inferred` / `told`; a reader re-verifies before relying.
- **Cheap recall.** Every doc opens with a one-line "what this is" so an agent
  can route without reading the whole file.

## Why this is worth it

- **Articulation pressure surfaces design flaws before code.** Forcing a
  normative account is a design review; "hard to specify cleanly" is a code
  smell caught early.
- **Invariants written down become testable contracts.**
- **Reconstructibility is part of the GridWorks product** (the whole sema
  premise — cross-language faithfulness, simulators, eventual rewrites), not
  documentation overhead.

The payoff is conditional on the living-spec discipline above. Keep it in
sync or it becomes a liability.
