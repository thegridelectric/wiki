# Changelog

A reverse-chronological log of WHY we made each commit. The matching git
commit (in the `sema` repo) holds the WHAT (the diff). Each entry's date and
one-line title should mirror the corresponding commit so the two can be
cross-referenced.

Newest at the top.

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

<!-- pending commit -->
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
