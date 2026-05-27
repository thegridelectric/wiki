# Design: rename Words→Types and drop Vocabulary framing in EJ's web app

Status: Draft · Pass 0 · Updated 2026-05-26

> A single, contained refactor of the sema dashboard at `sema/app/web/` +
> the hand-written API DTOs at `sema/app/api/models.py`. The rulebook and
> generated SQL **do not change**. Scope is two concrete fixes:
> (1) rename "Word" to "Type" everywhere it actually means type,
> (2) tear out the "Vocabulary" framing entirely (deferred — see
> [`research/concerns/dashboard-vocabulary-modeling.md`](../research/concerns/dashboard-vocabulary-modeling.md)
> for the deeper modeling question).

## TL;DR

- **The "word" terminology is a presentation-layer artifact.** The
  rulebook + Postgres use clean names (`types`, `type_versions`,
  `from_type_version`, `to_type_version`). The drift starts in
  `sema/app/api/models.py` (hand-written Pydantic DTOs translate clean
  DB rows into `from_word` / `to_word` / `is_cross_word` /
  `word_is_retired`) and propagates to the React app via the generated
  OpenAPI schema.
- **"Word" in sema's own vocabulary** is the **umbrella** for
  {type, enum, format} — see the `/make-sema-word` slash command and the
  dev-lens CLAUDE.md. EJ's app collapses "word" to just "type", which is
  inconsistent with sema's own usage.
- **"Vocabulary" in EJ's app** = "the words an owner created." This
  conflates authorship with use. The modeling fix is a separate concern
  (vocabulary should be application-scoped, every snapshot IS a
  vocabulary, semantic tagging cross-cuts owners). This design only
  *removes* the Vocabulary framing from the dashboard; it does **not**
  introduce a new one. Reintroducing vocabulary as a first-class concept
  is deferred to the concern.
- **~12 files touched** in `sema/app/` (excluding the regenerated
  `schema.d.ts`). All in `sema/`, ej-dev branch. No rulebook edit, no
  SQL regen, no `effortless build` required.

## Prerequisites

- **Decide whether to publish the dashboard.** The rename only matters
  if the dashboard is consumed by humans who don't already share the
  team's mental model (gridworks-scada devs, external sema consumers,
  onboarders, docs sites). If the dashboard stays internal forever,
  this design is dead weight — Postico + the rulebook JSON cover
  every internal use. Decision criterion captured in TL;DR; before
  starting work, confirm "yes, publish."

If the answer is "no, internal only": this design is canceled and the
durable distillate is just the concern file plus the finding that the
modeling is wrong (held for the next consumer-facing surface).

## Method

Bottom-up — let the wire format lead so TypeScript errors guide the
frontend pass.

### Step 1 — API DTOs (`sema/app/api/models.py`)

Rename Pydantic fields:

- `from_word` → `from_type`
- `to_word` → `to_type`
- `is_cross_word` → `is_cross_type`
- `word_is_retired` → `type_is_retired`
- `ref_enum_word_is_retired` → `ref_enum_type_is_retired`
- `ref_subtype_word_is_retired` → `ref_subtype_type_is_retired`
- `origin_word_is_retired` → `origin_type_is_retired`

### Step 2 — API routes (`sema/app/api/routes/*.py`)

Find and update:

- Path params: `/api/type-upgrades/{word}/...` → `/api/type-upgrades/{type}/...`
  and similarly for enum-upgrades.
- Any handler-internal references to the renamed DTO fields.

(Survey needed before edit: `grep -rn 'from_word\|to_word\|word_is_retired\|{word}' app/api/`.)

### Step 3 — Regenerate `sema/app/web/src/api/schema.d.ts`

Whichever regen mechanism the repo uses (likely `npm run gen` in
`app/web/` against `/openapi.json`). Confirm before running.

### Step 4 — Frontend renames (`sema/app/web/src/`)

#### Routes (`router.tsx`)

| Old | New |
|---|---|
| `v/:owner/words` | `:owner/types` |
| `v/:owner/enums` | `:owner/enums` |
| `v/:owner/formats` | `:owner/formats` |
| `v/:owner` | `:owner` |
| `w/:typeName` | `types/:typeName` |
| `w/:typeName/v/:version` | `types/:typeName/v/:version` |
| `w/:typeName/v/:version/edit` | `types/:typeName/v/:version/edit` |
| `w/:typeName/v/:version/diff/:other` | `types/:typeName/v/:version/diff/:other` |
| `w/:typeName/fork-from/:version` | `types/:typeName/fork-from/:version` |
| `type-upgrades/:word/...` | `type-upgrades/:type/...` |
| `enum-upgrades/:word/...` | `enum-upgrades/:type/...` |

