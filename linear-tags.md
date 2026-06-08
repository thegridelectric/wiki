# Linear tags glossary

Status: Draft · Pass 0 · Updated 2026-06-07

> What this is: the canonical meaning of every Linear **label** the team uses,
> grouped by axis. The wiki is canonical; each Linear label's `description`
> field should mirror its line here. Companion:
> [`designs/linear-integration.md`](designs/linear-integration.md) (how wiki
> designs map to Linear). Lines marked **(confirm)** are my best read of a
> tag's intent and need a human check.

Tags live on the **Ops team** (`OPS-*`), the live tracker. The dormant
**GridWorks team** (`GRI-*`) carries its own `keene.*` house labels on the
house reference cards — out of scope here.

## Axes

Every label belongs to one of four axes. A typical issue carries one house +
one component + (optionally) one work-kind / cross-cutting tag.

1. **House** — which installation.
2. **Component / domain** — which subsystem or repo.
3. **Work-kind** — what kind of work this is.
4. **Cross-cutting** — themes that span components.

## House

| Tag | Meaning |
| --- | --- |
| `beech` | Beech — first install (2023), beta-test house. |
| `fir` | Fir — third install (Aug 2024). |
| `elm` | Elm — fifth install (Apr 2025). |
| `maple` | Maple — fourth install (Feb 2025). |
| `oak` | Oak — second install (Feb 2024). |
| `spruce` | Spruce — Millinocket install. |
| `house0` | The canonical/template house — the `H0N` (House0 names) generic layout used as the modeling baseline, not a physical site. |

## Component / domain

| Tag | Meaning |
| --- | --- |
| `scada` | SCADA service / `gridworks-scada` repo. |
| `local-control` | The SCADA `LocalControl` actor — on-site autonomous time-of-use heat control (`all_tanks_tou`, `winter_tou`, `standby`, …) under the `auto.local_control.*` relay hierarchy, i.e. how the house runs itself when not under ATN dispatch. *(absorbed `scada-control`)* |
| `process-control` | Control-algorithm work — PID/setpoint loops regulating a process variable (e.g. leaving-water-temp targeting). The "Sieg loop" is one instance. *(was `sieg`, broadened)* |
| `dispatch-contract` | The ATN↔SCADA dispatch contract (terms under which the ATN dispatches the SCADA). |
| `state-machine` | Actor state-machine logic. |
| `heat-pump` | Heat-pump behavior / integration. |
| `air-conditioning` | Cooling / AC mode. |
| `sema` | Sema type system / `sema` repo. |
| `asl` | ASL codec / Application Shared Language messaging layer. **(confirm)** |
| `ltn` | LTN GNode role. **(confirm)** |
| `flo` | The FLO optimizer (forward-looking optimization / dispatch). |
| `pico` | Raspberry Pi Pico microcontrollers (tank modules, BTU meters). |
| `rabbit` | RabbitMQ broker. |
| `fcm` | Firebase Cloud Messaging — push notifications for alerts. **(confirm)** |
| `journalkeeper` | `gridworks-journalkeeper` / journaldb. |
| `code-gen` | Code generation (e.g. from Sema types). |
| `firmware` | Microcontroller firmware. |
| `electronics` | Board / electronics work. |
| `hardware` | Hardware generally. |
| `i2c-tricks` | I2C bus quirks / techniques. |
| `plumbing` | Physical hydronic plumbing. |

## Work-kind

| Tag | Meaning |
| --- | --- |
| `Bug` | A reproducible defect. |
| `glitch` | A transient/field anomaly — distinct from a reproducible `Bug`. **(confirm)** |
| `Feature` | New capability. |
| `Improvement` | Enhancement to existing behavior. |
| `refactor` | Internal restructuring, no behavior change. |
| `testing` | Test work. |
| `code-review` | Review-related. |
| `documentation` | Docs. |
| `investigation` | Open-ended digging into a question. |
| `post-mortem` | After-the-fact failure analysis. *(absorbed `forensics`)* |
| `ops-automate` | Spotting anything we do by hand that could be automated to save our sanity (pump-doctor self-healing, run-as-service, layout auto-gen). *(was `automate`)* |
| `software` | Software work (broad). |
| `infra` | Infrastructure / deployment substrate. |
| `ci-cd` | Continuous integration + deployment. *(merged `CI-CD` + the stray `CD`)* |
| `field` | On-site / installation work. *(absorbed `field-support`, `in-field-now`)* |
| `magoo` | Something George needs to do in the field. |
| `purchase` | Buy something. |
| `admin` | Administrative. |
| `agenda-item` | To raise at a team sync. |
| `decision` | A decision to make / record. |
| `collaboration` | Cross-person / external collaboration. |
| `backoffice` | Back-office / cloud-side services. **(confirm)** |
| `design` | **(new)** A design issue ↔ a `wiki/**/designs/<slug>.md` file. The bijection hook keys on this. See [`designs/linear-integration.md`](designs/linear-integration.md). |
| `nit` | **(new)** Sub-threshold one-line cleanup — too small for a design or a normal issue. |

## Cross-cutting

| Tag | Meaning |
| --- | --- |
| `COP` | Coefficient-of-performance analysis. |
| `Data Analysis` | Analysis of fleet data. |
| `observability` | Monitoring, metrics, logging. |
| `alerts` | Alerting (OpsGenie etc.). |
| `security` | Security / auth / certs. |
| `architecture` | System / actor structural design. |
| `data-architecture` | Data-layer structural design — schemas, pipelines, storage. |
| `data-sharing` | Sharing data with external parties (e.g. LBL). |
| `open-source` | Open-source-facing work. |
| `non-electric-backup` | The oil-boiler / non-electric failsafe heat path. |

## Consolidation actions — ✅ applied 2026-06-07

Decided in a one-by-one review and applied (renames/merges/deletes via the
Linear UI; the MCP can only *create* labels). Final state:

**Created (MCP, Ops team):** `design` (`99a0a12c`), `nit` (`68fdfdd2`).

**Renamed:** `Maple`→`maple` · `automate`→`ops-automate` · `CI-CD`→`ci-cd`
· `sieg`→`process-control`.

**Merged (source → target):** `forensics`→`post-mortem` ·
`scada-control`→`local-control` · `field-support`→`field` ·
`in-field-now`→`field` · `CD`→`ci-cd`.

**Deleted:** `technical`.

**Considered but kept:** `software` and `data-architecture` (kept on review —
not merged/deleted); `glitch` (distinct from `Bug`); `magoo`.

**Still TODO (no MCP path):** populate each kept label's Linear `description`
field to match its line here — UI only.
