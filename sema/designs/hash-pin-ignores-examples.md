# Design: hash pin ignores examples

Status: Draft · Pass 0 · Updated 2026-09-08 · Linear: OPS-528

> What this is: make the published-hash tripwire hash a schema's
> validating content, not its bytes, so an `examples:` block can be added
> to a published version without a sanctioned re-pin.

## The problem

`definitions/published_hashes.yaml` pins the sha256 of every published
schema file, and `tests/registry/test_published_hashes.py` fails when a
pinned file's bytes change. That is the immutability rule made
mechanical. A second gate, `tests/registry/test_superseded_examples.py`,
requires every superseded type version to carry an `examples:` block,
because the example is the fixture the snapshot round-trip decodes
through the old version and upgrades. A version published without an
example trips the two gates against each other the day it is superseded:
adding the example is the only way to satisfy the second, and the first
reads it as an in-place edit. `new.command.tree/002` hit this on
2026-09-08 and was re-pinned with `published_hashes --rewrite`. Every
published version without an example will hit it in turn.

## The change

`_sha256` in `src/sema/tools/published_hashes.py` hashes
`path.read_bytes()`. Replace it with a hash of the schema's validating
content: parse the YAML, drop the top-level `examples` key, serialize
canonically (`yaml.safe_dump` with `sort_keys=True`), hash that. Every
existing pin is recomputed once with `--rewrite` in the same commit, and
the README paragraph that names re-pinning as the sanctioned correction
for the examples case is deleted.

Effort: under an hour, one function and one pin rewrite.

## What the pin stops catching

A canonical-form hash ignores comment and whitespace edits to a
published file as well as examples. Comments and layout are not part of
the contract either, so this is a loosening only in the letter of the
byte rule. The rule that stays exact: any change to a property, `$ref`,
constraint, axiom, default, or `required` list still moves the hash.

## Open

- Whether `description` and `value_descriptions` prose should also be
  outside the hash. The enum authoring spec lets a new version clarify
  prose but says nothing about the current one; leaving prose inside
  the hash keeps the question closed by default.
- `spec/governance.md` "Promotion" names the content-hash pin as part
  of the promotion record. Check whether its wording assumes a byte
  hash before changing the tool; if it does, the spec edit rides this
  design and is discussed first.
