# Design: Untangle `market.slot.name` → `market.type.name` (format referencing an enum)

> Status: Draft · Pass 1 · Updated 2026-05-29

What this is: the problem statement + analysis-to-date for a structural Sema
question surfaced by a gridworks-journalkeeper import failure — **a property
format whose *validator* needs an enum, which the dependency closure can't see.**
This is an open architectural question; it stays here (a design under
investigation) until a direction is ratified, at which point the durable rule
folds into the `spec/` (formats authoring + closure) and this file is deleted.

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

## Recommendation (pending ratification)
Lean **Option 2** (axiom dependency on the consuming types): it gets
closure-trackability without spending the format-leaf/immutability guarantees.
Pick Option 1 only if many enum-validating formats make per-type axioms too
repetitive — and only after writing the format-pins-an-additive-enum rule. The
**decisive question** to answer first is that immutability/versioning rule.

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
