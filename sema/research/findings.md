# Findings — sema actions we will take

Status: Draft · Pass 0 · Updated 2026-05-26

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
