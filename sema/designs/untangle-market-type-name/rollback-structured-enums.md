# Rollback: remove the structured-enum sub-capability

Status: Accepted · Pass 1 · Updated 2026-06-08

> Spoke of the [`untangle-market-type-name`](primary.md) design. Reverses the
> [`structured-enums.md`](structured-enums.md) spoke (now superseded). The rest
> of the untangle work stands. Nothing here is published yet, so the rollback is
> clean.

## Why roll it back

The structured-enum capability was introduced to give a *format validator* a
typed per-product `slot_minutes` lookup, so `market.slot.name` could check that
a slot start aligns to the product's period. In commit `8190fdb` that alignment
check was **removed** — `market.slot.name` became a pure structural pattern
(the actual fix for the gjk closure bug). With the check gone, **the structured
enum lost its only in-vocabulary consumer.**

The case for removal:

- **The justification evaporated.** Nothing in the vocabulary consumes `.attrs`
  anymore; the one downstream that might (the MarketMaker app) generates via a
  separate legacy XSLT pipeline that was never taught structured enums.
- **The taxonomy research argues for "name + rich *type*"**, satisfied by the
  `market.product` type (and axioms) — not by smuggling attributes into an enum.
  Type fields get real `$ref`'d units; the enum's `value_attributes` carried
  `quantity_unit` as unvalidated free text (its own Pressure-test #2 admits this).
- **Emergent market semantics belong in type upgrades and axioms** — one home,
  not a third in-between mechanism with weaker guarantees. (See
  [`../../../gridworks-marketmaker/explorations/launch-intentions.md`](../../../gridworks-marketmaker/explorations/launch-intentions.md).)
- **Codegen cost.** The capability added ~240 lines across a fragile hand-rolled
  string-template generator, including an integer path that is a `raise`
  ("string-only for v1") — a knowingly half-built feature serving nothing.
- **Free now.** Unpublished — cheapest moment to reverse.

## Keep vs remove

| Piece | Disposition |
| --- | --- |
| Structured-enum capability (spec §, `StructuredEnum` codegen, `value_attribute_schema`/`value_attributes`) | **Remove** |
| `market.type.name → gw.market.product.name` rename (plain versioned enum) | **Keep** — research-backed naming |
| `market.product` type (open, minimal) | **Keep** — future home for slot/gate/quantity-unit as real fields |
| `market.slot.name` pure-pattern format | **Keep** — the gjk fix + alignment-check drop |
| `frozen_at` word field | **Keep** — orthogonal, tested, useful |

## Plan (independently-green units)

1. **Spec rollback (selective).** Restore `spec/authoring/enums.md` +
   `spec/registry/enums.md` to their pre-`8190fdb` (parent `b843710`) state to
   drop the "Structured Enums" section, the `value_attribute_schema`/
   `value_attributes` rules, and the Forbidden-Fields allow-list additions.
   Revert the `spec/primary.md` glossary enum-row tweak. **Do not touch
   `spec/registry/structure.md`** (`frozen_at` lives there — keep).
2. **Codegen removal.** Strip `_render_structured_string_enum`, the `render_enum`
   branch on `value_attribute_schema`, the integer-path `raise`, the
   `_ATTR_PYTYPE` map, and the `StructuredEnum` blob in `write_enum_base`
   (`src/sema/tools/runtime_generation/enums.py`); remove the `StructuredEnum`
   base + `attrs` from `src/sema/runtime/enums/gw_str_enum.py`. **Keep** the
   `templates/format.py` + `property_format.py` simplifications.
3. **Plain enum.** Drop `value_attribute_schema`/`value_attributes` from
   `definitions/enums/gw.market.product.name/000.yaml`, leaving a plain versioned
   enum (8 tokens, `value_descriptions` only). Keep the rename + `market.product`.
4. **Verify `market.slot.name`** is coherent as a standalone pattern (format +
   registry + simplified validator) with no dangling structured-enum reference.
5. **Regenerate + test.** `scripts/regenerate_runtime.py` + `build_indexes.sh`;
   prune structured-enum tests (keep `frozen_at` + `market.product` tests);
   `pytest` green; suggest commit + draft changelog entry.

## Spec strengthening (fold into unit 1)

The original spec already forbids formats referencing other Sema vocabulary
(`authoring/formats.md:16,67-70`) — enums included, so no enum-specific line is
needed. But the gjk hole was a validator reaching an enum **in generated code**,
not via a schema `$ref`. Add a one-line clarification that the no-reference rule
binds a format's **validation behaviour / generated validator**, not only its
schema `$ref`. This is the lesson that, if explicit, would have prevented the
tangle.

## Deferred follow-ups (NOT this rollback)

- **`%300` slot-start axiom** — a `market.slot.name` slot start divisible by
  300 s (5-min granularity; VCharge thesis + ISO RT patterns). Enum-free (a
  constant, not a per-product lookup) — which is *why* the rollback is clean.
- **Human-readable UTC slot-start helper** in `property_format`.
