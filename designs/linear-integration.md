# Linear integration

Status: Draft · Pass 0 · Updated 2026-06-07

> What this is: how `designs/` files in the wiki interface with Linear for
> work tracking. Companion: [`../designs-process.md`](../designs-process.md).
> **Linear is now wired** into Claude sessions via the official remote MCP
> server (see "How Claude reads + writes Linear"). This doc is written to
> the team's *current* Linear usage — start minimal, grow conventions only
> as a concrete need appears.

## Workspace facts (observed 2026-06-07)

Snapshot so future sessions don't re-discover. Re-verify before relying.

- **Two teams.**
  - **Ops** (`OPS-*`) — the **live tracker**. All real operational +
    design work flows here as flat issues (bugs, data/COP analysis, infra,
    refactors). ~377 issues. Active: tdefauw, gbaker, jmillar, joe@2040energy.
  - **GridWorks** (`GRI-*`) — effectively a **house registry**. Only durable
    content is GRI-6…10 = the Keene installs (beech/fir/maple/elm/oak) as
    reference cards; plus the GRI-1…4 onboarding tutorials. Not used for
    active work. Leave as-is.
- **Workflow states** (Ops): `Backlog → Todo → In Progress → In Review →
  Done`, plus `Canceled` / `Duplicate`. Both **In Progress** and **In
  Review** are `started`-type — this matters for cap-8.
- **No projects, milestones, or cycles** in use. Work is flat issues in a
  team. We do **not** introduce projects for designs (see below).
- **Labels** are organic + inconsistent: house tags as `keene.elm`
  (GridWorks team) but `elm` / `Elm` / `Maple` / `spruce` (Ops, mixed case);
  plus `software`, `security`, `ltn`, `scada`, `refactor`, `alerts`,
  `Data Analysis`, `open-source`. No maturity labels exist yet.
- **Members:** jmillar (admin), gbaker, tdefauw, joe@2040energy, + Linear bot.

## Principle

- **Linear = organizing + cross-linking.** Title (the slug), status, owner,
  priority, labels, parent/child links, dates.
- **Wiki = the details.** The design file at
  `wiki/<domain>/designs/<slug>.md` (or `<slug>/primary.md` for fractal
  designs) holds rationale, invariants, decisions, alternatives —
  everything substantive.
- **Shared: the slug and the link.** Linear knows the wiki path; the wiki
  knows the Linear issue ID. **No design content is mirrored.** Linear is
  not a copy of the wiki.
- **Status flows from Linear to the wiki**, not the other way around. The
  wiki design file in `designs/` does not move when the Linear issue's
  status changes. [`DESIGN_INDEX.md`](../DESIGN_INDEX.md) aggregates by
  reading each design's `Status:` line (and, optionally, the linked Linear
  issue's status).

## How a design maps to Linear (decided)

Match current usage — no new structure:

- **A design = one Linear Issue in the Ops team**, carrying the **`design`
  label**. Not a Project, not a Linear "epic" (the workspace uses neither).
- **Sub-work = child issues** (Linear native parent/child) under that design
  issue, created only when the need is concrete (see "Sub-issues").
- **The design issue title === the wiki slug** (or a display-friendly
  variant that trivially normalizes to it — see "Naming + bijection").
- **The design issue body is thin** — just the wiki link + optional
  cross-refs. The wiki holds the substance:

  ```
  **Design:** wiki/<domain>/designs/<slug>.md   ← required while the design file is alive
  **Concern (if applicable):** wiki/<domain>/research/concerns/<name>.md
  **Active-claims session:** {session-name} (if known)
  ```

## Status mapping (decided)

Linear (Ops) state → GridWorks meaning:

| Linear state | Type | GridWorks meaning |
| --- | --- | --- |
| `Backlog` | backlog | scratch / not ratified |
| `Todo` | unstarted | ratified + queued |
| `In Progress` | started | actively doing |
| `In Review` | started | doing, under review |
| `Done` | completed | shipped |
| `Canceled` | canceled | shelved without shipping |
| `Duplicate` | duplicate | folded into another issue |

**"Started" = In Progress *or* In Review.** Any count of active work
(cap-8 below) counts both.

## Cap-8 = my started issues (decided)

The focus-discipline cap is a **personal WIP limit on the current user's own
assigned issues**, not a global designs-doing count:

