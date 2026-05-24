# Typed Maps — open edge cases

Status: Draft · Pass 0 · Updated 2026-05-24

What this is: known unanalyzed edge cases for the Typed Maps
construct introduced in `sema/spec/authoring/types.md`. Park here;
revisit when a real use case forces resolution.

## The construct (recap)

A typed map is `type: object` + `propertyNames: {$ref: <key-format>}`
+ `additionalProperties: {$ref: <value-type>}`. Currently two blessed
key formats: `non.empty.string` (string-keyed) and
`positive.int.as.str` (int-keyed).

## Edge cases not yet analyzed

### 1. Typed maps inside `oneOf`

```yaml
SomeField:
  oneOf:
    - $ref: ".../types/foo/000"
    - $ref: ".../types/bar/000"
    # Can a oneOf branch be an inline typed map?
```

The current Composition Rule says each `oneOf` branch SHALL be an
object containing exactly one `$ref` to a Sema type or enum. A typed
map is neither — it's a structural pattern. So under the letter of
the rule, typed maps in `oneOf` are forbidden. Whether that's the
right call is unanalyzed. If a use case appears, decide whether to
allow typed-map branches and what their shape would be.

### 2. Arrays of typed maps

```yaml
SomeField:
  type: array
  items:
    type: object
    propertyNames:
      $ref: ".../formats/positive.int.as.str"
    additionalProperties:
      $ref: ".../types/foo/000"
```

A list where each element is itself a typed map. Currently neither
explicitly allowed nor forbidden. Adds a layer of nesting that may
or may not deserve a wrapper named type instead. Revisit if a use
case appears.

### 3. Typed maps as a value type of another typed map

```yaml
NestedMap:
  type: object
  propertyNames: {$ref: ".../formats/non.empty.string"}
  additionalProperties:
    type: object
    propertyNames: {$ref: ".../formats/positive.int.as.str"}
    additionalProperties:
      $ref: ".../types/foo/000"
```

Map of maps. Almost certainly the right design is to promote one
level to a named Sema type, but the spec hasn't said so. Revisit
if it shows up.

### 4. Sub-range constraints on int-keyed maps

Tank wants integer keys but only in the range 1-6. The
`positive.int.as.str` format covers "positive" but not the upper
bound. Today the upper bound lives in consumer code (or could move
to an axiom under the conditional-axiom rule if the cardinality
were tied to a sibling discriminator). Whether to formalize range
constraints (e.g., a `positive.int.as.str.bounded` family, or a
Sema-level keyword for map cardinality) is open. Defer until n>=2.

### 5. Growth discipline for blessed key formats

The spec currently blesses two key formats (`non.empty.string`,
`positive.int.as.str`). The "binary string XOR int" framing is
load-bearing for the construct's mental model. Each new key format
weakens that framing.

Guardrail: don't add a third key format casually. If a real use
case appears (e.g., uuid-keyed maps), document it here as a real
demand signal before adding the format. Aim for fewer than 5
blessed key formats long-term — if we're approaching that, the
construct has drifted and probably needs rethinking.

## What to do when one of these appears

When a real schema needs one of the above, don't widen the spec
silently. Surface the case, decide explicitly (allow / forbid /
require-promote-to-named-type), and update both the spec and this
research note.
