# Findings — sema actions we will take

Status: Draft · Pass 0 · Updated 2026-05-26 (Pass 1 turn this session: rename landed)

What this is: a chronological log of decisions and follow-up actions
*we* (jess + Claude) will take on sema or sema-adjacent tooling, surfaced
out of research / grilling sessions. Distinct from
[`erb-no-degradation-audit.md`](erb-no-degradation-audit.md), which lists
items *ej* would have to satisfy before sema could adopt his pipeline.
This file is the action log on our side.

Entries are newest-at-top. Each entry says what, why, and when it should
land. Entries can be marked done (✅) or removed once the action is
complete; the doc itself stays as a running ledger.

---

## 2026-05-26 — Integrate the two sema CLAUDE.mds (dev-lens + effortless-lens)

**Context:** as of commit 5fc0d94 ("swap claudes"), `sema/` is set up to
carry **two** Claude-orienting documents that frame the project through
different lenses:

- **`sema/effortless_CLAUDE.md`** (committed, team-shared) — EJ's
  *ERB lens*: SSoT is `effortless-rulebook/effortless-rulebook.json`
  (hand-edited). Invariants: never edit generated
  `postgres/0[0-5]*.sql`; read from `vw_*` views, write to base tables.
  Workflow: `effortless build` sandwiched by clean-tree commits. Skill
  set: the `effortless-*` family. Path the YAML-ODXML-RULEBOOK migration
  plan steers toward.
- **`sema/CLAUDE.md`** (gitignored, personal-local) — the *vocabulary
  lens* that jess uses today: SSoT is `spec/primary.md` + per-word
  `definitions/*.yaml`. Invariants: preserve `TypeName` + `Version`,
  formats immutable, enums additive-only, no edits to historical
  versions; pass `pytest` and registry validation. Workflow:
  `/make-sema-word` for additions / modifications; regen via
  `scripts/build_indexes.sh` and `scripts/regenerate_runtime.py`.

The `.gitignore` line `CLAUDE.md` is what makes this two-lens shape work
mechanically — the committed lens lives at an explicit name, and each
developer layers their preferred lens on top at the default path without
collisions.

**Tension:** both files claim authority over sema with different SSoTs
and different rituals. They are not contradictory but they are not
unified. The migration plan referenced in the effortless lens treats
`definitions/*.yaml` (today's source-of-record for the vocabulary lens)
as eventually becoming a *downstream artifact* of the rulebook (Phase 3
cutover). Until that flip lands, **both lenses are live** and a sema
session can run under either — but not coherently under both at once.

**Action:** produce an integration doc (likely a third, neutral
`wiki/sema/research/two-claudes.md` or a top section in
`erb-md-mirror.md`) that:

1. Names the two lenses explicitly so any new sema session knows which
   it is in and how to switch (rename the gitignored file, or load the
   committed `effortless_CLAUDE.md` instead).
2. Lists the **universal invariants** that hold under both lenses (preserve
   `TypeName` + `Version`, additive enums, immutable formats, no edits to
   historical versions). These are sema-language invariants, not
   lens-specific, and should appear *once* at the top of whichever
   CLAUDE.md is active.
3. Maps the **migration phases** to which lens binds: pre-Phase-3 (YAML
   is HEAD) → vocabulary lens is authoritative for vocab edits;
   post-Phase-3 (rulebook is HEAD, YAML emitted) → effortless lens is.
   The transition point is the moment YAML stops being HEAD.
4. Reconciles the per-word ritual with the rulebook ritual:
   `/make-sema-word` today edits YAML; post-cutover the slash command
   keeps its name but its body migrates to rulebook-row edits with the
   same universal invariants. (Worth testing the prompt against both
   shapes early so the cutover doesn't surprise.)
5. Documents the .gitignore convention itself as a *protocol* (not an
   accident), so future contributors know that `sema/CLAUDE.md` is a
   personal override slot, not a missing or forgotten file.

**Why:** carrying two lenses with no relationship spelled out invites
either (a) Claude loading whichever lens happens to be at the default
`CLAUDE.md` path that day and silently ignoring the other, or (b) jess
and Claude diverging session-to-session on which discipline applies. Both
failure modes break the harmonization goal of the `ej-dev` branch.
Naming the pattern + mapping it to migration phases resolves the
ambiguity once.

**When:** before any further rulebook touches on `jm/effortless`. The
integration is a prerequisite for working coherently across both rituals.

---

## 2026-05-26 — Practice ERB pair-programming with Claude before resuming the audit

**Action:** before continuing the open audit threads (F5 TypeHelpers
alignment, F6 Templates table, p axiom-DSL feasibility, r round-trip
empirical run), spend a session or more with full effortless tooling
loaded (effortless MCP server, effortless CLI, local Postgres mirror
of ej's rulebook, a friendly Postgres GUI of jess's choice), and use
that environment to pair on small rulebook touches with Claude. The
goal is to *internalize how ej used Claude to build a 28K-line rulebook
in days* — the action loop, the kind of prompts ej drove with, the way
the structured action-space (calc-fields, OpKind enums, FK columns)
turns LLM output into something that lands first try.

**Why:** jess does not yet have a firsthand feel for the ej + Claude
workflow that produced the existing rulebook so rapidly. The audit
and synergy thesis both implicitly assume that workflow is real and
reproducible. Until jess has independently experienced it, she can't
properly evaluate the strong CMCC thesis or judge whether ej's
pipeline is something she'd want to drive herself (vs. consume).
Doing the audit first without that experience risks reasoning about
ergonomics jess hasn't actually felt. Doing the practice first builds
the calibration needed to interpret the audit findings correctly.

**When this lands:** the next session, per
[[queued-next-session-effortless-setup]]. After enough practice that
jess can confidently describe what the ej + Claude rapid-rulebook loop
*feels* like, return to the audit threads.

---

## 2026-05-26 — Drop `PromotedAt` from any sema-side ERB modeling

**Action:** when sema-side ERB schemas are touched (either by us
proposing a change to ej or by us owning the schema directly), remove
the `TypeVersions.PromotedAt` column.

**Why:** per `spec/registry/structure.md:100-103`, sema's `created`
field IS the publication timestamp once a version is promoted from
draft to published ("when a draft definition is promoted to active,
`created` SHALL be updated to the activation or publication
timestamp"). For any row where `Status='published'`, `PromotedAt` and
`Created` carry the same value. Two fields with the same meaning
invite confusion ("which timestamp do I trust?") with no information
gain. The draft-creation moment is deliberately discarded by sema's
convention — consistent with immutability — and we don't have a use
case for preserving it.

The only case for retaining `PromotedAt` would be a sema-spec change
to preserve draft-creation history. Separate design question; no
motivating use case today.

**When this lands:** either at the next ERB↔sema integration touch
point we participate in, or as part of any future sema-side ERB
ownership transfer.