- **cap-8 = the number of issues assigned to me (jmillar) in a `started`
  state (In Progress + In Review).** Warn at 7, stop at 8.
- It spans **all** my issues — design and operational alike — because the
  scarce resource is *my attention*, not a design slot.
- **Today: 4/8** (OPS-219, OPS-313, OPS-324, OPS-334).
- Query: issues where `assignee = me` AND `state.type = started`.
- Until a hook enforces it (see Hooks), it's honor-system; I surface the
  count when I move one of my issues into a started state.

> Note: this supersedes the earlier draft notion of "cap-8 on designs in
> the doing column." The cap is per-person WIP; it is not about designs
> specifically.

## Labels + priority (decided, minimal)

> Full label inventory + meanings + the consolidation plan live in
> [`../linear-tags.md`](../linear-tags.md). This section covers only the
> two integration-specific labels.


- **`design`** — marks a design issue (the one ↔ a `wiki/**/designs/`
  file). The bijection hook keys on this label. *To create.*
- **`nit`** — sub-threshold items (one-line cleanups). *To create.*
- **Priority** — use Linear's native `Urgent / High / Medium / Low /
  No priority` directly. No parallel scheme.
- **Maturity labels** (`draft` / `accepted` / `verified`) — **deferred.**
  The doc's `Status:` line is already the maturity source of truth; mirror
  it to a Linear label only if/when the bijection hook needs to assert on
  it. Don't pre-create taxonomy we won't query.
- **House / domain labels** — leave the existing organic set alone for now;
  normalizing them is a separate cleanup (see "Cleanup backlog").

## Cross-references both ways (decided)

- Wiki design `Status:` line → Linear issue ID, e.g.
  `Status: Accepted · Pass 2 · Updated 2026-06-10 · Linear: OPS-142`.
- Linear design issue body → wiki path (`Design:` field above) **while the
  design file is alive**. After cleanup the link rots; that's expected.
- Every `executor/primary.md` update that descends from a shipped design
  **should** note the issue ID for traceability.

## Naming + bijection

**Bijection (normative).** Every `wiki/<domain>/designs/<slug>.md` (or
`<slug>/` folder) corresponds to **exactly one** Linear issue tagged
`design`; every `design`-tagged issue corresponds to **exactly one** wiki
design. Both sides cross-reference (links above).

**Canonical name = wiki slug.** The Linear issue title MAY be
display-friendly ("Shrink gwproto to proactor surface") but SHALL contain
the slug or trivially normalize to it (lowercase, hyphenated). When in
doubt, make them identical.

**Why a bijection.** Without it, work drifts: two issues for one design, or
two designs sharing one issue, both let intent fragment silently. The 1:1
rule lets either side resolve to the other unambiguously.

## Sub-issues

Use Linear native parent/child. Create a child issue only when the work is
concrete — don't decompose a design into sub-issues at port-time on spec.
Child issue title === a sub-section anchor or sub-spec filename in the
design where possible. Stay literal.

## Port from `designs/` to Linear — at ratification

When the user says "just do it":

1. I draft the design issue (thin body + the wiki link) for review.
2. **I ask for the metadata I can't decide:**
   - **Priority** (Linear's Urgent / High / Medium / Low / No priority).
   - **Owner** — assignee. (Counts against *that person's* cap-8.)
   - **Initial state** — `Todo` (queued) or `In Progress` (starting now).
   - **Extra labels** beyond `design`.
3. User reviews + adjusts.
4. I create the issue in Ops with the agreed metadata + `design` label +
   the wiki link.
5. The wiki `designs/<slug>` file **stays put** — never moved between
   folders. Linear's state is the authority on lifecycle from here on.
6. I add the issue ID to the wiki `designs/<slug>` `Status:` line so the
   link goes both ways.

## Resume from Linear

To re-engage a shelved design:

1. Open the Linear design issue; read its body + child issues.
2. Open the matching `designs/<slug>` (if still in the wiki) OR the
   affected `executor/primary.md` (if already shipped + distilled).
3. Open any matching `research/concerns/<name>.md`.
4. Run `/grill-me` + `/plan` to regenerate or update the design.
5. The work counts against the assignee's cap-8 from the moment its state
   flips to a started state.

## Clean up — on design completion

When the design ships (issue → Done):

1. Update the relevant `executor/primary.md` (or a sub-spec) with the
   durable architectural distillate — invariants, vocabulary, contracts.
2. Delete `wiki/<domain>/designs/<slug>.md` (or the folder).
3. The Linear issue's `Design:` link now points to a deleted path — fine;
   git history is the deep record.

## How Claude reads + writes Linear (decided)

- **Official remote MCP server.** `https://mcp.linear.app/mcp` (HTTP),
  added at **local (project) scope** — private to this user in
  `/Users/jessica/GridWorks`. OAuth (`read write`), token persists across
  sessions.
