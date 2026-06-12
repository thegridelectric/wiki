# Changelog

A reverse-chronological log of WHY we made each commit **in the
`sema` code repo**. The matching git commit (in `sema`) holds the
WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-06-12 — Finish the ActorClass cascade + fix an immutability slip (`cc3fac8`)

**What:** New versions `layout.lite/014` and `new.command.tree/002` re-point ShNodes
to `spaceheat.node.gt/302` — `new.command.tree/002` **drops the multi-version
`oneOf`** for a single clean `/302` (upgrade lifts old nodes). **Reverted** the
in-place edit to non-draft `scada.control.capabilities/001` (immutability
violation); its `/302` bump is deferred to the planned admin-for-nolan v002. Added
an `extended_description` "back-dated-traffic anti-pattern" note to 6 old `oneOf`
schemas (`new.command.tree/000`, `layout.lite/009/010/011`, `scada.params/004`,
`report/002`).

**Why:** complete the actor-class ripple through the published embedders while
respecting immutability (non-draft schema = no functional change → new version).
The old `oneOf` unions are flagged as a sema-bring-up lenience, not propagated.

## 2026-06-12 — `spaceheat.node.gt/302` + ActorClass cascade (`2b9e099`)

**What:** New `spaceheat.node.gt/302` re-points `ActorClass` to `gw1.actor.class/012`
(picks up `SimSensorActor`/`SimRelayActor`); trivial 301→302 upgrade, axiom
implementations ported, hand-written tests bumped + a v302 fixture. The two
embedders re-pointed **in place** (unpublished/draft): `scada.control.capabilities/001`
and `gw.nolan.layout/000` → `/302` (their `created` bumped to 2026-06-12 to satisfy
causal-timestamp ordering).

**Why:** the ActorClass cascade — adding the two sim actor classes forces a
`spaceheat.node.gt` bump and everything embedding it. `data.channel.gt` /
`derived.channel.gt` reference nodes by *name*, so they don't ripple. Remaining
embedders `layout.lite` + `new.command.tree` (both published) are separate version
bumps, still pending.

## 2026-06-12 — Add `gw1.actor.class/012` — `SimSensorActor` + `SimRelayActor` (`a7aa496`)

**What:** New enum version `gw1.actor.class/012` appends `SimSensorActor` and
`SimRelayActor` (`011` preserved under `old_versions/`); registry + indexes +
runtime regenerated. (The commit title reads "v011"; the diff adds `012`.)

**Why:** The two scada-side actors of the simulated test environment need
actor-class identities — `SimSensorActor` reads `sim.plant.flux` →
`synced.readings`, `SimRelayActor` sends `sim.plant.actuation`. First step of the
`ActorClass` cascade; the `spaceheat.node.gt/302` bump that picks up `012` follows.

## 2026-06-12 — Mint `sim.plant.actuation/000` + `change.relay.pin/000` enum (`81005bc`)

**What:** New type `sim.plant.actuation/000` — the actuation *event* a SimRelayActor
sends to the plant: `RelayName` + `Action` (Energize/DeEnergize via the new
`change.relay.pin` enum) + `ActuationTimeUnixMs` (sim time) + `ActualTimeUtc`
(human-readable). New string enum `change.relay.pin` (DeEnergize/Energize),
mirroring gwsproto's `ChangeRelayPin`. Regenerated indexes + runtime.

**Why:** The inverse boundary of `sim.plant.flux`: a simulated relay sends its
energize/de-energize event — the i2c multiplexer's atomic pin action, *not* the
closed/open interpretation (which depends on wiring) — into the plant, which
resolves the physical effect from the layout. Modeled as an event, not a state,
because actuation is an event. `change.relay.pin` was minted because sema had only
`change.relay.state` (CloseRelay/OpenRelay = the wiring-dependent closed/open
framing) and `relay.energization.state` (a state).

## 2026-06-12 — Mint `sim.plant.flux/000`, the simulated plant's source emission (`386ea55`)

**What:** New versioned type `sim.plant.flux/000` (+ registry entry, regenerated
indexes/runtime, filled `ListLengthConsistency` axiom template). Fields:
`ChannelNameList` + `ValueList` (index-aligned), `ScadaReadTimeUnixMs` (sim time,
`utc.milliseconds`), `ActualTimeUtc` (wall-clock, human-readable
`utc.iso8601.millis`). No `Simulates*` identity fields. Bumped
`metadata.last_updated` to 2026-06-12.

**Why:** The simulated terminal asset (gwta) emits its physical state as
`sim.plant.flux`; the scada-side sim sensor reads and *interprets* it into
`synced.readings` (and electrical/other derived signals later). It is the
plant-emits/sensor-reads boundary word of the SCADA simulated test environment
(OPS-40). Two timestamps because under sped-up coordinator time the sim clock
outruns the wall clock — `ActualTimeUtc` is human-readable provenance for CSVs,
not consumed downstream. `Simulates*` was dropped deliberately: the plant's raw
emission must not presume its destination.

## 2026-06-10 — Runtime ruff-clean at source: generator formats, drift guards compare formatted (`cdeba05`)

**What:** `generate_runtime_from_dag` now runs `ruff format` (`format_in_place`)
as its final pass, so the committed `src/sema/runtime` is ruff-clean. The four
`test_runtime_generation_*` drift guards format the generated output before
comparing (so canonical = formatted on both sides). Regenerated the runtime —
45 files reformatted once — and updated `regenerate_runtime.sh`'s header to
state the new canonical (ruff-formatted) and that its `ruff format --check` now
passes clean ("157 files already formatted").

**Why:** Permanently closes the *format* half of the `regenerate_runtime` trap.
Previously canonical was the *raw* generator output, so `ruff format` diverged
from it — the reason an in-place format in the `.sh` broke the drift guards.
Making ruff the single source of style (templates need not match it) means
`--check` is green and the format trap cannot recur; it also unifies the in-repo
runtime with the snapshot path, which already treated ruff-formatted as
canonical. This is the deferred follow-up to `a4a8b83`. The remaining `ruff
check` + `mypy` findings (over-/under-tracked typing imports; pydantic/enum
dynamics) are a *separate* report-only generator-cleanup follow-up, untouched
here.

## 2026-06-10 — new.command.tree/000 axiom: PrefixClosedHandles via effective handle (`668f00f`)

**What:** Rewrite `new.command.tree/000` axiom 1 from `PrefixClosedHierarchy`
(two-part: ShNode `Handle` *and* `ActorHierarchyName` each prefix-closed) to
**`PrefixClosedHandles`** — a single prefix-closure rule over each node's
*effective handle* (its `Handle` if present, else its `Name`). Rewrites the
axiom template + regenerated runtime enforcement, enriches the
`extended_description` (command-authority chain, runtime bossable-actor
`FromHandle`/`ToHandle` checks → `bad_boss` Glitch, dynamic handle reassignment,
dormant/root nodes), and adds a real-world `real_maple.json` fixture + test. The
`ShNodes` `oneOf [200, 300, 301]` widening was already on dev, so this commit is
axiom-only (no registry/index change).

**Why:** Captures what the SCADA↔LTN command tree actually does in the field.
The effective-handle convention lets a root node omit `Handle` on the wire (its
`Name` anchors children) while still participating in prefix-closure, and the
single-rule axiom matches the runtime enforcement bossable actors already
perform. **Modified `000` in place rather than bumping to `001`** — a deliberate
source-precedence call (rule 1, explicit instruction): field reality before sema
was well-structured is the higher truth, overriding the additive/version-bump
MUST, since `000` is pre-production. Faithful replay of `jm/fix-new-command-tree`
onto current dev: that branch forked from an ancient dev (~150-file divergence),
so the substantive delta was replayed on a clean branch + regenerated, not
merged.

## 2026-06-10 — gw1.unit/002 + regenerate_runtime.sh hygiene-report (`a4a8b83`)

