# design-execution-economics

Status: Accepted · Pass 1 · Updated 2026-06-08 · Linear: OPS-382

> What this is: a deterministic **subagent-spawn nudge** (a PreToolUse hook)
> that pushes design *execution* toward economical LLM-resource use — tighter
> spawn prompts and coupling-aware fan-out — at the moment work is delegated.
> Cross-cutting/tooling design; companion to
> [`working-with-llms.md`](../working-with-llms.md) and
> [`designs-process.md`](../designs-process.md).

## Problem

Executing a design burns LLM resources two avoidable ways. Both surfaced
concretely in the `sema/snapshot-improvement` execution (session
stalwart-frost), which is the genesis case:

1. **Over-broad delegation prompts.** An `Explore` agent was asked to map
   "the pipeline" and returned an exhaustive map of the *entire sema snapshot
   subsystem* when only ~40% was load-bearing for the edits. The waste was
   depth-within-one-subsystem, not breadth across GridWorks — the spawn prompt
   should have scoped to "the codec ↔ snapshot round-trip path," not "the
   pipeline." That full map then sits in context for the rest of the session
   whether or not it's reused.

2. **Independent work done inline in a heavy context.** The same session's
   thread #4 was a 20-example backfill — 20 *independent* "author one example
   against one schema" tasks with a central validation gate. That is a
   textbook fan-out (`Workflow` pipeline, or a fresh lean session), but the
   original plan ran it inline in an already-past-halfway context, inheriting
   front-loaded research it didn't need.

The shared root: **at the moment of delegating, the session doesn't pause to
ask "is this prompt as tight as it can be?" and "is this coupled-sequential
work, or independent fan-out that belongs elsewhere?"** A deterministic hook
can inject that pause exactly when a subagent is spawned.

## Goal

A `PreToolUse` hook on the subagent-spawn tool that injects a short,
standardized reminder to:

- **Scope the spawn prompt to the load-bearing slice** — request the specific
  files/answers needed, name the boundary ("only the X↔Y path"), and tell the
  agent to return conclusions, not file dumps.
- **Check coupling before going inline** — if this is one of N independent
  tasks sharing no state, prefer a `Workflow` fan-out or a fresh lean session
  over inline sequential work; reserve inline for tightly-coupled work that
  shares one mental model.

The nudge is **generic guidance fired at the right moment**, not a smart
detector of waste — the hook cannot read intent. Its value is the
well-timed pause, the way `precheck-*` hooks add a pause at their moments.

## Mechanism (chosen direction)

- **Event:** `PreToolUse`, `matcher: "Agent"` (the subagent-spawn tool). *(R1)*
- **Form:** advisory via `hookSpecificOutput.additionalContext` with
  `permissionDecision: "allow"` — injects the reminder into context **without**
  forcing an approval prompt. *(R2)*
- **Signal available:** the hook's `tool_input` carries `prompt`,
  `description`, `subagent_type`, and optional `model` — enough to key
  dampeners off both the spawn prompt text and the agent type. *(R3)*
- **Location:** `wiki/tools/spawn-economy-nudge.sh` (named *not* `precheck-*`
  — that prefix reads as a blocking gate in this repo, and this never blocks;
  mirrors advisory `sema-claim-context.sh`). Wired in `.claude/settings.json`
  under `PreToolUse` `matcher: "Agent"`. Honors the standard
  `~/.claude/.bulk-stop-override(.<session>)` silence convention.

## Implementation status (2026-06-08)

Built + wired. Hook `wiki/tools/spawn-economy-nudge.sh` passes an 8-case unit
matrix (fires on Explore/general-purpose/Plan or a broad-scope keyword; silent
on repeat via the once-per-session marker; a narrow spawn doesn't consume the
nudge; ignores non-`Agent`/non-`PreToolUse`; word-boundary guard so
`install`/`wallpaper` don't trip `all`/`map`). **One item left for `Verified`:**
confirm in a *live* session that `PreToolUse` `additionalContext` with
`permissionDecision: "allow"` actually lands in the model's context (the field
is comparatively new — see R2). Settings changes typically take effect on the
next session, so live confirmation comes then. On confirmation → bump to
Verified, distil the durable note (the hook + its header are largely
self-documenting; a one-liner may go to `working-with-llms.md`), then delete
this design and close OPS-382.

## Resolved (claude-code-guide, 2026-06-08)

- **R1 — tool name** is `Agent` in this harness's hook matchers (not `Task`).
- **R2 — advisory delivery** `PreToolUse` *does* support
  `hookSpecificOutput.additionalContext`; emitting it with
  `permissionDecision: "allow"` is non-blocking. (Verify live once at
  implementation — this field on `PreToolUse` is comparatively new.)
- **R3 — payload fields** confirmed: `prompt`, `description`, `subagent_type`,
  `model?`.

## Design decisions (resolved in grill, 2026-06-08)

- **O3 — once-per-session, gated to relevant spawns.** Fire at most
  once per session (marker `~/.claude/.spawn-nudge.$SESSION_ID`, mirroring the
  `.session-by-id` / `.bulk-stop-override.<name>` precedent), spending the one
  fire on the first spawn that is plausibly broad: `subagent_type ∈
  {Explore, general-purpose, Plan}` **OR** `prompt` matches broad-scope
  keywords (`map|all|every|comprehensive|full|entire`). No length threshold
  (weak signal). Rationale: the nudge is a principle-level *frame*, set once
  early; this also avoids injecting it N× across a legitimate parallel
  fan-out. Accepts the trade that a late broad spawn after the one fire goes
  un-nudged (consistent with O6 — not a babysitter).
- **O5 — spawn-hook-only.** The design-start / Linear-In-Progress
  nudge stays **deferred** (see Deferred below). The spawn hook already carries
  both prongs at the recurring, natural decision point (every delegation), and
  the genesis pain was all at spawn time, not design kickoff. Ship + validate
  the smaller surface first; revisit the design-start nudge only if the spawn
  hook proves insufficient.
- **O6 — pure advisory, never blocks.** A block needs confident
  detection of waste, but a single `Agent` payload can't reveal the
  cross-spawn intent (N independent tasks) that fan-out targets — any block
  fires on a keyword proxy with many legitimate uses, training reflexive
  approval and eroding the bright line that gives the real `precheck-*` blocks
  their teeth. Coupling enforcement is the human's call, not a shell script's.
  The hook only ever emits `additionalContext` with `permissionDecision: "allow"`.

## Deferred (not this build)

- **Design-start nudge** — a second hook on Linear `save_issue` → In Progress
  that prompts a coupled-sequential-vs-fan-out decomposition at design kickoff.
  Deferred per O5: lower-yield (rarer event, the genesis pain was at spawn
  time) and doubles the tuning surface. Revisit only if the spawn hook proves
  insufficient in practice.

## Non-goals

- Measuring context-window load (hooks can't see token counts reliably).
- Auto-converting inline work into a Workflow — the hook recommends; the
  session decides.
- Replacing human judgment on coupling — the nudge prompts the question, it
  does not answer it.

## Genesis receipt

- `sema/snapshot-improvement` execution, session stalwart-frost, 2026-06-08:
  Explore over-depth on the sema-snapshot subsystem (~60% unused), and the
  thread-#4 20-example backfill identified mid-execution as belonging in a
  fan-out / fresh session rather than inline. The recommendation made there —
  pull thread #4 into a `Workflow` run from a lean session — is the canonical
  example this hook exists to prompt earlier.