- **Add (one-time):** `claude mcp add --transport http linear
  https://mcp.linear.app/mcp`, then `/mcp` → linear → Authenticate.
- A server added mid-session needs a **session restart** before its tools
  load.
- **Reconnect / token rot:** `claude mcp remove linear -s local` then re-add.
- The MCP exposes `list_*` / `get_*` / `save_*` for teams, issues, labels,
  states, projects, comments, documents — enough for the bijection +
  cap-8 hooks to query and for porting designs.

## Hooks (script-enforced, not AI-checked)

Wiki-side halves can land now; Linear-side queries now have a live MCP/API
to call.

### `wiki/tools/precheck-design-bijection.sh`

Enforces slug ↔ `design`-issue-title bijection.

- **Trigger:** `UserPromptSubmit` (early sweep); `PreToolUse` on Write/Edit
  to `wiki/**/designs/**` (catch a mis-named new file at write-time);
  on first Linear MCP call in a session (catch cross-session drift).
- **Logic:** walk every `wiki/<domain>/designs/<slug>.md` (+ `<slug>/primary.md`)
  and `wiki/designs/<slug>.md`; extract slug + `Status:` line. For each
  slug, query Linear for a `design`-labeled issue whose title equals or
  trivially normalizes to the slug. **Flag:** (a) wiki slug with no issue;
  (b) `design` issue with no wiki slug; (c) slug collisions; (d) — *deferred
  until maturity labels exist* — `Status:` vs maturity-label mismatch.
- **Wiki-side-only mode** (no Linear): duplicate/malformed slug checks across
  `wiki/**/designs/**`.

### `wiki/tools/precheck-cap-8.sh`

Enforces the personal WIP cap.

- **Trigger:** `UserPromptSubmit` (warn early); before any action that would
  move one of *my* issues into a started state.
- **Logic:** query Linear for issues where `assignee = me` AND
  `state.type = started` (In Progress + In Review). **Warn at 7, fail at 8.**
- **No-Linear mode:** once-per-session honor-system reminder.

### `wiki/tools/regen-design-index.sh` (later)

Auto-regenerate [`DESIGN_INDEX.md`](../DESIGN_INDEX.md) from the filesystem
(walk `wiki/**/{designs,research/concerns}/**.md`, read each `Status:`
line) + optionally decorate with the linked Linear issue's state. Deferred:
most useful once we routinely carry Linear IDs in `Status:` lines.

## Cleanup backlog (Linear-side data hygiene)

Not blocking the integration; queue as `nit`/small issues when touched:

- **Normalize house/domain labels** — collapse `elm`/`Elm`, `Maple`/`maple`,
  `keene.elm` etc. into one consistent scheme across Ops + GridWorks teams.
- **Decide the GRI team's role** — keep as house registry (current de-facto)
  or fold the house cards elsewhere. Low priority; it's harmless as-is.
- **Create the `design` + `nit` labels** in Ops before the first design port
  or the bijection hook goes live.

## Reconciliation note (out of this session's scope)

[`../designs-process.md`](../designs-process.md) "Linear interaction — the
rules" still describes the older **epic / designs-project / designs-doing
cap-8** model. That top-level file needs a follow-up pass (under its own
active-claims claim) to align with the decisions here:
design = **issue** (not epic), tracked in **Ops** (no designs project),
cap-8 = **my started issues** (not designs-in-doing).

## Still open / deferred

- **Maturity → label mirroring** — create `draft`/`accepted`/`verified`
  labels only when the bijection hook actually asserts on them.
- **Session ↔ Linear coupling** — the design issue body's "Active-claims
  session" line is optional today; formalize if it proves useful.
- **Sub-issue conventions** — title alignment + thin bodies are the rule;
  finer mechanics decided ad-hoc as real sub-issues appear.
- **Cross-repo numbering** — single workspace, OPS numbering; the wiki slug
  (not the issue number) is the canonical cross-link, so multi-team
  numbering is a non-issue unless designs ever split across teams.
