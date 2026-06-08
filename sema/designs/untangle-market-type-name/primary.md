# Design: Untangle `market.slot.name` → `market.type.name` (format referencing an enum)

> Status: Draft · Pass 1 · Updated 2026-06-07 · Linear: OPS-378
>
> Fractal design hub. Spoke: [`structured-enums.md`](structured-enums.md)
> (the reusable Sema capability this plan depends on).

What this is: the problem statement + analysis for a structural Sema question
surfaced by a gridworks-journalkeeper import failure — **a property format whose
*validator* needs an enum, which the dependency closure can't see.** Direction
**refined 2026-06-07 (post-research** — see
[`../../../gridworks-marketmaker/research/market-product-taxonomy.md`](../../../gridworks-marketmaker/research/market-product-taxonomy.md)):
the fix combines **two new Sema capabilities**: (1) **structured enums**
([`structured-enums.md`](structured-enums.md)) give the product token a typed,
codegen'd decode; (2) **versioned property formats** let the renamed
`gw.market.slot.name` declare an **axiom dependency** on the product enum
`gw.market.product.name` — turning the original *hidden* format→enum edge into a
**declared** one the closure tracks (fixing the gjk bug at the root). Plus an
open `market.product` type for representing a product as an object. This file is
the **change plan**; it stays until implemented, at which point the durable rules
fold into `spec/` + the marketmaker executor and this file is deleted. (The
"versioned property formats" path, once shelved as superseded, is **active** —
see below.)

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
[`../../../gridworks-marketmaker/research/market-product-taxonomy.md`](../../../gridworks-marketmaker/research/market-product-taxonomy.md):
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
   / owning org** (NOT per territory — territory lives in the slot name) — e.g.
   `gw.market.product.name` is GridWorks's own product vocabulary; another maker
   would carry `acme.market.product.name`. Each MarketMaker defines its own; the
   fractal architecture expects exactly this. "Open" = *multiplicity of
   structured enums*, NOT an open pattern.
3. **`market.product`** — the coupled sema **type**, kept **minimal for now**:
   - `Name` — plain string; a value from some `*.market.product.name` enum
     (e.g. `rt60gate5`).
   - `ProductNameEnum` — string naming **which** structured enum `Name` belongs
     to (e.g. `gw.market.product.name`). Disambiguates the namespaced
     enums and encodes ownership (here: the `gw` maker namespace).
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

**Effect on the original gjk problem.** The renamed `gw.market.slot.name`
becomes a **versioned property format** that **declares an axiom dependency** on
`gw.market.product.name`. The validator may still check the embedded product
token against the enum — but the dependency is now **declared in the registry**,
so `sema snapshot prepare`'s closure follows it and the enum reaches the consumer
snapshot. The original failure was a *hidden* edge; this makes it a *visible*
one. (This is the chosen fix over the earlier "make the format shape-only so the
edge disappears" idea — declaring the edge keeps token validation at the boundary
*and* fixes the closure gap.)

**Implications (sema mechanics) — TWO complementary capabilities, not one
instead of the other:**
- a **structured-enum capability** in sema — enum values carry typed per-value
  metadata that codegen emits (the "special kind of enum" / rich enum). **Specced**
  in [`structured-enums.md`](structured-enums.md) (its own change plan, since the
  capability is reusable beyond markets); land it first so the word is authorable;
- a **versioned-property-format capability** — formats MAY be versioned and MAY
  declare an axiom dependency on an enum (see the "Versioned property formats"
  section below, now **active**); this is what `gw.market.slot.name` uses;
- a **namespacing convention** for multiple `*.market.product.name` structured
  enums (one per maker/org);
- the open `market.product` type (`Name`/`ProductNameEnum`: strings) + the
  `market.type.name → gw.market.product.name` rename + the `market.slot.name →
  gw.market.slot.name` rename;
- the `templates/format.py` hardcoded-import-root fix (needed regardless).

