# How GridWorks uses Linear

Status: Accepted · Pass 2 · Updated 2026-06-08

> What this is: the reference for how the team uses **Linear** for work
> tracking — the split with the wiki, the workspace shape, labels, the cap-8
> WIP rule, and the design↔issue bijection. Linear is wired into Claude
> sessions via the official remote MCP server. Setup/cleanup tasks that are
> still *in flight* live in the design checklist
> `designs/linear-integration.md`, not here.

## The split: Linear vs. the wiki

- **Linear = tracking + organizing.** Title, status, owner, priority, labels,
  parent/child links, dates. Linear is where work is sorted, queried, and
  assigned.
- **Wiki = the substance.** Rationale, invariants, decisions, alternatives —
  the "what we're doing and why." For a design that's the file at
  `wiki/<domain>/designs/<slug>.md`.
- **Shared: the slug + the link.** Linear knows the wiki path; the wiki knows
  the Linear issue ID. **No content is mirrored** — Linear is not a copy of
  the wiki, nor vice versa.
- **Status flows Linear → wiki**, never the reverse. A `designs/` file does
  not move when its Linear issue's status changes;
  [`DESIGN_INDEX.md`](DESIGN_INDEX.md) aggregates by reading each design's
  `Status:` line.

## Workspace facts

Snapshot (observed 2026-06-07; re-verify before relying).

- **Two teams.**
  - **Ops** (`OPS-*`) — the **live tracker**. All real operational and design
    work flows here as flat issues (bugs, COP/data analysis, infra, refactors).
    ~380 issues. Active: tdefauw, gbaker, jmillar, joe@2040energy.
  - **GridWorks** (`GRI-*`) — a dormant **house registry**: `GRI-6…10` are the
    Keene installs (beech/fir/maple/elm/oak) as reference cards, `GRI-1…4` are
    onboarding tutorials. Not used for active work; leave as-is.
- **Workflow states** (Ops): `Backlog → Todo → In Progress → In Review →
  Done`, plus `Canceled` / `Duplicate`.
- **No projects, milestones, or cycles** are in use — work is flat issues in a
  team. We do **not** introduce projects for designs.
- **Members:** jmillar (admin), gbaker, tdefauw, joe@2040energy, + Linear bot.

## Status mapping

| Linear state | Type | GridWorks meaning |
| --- | --- | --- |
| `Backlog` | backlog | scratch / not ratified |
| `Todo` | unstarted | ratified + queued |
| `In Progress` | started | actively doing |
| `In Review` | started | doing, under review |
| `Done` | completed | shipped |
| `Canceled` | canceled | shelved without shipping |
| `Duplicate` | duplicate | folded into another issue |

**"Started" = In Progress *or* In Review** — both count for cap-8.

## Cap-8 — a personal WIP limit

cap-8 is a discipline on **my own attention**, not a global design budget:

- **cap-8 = the number of issues assigned to me (jmillar) in a `started`
  state** (In Progress + In Review). **Warn at 7, stop at 8.**
- It spans **all** my issues — design and operational alike — because the
  scarce resource is my attention, not a design slot.
- Query: `assignee = me AND state.type = started`.
- Surfaced each turn by [`tools/precheck-cap-8.sh`](tools/precheck-cap-8.sh)
  (see Enforcement). When I move one of my issues into a started state, I
  surface the new count.

## Labels and tags

**The live Linear label set is the source of truth.** The wiki keeps no label
glossary — the MCP is create-only for labels, so a wiki copy would only drift.
**When making an issue, review the existing labels and reuse a fitting one;
coin a new tag only after a moment's thought.**

Tags cluster on five **axes** (a typical issue carries one house + one
component + optionally a work-kind / cross-cutting / effort tag):

1. **House** — which installation (`beech`, `fir`, `elm`, `maple`, `oak`,
   `spruce`, `house0`).
2. **Component / domain** — subsystem or repo (`scada`, `sema`, `pico`,
   `rabbit`, `ltn`, …).
3. **Work-kind** — what kind of work (`Bug`, `Feature`, `refactor`, `testing`,
   `infra`, `design`, …).
4. **Cross-cutting** — themes spanning components (`COP`, `security`,
   `observability`, `semantics`, …).
