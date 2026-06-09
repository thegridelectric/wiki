# designs-process — the `designs/` lifecycle

Status: Draft · Pass 0 · Updated 2026-05-26

> What this is: how design-specs live in the wiki across all domains.
> Companion: [`linear.md`](linear.md) for the Linear interface. Aggregated
> live view: [`DESIGN_INDEX.md`](DESIGN_INDEX.md).

## Where designs live

A design-spec lives in **one folder, never moved**:

- **Per-domain:** `wiki/<domain>/designs/<slug>.md` — for changes scoped to
  one domain (e.g., `wiki/gridworks-protocol/designs/gwproto-shrink.md`).
- **Cross-cutting / tooling / meta:** `wiki/designs/<slug>.md` — for
  multi-domain refactors or wiki/process tooling
  (e.g., `wiki/designs/linear-integration.md`).

**Owning-domain rule for cross-repo designs.** A design that touches
multiple repos lives in the domain that bears the most change (e.g.,
gwproto-shrink reshapes `gwproto`, with scada migration as downstream —
owned by `gridworks-protocol`).

## Folder shape

A design entry is either:

- **Single file** — `<slug>.md`, when the design fits ≤ ~500L.
- **Fractal subfolder** — `<slug>/primary.md` + sub-files, when the design
  needs more room. Same hub-and-spoke shape as `executor/`: `primary.md`
  ≤ 300L (overview + invariants + TOC), sub-files ~300-500L each,
  **1000L hard ceiling per file**.

### When a design grows past ~500L — just split

If a single design file is genuinely going to exceed ~500L, **split
into a fractal subfolder** (`<slug>/primary.md` + sub-files). That's
it.

A design legitimately contains everything about the change:
rationale, alternatives, decision tree, invariants, classification
matrices, sequencing, execution plan. All of it stays in the
design. For the canonical "what lives where" across designs vs
explorations vs executor vs Linear, see
[`glossary.md`](glossary.md) "Where content lives".

## Triage

