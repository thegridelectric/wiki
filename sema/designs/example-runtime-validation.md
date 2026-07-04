# example-runtime-validation — the main suite must decode every example through the runtime

Status: Draft · Pass 0 · Updated 2026-07-03

**EDD: no** build-out — a test-coverage change plus the example fixes it surfaces, verified by the
sema suite going green (every example decodes through the runtime); no standalone experiment.

> What this is: close the gap where the main sema test suite validates `examples:` **structurally**
> (against each type's own JSON Schema) but does **not** decode them through the **generated runtime**
> (fields + property formats + axioms + the *current* shapes of referenced sub-types). So an example
> can go stale — reference a type that was reshaped in place — and the main suite stays green while the
> example is broken. The snapshot round-trip gate (stricter) catches it, but only at snapshot time.

## The gap (why now)

The channel-config reshape + the bare-component `ConfigList` drop were done **in place** on unpushed
component types (no version bump — permitted while unpublished). That silently invalidated the
**embedded examples** in every type that composes those components: `gw.house0.layout`'s `examples:`
block now fails **3399** runtime validation errors (hubitat/web.server/pico components carry the old
`ConfigList`; tank-module fields moved). The main `pytest` suite passed the whole time — it validates
the example structurally, not by decoding it through the reshaped runtime. The tlayouts snapshot build
surfaced it because its round-trip gate *does* decode every example through the runtime.

An example that does not decode through the current runtime is a broken contract advertised as a
worked example. It should fail the main suite, loudly, at the moment the reshape lands — not later at
a consumer's snapshot build.

## Requirement

**The main sema test suite SHALL decode every published type version's `examples:` through the
generated runtime** — the same decode the snapshot round-trip gate performs (fields, property formats,
axioms, and the *current* shapes of all referenced sub-types), not merely a structural JSON-Schema
check. A stale example SHALL fail the main suite.

An existing test, `tests/runtime/test_example_runtime_validation.py`, already runtime-decodes a
**growing allowlist** of examples (it closed the JSON-only gap for a subset). This design **removes the
allowlist**: the test SHALL cover **all** examples (every version that carries an `examples:` block),
so nothing can regress silently. The context-dependent-upgrade exemption (snapshot.md) applies the same
way — a version with a context-dependent upgrade still round-trips at its **own** version.

## Scope

1. **The test.** Extend `test_example_runtime_validation.py` from an allowlist to all examples (or add
   a comprehensive companion). Reuse the snapshot round-trip's decode path so the two gates agree.
2. **Fix the examples it surfaces.** Regenerate the stale examples to the reshaped shapes:
   `gw.house0.layout`, `gw.nolan.layout`, `gw1.simple.sim.layout`, and any other referrer of the
   reshaped component / channel-config family. These layout examples are best produced by the tlayouts
   generator once it authors reshaped layouts (the generated instance becomes the fresh example) — so
   the fix is coupled to the tlayouts port, not hand-editing 3399 lines.
3. **Going-forward discipline.** When a type is reshaped in place (or a new version lands), its own
   example and every embedding referrer's example are updated **in the same change** — the new test is
   what enforces it.

## Open

- **Sequencing of the example fixes** vs the tlayouts generator (which produces the reshaped layout
  instances). The test can land first (red on the stale examples), or alongside the regenerated
  examples so the suite stays green — decide when the tlayouts gen port lands.
- **Linear.** Not yet an issue (Draft → Backlog); create the `design`-labeled Ops issue when this
  reaches Accepted (or sooner).
