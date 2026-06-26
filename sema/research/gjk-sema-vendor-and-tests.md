# gjk vendored sema tests — drop them (research)

Status: Draft · Pass 0 · Updated 2026-06-09

> What this is: a finding from the journalkeeper → base 0.4.0 refactor
> (2026-05-23, session bright-frost) proposing that gridworks-journalkeeper
> delete its vendored sema tests, with the coverage-confirmation gate that
> protects the deletion. Landed 2026-06-09 from a queued stash; the
> postscript below updates it against the now-merged snapshot spec.

## The finding

`gridworks-journalkeeper/src/gjk/sema/` is a **vendored copy** of the
canonical `sema/` package — same types, same `property_format`, same codec
shape — present because `sema` isn't yet a published Python package.
Alongside the vendored *code* sits a vendored *test*
(`src/gjk/sema/tests/test_property_format.py`), a copy of sema's own
format-validation tests rebound to `gjk.sema.property_format`.

**Proposal:** delete `src/gjk/sema/tests/` from journalkeeper. Type and
format-validation tests belong to whoever owns the type definitions —
`sema/` itself, not its consumers. Mirroring the tests alongside the
mirrored type code doubles the maintenance surface and lets the two drift
silently. Journalkeeper's tests should cover only the integration points
(dispatch → codec → persistor → DB row), which is already what
`tests/test_journal_keeper.py` does.

The whole vendoring of `gjk/sema/` is a stopgap; once `sema` becomes
importable as a normal Python dependency, the consumer simply does
`from sema import SemaCodec` and `gjk/sema/` evaporates entirely — tests
included.

## The gate: confirm sema-side coverage first

Before journalkeeper deletes its vendored tests, confirm `sema/tests/` has
equivalent format-validation coverage. The vendored test file roughly:

- loads YAML schemas from `definitions/formats/` (`handle.name`,
  `left.right.dot`, `market.slot.name`, `positive.int`, `spaceheat.name`,
  `utc.milliseconds`, `utc.seconds`, `uuid4.str`);
- validates the schema examples against the runtime `TypeAdapter` for each
  format;
- asserts ValidationError on negative examples.

## Postscript (2026-06-09): gate satisfied; proposal now spec-backed

Two things changed since the finding was queued:

1. **Coverage is confirmed.** `sema/tests/runtime/test_property_formats.py`
   loads the YAML format definitions and validates examples against the
   runtime `TypeAdapter`s for all eight formats above (plus newer ones:
   `non.empty.string`, `positive.int.as.str`, `pascal.case`, …).
2. **The snapshot contract now rules vendored test suites out.** The merged
   [OPS-380](https://linear.app/gridworks/issue/OPS-380) work canonized `sema/spec/snapshot.md`: a snapshot "ships data,
   not test code … it does NOT vendor a test suite," and the build itself
   carries the round-trip gate over generated `samples/`. gjk's vendored
   tests are therefore not just redundant — they are outside the snapshot
   contract.

The deletion is unblocked. (The journalkeeper-side staging doc this was to
be linked from — `refactor-to-base-0.4.2.md` — no longer exists; this note
is the gate's canonical record.)