5. **Effort** — a rough size estimate, orthogonal to work-kind (`bite-size`).

Two integration-specific labels, and how size relates to `design`:

- **`design`** — marks a design issue (↔ a `wiki/**/designs/` file); the
  bijection keys on this label.
- **`nit`** — sub-threshold software cleanup **not worth a wiki design**. So
  `nit` and `design` are **mutually exclusive** — a nit is by definition the
  work that doesn't earn a design.
- **`bite-size`** — small effort (~under 10 min of Claude time). Orthogonal to
  `design`: a `bite-size` issue **may still be a `design`** (small things are
  often worth designing first). So `design` + `bite-size` is valid; `design` +
  `nit` is a contradiction.
- **Priority** — use Linear's native `Urgent / High / Medium / Low /
  No priority`. No parallel scheme.
- **Maturity labels** (`draft`/`accepted`/`verified`) — **not used.** A
  design's `Status:` line is the sole maturity source; it is not mirrored to
  Linear.

## Designs ↔ Linear: the bijection

**A design = one Linear *issue* in the Ops team, carrying the `design` label.**
Not a Project, not an "epic" (the workspace uses neither). The issue body is
thin — just the wiki link:

```
**Design:** wiki/<domain>/designs/<slug>.md   ← required while the design file is alive
**Exploration (if applicable):** wiki/<domain>/explorations/<name>.md
```

**The bijection is 1:1 and normative.** Every `wiki/<domain>/designs/<slug>.md`
(or `<slug>/` folder) ↔ **exactly one** `design`-tagged issue, and vice versa.
Without it, intent fragments silently (two issues for one design, or two
designs sharing one issue).

**Cross-reference both ways:**
- Wiki `Status:` line carries the issue id, e.g.
  `Status: Accepted · Pass 2 · Updated 2026-06-08 · Linear: OPS-142`.
- The Linear issue body carries the `Design:` wiki path (above), while the
  file is alive.

**The wiki owns the slug; Linear follows.** The slug **is** the wiki file name;
the Linear title is derived from it. The title need not be string-equal — it
must **project** to the slug by: *lowercase → replace each run of
non-alphanumeric chars with one hyphen → strip leading/trailing hyphens*
(canonical `_slugify` in `tests/test_doc_health.py`). Examples:

- `Untangle market.type.name` → `untangle-market-type-name`
- `Circulator pump 0-10V models` → `circulator-pump-0-10v-models`

A title may be more display-friendly **only if the projection still lands on
the slug** — `SCADA simulated test environment` is NOT allowed for slug
`simulated-test-environment` (it projects to `scada-…`).

**Default to the EXISTING slug — never invent one.** To rename: (1) discuss
with the user; (2) rename the wiki **file** first (`git mv` — the file slug is
canonical); (3) update the Linear title to re-satisfy the projection. When
unsure whether to split one design into two, **ask** rather than spawning a
second slug + issue.

**Hub-and-spoke (fractal) designs are still ONE design → ONE issue.** The issue
corresponds to the **hub** (`designs/<slug>/primary.md`), whose title projects
to the *folder* slug; the hub's `Status:` line carries the id. **Spokes carry
no id** — they reference the hub by link. The doc-health linear-id check runs
over design *roots* only (a flat `<slug>.md` or a fractal `<slug>/primary.md`).

**Sub-issues are purely a Linear-side concern — the wiki tracks NOTHING about
them.** Linear native parent/child is used ad-hoc for execution as the team
sees fit; there is no wiki convention for sub-issue titles, anchors, or bodies.
Sub-issues are **unrelated** to the hub-and-spoke pattern (a spoke is not a
sub-issue, and vice versa).

## Design lifecycle in Linear

**When a design enters Linear:**
- **Draft (Pass 0) → optional.** A draft *may* get an issue early (to park or
  share it), sitting in **Backlog**. Not required — drafts are cheap and many
  won't survive.
- **Accepted (Pass ≥ 1) → required**, moved to **Todo** (queued) or **In
  Progress**. An Accepted design with no issue is untracked ratified work.
- **Reverse case** (an existing issue reframed into a design): just add the
  `design` label + cross-link; no new issue.

Enforced wiki-side by
`tests/test_doc_health.py::test_accepted_designs_have_linear_id` (every
Accepted/Verified design's `Status:` line must carry `· Linear: <ID>`).

**Porting a design to Linear** (at ratification — "just do it"): draft the thin
issue → ask the human for the metadata you can't decide (**priority**,
**owner/assignee**, **initial state** Todo-or-In-Progress, **extra labels**) →
create it in Ops with the `design` label + wiki link → stamp the id back onto
the `Status:` line. The `designs/<slug>` file stays put; Linear is the
authority on lifecycle from here. The
[`tools/link-design-linear.sh`](tools/link-design-linear.sh) helper validates
the wiki side and prints the exact paste.

**Always set metadata on the create.** A `design` issue is created with its
**assignee** (default: me), **initial state**, and **priority** set — never
half-configured. A `PreToolUse` hook **blocks** a `design` create that omits
any of them (see Enforcement).

**Flip the state when you start.** When you **begin executing** an Accepted
design, move its issue to **In Progress** (it then counts against cap-8) —
don't leave it in `Todo` while actively working it.

**Resuming a shelved design:** open the Linear issue → open the matching
`designs/<slug>` (or the `executor/primary.md` it distilled into) → open any
`explorations/<name>.md` → `/grill-me` + `/plan`. Work counts against the
assignee's cap-8 once its state flips to started.

**On completion (issue → Done):** distil the durable architecture into
`executor/primary.md` (or a sub-spec), then **delete** the `designs/<slug>`
file. The issue's `Design:` link then points at a deleted path — fine; git
history is the deep record.

## How Claude reads + writes Linear

- **Official remote MCP server** `https://mcp.linear.app/mcp` (HTTP), added at
  **local (project) scope**, OAuth `read write`, token persists across
  sessions. One-time add: `claude mcp add --transport http linear
  https://mcp.linear.app/mcp`, then `/mcp → linear → Authenticate`. A server
  added mid-session needs a restart before its tools load. Reconnect on token
  rot: `claude mcp remove linear -s local` then re-add.
