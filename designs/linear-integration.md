# Linear integration

Status: Draft · Pass 0 · Updated 2026-05-26

> What this is: how `designs/` files in the wiki interface with Linear for
> work tracking. Companion: [`../designs-process.md`](../designs-process.md).
> **Linear is not yet wired into Claude sessions; specifics will evolve once
> it is.**

## Principle

- **Linear = organizing + cross-linking.** Title (the slug),
  status, owner, priority, labels, parent/child links, dates.
- **Wiki = the details.** The design file at
  `wiki/<domain>/designs/<slug>.md` (or `<slug>/primary.md` for
  fractal designs) holds rationale, invariants, decisions,
  alternatives — everything substantive.
- **Shared: the slug and the link.** Linear knows the wiki path;
  the wiki knows the Linear epic ID. **No design content is
  mirrored.** Linear is not a copy of the wiki.
- **Status flows from Linear to the wiki**, not the other way
  around. The wiki design file in `designs/` does not move when
  the Linear ticket's status changes.
  [`DESIGN_INDEX.md`](../DESIGN_INDEX.md) aggregates by querying
  Linear (once wired) or by reading the design's `Status:` line
  (until wired).
- **Bijection is enforced by a generated script**, not by Claude
  eyeballing. See `designs-process.md` "Linear interaction — the
  rules" for the normative version of these rules.

## Epic template (one per design)

```
Title:  <slug>   (or a display-friendly variant that contains the slug
                  or trivially normalizes to it — see "Naming alignment
                  + bijection" below)

Body:

**Design:** wiki/<domain>/designs/<slug>.md   ← required while design file is alive
**Concern (if applicable):** wiki/<domain>/research/concerns/<name>.md
**Active-claims session:** {session-name} (if known)
```

The epic body is **just the slug + the wiki link** (plus optional
cross-references like concern / session). It is NOT a copy of the
design content, NOT a summary, NOT an acceptance list. The wiki
holds the substance.

## Sub-issues — to investigate

How sub-issues should work (whether to use Linear's native parent/
child, how their titles align with sub-file slugs or sub-section
anchors, how their bodies stay thin, whether they're created at
port-time vs. ad-hoc during execution) is **deferred to when Linear
is actually wired**. The decision will be informed by what Linear's
native features look like in practice + how the human-team uses
sub-issues today.

For now: assume the epic alone is enough; design at the
file-or-folder grain and break into sub-issues only when the
need is concrete.

## Port from `designs/` to Linear — at ratification

Procedure when the user says "just do it":

1. I draft the epic description + sub-issue list (acceptance criteria
   included) for review.
2. **I ask the human for the Linear-side metadata** that I can't
   decide myself:
   - **Priority** (Linear's `Urgent / High / Medium / Low / No priority`,
     or whatever scheme the workspace uses).
   - **Owner** — Linear assignee for the epic. Sub-issues may have
     different owners; I'll ask per sub-issue if it's not obvious.
   - **Initial status** — `todo` (queued; not counted against the
     cap-8) or `doing` (active; counts). Defaults to `todo` unless
     the user is starting work immediately.
   - **Tags / labels** — any workspace labels (e.g.,
     `boundary-cleanup`, `summer-mvp`, `infra`, repo-scope tags). I
     propose; user confirms.
3. User reviews + adjusts the draft + metadata.
4. I create the epic + sub-issues in Linear (once Linear is wired)
   with the agreed metadata. Each Linear issue carries the wiki path
   link.
5. The wiki `designs/<slug>` file **stays put** — never moved between
   folders. Linear's status field (todo / doing / done) is the
   authority on lifecycle state from here on.
6. I add the epic ID to the wiki `designs/<slug>` `Status:` stamp or
   frontmatter so the link goes both ways.

## Resume from Linear