Drop the duplicate `owners/:owner` → `OwnerView` route alongside
`:owner` (pick one).

#### Component renames

- `WordView` → `TypeView`, `routes/Word.tsx` → `routes/Type.tsx`
- `VocabWordsView` → `TypesView`, `VocabEnumsView` → `EnumsView`,
  `VocabFormatsView` → `FormatsView`
- `routes/VocabularyTabs.tsx` → `routes/OwnerTabs.tsx`. Inside:
  `VocabSidebar` → `OwnerSidebar`, drop the `<h2>Vocabulary</h2>`
  header (or replace with `<h2>{owner}</h2>`), retire the "All Word
  Types published by this Vocabulary" / "Versioned controlled
  vocabularies" subtitles in favor of plain descriptions.

#### Labels & UI strings

- `Owner.tsx`: `<h2>Vocabulary</h2>` → `<h2>{owner}</h2>` (or drop);
  `Words ({type_count})` → `Types ({type_count})`; table header `<th>Words</th>`
  → `<th>Types</th>`.
- `Word.tsx` body: "Word" → "Type"; "This Word has no Definitions" →
  "This Type has no Definitions"; "Vocabulary: <link>" → "Owner:
  <link>"; inline `vocab <Link>...</Link>` → `owner <Link>...</Link>`.
- `Workbench.tsx`: `<h2>Vocabularies</h2>` → `<h2>Owners</h2>`; table
  `<th>Vocab</th>` → `<th>Owner</th>`.
- `ThreePaneShell.tsx`: `<h2>Vocabularies</h2>` + `id="vocab-nav"` →
  `<h2>Owners</h2>` + `id="owner-nav"`.
- `AdminShell.tsx` comment: "vocab nav" → "owner nav".
- `styles.css`: `.word-summary` → `.type-summary`; `.word-summary-name` →
  `.type-summary-name`. Leave the two `word-break` CSS-property rules
  alone — unrelated.

#### Variable / property renames in TS

- `Word.tsx`'s `const word = useAsync(...)` → `const type = useAsync(...)`
  (TS keyword `type` is fine as a local binding); all `word.data.*` →
  `type.data.*`.
- `Upgrades.tsx`'s `const { word, fromVersion, toVersion } = useParams()`
  → `const { type, fromVersion, toVersion } = useParams()`; all
  `from_word` / `to_word` / `is_cross_word` reads → renamed per DTO step.
- Other route files: incoming `Link to={\`/w/${typeName}\`}` →
  `Link to={\`/types/${typeName}\`}`; reads of `word_is_retired` →
  `type_is_retired`; `ref_enum_word_is_retired` →
  `ref_enum_type_is_retired`; etc.

### Step 5 — Restart, smoke-test

- `./start.sh` (kills 8765 + 8766, restarts API + Vite).
- Navigate the app:
  - `/<owner>` loads with "Types ({count})" link.
  - `/<owner>/types` shows the type list (no "Vocabulary" framing).
  - `/types/<name>` opens type detail.
  - Type-upgrade chains render.
  - No console errors / broken links.

## Out of scope

- The rulebook (untouched).
- Reintroducing Vocabulary as a first-class concept (deferred to
  [`research/concerns/dashboard-vocabulary-modeling.md`](../research/concerns/dashboard-vocabulary-modeling.md)).
- Any backend logic changes other than DTO field renames + path param
  renames.

## Alternatives considered

- **Rename in the frontend only**, leave the API "word" terms.
  Rejected: leaves the wire format misleading; future API consumers
  (other dashboards, external clients, Claude reading OpenAPI) inherit
  the bug. The whole point of the design is removing the misnaming.
- **Rulebook-level rename** (e.g., rename rulebook fields to use
  "type" everywhere). Unnecessary — the rulebook already uses "type"
  correctly. The drift is purely in the API DTOs.

## Open

- **Publish decision.** Pending.
- **`/v/` prefix.** Proposed dropping entirely (cleaner). Acceptable
  alternative is keeping the `/v/` prefix and just renaming the inner
  segments — less diff churn, slightly weirder URLs.
- **File rename `VocabularyTabs.tsx` → `OwnerTabs.tsx`.** Proposed,
  but a string-only rename inside the existing filename also works.
  Minor diff-churn tradeoff.

## Sequencing

Wait for the publish decision. If "publish": run as one cluster
(`bulk-on` already active in the session that does this). One commit,
one changelog entry on `wiki/sema/changelog.md`. The diff is contained
to `sema/app/`.
