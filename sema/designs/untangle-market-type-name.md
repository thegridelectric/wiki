# Design: Untangle `market.slot.name` → `market.type.name` (format referencing an enum)

> Status: Draft · Pass 1 · Updated 2026-06-07

What this is: the problem statement + analysis for a structural Sema question
surfaced by a gridworks-journalkeeper import failure — **a property format whose
*validator* needs an enum, which the dependency closure can't see.** A direction
is now **ratified** (see *Decision*, 2026-06-07): allow **versioned property
formats**. This file is therefore now the **change plan**; it stays here until the
spec amendment + `market.slot.name` versioning are implemented, at which point the
durable rule folds into the `spec/` (formats authoring + closure) and this file is
deleted.

## The incident

Joe's `gjk` S3 importer crashed decoding an `atn.bid` message
(`ModuleNotFoundError: No module named 'sema.runtime'` / missing `MarketTypeName`).
Layered causes:

1. `atn.bid` (and `bid`, `latest.price`) have a `MarketSlotName` field →
   `$ref` the **`market.slot.name`** format.
2. The `market.slot.name` validator (`is_market_name` in generated
   `property_format.py`) checks the embedded market-type token against the
   **`MarketTypeName`** enum's values.
3. **The closure can't see that edge.** Per spec a format **cannot reference
   other vocabulary** (`authoring/formats.md:16`), so the dependency is *not* a
   `$ref` — it lives only in validator code. `sema snapshot prepare`'s transitive
   closure follows `$ref` edges, so it never pulled `market.type.name`, and the
   enum was absent from the consumer snapshot.
4. Two follow-on mechanics bugs: the format template hardcodes
   `from sema.runtime.enums import MarketTypeName` (`templates/format.py:144`)
   instead of `import_root` (so even once vendored, the import was wrong); and the
   manual stopgap commit added the enum + `property_format` import but missed the
   `enums/__init__.py` re-export (later fixed).

## The core tension

- **Spec invariant:** formats are immutable, unversioned, **dependency-free
  leaves** — "Formats SHALL NOT reference other Sema vocabulary."
- **Reality:** `market.slot.name`'s validation genuinely *requires* an enum
  (`market.type.name`). The requirement is real; it's just not expressible as a
  `$ref`. In Sema's own glossary this is the shape of an **axiom dependency**
  ("required to implement an axiom… but not referenced via `$ref`").

## Options

