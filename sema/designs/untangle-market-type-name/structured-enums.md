# Design: Structured Enums (per-value typed attributes in Sema vocabulary)

Status: Accepted · Pass 1 · Updated 2026-06-08

> Spoke of the [`untangle-market-type-name`](primary.md) fractal design
> (issue OPS-378). A spoke, **not** a standalone design — it has no own Linear
> id; it shares the hub's issue, per the design↔issue bijection.

What this is: the change plan for a new Sema capability — an **enum whose
values each carry a fixed, typed set of attributes** (a faithful, machine-
readable decode of the value token), emitted by codegen as accessors. This is
the load-bearing mechanic the
[`primary.md`](primary.md) decision depends
on (its active path was left "TBD" pending this spec). The capability is
reusable beyond markets, so it lives in its own change plan; when implemented,
the durable rules fold into `sema/spec/authoring/enums.md` +
`sema/spec/registry/enums.md` and this file is deleted.

## Why this exists (relation to the untangle problem)

`primary.md` chose to move market-product semantics **into the
vocabulary** rather than into a format validator (which can't `$ref`) or a
separate catalog (a second source of truth). The chosen vehicle is a *structured
enum*: each `market.product.name` token (e.g. `rt60gate5`) decodes to its slot
timing — commodity class, slot minutes, gate offset, quantity unit. Today Sema
enums carry only `value_descriptions` (free prose), which is not machine-typed
and not decodable. This capability makes the decode **structural, typed, and
codegen'd**, so consumers read `…rt60gate5.attrs.slot_minutes == 60` instead of
parsing the string or reaching a side table.

Crucially it does this **without reintroducing the closure edge** that caused the
original gjk failure (see below).

## Concept

A **structured enum** is an ordinary Sema enum (`literal` or `versioned`,
`string`-valued for v1 — see Pressure test #4 for why integer is deferred) that
additionally declares, per value, a row of **attributes** conforming to a single
declared **attribute schema**.

- Attributes are **vocabulary metadata**, not serialized message fields. The
  on-the-wire value of a structured-enum-valued property stays the bare token
  (`"rt60gate5"`). Principle 2 (CamelCase serialized fields) and Principle 2a
  (validation at the serialized boundary) are untouched — there is no new field
  on the wire. The attributes are a *derived decode* available at authoring and
  codegen time, carried by the vocabulary word itself.
- This is the structural expression of Principle 4 (`spec/primary.md:89` —
  "Semantics at the Boundary Must Be Declared"): the name-decodable semantics
  that affect how the token is interpreted are now declared in the schema, not
  left to code conventions or comments.
- "Structured" is **orthogonal** to `enum_type`. A structured enum may be
  `literal` (fixed) or `versioned` (additive). The market-product enums are
  `versioned` (products get added over time).

## Invariants (the new normative rules)

1. **Totality.** Every enum value SHALL have exactly one attribute row, and each
   row SHALL provide a value for **every** attribute declared in the attribute
   schema. A structured enum is a *total* decode — no value may be silently
   undecodable. **Enforcement point:** authoring/registry validation (the same
   pass that checks `value_descriptions` conformance) SHALL reject any structured
   enum where a non-exempt value lacks a row or a row omits a declared column;
   this is a build-time gate, not a runtime check. (Exemption: **only the single
   value named in `default`** MAY omit its row, decoding to `.attrs == None`. A
   structured enum with no `default` has **no** exempt value and SHALL provide a
   row for every value. Multiple sentinels are not a concept — there is exactly
   one `default` per enum schema, so at most one value is ever exempt.)
2. **Primitive, dependency-free attributes.** Attribute values SHALL be JSON
   primitives (`string`, `integer`, `number`, `boolean`, or `null`). An
   attribute value SHALL NOT be a `$ref` to any other Sema vocabulary, and SHALL
   NOT be a nested object or array. *This is the property that keeps structured
   enums closure-leaf-clean:* a structured enum introduces **no new dependency
   edges**, so it cannot recreate the format→enum tangle that
   `primary.md` exists to remove. A token like `"AvgkW"` is a
   bare string literal here, not a reference to `market.quantity.unit`. *This
   buys closure-leaf cleanliness at the cost of an unvalidated semantic
   dependency* — `quantity_unit` is conceptually a controlled vocabulary carried
   as free text (see Pressure test: this is a real, accepted-for-v1 tradeoff, not
   a non-issue). For **v1, columns are free text** — no closed-list constraint
   machinery (decided 2026-06-08). A closed `enum:` member-list on a column is a
   possible **future** addition (still no `$ref`, no closure edge) and is
   forward-compatible — adding it later constrains nothing already authored — so
   it is deliberately out of v1.
3. **Attribute immutability per value.** Once a value's attribute row is
   published, the **existing cells** of that row SHALL NOT change in any later
   version — same stability rule enums already apply to value *meaning*
   (`authoring/enums.md:148-150`). A changed decode of an existing column means a
   new value, not a mutated cell. *Adding a cell for a newly-introduced column
   (Invariant 4) is not a mutation:* the row grows monotonically, every cell that
   ever existed keeps its published value, so any decode performed against a given
   column is stable forever once that column exists. (See Pressure test: 3-vs-4 is
   reconciled as "cells are append-only; published cells frozen.")
4. **Additive attribute schema.** The attribute schema itself evolves additively
   in `versioned` structured enums: a new version MAY **add** an attribute
   column (appended after existing columns; never inserted between them) and
   SHALL then populate it for *every* existing value, preserving totality, but
   SHALL NOT remove, rename, reorder, or retype an existing column. The
   back-population value chosen for a pre-existing value's new cell is itself
   frozen by Invariant 3 from the moment that column ships. `literal` structured
   enums have a fixed attribute schema (version `000` only).

## Authoring spec changes — `sema/spec/authoring/enums.md`

Add an **Optional Metadata** block and corresponding rules. Two new
`x-gridworks` keys:

- `value_attribute_schema` — declares the columns once: a map of
  `<attribute-name>` → `{ type: string|integer|number|boolean }`. Attribute
  names use snake_case (they are not serialized fields, so the CamelCase rule
  does not bind them; snake_case matches their codegen surface as Python
  attributes). A column is implicitly nullable (a value's row MAY set it
  `null`); `type` constrains the non-null values.
- `value_attributes` — the rows: a map of `<EnumValue>` → `{ <attribute-name>:
  <primitive> }`, one entry per enum value, each entry providing every declared
  column.

Rules to add:
- `value_attributes` MAY appear only within `x-gridworks`, and only when
  `value_attribute_schema` is also present.
- When `value_attribute_schema` is present, the enum is a **structured enum**
  and the Totality + Primitive + Immutability + Additive-schema invariants above
  apply.
- Each `value_attributes` row SHALL conform to `value_attribute_schema` (every
  declared column present; each value matching its declared `type` or `null`).

Update the **Forbidden Extra Fields** list (`authoring/enums.md:126-132`): the
within-`x-gridworks` allow-list grows from `{owner, version,
value_descriptions, extended_description}` to additionally permit
`value_attribute_schema` and `value_attributes`. (This is the specific
invariant the design sketch in `primary.md:118-124` flagged as
"not yet authorable" — this change makes it authorable.)

## Registry spec changes — `sema/spec/registry/enums.md`

Minimal. The enum **schema file stays authoritative** for the attribute schema
and rows (same posture as `value_type` today — registry holds a compact copy,
schema file is the source, `registry/enums.md:26-28`). Options, cheapest first:

- **(A, preferred) Record nothing new in the registry.** Structured-ness is
  detected by tooling from the schema file's `value_attribute_schema`. No
  registry-shape change; `enum_type` and `value_type` are unaffected.
- (B) Record an optional boolean `structured: true` on the entry for compact
  tooling/validation, mirroring how `value_type` is mirrored. Adds a registry
  field to keep in sync for marginal tooling convenience.

Going with **(A)** unless a tooling pass shows the registry needs the flag for
cheap filtering. Either way, `enum_type` semantics (`literal`/`versioned`) are
unchanged — structured-ness is orthogonal.

## Codegen changes — `sema/src/sema/tools/runtime_generation/`

`enums.py` currently renders `SemaEnum` subclasses with bare members
(`_render_string_enum`, `enums.py:189`). Add a structured path:

- **New base `StructuredEnum(SemaEnum)`** in `write_enum_base`
  (`enums.py:41`), alongside the existing `SymbolizedEnum` precedent
  (`enums.py:129`) — `SymbolizedEnum` already establishes that Sema codegen may
  enrich an enum with per-value data beyond the token, so this is a known
  pattern, not a new architecture.
- **Generated interface (the consumer-facing contract):**
  - a generated frozen attribute record type (a `@dataclass(frozen=True)`) with
    one typed field per declared column;
  - a per-member accessor — `member.attrs` returning that record (or `None` for
    a sentinel with no row);
  - the column names and types come straight from `value_attribute_schema`.
- **Codegen mechanism constraint (load-bearing).** The attribute table MUST NOT
  be written as a plain class-body assignment on the Enum subclass: Python's
  `Enum` metaclass would try to treat a class-level data attribute as a member.
  The existing runtime already dodges this — `_init_index_maps` assigns
  `_index_to_value`/`_value_to_index` *lazily after class creation* rather than
  in the class body (`enums.py:79-85`). Structured-enum codegen SHALL follow the
  same pattern (module-level table or deferred/lazy assignment), not a naive
  class-body dict.
- `render_enum` (`enums.py:145`) branches to the structured renderer when the
  schema carries `value_attribute_schema`. **Integer asymmetry (load-bearing,
  see Pressure test):** the string path emits a `SemaEnum` subclass, but the
  integer path (`enums.py:243-256`) emits a **plain `IntEnum`** — not a
  `SemaEnum`/`GwStrEnum` subclass — and derives member names from
  `value_descriptions` (`enums.py:173-177`, `helpers.py:178-191`). So a
  `StructuredEnum(SemaEnum)` base does **not** cover the integer case. v1 SHALL
  support **string structured enums only**; integer structured enums are
  out-of-scope until the integer path is unified onto a shared Sema base (a
  separate change). The market-product enums are string-valued, so this does not
  block the untangle.
- **Concrete generated shape (string path, deferred table):** the renderer emits
  the frozen `…Attrs` dataclass, the `SemaEnum` member block unchanged, and then
  — *outside the class body* — a module-level `dict[str, …Attrs]` keyed by the
  member `.value`, attached via a classmethod/property that reads it lazily,
  exactly mirroring `_init_index_maps` (`enums.py:79-85`). `member.attrs` resolves
  through that table; the table assignment SHALL NOT appear in the class body
  (Enum metaclass would absorb it as a member). The `.attrs` accessor returns
  `None` iff the member is the exempt `default` with no row.
- The hardcoded-import-root bug that `primary.md` documents in
  the *format* template (`templates/format.py:143-146`) is a separate fix; the
  enum codegen already threads `import_root` (`enums.py:21`), so the structured
  renderer SHALL likewise parameterize it — no new hardcode.

## Closure / index behavior — the key property

Structured enums require **no change** to dependency tracking, and that is the
point. Because attribute values are primitives with no `$ref` (Invariant 2), a
structured enum is exactly as much of a closure leaf as a plain enum: it is
pulled into a consumer snapshot by the same `$ref` edges that already reference
it, and it drags in nothing further. The original gjk failure was a *hidden*
edge (a format validator reaching an enum the closure couldn't see); structured
enums add **zero hidden edges**. Verify this explicitly in the build tools pass —
the closure/seed-expander code SHALL NOT need a special case for structured
enums.

## Namespacing convention (many product enums)

Per Principle 5 (`spec/primary.md:109` — vocabulary is namespace-scoped, orgs
define their own under distinct namespaces), the product vocabulary is **opened
by multiplicity, not by an open pattern**: many structured enums, one per **market
maker / owning org** (NOT per territory — territory lives in the slot name, see
`primary.md` §1), named `<ns>.market.product.name` where `<ns>` is the maker's
namespace — e.g. `gw.market.product.name` is GridWorks's own product vocabulary;
another maker would carry `acme.market.product.name`. The `market.product` type's
`ProductNameEnum` field names which structured enum a given `Name` belongs to,
disambiguating the namespaced set. Each is independently versioned.

## Worked example

Authored structured enum (now legal under the authoring change above):

```yaml
$schema: "https://json-schema.org/draft/2020-12/schema"
$id: "https://schemas.electricity.works/enums/gw.market.product.name/000"
title: "gw.market.product.name"
type: "string"
description: >
  GridWorks's own market-product vocabulary (the maker's products, deployed
  across whatever territories GridWorks operates in). Each token decodes
  directly to its slot timing.
enum: ["unknown", "da60", "rt60gate5", "rt60gate30", "rt60gate30b", "rt30gate5", "rt15gate5", "rt5gate5"]
default: "unknown"
x-gridworks:
  owner: "gridworks-energy"
  version: "000"
  value_descriptions:
    "da60": "Day-ahead energy, 60-minute slots"
    # … one per value …
  value_attribute_schema:
    timeframe:     { type: string }
    slot_minutes:  { type: integer }
    gate_minutes:  { type: integer }
    quantity_unit: { type: string }
  value_attributes:
    da60:        { timeframe: da, slot_minutes: 60, gate_minutes: null, quantity_unit: AvgkWh }
    rt60gate5:   { timeframe: rt, slot_minutes: 60, gate_minutes: 5,    quantity_unit: AvgkWh }
    rt60gate30:  { timeframe: rt, slot_minutes: 60, gate_minutes: 30,   quantity_unit: AvgkWh }
    rt60gate30b: { timeframe: rt, slot_minutes: 60, gate_minutes: 30,   quantity_unit: AvgkW  }
    rt30gate5:   { timeframe: rt, slot_minutes: 30, gate_minutes: 5,    quantity_unit: AvgkWh }
    rt15gate5:   { timeframe: rt, slot_minutes: 15, gate_minutes: 5,    quantity_unit: AvgkWh }
    rt5gate5:    { timeframe: rt, slot_minutes: 5,  gate_minutes: 5,    quantity_unit: AvgkWh }
    # "unknown" — sentinel, no row (all-null decode)
```

Generated runtime shape (interface, not literal emission — see mechanism
constraint above):

```python
@dataclass(frozen=True)
class GwMarketProductNameAttrs:
    timeframe: str | None
    slot_minutes: int | None
    gate_minutes: int | None
    quantity_unit: str | None

class GwMarketProductName(StructuredEnum):
    """Sema: https://schemas.electricity.works/enums/gw.market.product.name/000"""
    unknown = auto()
    da60 = auto()
    # …
    # attribute table attached via the deferred pattern, NOT a class-body member

# consumer:
GwMarketProductName.rt60gate5.attrs.slot_minutes   # -> 60
GwMarketProductName.unknown.attrs                  # -> None
```

## Migration of the existing word

`market.type.name` (today: a `versioned` enum with `value_descriptions` only —
`definitions/registry.yaml:463-472`, `definitions/enums/market.type.name/000.yaml`)
is renamed and upgraded under the untangle plan to
`gw.market.product.name` (structured, `versioned`, `000`), carrying the
same eight tokens plus the attribute rows above. The rename + the `market.product`
type are owned by `primary.md`; this design owns only the
*structured-enum mechanism* that makes the new word authorable. Sequencing: land
this capability first (so the word is authorable and codegen'd), then the
untangle renames + the `market.product`/`ltn.bid` types (`gw.market.slot.name`
becomes a versioned format declaring an axiom dep on this enum — `primary.md` §3).

## Implementation checklist (not yet built)

### Spec (`sema/spec/`) — do first
- [ ] `authoring/enums.md` — add `value_attribute_schema` + `value_attributes`
      optional-metadata block + rules; extend the within-`x-gridworks`
      Forbidden-Fields allow-list (`:126-132`).
- [ ] `authoring/enums.md` Evolution Rules — add the Totality / Primitive /
      Attribute-immutability / Additive-attribute-schema invariants.
- [ ] `registry/enums.md` — note structured-ness is schema-file-authoritative
      (option A); decide A vs B.
- [ ] `primary.md` Glossary (`:162`) — extend the **enum** row to mention
      structured enums (values may carry typed attribute rows).
- [ ] `sema/CLAUDE.md` — the "enums additive only" MUST extends to attribute
      rows/columns (additive, never mutate).

### Definitions
- [ ] (Owned by untangle) author `gw.market.product.name/000.yaml` as a
      structured enum; registry entry.

### Codegen (`src/sema/tools/runtime_generation/`)
- [ ] `enums.py:41` `write_enum_base` — emit `StructuredEnum` base.
- [ ] `enums.py:145` `render_enum` — branch to structured renderer on
      `value_attribute_schema`.
- [ ] new `_render_structured_string_enum` — frozen attr record + deferred
      attribute table + `.attrs` accessor; thread `import_root`. (Integer path
      deferred: the integer renderer emits a plain `IntEnum`, not a `SemaEnum`
      subclass — see Pressure test. v1 is string-only.)

### Build tools / indexes (`src/sema/tools/`)
- [ ] Confirm (with a test) that closure / seed-expander / public-registry need
      **no** structured-enum special case (Invariant 2). If any does, that is a
      smell to investigate, not a feature to add.

### Tests (`tests/`)
- [ ] `registry/` + `runtime/` — authoring validation: totality, primitive-only,
      schema conformance, additive-only attribute evolution.
- [ ] runtime generation — generated `.attrs` shape + `None` sentinel + typed
      fields. Assert old-version structured enums (`enums/old_versions/`) also
      emit their (version-appropriate) attribute table, since `attrs`-bearing
      consumers may pin an old version (see Pressure test).
- [ ] a structured enum in a **restricted consumer snapshot** pulls in nothing
      extra and codegens cleanly (the gjk-class regression guard).
- [ ] Regen + green: `scripts/build_indexes.sh`, `scripts/regenerate_runtime.py`,
      `pytest`.

## Open questions
- **Registry option A vs B** — settle during the tools pass; leaning A (record
  nothing new), per the Registry section.

> Resolved questions (sentinel handling) moved into the Pressure test below.

## Pressure test (hardening before Accepted)

Adversarial review of the four invariants + mechanism. Invariants 1, 2, 3, 4
and the Codegen section were **edited in place** as a result; deltas noted per
finding.

1. **Invariant 3 vs 4 — "immutable row" vs "add a column and back-populate."**
   **Verdict: not a contradiction once cells, not rows, are the unit of
   immutability — but the original wording was a real hole.** Adding a column
   does grow an existing value's row, which the old Invariant 3 ("the row SHALL
   NOT change") literally forbade. **Resolution (edited Inv. 3 + 4):** immutability
   binds **published cells**, not the row as an object; columns are
   **append-only** (new columns appended after existing ones, never inserted or
   reordered), and a back-populated cell is frozen from the version it ships in.
   This makes every per-column decode monotone and stable forever: a consumer
   reading `.attrs.slot_minutes` against any value gets the same answer in v001
   and v007. Note the consequence: `…Attrs` for an old version has *fewer*
   columns than for a newer one (it is a structural prefix) — codegen for
   `old_versions/` MUST emit the version-appropriate (narrower) dataclass, not
   the latest schema. Captured in the test checklist.

2. **Invariant 2 — does primitive-only truly close the hidden-edge hole, or just
   push the dependency into a bare string?** **Verdict: real, accepted tradeoff —
   not a non-issue.** Forbidding `$ref` genuinely removes the *closure* edge (the
   gjk failure was the closure expander not seeing a format→enum `$ref`; a bare
   string is invisible to closure by construction, so the regression class is
   actually gone). But it does **not** remove the *semantic* dependency:
   `quantity_unit: "AvgkW"` is a stringly-typed reference to what is conceptually
   `market.quantity.unit`, and nothing validates that the string is a real member
   of that vocabulary — a typo `"AvkW"` would pass. That is a weaker, different
   bug (silent-bad-data, not snapshot-incompleteness) and it is **contained**:
   it cannot drag hidden vocabulary into a consumer snapshot. **Resolution (edited
   Inv. 2):** keep `$ref` forbidden for v1, and **v1 columns are free text**
   (decided 2026-06-08 — smallest surface, fully forward-compatible). A closed
   `enum:` member-list on a column is recorded as a future option, not v1; the
   open `market.product` model (`Name`/`ProductNameEnum` are bare strings — see
   `primary.md` §2) makes consumer-side validation the norm here anyway.

3. **Invariant 1 — totality + sentinel exemption.** **Verdict: clean once scoped
   to exactly the `default` value; the prior "typically `unknown`" phrasing was
   loose.** **Resolution (edited Inv. 1):** the exemption is **only** the single
   value named in `default`; an enum with no `default` (legal — `default()`
   returns `None`, `gw_str_enum.py:98-99`) has **no** exempt value and SHALL be
   row-total. "Multiple sentinels" is a non-issue: a Sema enum schema has at most
   one `default` (`authoring/enums.md:66-68`). **`.attrs` ergonomics / None-
   safety:** `.attrs` returns `…Attrs | None`, `None` iff the member is the
   exempt default — so consumers MUST None-guard exactly where they already
   None-guard `default()`/`_missing_` coercion. **Enforcement point named:**
   build-time authoring/registry validation (not runtime), same pass as
   `value_descriptions` conformance.

4. **Codegen mechanism robustness.** **Verdict: sound for the string path; the
   doc's `member.attrs` was underspecified and the integer path was a latent
   trap.** The `Enum`-member-vs-data-attribute gotcha is real and the
   `_init_index_maps` deferred pattern (`enums.py:79-85`) is the correct dodge —
   a module-level table + lazy accessor, never a class-body dict. **Concrete shape
   added** to the Codegen section. Interactions checked: `values()` (iterates
   members, unaffected — the table is keyed off `.value`); `_missing_`/`default`
   coercion (unaffected — coercion yields a member, `.attrs` then resolves
   normally, `None` for the exempt default); StrEnum identity (the `.value` token
   is unchanged on the wire — Invariant/Principle 2 untouched). **Latent trap
   found:** `StructuredEnum(SemaEnum)` cannot serve the **integer** path, which
   emits a bare `IntEnum` (`enums.py:243-256`) with member names derived from
   `value_descriptions` — a different base class and a different naming source.
   **Resolution (edited Codegen + checklist): v1 is string structured enums
   only.** Integer structured enums wait for a separate change that first unifies
   the integer renderer onto a shared Sema base. Market products are string-
   valued, so the untangle is unblocked.

5. **Versioned + structured interaction (old versions, integer path).**
   **Verdict: real gap in coverage, now closed.** `old_versions/` enums are
   codegen'd (`enums.py:38`), so a structured enum's old versions MUST also emit
   attribute tables — and (per finding 1) each old version's `…Attrs` is the
   *prefix* of columns that existed then, not the latest schema. The doc did not
   say this; added to the test checklist. The integer conflict (`value_descriptions`
   is mandatory for integer enums and also drives member naming) is subsumed by
   the v1 string-only scoping in finding 4 — no separate work.

> **Divergence flag (Source precedence).** This design amends current Sema
> invariants: `authoring/enums.md` today forbids any within-`x-gridworks` field
> beyond `{owner, version, value_descriptions, extended_description}`
> (`:126-132`). Until the spec edits above land, the spec still says otherwise —
> implementers MUST carry this decision into `sema/spec/` rather than let the
> record drift. Per `sema/CLAUDE.md`, structured-enum changes still obey every
> Universal MUST (enums additive only, CamelCase serialized fields — N/A here
> since attributes are not serialized, formats immutable, pass pytest + registry
> validation).
