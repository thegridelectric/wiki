# Design: practice ERB pair-programming before resuming the ERB↔Sema audit

Status: Draft · Pass 0 · Updated 2026-05-26

> A focused setup-and-practice arc to give jess firsthand experience of
> the ej+Claude rapid-rulebook loop **before** continuing the open audit
> threads (F5 TypeHelpers alignment, F6 Templates table, axiom-DSL
> feasibility, round-trip empirical run). Most of the setup has already
> landed in this session; the design captures the remaining shape and
> the exit criterion.

## TL;DR

- The strong CMCC thesis and the synergy proposal both implicitly assume
  the ej+Claude workflow is real and reproducible. Until jess has
  independently experienced it, evaluating those claims is reasoning
  about ergonomics she hasn't felt.
- **Pre-audit practice is faster than post-audit retro.** A few hours
  pair-programming on small rulebook touches builds the calibration
  needed to interpret the audit findings correctly. Doing the audit
  first risks anchoring on the wrong cost model for ej's pipeline.
- The setup is largely done in this session: effortless CLI installed,
  effortless-rulebook on the `jm/effortless` branch, local Postgres
  mirror (`sema-pg` on :5434, harmonized away from `gw-data-pg`'s :5433),
  Postico configured. The remaining work is the practice itself.

## Setup status (as of 2026-05-26)

- ✅ `effortless` CLI present (`2025.11.06.1225`).
- ✅ Local Postgres mirror up — `sema-pg` on `:5434`, schema initialized
  via `postgres/init-db.sh`. Coexists with `gw-data-pg` (`:5433`) and a
  native Homebrew Postgres (`:5432`).
- ✅ Postico 2 installed + connected to the local mirror.
- ✅ Branch shape: `jm/effortless` off `ej-dev`. Port move and "swap
  claudes" rename landed there.
- ✅ Local `sema/CLAUDE.md` (gitignored) running the dev-lens
  vocabulary-author frame; team-shared `effortless_CLAUDE.md` carrying
  ej's ERB-pipeline frame. See
  [`research/concerns/two-claudes.md`](../research/concerns/two-claudes.md).
- 🟡 **Effortless MCP server** — not yet wired into Claude Code. The
  user-level `~/.claude.json` does not include `effortless-mcp`. Deferred
  because the practice doesn't strictly need it; useful later for
  queryable rulebook tooling from inside other agents.
- 🟡 **One full ej+Claude loop turn** — not yet executed. Was scoped to
  Words→Types in the web app but the rename specifically is now scoped
  separately (see
  [`web-app-words-to-types.md`](web-app-words-to-types.md)). Practice
  goal is a *different* loop turn (see Exit criterion).

## What practice means here

A "loop turn" is the full cycle:

1. Identify a small change in the rulebook (add a field, fix a
   description, add a row, tighten a formula).
2. Edit `effortless-rulebook/effortless-rulebook.json` directly.
3. Run `effortless build` — watch SQL regenerate, Postgres reinit,
   views update.
4. Observe the change downstream: in Postico (`vw_*` views), in the API
   (`/api/...` response shape), and in the dashboard if applicable.
5. Commit (rulebook change + generated output as separate commits per
   the effortless_CLAUDE.md "bright red line").

What we're trying to internalize:

- **The action loop** — how much of the cycle is mechanical vs.
  judgment.
- **The prompt shape** — how ej drives rulebook edits via Claude (or
  hand-edits), what the model lands first-try vs. needs nudging on.
- **The structured action-space** — calc-fields, OpKind enums, FK
  columns, etc. — and how it constrains LLM output into something
  schema-valid.
- **The failure modes** — what does it feel like when a rulebook edit
  produces bad SQL, broken FKs, or a snapshot-format diff that fights
  a consumer's pre-commit.

## Out of scope for this design

- The audit itself (F5, F6, axiom-DSL feasibility, round-trip
  empirical). Picked up *after* practice converges.
- The Words→Types refactor — separate design, separately scoped.
- Any structural rulebook changes that aren't reversible — practice is
  on changes we'd be happy to revert.

## Exit criterion

Jess has driven **at least one full loop turn end-to-end** on the local
mirror (rulebook edit → `effortless build` → observed downstream in
Postgres + API + dashboard if relevant → commit), and can articulate:

1. Which parts of the cycle were ergonomic vs. friction.
2. Where Claude added leverage vs. where she would've been faster solo.
3. Whether the structured action-space did the work it's claimed to
   (LLM output landing first-try because the schema constrains shape).

Once that's true, this design is "shipped" — its distillate is
"practice happened; audit can proceed on calibrated ground" (one line
in `executor/primary.md` if it stays load-bearing, else nothing).
Linear closes; design file deletes.

## Open

- **Which rulebook touch to use for the first turn.** Options
  considered: (a) extend `cli_commands` / `cli_flags` to capture
  examples for the bare commands that currently have `example_count=0`;
  (b) add a new tag-style field somewhere lightweight; (c) fix a
  description typo. (a) gives the most signal because it exercises a
  table with relationships and a downstream API; (c) gives the least.
- **MCP server wiring.** Worth doing now or after practice converges?
  Argument for now: more tools = more realistic ej+Claude experience.
  Argument for later: keeps the variable count low, isolates "did the
  loop work because of the loop or because of the MCP tooling."