Landed as one commit ("Various — gw1.unit/002 from Joe and various cleanups").
Two distinct changes:

**(1) Add `gw1.unit` version 002** (`DollarsX1000`, `MilesPerHourX1000`,
`KilowattHoursX1000`). `registry.yaml` (`latest_version: 002` + the `002` entry)
and the new `definitions/enums/gw1.unit/002.yaml`, then regenerated indexes +
runtime. Additive only; `000`/`001` preserved verbatim (frozen
`runtime/enums/old_versions/gw1_unit_001.py`). The runtime regen wired the new
member into the three types that reference `gw1.unit` (`derived_channel_gt`,
`gw1_unit_quantity_projection`, `synced_readings_bundle`).

*Why:* makes those 3 members canonical, so the gridworks-journalkeeper snapshot
regen (OPS-386) no longer drops units its persistors use — they had been
hand-patched into JK's old snapshot. This *replays* Joe's reviewed schema delta
(`jds/dollarsX1000`) onto current `dev` rather than merging his stale branch;
merging the 29-commits-behind branch produced generator/formatting drift (4
`test_runtime_generation_*` failures), whereas replaying the delta and
regenerating with `dev`'s own generator is clean.

**(2) `regenerate_runtime.sh` reports hygiene, never mutates the runtime.**
Change `ruff format` from an in-place rewrite to `ruff format --check` (report
only), alongside the already report-only `ruff check` / `mypy`; `--strict` still
makes any finding fatal.

*Why:* the canonical runtime is the *raw* `regenerate_runtime.py` output — what
the committed tree is and what the `test_runtime_generation_*` drift guards pin.
The in-place `ruff format` rewrote the runtime into a *different* form (it wraps
the over-long `e.compile(...)` line in `property_format.py`), so a regen via the
`.sh` silently diverged from canonical and turned the drift guards red — a trap
that cost real time. Report-only converges the `.sh` with the `.py` (the
generator is deterministic, so no formatting step is needed for zero-diff), so
**either entrypoint is now safe.** Making the generated runtime ruff-clean *at
the source* (so `--check` passes clean and the trap cannot recur) is the next
step.

## 2026-06-09 — Merge pull request #21 — jm/ops-380-snapshot-improvement (`8293b4e`)

**What:** Merge landing the OPS-380 snapshot-improvement branch on `dev`. The
constituent commits each have their own entries below (`bea9846`, `ee5bd53`,
`0169b47`, `653a152`, `701495c`, `be72b40`, `6f68508`).

**Why:** Collectively: snapshot builds became deterministic (zero-diff regen
via canonical formatting + stable ordering), atomic (failed gate = no-op), and
gated (round-trip over generated samples, with the context-dependent-upgrade
exemption), with the contract canonized in `spec/snapshot.md`. Consumers
regenerating a snapshot no longer fight cosmetic formatter drift — this
resolves the 2026-05-25 finding where ~75% of a gjk snapshot-refresh diff was
ruff-format noise.

## 2026-06-08 — feat: UpgradeRequiresContext for context-dependent upgrades (`701495c`)

**What:** New `UpgradeRequiresContext(SemaError, ValueError)` in the
runtime base (`templates/base.py.jinja2`) + a `SemaType.upgrade_requires_context()`
factory so an upgrade body raises it via the already-imported `SemaType` (no new
per-file import). The three upgrades that legitimately cannot run on a standalone
instance — `scada.control.capabilities/000→001`, `send.layout/000→001`,
`linear.one.dimensional.calibration/000→001` — now raise it instead of a bare
`ValueError`. The shipped round-trip gate (`templates/roundtrip.py.jinja2`) and
the build-time check catch `UpgradeRequiresContext` in the decode-old→upgrade
step and treat it as an **expected pass** (the sample still must round-trip at its
own version). Runtime regenerated; spec `authoring/type-semantics.md` Upgrade
Discipline documents the contract.

**Why:** OPS-380 thread 4 mandates an example on every superseded version and the
gate upgrades each sample to latest — but some `old→new` transforms need
out-of-band context (layout handles/ids, source message) an isolated message
can't carry, so their `upgrade()` correctly refuses. A bare `ValueError` made
"refuses by design" indistinguishable from "broke." The typed exception lets the
gate exempt exactly those versions from the upgrade round-trip while keeping the
example mandate + decode-own-version coverage (the `atn.bid`-class check) intact.
`scada.control.capabilities/000` (in the thread-4 backfill set) is the version
that forced this.

## 2026-06-09 — drop rolled-back structured-enum residue (`6f68508`)

**What:** `CLAUDE.md` Universal MUSTs — removed the `(for structured enums this
extends to attribute rows/columns…)` parenthetical from the enums-are-additive
bullet. Structured enums were rolled back (`0bf8f0f`), so the clause referenced a
capability that no longer exists.

**Why:** Stale residue left by the structured-enums rollback; surfaced while
closing out the `untangle-market-type-name` design (OPS-378). Keeps the operative
instructions honest.

## 2026-06-08 — backfill: examples on 20 superseded versions, flip gate, fold snapshot spoke (`be72b40`)

**What:** (1) A minimal, schema-valid, axiom-consistent `examples:` block on each
of the 20 superseded type versions that lacked one (enumerated by
`tests/registry/test_superseded_examples.py`): `channel.readings/001`,
`flo.params.house0/003-006`, `fsm.full.report/000`,
`i2c.multichannel.dt.relay.component.gt/002-003`, `layout.lite/007-012`,
`report.event/002-003`, `scada.control.capabilities/000`, `scada.params/004`,
`spaceheat.node.gt/200,300`. Each round-trips at its own version and, where the
upgrade is runnable, along `decode-old → upgrade() → decode-current`
(`scada.control.capabilities/000` is upgrade-exempt via `UpgradeRequiresContext`,
`701495c`). Several were mined from existing field/test fixtures (the `layout.lite`,
`report.event`, `i2c`, `spaceheat.node.gt/300` instances); the rest authored
minimal. (2) The `xfail` marker is removed from `test_superseded_examples.py`,
promoting it to a hard gate. (3) Folds the design's durable architecture into a
new language-neutral `spec/snapshot.md` spoke (determinism/zero-diff, atomic
build, `samples/`, the round-trip gate + context-dependent-upgrade exemption),
linked from `spec/primary.md`; Python tool specifics stay in the
`src/sema/tools/` docstrings per the in-repo-spec / wiki-pointer split.

**Why:** OPS-380 thread 4 — completes the mandate landed in `ee5bd53` so the
snapshot round-trip exercises every old version along the upgrade path where
restricted-snapshot bugs concentrate (the `atn.bid` class; this same pass already
surfaced the `layout.lite/007→008` ShNodes-lift bug fixed in `0169b47`). Folding
the durable architecture into `spec/` is the prerequisite to deleting
`wiki/sema/designs/snapshot-improvement.md` (per designs-process); the design
file is removed once this lands.

## 2026-06-08 — test: enforce upgrade docstring ↔ registry summary mirror (`653a152`)

**What:** New `tests/registry/test_upgrade_summary_matches_template.py` asserts
that for every `templates/upgrades/<type>_<a>_to_<b>.py.jinja2`, the upgrade
docstring equals `registry.yaml` → `types.<type>.versions.<b>.summary` (modulo
whitespace) — true for all 30 upgrade templates today. Plus a `CLAUDE.md`
"Upgrade deltas live in three coupled places" note naming the
template-body+docstring / registry-summary / `direct_dependencies` triple and
pointing at the spec's "Nested Upgrades" rule.

**Why:** The `007→008` ShNodes omission drifted silently because the prose
summary and the upgrade docstring (mirror copies) were maintained by hand with
no gate, while the machine `direct_dependencies` stayed correct. The test turns
that mirror into an enforced invariant — editing one side without the other now
fails CI — and the `CLAUDE.md` note makes the coupling discoverable so a future
session checks the registry when it touches an upgrade.

