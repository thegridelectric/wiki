# Findings register

Actionable backlog: bugs, smells, and small/medium cleanups. Append-only IDs
(`F-NNN`), never reused. Conventions in [`../PROCESS.md`](../PROCESS.md).
Grouped into **area subsections** so a cleanup session can grab a localized
batch. Big/cross-cutting work is **not** here — it lives as an epic in
[`concerns/`](concerns/).

Provenance: findings raised from reading source without tracing all callers are
marked **(inferred)** — confirm before acting. Status of each finding is owned
here; concerns link in by `Concern:` tag and never restate.

To find a concern's open findings: search this file for `Concern: [[that-concern]]`.

---

## Area: docs / cross-repo

### F-001 — `docs/architecture-overview.md` is stale
- **Type:** doc-gap
- **Severity:** low
- **Effort:** small
- **Location:** `docs/architecture-overview.md`
- **Concern:** —
- **What:** References "winter 2022-2023" and the Nolan house as current; predates the contract/heartbeat and Scada2 architecture. `CLAUDE.md` is the accurate summary.
- **Fix idea:** Refresh to point at the wiki (`executor/primary.md`), or mark it historical.
- **Status:** open

---

## Area: contract_handler (`actors/contract_handler.py`)

### F-002 — Inconsistent heartbeat `FromNode` source
- **Type:** smell
- **Severity:** med
- **Effort:** small
- **Location:** `actors/contract_handler.py:228,282,305,333` (inferred)
- **Concern:** [[concerns/liveness-and-sla]]
- **What:** `FromNode` is set from `self.node.Name` in most constructors but hardcoded to `H0N.primary_scada` in `update_existing_contract_hb` (`:282`). The ctor comment (`:38`) says `node` is only "intended to be" `H0N.primary_scada`, not enforced — so these can disagree.
- **Fix idea:** Single source of truth: assert `node` is the primary scada at construction, or always use `self.node.Name`.
- **Status:** open

### F-003 — Expected "still inside existing contract" raises an exception
- **Type:** design-question
- **Severity:** med
- **Effort:** med
- **Location:** `actors/contract_handler.py:220-223` (inferred)
- **Concern:** [[concerns/liveness-and-sla]]
- **What:** `start_new_contract_hb` raises `Exception` when a new LTN contract arrives while one is live. Overlapping/duplicate offers look like a normal protocol event, not a programmer error.
- **Fix idea:** Return a typed rejection/decision; let the caller handle it.
- **Status:** open

### F-004 — `load_heartbeat` silently drops a persisted LTN heartbeat in unexpected status
- **Type:** bug
- **Severity:** med
- **Effort:** med
- **Location:** `actors/contract_handler.py:112-116` (inferred)
- **Concern:** [[concerns/liveness-and-sla]]
- **What:** When the persisted heartbeat is `FromNode == H0N.ltn` and its status is not in `[TerminatedByLtn, CompletedUnknownOutcome]`, the method bare-`return`s (`None`) and sets neither `latest_scada_hb` nor `prev`. On reboot mid-contract a live LTN-authored state could be discarded silently.
- **Fix idea:** Confirm against the reboot/persistence test; if real, handle or log the dropped state explicitly.
- **Status:** open

### F-005 — Known energy-accounting race reset-to-zero, info-logged only
- **Type:** smell
- **Severity:** low
- **Effort:** med
- **Location:** `actors/contract_handler.py:62-66` (inferred)
- **Concern:** [[concerns/liveness-and-sla]]
- **What:** `update_energy_usage` logs "Race condition!" and resets energy accounting to 0, silently losing the slot's accrued energy.
- **Fix idea:** Determine whether the race is reachable; if so, recover elapsed energy rather than zeroing.
- **Status:** open

### F-006 — Unused timing constants
- **Type:** cleanup
- **Severity:** low
- **Effort:** small
- **Location:** `actors/contract_handler.py:31-32` (inferred)
- **Concern:** —
- **What:** `GRACE_PERIOD_MINUTES` and `WARNING_MINUTES_AFTER_END` are defined but not referenced in this file. Either dead, or the logic lives elsewhere and should be co-located/cross-referenced.
- **Status:** open

### F-007 — Docstring typos in `contract_handler.py`
- **Type:** cleanup
- **Severity:** low
- **Effort:** small
- **Location:** `actors/contract_handler.py` (multiple)
- **What:** "Creats", "Managesthe", "fluses", "aysnchronously", etc. Cosmetic, but they hurt the à-la-carte legibility goal.
- **Status:** open
