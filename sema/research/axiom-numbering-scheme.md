# Axiom numbering scheme — open question

Status: Draft · Pass 0 · Updated 2026-05-23

What this is: an unresolved spec design question surfaced during the
spec-bakeoff sweep. Not normative — this is `research/`, not `executor/`.
Park here until decided; do not write tests against it until the question
is closed.

## The question

The spec (`sema/spec/authoring/type-semantics.md` §Axioms) requires every
axiom to have a positive-integer `number:` field, in strict ascending
order from 1, plus the lowercase clause-label mechanism (`a. / b. / c.`)
for sub-clauses within one axiom.

`gw.nolan.layout/000` has 30+ axioms (most with empty `number:` fields —
a separate cleanup question) that naturally cluster into groups: identity
/ topology / channel-existence / channel-binding / channel-semantics /
relay-semantics. The drafter wanted hierarchical numbering (`1.2.3`) to
communicate the grouping.

## Why this surfaced

During the spec-bakeoff sweep, the existing `gw.nolan.layout/000`
axioms (which are structurally non-compliant — missing `number:`
fields) prompted the question: should we change the numbering scheme
*before* fixing them, in case the right answer is hierarchical?

## Sketch of the alternatives

1. **Keep flat positive integers** (current spec).
2. **Allow hierarchical dotted numbers** (`1`, `1.1`, `1.2`, `2`, …).
3. **Keep flat numbers, add optional `group:` metadata** — purely
   organizational, no impact on counterexample fixture naming or
   `check_axiom_<n>` Python validator naming.
4. **Refactor large axiom lists into clause-based axioms** — the
   existing `a. / b. / c.` clause-label mechanism was designed exactly
   for this. `gw.nolan.layout`'s pipe/tank/zone channel-semantics
   axioms are highly parallel and would collapse into a few multi-clause
   axioms.

## Trade-offs

- Hierarchical numbering forces a definition of ordering (lexicographic
  vs. segment-numeric: is `1.10` after `1.9`, or after `1.1`?) and
  breaks the existing fixture-naming convention (`axiom_<n>.json`,
  `check_axiom_<n>`). Dotted numbers don't translate cleanly into Python
  identifiers.
- Optional `group:` is cheap and reversible.
- Refactoring toward clause-based axioms is the most spec-faithful
  option but is real work and is type-by-type.
- A large axiom list may itself be a smell — `gw.nolan.layout` could
  plausibly be decomposed into smaller types each with their own axiom
  set.

## What to do for now

- **Do NOT add a `test_axiom_numbering.py`** test until this question
  is resolved. The currently-published spec text would justify the
  test, but landing it now would force a fix to `gw.nolan.layout` in a
  direction we might want to revisit.
- The bakeoff's other four test additions (primitive constraints
  extension, inline-object `additionalProperties` extension, example
  format, identity consistency) are unblocked and going ahead.

## Decision required from

The spec owner. Not load-bearing on any other in-flight work; can sit
until convenient.
