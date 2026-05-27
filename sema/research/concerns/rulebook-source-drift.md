# Concern: how does the rulebook stay coherent with source it describes?

Status: Draft · Pass 0 · Updated 2026-05-26

> The rulebook contains tables that *describe code* (`cli_commands`,
> `cli_flags`, `cli_examples`, possibly more). Today those rows are
> hand-authored to mirror source under `src/sema/interfaces/cli/`.
> Nothing automatic keeps them in sync. This concern captures the
> pattern + the direction question: who generates whom, and how is
> drift caught?

## What we observed this session

Walked `cli_commands` against the actual CLI tree (`grep` of
`argparse.add_parser` calls). They matched exactly:

- 9 rulebook rows ↔ 9 CLI nodes (`sema`, `info`, `reverse`,
  `runtime`, `runtime scaffold-axiom-template`, `runtime
  scaffold-upgrade-template`, `snapshot`, `snapshot prepare`,
  `snapshot build`).
- `parent` fields matched the argparse tree.
- `impl_file` paths matched (all `src/sema/interfaces/cli/{main,reverse,runtime,snapshot}.py`).
- `child_count` calculated-field values matched the source.
- The `sema` row's description ("four subcommand groups (info,
  reverse, runtime, snapshot)") matched the actual subparser shape.

No drift detected. **But** the audit was a manual SQL-vs-grep walk;
nothing prevents future drift.

## The architectural question

The rulebook holds "what is the CLI?" as queryable data. The CLI
itself is argparse code. Both claim to be true. Today they agree, but
agreement is by manual maintenance — when ej (or a future contributor)
adds a CLI command, they must also add a `cli_commands` row, plus
matching `cli_flags` and `cli_examples` rows. Nothing in the build
catches the omission.

There are three possible end-states:

### (A) Code is canonical, rulebook is a mirror (status quo)

- Rulebook rows are documentation-as-data.
- Drift detection runs in CI / a sema check command.
- Affordances: queryable docs, dashboard rendering, MCP tool surface
  for other agents.
- Cost: every CLI change is a two-step (source + rulebook).
- Catch mechanism needed: `sema check cli` or similar, comparing
  rulebook to argparse introspection.

### (B) Rulebook is canonical, code is generated

- The rulebook drives a `rulebook-to-python` (or similar) transpiler
  that emits `src/sema/interfaces/cli/*.py`.
- One-step CLI changes: edit the rulebook, build regenerates code.
- Cost: argparse-shaped logic constrained to what the transpiler can
  express. Custom handler bodies still hand-written somewhere; the
  generated layer is the *parser*, not the *handlers*.
- Affordances: drift impossible by construction.

### (C) Code is canonical, rulebook is generated from code

- A reverse-direction tool introspects the argparse tree and emits
  rulebook rows.
- One-step CLI changes: edit code, regen pulls rulebook rows from
  source.
- Cost: rulebook is no longer the authoring surface for CLI metadata
  — descriptions, examples must be authored *somewhere* (docstrings?
  annotations?) and pulled.
- Affordances: drift impossible by construction *in the reverse
  direction* — anything the introspector can see stays in sync.

## Tensions

- **(A) is the only path that works today.** Both (B) and (C) require
  building tools that don't exist; (A) requires only writing a check.
- **(B) is the effortless / CMCC end-state.** "The rulebook is the
  SSoT for everything that's true about sema." Including its CLI.
  But: this presupposes the CLI is structurally simple enough to
  generate. Handler bodies (actual functionality) stay code; only the
  parser shell is generated.
- **(C) keeps code as the source of authoring** but loses the
  rulebook's queryability for free-text fields (descriptions,
  examples) — those have to live somewhere accessible to the
  introspector.
- **(A)+(C) hybrid** is possible: code is canonical, an introspector
  catches structural drift (commands, parent relationships, flag
  presence), and free-text fields stay rulebook-authored (descriptions,
  examples) with a manual reconciliation step.

## The bigger question this gestures at

`cli_commands` is one example. What other tables in the rulebook
*describe code that exists elsewhere*?

- `emitters` — probably describes transpiler / emitter modules.
- `index_builders` — probably describes index-build entry points.
- `feature_bindings` — possibly describes feature-flag wiring.
- `seed_request_entries` — describes seed-request file structure.

Any rulebook table whose rows mirror code structures faces the same
question. **The drift question generalizes; the answer should too.**

## Working theses

1. **Stay on (A) for now.** Build a `sema check` mode that audits
   rulebook code-describing tables against introspectable truth.
   Catches drift; cheap to write; no new build-pipeline surface.
2. **Treat (B) as the long-horizon goal** consistent with the
   effortless CMCC bet, but don't pre-build it.
3. **The check itself is the design artifact.** When (B) is ready
   (transpiler exists, argparse generation is feasible), the check
   becomes obsolete and gets deleted; until then, it's the
   load-bearing thing.

## Open questions

- **Which tables count as "code-describing"?** Beyond `cli_commands`
  / `cli_flags` / `cli_examples`, which others mirror source structure
  (vs. being pure ontology)?
- **What does `sema check` look like?** A separate CLI command? A
  build-step hook? A pytest fixture?
- **Reverse population.** Could a one-shot tool import the current
  argparse tree into the rulebook to seed `cli_commands` on first
  setup, freeing ej from hand-authoring? Worth scoping if it's a
  morning of work.
- **Description authoring.** If we move (B), where do command
  descriptions and examples live? In the rulebook (hand-authored
  there)? In docstrings (pulled by the transpiler)? Both with
  reconciliation?

## Why this stays a concern, not a design

The right answer depends on facts not yet decided:

- Whether sema commits to (B) as part of the YAML→rulebook migration
  or scopes it out.
- Whether other code-describing tables exist and share the same
  resolution.
- Whether ej has an existing convention (docstrings, decorators)
  that biases (B) or (C).

## Trigger conditions to graduate to a design

- A real drift incident — someone adds a CLI command without
  updating `cli_commands`, the dashboard or MCP surface shows
  stale info, and we want a structural fix.
- Sema commits to a `rulebook-to-python` CLI transpiler (option B)
  as part of Phase 2 or Phase 3 of the migration plan.
- Audit of other code-describing tables (`emitters`, `index_builders`,
  …) surfaces the same drift question and we want one resolution.

## Related

- `sema/src/sema/interfaces/cli/` — the code side of the
  cli_commands example.
- `effortless_CLAUDE.md` — the effortless-lens framing where
  rulebook-as-SSoT motivates (B).
- [`research/erb-md-mirror.md`](../erb-md-mirror.md) — the
  bijective-MD proposal touches similar code-gen-direction questions.
- [`research/erb-no-degradation-audit.md`](../erb-no-degradation-audit.md)
  — the audit items (F5, F6, axiom-DSL feasibility) feed into the
  feasibility of (B) more broadly.
