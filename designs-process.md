# designs-process — the `designs/` lifecycle

Status: Draft · Pass 0 · Updated 2026-05-26

> What this is: how design-specs live in the wiki across all domains.
> Companion: [`designs/linear-integration.md`](designs/linear-integration.md)
> for the Linear interface. Aggregated live view:
> [`DESIGN_INDEX.md`](DESIGN_INDEX.md).

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
concerns vs executor vs Linear, see
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
   - **No** → investigate it as a *concern*.
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
   bijection hook something to match against once Linear is wired.

When the output is "concern" (no-clarity branch):

a. Create `wiki/<domain>/research/concerns/<name>.md` (Status stamp
   per the convention).
b. Register the concern in `DESIGN_INDEX.md` under `## Open concerns`
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
concerns/              designs/
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

**At most 8 designs in "doing" state across GridWorks at any time.**
A focus discipline: it forces "what are we actually working on this
fortnight?" to be answerable.

**Source of truth: Linear** (once wired) — query the "In Progress"
view for the designs project. Until Linear is wired, the cap is
honor-system; [`DESIGN_INDEX.md`](DESIGN_INDEX.md) is a flat
directory of *what designs exist*, not a workflow-state board, so it
doesn't track doing-vs-todo. Enforced by a planned script-driven
hook — see the **Open** section.

## Linear interaction — the rules

Full templates, port/pull recipes, and open questions in
[`designs/linear-integration.md`](designs/linear-integration.md). The
**rules** below are normative.

### Division of responsibility

- **Linear = organizing + cross-linking.** Title (the slug),
  status, owner, priority, labels, parent/child relationships,
  dates. Linear is where work is tracked, sorted, queried, and
  assigned.
- **Wiki = the details.** The design file at
  `wiki/<domain>/designs/<slug>.md` (or `<slug>/primary.md` for
  fractal designs) holds rationale, invariants, decisions,
  alternatives, classification tables — everything that's the
  "what we're going to do and why."
- **Shared between the two: the slug (the topic) and the link.**
  Linear knows the wiki path; the wiki knows the Linear epic ID.
  **No design content is mirrored.** Linear is not a copy of the
  wiki and the wiki is not a copy of Linear.

### Hard rules (script-enforced, not AI-checked)

1. **Bijection on names AND draft-state.** Every
   `wiki/<domain>/designs/<slug>.md` (or
   `wiki/<domain>/designs/<slug>/` folder) SHALL correspond to
   **exactly one** Linear epic, and every Linear epic representing
   a design SHALL correspond to **exactly one** wiki design. The
   `<slug>` is canonical — the Linear epic **title MUST equal the
   slug** (or trivially normalize to it: same letters in the same
   order, hyphens ↔ spaces, case-insensitive). No two designs with
   the same slug; no two epics for the same slug. Additionally,
   **maturity propagates as a Linear label**: a wiki design at
   `Status: Draft` SHALL have a `draft` label on its Linear epic;
   when the wiki flips to `Accepted` the `draft` label SHALL be
   removed. (Linear's native *status* field — Backlog / Todo /
   In Progress / Done — tracks workflow state, not maturity; we
   carry maturity in a label so both can be queried independently.)
   *Enforced by a generated script run as a hook (see Open) — not
   by Claude eyeballing.*

2. **Linear → wiki link.** Every Linear epic body MUST carry the
   wiki path to its design (`wiki/<domain>/designs/<slug>.md` or
   the fractal-folder `primary.md`). This and the slug are the
   only required content in the epic body.

3. **Wiki → Linear link.** Every wiki design's `Status:` line MUST
   carry the Linear epic ID once the epic exists.

4. **Cap-8 on doing.** At most **8 designs** GridWorks-wide may be
   in Linear "doing" status at one time. *Enforced by a generated
   script run as a hook (see Open).* Source of truth: Linear "In
   Progress" view for the designs project. Interim signal until
   Linear is wired: entries under `## Doing` in
   [`DESIGN_INDEX.md`](DESIGN_INDEX.md).

### Metadata Claude asks the human for at port-time

Per the port recipe in
[`designs/linear-integration.md`](designs/linear-integration.md):
**priority**, **owner/assignee**, **initial status** (`todo` or
`doing` — `doing` counts cap-8; defaults to `todo`), and any
**workspace labels/tags** (Claude proposes; human confirms).

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

## Concerns vs. designs

Both `concerns/` (under `research/`) and `designs/` live alongside
`executor/` in a domain. Triage decides which one a new item lands
in; afterwards the difference is:

- **Concern** — an investigation with **no clarity yet**. Open
  design questions, not ratified plans. Pure uncertainty surface.
  A concern may *graduate* to a design via /grill-me + /plan once
  clarity emerges. Concerns do NOT receive content from shipped
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
- The **Linear epic** is closed (status: Done). Its title (the slug)
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
  issues (if actionable work), become `concerns/` entries (if
  there's no clarity yet on the right move), or update
  `executor/primary.md` (if it's a durable fact about the domain).
- The "where does the frontier ledger live" open question in
  `working-with-llms.md` "Looking for trouble." Resolved by this doc.

## Open

- **Linear conventions** (workspace shape, labels, status names,
  epic naming) — to be defined when Linear is wired. See
  [`designs/linear-integration.md`](designs/linear-integration.md).
- **Bijection-enforcement hook** (`wiki/tools/precheck-design-bijection.sh`)
  — verify that every `wiki/<domain>/designs/<slug>` has a Linear
  epic whose title equals (or trivially normalizes to) the slug,
  and vice versa. Until Linear is wired, the hook only checks the
  wiki-side (no duplicates, no malformed slugs); after Linear is
  wired, it queries Linear and flags missing/mismatched epics. Spec
  in [`designs/linear-integration.md`](designs/linear-integration.md)
  "Planned hooks".
- **Cap-8 enforcement hook** (`wiki/tools/precheck-cap-8.sh`) —
  warn at 7 designs in doing, fail at 8. Until Linear is wired,
  the hook is a no-op stub (cap is honor-system). Linear-integrated:
  query Linear's "In Progress" view for the designs project. Wire
  as a `UserPromptSubmit` hook in the umbrella
  `~/.claude/settings.json`.
- **Verified by experiment.** Aspirational — needs the test/chaos
  framework to exist first. Track separately.
