# Design: Untangle `market.slot.name` → `market.type.name` (format referencing an enum)

> Status: Draft · Pass 1 · Updated 2026-06-07

What this is: the problem statement + analysis for a structural Sema question
surfaced by a gridworks-journalkeeper import failure — **a property format whose
*validator* needs an enum, which the dependency closure can't see.** Direction
**refined 2026-06-07 (post-research** — see
[`../../gridworks-marketmaker/research/market-product-taxonomy.md`](../../gridworks-marketmaker/research/market-product-taxonomy.md)):
split the concept into a simple, decodable **`market.product.name`** plus a
coupled **`market.product` type** that carries the settlement/response attributes
— the heavy logic leaves the format. This file is the **change plan**; it stays
until implemented, at which point the durable rule folds into `spec/` + the
marketmaker executor and this file is deleted. The earlier "versioned property
formats" path (below) becomes **contingent** under the refined model.

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

## Decision — refined (2026-06-07, post-research)

Grounded in
[`../../gridworks-marketmaker/research/market-product-taxonomy.md`](../../gridworks-marketmaker/research/market-product-taxonomy.md):
every mature framework (EMIX/TeMIX, ISO products, OpenADR) models a market
product as **a named token carrying structured attributes** — never a bare token,
and never with the structure scattered into a separate database. GridWorks adopts:

1. **`market.product.name` stays a STRUCTURED enum** — each value carries **only
   the attributes already implicit in the name token** (a faithful decode of the
   name): commodity class, slot duration (minutes), gate offset, and quantity
   unit where the name encodes it (e.g. the `…b` variant). The token (e.g.
   `rt60gate5`) is the obvious, unique, decodable product name embedded in
   `market.slot.name`. These name-decodable semantics live **in the vocabulary**.
2. **Open the enum by allowing MANY structured enums, namespaced per market maker
   / territory** — e.g. `gw.versant.market.product.name` (the one GridWorks would
   use in Versant territory). Each MarketMaker defines its own product vocabulary;
   the fractal architecture expects exactly this. "Open" = *multiplicity of
   structured enums*, NOT an open pattern.
3. **`market.product`** — the coupled sema **type**, kept **minimal for now**:
   - `Name` — plain string; a value from some `*.market.product.name` enum
     (e.g. `rt60gate5`).
   - `ProductNameEnum` — string naming **which** structured enum `Name` belongs
     to (e.g. `gw.versant.market.product.name`). Disambiguates the namespaced
     enums and encodes ownership/context (here: GridWorks-in-Versant).
   - `MarketProductId` (proposed) — a UUID for stable identity.

   **No** settlement / dispatch / response / price attributes yet — those get
   added to the type **as we design each market**, not now.

**Split rule (applies when attributes *are* added):** decodable from the name
token → on the structured-enum value; not in the name → on the `market.product`
type. (Slot-duration-minutes on the enum; settlement interval on the type, later.)

`market.slot.name` keeps its job — an obvious unique name per market slot —
embedding the product name + maker alias (location) + slot start. Location stays
out of the product (it lives in the slot name), matching EMIX/CAISO.

**"Keep the enum flat?" → no.** The semantics stay *in* the (structured) enum —
that is the point. What changes vs one global list is that the enum is **opened by
namespacing**: many structured enums, one per maker/territory.

**Why not the open-pattern + catalog route (rejected).** An open pattern would
push product validity + semantics into a separate `market.product` catalog —
*another entire source of truth* (a database). The structured-enum route
**encapsulates the semantics in versioned, closure-tracked, codegen'd
vocabulary**, where they belong. Not adding a second source of truth is the
deciding factor.

**Effect on the original gjk problem.** `market.slot.name` validation becomes
shape-only at the format layer; the product token is interpreted against the
relevant maker's structured enum (selected by the maker-alias segment) where that
enum is in scope — so the format validator no longer reaches a single global enum,
and the original failure mode dissolves.

**Implications (sema mechanics) — this REPLACES the versioned-formats path as the
primary mechanism:**
- a **structured-enum capability** in sema — enum values carry typed per-value
  metadata that codegen emits (the "special kind of enum" / rich enum);
