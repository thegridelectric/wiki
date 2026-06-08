# Design: Sema snapshot generation improvements

> Status: Draft · Pass 1 · Updated 2026-05-29

What this is: upgrades for the `sema snapshot prepare`/`build` pipeline that
emits a restricted Sema runtime into a consumer package (e.g. `gjk.sema`).
Three improvements: lint generated code, move snapshot validation to build-time
(don't vendor test code), and emit a `samples/` folder from existing schema
examples. On completion the durable bits fold into the relevant `spec/` spoke
(snapshot / runtime-generation) and this file is deleted (per `designs-process.md`).

## Context

`generate_runtime_from_dag` (`src/sema/tools/runtime_generation/`) writes a
vocabulary subset into `<pkg>/sema` for a consumer. Friction seen while standing
up the gridworks-journalkeeper snapshot:

- **Diff churn.** Generated `.py` isn't run through a formatter, so every regen
  produces large formatting-only diffs that fight pre-commit and bury real
  changes. (The generator already *sorts* its output — imports, `topo_sort` —
  so it's deterministic by ordering; only whitespace/quote normalization is
  missing.)
- **`tests/` leaks into consumers.** `build` emits `tests/test_property_format.py`
  into the vendored snapshot — generated test *code* doesn't belong inside a
  consumer's package.
- **No round-trip validation.** The only generated test covers format
  examples; there is **no per-type decode test**. That is exactly the gap that
  let the `atn.bid` closure bug ship (see
  [`untangle-market-type-name.md`](untangle-market-type-name.md)).
- **No typed fixtures.** Downstream repos want ready JSON instances per type.

## Plan

### 1. Lint generated code *after* generation (gate, don't blindly fix)
After generation, over the emitted tree:
- **`ruff format`** — safe, semantics-preserving; this is the real win and (given
  the generator already sorts) makes a re-run produce **zero diff**.
- **`ruff check`** as a **gate** — fail the regen if generated code is dirty
  (that signals a *generator* bug). Use `--fix` only for safe rules (e.g. import
  sorting); do **not** let autofix rewrite generated code wholesale — it can
  strip the `# noqa: PLC0415` lazy import or "unused" re-exports and hide bugs.
- **`mypy`** as a gate — expect a tailored config for the generated package
  (pydantic dynamics are noisy) and a little initial cleanup.

Provide a bash wrapper **`scripts/regenerate_runtime.sh`** that runs the existing
`scripts/regenerate_runtime.py` then applies these steps — one command for
"regenerate cleanly." Reuse sema's own `ruff`/`mypy` config.

*(Pragmatic 90/10: post-`format` beats making every template byte-perfect;
the generator's existing sorting makes it deterministic.)*

### 2. Build-time validation, not vendored tests
- **Stop vendoring `tests/`** into consumer snapshots (the `write_tests=True`
  path) — ship data, not test code.
- **But run validation at build time as a gate**, including a **per-type
  round-trip** over the samples: `from_dict → to_dict → deep-equal` +
  schema-validate, executed against the **restricted consumer snapshot**. This
  is the check that would have caught `atn.bid` (the enum was missing only in
  the *restricted* snapshot, so a sema-runtime test wouldn't see it).

### 3. Auto-generate a `samples/` folder from existing examples
For each **type/version whose schema already has an `examples:` block**, emit a
JSON instance under `samples/`:
- Named per the Sema-typed-JSON convention; versioned types →
  `samples/<type>/<version>.json`.
- **Do NOT require every schema to have an example** — only emit a file when one
  exists (no new authoring mandate). Source of truth stays `examples:`; samples
  are generated, never hand-edited (no drift).
- **Ship `samples/` *into* the snapshot** — fixtures are data, fine to vendor
  (it's test *code* we're dropping) — so downstream consumers can load them.
- **Emit JSON deterministically** (stable key order) so samples don't churn.
- These are the fixtures the build-time round-trip (#2) consumes. (Optional
  later: also emit `counterexamples` for negative tests.)

### Related fix to fold in — now MOOT (2026-06-08)
The format generator hardcoded `from sema.runtime.enums import MarketTypeName`
in the `market.slot.name` validator template — a consumer-snapshot correctness
bug. The `untangle-market-type-name` work resolved this **by removal**:
`market.slot.name` was de-tangled into a self-contained, shape-only leaf
(structure only — no enum import), so **no format imports vocabulary anymore**
and there is no hardcoded import left to thread. (A short-lived `import_root`
threading was added then reverted along with the versioned-property-format
capability.) If a future format ever needs to import vocabulary, thread
`import_root` through `generate_property_format` at that point.

## Verification
- `scripts/regenerate_runtime.sh` → `ruff`/`mypy` clean; a **second** regen
  produces **zero diff** (code *and* samples).
- Emitted snapshot has **no `tests/`** directory but **does** have `samples/`
  (only for schemas with an `examples:` block, each validating against its schema).
- Build-time round-trip passes for every seeded type with a sample; deliberately
  removing a needed enum from the seed makes it **fail** (proves it guards the
  `atn.bid`-class bug).
