# Linear integration

Status: Accepted · Pass 2 · Updated 2026-06-10 · Linear: OPS-381

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

- [ ] **Triage the existing Ops issues** — the in-flight pass through the
  backlog: reuse/normalize tags, set states, fix assignees, close stale items.
  Open issues assigned to me (snapshot **2026-06-10**, after the organize-pass;
  `✓` = dealt with / exec-summarized / parked deliberately; `D` =
  `design`-tagged). Unmarked rows are the **less-important / ops residue** —
  parked here on purpose per the 2026-06-10 triage:

  | ✓ | Issue | Status | D | Title / triage note |
  | --- | --- | --- | --- | --- |
  | x | OPS-27 | Backlog | D | Circulator pump 0-10V models |
  | x | OPS-40 | Backlog | D | Simulated test environment |
  | x | OPS-47 | Backlog | D | BTU meter integration |
  | x | OPS-59 | Backlog | | i2c-dfr exception hardening (good code-read notes in issue) |
  | x | OPS-118 | Backlog | | Shorten SCADA CI time |
  | x | OPS-141 | Todo | | Tracing missing oak data |
  | x | OPS-150 | Todo | | Fix spurious no-data alerts |
  | x | OPS-172 | Backlog | | Cold garages / freeze backstop (decision item) |
  | | OPS-213 | Todo | | beech2 store-and-forward check (forensics, low) |
  | | OPS-215 | Todo | | Oil-boiler responsiveness diagnostic — **important, but next heating-season prep**; revisit at fall planning |
  | x | OPS-219 | Todo | | Nolan House control → folded into **spruce-unlimbo OPS-392** (Chunks A+D); exec summary in issue |
  | | OPS-223 | Todo | | SWT derivations — pairs with the facts-vs-calcs remainder of OPS-238 |
  | | OPS-224 | Todo | | Fix `is_buffer_charge_limited` (House0 sensor-absence bug) |
  | | OPS-225 | Todo | | H0CN → ChannelSpec refactor |
  | x | OPS-230 | Todo | | Spruce starter script → interim retired by OPS-392; Take2/3 only if merge slips vs July-15 |
  | x | OPS-238 | Todo | | ActorBase/ASL codec — 2/3 shipped (gwbase 0.5.x, OPS-386); extract facts-vs-calcs principle, then **close** |
  | | OPS-248 | Todo | | Maple became-a-different-system note (low) |
  | | OPS-257 | Todo | | GW admin: layout-version tolerance |
  | | OPS-265 | Todo | | MCU choice re-evaluation (Wiznet Pico vs Pico2) |
  | | OPS-270 | Todo | | SCADA Template 7 (py3.12 SD card) |
  | x | OPS-281 | Todo | | LBL observatory db — checklist nearly complete |
  | x | OPS-282 | Todo | | LBL intro session — description filled; gated on OPS-283 |
  | | OPS-283 | Todo | | S3 → observatory pipeline — the real LBL gate (outside-world lane) |
  | x | OPS-313 | Todo | | pico improvements — moved off In Progress 2026-06-10 |
  | x | OPS-324 | Backlog | | sema axioms thread — parked until post-MarketMaker-skeleton; exec summary in issue |
  | x | OPS-334 | Todo | | `gw.nolan.layout` → Chunk B of **OPS-392**; exec summary in issue |
  | | OPS-358 | Backlog | | zoneX heatcall derived channel — adjacent to OPS-392 Chunk C; fold or sequence there |
  | | OPS-367 | Backlog | | RabbitMQ security — overlaps rmqbot designs `prod-tls-fix` + `prod-4x-upgrade`; reconcile/dedupe |
  | | OPS-368 | Todo | | SystemMode in visualizer (nice-to-have) |
  | x | OPS-380 | **Done** | D | Snapshot improvement — merged 2026-06-09 |
  | x | OPS-381 | In Progress | D | Linear integration *(this design)* |
  | x | OPS-384 | Backlog | D | publish-backpressure |
  | x | OPS-386 | Backlog | D | integrate-gwbase-sema-updates |
  | x | OPS-387 | In Progress | D | ltn-sends-gw-wrapped |
  | x | OPS-389 | Todo | | Publish gwbase 0.5.x to PyPI (fresh, crisp, High) |
  | x | OPS-390 | Todo | | scada pytest pythonpath (nit) |
  | x | OPS-391 | Backlog | D | substrate-fit (parked brainstorm; focus AFTER the launch) |
  | x | OPS-392 | Backlog | D | **spruce-unlimbo** — anchor for 219/230/334; July-15 AC driver |
- [ ] **Write the issue-snapshot script** (token-cheap sync): a tiny script
  (e.g. `tools/linear-snapshot.sh`) that pulls open Ops issues via the Linear
  GraphQL API (`LINEAR_API_KEY`) and writes a compact, gitignored CSV
  (id, title, state, priority, labels, started/updated ages, design-link) —
  e.g. `wiki/.linear-snapshot.csv` — so a Claude session greps one small file
  instead of paying for MCP JSON. The table above then stops being
  hand-maintained: the script refreshes the facts; sessions only add judgment.
- [ ] *(optional, decide later)* **Wire `LINEAR_API_KEY`** so the hooks' live Linear-side
  checks run instead of the wiki-side / honor-system fallback (see
  [`../linear.md`](../linear.md) "Enforcement").
- [ ] **Fix `precheck-design-bijection.sh` stamp parsing** — it locates the
  stamp with `grep '^Status:'`, so it silently skips a design whose stamp is
  blockquoted/indented (e.g. `> Status:`) and misses the Accepted-missing-id
  check that `tests/test_doc_health.py` catches. Detect maturity with the
  test's lenient `STAMP_RE`; keep the bare-`Status:` rule for the id.

## Retirement

When the **To do** list is empty: confirm [`../linear.md`](../linear.md) holds
everything durable, **delete this file**, and move OPS-381 to Done. (Per the
designs convention, a shipped design is deleted; its distillate already lives
in the reference doc.)
