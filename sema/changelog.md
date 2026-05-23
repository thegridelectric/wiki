# Changelog

A reverse-chronological log of WHY we made each commit. The matching git
commit (in the `sema` repo) holds the WHAT (the diff). Each entry's date and
one-line title should mirror the corresponding commit so the two can be
cross-referenced.

Newest at the top.

---

## 2026-05-23 — Dissolve sema/docs/: relocate context to wiki, merge motivation into README (<!-- pending commit -->)

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
