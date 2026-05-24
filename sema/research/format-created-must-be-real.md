# Format `created` timestamp: tighten to actual creation time

Status: Draft · Pass 0 · Updated 2026-05-23

What this is: a deferred policy tightening surfaced while back-dating
the `non.empty.string` format. Park here; revisit once the current
bakeoff bug-fixes have settled.

## The current situation

While registering `non.empty.string` to replace orphaned `minLength: 1`
constraints in published schemas (`relay.actor.config:002`, `:003`,
`fis.instance.authorization.event:000`), the dependency-timestamp-
ordering rule from `sema/spec/registry/types.md` forced the new
format's `created` field to be **earlier** than the earliest type that
depends on it. Concretely the format was backdated to
`2024-12-31T15:00:00Z` (before `relay.actor.config:002`'s
`2024-12-31T15:38:00Z`), even though the format was actually authored
on 2026-05-23.

This is operationally correct — formats are immutable and the
`created` field is a provenance pointer, not a strict creation time —
but it sets a precedent where `created` can be back-dated to escape
the dep-ordering rule. In a published, multi-tenant ecosystem, that
weakens the dep-ordering invariant: a malicious or sloppy registrar
could backdate any new word to slip past ordering checks.

## What to lock in (eventually)

Once the spec bakeoff bug-fix pass is fully landed and the current
batch of "should have used a format from the start" patches has flushed
through, tighten the rule:

- `created` SHALL equal the actual wall-clock time at which the
  registry entry was first added to the working registry.
- Adding a new format/enum/type that older versions depend on SHALL
  require a new version of those dependents (not a backdated
  registration).

The transition needs a one-time amnesty for entries created during the
bakeoff pass; specific entries to mark are at minimum:
`non.empty.string` (this entry).

## Why park rather than fix now

The strict rule above is the right end state, but enforcing it today
would block the in-place bakeoff fixes that the user has explicitly
preferred (no version bumps for typo-class issues). The
spec-text-change for tightening is small (one paragraph in
`registry/structure.md` §Timestamp Rules or `registry/types.md`
§Versioning Semantics). Defer until the bakeoff fixes are committed
and the dust settles.
