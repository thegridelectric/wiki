# Discriminated type unions: the runtime decodes a oneOf of types by TypeName and Version

Status: Draft · Pass 0 · Updated 2026-11-04 · Linear: OPS-651
**EDD: no** — a generator change, verified by the suite plus the prototype
table below and a pyright-clean regenerated runtime.

> What this is: the generated Python runtime decodes a `oneOf` of types
> as a plain union, so pydantic picks the first branch whose required
> fields the input satisfies and fills in that branch's TypeName and
> Version defaults. A member with no TypeName is accepted. This design
> makes the generator emit a tag-discriminated union, so the branch is
> chosen by TypeName and Version alone.

## The gap

Every `oneOf` in the registry is a closed union of `$ref`s, as the
Composition Rule in `sema/spec/authoring/types.md` requires. On
2026-11-01 there are 44 such sites across 33 word files. One is a union
of enums (gw.alert `Kind`), which the generated class already decodes
by its sibling `Category`. The other 43 are unions of types, in two
shapes:

- **Version unions of one type**: layout.lite (`Ha1Params`,
  `TankModuleComponents`, `ShNodes`, `DerivedChannels`), scada.params
  `OldParams` and `NewParams`, report `FsmReportList`, atn.bid
  `PqPairs`, new.command.tree `ShNodes`, gw.readings `Channels`,
  layout.bundle `Layouts`, gw.house.summary `Layout`.
- **Sibling-type unions**: flo.params `Tuning`, gw.operational.params
  `FamilyParams`, the `Components` and `DeviceTypes` items of
  gw.house0.layout, gw.house0.no.sieg and gw.nolan.layout, gw.hydronic
  `Backup`, gw.weather.create.cmd `Record`, fsm.atomic.report `Action`.

The generator (`src/sema/tools/runtime_generation/types.py`,
`_annotation_for_schema`) renders a `oneOf` as `A | B` and renders each
branch's TypeName and Version as `Literal["x"] = "x"`. Pydantic treats a
Literal with a default as optional and tries the union's branches in
order, so an input whose TypeName or Version is missing is accepted by
the first branch whose other required fields it satisfies. A branch
with a TypeName present but wrong is already rejected by the Literal.
Reproduced against the generated classes: `flo.tuning.alice` has no
fields of its own, so `Tuning: {}` decodes as alice.

The same emit fails pyright. The base class declares `type_name: str`
and `version: str | None`; every generated class narrows both to a
Literal, and pyright reports `reportIncompatibleVariableOverride` on
each, since a mutable attribute is invariant. On 2026-11-04 that is 662
of the runtime's 757 pyright errors, two per class; mypy accepts the
narrowing. A further 76 are the gw.house0.layout axiom template reading
`board_component_id` across the `Components` union, where not every
member has the field. Every consumer excludes its vendored snapshot
from pyright for this reason (gridworks-base, gridworks-journalkeeper),
so pyright asserts nothing about generated classes anywhere.

This contradicts spec Principle 3 (every type declares its identity)
for a nested member, and it is the type-union twin of the enum rule the
Composition Rule already states: decode the branch the discriminator
selects, never by trying branches in order.

## The fix

The generator emits, for every `oneOf` of types, a pydantic
tag-discriminated union whose tag is `<TypeName>/<Version>`:

```python
Tuning = Annotated[
    Union[
        Annotated[FloTuningAlice, Tag("flo.tuning.alice/000")],
        Annotated[FloTuningBruce, Tag("flo.tuning.bruce/000")],
    ],
    Discriminator(sema_tag),
]
```

`sema_tag` lives once in `sema.runtime.base`: it reads `TypeName` and
`Version` off a raw dict, or `type_name` and `version` off an instance,
and returns `None` when either is missing. The composite tag covers
both shapes above with one mechanism; a single-key discriminator cannot
tell `ha1.params/004` from `ha1.params/005`. The same rendering applies
to a `oneOf` under `items` (`list[...]`) and inside an inline object,
since all three go through `_annotation_for_schema`.

Prototyped 2026-11-01 over the real FloTuningAlice and FloTuningBruce
classes:

| input member | result |
|---|---|
| `{TypeName: flo.tuning.alice, Version: 000}` | FloTuningAlice |
| `{}` | rejected, `union_tag_not_found` |
| `{Version: 000}` | rejected, `union_tag_not_found` |
| alice at Version 001 | rejected, `union_tag_invalid` |
| unknown TypeName | rejected, `union_tag_invalid` |
| python-name construction, `by_alias` dump | unchanged |

Why the discriminator and not a validator row on the containing type: a
`model_validator` runs after pydantic has already filled the wrong
branch, so it would have to re-read the raw input in before-mode, which
is a hand-rolled copy of what the discriminator does natively. The
discriminator also ends branch trial entirely, so two branches with
overlapping shapes can never be confused.

This is a generator rule for every word at once. No word changes, and
no axiom is written per word.

The discriminator reads the Literal TypeName and Version off each
branch, so the pyright fix cannot be to stop narrowing. The declaration
of `type_name` and `version` has to satisfy pyright with the Literal
kept; the prototype table above is the regression check that whatever
shape is chosen still rejects the tagless member. The axiom template
narrows with `isinstance` before reading a member-specific field.

## Plan

1. `sema_tag` in `sema.runtime.base`, with a unit test.
2. The generator renders every `oneOf` of types as above; the
   generator test suite gains a `oneOf` fixture covering a sibling-type
   union, a version union, and a union under `items`.
3. Regenerate the runtime. Expect every oneOf-bearing class to change.
4. Runtime tests: flo.params `Tuning` and gw.operational.params
   `FamilyParams` reject a tagless member and a member at a version the
   union does not list.
5. Spec: one sentence added to the Composition Rule in
   `sema/spec/authoring/types.md`, stating that TypeName and Version
   discriminate a `oneOf` of types and implementations decode by them.
   The spec is change-controlled; this line is agreed with the human
   before it is written.
6. The regenerated runtime passes pyright: the `type_name` and
   `version` declarations satisfy both checkers with the Literal kept,
   and the gw.house0.layout axiom template narrows before it reads.
   `src/sema/runtime` leaves sema's pyright exclude in the same change.

Effort: 3.5 h point, 2 to 6 h at 90%. The pyright step adds an hour at
the point and widens the high bound: the declaration shape is one
decision, and the regen diff touches every class.

## Consumers

- **gwsproto (gridworks-scada).** The hand-written twins already
  discriminate `FamilyParams` (`operational_params.py`) and `Backup`
  (`hydronic.py`) with `Field(discriminator="TypeName")`, a single-key
  discriminator that is right for a sibling-type union at one version
  each. A twin for a version union would need the composite tag. Until
  the proactor port regenerates the twins, a new twin with a `oneOf`
  takes the discriminator by hand, with a note naming this design's
  Linear issue.
- **TypeScript runtime (jm/ts).** The same rule applies. zod's
  `discriminatedUnion` takes one key, so a version union needs a
  custom refinement or a `superRefine` on the pair. Record the rule on
  that branch; build it when the generator reaches a oneOf-bearing
  word.
- **Vendored snapshots.** gridworks-base and gridworks-journalkeeper
  exclude their snapshot from pyright. After this regenerates, each
  drops the exclude at its next snapshot regen.

## Open

- Whether the enum-union case (gw.alert `Kind`) should move onto the
  same generator path, with the sibling discriminator declared in the
  schema rather than in an axiom the generator reads. Out of scope
  here; noted so the two rules converge later.