## Proposed word sketches (capability-dependent)

> These are **proposals**, not yet authorable as live sema words: the
> `value_attributes` block below is **not permitted by current
> `authoring/enums.md:113-132`** (x-gridworks allows only `owner`, `version`,
> `value_descriptions`, `extended_description`). They become valid once the
> **structured-enum capability** lands. Authored here so the target is concrete.

### Proposed structured enum: `gw.market.product.name` v000

```yaml
$schema: "https://json-schema.org/draft/2020-12/schema"
$id: "https://schemas.electricity.works/enums/gw.market.product.name/000"
title: "gw.market.product.name"
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
  ProductNameEnum : string  # which structured enum, e.g. "gw.market.product.name"
  Name            : string  # a value in that enum, e.g. "rt60gate5"
```

## Active path — detailed change plan

The three pieces the refined decision leaves for this hub (the
structured-enum *capability* is owned by the spoke
[`structured-enums.md`](structured-enums.md) — referenced, not respecced
here). Sequencing across all three: **land the capability spoke first**
(so the structured word is authorable + codegen'd), **then** the rename
below, **then** the `market.product` type. The `templates/format.py`
import-root fix (under the superseded checklist) is orthogonal and lands
whenever.

### 1. Enum namespacing convention

Grounded in **Principle 5** (`sema/spec/primary.md:109` — vocabulary is
namespace-scoped; orgs define their own under distinct namespaces, `gw.*`,
`acme.*`, …). The product vocabulary is opened **by multiplicity**, not by
an open pattern: many structured enums, one per market maker / territory.

- **Name pattern.** `<ns>.market.product.name`, where `<ns>` is the
  maker/territory namespace (`gw.versant`, …). The GridWorks-in-Versant
  enum is `gw.market.product.name`. The segment after the
  namespace is fixed (`market.product.name`); only `<ns>` varies. Tokens
  inside each enum are the decodable product names (`rt60gate5`, `da60`, …)
  embedded in `market.slot.name`.
- **Consumer selection (which enum applies).** Two coordinated signals:
  1. **Authoritative — the `market.product` type's `ProductNameEnum`
     field** (§2): a `market.product` instance names its own enum
     explicitly, so a consumer holding the type needs no inference.
  2. **In-wire shorthand — the maker-alias segment of `market.slot.name`.**
     The slot name already carries a maker alias (location); a consumer
     decoding a bare `market.slot.name` string maps that alias → the
     maker's namespace → its `*.market.product.name` enum. This is the
     path the format validator would have taken; under the refined model
     it no longer reaches a *single global* enum (the original gjk failure
     mode dissolves — see "Effect on the original gjk problem" above).
- **`registry.yaml` entry (per enum).** Each is an ordinary structured
  enum entry: `owner` (the maker, e.g. `gridworks-energy`),
  `enum_type: "versioned"`, `description`, and a `versions:` block — the
  same shape `market.type.name` already has today
  (`sema/definitions/registry.yaml:463-472`). Structured-ness is **not**
  a new registry field (spoke registry option A,
  [`structured-enums.md`](structured-enums.md) — detected from the schema
  file's `value_attribute_schema`).
- **Independent versioning.** Each `*.market.product.name` enum versions
  on its own lineage; one maker adding a product does not touch another
  maker's enum. Additive-only per the enum evolution rules (and the
  spoke's attribute-additivity invariants).

### 2. The `market.product` type

A real, authorable Sema **type** per `sema/spec/authoring/types.md` +
`sema/spec/registry/types.md`. Versioned (`"000"`), `string` strategy.
**Minimal now**: identity + which-enum context only.

Schema shape (`definitions/types/market.product/000.yaml`), conforming to
the required top-level order (`authoring/types.md:67-81`) and CamelCase
serialized fields (Principle 2):

```yaml
$schema: "https://json-schema.org/draft/2020-12/schema"
$id: "https://schemas.electricity.works/types/market.product/000"
title: "market.product"
type: "object"
description: "A market product: a named token from a maker's product-name enum, plus stable identity."
properties:
  TypeName:
    const: "market.product"
  Version:
    const: "000"
  MarketProductId:
    $ref: "https://schemas.electricity.works/formats/uuid4.str"   # proposed — stable identity
  ProductNameEnum:
    type: "string"            # which structured enum, e.g. "gw.market.product.name"
  Name:
    type: "string"   # a value from the enum named by ProductNameEnum, e.g. "rt60gate5" — a bare token, NOT a $ref (see below)
required:
  - TypeName
  - Version
  - MarketProductId
  - ProductNameEnum
  - Name
additionalProperties: false
```

- **`TypeName`/`Version`** — `const`, per the identity-field rules
  (`authoring/types.md:32-53`, `const`-only-for-identity at `:157-177`).
- **`MarketProductId`** (proposed) — UUID identity via the `uuid4.str`
  format `$ref` (no bare `pattern` — Principle / `authoring/types.md:119`).
- **`ProductNameEnum`** — a plain `string` for now (it names *which*
  enum; a controlled vocabulary of namespaces could later promote it to
  its own enum, but not now).
- **`Name`** — a plain `string`: a value from the structured enum named
  by `ProductNameEnum`. **Deliberately NOT a `$ref` to that enum.**
  Rationale (user, 2026-06-08): GridWorks expects to scale to
  **thousands of market makers**, each potentially carrying its own
  `*.market.product.name` vocabulary. A single shared `market.product`
  type cannot statically `$ref` thousands of enums, and pinning one would
  make the type maker-specific. So `market.product` stays **one open,
  maker-agnostic type**, and `ProductNameEnum` (string) is the
  discriminator that says *which* vocabulary `Name` belongs to. The cost:
  `Name` is not validated against its enum at the Sema boundary (it is a
  bare token, exactly like `ProductNameEnum`); membership + attribute
  decode are an **opt-in, consumer-side** step (a consumer that wants the
  decode seeds that maker's structured enum and looks `Name` up in it).
  This is the fractal/open grain, accepted with eyes open.
- **`registry.yaml` entry.** Versioned type entry
  (`registry/types.md:55-78`): `latest_version: "000"`, `owner:
  gridworks-energy`, `versioning_strategy: "string"`. Because `Name` and
  `ProductNameEnum` are plain strings, the **only**
  `direct_dependencies.structural` is `uuid4.str` (the `MarketProductId`
  format) — the type carries **no dependency on any product-name enum**
  (the open model's whole point). Closure therefore pulls **no** product
  enum via this type; see §3.
- **No settlement / dispatch / response / price attributes now.** Those
  are added to the type **as each market is designed**, per the
  **split rule**: *decodable from the name token → a row on the
  structured-enum value (the spoke); not in the name → a field on this
  type, later.* (Slot-duration-minutes → enum; settlement interval →
  type, later.) Adding a required field later is a new type version
  (`registry/types.md:221-228`) with an upgrade path.

### 3. The `market.type.name → gw.market.product.name` rename + migration

`market.type.name` is today a `versioned` enum
(`sema/definitions/registry.yaml:463-472`,
`sema/definitions/enums/market.type.name/000.yaml`) carrying **8 tokens**
(`unknown`, `rt5gate5`, `rt60gate5`, `da60`, `rt60gate30`, `rt15gate5`,
`rt30gate5`, `rt60gate30b`) with `value_descriptions` only. The migration:

- **Rename + upgrade to a `versioned` STRUCTURED enum**
  `gw.market.product.name` (per §1's name pattern). The 8 tokens
  carry over verbatim; each gains an attribute row
  (`timeframe`/`slot_minutes`/`gate_minutes`/`quantity_unit`) under
  `value_attribute_schema` + `value_attributes`. **The worked rows are in
  the spoke** — [`structured-enums.md`](structured-enums.md) "Worked
  example" + "Migration of the existing word" — not duplicated here. Note
  the `rt60gate30b` description has a **pre-existing data bug** (says "30
  minute … gate 5 … AvgkW" at `enums/market.type.name/000.yaml:31` while
  the spoke decodes it as 60-min / gate-30 / AvgkW); reconcile the row
  against MarketMaker reality when authoring, don't copy the stale prose.
- **Generated runtime rename** `MarketTypeName → GwMarketProductName`
  (`src/sema/runtime/enums/market_type_name.py` →
  `gw_market_product_name.py`; re-export in
  `src/sema/runtime/enums/__init__.py:31,72`). Regenerated by
  `scripts/regenerate_runtime.py`, not hand-edited.
- **Every referencing site that must update** (verified by grep over
  `sema/`):
  - **Type `$ref`s to `market.slot.name`** (the *format*, unchanged in
    name) on `atn.bid` (`definitions/types/atn.bid/002.yaml:26-27`),
    `bid` (`bid/000.yaml:26-27`), `latest.price`
    (`latest.price/000.yaml:32-33`). These reference the **format**, not
    the enum, so the `$ref` URL is untouched — but their docstrings say
    "the MarketType associated with MarketSlotName"
    (`atn.bid/002.yaml:56,62,99`; `bid/000.yaml:105,111,117`); update the
    *prose* to "market product" to match the rename (no version bump — a
    description clarification, `registry/types.md:293-294`).
  - **The `market.slot.name` format validator** — generated
    `is_market_name` / market-minutes lookup in
    `src/sema/runtime/property_format.py:83-143` and its template
    `src/sema/tools/runtime_generation/templates/format.py:120-185`,
    which today import `MarketTypeName` and key a duration dict off its
    members. Under the refined model **this validator becomes shape-only**
    (the product token is interpreted against the maker's structured enum,
    not re-validated in the format), so the `_market_type_name_enum()`
    helper + the hardcoded `from sema.runtime.enums import MarketTypeName`
    (`format.py:144`, `property_format.py:102` — the gjk
    `ModuleNotFoundError` root) are **removed**, not merely renamed. The
    slot-duration decode, if still needed, reads it off the structured
    enum's `.attrs.slot_minutes` (spoke) instead of the in-format dict.
  - **Registry** `definitions/registry.yaml:463` (the
    `market.type.name:` key → `gw.market.product.name:`) and the
    enum dir `definitions/enums/market.type.name/` →
    `definitions/enums/gw.market.product.name/`.
- **Closure / index / codegen consequences.**
  - `market.slot.name` does **not** currently declare a `$ref` or
    dependency on `market.type.name` (the hidden edge that caused the
    incident — confirmed: `market.slot.name`'s registry entry
    `definitions/registry.yaml:25-27` lists no enum dep). Making the
    format shape-only **removes the hidden edge entirely** — there is
    nothing to migrate into a closure dep; the format goes back to being
    a true dependency-free leaf.
  - **No edge replaces the removed hidden one — by design.** Under the
    open `market.product` model (§2) nothing in the type machinery `$ref`s
    a product-name enum, so closure pulls **no** product enum
    automatically. That is correct now that the format is shape-only:
    nothing *validates* against the enum at the boundary anymore, so
    nothing *needs* it forced into every snapshot. A consumer that wants
    to **decode** a product token (read `.attrs.slot_minutes` off the
    maker's structured enum) opts in by seeding that specific enum. The
    gjk failure class is gone (no hidden edge); the trade is that token
    validity is consumer-side, not boundary-enforced (§2).
  - Re-run `scripts/build_indexes.sh` (rebuilds `lookup`,
    `public_registry`, `dependency_closure`, `reverse_dependencies`,
    `versions` — all carry stale `market.type.name` rows:
    `indexes/versions.yaml:787`, `indexes/lookup.yaml:514-518`,
    `indexes/public_registry.yaml:384-391`) and
    `scripts/regenerate_runtime.py`.

### Active-path implementation checklist

Distinct from the superseded checklist below. For the **structured-enum
capability itself** (spec/codegen/tests for `value_attribute_schema` etc.)
see the spoke's checklist — [`structured-enums.md`](structured-enums.md)
"Implementation checklist"; **not duplicated here**.

**Spec (`sema/spec/`)** — light; the capability spoke owns the
`authoring/enums.md` changes.
- [ ] Confirm no `spec/` change is needed for the `market.product` type
      beyond what `authoring/types.md` / `registry/types.md` already
      permit (a type `$ref`-ing an enum is already legal — verify, don't
      amend).

**Definitions (`sema/definitions/`)**
- [ ] Author `enums/gw.market.product.name/000.yaml` as a
      **structured** enum (8 tokens + attribute rows per spoke); rename
      from `enums/market.type.name/`.
- [ ] Registry: rename `market.type.name:` → `gw.market.product.name:`
      (`registry.yaml:463`); keep `enum_type: versioned`.
- [ ] Author `types/market.product/000.yaml` (§2 shape) + its versioned
      registry entry with `direct_dependencies.structural:
      [gw.market.product.name:000, uuid4.str]`.
- [ ] `market.slot.name` → shape-only: drop the embedded market-type
      enum lookup; confirm it declares no enum dependency.
- [ ] Update `atn.bid`/`bid`/`latest.price` docstring prose
      ("MarketType" → "market product"); no version bump.

**Tools / codegen (`sema/src/sema/`)**
- [ ] `runtime_generation/templates/format.py:120-185` — remove the
      `_market_type_name_enum()` helper + hardcoded `MarketTypeName`
      import from the `market.slot.name` path (becomes shape-only).
- [ ] Regenerate: `MarketTypeName` runtime file/re-export
      (`runtime/enums/__init__.py:31,72`) replaced by
      `GwMarketProductName` (structured, via the spoke's codegen).
- [ ] `scripts/build_indexes.sh` + `scripts/regenerate_runtime.py` — clear
      stale `market.type.name` rows from all five indexes.

**Tests (`sema/tests/`)**
- [ ] `runtime/test_property_formats.py:17` — `market.slot.name` validator
      is shape-only (no enum reach).
- [ ] Add a consumer-snapshot guard: a snapshot seeding `market.product`
      pulls **no** product-name enum automatically (`Name`/`ProductNameEnum`
      are bare strings — open model), and `market.slot.name` pulls **nothing**
      extra (the gjk regression guard); a consumer that opts into decoding by
      seeding `gw.market.product.name` gets it cleanly (cf. the spoke's
      snapshot test).
- [ ] Regen + green: `scripts/build_indexes.sh`,
      `scripts/regenerate_runtime.py`, `pytest`.

## Versioned property formats (sema-mechanics path — SUPERSEDED)

> **Superseded by the structured-enum decision above.** This path treated the
> problem as "a format validator must reach an enum." Under the chosen model the
> semantics live in namespaced **structured enums**, not in a format validator, so
> `market.slot.name` becomes shape-only and the format→enum dependency disappears.
> Kept below as the fallback analysis and because the `templates/format.py`
> import-root bug it documents is real and still needs fixing. The implementation
> checklist that follows is for THIS (superseded) path; the active path's
> checklist — structured-enum capability + enum namespacing + the `market.product`
> type + the rename — is partly specced: the **structured-enum capability** now
> has its own change plan in [`structured-enums.md`](structured-enums.md)
> (incl. its implementation checklist); enum namespacing + the `market.product`
> type + the rename remain to be detailed here.

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
  fix ([`snapshot-improvement.md`](../snapshot-improvement.md) "Related") to be durable.
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
