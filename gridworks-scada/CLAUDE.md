# gridworks-scada — Claude protocol

Status: Draft · Pass 0 · Updated 2026-07-04

> What this is: the operative rules for sessions editing the `gridworks-scada`
> repo (gwsproto above all). Pointed to from `GridWorks_CLAUDE.md` "Domain
> protocol files" — Read this BEFORE the first scada edit of a session. Lives
> in the wiki (all LLM-facing material does); the code repo carries no
> CLAUDE.md.

## ⏳ Until spruce-unlimbo lands — work on `jm/spruce-unlimbo` (REMOVE when the epic is done)

Scada work lands ON `jm/spruce-unlimbo` — the epic integration branch; the
layout-pipeline rework lives there and downstream work depends on it. Cut a
topic branch only for genuinely parallel or experimental work, off
`jm/spruce-unlimbo` (never `dev`/`main`), and fold it back promptly. Do NOT
stack topic branch on topic branch. (Added 2026-06-12; enforced form
2026-07-04.)

## ⏳ Terminalasset plant simplicity (REVERT when the sim plant MVP works)

Keep the terminalasset plant as simple as possible while it still works well
with the scada code, and no simpler. When in doubt, err simpler and leave a
question for Jessica. (Added 2026-06-12; reversion tracked at the end of the
simulated-test-environment design's `primary.md`.)

## gwsproto rules

- **Serialize with `model_dump(by_alias=True)`.** gwsproto named-types define
  snake_case python fields with `alias_generator=snake_to_camel`; the
  PascalCase wire names are pydantic aliases. Plain `model_dump()` emits
  snake_case, and decode tolerance (`populate_by_name=True`) hides the
  mistake. PascalCase-native types (e.g. `g.node.gt`) are unaffected; the
  bite is on snake-field types (the Hubitat poller, `maker.api.attribute.gt`).
- **Sema-type docstrings are `Sema: <schema_url>` and NOTHING else.** No
  value enumerations, no links, no prose — that duplicates the schema, the
  single source of truth. Do not reintroduce stripped blocks on regen.
- **Mirror sema axioms as `check_axiom_<n>` methods** —
  `@model_validator(mode="after")`, numbered to match the sema axiom numbers,
  raising `ValueError` with `"Axiom <n> (<Name>) failed: …"`. Mandatory even
  for value-range constraints: type the field with the matching sema format
  (`NonNegativeInt`, `PositiveInt`, …) + the axiom method. NEVER a
  `Literal[0,1]`-style bound — it silently drops the axiom. The check lives
  in code, mirroring the sema schema, so the proactor port regenerates it.
- **Validate hand-written types against the canonical runtime** — serialize
  an instance and run `sema validate <payload.json>`; exit 0 = conforms.
  gwsproto types are written by hand, not generated from a snapshot; `sema
  validate` — not any generated copy — is what proves them correct.
