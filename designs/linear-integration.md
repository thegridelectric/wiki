# Linear integration

Status: Accepted · Pass 2 · Updated 2026-06-22 · Linear: OPS-381

> What this is: the **remaining setup/cleanup work** to integrate Linear with
> the wiki. The durable "how it works" reference now lives in
> [`../linear.md`](../linear.md) — this file is only the checklist, and gets
> **deleted** once the checklist is clear (see Retirement).

## Done

- [x] Wire `precheck-design-bijection.sh` + `precheck-cap-8.sh` into
  `.claude/settings.json` — *2026-06-08*.
- [x] Create the `design` + `nit` labels in Ops — *2026-06-07*.
- [x] Normalize the worst house/domain Ops labels (`Maple→maple`,
  `sieg→process-control`, `automate→ops-automate`, `CI-CD→ci-cd`, and the
  `forensics`/`scada-control`/`field-support` merges) — *2026-06-07*.
- [x] Migrate the decisions + how-it-works into [`../linear.md`](../linear.md)
  — *2026-06-08*.

## To do

- [ ] **Triage my untriaged issues** — the cleanup worklist. The triage
  invariant: every issue of mine is *closed* (Done/Cancelled/Duplicate) or, if
  open, carries **at least one** of {`design`, `parked`, `nit`} (`nit` =
  sub-threshold cleanup not worth a design; an active nit is fine left as-is).
  The rows below are the live discrepancies: my open issues with **none** of
  those labels, surfaced by `tools/linear-snapshot.sh`'s invariant check
  (snapshot **2026-06-23**). Each needs a decision — promote to a `design`, tag
  `parked`, mark a `nit`, or close. Fill the **Decision** column as we go; an
  issue leaves this list once it carries a label (re-run the script to refresh).

  | Issue | Status | Priority | Title | Decision |
  | --- | --- | --- | --- | --- |
  | OPS-393 | Todo | High | Post-mortem: maple HP on during on-peak while in Standby (2026-06-09) |  |
- [x] **Write the issue-snapshot script** (token-cheap sync) —
  [`tools/linear-snapshot.sh`](../tools/linear-snapshot.sh), *2026-06-22*.
  Pulls open Ops issues (state type ≠ completed/canceled, paginated) via the
  Linear GraphQL API (`LINEAR_API_KEY`) and writes a compact, gitignored CSV
  `wiki/.linear-snapshot.csv` (`id,title,state,priority,labels,started_age_d,
  updated_age_d,design`) so a session greps one small file instead of paying
  for MCP JSON. The table above then stops being hand-maintained: the script
  refreshes the facts; sessions only add judgment. **Needs `LINEAR_API_KEY`**
  (the MCP is Claude-facing, not shell-callable) — same dependency as the live
  hook checks below; refuses with guidance when unset.
- [x] **Wire `LINEAR_API_KEY`** — *2026-06-22*. Stored as plaintext in
  `.claude/settings.local.json` `env` (project-local, not committed — the
  umbrella isn't a git repo), injected into the session + hook environment on
  start. Verified live: `linear-snapshot.sh` pulls 113 open issues,
  `precheck-cap-8.sh` reports the real started count (2/8), and
  `precheck-design-bijection.sh` runs its Linear-side mismatch sweep. The
  hooks' wiki-side / honor-system fallbacks remain for any environment without
  the key.
- [x] **Fix `precheck-design-bijection.sh` stamp parsing** — *2026-06-22*.
  Added a `stamp_line` helper mirroring `tests/test_doc_health.py::_stamp_line`
  (strips a leading `>`/space/tab run, then matches `Status:`) and routed the
  Accepted/Verified-needs-an-id check through it, so a blockquoted/indented
  stamp is found instead of silently skipped. The id check stays scoped to that
  Status line (`Linear: (OPS|GRI)-NNN`). Verified end-to-end: a blockquoted
  Accepted stamp with no id is now flagged; the `_stamp_line`/`_slugify`/
  `accepted-designs-have-linear-id` pytest cases stay green.

## Retirement

When the **To do** list is empty: confirm [`../linear.md`](../linear.md) holds
everything durable, **delete this file**, and move OPS-381 to Done. (Per the
designs convention, a shipped design is deleted; its distillate already lives
in the reference doc.)
