# GridWorks — working conventions for Claude

Status: Draft · Pass 0 · Updated 2026-06-13

> Canonical at `wiki/GridWorks_CLAUDE.md`; symlink setup in
> [`README.md`](README.md#setup). Paths below are relative to the umbrella dir
> (parent of `wiki/` + the sibling code repos: `gridworks-base`,
> `gridworks-scada`, `sema`, …). The wiki holds the
> durable thinking and the **rebuild specifications** for each domain — start
> at [`wiki/README.md`](wiki/README.md) to find anything (domain map +
> getting-started/how-to). Coordination before editing is under Multi-session.

## ⏳ This session only — lively-cedar MAY edit sema schema definitions (REMOVE at session end)

**Temporary (added 2026-06-17, session lively-cedar; remove when the session
ends).** None of the in-flight sema words have been published to
`schema.electricity.works`, so they are mutable in place. For **this session
only**, lively-cedar MAY edit the sema schema definitions Jessica asks for —
in-place functional edits (axioms, fields, etc.) without cutting a new version.
Scope is the specific types Jessica names; no `push`/PR without asking. Also:
passing references to other sema types in a schema MUST appear only in
`extended_description` (or as a formal `$ref`), never in a field `description`.

## ⏳ Tonight only — terminalasset plant simplicity (REVERT ME)

**Temporary directive (added 2026-06-12; revert when the
simulated-test-environment plant MVP is working — reversion is tracked at the end
of that design's `primary.md`).** You SHALL keep the terminalasset plant as simple
as possible while it still works well with the scada code, **and no simpler**. When
in doubt, err on the side of simpler but leave a question for Jessica.

## ⏳ Until spruce-unlimbo lands — branch `gridworks-scada` off `jm/spruce-unlimbo`

**Temporary directive (added 2026-06-12; remove when the spruce-unlimbo epic is
done).** While the spruce-unlimbo "unlimbo" epic is in flight, **new
`gridworks-scada` branches SHALL be cut off `jm/spruce-unlimbo`** — not off
`dev`/`main`. The layout-pipeline rework lives there and downstream work
(including the simulated-test-environment actors) depends on it.

## ⏳ Sema-words commit permission (review pending — REMOVE after Jessica reviews)

**Temporary (added 2026-06-12; remove after Jessica reviews the
simulated-test-environment sema words — tracked at the end of that design's
`primary.md`).** Claude MAY make **bounded, test-passing** git commits of sema
vocabulary additions/bumps — each scoped to one word/change, `pytest` green,
**title-only**, on the **same `jm/` topic branch** (currently `jm/sim-vocab`; do
not proliferate branches), each with its `wiki/sema/changelog.md` entry. No `push`
or PR without asking; Jessica does the merges to `dev` and **will review and may
adjust the words after the fact** — committing is not finalizing. (The commit-block
hook `precheck-no-claude-commits.sh` was removed from `.claude/settings.json` to
enable this — **restore it when this directive is removed.**)

## ⏳ Until the proactor port — sema words are FLAT (REVERT note)

**Temporary clarification (added 2026-06-12; revise when the proactor
replacement lands and the scada's `gwsproto` is regenerated flat).** Sema
vocabulary words do **NOT** inherit from one another — every type schema is
**flat**, every field spelled out explicitly. The scada `gwsproto` types
*pretend* sema types inherit (base classes `ComponentGt`,
`ComponentAttributeClassGt`, `ChannelConfigBase`); **that is a flaw**, not a
pattern to mirror. When authoring a sema type from a gwsproto class, **flatten**
the base-class fields into the type and reference other sema words only by
`$ref` composition (e.g. a `ConfigList` of `channel.config`). Do **not** fix the
gwsproto inheritance now — it gets swept up in the proactor port. Remove this
note once that port regenerates `gwsproto` flat.

## Bearings (held at every altitude)

True in every session, whatever the Focus. One line each; the full text
lives at the pointer — don't restate it here, keep this block short.

- **The ambition:** a codebase that carries the vision by next winter
  (2026–27); 6 → 20 → 100 homes; none of it about expected outcome or
  accruing money or power. Full statement + the clear-and-present gates:
  [`wiki/vision/primary.md`](wiki/vision/primary.md) "The ambition".
- **Clear and present:** launch the **MarketMaker** and **Sema** before the
  next heating season; **teammates' gates first** — the flexible loads
  (thermal storage, SCADA, FLO) are the ground floor of everything.
- **Operating stance:** align to the ambition; push back when the focus runs
  too small; plain working prose — the deep river runs underneath, unquoted.
  See [`wiki/vision/claude/primary.md`](wiki/vision/claude/primary.md).
- **Session mix:** gate-work · larger-picture · outside world — pick the
  lane consciously at session open, with the Focus ask.

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

## Legacy first-pass code: vision, not how

Several repos hold **first-pass simulation code that never ran in
production and was never tested in reality** — written to prove a vision,
not to be the implementation we ship. Treat such code as a **reservoir of
design intent, not a template.** Mine it for the *what* and *why* (the
market structure, the invariants, the hard-won domain learning); do **not**
carry forward its *how* (its transport, serialization, naming, vendor-specific
plumbing, or simulation shortcuts). When the user's stated vision and the
legacy implementation conflict, the vision wins and the old code is the
suspect. Do not over-design to legacy mechanics just because they exist in a
repo — design the new thing from the vision. **But distinguish a legacy
*implementation* from a durable *principle*:** dropping vendor-specific
plumbing does NOT mean dropping the capability it implemented. (E.g. the
Algorand code is legacy plumbing, but the *cryptographic-veracity / distributed-
trust* principle it served is core vision.)

## Status stamps

Every non-trivial wiki doc carries a one-line stamp at the top.
Applies to **all wiki markdown** except: `README.md`, `changelog.md`,
`DESIGN_INDEX.md`, `glossary.md`, `active-claims*.md`, and files under
`wiki/tests/` and `wiki/tools/`. Enforced by
`wiki/tests/test_doc_health.py`.

`Status: <maturity> · Pass <n> · Updated <date>[ · Reviewed <date>@<commit>]`

**The doc-level stamp is a floor.** No section in the doc may have
*lower* maturity than the doc-level stamp. A `##` section MAY carry
its own stamp *only when it is more mature than the doc-level stamp*
— e.g., a settled glossary or already-`Verified` list of invariants
inside an otherwise-`Draft` design. If a section would be *less*
mature than the doc, demote the doc instead. Section stamps live at
`##`, never deeper.

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

## Engineering maxims

- **If it flaps, skip the acks** — never report on a comm path with messages that demand acks on that path.
- **No phantom references** — never cite a task number, id, or handle the user can't open and see verbatim. Ephemeral session task-list numbers (`#11`, `#14`) are phantom: they mean nothing to the user and vanish with the session. Point only at durable, openable things — file paths, real Linear ids, commit hashes.
- **Sema regen touches more than you changed** — bumping one sema type's version rewrites the generated runtime of *unchanged* types that reference it: their versionless class ref (reserved for the new latest) rebinds to the explicit `XxxNNN` old-version class. Expected and correct, not a stray diff.
- **Published (non-draft) sema schema is IMMUTABLE.** You **MAY NOT** make a functional change — fields, `$ref`/dependency versions, axioms, constraints, `required`, enum values — to a non-draft version. That **requires a NEW version**. Only `draft` versions (registry `status: "draft"` / a `/draft/` schema_url) may be edited in place. Clarifying prose (`description`/`examples`) is fine; anything that changes the contract is not. **Asked to edit a published version in place? Refuse and propose a new version** — the request itself is the red flag.
- **Timestamps are real wall-clock, rounded to 5 minutes** — when stamping a sema registry `created` (per version) or `metadata.last_updated`, use the *actual* current UTC time (`date -u`) rounded to the nearest 5 minutes, never an arbitrary placeholder like `12:00:00Z`. Several versions added in one sitting MAY share that rounded stamp; `created` need only be unique *within* a type, dependency ordering allows equal stamps, and `last_updated` must be ≥ every `created`.
- **Dev broker = local `gw-dev-rabbit`** — one RabbitMQ container serves both faces: **gwbase actors over AMQP (`localhost:5672`)** and **scada over MQTT (`localhost:1885`, TLS off, via the Rabbit MQTT plugin — which rewrites topic dots to slashes; payloads are intact)**. Management UI on `15672`. Connection creds live in the per-repo `.env` (e.g. `gridworks-scada/.env` `SCADA_GRIDWORKS_MQTT__*`); never hardcode them.
- **gwsproto serialize needs `by_alias=True`** — gwsproto named-types define **snake_case** python fields with `alias_generator=snake_to_camel`, so the PascalCase wire names (the serialized/Sema form) are pydantic **aliases**, not the field names. A plain `model_dump()` emits snake_case; **`model_dump(by_alias=True)` emits the PascalCase wire form.** Decoding tolerates either (`populate_by_name=True`), which hides the asymmetry. So **serialize layouts/components with `by_alias=True`** — the deployed `LayoutDb.dict()` does; the dc→sema bijection (`house0_bijection.py`) and the round-trip return adapter were the gap that leaked snake_case (Hubitat poller keys) into the `gw.house0.layout` sema example. Not every type bites: PascalCase-native types (e.g. `g.node.gt`) have no alias, so `by_alias` is a no-op for them — the bite is on snake-field types (the Hubitat poller, `maker.api.attribute.gt`).
- **gwsproto sema-type docstrings are the `Sema:` URL and nothing else** — a gwsproto sema type's (or enum's) class docstring MUST be exactly the one-line schema pointer `Sema: <schema_url>` (e.g. `Sema: https://schemas.electricity.works/types/channel-readings/002`) and NOTHING ELSE. No "Values:" enumerations, no "For more information" / global-authority links, no prose — that content duplicates the schema, which is the single source of truth. (The scada `name shuffle` commit stripped these blocks back to the bare `Sema:` line; keep it that way and don't reintroduce them on regen.)
- **gwsproto sema-type axioms are `check_axiom_n` methods** — a gwsproto sema type SHALL mirror its sema schema's `x-gridworks.axioms` as `@model_validator(mode="after")` methods named `check_axiom_<n>`, numbered to match the sema axiom numbers, each raising `ValueError` with a `"Axiom <n> (<Name>) failed: …"` message on violation. This is **mandatory even for value-range constraints** (a 0/1 bit, a 1/2 NumBytes): type the field with the matching sema **format** (`NonNegativeInt`, `PositiveInt`, …) and add the axiom method — do **NOT** capture the bound with a `Literal[0,1]`/`Literal[1,2]`, which silently drops the axiom. The check belongs in code, mirroring the authority (the sema schema), so the proactor port regenerates it; a missing `check_axiom_n` is the defect this maxim exists to prevent.
- **No dead code, no assumed defaults** — when a refactor orphans a name, method, or constant, **delete it in the same change**; never leave it "because it's harmless." Unused symbols obscure intent and accrete. And do **not** introduce a default that hides a value the layout/caller must declare (e.g. a default `NameplatePowerW`) — make it **required** and sourced from a `names` constant, so the source has to state it. Clean and clear beats convenient.

## Experiment-Driven Design (EDD) — the verification bar

**Experiment-Driven Design** is how we reach confidence — the evolution of
test-driven design. Where TDD writes an in-process test first, EDD runs an
**experiment in close-to-real-world conditions** — a real broker, real
timing (optionally sped up) — and lets that experiment be what verifies the
design. Confidence comes first from experiments, not from code analysis and
not from in-process unit tests. In-code tests are necessary, not sufficient:
they share a backdoor transport and a wall clock, and they go green while
gating real-world behavior stays invisible (the 2026-06-09 routing-key bug
`ScadaLiveTest` could not see; the ~15-minute broker-access blackhole no unit
test would catch). A spec reaches **`Verified`** only when an experiment
tests it against reality — the `experiments` entry in the
`Draft → Accepted → Verified` ladder. Keep the harness as a re-runnable
reproducer (it is the evidence behind the stamp); distill findings into
scoped Verified claims, `Reviewed` pointing at the experiment. Lineage:
Karan's verify ethic — build the experiment before calling a design
verified. The framework and conventions live in the simulated-test-environment
design (`wiki/gridworks-scada/`, experimentation-tools spoke).

**When starting a design, use EDD when appropriate** — the
capture → refactor → re-orient working rhythm is in
[`working-with-llms.md`](working-with-llms.md#the-edd-working-rhythm--capture-refactor-re-orient).

**Every design hub self-declares EDD-or-not** on one line directly under the
`Status:` stamp, so the next agent knows the verification bar before reading the
plan. Format: a **bold** `**EDD: yes**` / `**EDD: no**` immediately followed by
the verifying clause — **no separator hyphen**. Examples:

> **EDD: yes** the X harness *is* the verification; spokes reach Verified only
> when an experiment runs against it (`experiments/…`).

> **EDD: no** build-out/integration; verified by the suite (+ the key test),
> not gated on a standalone real-world experiment.

`EDD: yes` when confidence comes from an experiment; `EDD: no` for a build-out
design (migration, integration, refactor). The general hub conventions (layout,
refactor rhythm) apply either way; only the *verification bar* differs.
(Single-file designs may put the line under their stamp too; it's the hub that
must.)

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

**Focus shorthand — design lookup.** When the user states a Focus as loose
words that read like a design name (e.g. "sema snapshot improvement",
"gridworks-scada relay timing", "mtls fis auth"), resolve it to a design
file before doing anything else. Kebab-case the words and match fuzzily against
file names. Try **both** of these and take whichever hits:

- **Cross-cutting** — the *whole* phrase as the slug in **`wiki/designs/`**
  ("mtls fis auth" → `wiki/designs/mtls-fis-auth.md`).
- **Per-domain** — if the first word names a `wiki/` domain folder, treat it as
  `<subfolder>` and the *remaining* words as the slug in
  **`wiki/<subfolder>/designs/`** ("sema snapshot improvement" → domain `sema`,
  slug `snapshot-improvement` → `wiki/sema/designs/snapshot-improvement.md`).
  (`<subfolder>` is the bare domain name; prepend `wiki/`.)

Don't assume the first word is always a domain — for a cross-cutting design the
first word is part of the slug. Open the matched design and treat it as the
session's anchor. If both interpretations miss, list what you found in the
candidate folders and ask rather than guessing.

**Focus stays the design, never a spoke.** When the Focus is a design (a hub),
the active-claims Focus cell names that **design** and holds it there for the
whole session. I **SHALL NOT** rewrite the Focus to one of its spokes — the
spoke is where today's *work* is, but the **design is the altitude**. Keeping
the design in the Focus cell is what keeps the session on the big picture as the
active spoke moves.

**When I take on a design, READ the design loop and SUMMARIZE it back.**
Whenever I claim a design as Focus (open it), **or** restructure / reorder a
hub's `primary.md` (reordering sections, marking spokes done, trimming the hub),
I **SHALL** first read [`designs-process.md`](designs-process.md) §"The design
loop — behave this way on every design" **and** §"Hub `primary.md` layout
(fractal designs)" — then **reflect a short summary back to the user**: the
verification bar (the hub's `EDD: yes`/`no`), the capture → refactor → re-orient
rhythm, and the rule that the **hub only points to the active spoke** (it does
NOT carry or hint at the "do this next" — that lives in the spoke). Reading-then-
summarizing is the gate: it proves I loaded the convention rather than working a
hub from memory, which is the mistake these pointers exist to prevent. The
layout section defines the ordering (active-spoke pointer at the top, the ordered
spoke list, notes at the bottom) and the rule that ephemeral coordination
(session names, "BLOCKED") stays out of design docs. Every hub stays written to
enable the next agent rather than stall it.

## Sub-CLAUDE.md protocols

- **Do NOT create a new `CLAUDE.md` in a sub-repo or sub-folder unless
  the human asks.** Sub-CLAUDE.md files are *operative* — they encode
  protocol Claude is expected to follow when working in that area. New
  ones proliferate easily and burden every future session with
  discovery + load. The human decides when one is genuinely warranted.
- **Adding or modifying a sema word** → suggest the user run
  `/make-sema-word`. Before any edit, **Read `sema/CLAUDE.md`** and follow
  its protocol verbatim.

## Commit suggestions

Human does all `git commit`s; I suggest at logical units (path-scoped
`git add` + a one-line message) and never `git add -A` while other sessions
may be live (mirror your active-claims Scope). For Karan-style autonomy
(Claude doing commits/merges with merge-safety guardrails) see
`working-with-llms.md` "Karan's commit rules" — reference, not active.

**Never edit or commit locally on a code repo's `dev`/`main`/`master`.**
Cut a `jm/<topic>` branch first, always. This is **absolute** — enforced by
two hard-`deny` PreToolUse hooks (no override): `precheck-protected-branch.sh`
blocks edits, and `precheck-protected-branch-git.sh` blocks history-mutating
git (commit/merge/rebase/reset --hard/branch -f/push --force) while a code repo
is on a protected branch. The **wiki is exempt** — editing `wiki` on `main` is
normal. Before any first edit in a repo, check `git -C <repo> branch
--show-current`; if it is protected, branch before touching anything.

## Linear issue tags

**Keep Linear ↔ wiki in sync** — reconcile at session start and after any
Linear-UI edits: run the bijection sweep + `tools/linear-snapshot.sh` and fix
drift (routine + cadence in `linear.md` "Keeping in sync"). When you rename,
rename both sides — the wiki file is the canonical slug.

**Log hours on completion** — when a substantial task or design wraps, add an
hours note to its Linear issue (total + a brief per-day breakdown) **and** a
Harvest entry (a churn/scope estimate from the wiki commits, via the `hv`
workflow). Confirm the hours with the user before posting to Harvest — it's
billable.

When creating a Linear issue, **first review the existing label set**
(`list_issue_labels` on the **Ops** team) and reuse a fitting tag; coin a new
one only after a moment's deliberation — tags proliferate easily, and the
**live Linear set (not the wiki) is the source of truth** (the MCP is
create-only for labels, so the wiki deliberately keeps no glossary). Tags
cluster on five axes: house · component/domain · work-kind · cross-cutting ·
effort. Two integration-specific tags: **`design`** ↔ a `wiki/**/designs/`
file (the bijection), and **`nit`** = sub-threshold software not worth a wiki
design (so `nit` and `design` are mutually exclusive); **`bite-size`** is a
small effort that **may** still be a design. Full convention in
[`linear.md`](linear.md).

**Reflect on labels on *every* issue create — not from memory.** I call
`list_issue_labels` (Ops) each time and tag across the **relevant axes** — at
minimum a **component/domain** tag *and* a **work-kind** tag, not just one. A
`design` also gets its component (`gwbase` / `scada` / `ltn` / …); a `nit` also
gets component + work-kind (`testing` / `ci-cd` / …). Tagging on a single axis
(e.g. just `design`) is the defect this rule exists to prevent.

**No issue-to-issue relations.** I **SHALL NOT** add Linear issue relations —
not `blocks`/`blockedBy`, not `relatedTo`, not `duplicateOf`, nor any other
issue-to-issue link — via the MCP or otherwise. These links proliferate and
tangle the graph; the human curates relations by hand. I MAY *remove* a
relation when asked. Dependencies and context belong in the issue **description
prose** (e.g. "blocked from merge until gridworks-base 0.5.x publishes"), not in
a relation edge.

**Shared-dependency work earns its own flat Linear issue.** When a sizable chunk
of work is depended on by **two or more** larger designs, it becomes its **own**
issue + design — never a sub-issue of either. Two reasons: it keeps Linear **flat**
(no sub-issue trees, no tangled relations — composes with *No issue-to-issue
relations* above: the dependents reference it **by name in their description
prose**, not by a relation edge); and it stays **explainable to the team** —
"here's one thing we did, referenced from these two big functional issues." Scope it
generously enough to absorb honest creep (a "pass-one" framing both bounds the work
and signals a later pass), so the shared piece is one coherent, closeable unit
rather than a litter of tiny adjacent issues.

## Working-tree hygiene

Code-repo edits are organised into **clusters**: one pending changelog
entry (`<!-- pending commit -->`) in `wiki/<domain>/changelog.md` = one
cluster. Wiki changes are not cluster-checked. **Changelogs are a
per-domain artifact only** — cross-cutting wiki folders (`wiki/designs/`,
`wiki/tests/`, `wiki/tools/`, etc.) SHALL NOT have their own
`changelog.md`; wiki-convention changes live in git history only. Enforced structurally by
hooks in `tools/` — `precheck-pending-changelog.sh`,
`precheck-claim-on-dirty.sh`, `precheck-bulk-on-dirty-tree.sh`,
`stop-cluster-coherence.sh`. If a hook fires, cache any in-flight plan
to a scratch note before pivoting and surface the state to the user;
disposition is theirs. Before more than ~5 file edits in one cycle, I
SHALL ask whether to enable `bulk-on` for the burst. The user creates
`~/.claude/.bulk-stop-override(.<session>)` via `bulk-on` to silence
the hooks; I MUST NOT create that file myself.

## Wiki essentials (the wiki's authoring conventions)

**Structure** — each top-level `wiki/<domain>/` is a service/mechanism/design
area. Within a domain: `research/` (pre-spec notes, not normative), `executor/`
(the **faithful-rebuild spec** — complete enough to rebuild the domain from the
docs alone), and `changelog.md` (one entry per commit **in the corresponding
code repo**; code-repo git = the *what*, changelog = the *why*). Wiki edits
live in the wiki repo's own git history, not here.

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
  entry before considering the work done.** See *Commit + changelog
  convention* below for the entry shape and verification requirement.
- A spec may say "Open" and may change — a short, honest, current spec beats
  a long speculative one.
- Holistic consistency pass at milestones.

**Commit + changelog convention:**

- Code-repo git commits SHALL be **title-only** — a single concise
  summary line, no body. The diff is the authoritative *what*.
- The corresponding `wiki/<domain>/changelog.md` entry SHALL contain
  a brief *what* and the *why*. Date + title mirror the code-repo
  commit (`code-repo git = the pointer; changelog = the narrative`).
- **Before writing a changelog entry, you SHALL verify it against
  the actual diff** (`git show <hash>` in the code repo), not your
  memory of the change.
- Pending entries (`<!-- pending commit -->`) get written ONLY when
  the next planned commit is in the **code repo**. Wiki-only edits
  earn no pending entries.

**Where to start** — `executor/` specs are a work in progress across every
domain. When a repo has substantial code but a poor/missing `executor/`, the
highest-value first move is to bring its `executor/primary.md` to an
**acceptable minimum** (overview + invariants + glossary + TOC), marking the
rest "Open." Acceptable-minimum first, depth later.

**Where content lives across designs / explorations / executor / Linear** —
the canonical disambiguation is in [`glossary.md`](glossary.md) "Where
content lives". The discriminator is clarity, not "architectural":
open architectural *questions* live in `explorations/`; settled
architectural *patterns* live in `executor/`; ratified change plans
(full content) live in `designs/`; workflow state (status / owner /
priority) lives in Linear.

**Design-specs (`designs/`)** — ratified design-specs live in
`wiki/<domain>/designs/<slug>.md` (per-domain) or `wiki/designs/<slug>.md`
(cross-cutting / tooling). A single fixed location per design; files do
NOT move between folders as status changes. **Linear is the authority on
status** (backlog / todo / doing / done). Designs are tracked as **Ops-team
issues tagged `design`**. A design **MAY** enter Linear at Draft (sitting in
**Backlog**) and **MUST** be in Linear once **Accepted** (moved to **Todo**);
see [`linear.md`](linear.md). **Create a design issue with its assignee
(default: me), state, and priority set** — a hook blocks a `design` create
that omits them — and **move it to In Progress when you start executing it**.
The focus
**cap-8** is a **personal WIP limit** — at most 8 issues assigned to you in a
*started* state — not a count of designs in "doing". Each design file MUST carry
a status stamp; `Accepted` maturity requires `Pass ≥ 1`, and an Accepted
design's stamp MUST carry its `· Linear: <id>` (all enforced by
[`tests/test_doc_health.py`](tests/test_doc_health.py)). On completion,
the design's durable distillate updates `executor/primary.md` (or a
sub-spec); the `designs/<slug>` file is deleted. **The same completion step
SHALL finalize the Linear issue:** (1) **strip the now-dangling design
hyperlink** from the issue description (the file is gone — the link would rot,
per the no-links rule below), (2) **add a short final-writeup comment** — what
shipped, where the distillate now lives (`executor/…`), and any carried-forward
caveat (e.g. an interim hack's revert condition) — so the issue stays the
durable workflow record after the file is gone, and (3) move it to **Done**.
**Because designs are
ephemeral — deleted on completion — NOTHING SHALL link to OR name a design
*file*** (a markdown link to a `designs/` file rots into a dangler the moment
that design is deleted; a name-in-prose mention rots the same way for a reader).
A wiki doc references only durable records — `executor/` specs, code,
research/explorations, external refs, **and Linear issues** (an issue URL like
`https://linear.app/gridworks/issue/OPS-407` is **immutable even as status
changes** — hyperlink it in **human-facing prose**; Claude/tooling bookkeeping
(`DESIGN_INDEX.md`, the triage worklist, Status-line stamps) keeps the bare
`OPS-NNN`). So express a **cross-design / cross-work
relationship** by pointing at the other work's **Linear issue**, not its design
file; the richer relationship narrative (depends-on, sequencing, gated-by, folds,
supersedes) also lives in Linear (the issue description, which may reference
other issues). The sole exception is
[`DESIGN_INDEX.md`](DESIGN_INDEX.md), the aggregator that indexes every
design by definition. Per-domain `findings.md`
registers are legacy and SHALL NOT be created in new domains — items
become Linear issues (if actionable work), become `explorations/`
entries (if there's no clarity yet), or update `executor/primary.md`
(if they're durable facts about the domain). Full convention in
[`designs-process.md`](designs-process.md); Linear interface in
[`linear.md`](linear.md);
live aggregated view in [`DESIGN_INDEX.md`](DESIGN_INDEX.md).

**Implementation gate** — a design SHALL NOT begin implementation
(code-repo edits matching its scope) until **every spoke** of the
design — `primary.md` and all sub-specs in its folder — is at
`Accepted` maturity with `Pass ≥ 1`. The hub-and-spoke pattern
explicitly permits hub > spoke maturity during drafting (e.g. an
Accepted `primary.md` with Draft sub-specs while individual sub-specs
catch up — the doc-level *floor* rule applies within a doc, not
across the hub-spoke relationship); the implementation gate is the
moment everything must converge. Rationale: writing code against a
Draft spec is the antipattern this convention exists to prevent.

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

**Voice** — wiki prose is Jessica's voice: plain sentences she can align
to. DO NOT use the AI-cadence drumroll — an em-dash setup resolved by a
punchy verdict fragment ("there are only two honest options — X, or Y.
No incremental third path."). Same family, also banned: ", full stop",
"— X edition", one-fragment verdict sentences, antithesis flourishes
("saves bytes, never trust"). Say the thing as an ordinary sentence.
Her verbatim phrases stay verbatim. **Do NOT attribute notes, decisions,
or quotes to the specific human developer by name and date** — no
"(Jessica, 2026-06-14)", "Jessica's bar", "Raised … (Jessica)". Wiki prose
is the project's settled voice: state the decision or fact as the
project's own. A bare date is fine when genuinely useful; the name is not.

**Sema-typed JSON files** — on-disk JSON instances of a Sema type SHALL
be named `<sema-type-name>.json`, where `<sema-type-name>` is the Sema
`TypeName` verbatim with dots preserved (e.g. `g.node.gt.json`,
`weather.channel.json`, `synced.readings.bundle.json`). NOT
`g_node_gt.json` (Python-style transformation) and NOT `g_node.json`
(half-snake legacy). The dot↔underscore transformation belongs at the
code boundary only — Python module names for the same type stay
snake-cased per Python convention (`g_node_gt.py`).



## ⏳ Until the proactor port — sema words are FLAT (REVERT note)

**Temporary clarification (added 2026-06-12; revise when the proactor
replacement lands and the scada's gwsproto is regenerated flat).** Sema
vocabulary words do **NOT** inherit from one another — every type schema is
**flat**, every field spelled out explicitly. The scada `gwsproto` types
*pretend* sema types inherit (base classes `ComponentGt`,
`ComponentAttributeClassGt`, `ChannelConfigBase`); **that is a flaw**, not a
pattern to mirror. When authoring a sema type from a gwsproto class, **flatten**
the base-class fields into the type and reference other sema words only by
`$ref` composition (e.g. a `ConfigList` of `channel.config`). Do **not** fix the
gwsproto inheritance now — it gets swept up in the proactor port. Remove this
note once that port regenerates gwsproto flat.