## 2026-06-08 — fix: layout.lite 007→008 upgrade lifts ShNodes 200→300 (`0169b47`)

**What:** `templates/upgrades/layout_lite_007_to_008.py.jinja2` (and its
regenerated output `runtime/types/old_versions/layout_lite_007.py`) now lifts the
embedded `ShNodes` list through `spaceheat.node.gt` `200 → 300` during the
`007 → 008` upgrade: `data["sh_nodes"] = [node.upgrade() for node in self.sh_nodes]`,
plus the matching docstring line. The same change-line was missing from the
registry's prose record, so `registry.yaml` → `layout.lite.versions.008.summary`
gains `- ShNodes[]: spaceheat.node.gt:200 -> 300` (the version's
`direct_dependencies` already carried `spaceheat.node.gt:300` — only the summary
had drifted); `indexes/public_registry.yaml` + `indexes/versions.yaml` rebuilt to
match. (No version bump — completing a non-normative summary is a permitted
descriptive correction.)

**Why:** `layout.lite/007` declares `ShNodes: spaceheat.node.gt/200`, but
`LayoutLite008` accepts only `300` — the `007 → 008` upgrade bumped the version
and added the new top-level fields yet never lifted the embedded nodes, so any
`007` instance carrying nodes raised a `literal_error` on upgrade. The gap had
gone unnoticed because no old-version `layout.lite` fixture exercised the chain
(fixtures start at v011, whose nodes are already `301`). Surfaced by the OPS-380
thread-4 backfill: a realistic `layout.lite/007` example must round-trip
`decode-old → upgrade() → decode-current`, which is exactly the path this gate
exists to protect (the `atn.bid` class). The sibling steps in the chain
(`009→010` ha1 guard, `011→012` sub-type lifts, `012→013` i2c None-guard) were
audited against the per-version field types and are correct.

## 2026-06-08 — spec: superseded type versions MUST carry examples (`ee5bd53`)