Triage runs when **the human asks to capture something to the wiki**
(e.g., "let's write that down", "canonize this", "this belongs
somewhere"). It is NOT an automatic gate fired on every observation
or musing — most thoughts in conversation don't need to be captured.
The act of triage is the deliberate decision to keep an item.

Once triage is invoked, run this gate **before writing anything**:

1. **Is the problem itself clear?** Do we understand what we're being
   asked to address?
   - **No** → ask the person to clarify. Do not write a file yet.
   - **Yes** → continue.
2. **Is the solution direction clear?**
   - **No** → investigate it as an *exploration*.
   - **Yes** → write it up as a *design*.

When the output is "design" (clarity branch), Triage performs **both
acts together, at the same time**:

a. Create `wiki/<domain>/designs/<slug>.md` (or
   `wiki/<domain>/designs/<slug>/primary.md` for a fractal design)
   with `Status: Draft · Pass 0 · Updated <today>`. The `<slug>` is
   chosen here; this is the canonical name.
b. **Register the slug in `DESIGN_INDEX.md` under `## Drafts`**
   with the slug + a one-line topic description + the path. This
   makes the slug visible across sessions immediately and gives the
   bijection hook something to match against.

When the output is "exploration" (no-clarity branch):

a. Create `wiki/<domain>/explorations/<name>.md` (Status stamp
   per the convention).
b. Register the exploration in `DESIGN_INDEX.md` under `## Explorations`
   with name + one-line description + path.

Output of triage is **where to write + the corresponding INDEX
entry** — both done atomically. Or: nothing yet (back to the human
for clarification).

## Lifecycle

```
new ask / observation / problem
        │
        ▼ Triage  (problem clear? · solution clear?)
        │
   ┌────┴────────────────┐
   │                     │
   ▼                     ▼
explorations/          designs/
(no clarity yet)       (clarity; Linear tracks status; file stays put)
   │                     │
   │ /grill-me +         │ executes, ships
   │ /plan converges;    │
   │ clarity emerges     ▼
   │                  deleted from designs/;
   └──→ designs/      durable outcome → executor/primary.md;
                      Linear closes
```

**Linear is the authority on status.** The wiki holds the design
content in a single fixed location; lifecycle state (todo / doing /
done) lives in Linear.

## The cap-8

**A personal WIP limit: at most 8 issues assigned to *me* in a
`started` state (In Progress + In Review) at any time.** It is **not** a
count of designs in "doing" — the scarce resource is my attention, not a
design slot, so the cap spans all my issues (design and operational
alike). A focus discipline: it forces "what am I actually working on this
fortnight?" to be answerable. Warn at 7, stop at 8.

**Source of truth: Linear** — query `assignee = me AND state.type =
started`. The full definition (states, the "started = In Progress *or* In
Review" rule, the `precheck-cap-8.sh` hook) lives in
[`linear.md`](linear.md) "Cap-8 — a personal WIP limit".

## Linear interaction — the rules

[`linear.md`](linear.md) is the **authority on the Linear interface** — it
holds the workspace facts, status mapping, labels, port/resume recipes, and
the enforcement tooling. The handful of rules below are the normative core;
for anything more specific, that doc wins (this section defers to it
deliberately, so the Linear mechanics live in one place and don't drift
across two).

### Division of responsibility

- **Linear = organizing + cross-linking.** Title (the slug), status,
  owner, priority, labels, parent/child relationships, dates. Linear is
  where work is tracked, sorted, queried, and assigned.
- **Wiki = the details.** The design file at
  `wiki/<domain>/designs/<slug>.md` (or `<slug>/primary.md` for fractal
  designs) holds rationale, invariants, decisions, alternatives,
  classification tables — the "what we're going to do and why."
- **Shared between the two: the slug (the topic) and the link.** Linear
  knows the wiki path; the wiki knows the Linear issue ID. **No design
  content is mirrored** — Linear is not a copy of the wiki, nor vice versa.

### Hard rules

1. **A design = one Linear *issue* in the Ops team, carrying the `design`
   label.** Not a Project, not a Linear "epic" (the workspace uses
   neither). The slug ↔ issue is a **bijection**: every
   `wiki/<domain>/designs/<slug>.md` (or `<slug>/` folder) corresponds to
   exactly one `design`-tagged issue, and vice versa. The `<slug>` is
   canonical — the issue **title MUST normalize to the slug** (lowercase →
   non-alphanumeric runs → single hyphen → strip ends). No two designs with
   the same slug; no two issues for one slug. *(Maturity labels are not used
   — the design's `Status:` line is the sole maturity source; see
   [`linear.md`](linear.md) "Labels and tags".)*

2. **Linear → wiki link.** Every design issue body MUST carry the wiki path
   to its design (`wiki/<domain>/designs/<slug>.md` or the fractal-folder
   `primary.md`) while the design file is alive. The
   `wiki/tools/link-design-linear.sh` helper emits the exact line to paste.

3. **Wiki → Linear link.** Every wiki design's `Status:` line MUST carry
   the Linear issue ID (`· Linear: OPS-NNN`) once the issue exists.
   Enforced for Accepted/Verified designs by
   `tests/test_doc_health.py::test_accepted_designs_have_linear_id`.

4. **Cap-8 is personal WIP, not designs-in-doing** — see "The cap-8" above.

### Metadata Claude asks the human for at port-time

Per the port recipe in [`linear.md`](linear.md) "Design lifecycle in
Linear": **priority**, **owner/assignee**, **initial state** (`Todo` = queued, or
`In Progress` = starting now — a started state counts against that person's
cap-8), and any **extra labels** beyond `design` (Claude proposes; human
confirms).

## Status stamps — required for all designs/

Every file under any `designs/` folder MUST carry a status stamp on or
near the top:

```
Status: <Draft|Accepted|Verified> · Pass <n> · Updated <YYYY-MM-DD>[ · Reviewed <YYYY-MM-DD>@<commit>]
```

### Maturity dial

- **Draft** — design still converging. Pass 0 (Claude-solo) is allowed in
  this state, but the design SHALL NOT be ratified at Draft maturity.
- **Accepted** — ratified ("just do it"). Requires **Pass ≥ 1** (at least
  one meaningful human-LLM iteration). A Pass 0 Accepted design is a
  protocol violation.
- **Verified** — confirmed by experiment, test, or production observation
  that the design held. Pass ≥ 1 required, but Verified is about external
  validation, not iteration count.

### Pass requirements

- **Pass 0** — Claude-solo, unreviewed. Allowed only in `Draft` maturity.
- **Pass ≥ 1** — required for `Accepted` or `Verified`. Hard rule, enforced
  by `wiki/tests/test_doc_health.py`.
- **Pass ≥ 2** — *preferred* before shipping. Strong recommendation, not
  enforced.
- **Aspirationally:** a Verified design with an attached experiment / chaos
  run that demonstrates the design held under failure modes.

## Explorations vs. designs

Both `explorations/` and `designs/` live alongside
`executor/` in a domain (both at the domain root). Triage decides
which one a new item lands in; afterwards the difference is:

- **Exploration** — an investigation with **no clarity yet**. Open
  design questions, not ratified plans. Pure uncertainty surface.
  An exploration may *graduate* to a design via /grill-me + /plan once
  clarity emerges. Explorations do NOT receive content from shipped
  designs — durable patterns land in `executor/`, not here.
- **Design** — clarity reached, ratification on the table, Linear
  will track the work.

## What stays where — when a design ships

The wiki holds full design content (rationale, alternatives, decision
tree, classification matrices, sequencing) **only while the design is
in `designs/`**. On completion:

- The **architectural distillate** (≤ ~100L: "here's the invariant we
  now hold") → updates `executor/primary.md` (or a sub-spec).
- The **wiki design file/folder** is deleted.
- The **Linear issue** is closed (status: Done). Its title (the slug)
  + the wiki path it once linked to preserve the historical record
  that this design existed and shipped.
- The **verbose detail** is **not preserved in the wiki**. Git
  history has the full text if anyone ever needs it.

This is intentional: keeps the wiki small + current, and forces
ratification to require "is the executor update enough to capture
what we'll need to know later?" Designs decay; re-grilling from
`executor/` + current code is often better than rehydrating an old
doc anyway.

## What this REPLACES

- `wiki/doing/` and `wiki/todo/` (the earlier two-folder model). Deleted.
- Per-domain `findings.md` registers. Items either become Linear
  issues (if actionable work), become `explorations/` entries (if
  there's no clarity yet on the right move), or update
  `executor/primary.md` (if it's a durable fact about the domain).
- The "where does the frontier ledger live" open question in
  `working-with-llms.md` "Looking for trouble." Resolved by this doc.

## Open

- **Linear interface — settled.** Linear is wired (official MCP); the
  workspace shape, labels, status mapping, bijection, and enforcement hooks
  (`precheck-design-bijection.sh`, `precheck-cap-8.sh`, wired into
  `.claude/settings.json`) are all live. Full reference:
  [`linear.md`](linear.md).
- **Verified by experiment.** Aspirational — needs the test/chaos
  framework to exist first. Track separately.