- a **namespacing convention** for multiple `*.market.product.name` structured
  enums;
- the `market.product` type (`Name`: string) + the `market.type.name →
  market.product.name` rename;
- the `templates/format.py` hardcoded-import-root fix (needed regardless).

## Proposed word sketches (capability-dependent)

> These are **proposals**, not yet authorable as live sema words: the
> `value_attributes` block below is **not permitted by current
> `authoring/enums.md:113-132`** (x-gridworks allows only `owner`, `version`,
> `value_descriptions`, `extended_description`). They become valid once the
> **structured-enum capability** lands. Authored here so the target is concrete.

### Proposed structured enum: `gw.versant.market.product.name` v000

```yaml
$schema: "https://json-schema.org/draft/2020-12/schema"
$id: "https://schemas.electricity.works/enums/gw.versant.market.product.name/000"
title: "gw.versant.market.product.name"
type: "string"
description: >
  Market products GridWorks offers within Versant territory. Each token decodes
  directly to its slot timing — timeframe class, slot minutes, gate minutes, and
  quantity-unit variant.
enum:
  - "unknown"
  - "da60"
  - "rt60gate5"
  - "rt60gate30"
  - "rt60gate30b"
  - "rt30gate5"
  - "rt15gate5"
  - "rt5gate5"
default: "unknown"
x-gridworks:
  owner: "gridworks-energy"
  version: "000"
  value_descriptions:
    "da60": "Day-ahead energy, 60-minute slots"
    "rt60gate5": "Real-time energy, 60-min slots, gate 5 min prior"
    "rt60gate30": "Real-time energy, 60-min slots, gate 30 min prior"
    "rt60gate30b": "As rt60gate30 but QuantityUnit = average kW"
    "rt30gate5": "Real-time energy, 30-min slots, gate 5 min prior"
    "rt15gate5": "Real-time energy, 15-min slots, gate 5 min prior"
    "rt5gate5": "Real-time energy, 5-min slots, gate 5 min prior"
  # PROPOSED structured extension — NOT legal under current authoring/enums.md.
  # name-decodable attributes only (the "split rule"):
  value_attributes:
    da60:        { timeframe: da, slot_minutes: 60, gate_minutes: null, quantity_unit: AvgkWh }
    rt60gate5:   { timeframe: rt, slot_minutes: 60, gate_minutes: 5,    quantity_unit: AvgkWh }
    rt60gate30:  { timeframe: rt, slot_minutes: 60, gate_minutes: 30,   quantity_unit: AvgkWh }
    rt60gate30b: { timeframe: rt, slot_minutes: 60, gate_minutes: 30,   quantity_unit: AvgkW  }
    rt30gate5:   { timeframe: rt, slot_minutes: 30, gate_minutes: 5,    quantity_unit: AvgkWh }
    rt15gate5:   { timeframe: rt, slot_minutes: 15, gate_minutes: 5,    quantity_unit: AvgkWh }
    rt5gate5:    { timeframe: rt, slot_minutes: 5,  gate_minutes: 5,    quantity_unit: AvgkWh }
    # "unknown" carries no attributes
```

### Proposed type: `market.product` v000 (conceptual — real shape per `authoring/types.md`)

Kept minimal: identity + which-enum context only. Market-specific attributes
(settlement, dispatch, response, price-formation) are added later, per market.

```
TypeName: market.product   Version: "000"
  MarketProductId : UUID    # proposed — stable identity
  ProductNameEnum : string  # which structured enum, e.g. "gw.versant.market.product.name"
  Name            : string  # a value in that enum, e.g. "rt60gate5"
```

## Versioned property formats (sema-mechanics path — SUPERSEDED)

> **Superseded by the structured-enum decision above.** This path treated the
> problem as "a format validator must reach an enum." Under the chosen model the
> semantics live in namespaced **structured enums**, not in a format validator, so
> `market.slot.name` becomes shape-only and the format→enum dependency disappears.
> Kept below as the fallback analysis and because the `templates/format.py`
> import-root bug it documents is real and still needs fixing. The implementation
> checklist that follows is for THIS (superseded) path; the active path's
> checklist — structured-enum capability + enum namespacing + the `market.product`
> type + the rename — is TBD.

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