1. **Allow a format to declare an enum dependency** (amend the `SHALL NOT`).
   - *Pro:* makes the real dependency explicit → closure pulls the enum
     automatically for every consumer; codegen imports it correctly; DRY.
   - *Con:* breaks the dependency-free-leaf invariant; **immutability vs. versioning
     puzzle** — formats are immutable+unversioned but enums are versioned+additive,
     so a format would need a written rule (reference the enum *word*, rely on
     additive-only monotonicity, never pin a version); slippery slope (then
     formats→formats? →types?); blurs the format/type/axiom layering; tooling
     ripple (closure, reverse-deps, published-can't-depend-on-draft checks).
2. **Keep formats purely syntactic; move enum-membership to a type-level axiom
   dependency** (closure already tracks axiom deps).
   - *Pro:* preserves the invariant; uses an existing declared-dependency
     mechanism; keeps the wire shape (string).
   - *Con:* validation logic moves out of the format into each consuming type;
     membership check no longer automatic everywhere the format is used.
3. **Make `market.slot.name` a type, not a format** — types may `$ref` enums.
   - *Con:* changes the wire shape from a string to an object. Almost certainly a
     non-starter.

## Current-spec answer
**Not allowed today.** `authoring/formats.md:16` ("Formats SHALL NOT reference
other Sema vocabulary") + formats are immutable/unversioned/primitive-refining.
So Option 1 is a normative spec amendment, not a tweak.

## Decision (ratified 2026-06-07)

**Sema SHALL allow versioned property formats.** The default for a format stays
**unversioned + immutable** (status quo for the vast majority). Versions are
added **exactly to those formats whose validator depends on `market.type.name`**
— right now that is **only `market.slot.name`**.

This adopts **Option 1** (a format may carry an enum dependency) and resolves
its blocking "con" — the immutability-vs-versioning puzzle, the *decisive
question* flagged above — by answering it directly: a format that must track an
evolving enum becomes **versioned**, so each market-type evolution can land as a
new format version rather than mutating an immutable leaf.

**Rationale (user, 2026-06-07).** Markets are a foundational aspect of GridWorks.
We want simple mechanisms for decoding core information about the market slot one
is bidding into **directly from the name itself** (the `market.slot.name` string
carries the commodity class, the market-type token, the maker alias, and the slot
start). Making that work over time requires an explicit acknowledgement that the
**market type names will evolve** — hence the format that decodes them must be
allowed to evolve, with versions, in lockstep with `market.type.name`.

### What this entails (implementation plan — not yet built)
- **Normative spec amendment.** `authoring/formats.md:16` ("Formats SHALL NOT
  reference other Sema vocabulary") and the immutable/unversioned framing — plus
  the universal MUST **"Treat formats as immutable"** in `sema/CLAUDE.md` — must
  be revised to permit (a) **versioned** formats and (b) a **declared enum
  dependency** on a format. This is a spec change, not a tweak; it must spell out
  the rule (a versioned format MAY `$ref`/declare a versioned enum; default
  remains unversioned-immutable).
- **`market.slot.name` becomes versioned** — move the flat
  `definitions/formats/market.slot.name.yaml` to a versioned form
  (`market.slot.name/000.yaml`, mirroring `enums/market.type.name/000.yaml`) and
  **declare its dependency on `market.type.name`** so the snapshot closure pulls
  the enum automatically for every consumer (killing the gjk
  `ModuleNotFoundError` at its root, not via the seed stopgap).
- **Tooling.** Closure / reverse-deps / regen must understand versioned formats;
  the `import_root` generator fix (see Regression note above /
  [`snapshot-improvement.md`](snapshot-improvement.md)) lands as part of this so
  the generated import is correct and durable.
- **Everything else stays unversioned.** No other format gains a version unless it
  too grows an enum-validation dependency.

> **Divergence flag (source precedence).** This decision overrides current sema
> spec invariants (formats immutable/unversioned/dependency-free). Until the spec
> amendment lands, `spec/authoring/formats.md` + `sema/CLAUDE.md` still say
> otherwise — implementers MUST carry this decision into those documents rather
> than let the record drift. Supersedes the earlier "lean Option 2" recommendation.

## Notes / facts established
- `MarketTypeName.values()` works on the generated enum — the validator's enum
  API is fine; the only gap was the enum's *presence*/*import* in the snapshot.
- A round-trip test **in sema** would NOT catch this — sema's own runtime has all
  vocabulary; the gap only exists in a restricted consumer snapshot. The catching
  test must run against the **consumer** snapshot, per-seeded-type (see the
  three-layer test plan discussed for gridworks-journalkeeper).
- Stopgap currently in place (gjk): seed `market.type.name` + fix the import +
  `__init__` re-export. Works, but a clean regen needs the `import_root` generator
  fix ([`snapshot-improvement.md`](snapshot-improvement.md) "Related") to be durable.
- **Regression confirmed (2026-06-07).** The stopgap was *not* durable: gjk's
  `57f5340` snapshot regen reverted the `49c7cb3` import fix, so
  `src/gjk/sema/property_format.py:72` again reads
  `from sema.runtime.enums import MarketTypeName` (no top-level `sema` pkg in the
  consumer) → `ModuleNotFoundError: No module named 'sema'` whenever
  `market.slot.name` is validated (e.g. `pytest` on the vendored
  `test_property_format.py[schema_path2]`). `property_format.py` is **generated**,
  so the fix must live upstream (the `import_root` generator fix), not in a
  hand-edit of the snapshot. This is the empirical proof that the manual stopgap
  cannot hold across regens.
