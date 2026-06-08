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

## Current-spec answer
**Not allowed today.** `authoring/formats.md:16` ("Formats SHALL NOT reference
other Sema vocabulary") + formats are immutable/unversioned/primitive-refining.
So the chosen direction below is a normative spec amendment, not a tweak.

## Decision (ratified 2026-06-07)

Sema SHALL allow **versioned property formats**. Default stays unversioned +
immutable. Add versions only to formats whose validator depends on an enum —
today only `market.slot.name` (→ `market.type.name`). A format that must track an
evolving enum becomes versioned: each market-type change lands as a new format
version instead of mutating an immutable leaf.

**Mechanism.** Declare the enum dependency as a registry **axiom dependency** on
the versioned format (closure already tracks axiom deps for types). The format
*schema* stays a pure pattern — no in-schema `$ref` — so "formats SHALL NOT
`$ref`" survives; only the immutable / unversioned / dependency-free rules change.

**Rationale (user).** Markets are foundational. We want to decode core market-slot
info (commodity class, market-type token, maker alias, slot start) directly from
the `market.slot.name` string. That requires acknowledging market type names will
evolve, so the decoding format must version in lockstep with `market.type.name`.

## Implementation checklist (not yet built)

Three must-fixes the recon surfaced as load-bearing:
- `build_versions.py` emits **no `formats:` section** — `indexes/versions.yaml` is
  types/enums only today; versioned formats must appear there.
- `runtime_generation/templates/format.py:143-146` **hardcodes**
  `from sema.runtime.enums import MarketTypeName` — must use the snapshot
  `import_root` (this is the gjk `ModuleNotFoundError` root cause).
- `build_seed_expanded.py` `absorb_closure` (~208-218) adds formats but never
  expands *their* deps — the one spot where `market.type.name` gets pulled once
  the format declares it.

### Spec (`spec/`) — do first
- [ ] `spec/primary.md:161` — format glossary row ("Immutable, unversioned … Cannot reference other Sema vocabulary").
- [ ] `spec/authoring/formats.md:81-88` — "## Immutability / Formats do not have versions" → versions allowed, immutable *per version*.
- [ ] `spec/authoring/formats.md:67-73` — drop "SHALL NOT include a Version field" for versioned formats (keep "SHALL NOT `$ref`").
- [ ] `spec/authoring/formats.md:16` — "SHALL NOT reference other Sema vocabulary" → carve out a registry axiom dep on an enum.
- [ ] `spec/registry/formats.md:12,25` — "immutable and unversioned" / "SHALL NOT include version-related information" → allow `versions:`/`latest_version:`/`direct_dependencies.axiom`.
- [ ] `spec/registry/structure.md:78-80` — versioned formats carry per-version status (not word-level).
- [ ] `spec/registry/types.md:340,352,388` — dep-ref syntax: permit `name:###` for versioned formats.
- [ ] `sema/CLAUDE.md` universal MUST "Treat formats as immutable" → "immutable per version".

### Definitions
- [ ] `definitions/registry.yaml` (`market.slot.name`) — add `versions:`/`latest_version:` + `direct_dependencies.axiom: [market.type.name:000]`.
- [ ] `definitions/formats/market.slot.name.yaml` → versioned layout `definitions/formats/market.slot.name/000.yaml`.

### Index / registry build tools (`src/sema/tools/`)
- [ ] `build_versions.py:78-144` — add `formats:` section (absent today).
- [ ] `build_lookup.py:79-80` — version map / versioned path for formats.
- [ ] `build_dependency_closure.py:27-46,99-100` — `classify()`: bare dep ≠ always format; versioned-format bucket.
- [ ] `build_reverse_dependencies.py:48-60,98-133` — same classify fix; per-version reverse-dep storage + output.
- [ ] `build_public_registry.py:37-60,73-75,146` — per-version status validation + publish filtering for versioned formats.
- [ ] `build_seed_dag.py:17-28,99-107,186-209,260-282` — `FORMAT_REF_PATTERN` optional version; expand format axiom deps; resolve format node version.
- [ ] `runtime_generation/formats.py:50,123-179,182-209` — version-aware codegen + generated test paths.
- [ ] `runtime_generation/templates/format.py:143-146` — parameterize import root.
- [ ] `runtime_generation/generate_runtime.py:70` — pass `import_root` into format codegen.

### Snapshot CLI + seed closure (`src/sema/`)
- [ ] `interfaces/cli/snapshot.py:113,154-161` — format deps flow into closure; versioned formats reach codegen.
- [ ] `tools/build_seed_expanded.py:28-30,208-218,280-283` — versioned format lookup; expand format axiom deps; versioned worklist entries.
- [ ] `tools/build_seed_definitions.py:121-122,312-354,373-419,528-550` — restricted registry/lookup versioned; closure expands format deps; `_classify_dep` versioned formats.
- [ ] `tools/seed_requests.py:32-34` — versioned format paths.

### Tests (`tests/`)
- [ ] `registry/test_registry_yaml_correctness.py:12-15,225-229,235-236,250-262` — drop "formats must not have versions/deps" asserts; add versioned-format + URL-version validation.
- [ ] `registry/test_registry_schema_file_layout.py:25,54,103-189` — versioned path/URL helpers; iterate versions.
- [ ] `registry/test_registry_status_consistency.py:45,62,96-97` — per-version status for versioned formats.
- [ ] `registry/test_structural_dependency_consistency.py:84-87` — `normalize_ref` keeps version suffix on formats.
- [ ] `registry/test_ref_values.py:56-58` — stop skipping formats once they carry declared deps.
- [ ] `registry/conftest.py:61` — also glob `formats/*/*.yaml`.
- [ ] `runtime/test_property_formats.py:41,51` — glob versioned formats.
- [ ] `runtime/test_runtime_generation_property_format.py:20,25-27,66` — versioned paths.
- [ ] `test_build_seed_expanded.py:77-89` — keep "no formats in initial_targets"; add a versioned-format transitive-pull case.
- [ ] Regen + green: `scripts/build_indexes.sh`, `scripts/regenerate_runtime.py`, `pytest`.

> **Divergence flag (source precedence).** This decision overrides current sema
> spec invariants (formats immutable/unversioned/dependency-free). Until the spec
> amendment lands, `spec/authoring/formats.md` + `sema/CLAUDE.md` still say
> otherwise — implementers MUST carry this decision into those documents rather
> than let the record drift.

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
