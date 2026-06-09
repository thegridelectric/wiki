# Design: Untangle `market.slot.name` → `market.type.name` (format referencing an enum)

Status: Accepted · Pass 1 · Updated 2026-06-08 · Linear: OPS-378

> **⚠ PARTIAL REVERSAL (2026-06-08).** The **structured-enum** sub-capability is
> being **rolled back** — see [`rollback-structured-enums.md`](rollback-structured-enums.md).
> The rest of this design stands (the `market.type.name → gw.market.product.name`
> rename, the `market.product` type, the pure-pattern `market.slot.name` format,
> and `frozen_at`). `gw.market.product.name` reverts to a **plain** versioned
> enum; name-decodable semantics move to the `market.product` **type** and to
> **axioms**. Sections below that present structured enums / versioned formats as
> the chosen direction are superseded by the rollback spoke.
>
> Fractal design hub. Spokes: [`rollback-structured-enums.md`](rollback-structured-enums.md)
> (active plan) · [`structured-enums.md`](structured-enums.md) (**superseded**).

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

## Execution notes (handoff to a fresh session)

Read this first if you are implementing. The plan is execution-ready for the
**sema-side** work, with these guardrails:

- **Re-grep every `file:line`.** All line numbers here were grep'd 2026-06-07/08
  and WILL drift. Treat them as "look near here for X," re-locate by symbol, and
  never edit by line number alone.
- **Follow `sema/CLAUDE.md`.** Read `spec/primary.md` + the relevant
  `spec/registry/` + `spec/authoring/` spokes first; use `/make-sema-word` for
  each word add/change; obey the universal MUSTs (CamelCase serialized fields,
  enums additive-only, bump type versions, `pytest` + registry validation green).
- **Land in three independently-green units, in this order — do NOT do it all in
  one diff:**
  1. **Structured-enum capability** — spoke checklist
     ([`structured-enums.md`](structured-enums.md) "Implementation checklist").
  2. **Versioned-property-format capability** — the "Versioned-format capability"
     checklist below (incl. the relax → migrate → re-constrain spec sequencing).
  3. **Market application** (§3) — the renames, `market.product`, `ltn.bid`,
     `bid`/`latest.price` v001, the `frozen_at` field.
- **Resolve these up front (ask the user — they don't block the architecture but
  do block authoring):** registry option A vs B (spoke; **resolved → A**);
  confirm integer structured enums stay out of v1 (spoke). (The `frozen`
  question is **resolved** — see §4: word-level `frozen_at`.)
- **Confirm the `rt60gate30b` row against MarketMaker reality** before authoring —
  the legacy description is internally contradictory (§3); MarketMaker is the
  source of truth, not this doc.
- **Out of scope — separate follow-ups, not this sema design:** the downstream
  consumers. The **MarketMaker app** (`MarketTypeName → GwMarketProductName`) and
  the **gjk snapshot regen** (remove the stopgap once the real fix lands) each
  need their own change in their own repo. This design is sema-only; it makes the
  fix *possible*, it does not carry the consumer edits.

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
namespacing**: many structured enums, one per maker/org.

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
  GridWorks's own market-product vocabulary (the maker's products, across
  whatever territories GridWorks operates in). Each token decodes directly to its
  slot timing — timeframe class, slot minutes, gate minutes, and quantity-unit
  variant.
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

The pieces this hub owns (the structured-enum *capability* is owned by the
spoke [`structured-enums.md`](structured-enums.md) — referenced, not respecced
here; the **versioned-property-format capability** is detailed in its own
section below). Sequencing: **land both capability specs first** (structured
enums in the spoke; versioned formats below), **then** the renames + the
`market.product`/`ltn.bid` types. The `templates/format.py` import-root fix
(in the versioned-format checklist below) is orthogonal and lands whenever.

### 1. Enum namespacing convention

Grounded in **Principle 5** (`sema/spec/primary.md:109` — vocabulary is
namespace-scoped; orgs define their own under distinct namespaces, `gw.*`,
`acme.*`, …). The product vocabulary is opened **by multiplicity**, not by
an open pattern: many structured enums, one per market maker / owning org —
**not per territory** (territory is carried in the slot name's maker-alias
segment, not the vocabulary name; this matches EMIX/CAISO — location lives in
the slot, not the product).

