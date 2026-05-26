# ERB no-degradation audit (for YAML-leading granular bidirectional)

Status: Draft · Pass 0 · Updated 2026-05-24

What this is: a checklist of every operation sema supports today,
classified for whether it would be **preserved without loss** under
the working synergy thesis — *ej's ERB as a granular bidirectional
mirror, YAML-leading, no degradation*. The intent is to surface the
concrete acceptance criteria ej's pipeline would have to clear
before sema could adopt it without giving anything up.

Companion to [`erb-md-mirror.md`](erb-md-mirror.md) (proposed tooling
for reasoning *about* the rulebook schema) and the working interpretation
of "ERB IS an LLM" memorized at `~/.claude/projects/.../memory/erb-is-an-llm-interpretation.md`.

## The bar

**(ii) — YAML-leading, granular bidirectional, no degradation.**

- Sema YAML under `definitions/` remains the canonical source of truth.
- Every YAML edit projects to ERB rows via a granular emitter (per-word
  add / edit / delete, not full rebuild). Round-trip CI gate enforces
  parity.
- ERB MAY hold strictly more than YAML (lifecycle fields, DAG calc-fields,
  admin UI metadata). Round-trip is asymmetric: every YAML word must
  appear in ERB; ERB-extra fields need not appear in YAML.
- Every operation sema supports today either:
  - **continues unchanged** (operates on YAML, ERB irrelevant), or
  - **continues with ERB providing an equivalent or strictly-better
    path** (e.g., dependency-closure via calc-field DAG), or
  - is explicitly **retired with no loss of capability** (because ERB
    subsumes it).

If any operation can ONLY be supported by losing a capability, that's
the degradation that disqualifies (ii).

## Operation catalog

Read row-by-row: each is an operation sema does today; the right
column says where it lands under (ii).

### A — Authoring & ritual

| Operation | Status under (ii) | Notes |
|---|---|---|
| Edit YAML word file (`definitions/{formats,enums,types}/<word>/<NNN>.yaml`) | **Preserved** | YAML is authoritative. |
| Edit `definitions/registry.yaml` (master word list) | **Preserved, with caveat** | Granular emitter must handle deletions, not just additions. Today's `yaml_to_rulebook.py` is a full rebuild — granular delete-aware emit is not yet implemented. |
| Edit `definitions/owners.yaml` | **Preserved** | Mirrored as the `Owners` table; round-trips cleanly. |
| `/make-sema-word` slash command (per-word ritual) | **Preserved** | Operates on YAML; no change. |

### B — Index generation (today via `scripts/build_indexes.sh`)

| Operation | Today | Under (ii) | Verdict |
|---|---|---|---|
| `build_public_registry.py` → `indexes/public_registry.yaml` | Filesystem walk + YAML emit. | ERB has `Owners` + `Types` + `TypeVersions` tables; equivalent live query. Indexes can stay (regen from YAML pre-ERB) OR retire (consumers move to ERB queries). | **Preserved (redundant capability)** — kept or retired by choice. |
| `build_dependency_closure.py` → `indexes/dependency_closure.yaml` | Static computation over YAML refs. | ERB's `TypeVersions.IsDependencyClosed` + `RefIsResolvable` + `UnresolvedRefCount` calc-fields compute this live and per-version. | **Preserved + strictly better** in ERB. |
| `build_lookup.py` → `indexes/lookup.yaml` | Aggregate index for runtime/test fixtures. | ERB query covers it. | **Preserved (redundant)**. |
| `build_reverse_dependencies.py` → `indexes/reverse_dependencies.yaml` | Static reverse-dep computation. | ERB's `TypeAttributeUsageCount` / `IsUsed` / `IsUnused` calc-fields. | **Preserved + strictly better**. |
| `build_versions.py` → `indexes/versions.yaml` | Per-word version listings. | ERB has `Types.VersionCount` / `LatestVersion`-style aggregations. | **Preserved (redundant)**. |

