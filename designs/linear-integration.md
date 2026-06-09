# Linear integration

Status: Accepted · Pass 2 · Updated 2026-06-08 · Linear: OPS-381

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
  Open issues assigned to me (snapshot 2026-06-08; `✓` = dealt with /
  in sync with the linear-integration model; `D` = `design`-tagged):

  | ✓ | Issue | Status | D | Title |
  | --- | --- | --- | --- | --- |
  | x | OPS-27 | Backlog | D | Circulator pump 0-10V models |
  | x | OPS-40 | Backlog | D | Simulated test environment |
  | x | OPS-47 | Backlog | D | BTU meter integration |
  | x | OPS-59 | Backlog | | Improve exception catching for i2c bus failure in dfr |
  | x | OPS-118 | Backlog | | Shorten SCADA CI time |
  | x | OPS-141 | Todo | | Tracing missing oak data |
  | x | OPS-150 | Todo | | Fix spurious no-data alerts |
  | x | OPS-172 | Backlog | | What do we do about cold garages to keep them from freezing |
  | | OPS-213 | Todo | | Check how/if beech2 got its data upstream after it could message beech again |
  | | OPS-215 | Todo | | Procedural diagnostic for non-electric backup (oil boiler) responsiveness |
  | | OPS-219 | In Progress | | Nolan House control in scada |
  | | OPS-223 | Todo | | Clarify and expose SCADA's required SWT derivations |
  | | OPS-224 | Todo | | Fix is_buffer_charge_limited |
  | | OPS-225 | Todo | | Turn H0CN into ChannelSpec objects |
  | | OPS-230 | Todo | | Create starter script to get Spruce running |
  | | OPS-238 | Todo | | Update ActorBase and ASL codec for database code |
  | | OPS-248 | Todo | | When did maple "become a different system"? Add note to persistent store |
  | | OPS-257 | Todo | | GW admin: handle new layout versions better |
  | | OPS-265 | Todo | | Re-evaluate MCU (Wiznet Pico2, Wiznet Pico, PicoW) choice |
  | | OPS-270 | Todo | | SCADA Template 7 — new Python, etc. |
  | | OPS-281 | Todo | | Create db w permissions for Peter Grant and Kelsi Zhang from LBL |
  | | OPS-282 | Todo | | Introduce Peter and Kelsi to the observatory data |
  | | OPS-283 | Todo | | Improve S3 → `gw_fleet_observatory` data pipeline |
  | | OPS-313 | In Progress | | pico improvements |
  | | OPS-324 | In Progress | | sema snapshots under code derivation |
  | | OPS-334 | In Progress | | gw1.nolan.layout a Sema type |
  | | OPS-358 | Backlog | | Add zoneX-YYY-heatcall derived channel for all homes |
  | | OPS-367 | Backlog | | RabbitMQ security improvements |
  | | OPS-368 | Todo | | Include SystemMode in the visualizer? |
  | x | OPS-380 | In Progress | D | Snapshot improvement |
  | x | OPS-381 | In Progress | D | Linear integration *(this design)* |
- [ ] *(optional, decide later)* **Wire `LINEAR_API_KEY`** so the hooks' live Linear-side
  checks run instead of the wiki-side / honor-system fallback (see
  [`../linear.md`](../linear.md) "Enforcement").

## Retirement

When the **To do** list is empty: confirm [`../linear.md`](../linear.md) holds
everything durable, **delete this file**, and move OPS-381 to Done. (Per the
designs convention, a shipped design is deleted; its distillate already lives
in the reference doc.)
