# Concern: liveness, heartbeat & the SLA

Design intent from Jessica + evidence from code. See [[../principles]].

## The commitment

- A heartbeat demonstrating **liveness** must run **SCADA ↔ LTN**, not
  cloud ↔ LTN. A provider's cloud engineers can fake liveness; the SCADA is the
  party that genuinely goes offline. In residential settings the SCADA *will* be
  offline sometimes, and for many contract types **SCADA offline ⇒ contract
  broken**. The liveness signal must originate where the real failure can occur.
- The SCADA terminates only on **SLA breach** (e.g. a critical zone too cold) —
  never "whenever convenient to the SCADA." (Legacy term: SCADA *suspends
  Representation*, `old_words/representation-contract.md`.)

## What exists in code today

`actors/contract_handler.py` already implements a heartbeat between SCADA and
LTN — aligned with the commitment above. (See [[../components/contract-handler]]
for the full description.)

- `SlowContractHeartbeat` carries a `MyDigit` / `YourLastDigit` ping-pong — a
  liveness/continuity token exchanged each heartbeat (`contract_handler.py:228`,
  `:236`).
- `SlowDispatchContractStatus` lifecycle includes `TerminatedByScada`,
  `TerminatedByLtn`, `CompletedSuccess`, `CompletedFailureByScada/ByLtn`,
  `CompletedUnknownOutcome` — i.e. termination is attributed to a party, and
  failure is distinguished from clean completion.
- On reboot, an expired/unresolved contract is reconciled to
  `CompletedUnknownOutcome` and reported up (`contract_handler.py:118-135`).

## Open questions

- Where is the *liveness deadline* enforced (how long offline before the LTN
  considers the contract broken)? Found the contract-expiry check
  (`active_contract_has_expired`, `:87`) but not yet the heartbeat-timeout
  logic — trace in `actors/scada.py` callers.
- Is "SLA breach" (critical zone too cold) currently a code-driven termination,
  or only a human/operational concept? Not yet found in code.
- The two-layer model (long-standing **Representation Contract** umbrella vs.
  short-term **DispatchContract**) from `old_words` — how much of the umbrella
  layer exists today vs. only the dispatch layer?

## Links

[[../components/contract-handler]] · [[deeds-and-trading-rights]] · [[../principles]]
