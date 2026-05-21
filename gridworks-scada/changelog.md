# Changelog

A reverse-chronological log of WHY we made each commit. The matching git
commit holds the WHAT (the diff). Each entry's date and one-line title
should mirror the corresponding commit so the two can be cross-referenced.

Format:

```
## YYYY-MM-DD — <commit subject line>

**Why:** <the motivation — what problem, constraint, or decision drove
this change; what alternatives were considered; what this unblocks>
```

Newest at the top.

---

## 2026-05-21 — Add multi-session coordination, effort-sized findings, concerns/findings sync rule

**Why:** Three operational refinements as the effort goes parallel:

1. **Concerns vs. findings sync.** Clarified the three `research/` artifacts as
   non-redundant with one owner each (components=description, concerns=big design
   epics, findings=small/med actionable backlog). They stay in sync by *never
   copying* — only ID/tag links; a concern queries `findings.md` by
   `Concern: [[self]]` instead of hand-maintaining a list. Added a reconciliation
   checkpoint.
2. **Effort sizing + cleanup sessions.** Findings now carry an `Effort` field and
   `findings.md` is grouped into area subsections, so a daily session can grab a
   localized batch of small cleanups. `Effort: large` means it's really a concern
   (epic), not a finding. Documented a distinct cleanup-session workflow.
3. **Multi-session coordination.** Jessica runs 2–4 Claude sessions across repos
   (e.g. a gridworks-base refactor concurrently). Added `wiki/active-work.md` as
   the cross-repo claim registry + protocol (claim area, check overlap, raise
   conflicts to Jessica), referenced at the top of `wiki/primary.md`, and added a
   "claim your area first" step to the per-session protocol. Also added the
   per-domain `PROCESS.md` recommendation to `wiki/primary.md`.

## 2026-05-21 — Conform to wiki conventions; seed executor/primary.md; point CLAUDE.md at wiki

**Why:** The bootstrap diverged from the established wiki conventions (root
`wiki/primary.md` is the index + conventions hub; every domain uses
`primary.md`, not `README.md`). Reconciled: renamed the stray
`gridworks-scada/README.md` → `primary.md`; moved the wiki-wide rules I'd put in
this domain's `PROCESS.md` (agent-memory-vs-wiki routing + authoring
disciplines) up into `wiki/primary.md` so they're single-sourced for every
domain, leaving a pointer here; added `gridworks-scada` + `glossary.md` to the
root domains table.

Seeded `executor/primary.md` as an "acceptable-minimum" first pass (endorsed by
root `primary.md`), sourced from the accurate architecture summary in the repo's
`CLAUDE.md`, with unbuilt/unverified items marked Open. Then reduced the repo's
`gridworks-scada/CLAUDE.md` to a **pointer** at `executor/primary.md` plus a
trimmed dev runbook (env/commands/tests/branch/TLS stay with the code;
architecture/design moves to the wiki). This makes "CLAUDE.md points to the
wiki" the standard repo↔wiki handshake for contributors.

## 2026-05-21 — Bootstrap gridworks-scada wiki + define the cleanup process

**Why:** Starting the long-running effort to make the SCADA code something LLMs
and humans can glean from à la carte (and eventually rebuild from `executor/`).
The first deliverable is deliberately *not* documentation of the code — it is a
**process** (`PROCESS.md`) for continuously producing two separated outputs:
faithful descriptions (`research/components/`) and an opinionated bug/improvement
register (`research/findings.md`), tracked against a coverage map
(`research/map.md`).

Seeded the cross-cutting `research/concerns/` with the design intent that motivated
this work — liveness/SLA, TerminalAsset deeds + TradingRights, transport/links
(proactor limits, possible rabbit-native scada), sema legacy style, and non-GNode
interfaces (provisioning/certs/admin) — plus `research/principles.md` capturing the
foundational commitment that the party owning the LTN's financial choices holds the
SLA and the SCADA operates on behalf of the customer, not the provider.

Grounding reads this pass: scada `CLAUDE.md`, `docs/architecture-overview.md`,
`actors/contract_handler.py`, `sema/CLAUDE.md`,
`sema/docs/where-meaning-lives-in-gridworks.md`, and the `old_words/` historical
vocabulary (scada, representation-contract, g-node-instance/status, supervisor).
Did one worked component pass (`research/components/contract-handler.md`) to prove
the process out, raising findings F-001..F-007.
