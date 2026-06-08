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

**The wiki is authoritative for slugs; Linear follows.** The slug **is** the
wiki design file name. The Linear issue title is derived from it, not the other
way around. Normal flow: decide the name → name the wiki file → set the Linear
title to match. (OPS-40 → `simulated-test-environment` followed exactly this and
is correct — naming it well in the wiki and updating Linear is the intended use
of both tools, not a violation.)

**The bijection is a normalization, not string equality.** Project a Linear
issue title to a slug by: **lowercase → replace every run of non-alphanumeric
characters with a single hyphen → strip leading/trailing hyphens.** The result
MUST equal the wiki design's file slug. Examples:

- `Untangle market.type.name` → `untangle-market-type-name`
- `Simulated test environment` → `simulated-test-environment`
- `Circulator pump 0-10V models` → `circulator-pump-0-10v-models`

The Linear title MAY be more display-friendly than the slug **only insofar as
the projection still lands on the slug** — so `SCADA simulated test environment`
is NOT allowed for slug `simulated-test-environment` (it projects to
`scada-…`). The canonical normalization lives in
`tests/test_doc_health.py::_slugify` (unit-tested); the future
`precheck-design-bijection.sh` applies it to live Linear titles.

**Default to the EXISTING slug — never invent one.** Keep the slug that already
exists. To rename: (1) discuss with the user; (2) if agreed, rename the wiki
**file** first (`git mv` — the file slug is canonical); (3) then update the
Linear title to re-satisfy the projection. Coining a fresh slug also mis-labels
scope (e.g. `structured-enums` for a capability that also covers *versioned
names*). When unsure whether to split one design into two, **ask** rather than
spawning a second slug + issue.

**Exception — Linear-first capture.** Sometimes an issue is jotted into Linear
first (e.g. distractedly, during a meeting). Fine: when it becomes a design,
reconcile its title to the wiki slug — the wiki still wins, and the name is open
to re-contemplation at that point.

**Why a bijection.** Without it, work drifts: two issues for one design, or
two designs sharing one issue, both let intent fragment silently. The 1:1
rule lets either side resolve to the other unambiguously.

## Sub-issues and hub-and-spoke designs

**A hub-and-spoke (fractal) design is ONE design → ONE Linear issue.** When a
design is a folder (`designs/<slug>/primary.md` + sub-spec spokes), the Linear
issue corresponds to the **hub**; its title projects to the **folder** slug. The
**hub** (`primary.md`) carries that one issue's `· Linear: <id>` in its Status
line; **spokes carry NO id of their own** — they reference the hub by link/prose,
since a spoke's own `Linear:` stamp would imply a second issue for one design and
break the 1:1. The doc-health linear-id check runs over design **roots** only —
a flat `<slug>.md` or a fractal `<slug>/primary.md` (see
`tests/test_doc_health.py::_design_roots`) — so a spoke is *structurally* never
required to carry an id (no name-matching on spokes). In `DESIGN_INDEX.md` only
the hub `primary.md` is listed, not each spoke.

**Linear sub-issues are for concrete work, not for spokes.** Use Linear native
parent/child only when execution decomposes into distinct work items, created
ad-hoc when the need is concrete — never auto-created per spoke. Child issue
title === a sub-section anchor or sub-spec filename where natural. Stay literal.

## When a design enters Linear (decided)

Timing rule:

- **Draft (Pass 0) → Linear optional.** A draft design MAY get a Linear issue
  early when it helps (parking it, sharing it, remembering it), but it is not
  required — drafts are cheap and many won't survive. If present, it sits in
  Linear **Backlog** (matches the status mapping: Backlog = scratch / not
  ratified).
- **Accepted (Pass ≥ 1) → Linear required.** By the time a design is Accepted it
  MUST have a Linear issue, moved to **Todo** (ratified + queued) or In Progress.
  An Accepted design with no Linear issue is untracked ratified work — exactly
  the gap to forbid. Acceptance is also when the implementation gate, cap, and
  ownership start to matter.
- **Reverse case** (an existing Linear issue reframed into a design, e.g.
  OPS-27/OPS-40): the issue already exists — just tag `design` + cross-link at
  whatever maturity. No new issue needed; move it to Backlog while the design
  is Draft.

One-liner: **Draft → Linear optional (Backlog if present); Accepted → Linear
required (Todo).**

**Enforcement (tests, not hooks).** The wiki-side half is enforced by
`tests/test_doc_health.py::test_accepted_designs_have_linear_id`: every
Accepted/Verified design's `Status:` line must carry `· Linear: <ID>`. The
Linear-side half (the issue exists and is `design`-tagged) needs a Linear API
token and stays a future script (`precheck-design-bijection.sh`), not a git
hook.

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