When we want to re-engage a shelved design (closed Linear issue, or
just one in backlog/todo we hadn't touched):

1. Open the Linear epic and read its description + sub-issues.
2. Open the matching `designs/<slug>` (if still in the wiki) OR the
   `executor/primary.md` of the affected domain(s) (if the design
   already shipped and was distilled there).
3. Open any matching `research/concerns/<name>.md`.
4. Run `/grill-me` + `/plan` to regenerate or update the design — may
   produce a fresh `designs/<slug>` if one isn't there.
5. New / updated design counts against the cap-8 from the moment its
   Linear status flips to "doing".

## Clean up — on epic completion

When all sub-issues are closed:

1. Update the relevant `executor/primary.md` (or a sub-spec under it)
   with the durable architectural distillate from the design — the
   invariants, vocabulary, contracts that now hold.
2. Delete `wiki/<domain>/designs/<slug>.md` (or the folder).
3. The Linear epic's `Design:` link now points to a deleted path —
   that's fine; the description body carries the design summary, and
   git history is the deep record if anyone needs it.

## Cross-references both ways

- Every `wiki/<domain>/designs/<slug>.md` **should** list its Linear
  epic ID at the top once Linear is wired.
- Every `executor/primary.md` update that descends from a shipped
  epic **should** include the epic ID for traceability.
- Every Linear issue **must** include the path to its wiki
  `designs/` file *while alive*. After cleanup, the link rots;
  that's expected.

## Naming alignment + bijection

**Bijection (normative).** Every `wiki/<domain>/designs/<slug>.md` (or
`<slug>/` folder) corresponds to **exactly one** Linear epic; every
Linear epic representing a design corresponds to **exactly one** wiki
design. Both sides SHALL cross-reference:

- Linear epic body → wiki path link (`Design:` field in the template).
- Wiki design `Status:` line → Linear epic ID (e.g.,
  `Status: Accepted · Pass 2 · Updated 2026-06-10 · Linear: GRID-142`).

**Canonical name = wiki slug.** The wiki slug is the canonical name
(`gwproto-shrink`, `transactive-mvp-clearing`, etc.). The Linear epic
title MAY be a display-friendly variant ("Shrink gwproto to proactor
surface"), but it SHALL contain the slug, or trivially normalize to
it (lowercase, hyphenated). When in doubt, make them identical.

**Sub-issue alignment.** Linear sub-issue title === a sub-section
anchor or sub-spec filename in the design where possible. Stay literal.

**Why a bijection.** Without it, work drifts: two Linear epics for the
same design, or two designs sharing one epic, both let intent fragment
silently. The 1:1 rule lets either side resolve to the other
unambiguously.

## Planned hooks (script-enforced, not AI-checked)

These two hooks formalize the hard rules in `designs-process.md`
"Linear interaction — the rules" so they're checked
deterministically, not eyeballed by an LLM. **Wiki-side
implementation can land now; Linear-side queries land when Linear is
wired.**

### 1. `wiki/tools/precheck-design-bijection.sh`

Enforces the slug ↔ Linear-epic-title bijection **AND** the
maturity ↔ Linear-label bijection (`Status: Draft` in the wiki
matches a `draft` label on the Linear epic).

- **Trigger:**
  - `UserPromptSubmit` (early-session sweep) — runs wiki-side
    checks + (once Linear is wired) the full bijection query.
  - **On Linear-connect** (first time Claude opens a Linear
    session in a given Claude session, e.g., the first MCP call
    to Linear) — runs the full bijection query so any
    drift accumulated between sessions surfaces immediately.
  - `PreToolUse` on Write/Edit when the target path matches
    `wiki/**/designs/**` — re-check just that slug's bijection
    so a mis-named new file is caught at write-time.
- **Logic:**
  - Walk every `wiki/<domain>/designs/<slug>.md` (and
    `wiki/<domain>/designs/<slug>/primary.md` for fractal
    designs) — extract the slug + read its `Status:` line.
  - Walk every `wiki/designs/<slug>.md` similarly (cross-cutting
    designs).
  - For each slug, query Linear for an epic whose title equals
    the slug or trivially normalizes to it (case-insensitive,
    hyphens ↔ spaces, same letters in same order).
  - **Flag, per design:**
    - (a) wiki slug with no matching Linear epic;
    - (b) Linear epic in the designs project with no matching
      wiki slug;
    - (c) slug collisions on either side;
    - (d) wiki `Status: Draft` but the Linear epic has no `draft`
      label (or vice versa: epic has `draft` but the wiki is
      already `Accepted`).
- **Until Linear is wired:** the hook runs the wiki-side half
  only — checks for duplicate slugs and malformed slugs across
  `wiki/**/designs/**`, no Linear query, no label check.

### 3. `wiki/tools/regen-design-index.sh` (consider during Linear integration)

Auto-regenerate [`DESIGN_INDEX.md`](../DESIGN_INDEX.md) from the
file system rather than hand-maintaining its entries.

- **What it does:**
  - Walks `wiki/**/{designs,research/concerns}/**.md`.
  - Reads each file's `Status:` line (maturity + Pass).
  - (Once Linear is wired) queries the matching Linear epic's status
    + labels for each design.
  - Emits a refreshed `DESIGN_INDEX.md`: same two sections (Designs +
    Concerns), each entry decorated with `Status: Draft · P0`
    inline + (optionally) the Linear status.
- **Trigger:** pre-commit hook on the wiki, plus on-demand
  invocation. Could piggyback on `precheck-design-bijection.sh`
  (same walk, same Status reads).
- **Why deferred to Linear-integration time:** the script is more
  useful when it can also surface Linear's workflow status (doing /
  todo / done) alongside wiki maturity. Hand-maintaining
  DESIGN_INDEX with status info before then would create the drift
  problem the current flat-directory design is built to avoid; the
  auto-gen path gets us scanability without dual-write.
- **Until then:** DESIGN_INDEX stays a flat directory of paths.
  Maturity lives in each file; readers click through if they need it.

### 2. `wiki/tools/precheck-cap-8.sh`

Enforces the cap-8 on designs in Linear "doing" status.

- **Trigger:** `UserPromptSubmit` (warn early in a session) and
  before any action that would flip a Linear ticket into "doing".
- **Logic:**
  - Query Linear's "In Progress" view for the designs project;
    count epics there.
  - Warn at 7, fail at 8 (block the flip to "doing" until one
    is moved back to "todo" or closed).
- **Until Linear is wired:** the hook is a no-op stub (or
  optionally emits a once-per-session reminder that the cap is
  on the honor-system). `DESIGN_INDEX.md` is a flat directory,
  not a doing-state board, so no count is derivable from it.

## Open (until Linear is wired)

- **Workspace / project shape.** One project per code repo? One per
  active design? One umbrella with labels? Decide when wiring.
- **Status names.** Linear's defaults are
  `Backlog / Todo / In Progress / Done / Canceled`. Map to GridWorks:
  `backlog` = scratch, `todo` = ratified+queued, `in progress` = doing
  (counts cap-8), `done` = shipped, `canceled` = shelved without
  shipping.
- **Labels / priority conventions.** Map onto the Type/Severity/Effort
  fields the legacy `findings.md` registers used.
- **Cross-repo issue numbering.** Linear IDs are workspace-scoped;
  one workspace = one numbering. Multi-workspace would need a
  path-style identifier.
- **How Claude reads + writes Linear.** MCP server vs. direct API.
  Until set up, this doc describes the model; nothing executes.
- **Session ↔ Linear coupling.** Should a Linear issue surface which
  `active-claims.md` session is currently on it? Probably useful;
  defer to first real use.
- **What about items below the Linear-ticket threshold** — one-line
  nits a contributor would mop up on a slow afternoon? Default:
  tiny Linear issues with a `nit` label. The wiki SHALL NOT carry
  a separate todo/queue list — "queue" is a Linear concept, not a
  wiki concept. Nits do NOT go to `concerns/` either — concerns are
  for genuine open design questions, not work-tracking spillover.