**What:** Two spec edits + a new (xfail) enforcement test, no schema/data
changes. `spec/registry/types.md` "Permitted Changes (All Types)": added a
bullet explicitly permitting *addition or improvement of non-normative
`examples`* on a published version (same family as "clarification of descriptive
text" — alters no validation behavior). `spec/authoring/types.md`: retitled
"Examples (Optional)" → "Examples" and added a "Superseded versions" rule — a
type version that has a successor MUST carry at least one `examples:` entry;
latest versions and versionless types stay optional. New
`tests/registry/test_superseded_examples.py` enforces the mandate by walking
`definitions/types/`; marked `xfail` (non-strict) until the one-time backfill of
existing old versions lands (OPS-380 thread 4), at which point it xpasses and
the marker is removed.

**Why:** Superseded versions exist to be **upgraded**, and the
`decode-old → upgrade() → decode-current` path is where restricted-snapshot bugs
concentrate (the `atn.bid` class). The snapshot round-trip can only exercise a
version it has a fixture for, and the fixture is the authored `examples:` entry
(→ a generated sample). So every superseded version needs an example for
old-version round-trip coverage to be total. Permitting examples on published
versions removes the immutability grey area that would otherwise block the
backfill — examples are non-normative guidance, not validation behavior. Part of
OPS-380 (thread 4, spec half; the example backfill itself follows separately).

## 2026-06-08 — snapshot: round-trip gate + generated samples + lint-gated atomic build (`bea9846`)

**What:** Reworked `sema snapshot build` (`src/sema/interfaces/cli/snapshot.py`)
to generate into a **staged** tree, gate it, and swap into place only on green —
a failed gate is a no-op (the previous snapshot is left untouched), replacing the
old clear-then-write that could half-write on failure. New gates:

- **`samples/`** (OPS-380 thread 3) — `src/sema/tools/snapshot_check.py` runs in a
  subprocess against the staged package and, for every type version under
  `definitions/` with an `examples:` block, feeds the first example through the
  snapshot codec (`from_dict → to_dict`) and writes the canonical serialized form
  to `samples/<type.name>[.<version>].json` (old versions included). Writes a
  coverage `samples/README.md`. Samples are the exact wire bytes the runtime
  emits, so they double as the round-trip's expected output and don't churn.
- **Round-trip gate** (OPS-380 thread 2) — a new shipped, pydantic-only
  `roundtrip.py` harness (`templates/roundtrip.py.jinja2`, emitted by
  `generate_runtime.py`) walks `samples/`, decodes each at its own version,
  re-encodes (deep-equal), and upgrades superseded versions to latest. Run
  build-time over the staged tree (raises → no-op) and re-runnable consumer-side.
  This is the check that catches a word missing only from the *restricted*
  snapshot (the `atn.bid` class). `tests/test_snapshot_roundtrip.py` proves it
  flags a non-decoding sample.
- **Lint gate** (OPS-380 thread 1) — `src/sema/tools/snapshot_lint.py` runs
  `ruff format` in place (the generator already sorts output, so format makes a
  re-build a zero diff) and reports `ruff check` / `mypy` (fatal only under
  `--strict-lint`, because the generator emits known pre-existing violations
  that are a tracked cleanup). New `scripts/regenerate_runtime.sh` applies the
  same gates to the in-repo runtime.

Stopped vendoring `tests/` into snapshots: removed the `write_tests` path
(`generate_runtime.py`, `formats.py` — deleted `generate_property_format_test`)
and its emission at the build call site; snapshots now ship `samples/` +
`roundtrip.py` instead of generated test code. Updated `test_snapshot_cli.py`
(asserts no `tests/`, presence of `samples/` + `roundtrip.py`) and dropped the
obsolete `write_tests` unit test.

**Why:** Standing up the gridworks-journalkeeper snapshot surfaced four
frictions: formatting-only regen churn that buries real diffs; generated test
*code* leaking into the consumer package; no per-type decode test (the gap that
let the `atn.bid` closure bug ship); and no ready JSON fixtures per type. The
round-trip gate makes "does the emitted runtime decode its own types" a
build-time invariant against the *restricted* vocabulary — exactly where a
sema-runtime test can't see the bug. Atomic staging means a failing gate can
never corrupt a consumer's snapshot. `ruff format` + the generator's existing
sorting make a second regen a zero diff. Part of OPS-380 (threads 1–3).

---

## 2026-06-08 — drop snapshot.built_at from the restricted registry (`c1d9dad`)

**What:** Removed the wall-clock `built_at` field (and the now-empty `snapshot:`
section) that `build_restricted_registry` injected into the snapshot's
`registry.yaml` (`src/sema/tools/build_seed_definitions.py`); dropped the
now-unused `datetime`/`timezone` import; updated `_is_top_level_sections_mapping`
to expect `[metadata, formats, enums, types]`.

**Why:** `built_at` was non-deterministic — it made every snapshot regen diff on
`registry.yaml` regardless of generated-code formatting, blocking the zero-diff
goal (OPS-380, thread #1). Nothing reads it; snapshot provenance is already
carried by the copied `metadata.registry_version` + `last_updated`. Dropping the
`snapshot:` key also makes the restricted registry conform to the spec's
top-level structure — `metadata/formats/enums/types`, which has no `snapshot`
section (`spec/registry/structure.md`). Part of OPS-380.

---

## 2026-06-08 — remove structured enums. market slots must be divisible by 300 (`0bf8f0f`)

**What:** Removed the unpublished structured-enum capability from the prior
commit. Reverted `spec/authoring/enums.md`, `spec/registry/enums.md`, and the
`spec/primary.md` enum-glossary line (drops the "Structured Enums" section +
`value_attribute_schema`/`value_attributes` rules); restored the codegen path
(`src/sema/tools/runtime_generation/enums.py`) and runtime base
(`src/sema/runtime/enums/gw_str_enum.py`) to pre-capability; demoted
`gw.market.product.name` to a plain versioned enum (`value_descriptions` only).
Kept the rest of the untangle — the `market.type.name → gw.market.product.name`
rename, the `market.product` type, the pure-pattern `market.slot.name` format,
and `frozen_at`. Added a one-line clarification to `spec/authoring/formats.md`
that the no-reference rule binds a format's validation behaviour / generated
validator, not just its schema `$ref`. Same cluster, two additions: (1) enrich
`market.product` with the name-encoded fields it now carries as validated data —
`SlotDurationMinutes`, `GateClosingSeconds`, and `QuantityUnit` (`$ref`
`market.quantity.unit`, a power unit so quantities compare across slot
durations); `Timeframe` deferred. (2) Bake the 5-minute grid invariant into the
`market.slot.name` validator (slot start MUST be divisible by 300) — a
vocabulary-free arithmetic check, so it does not reintroduce the format→enum
edge the gjk fix removed.

**Why:** `market.slot.name` became a pure structural pattern (the real gjk fix),
removing the slot-start/period alignment check — the only in-vocabulary consumer
of the structured enum's per-product `slot_minutes`. With no consumer left, the
capability was complexity for nothing: a fragile hand-rolled codegen path (its
integer case stubbed with a `raise`) and a third home for semantics with weaker
guarantees (primitive-only, unvalidated free-text units). Name-decodable
semantics belong on the `market.product` **type** (real `$ref`'d fields) and in
axioms — mirroring the legacy `MarketTypeGt` and the market-product taxonomy's
"name + rich type" verdict. Unpublished, so the rollback is clean. See OPS-378 +
`wiki/sema/designs/untangle-market-type-name/rollback-structured-enums.md`.

## 2026-06-08 — Untangle market.type.name into structured gw.market.product.name + market.product type (`8190fdb`)

**What:** The complete `untangle-market-type-name` work (OPS-378), squashed.
Two reusable Sema capabilities applied to the market vocabulary, while keeping
the universal market messages uniform across makers:

- **Structured enums** (`spec/authoring/enums.md` "Structured Enums") — enum
  values may carry a fixed, typed row of primitive attributes
  (`value_attribute_schema` + `value_attributes`), codegen'd as a frozen
  `…Attrs` dataclass + a `.attrs` accessor (deferred module-level table so the
  Enum metaclass doesn't absorb it). Zero closure edges (attributes are
  primitives, never `$ref`). Authored `enums/gw.market.product.name/000.yaml` —
  GridWorks's product vocabulary; each token decodes to
  `timeframe / slot_minutes / gate_minutes / quantity_unit`; `unknown` is the
  row-less default sentinel.
- **`market.product` type** — an open, maker-agnostic product object
  (`MarketProductId` uuid · `ProductNameEnum` left.right.dot · `Name` bare
  token). It names *which* maker's product vocabulary a token belongs to without
  pinning one, so one shared type scales across thousands of makers; the decode
  is opt-in, consumer-side.
- **`frozen_at` word-status** (`spec/registry/structure.md`) — a word-level
  RFC-3339 marker closing a version lineage (no new versions), orthogonal to
  `replaced_by`. Used to retire-in-place: `market.type.name` →
  `replaced_by gw.market.product.name`; `atn.bid` → `replaced_by bid`. Legacy
  words stay valid and decodable forever; they are not deleted.
- **`market.slot.name` kept maker-agnostic & shape-only** — de-tangled to a
  self-contained, versionless leaf whose single regex enforces commodity
  `[erd]` · a `spaceheat.name`-shaped product token · a `left.right.dot` maker
  alias · 10-digit slot start. It no longer reaches any enum. So `bid` and
  `latest.price` stay **uniform across all market makers** (no per-maker bid
  types); product-token validity and slot-start alignment are decoded opt-in,
  receiver-side, against that maker's structured product enum.

**Why:** `market.type.name` conflated a market *product* (a named, decodable
thing) with the *type of market*, and the legacy `market.slot.name` validator
reached the `MarketTypeName` enum through an edge the dependency closure couldn't
see — the gridworks-journalkeeper `ModuleNotFoundError`. The fix puts product
semantics in a structured enum (decodable in the vocabulary, not a side table),
keeps the shared slot-name format shape-only so it carries no hidden vocabulary
edge (that class of bug is gone **by removal**), and retires the old words in
place via `frozen_at`/`replaced_by` rather than deleting them. Keeping the slot
format maker-agnostic is what lets `bid`/`latest.price` stay a single shared
contract; each market owner instead publishes its own
`<ns>.market.product.name` structured enum (see
`wiki/gridworks-marketmaker/explorations/market-product-and-uniform-bids.md`).

Note: an interim "versioned property formats" approach (a slot-name format
declaring a registry axiom dependency on the product enum) was prototyped and
then reverted in favor of this simpler maker-agnostic shape-only format — it
nets to zero in this squash. `gw.market.product.name`'s `rt60gate30b` row uses
the design's decode (60-min slot / gate 30 / AvgkW); MarketMaker remains the
source of truth — confirm before relying on that token's decode.

---

## 2026-05-29 — Adjust GNodeClass concepts (`b843710`)

**What:** Two enum edits:

- `definitions/enums/gw.g.node.class/000.yaml` — remove
  `TimeCoordinator` from the enum AND its value-description block.
  The enum is unpublished, so removal is permissible (per Sema's
  "enums are additive only" MUST, which binds only after publication).
- `definitions/enums/base.g.node.class/000.yaml` — port the
  `ced7cec` tightening of the `Logical` value-description from the
  `jm/effortless` branch onto `dev`. Replace
  *"purely logical or service-level nodes such as SCADA, forecasting
  services, market-maker actors, simulation nodes, or organizational
  microservices..."* with *"Used by GridWorks for SCADA and forecasting
  services."*

**Why:** Both edits land the same architectural distinction that's
emerging in `gridworks-base`: GNodes are grid entities (physical +
logical) participating in the production control plane; system
services (Supervisor, TimeCoordinator, journalkeeper, ear actor-side)
are NOT GNodes even if they ride the same rabbit+sema toolkit.

TimeCoordinator specifically: its role is "maintaining simulation
time or orchestrated test time across actors." That's a system
service, not a grid entity. The tightened `base.g.node.class/Logical`
explicitly excludes "simulation nodes" and "organizational
microservices." TimeCoordinator fits both excluded categories.
Symmetry with Supervisor (also non-GNode but a control-plane
orchestrator) becomes clean after this change.

The base.g.node.class fix-forward closes a branch-discipline issue:
the tightening was made on `jm/effortless` (which hasn't merged to
dev) but the lexicon-level distinction is dev-applicable.

Supports the in-flight
`wiki/gridworks-base/designs/support-non-gnode-actors/` design —
specifically the `orchestrator.md` (formerly `control-plane-tier.md`)
sub-spec, which lifts the heartbeat + sim.timestep machinery into a
middle `Orchestrator` tier that both Supervisor and TimeCoordinator
can extend without GNode identity.

## 2026-05-29 — ignore top level seed_request.yaml (`ce5e770`)

**What:** Add `seed_request.yaml` to the repo-root `.gitignore`.

**Why:** The repo-root `seed_request.yaml` is a scratch seed for exercising
`sema snapshot prepare` locally (e.g. validating that the
gridworks-journalkeeper closure pulls `market.slot.name` → `market.type.name`).
It is distinct from the canonical per-consumer seed
(`gridworks-journalkeeper/src/gjk/sema_seed_request.yaml`) and the committed
`template_seed_request.yaml`; ignoring it keeps ad-hoc snapshot experiments out
of version control.

## 2026-05-27 — tweak base g node class (`ced7cec`)

**What:** Narrow the `Logical` value description in
`definitions/enums/base.g.node.class/000.yaml`. Replace
*"purely logical or service-level nodes such as SCADA, forecasting
services, market-maker actors, simulation nodes, or organizational
microservices..."* with *"Used by GridWorks for SCADA and forecasting
services."* Removes "market-maker actors", "simulation nodes", and
"organizational microservices" from the named examples.

**Why:** Aligns Sema's lexicon with the architectural distinction
emerging in `gridworks-base`: GNodes (Physical + Logical) are
production control-plane participants; services that use the gwbase
rabbit+sema toolkit without joining the production GNode system
(journalkeeper, ear's actor-side, future analytics consumers) are
explicitly NOT Logical GNodes. The prior description's
"organizational microservices" phrasing invited the journalkeeper-
as-Logical-GNode reading the design is moving away from. Narrowing
to *only* SCADA + forecasting services removes the ambiguity.
Supports the in-flight `wiki/gridworks-base/designs/support-non-gnode-actors/`
design (ServiceSettings vs GNodeSettings split).

Side-effect to track separately: Supervisor and TimeCoordinator —
both in `TransportClass`, both control-plane participants, neither
in `base.g.node.class` — are now also outside Logical's scope. They
were never strictly GNodes, but the design implications surface
during the gwbase refactor (see `wiki/gridworks-base/designs/support-non-gnode-actors/`).

## 2026-05-26 — merge dev (`0d07927`)

**What:** Merge commit `0d07927` bringing `origin/dev` into the local
`ej-dev` line. Brings in a large batch of dev-landed changes:
`active`→`published` lifecycle rename, new format definitions
(`non.empty.string`, `positive.int.as.str`), several type-version
adjustments, the new top-level `spec/` folder, deletion of the old
`docs/` tree (content relocated to wiki), regenerated indexes, and
the dev-branch sema-vocabulary CLAUDE.md.

**Why:** Sync point so the `jm/effortless` work (port move, swap
claudes, eventual web-app refactor) sits on top of current dev rather
than the older ej-dev branch base. Brings the dev-lens authoring
conventions into reach on this branch — required for the two-lens
CLAUDE.md pattern (effortless_CLAUDE.md committed + gitignored
personal CLAUDE.md) to be meaningful.

## 2026-05-26 — swap claudes

**What:** Pure rename (R100, 0 line changes) of the committed
`sema/CLAUDE.md` to `sema/effortless_CLAUDE.md`. The file content — EJ's
ERB-lens framing of sema (rulebook-as-SSoT, `effortless build` discipline,
effortless skill suite) — is unchanged. Done on the `jm/effortless`
branch.

**Why:** sema's `.gitignore` already ignores `CLAUDE.md`, so renaming the
committed copy out of that slot lets each developer keep their preferred
*local* `CLAUDE.md` (a personal working-frame override) without touching
the team-shared recipe. The team-shared recipe for the ERB-pipeline side
now lives at the explicit name `effortless_CLAUDE.md`, and individual
devs (jess, ej, …) can layer their own gitignored `CLAUDE.md` on top —
e.g. jess's local copy uses the dev-branch sema-vocabulary lens (axiom /
registry / `/make-sema-word` discipline). See
the "Integrate the two sema
CLAUDE.mds" for the integration plan.

## 2026-05-26 — move sema-pg from host port 5433 to 5434

**What:** Eight files in sema/ updated to point local Postgres at host port
5434 instead of 5433 (and unify the lingering 5432 defaults that drifted
from the script): `start-db.sh` (PORT + header rationale),
`postgres/init-db.sh` (DEFAULT_CONN), `app/api/db.py` (default fallback),
`app/api/.env.example`, `app/README.md` (rationale paragraph + Docker
snippet + DB-connection blurb), `DEPLOY.md` (two URL references),
`postgres/migrations/README.md`, and `CLAUDE.md` (DB connection line +
note on what occupies 5432/5433).

**Why:** First step of harmonizing ej-dev sema with the rest of the
GridWorks dev fleet. `gw-data-pg` (the analytics TimescaleDB container,
see `gridworks-data/README.md`) holds host port 5433 unconditionally; a
dev who runs both gets a port collision today. The two systems are
sufficiently separate (different code paths, different teams, sema doesn't
need TimescaleDB) that consolidating into one container is the wrong
move — see Brian's earlier pushback. Moving sema to 5434 lets a native
Homebrew Postgres (5432), gw-data-pg (5433), and sema-pg (5434) all
coexist on one dev box. While in there, swept the stale 5432 defaults
that the original f34a4e4 script-add missed.

## 2026-05-22 — add a script for starting postgres in docker

**What:** New top-level `start-db.sh` (+69 lines, no other files touched).
Idempotent orchestration of a local `sema-pg` container (`postgres:16`)
mapped to host port **5433** → container 5432, with `POSTGRES_DB=sema` and
`POSTGRES_HOST_AUTH_METHOD=trust`. Waits on `pg_isready`, then dispatches
to `postgres/init-db.sh` based on flag (default: init if schema absent;
`--no-init` skips; `--reinit` rebuilds). Fails fast if Docker isn't running.

**Why:** Local dev needed a one-command DB bring-up that plays nicely with a
native Homebrew Postgres on 5432 (hence 5433) and is safe to re-run — the
prior workflow was hand-rolled `docker run` invocations, which drifted
between developers and silently re-created containers under varying flags.
Centralising the container shape here also gives the ej-dev/dev
harmonization a single chokepoint to edit when the port or image moves.

## 2026-05-26 — Wrap-up: highlight bijective MD↔ERB thesis (sema-specific) + queue ERB practice finding

**What:** Two wiki/sema/research/ doc updates closing this investigation
as work-in-progress.

`erb-md-mirror.md` — new §"Core thesis (sema-specific)" lifted to the
top of the doc. Makes three properties of the proposed refactor
explicit and load-bearing: *bijective* (round-trip exact, CI-gated),
*code-gen only* (mechanical, no curated translation), and
*sema-specific* (a general ERB-refactor pipeline would be infeasible;
sema's per-word + axioms + upgrades shape admits a clean hub-and-spoke
decomposition that a generic rulebook does not). Adds the motivation:
the load-bearing requirement is **unbounded ability to add new
axioms** (and probably upgrades) over sema's lifetime — axioms-as-
prose-in-28K-JSON does not scale, and a bijective MD mirror keeps
axiom authoring inside the git-native hub-and-spoke workflow without
giving up ERB's queryable DAG. Bumped Updated stamp to 2026-05-26.

`findings.md` — new dated entry: "Practice ERB pair-programming with
Claude before resuming the audit." Action: load full effortless
toolchain (CLI + MCP + Postgres mirror + Postgres GUI) and pair on
small rulebook touches so jess internalizes the ej + Claude rapid-
rulebook loop firsthand before continuing the audit threads (F5, F6,
p, r). Rationale: jess doesn't yet have a firsthand feel for the
workflow that produced ej's 28K-line rulebook so quickly; until she
does, she can't properly calibrate the strong CMCC thesis or judge
whether to drive vs consume ej's pipeline. Entry references the
queued-next-session-effortless-setup memory.

**Why:** The investigation hit a natural pause point with the
`active` → `published` rename landed and the audit's first-pass
findings recorded. Jess's stated next move is to set up tooling and
practice the workflow before pushing further on synergy analysis; the
remaining open audit threads (F5 TypeHelpers alignment, F6 Templates
table, p axiom-DSL feasibility, r round-trip empirical run) are best
re-engaged after that calibration. These two doc updates capture the
sharpest distillation of the thesis we have today (bijective refactor
+ unbounded axioms) and the explicit next-step action (practice
before more theory), so the work picks up cleanly in the next
session.

---

## 2026-05-26 — sema lifecycle: rename `active` → `published` (`fa42333`)

**What:** Replace the lifecycle status word `"active"` with `"published"`
across `spec/` and the Python tooling that reads/writes the `status:`
field. Touches:

- `spec/primary.md` glossary entry (draft vs published, with cleaner
  "mutable vs immutable" framing).
- `spec/registry/structure.md` §Status Field — full section rewritten:
  allowed values, defaults, lifecycle prose, `created`-after-promotion
  rule. Drops "under active development" phrasing (mutability is the
  property that matters, not "active development").
- `spec/registry/types.md` — status field schema and 5 references.
- `src/sema/tools/build_public_registry.py` — `is_active()` →
  `is_published()` (renamed; all 5 call sites updated), `active_versions`
  variable → `published_versions`, docstring updates.
- `src/sema/interfaces/cli/snapshot.py` — comment update.
- `tests/registry/test_registry_status_consistency.py` — `ALLOWED` set,
  `DEFAULT_STATUS` constant, `_schema_status()` default, docstrings.
- `tests/registry/test_registry_schema_file_layout.py` — `_registry_*_status()`
  defaults, `expected_*_id_line()` default-arg values.
- `tests/registry/test_registry_yaml_correctness.py` — literal `"active"`
  occurrences, variable names (`active_version_keys` →
  `published_version_keys`, `active_versions` → `published_versions`,
  `latest_active` → `latest_published`), test function name
  (`..._matches_latest_active_schema` → `..._matches_latest_published_schema`),
  error message strings.
- `tests/registry/test_public_registry_consistency.py` — literals + 2
  comments.
- `tests/registry/test_structural_dependency_consistency.py` — 2 literals.
- `tests/registry/test_identity_consistency.py` — 1 default value.
- `tests/registry/conftest.py` — 2 docstring lines.

`definitions/registry.yaml` and `definitions/*` schema files needed no
edits: pre-rename, no entry carried the literal word `"active"` —
status was always default-via-absence. Post-rename, the default value
is now `"published"` but the registry data is unchanged.

Three sema source files contain `active` in **non-lifecycle**
contexts and are deliberately left alone: `spec/primary.md:11`
("in active context" = LLM working context), `spec/authoring/types.md:384`
("under active schema evolution" = ongoing), and the runtime axiom
templates for `layout.lite/*` and `fis.authority.manifest/000`
("active ActorClass", "active count" = SCADA runtime semantics).

Full `pytest` run: 159 passed, 1 xpassed (pre-existing, unrelated).

**Why:** "Published" is unambiguous (committed to
`https://schemas.electricity.works/...` and immutable). "Active" was
overloaded — read as "currently used," "not deprecated," or "latest"
depending on context, and the spec text already said "active is
published and immutable," which itself signals the better word. The
rename aligns sema's vocabulary with ej's ERB out of the box (his
`TypeVersions.Status` already uses `'published' | 'draft'`), with
industry norms (npm, crates, PyPI, semver tooling), and with the
mutable-vs-immutable dichotomy that is what the lifecycle is actually
*about*. Migration cost was zero in registry data because the old
`"active"` value was default-via-absence — no entry needed touching.
The reason for the full clean (renaming the internal `is_active()`
function, the test variable names, etc.) rather than a literal-only
replacement: leaving `is_active()` as a function name when the value
it tests is `"published"` would be a permanent semantic landmine.

This commit lands per the queued
`queued-sema-active-to-published-rename` memory from the prior
(tame-raven) session.

---

## 2026-05-25 — `new.command.tree/000`: allow union over multiple `spaceheat.node.gt` versions (`3286294`)

**What:** `definitions/types/new.command.tree/000.yaml` —
`ShNodes.items` changed from a single
`$ref → spaceheat.node.gt/200` to a `oneOf` over `/200`, `/300`, and
`/301`. `registry.yaml` structural deps for `new.command.tree:000`
extended to include `spaceheat.node.gt:300` and `:301`. Indexes regen
(`dependency_closure`, `public_registry`, `reverse_dependencies` —
also picks up `gw1.actor.class:009` and `:011` as transitive enum deps
via the new node-gt versions). Runtime regen
(`src/sema/runtime/types/new_command_tree.py`, `reverse_query.py`,
`type_helpers/__init__.py`).

**Why:** `new.command.tree:000` was pinned to a single
`spaceheat.node.gt` version (`/200`) but real-world command-tree
payloads now need to carry nodes spanning multiple node-gt versions
during the SCADA rolling-version window. Widening via `oneOf` rather
than version-bumping `new.command.tree` itself is the right move
because the envelope semantics are unchanged — only the per-item union
shape needs to admit the additional versions. Pre-publication
in-place edit (no version bump) per `feedback_schema_fix_protocol`.

---

## 2026-05-25 — Add weather type v000 (`656c3c0`)

**What:** New `definitions/types/weather/000.yaml` (literal versioning).
`registry.yaml` entry added with `latest_version: 000`, deps closure
(`spaceheat.name`, `utc.seconds`, `non.empty.string`, `unitless.float`,
etc.). Indexes regenerated (`dependency_closure`, `lookup`,
`public_registry`, `reverse_dependencies`, `versions`). Runtime
generated (`src/sema/runtime/types/weather.py`) and an empty axiom
template stub created (`templates/axioms/weather_000.py.jinja2`).
`registry.yaml.metadata.last_updated` bumped to `2026-05-24T17:00:00Z`.

**Why:** Registers the legacy weather observation type (single-instant
outside-air-temperature + wind-speed from a third-party source,
identified by a weather channel name like `weather.gov.kmlt`) so that
journalkeeper can persist messages emitted by the new
gridworks-weather-forecast service. Closes the `queued-sema-add-weather-v000`
memory item. Stub axiom template lands ahead of axiom logic; the type
ships usable without it (the axiom slot is reserved for a future
"WeatherChannelNameInRegistry" or similar constraint, currently empty).

---

## 2026-05-26 — Three new research docs: MD↔ERB mirror + no-degradation audit + findings log

**What:** Three new docs under `wiki/sema/research/`, all Pass 0 Draft.

`erb-md-mirror.md` — proposes a small bidirectional tool that emits the
rulebook schema as a wiki-style hub-and-spoke MD tree under
`wiki/sema/erb-mirror/` and accepts schema-level edits back as JSON
patches against the rulebook. Data rows stay in JSON; only the schema
round-trips. Two-emitter design + CI gate + day-one pilot scope + open
questions. Names the downstream extension: same tooling enables
Karan-style ERB-as-functional-spec convergence on production repos like
gridworks-scada (with the structural-~50% / behavioral-~50% fit caveat).

`erb-no-degradation-audit.md` — catalogs every operation sema supports
today (authoring, indexes, runtime gen, tests, publishing) and
classifies each under the working thesis (ii): YAML-leading, granular
bidirectional, no degradation. Surfaces 6 specific findings for ej
(granular emit not yet implemented; upgrades are a second source-of-truth
in Python modules not in YAML; coverage gap from unfinished migration;
TypeHelpers rule alignment to verify; Templates table empty;
axioms/combinators round-trip as opaque blobs). F3 (lifecycle/publication
Status) was initially scoped as a degradation risk; corrected during
review (jess caught the error — sema does carry explicit `status:`) and
dissolved. Closes with a 9-item acceptance checklist plus 5 open
questions for ej.

`findings.md` — new running log of actions WE (jess + Claude) will take
on sema or sema-adjacent tooling. First entry: drop ERB's `PromotedAt`
column (redundant with sema's `created` per
`spec/registry/structure.md:100-103`). Distinct from the audit, which
lists items for ej to satisfy.

**Why:** The trio forms the load-bearing artifact set for evaluating
ej's ERB integration. The mirror tool addresses how the team and Claude
reason about the rulebook itself (the meta-work case ej's
LLM-friendliness story does not optimize for, per the working
`erb-is-an-llm-interpretation` C-reading: rulebook-as-generative-prior).
The audit converts the abstract "no degradation" goal into a concrete
checklist for ej. The findings log separates *our* action items from
ej-facing recommendations so the audit stays scoped to its actual
audience. Together they surface that several pieces ej presents as
working — notably granular bidirectional emit — are aspirational
rather than current code. Output of `/grill-me` thread item q (audit)
and the MD-mirror brainstorm; sets up p (axiom DSL feasibility) and r
(round-trip empirical run) as smaller follow-on investigations.

---

## 2026-05-24 — Typed Maps construct & applications (`f2472ba`)

**What:** Add `spec/authoring/types.md` §Open Containers and §Typed
Maps; add Composition Rule paragraph permitting multi-version `oneOf`;
add Referencing Other Vocabulary header requiring canonical
`https://schemas.electricity.works/...` URLs for every `$ref`. New
format word `positive.int.as.str` (int-keyed-map blessed key format)
+ registry entry. `gw1.tank.temp.calibration.map/000` Tank restored
to typed-map shape using the new construct; the redundant
`ContiguousTankIndexConstraint` axiom is dropped (subsumed by
structural enforcement; orphan runtime axiom template removed).
`gw.nolan.layout/000` GNodes refactored from
typed-dict-without-propertyNames to a typed array; axiom 1 restated
for arrays. New `test_typed_maps_have_blessed_propertynames` enforces
the binary key-format rule.

This commit also carries the cross-cutting state that earlier commits
in the series deferred: `registry.yaml` reconciliation (adds
`non.empty.string` and `positive.int.as.str` format entries, deletes
the `analytics.channel.gt` type entry, adds typed-map structural deps
for calibration.map), all `indexes/*` regen, runtime regen for
`property_format.py`, `relay_actor_config.py`,
`old_versions/relay_actor_config_002.py`, and
`gw1_tank_temp_calibration_map.py`, plus the new
`positive.int.as.str` runtime template.

**Why:** "Keyed dicts of typed values" is a standard pattern (per
user) and the orig spec was silent on it. Formalizing as the Typed
Map construct gives the pattern a single, mechanically-checkable
shape with a tight binary key-format choice (string XOR int) — wider
than "forbid all typed dicts" but narrower than "any propertyNames
goes." GNodes was the smell case (keys redundant with `GNodeClass`
field on the value); Tank was the legitimate case (keys are tank
indices, genuine semantic content). The new test mechanically
distinguishes them via the propertyNames signal. Open Containers
section codifies the "no unconditional axioms on `type: object`
contents" rule — the conditional-discriminator pattern in
`derived.channel.gt`'s `Parameters` axioms 3+4 remains permitted as
the spec-can't-express exception. Cross-cutting state lands here
because earlier commits intentionally deferred registry/indexes/regen
to keep their own diffs minimal and reviewable; the cost is that the
suite was partially red between commits 3 and 7 inclusive, fully
green again at this commit.

---

## 2026-05-24 — Identity-field consistency tests and title typo fix (`150b01a`)

**What:** New `tests/registry/test_identity_consistency.py` with three
functions: `title` matches the name segment of `$id`; `TypeName.const`
matches the same; Version field shape matches the current
`versioning_strategy` (`const` for the latest of a literal-strategy
type; `type: string` for all versions of a string-strategy type).
`gw1.telemetry.name.quantity.projection/000`: title was
`telemetry.name.quantity.projection` (missing the `gw1.` prefix);
fixed.

**Why:** The existing `test_registry_schema_file_layout.py` checked
the `$id` line against the canonical URL but never compared it to the
schema's inner `title` field. Drift between them was silently OK. The
title typo on `gw1.telemetry.name.quantity.projection` had been
shipped that way; pure metadata typo (runtime gen derives the class
name from `$id`, so zero runtime impact). The strategy-aware Version
check matters because a type whose `versioning_strategy` evolved from
`string` to `literal` keeps the original `type: string` shape on
older versions — a naive "Version must always be const" test would
false-positive on legitimate legacy versions.

---

## 2026-05-24 — Type-schema examples MUST be JSON document strings (and valid JSON) (`ab218db`)

**What:** New `tests/registry/test_example_format.py` with two
functions: entries under `examples:` MUST be strings (not YAML maps),
and if strings MUST parse as valid JSON. Four example blocks fixed:
`channel.readings/002` and `channel.readings.list.item/000` (YAML
maps rewritten as JSON strings); `relay.actor.config/002` example
(missing comma after `WiringConfig`, trailing comma after `Version`);
`derived.channel.gt/002` (missing comma after `OutputUnit`). This
commit also folds in the `relay.actor.config/002` minLength → `$ref →
non.empty.string` swap (parallel to commit 4091454's swap on `/003`),
since the file was already being touched here for the example fix.

**Why:** `sema/spec/authoring/types.md` §Examples already says
"Examples SHALL be serialized JSON documents, not YAML object
representations," but no test enforced it. YAML-map examples
masquerade as valid (they're parseable YAML) while telling consumers
the wrong format. Examples don't affect runtime validation, but they
ARE used by integrators to seed code and as IDE/CI fixtures — wrong
or malformed examples mislead. Folding the `/002` minLength swap into
the same commit avoided touching `relay.actor.config/002` twice.

---

## 2026-05-24 — Extend Primitive Constraint Rule to all string-constraint keywords; add non.empty.string (`4091454`)

**What:** New format schema `non.empty.string` (type: string,
minLength: 1). `tests/registry/test_primitive_constraints.py`
extended to cover all forbidden constraint keywords (`pattern`,
`minLength`, `maxLength`, `multipleOf`), not just numeric ones.
Recursion stops at `propertyNames:` (blessed by Typed Maps). Six
fields swapped from `type: string + minLength: 1` to `$ref →
non.empty.string`: four on `relay.actor.config/003` (event / state
names), two on `fis.instance.authorization.event/000` (peer address,
connection handle). The parallel four-field swap on
`relay.actor.config/002` is folded into commit `ab218db` (the example
fix touched the same file). Runtime tightens `str` → `NonEmptyString`
once commit `f2472ba` regenerates.

This commit ships the format schema YAML only; the corresponding
`registry.yaml` entry (and runtime regen + indexes) land in commit
`f2472ba`.

**Why:** The Primitive Constraint Rule already said primitive
constraints must be wrapped in named formats; the test only enforced
the numeric subset. The minLength fields had been shipped with
inline `minLength: 1` — a workaround for not having a "non-empty
string" format word. Adding the format and enforcing the rule for
ALL constraint keywords closes the gap. Runtime tightening means
empty strings, which the old `str` type accepted, now hard-fail at
deserialization. `non.empty.string`'s `created` is back-dated to
2024-12-31 so dep timestamps order correctly against the older
consumer types it now serves (see
`wiki/sema/research/format-created-must-be-real.md` for the follow-up
rule-tightening proposal).

---

## 2026-05-24 — $ref values must be canonical Sema URLs (`372f73f`)

(Commit subject as recorded by git is ` values must be canonical Sema URLs` —
leading space, missing `$ref` prefix — because the shell ate the `$ref`
substring at commit time. Intended subject was "$ref values must be canonical
Sema URLs"; flagged here for accuracy.)

**What:** New `tests/registry/test_ref_values.py`: every `$ref` value
in a type or enum schema SHALL be a canonical Sema schema URL
(`https://schemas.electricity.works/{formats,enums,types}/...`).
`definitions/types/analytics.channel.gt/000.yaml` deleted (had
`$ref: string` — not a valid URL); references to it removed from
`synced.readings.bundle/{001,002}` prose. `src/sema/tools/build_seed_dag.py`
tightened: `normalize_ref` no longer silently passes through non-canonical
refs (`/types/...`, `types/...`, `enums/...` shorthand branches deleted —
no schema used them); the main DAG loop's `if dep is None: continue`
defensive skip replaced with `raise`.

This commit ships the schema file deletion + prose updates + the
tightening + the new test. The matching `registry.yaml` deletion of
`analytics.channel.gt`'s entry, and the indexes regen that follows,
land in commit `f2472ba`.

**Why:** `analytics.channel.gt` was a draft Joe didn't end up using
(user direction: delete rather than fix). The two defensive
fallbacks in `build_seed_dag.py` existed only to tolerate exactly the
kind of malformed `$ref` that analytics.channel.gt had — with the
test now catching them and analytics.channel.gt gone, both
workarounds are dead code. Hard-raise replaces silent-skip so future
schema authors can't reintroduce the pattern by accident.

---

## 2026-05-24 — Fixture broadens coverage (`0802853`)

**What:** `tests/registry/conftest.py` `all_schemas` fixture now
walks `definitions/{formats,enums,types}/` on disk and loads every
schema file directly. Previously loaded only via
`indexes/lookup.yaml`, which filters drafts and keeps only
`latest_version` per type. Fixture keys switched from `title` to
short canonical id derived from `$id` (`bid:000`, `uuid4.str`);
duplicate keys hard-error.

**Why:** Older immutable versions and draft schemas were silently
out of scope under the lookup-based fixture — a regression edit on
either was invisible to the suite. Walking the filesystem brings
every schema file in scope. The keying change ensures failure
messages include the version (e.g., `relay.actor.config:002`
rather than just `relay.actor.config`) so it's obvious which file
broke. This commit lands ahead of the rule-enforcement commits
below it in the changelog because those rules need the broadened
fixture to see all the schemas they're meant to catch.

---

## 2026-05-24 — Retire orig-spec.md (`6decb38`)

**What:** Delete `spec/orig-spec.md` (the pre-hub-and-spoke
monolithic spec, 2006 lines).

**Why:** Bakeoff complete; the hub-and-spoke spec
(`spec/primary.md` + `spec/registry/` + `spec/authoring/`) is the
canonical source. The orig was preserved per `sema/CLAUDE.md` for
transitional reference; that transition is now done. The orig
content lives forever in git history if needed for archaeology;
keeping it in-tree creates dual-source-of-truth drift risk and
~2000 lines of read-burden for anyone scanning `spec/`.


## 2026-05-23 — Dissolve sema/docs: relocate GridWorks context to wiki, merge motivation into README (`f377e76`)

**Why:** With the spec promoted to `sema/spec/`, `sema/docs/` had no
load-bearing job left — orig-spec.md moved to `sema/spec/`, and the
remaining files were either GridWorks-flavored context (wrong repo) or
overlapped with the README. A single-file `docs/` folder is overhead;
the README is THE standalone landing page per wiki convention and the
right home for motivation.

GridWorks-flavored context moved out (wrong repo):

- `scada-layout-concerns.md` (SCADA-side critique of the
  `gw.nolan.layout` word framed in LLM-comprehension terms — concerns
  *about* a Sema word, not the spec) → moved to
  `wiki/gridworks-scada/research/concerns/layout-axiom-complexity.md`
  with light rephrasing (header, attribution, typo fixes).
- `sema-and-domain-protocols.md` (framing on how Sema relates to OpenADR
  and similar) → moved to `wiki/sema/research/sema-and-domain-protocols.md`
  with a status stamp and a one-line "what this is" opener.
- `where-meaning-lives-in-gridworks.md` (GridWorks-architecture position
  paper naming Sema as the semantic authority, written in the first
  person) → moved to `wiki/sema/research/where-meaning-lives-in-gridworks.md`
  with a status stamp; cross-refs in `wiki/gridworks-scada/research/`
  updated to the new path.

Repo-level reshuffles:

- `motivation.md` merged into `README.md` as a new "Why this matters"
  section (the README already covered most of the framing; the unique
  bits — the four-point benefits list and the vision line — fit cleanly
  there). Also fixed a misplaced-bold typo from the original
  (`i**ndependent teams and organizations**` →
  `**independent teams and organizations**`) en route.
- `index.md` deleted: with everything either in `README.md` or in
  `spec/`, the navigation file was pure overhead.
- `docs/` folder deleted entirely.
- `README.md` also fixed a pre-existing broken link to
  `docs/rules_and_guidelines.md#vocabulary-registration-process` →
  `spec/governance.md#vocabulary-registration-process`.
- `sema/CLAUDE.md`: `docs/orig-spec.md` → `spec/orig-spec.md` (you
  moved orig-spec to spec/ between turns).

## 2026-05-23 — Promote sema/spec/ to the top level alongside definitions/ and indexes/ (`bfc7c21`)

**Why:** Primary motivation is to make the spec **digestible for LLMs** —
a 2006-line monolith forces every AI session to skim or partial-load,
making "Read the spec" a wishful directive rather than a real verification
step. Bundles two moves: (1) split `docs/sema-specification.md` into a
hub-and-spoke layout (`spec/primary.md` + `spec/registry/` +
`spec/authoring/` + `spec/governance.md`) so an agent under
`/make-sema-word` can pull the ~200-line spoke for the kind it's touching
and actually load it in full; (2) elevate `spec/` out of `docs/` to sit
beside `definitions/` and `indexes/` because the spec is the canonical
rebuild artifact, not background reading. The split also let us fold
language-neutral runtime upgrade discipline into the spec
(`authoring/type-semantics.md#upgrade-discipline`, replacing lore that had
been hiding in `sema/CLAUDE.md`) and fix two latent issues in the source:
a duplicated Change Process section and the `report v002`
`Version: const "003"` mismatch with its `$id`/title.

## 2026-05-23 — Update regular sema CLAUDE.md (`87cae7c`)

**Why:** Slimmed `sema/CLAUDE.md` to invariants only — dropped stale
`Coding/...` paths, dropped pydantic-emitter lore that doesn't belong on
every sema session, added the regen commands by path
(`scripts/build_indexes.sh`, `scripts/regenerate_runtime.py`), pointed at
`/make-sema-word` for the per-word ritual. Loaded on every sema work session,
so keeping it dense saves tokens and concentrates attention on the MUSTs
that actually bind.

## 2026-05-21 — Add gw / gridworks.header envelope Sema types; fix Dst; regenerate

**Why:** Register the GridWorks application-layer **envelope** as Sema
vocabulary. `gridworks.header/001` (literal) captures the delivery metadata
(`Src`, `Dst`, `MessageType`, `MessageId`, `AckRequired`) exactly as emitted by
the field-deployed gwproto Header wire format; `gw` (versionless) is the
envelope = header + an opaque `Payload` (any registered Sema type, matched by
`TypeName`). These are the types the gridworks-base **codec layer** wraps for
multi-hop traversal (see
`wiki/gridworks-base/executor/codec.md`). Fixed a schema bug — `gridworks.header/001`'s
`Dst` had no `type` (added `type: string`). Also removed an orphaned
`heartbeat_a_000_to_001` upgrade template left behind by the heartbeat change
below (it referenced the deleted v001 and failed two tests). Full suite green.
The header doc records a deliberate v002 evolution path (drop empty-string
sentinels, drop redundant `MessageType`, constrain `Dst`, add instance
provenance / signing).

## 2026-05-21 — heartbeat.a: delete unpublished v001, revert latest_version to 000, document supervisor use (`359f5b5`)

**Why:** An unpublished `heartbeat.a/001` had *deleted* the `MyHex`/`YourLastHex`
pair. That pair is the supervisor-tier liveness/continuity primitive — the names
are **sender-relative** (`MyHex` = sender's fresh token, `YourLastHex` echoes the
peer's last), so one type serves both the supervisor and the supervised actor;
it must not be dropped, and must not be renamed to a role-specific "SuHex."
Pre-publication revise-in-place is sema-legal, so v001 was deleted,
`latest_version` reverted to `000`, and v000's docs improved to state the
supervisor health-monitoring purpose. This is supervisor liveness, distinct from
the cross-party SCADA↔LTN contract heartbeat — see
`wiki/gridworks-scada/research/concerns/liveness-and-sla.md`.
