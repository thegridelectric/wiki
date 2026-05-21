# Component: `ContractHandler`

> **What this is:** the SCADA-side bookkeeper for its dispatch relationship with
> the LTN. It owns the lifecycle of the `SlowDispatchContract`, the
> heartbeat exchange that proves liveness between SCADA and LTN, running energy
> accounting against the contracted amount, and persistence of contract state
> across reboots. Source: `gw_spaceheat/actors/contract_handler.py` (397 lines).

Provenance: read from source this pass; callers in `actors/scada.py` **not yet
traced**. Behavioral claims are `inferred` unless marked otherwise.

## Responsibilities

| Responsibility | Where |
|---|---|
| Hold the current contract heartbeat (`latest_scada_hb`) and the previous (`prev`) | `:50-51` |
| Accrue energy used in the slot from power readings | `update_energy_usage` `:56`, `remaining_watthours` `:75` |
| Detect contract expiry by wall clock | `active_contract_has_expired` `:87` |
| Persist/restore contract across reboots | `load_heartbeat` `:95`, `store_heartbeat` `:153`, `initialize` `:172` |
| Drive the heartbeat state machine | `start_new_contract_hb` `:203`, `update_existing_contract_hb` `:241` |
| Originate SCADA-side terminations/completions | `scada_terminates_contract_hb` `:297`, `scada_contract_completion_hb` `:319` |
| Human-readable contract logging | `formatted_contract` `:349` |

## The heartbeat & liveness model

- The unit exchanged is `SlowContractHeartbeat` (a `gwsproto` boundary type).
- Each heartbeat carries `MyDigit = random.choice(range(10))` and
  `YourLastDigit` echoing the peer's last digit (`:236-237`, `:312-313`) — a
  ping-pong continuity/liveness token between SCADA and LTN. This is the
  code-level realization of the SCADA↔LTN liveness commitment in
  [[../concerns/liveness-and-sla]].
- `FromNode` attributes each heartbeat to its author (SCADA or `H0N.ltn`),
  which is how termination/completion is attributed to a party.

## Contract status lifecycle

`SlowDispatchContractStatus` (from `gwsproto.enums`). Terminal states
(`DONE_STATES`, `:23-30`): `TerminatedByLtn`, `TerminatedByScada`,
`CompletedUnknownOutcome`, `CompletedSuccess`, `CompletedFailureByLtn`,
`CompletedFailureByScada`.

Observed transitions:

| Trigger | Method | Resulting SCADA status |
|---|---|---|
| LTN sends `Created` | `start_new_contract_hb` `:203` | `Received` |
| LTN sends `Confirmed`/`Active` | `update_existing_contract_hb` `:281` | `Active` |
| LTN sends `TerminatedByLtn` | `update_existing_contract_hb` `:264` | clears contract, no reply |
| LTN sends `CompletedUnknownOutcome` | `update_existing_contract_hb` `:269` | final accounting, then `CompletedUnknownOutcome` |
| SCADA decides to bail | `scada_terminates_contract_hb` `:297` | `TerminatedByScada` |
| Time passes contract end | `scada_contract_completion_hb` `:319` | `CompletedUnknownOutcome` (`IsAuthoritative=False`) |
| Reboot after expiry | `load_heartbeat` `:118-135` | reconciles to `CompletedUnknownOutcome` to report up |

Per [[../principles]], `scada_terminates_contract_hb` is the SLA-breach exit —
it must be used only on breach, not convenience. The code does not itself encode
*what* counts as a breach (no critical-zone check found here); the cause is a
free-text `cause` arg.

## Energy accounting

- `update_energy_usage` integrates `latest_power_w × Δt` into `energy_used_wh`
  (`:56-73`).
- `remaining_watthours` = `AvgPowerWatts × DurationMinutes/60 − energy_used_wh`,
  floored at 0 (`:75-85`).
- `get_initial_watt_hours` seeds usage for the gap between slot start and the
  first heartbeat (`:196-201`).

## Persistence

Single JSON file `slow_dispatch_contract.json` under `paths.data_dir`
(`:47-49`). `store_heartbeat` writes either `latest_scada_hb` or an LTN
heartbeat in a terminal status; `load_heartbeat` restores and, if the slot has
ended unresolved, manufactures a `CompletedUnknownOutcome` to send up on reboot.

## Findings raised against this component

- [[../findings#f-002]] inconsistent `FromNode` source
- [[../findings#f-003]] expected "already in contract" raises an exception
- [[../findings#f-004]] reboot may silently drop a persisted LTN heartbeat
- [[../findings#f-005]] energy race reset-to-zero, info-logged only
- [[../findings#f-006]] unused timing constants
- [[../findings#f-007]] docstring typos

## Next on this component

- Trace callers in `actors/scada.py`: who calls `update_existing_contract_hb`,
  where the heartbeat *timeout* (liveness deadline) is enforced, and where (if
  anywhere) SLA-breach termination is triggered.
- Confirm F-004 against the reboot/persistence test before treating it as a bug.
- Map `SlowContractHeartbeat` / `SlowDispatchContractStatus` in `gwsproto`
  (Sema boundary types) — feeds [[../concerns/sema-style]].
