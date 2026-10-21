# sema — Claude protocol

Status: Draft · Pass 0 · Updated 2026-10-18

## Read the spec first, and prove it

Before ANY sema edit, Read `sema/spec/primary.md`. Adding or modifying a
vocabulary word: first read the `sema/spec/registry/` and
`sema/spec/authoring/` spokes for the kind (format / enum / type) being
touched, then post a summary of that kind's registry, authoring, dependency,
and axiom/projection rules and WAIT for confirmation. The summary proves the
spec was read this session, not recalled.

A promotion-only turn (staging → published, no schema edit) reads only
`governance.md` "Promotion" and `registry/structure.md` "Status Field"; the
read-receipt is the list of words promoted, bottom-up, and `sema promote` is
the gate.

## The spec is change-controlled

ANY change to `sema/spec/`, however small, additions included, requires
discussion with the human before editing. Never fold a spec edit into
another change; when a task appears to force one, stop and raise it. Prefer
moving rapidly beyond an exceptional case over adding exception machinery
to the spec.

## Registry rules

- **`status` decides edit-in-place vs new version; check it first.**
  `published` is IMMUTABLE: no functional change (fields, `$ref`/dependency
  versions, axioms, constraints, `required`, enum values) ever; that takes a
  NEW version (clarifying prose is fine). `staging` and `draft` are edited IN
  PLACE; NEVER add a new version of a word whose latest is staging or draft.
  A versioned staging word forks a mutable line that every mirror, fixture
  and pin then has to be squashed back. Asked to change a published version
  in place? Refuse and propose a new version. Asked for a new version of a
  staging word? Refuse and edit in place. Bootstrap allowance, sanctioned
  per case and NOT in `sema/spec`: a version published before June 2026 MAY
  be corrected in place when shipped wire data proves the schema wrong.
- **Regen touches more than you changed.** Bumping one type's version
  rewrites the generated runtime of unchanged referrers (versionless class
  ref rebinds; the old version gets an explicit `XxxNNN` class). Expected,
  not a stray diff.
- **Timestamps are real wall-clock, rounded to 5 minutes.** Registry
  `created` / `metadata.last_updated` use actual current UTC (`date -u`)
  rounded to the nearest 5 min, never a placeholder. Same-sitting versions
  MAY share the stamp; `created` is unique only within a type; dependency
  ordering allows equal stamps; `last_updated` ≥ every `created`.
- **Every layout-word edit asks: did this expose a missing layout axiom?**
  After each sema item on a layout or ops word, ask the human whether the
  change surfaced an invariant the word does not yet state; capture it as an
  axiom candidate before moving to the next item.
- **The sender's clock has two names; pick by the word's lifecycle.**
  `CreatedMs` (`utc.milliseconds`) is the default: the sender's clock when
  the content came to be, for every word that records a state change, an
  observation or a command, whether sent at once or stored until acked.
  `SendTimeMs` is the exception, for a word reassembled from current state
  on each request or broadcast, where a re-send rebuilds the message
  (`g.node.forest`, a dashboard summary); such a word has no `CreatedMs`.
  A word never has both; the time of a transmission is envelope metadata.
  A new word uses these names from birth; a word with another spelling
  converges at its next version. Optional on adoption; a later version MAY
  require it.
- **Word prose never restates the schema.** A description states the
  field's own meaning; requiredness, types and cross-cutting narrative
  belong to the schema and the spec.
