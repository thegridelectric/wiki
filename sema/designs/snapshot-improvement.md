# Design: Sema snapshot generation improvements

> Status: Accepted · Pass 2 · Updated 2026-06-08 · Linear: OPS-380

What this is: upgrades for the `sema snapshot prepare`/`build` pipeline that
emits a restricted Sema runtime into a consumer package (e.g. `gjk.sema`).
Four threads: (1) lint + atomically regenerate generated code (and drop the
non-deterministic `built_at`); (2) replace vendored tests with a build-time
per-type round-trip gate + an opt-in consumer-side harness; (3) emit a
types-only `samples/` folder (canonical JSON, dotted-`TypeName` filenames) from
existing `examples:`; (4) require examples on superseded type versions and
backfill them. On completion the durable bits fold into the relevant `spec/`
spoke (snapshot / runtime-generation) and this file is deleted (per
`designs-process.md`).

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
  [`untangle-market-type-name/primary.md`](untangle-market-type-name/primary.md)).
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

**Make the regen atomic.** Today `build` does clear-then-write
(`snapshot.py:153` rmtrees `enums/ types/ tests/`, then generates). Once the
gates above can *fail by design*, a failure after the rmtree leaves the
consumer with a corrupted/partial snapshot. So: **generate into a temp tree,
run `ruff`/`mypy` + the build-time round-trip (#2) there, and atomically swap
into place only on green.** A failing gate must leave the previous snapshot
untouched — a failed regen is a no-op, never a half-write.

*(Pragmatic 90/10: post-`format` beats making every template byte-perfect;
the generator's existing sorting makes it deterministic.)*

**Drop the `built_at` timestamp** (`build_seed_definitions.py:110,114`).
`prepare` bakes `datetime.now()` into `output/sema/definitions/registry.yaml`
as `snapshot.built_at`; nothing reads it, and it makes a second regen diff on
`registry.yaml` no matter how clean the `.py` is — so it directly blocks the
zero-diff goal. **Decision (2026-06-08): remove the field outright.** Provenance
is *already* covered: `build_restricted_registry` deep-copies the source
registry's `metadata` block into the snapshot (`build_seed_definitions.py:112`),
and that block carries `registry_version` + `last_updated`
(`definitions/registry.yaml:1-4`) — curated, content-meaningful fields a
consumer/CI can compare against the producing sema. `built_at` was wall-clock
noise on top of a real version pin we already ship. *(Code detail for impl:
`built_at` is the only key under `snapshot:`, so removing it leaves
`snapshot: {}` — drop the `snapshot` key entirely and update the expected-key
list in the registry formatter at `build_seed_definitions.py:270`.)*

### 2. Build-time validation, not vendored tests
- **Stop vendoring `tests/`** into consumer snapshots (the `write_tests=True`
  path) — ship data, not test code.
- **Drop the property-format tests entirely** — do **not** carry the
  format example/counterexample checks (`tests/test_property_format.py`,
  `formats.py:163-178`) into a build-time gate. **Decision (2026-06-08):**
  formats are validated in *sema's own* test suite at authoring time; the
  snapshot build only needs to prove the **emitted runtime actually runs**, and
  that job is the per-type round-trip below. Re-running format
  example/counterexample assertions at snapshot-build time adds machinery for
  coverage the source repo already owns.
- **Build-time gate = per-type round-trip** over the samples:
  `from_dict → to_dict → deep-equal` + schema-validate, executed against the
  **restricted consumer snapshot** (run inside the temp tree of #1, before the
  atomic swap). This is the check that would have caught `atn.bid` (the enum was
  missing only in the *restricted* snapshot, so a sema-runtime test wouldn't
  see it) — "does the emitted runtime decode its own types" is exactly
  "does it run."
- **Ship a tiny consumer-side round-trip harness** — a `conftest`/fixture
  loader that walks `samples/` and re-runs the same round-trip, **not** the
  vendored `tests/` we're dropping. Rationale: the build-time `mypy`/round-trip
  gate runs in *sema's* env (its pydantic/Python), not the consumer's; the
  harness lets a consumer (e.g. `gjk`) re-verify against *its* env. It's
  opt-in — if a consumer never runs it, the build-time gate remains the
  best-effort floor. (This is the resolution of the `mypy`-env-mismatch
  question: keep `mypy` as a best-effort sema-side gate **and** ship the
  harness; the two layers are complementary.)

### 3. Auto-generate a `samples/` folder from existing examples
**Samples are for `type`s only** — not formats, not enums. (Only types are
serialized between applications and carry `TypeName`/`Version`; the round-trip
is a per-type decode, so a sample of a format or enum has nothing to round-trip
through `from_dict`/`to_dict`.) For each **type version whose schema has an
`examples:` block**, emit one JSON instance under `samples/`:
- **Filename = the dotted Sema `TypeName`, with the `Version` appended when the
  type is versioned**, per the Sema-typed-JSON convention (dots preserved):
  - versioned → `samples/<type.name>.<version>.json`
    (e.g. `samples/spaceheat.node.gt.000.json`)
  - versionless → `samples/<type.name>.json` (e.g. `samples/g.node.gt.json`)
  - **Include old versions**, not just latest — each old version with an
    `examples:` block gets its own `samples/<type.name>.<old-version>.json`.
    (See #4: old versions are the highest-value round-trip target —
    decode-at-old → `upgrade()` → decode-at-current.)
- **Content = the canonical serialized form** — feed the authored `examples:`
  entry through the snapshot codec (`from_dict → to_dict`) and write *that*:
  CamelCase field names (`by_alias=True`, per spec Principle 2), `exclude_none`,
  deterministic key order. These are the exact bytes the sema runtime emits
  over the wire, so the sample doubles as the round-trip's **expected output**
  and won't churn between regens.
- **Latest versions: do NOT require an example** — only emit a file when one
  exists (no new authoring mandate for current types). Source of truth stays
  `examples:`; samples are generated, never hand-edited (no drift).
- **Ship `samples/` *into* the snapshot** — fixtures are data, fine to vendor
  (it's test *code* we're dropping) — so downstream consumers can load them.
- These are the fixtures the build-time round-trip (#2) and the consumer-side
  harness consume.
- **Emit an honest coverage report** at **`samples/README.md`**: "N of M seeded
  type versions have a sample; the following lack one: …". The build writes it
  every regen so the gap is visible and reviewable, not implied-universal — a
  type with no sample is silently untested otherwise.

### 4. Old type versions MUST have examples (+ backfill)
Old versions exist precisely to be **upgraded**, and the
decode-old → `upgrade()` → decode-current path is where restricted-snapshot
bugs concentrate (the `atn.bid` class). A round-trip is only as good as the
fixtures, so:

**Immutability is not a blocker — adding examples to published old versions is
permitted (decision 2026-06-08, option (a)).** `examples` are non-normative:
the spec defines them as developer guidance / validation fixtures / contract
clarity, requires only that they be structurally valid and not contradict
axioms (`authoring/types.md` "Examples (Optional)"), and they alter no
validation behavior. So adding one to a published version does **not** "change
validation behavior or semantics" — the bar set by `registry/types.md`
"Immutability → General Rules". It falls in the same family as the already-
permitted *"Clarification of descriptive text"* (`registry/types.md`
"Permitted Changes (All Types)"): an improved description, in effect.

- **Spec change 1 — permission** (`registry/types.md`, Permitted Changes): add
  *"Addition or improvement of non-normative `examples` (does not alter
  validation behavior or semantics)"* to the permitted-changes list, so
  backfilling published old versions is explicitly sanctioned, not a grey area.
- **Spec change 2 — mandate** (`authoring/types.md`, currently "Examples
  (Optional)"): every *superseded* type version MUST carry at least one
  `examples:` entry. Targeted — latest versions stay optional (#3); the mandate
  binds only once a version has a successor (i.e., an `upgrade()` exists to
  exercise).
- **Work item — backfill now:** author `examples:` for **all existing old type
  versions** that lack one, so the mandate holds across the current registry
  the day it ships. Enumerate the gaps from #3's coverage report; this is a
  one-time authoring pass over the old-version schemas under `definitions/types/`.
- The round-trip (#2) then covers, per old version: decode the sample at its
  own version → `upgrade()` to current → decode-validate the result.

## Verification
- `scripts/regenerate_runtime.sh` → `ruff`/`mypy` clean; a **second** regen
  produces **zero diff** (code, samples, *and* `registry.yaml` — `built_at`
  gone).
- A regen whose gate **fails** is a **no-op**: the previous snapshot is
  byte-for-byte unchanged (atomic temp-tree → swap-on-green).
- Emitted snapshot has **no `tests/`** directory (format tests dropped, not
  re-homed) but **does** have `samples/` (every type/version with an
  `examples:` block, latest *and* old) plus `samples/README.md` listing
  coverage gaps.
- Build-time round-trip passes for every seeded type/version with a sample,
  **including decode-old → `upgrade()` → decode-current** for old versions;
  deliberately removing a needed enum from the seed makes it **fail** (proves it
  guards the `atn.bid`-class bug).
- Every **superseded** type version in the current registry has an `examples:`
  block (backfill complete), so old-version coverage is total.
- The consumer-side harness re-runs the round-trip over `samples/` in the
  consumer's env.