- **Name pattern.** `<ns>.market.product.name`, where `<ns>` is the
  **maker/org** namespace (`gw`, `acme`, …). GridWorks's own enum is
  `gw.market.product.name`. The segment after the namespace is fixed
  (`market.product.name`); only `<ns>` varies. Tokens inside each enum are the
  decodable product names (`rt60gate5`, `da60`, …) embedded in the slot name.
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
  Rationale (user, 2026-06-08): the ecosystem will host **many independent
  market makers** — across different owners and regulatory environments, not
  all of them GridWorks — each potentially carrying its own
  `*.market.product.name` vocabulary. A single shared `market.product`
  type cannot statically `$ref` every maker's enum, and pinning one would
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

### 3. The renames + migration (`market.type.name → gw.market.product.name` enum; `market.slot.name → gw.market.slot.name` versioned format)

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
  - **Types with a `MarketSlotName` field** (`$ref` the slot-name format):
    `atn.bid` (`atn.bid/002.yaml:26-27`), `bid` (`bid/000.yaml:26-27`),
    `latest.price` (`latest.price/000.yaml:32-33`). The format is **renamed**
    `market.slot.name → gw.market.slot.name`, so these `$ref` URLs **do**
    change. Disposition per type:
    - **`atn.bid` → replaced by `ltn.bid`** (ATN is the legacy name for Leaf
      Transactive Node). Do **not** bump `atn.bid`; author **`ltn.bid` v000**
      (the modern type) with the `MarketSlotName` field `$ref`ing
      `gw.market.slot.name` (so it transitively pulls `gw.market.product.name`
      via the format's axiom dep), and mark `atn.bid` **frozen** — no new
      versions (see §4).
    - **`bid`, `latest.price` → new versions** (`001`) repointing
      `MarketSlotName` to `gw.market.slot.name` (a `$ref` change is structural
      → version bump). Docstrings ("the MarketType associated with
      MarketSlotName") update to "market product".
  - **The slot-name format validator** — generated `is_market_name` /
    market-minutes lookup in `src/sema/runtime/property_format.py:83-143` and
    its template `templates/format.py:120-185`, which import `MarketTypeName`
    and key a duration dict off its members. Under the chosen model
    `gw.market.slot.name` is a **versioned format that declares an axiom
    dependency** on `gw.market.product.name` (registry), so the validator may
    keep checking the embedded token against the enum — but because the
    dependency is now **declared**, the closure carries the enum into consumer
    snapshots (this is the gjk fix). The hardcoded
    `from sema.runtime.enums import MarketTypeName` (`format.py:144`,
    `property_format.py:102` — the gjk `ModuleNotFoundError` root) is replaced
    by the snapshot `import_root` + the renamed `GwMarketProductName`. The
    slot-duration lookup can read `.attrs.slot_minutes` off the structured
    enum (spoke) rather than a hand-maintained in-format dict.
  - **Registry + files.** Enum: `registry.yaml:463` key
    `market.type.name: → gw.market.product.name:`; dir
    `enums/market.type.name/ → enums/gw.market.product.name/`. Format:
    `registry.yaml:25` key `market.slot.name: → gw.market.slot.name:`, now
    **versioned** (`latest_version: "000"`, `versions:` block,
    `direct_dependencies.axiom: [gw.market.product.name:000]`); file
    `formats/market.slot.name.yaml → formats/gw.market.slot.name/000.yaml`
    (versioned layout).
- **Closure / index / codegen consequences.**
  - The incident's **hidden** edge (`market.slot.name`'s validator reaching
    `market.type.name` with no declared dep — `registry.yaml:25-27` lists
    none) becomes a **declared axiom dependency** on the versioned
    `gw.market.slot.name`. `sema snapshot prepare` follows declared deps, so
    any consumer seeding a type with a `MarketSlotName` field (e.g. `ltn.bid`)
    transitively pulls `gw.market.product.name` — the enum is in the snapshot
    and the gjk `ModuleNotFoundError` class is gone at the root.
  - **The `market.product` *type* path is separate and stays open** (§2): it
    does not `$ref` any product enum, so a consumer holding only
    `market.product` pulls no enum automatically and decodes opt-in. The two
    paths coexist by design: the **slot-name format** carries the declared
    dependency (the bid path); the **`market.product` type** stays
    string-open (the thousands-of-makers scale path).
  - Re-run `scripts/build_indexes.sh` (rebuilds `lookup`,
    `public_registry`, `dependency_closure`, `reverse_dependencies`,
    `versions` — all carry stale `market.type.name` rows:
    `indexes/versions.yaml:787`, `indexes/lookup.yaml:514-518`,
    `indexes/public_registry.yaml:384-391`) and
    `scripts/regenerate_runtime.py`.

### 4. Frozen words — `frozen_at` (closed version lineage)

`atn.bid` is superseded by `ltn.bid` but **cannot be deleted**: historical
messages + stored data carry `TypeName: atn.bid`, and consumers still decode
them. We want it to **stay decodable forever** while signalling that **no new
version will ever be cut**. Decision (resolved 2026-06-08):

- **A word-level `frozen_at` field — NOT a new `status` value.** `frozen` is a
  *different axis* than `status`: `status` (`draft`/`published`) answers "is
  *this version* published?" and is **per-version** for versioned words;
  frozen-ness answers "will *this word* ever get another version?" and is
  **per-word**. Modelling frozen as a `status` value would conflate the two
  (a frozen word's existing versions are still `published`). So frozen is a
  **separate word-entry field**.
- **Date-as-marker.** The field is `frozen_at: "<RFC 3339>"` (seconds-precision
  UTC, matching the registry Timestamp Rules). **Presence ⇒ frozen**; absence ⇒
  not frozen. This avoids a redundant `frozen: true` boolean *and* records the
  audit fact "when the lineage was closed," mirroring `created`.
- **Semantics.** A word with `frozen_at` remains valid and its existing
  published versions stay decodable forever; **authoring a new version is a
  registry-validation error.** `frozen_at` gates *only* new versions — it says
  nothing about description edits, which stay governed by the existing
  published-immutability rules (so the earlier "does frozen forbid description
  edits?" question resolves to **no, automatically**). For structurally
  single-version words (versionless formats, literal enums, versionless types)
  "no new versions" is already automatic, so `frozen_at` there is a retirement
  *signal* rather than a new gate.
- **Orthogonal to `replaced_by`; NOT coupled.** `replaced_by` (already in
  `spec/registry/structure.md`) is the advisory *successor* hint and explicitly
  "does not create a lifecycle state." `frozen_at` is the lifecycle gate. They
  **compose**, neither subsumes the other:
  - `frozen_at` without `replaced_by` is legitimate (retire a concept with no
    successor);
  - `replaced_by` without `frozen_at` is legitimate during a migration window
    (the old lineage may still be hotfixed while the successor matures);
  - forcing `replaced_by ⇒ frozen_at` (a MUST) would make `replaced_by` carry
    lifecycle meaning, contradicting its current spec. So **no MUST**; at most a
    **SHOULD** + a lint *warning* if a `replaced_by` word lacks `frozen_at`.
  - `atn.bid` simply carries **both** (`replaced_by: [ltn.bid]` *and*
    `frozen_at`).
- **Why not just stop touching it?** Silence is not a contract. `frozen_at`
  makes "this is done, build `ltn.bid` instead" machine-checkable and
  self-documenting in the registry.
- **Spec touch.** `spec/registry/structure.md` gains the `frozen_at` field
  definition (alongside `status` and `replaced_by`) + a registry-validation
  rule: no version may be authored on a word once `frozen_at` is present.
  Small and orthogonal to the format/enum work — could land independently.
- **Applies here to:** `atn.bid` (→ `frozen_at` + `replaced_by: [ltn.bid]`).
  Candidate for other legacy words later; out of scope to sweep now.

### Active-path implementation checklist

Distinct from the versioned-format checklist below. For the **structured-enum
capability itself** (spec/codegen/tests for `value_attribute_schema` etc.)
see the spoke's checklist — [`structured-enums.md`](structured-enums.md)
"Implementation checklist"; **not duplicated here**.

**Spec (`sema/spec/`)** — the structured-enum `authoring/enums.md` changes
are owned by the spoke; the **versioned-property-format** changes are below
(now active). Sequence the format-immutability rule carefully (user, 2026-06-08):
1. [ ] **Relax first.** Remove the blanket "formats are immutable & unversioned
       / SHALL NOT have a version" rules (`authoring/formats.md:67-73,81-88`,
       `registry/formats.md:12,25`). Do **NOT** yet add any
       "versionless-stays-versionless" constraint.
2. [ ] **Migrate** `market.slot.name → gw.market.slot.name` to a versioned
       format (definitions step below) — legal precisely because no rule
       forbids the promotion in this window.
3. [ ] **Re-constrain after.** Add the rule: a **versionless (immutable) format
       SHALL remain versionless** — a format's versioned-ness is fixed at
       creation; no later promotion. This locks the door behind the one needed
       migration, so the final rule is clean (no grandfather exception).
- [ ] `authoring/formats.md:16` — carve out a registry **axiom dependency** on
      an enum for versioned formats (keep "SHALL NOT `$ref`").
- [ ] Confirm `market.product` needs no `spec/` change (a type referencing an
      enum is already legal — but here `Name`/`ProductNameEnum` are strings, so
      not even that).
- [ ] Add the **`frozen_at`** word field (§4) to `registry/structure.md`.

**Definitions (`sema/definitions/`)**
- [ ] Author `enums/gw.market.product.name/000.yaml` as a **structured** enum
      (8 tokens + attribute rows per spoke); rename from `enums/market.type.name/`.
- [ ] Registry: rename `market.type.name: → gw.market.product.name:`
      (`registry.yaml:463`); keep `enum_type: versioned`.
- [ ] `formats/market.slot.name.yaml → formats/gw.market.slot.name/000.yaml`
      (versioned layout); registry entry gains `latest_version`/`versions:` +
      `direct_dependencies.axiom: [gw.market.product.name:000]`.
- [ ] Author `types/market.product/000.yaml` (§2 shape, open) + registry entry
      with `direct_dependencies.structural: [uuid4.str]` (no enum dep).
- [ ] Author `types/ltn.bid/000.yaml` (modern replacement for `atn.bid`) —
      `MarketSlotName` `$ref`s `gw.market.slot.name`; mark `atn.bid` **frozen**.
- [ ] `bid` → `001`, `latest.price` → `001`: repoint `MarketSlotName` to
      `gw.market.slot.name`; docstrings "MarketType" → "market product".

**Tools / codegen (`sema/src/sema/`)**
- [ ] Versioned-format machinery (the un-superseded checklist below): closure +
      indexes must track a format's axiom dep and per-version layout.
- [ ] `runtime_generation/templates/format.py:120-185` — replace the hardcoded
      `MarketTypeName` import with `import_root` + `GwMarketProductName`; keep
      the token-vs-enum check (now backed by the declared axiom dep).
- [ ] Regenerate: `MarketTypeName` runtime/re-export
      (`runtime/enums/__init__.py:31,72`) → `GwMarketProductName` (structured,
      via the spoke's codegen).
- [ ] `scripts/build_indexes.sh` + `scripts/regenerate_runtime.py` — clear
      stale `market.type.name`/`market.slot.name` rows from all five indexes.

**Tests (`sema/tests/`)**
- [ ] Consumer-snapshot regression guard (the gjk root case): a snapshot
      seeding `ltn.bid` **does** pull `gw.market.product.name` transitively via
      `gw.market.slot.name`'s declared axiom dep (no `ModuleNotFoundError`).
- [ ] `market.product` (type) seeded alone pulls **no** product enum (open
      model) — decode is opt-in.
- [ ] `frozen_at`: authoring a new `atn.bid` version is a registry error.
- [ ] Regen + green: `scripts/build_indexes.sh`,
      `scripts/regenerate_runtime.py`, `pytest`.

## Versioned property formats (sema-mechanics path — ACTIVE)

> **ACTIVE — runs alongside structured enums, not instead of them** (reframed
> 2026-06-08). Earlier shelved as superseded on the assumption that the
> slot-name format would go shape-only and the format→enum edge would
> *disappear*. The chosen direction instead makes the edge **declared**:
> `gw.market.slot.name` is a versioned property format that declares an axiom
> dependency on the structured enum `gw.market.product.name`. Both capabilities
> are needed — structured enums for the typed decode
> ([`structured-enums.md`](structured-enums.md)), versioned property formats for
> the slot-name format below. The implementation checklist that follows is for
> THIS (versioned-format) capability and is **active**; the structured-enum
> capability's own checklist lives in the spoke.

Sema SHALL allow **versioned property formats**. Default stays unversioned +
immutable. Add versions only to formats whose validator depends on an enum —
today only `gw.market.slot.name` (→ `gw.market.product.name`). A format that must
track an evolving enum becomes versioned: each product-set change lands as a new
format version instead of mutating an immutable leaf.

**Migration sequencing for the immutability rule (user, 2026-06-08).** To avoid
a grandfather exception, order the spec changes: (1) **relax** — drop the blanket
"formats SHALL NOT have versions / are immutable" rule, adding **no** replacement
constraint yet; (2) **migrate** `market.slot.name → gw.market.slot.name` to a
versioned format (legal in this window); (3) **re-constrain** — add "a
versionless format SHALL remain versionless" (versioned-ness fixed at creation).
The one needed promotion happens before the final rule exists, so the final rule
is clean and uniform.

**Mechanism.** Declare the enum dependency as a registry **axiom dependency** on
the versioned format (closure already tracks axiom deps for types). The format
*schema* stays a pure pattern — no in-schema `$ref` — so "formats SHALL NOT
`$ref`" survives; only the immutable / unversioned / dependency-free rules change.

**Rationale (user).** Markets are foundational. We want to decode core market-slot
info (commodity class, product token, maker alias, slot start) directly from the
`gw.market.slot.name` string. That requires acknowledging product names will
evolve, so the decoding format must version in lockstep with
`gw.market.product.name`.

## Versioned-format capability — implementation checklist (not yet built)

The sema-mechanics checklist for the versioned-property-format capability itself
(distinct from §3's market-specific application above, which consumes it).

Three must-fixes the recon surfaced as load-bearing:
- `build_versions.py` emits **no `formats:` section** — `indexes/versions.yaml` is
  types/enums only today; versioned formats must appear there.
- `runtime_generation/templates/format.py:143-146` **hardcodes**
  `from sema.runtime.enums import MarketTypeName` — must use the snapshot
  `import_root` (this is the gjk `ModuleNotFoundError` root cause).
- `build_seed_expanded.py` `absorb_closure` (~208-218) adds formats but never
  expands *their* deps — the one spot where `gw.market.product.name` gets pulled
  once `gw.market.slot.name` declares the axiom dep.

### Spec (`spec/`) — do first (in the relax → migrate → re-constrain order, §3)
- [ ] `spec/primary.md:161` — format glossary row ("Immutable, unversioned … Cannot reference other Sema vocabulary").
- [ ] `spec/authoring/formats.md:81-88` — "## Immutability / Formats do not have versions" → versions allowed, immutable *per version*.
- [ ] `spec/authoring/formats.md:67-73` — drop "SHALL NOT include a Version field" for versioned formats (keep "SHALL NOT `$ref`").
- [ ] `spec/authoring/formats.md:16` — "SHALL NOT reference other Sema vocabulary" → carve out a registry axiom dep on an enum.
- [ ] `spec/registry/formats.md:12,25` — "immutable and unversioned" / "SHALL NOT include version-related information" → allow `versions:`/`latest_version:`/`direct_dependencies.axiom`.
- [ ] `spec/registry/structure.md:78-80` — versioned formats carry per-version status (not word-level).
- [ ] `spec/registry/types.md:340,352,388` — dep-ref syntax: permit `name:###` for versioned formats.
- [ ] `sema/CLAUDE.md` universal MUST "Treat formats as immutable" → "immutable per version".

### Definitions
- [ ] `definitions/registry.yaml` (`gw.market.slot.name`) — add `versions:`/`latest_version:` + `direct_dependencies.axiom: [gw.market.product.name:000]`.
- [ ] `definitions/formats/market.slot.name.yaml` → versioned layout `definitions/formats/gw.market.slot.name/000.yaml`.

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
