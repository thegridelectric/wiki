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