**Net:** the `indexes/` directory is structurally subsumed by ERB calc-fields. They can continue to be regenerated from YAML for consumer compatibility, but the *capability* they provide moves into ERB. No degradation.

### C — Seed / DAG analysis CLIs

| Operation | Status | Notes |
|---|---|---|
| `build_seed_dag.py` (CLI) | **Preserved** | Reads YAML; pre-ERB; unaffected. |
| `build_seed_expanded.py` (CLI) | **Preserved** | Same. |
| `build_seed_definitions.py` (CLI) | **Preserved** | Same. |

### D — Runtime code generation (`scripts/regenerate_runtime.py`)

| Operation | Status under (ii) | Notes |
|---|---|---|
| `runtime_generation/types.py` (675 lines) — Python classes from type YAMLs | **Preserved** | Reads YAML; emits Python. ERB-independent. |
| `runtime_generation/enums.py` | **Preserved** | Same. |
| `runtime_generation/formats.py` | **Preserved** | Same. |
| `runtime_generation/helpers.py` — TypeHelpers (auto-promoted inline objects) | **Preserved, with verification needed** | ej's `TypeHelpers` table (4 rows currently) implements the same auto-promotion concept. Must verify sema's existing rule and ej's rule are identical or aligned. Quiet divergence is the risk. |
| `runtime_generation/scaffold_axiom_template.py` — `def check_axiom_N(self): raise NotImplementedError()` stubs | **Preserved**, but ERB's `Templates` table currently has 0 rows | If ej's intent is for the rulebook to track template presence/status, someone must populate `Templates`. Either sema's scaffold writes to it via a new path, or ej's tool filesystem-scans `templates/axioms/*.py.jinja2` and populates. Story needs to be specified. **Not a blocker for (ii); is an integration loose end.** |
| `runtime_generation/scaffold_upgrade_template.py` — upgrade stub `def upgrade(self): raise NotImplementedError()` | **Preserved**, but see Finding F2 below | Sema's upgrades are NOT in YAML — they live as hand-written Python at `src/sema/runtime/{types,enums}/old_versions/*.py`. This is a **second source-of-truth surface** on the sema side that (ii)'s "YAML-leading" framing does not cover. |

### E — Test suite (47 tests)

| Category | Count | Status under (ii) |
|---|---|---|
| registry/ | 13 | **Preserved** — all operate on YAML / schemas. |
| runtime/ | 30 | **Preserved** — operate on regenerated Python. Includes axiom-template, upgrade-template, and logic-vs-template consistency tests. |
| indexes/ | 1 | **Preserved** — index format checks. |
| top-level | 3 | **Preserved** — seed-build and snapshot CLI tests. |
| **NEW required test** | — | **`yaml_round_trip_check.py` MUST be wired into CI as a hard gate.** ej's checker exists at `rulebook-emitters/yaml/yaml_round_trip_check.py`; today it's a CLI script, not a pytest. Promoting it to a tested gate is non-negotiable for (ii). |

### F — External consumption / publishing

| Operation | Status under (ii) |
|---|---|
| Downstream consumers (`gjk`, gwproto, others) `pip install` the regenerated runtime module | **Preserved** — runtime is regenerated from YAML, unchanged. |
| Publishing to `https://schemas.electricity.works/...` (immutability gate) | **Preserved** — publication is a YAML/JSON-Schema upload, ERB-independent. |
| Publication-status lifecycle (draft → published, immutable post-publish) | **At risk** — see Finding F3. |

## Findings — specific degradation risks

### F1. Granular bidirectional is NOT yet implemented

`rulebook-emitters/yaml/yaml_to_rulebook.py` is a **full-rebuild** emitter
(walks the entire `definitions/` tree and reconstructs all rows). There
is no per-word add/edit/delete diff applicator. The
[`erb-md-mirror.md`](erb-md-mirror.md) sibling note assumes granular emit;
so does the user's stated thesis ("granular bidirectional with no
degradation"). This is a planned future, not current code.

**Why this matters for (ii):** under full-rebuild emit, every YAML
edit rebuilds the entire rulebook, which (a) defeats per-row
provenance / lifecycle continuity in ERB (every row gets a new
`Created` timestamp), and (b) makes the operation O(corpus) for
every single-word change.

