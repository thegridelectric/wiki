# Concern: integrate the two sema CLAUDE.mds (dev-lens + effortless-lens)

Status: Draft · Pass 0 · Updated 2026-05-26

> Sema currently carries two Claude-orienting documents that frame the
> project through different lenses. They are not contradictory but they
> are not unified. This concern captures the tension and the open
> questions; ratification is deferred until the YAML→rulebook migration
> phase mapping is firmer.

## What landed in this session

As of commit `5fc0d94` ("swap claudes") on the `jm/effortless` branch:

- **`sema/effortless_CLAUDE.md`** is committed and shared (the ERB lens —
  ej's framing).
- **`sema/CLAUDE.md`** is **gitignored** (`.gitignore` line `CLAUDE.md`)
  and is a per-developer personal-local lens. Jess's local copy carries
  the dev-branch sema-vocabulary framing (`spec/primary.md` + per-word
  YAML, `/make-sema-word` ritual, axiom/registry invariants).
- The team-shared file at the explicit name `effortless_CLAUDE.md`,
  combined with the gitignore on the default name, mechanically enables
  the two-lens shape: every dev keeps a personal lens at the default
  path without colliding with the team-shared one.

## The two lenses

### Effortless lens (`effortless_CLAUDE.md`, committed)

- **SSoT** is `effortless-rulebook/effortless-rulebook.json` (hand-edited).
- **Pipeline:** rulebook → `effortless build` → postgres SQL → views.
- **Invariants:** never edit generated `postgres/0[0-5]*.sql`; read
  from `vw_*` views, write to base tables.
- **Workflow:** `effortless build` sandwiched by clean-tree commits;
  build commits contain *only* generated output (the "bright red line").
- **Skill set:** `effortless-*`.
- **Path the migration plan steers toward** (Phase 3 cutover).

### Dev lens (gitignored `CLAUDE.md`, personal-local)

- **SSoT** is `spec/primary.md` + per-word `definitions/*.yaml`.
- **Invariants:** preserve `TypeName` + `Version`; formats immutable;
  enums additive-only; no edits to historical versions; pass `pytest`
  and registry validation.
- **Workflow:** `/make-sema-word` for additions / modifications; regen
  via `scripts/build_indexes.sh` and `scripts/regenerate_runtime.py`.
- **Skill set:** none specific — generic sema vocabulary tooling.

## Tension

Both files claim authority over sema with different SSoTs and
different rituals. They are not contradictory at the *invariant* level
(both want `TypeName`/`Version` preservation, additive enums, immutable
formats) — those are sema-language invariants, not lens-specific. They
diverge on *which artifact is authored directly*:

- Effortless lens: edit `effortless-rulebook.json`.
- Dev lens: edit `definitions/*.yaml`.

The YAML→ODXML→RULEBOOK migration plan (referenced in the effortless
lens) treats `definitions/*.yaml` as eventually becoming a *downstream
artifact* of the rulebook (Phase 3 cutover). Until that flip lands,
both lenses are live and a sema session can run under either — but not
coherently under both at once.

## Working theses

1. **The .gitignore pattern is intentional, not accidental** — it
   should be documented as a protocol, not left implicit. Future
   contributors should know that `sema/CLAUDE.md` is a personal
   override slot, not a missing or forgotten file.
2. **Universal invariants belong at the top of whichever CLAUDE.md is
   active** (preserve `TypeName`+`Version`, additive enums, immutable
   formats, no edits to historical versions). These are sema-language
   invariants and should appear *once*, not lens-duplicated.
3. **Migration phase maps to which lens binds.** Pre-Phase-3 (YAML is
   HEAD): vocabulary lens is authoritative for vocab edits.
   Post-Phase-3 (rulebook is HEAD, YAML emitted): effortless lens is.
   The transition point is the moment YAML stops being HEAD.
4. **`/make-sema-word` survives the cutover** — same slash command
   name, body migrates from YAML edits to rulebook-row edits with the
   same universal invariants. Worth testing the prompt against both
   shapes early so the cutover doesn't surprise.

## Open questions

- **Should the two lenses ever merge into one?** Or is the two-lens
  shape itself the right end-state — different devs work under
  different frames, both valid?
- **If they merge:** which becomes the single CLAUDE.md, and when?
  Probably effortless wins post-Phase-3, but worth confirming.
- **If they don't merge:** how do we document the pattern so a new dev
  doesn't accidentally edit `effortless_CLAUDE.md` thinking they're
  customizing their personal lens?
- **Cross-session coherence.** Should the gitignored `CLAUDE.md`
  reference `effortless_CLAUDE.md` and pull in its universal invariants
  by reference? Or duplicate them inline (today's state)?
- **The `/make-sema-word` body migration.** Does its prompt template
  need rewriting before Phase 3, or can the slash command stay
  identical and the underlying tools change shape?

## Why this stays a concern, not a design

The shape that resolves the tension depends on facts we don't have
yet:

- Whether Phase 3 (YAML→rulebook cutover) lands cleanly or stalls.
- Whether other devs adopt the two-lens pattern or all converge on one
  lens.
- Whether `/make-sema-word` evolves substrate-agnostically or
  bifurcates into two rituals.

Ratifying now would invent a structure that the migration may obsolete
within months.

## Trigger conditions to graduate to a design

- Phase 3 cutover scheduled or executed — at that point, the migration
  mapping graduates from speculative to concrete.
- A second dev (beyond jess + ej) joins the project and asks "which
  CLAUDE.md do I read?" — the question forces a documented answer.
- A `/make-sema-word` modification lands that has to choose between
  the two lenses — concretizes the ritual-migration question.

## Related

- `sema/effortless_CLAUDE.md` (committed) — the ERB lens.
- `sema/CLAUDE.md` (gitignored) — the personal-local lens (jess's
  current copy: dev-branch vocabulary frame).
- `sema/YAML-ODXML-RULEBOOK-MIGRATION-PLAN.md` — the substrate
  migration plan.
- [`research/erb-md-mirror.md`](../erb-md-mirror.md) — bijective MD↔ERB
  proposal (orthogonal to the CLAUDE.md question but bears on the
  authoring-surface question).