- The MCP exposes `list_*` / `get_*` / `save_*` for teams, issues, states,
  comments, documents — enough to query and to port designs.
- **Labels are create-only over MCP.** `create_issue_label` exists; there is
  **no** update/delete-label tool, so names/descriptions/colors can only be set
  *at creation*. Later edits (renames, merges, description backfills) are
  **Linear-UI-only** — which is why the wiki keeps no label glossary.

## Enforcement (tools + hooks)

- **[`tools/link-design-linear.sh`](tools/link-design-linear.sh)** — manual
  helper that wires a design to its issue: validates the wiki→Linear back-link
  and prints the `**Design:**` line to paste (it can't call Linear — the MCP is
  Claude-facing). It hardcodes the `thegridelectric/wiki` GitHub remote.
- **[`tools/precheck-design-bijection.sh`](tools/precheck-design-bijection.sh)**
  (`UserPromptSubmit` sweep + `PreToolUse` write-time slug guard) — wiki-side
  always: malformed slug, slug collisions, Accepted/Verified missing a Linear
  id. Linear-side with a `LINEAR_API_KEY`: wiki slug with no issue, or `design`
  issue with no wiki slug.
- **[`tools/precheck-cap-8.sh`](tools/precheck-cap-8.sh)** (`UserPromptSubmit`)
  — surfaces the cap (warn 7, flag 8), advisory. Wiki-side fallback is an
  honor-system reminder; the live count needs a `LINEAR_API_KEY`.
- **[`tools/precheck-linear-issue-meta.sh`](tools/precheck-linear-issue-meta.sh)**
  (`PreToolUse` on the Linear `save_issue` MCP call) — **blocks** a `design`
  issue *create* that omits assignee, initial state, or priority. Updates and
  non-design issues pass through.

**About `LINEAR_API_KEY`.** The hooks are shell scripts, and the Linear MCP is
available only to Claude, not to shell. For a hook to query Linear *itself* (the
live cap count, or whether a design issue exists) it must call Linear's web API,
which needs a secret token in the environment named `LINEAR_API_KEY`. It is
**optional**: without it the hooks still run every wiki-side check and just fall
back to a reminder for the Linear-side. To enable the live checks, create a
personal API key in Linear settings and set it in the environment.