**Required for (ii):** implement granular per-word add/edit/delete
emit. Out-of-scope today; tracked as Module 2 in ej's branch.

### F2. Upgrades are a second source of truth NOT in YAML

Sema's upgrade transformations live as hand-written Python at
`src/sema/runtime/{types,enums}/old_versions/*.py`. The rulebook's
`yaml_to_rulebook.py` docstring is explicit: "Module 2 tables
(Projections / *Upgrades / *UpgradeMappings) ... Phase 1.5
(python-upgrades-to-rulebook) populates those from
src/sema/runtime/.../old_versions/*.py."

So the (ii) phrasing **"YAML-leading"** is incomplete — the actual
leading-edge surface is **YAML + Python upgrade modules**. Either:

- the audit clarifies the bar as "YAML-and-Python-leading," or
- upgrades migrate into YAML declarations (substantial refactor — the
  current `OpKind=Custom` rows with `RawScript` Python strings would
  have to live somewhere YAML-shaped), or
- ej's pipeline accepts that some sema-side rows come from the Python
  modules and that the round-trip on those is Python ↔ rulebook, not
  YAML ↔ rulebook.

**Required for (ii):** an explicit policy on where the upgrade
source-of-truth lives. Currently ambiguous in both sema docs and ej's branch.

### F3. Lifecycle / publication-status — dissolved (was: two competing models)

Initial reading of this audit treated Status as an ERB-side addition
not present in sema. **That was wrong** (caught by jess on review).
Sema has had explicit draft/active lifecycle from the start:

- `spec/primary.md` glossary defines `draft` vs `active`.
- `spec/registry/types.md` line 68: `status: "active" | "draft"   # optional; default active`.
- `spec/registry/structure.md` documents the full lifecycle (drafts
  mutable, active published-and-immutable, drafts excluded from
  `latest_version`, draft schema URLs use the parallel
  `https://schemas.electricity.works/draft/{formats,enums,types}/...`
  prefix per the draft-publication rules).
- `definitions/registry.yaml` carries explicit `status: "draft"` on
  multiple entries; absence means active.

ej's ERB already picks this up correctly: `TypeVersions.Status` is
populated from the YAML `status:` field at ingest, and the calc-fields
(`IsPublished`, `IsDraft`, `IsPromotable`) are pure derivations over
that single YAML-sourced field. **No competing source of truth; YAML
remains authoritative; ERB adds derived lifecycle gates on top.**

**Small residual:** ej's `PromotedAt` column duplicates what sema's
`created` already carries for published versions (per
`spec/registry/structure.md:100-103`, `created` is overwritten to the
publication moment on promotion). We've recorded the action to drop it
in our findings log → see [`findings.md`](findings.md). Not a (ii)
blocker.

### F4. Coverage gap — unfinished migration

Source today: 71 type-names / 16 formats / ~48 enums.
Rulebook (ej-dev): 69 Types / 14 Formats / 41 Enums.

Per user, the gap is **unfinished migration**, not intentional
exclusion. The round-trip check would fail on the missing words until
ingest is complete.

**Required for (ii):** close the migration gap and turn `yaml_round_trip_check.py` green.

### F5. TypeHelpers — verify rule alignment

Both sema (`runtime_generation/helpers.py`, 332 lines) and ej's ERB
(`TypeHelpers` table, 4 rows) implement "auto-promote inline-nested
object to a helper class." If the auto-promotion rule diverges
(different naming heuristic, different trigger condition, different
attribute extraction), the YAML ↔ ERB round-trip will produce
spurious helpers on one side and not the other.

**Required for (ii):** audit the two implementations against each
other and document the canonical rule.

### F6. Templates table empty — integration loose end

ej's `Templates` table is schema-complete (Kind ∈ {axiom, upgrade},
Status ∈ {present, missing, deprecated}, FKs to TypeVersion /
EnumVersion) but has **0 rows**. sema's existing `scaffold_axiom_template`
and `scaffold_upgrade_template` write to the filesystem and do not
report to any registry.

**Required for (ii):** decide who populates `Templates` and when. Either:

- sema's scaffold writes a row whenever it creates a template,
- ej's tool filesystem-scans templates and populates rows on each emit,
- the table is documented as "planned but not active in current phase"
  and removed from the rulebook until needed.

Choosing the first or second is non-blocking but should be specified.

### F7. Axioms and JSON-Schema combinators round-trip as opaque blobs

Documented behavior (not a defect, but worth naming explicitly): ERB
captures axiom `Statement` as natural-language text and parks
unmodeled JSON-Schema (`oneOf`, `if/then`, conditionals) in
`RawJson` columns. The ERB DAG cannot reason about these; they are
preserved but not queryable.

**Implication:** the "ERB makes sema queryable as a DAG" claim is
true *over the structurally-modeled subset only*. The expressively-rich
tail (axioms-as-logic, combinator-driven types) remains text-of-record.

**Not a degradation for (ii)** — the YAML had this content already and
ERB faithfully round-trips it. It IS a degradation for any thesis that
claims "ERB makes sema's semantics machine-checkable." That's a
stronger claim than (ii).

## Acceptance criteria — the checklist for (ii)

Numbered for ease of reference. Each is a thing ej's pipeline must
demonstrate before sema can adopt without giving up capability.

1. **Granular per-word emit (add / edit / delete)** wired through
   `yaml_to_rulebook.py`. Per-row `Created` timestamps preserved
   across emits. **(blocks F1)**
2. **Round-trip CI gate green on the full sema corpus** —
   `yaml_round_trip_check.py` reports zero diffs across all formats,
   enums, types. **(blocks F4)**
3. **Round-trip checker promoted to pytest** (or equivalent), wired
   into CI of both the sema repo and the rulebook. Failures block
   merge.
4. **Upgrade source-of-truth policy specified** — YAML, Python
   modules, or a documented split. **(blocks F2)**
5. *(retired — F3 dissolved on review.)* If `PromotedAt` is meant to
   carry information beyond `IsPublished`, specify where the
   promotion-time value comes from (git history inference or new YAML
   field). Minor.
6. **TypeHelper auto-promotion rule canonicalized** across sema
   and ej's rulebook; documented in `spec/`. **(blocks F5)**
7. **Templates-table population story specified** — who writes,
   when, who reads. **(blocks F6)**
8. **No-degradation declaration for the 7 operation categories
   above** — written into the sema spec (or `wiki/sema/`) as the
   adoption contract.

Optional but strongly recommended:

9. **MD ↔ ERB schema mirror tooling** ([`erb-md-mirror.md`](erb-md-mirror.md))
   so the rulebook is reviewable / refactorable from a wiki-style
   hub-and-spoke surface without paying the 28K-line catastrophic
   file-size cost in Claude context.
10. **Audit of axiom expressiveness** — empirical classification of
    current sema axioms into ERB-structured-coverable vs `RawScript`
    tail, to size the multi-language-emission opportunity. Companion
    audit; was Q-grill item (p).

## Open questions for ej

These are the questions whose answers gate the audit:

- Is granular emit on his roadmap, and when? (#1)
- Does he intend to read Python upgrade modules as a source-of-truth
  surface, or to migrate upgrades into YAML? (#4)
- What's the canonical rule he applies for inline-object → TypeHelper
  promotion? (#6)
- Is `Templates` an aspirational scaffold or actively maintained? (#7)
- Would he accept the MD ↔ rulebook mirror as a contribution to
  `rulebook-emitters/markdown/`, or prefer it as a sema-side tool? (#9)

## Status / next step

This audit is the deliverable for `/grill-me` thread item (q). It is a
specification of what "no degradation" means concretely; it does not
itself commit to adoption. The decision to adopt would also require
items (p) — axiom DSL feasibility — and (r) — empirical round-trip
status — both of which are smaller-scoped sub-investigations enabled by
this catalog.
