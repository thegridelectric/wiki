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

## Two heartbeat layers — keep them separate

There are **two distinct heartbeat mechanisms** in the system. Conflating them
is a design risk; they answer different questions, live at different layers, and
have different trust requirements.

| | Supervisor liveness | Contract heartbeat |
|---|---|---|
| Type | `heartbeat.a` (`MyHex`/`YourLastHex`) | `SlowContractHeartbeat` (`MyDigit`/`YourLastDigit` + contract + energy) |
| Layer | gridworks-base control plane | SCADA↔LTN application/contract |
| Question | "is this actor/process running?" | "is the responsible party demonstrably alive & accountable for dispatch?" |
| Parties | intra-trust-domain (a supervisor and its subordinates, one operator) | **cross-party** (customer's SCADA ↔ aggregator's LTN) |
| Auth | alias only — no secret/token (gwbase `primary.md` invariant) | must be **signed** (see below) |
| Carries | continuity only | contract state, energy used vs contracted, party-attributed termination/failure |
| Handled by | `GridworksActor` auto-pongs `heartbeat.a` from `my_super_alias`; others fall through (a supervisor watches subordinates) — `wiki/gridworks-base/executor/actors.md` §5.2 | `ContractHandler` ([[../components/contract-handler]]) |

**`heartbeat.a` (supervisor) is the right tool for liveness/respawn within one
operator's fleet** — lightweight, alias-identified, no money. The
`MyHex`/`YourLastHex` pair is just continuity (detect missed/duplicate beats,
order them).

**The SCADA↔LTN contract heartbeat is the right tool for the SLA** — it is the
running record of *the agreement*, not just "is the link up." This is the layer
the contract, the energy accounting, and the blockchain/umpire vision attach to.

> **Resolved (was an OFI to rename `MyHex` → `SuHex`):** *do not* rename. The
> fields are **sender-relative** — `MyHex` is the sender's fresh token,
> `YourLastHex` echoes the peer's last — so the *same* type serves both the
> supervisor and the supervised actor; "SuHex" would wrongly imply a
> supervisor-only field and break that symmetry. Instead the supervisor
> health-monitoring purpose is now documented in `sema` `heartbeat.a/000`, and
> Joe's unpublished erroneous `heartbeat.a/001` (which deleted the hex) was
> removed (`latest_version` reverted to `000`). See [[../findings#f-008]].

## Is application-level SCADA↔LTN heartbeating sound? — Yes, conditionally

Yes — and it is arguably *necessary*, not merely acceptable, **provided** the
beat is **end-to-end, signed by the SCADA, and chained**. The reasoning:

- **Only the application layer can prove the right thing.** Transport/connection
  liveness (TCP/MQTT/AMQP up, or FIS/mTLS connection-authorized) proves *a link
  is up* — not that the real responsible device is alive and in control. In a
  multi-hop or provider-bridged path (SCADA → MQTT → rabbit → LTN, or via an
  Aris cloud), connection liveness at any hop can be proxied or faked. Only a
  beat the **SCADA itself originates** demonstrates the SCADA is alive.
- **This is the whole reason the heartbeat is SCADA↔LTN, not cloud↔LTN.** If an
  intermediary (e.g. an Aris cloud) can synthesize the beat, you have
  reintroduced fake liveness. So the soundness condition is: the beat is
  **signed by the SCADA's key** (the TerminalAsset deed key — see
  [[deeds-and-trading-rights]]) end-to-end to the LTN, so no relay can fabricate
  it. App-level + unsigned + relayed-by-an-interested-party is **not** sound.
- **It carries semantics a connection ping never could** — contract status,
  energy used vs contracted, and party-attributed termination. That is the SLA
  in motion, not just a pulse.
- **It survives transport changes** — as a `gw`-wrapped message it can traverse
  the MQTT↔AMQP bridge (gwbase `transport.md` shows `gw.…to.scada.heartbeat-a`),
  so the contract layer is decoupled from whether SCADA stays MQTT or goes
  rabbit-native ([[transport-and-links]]).

## The non-repudiation / umpire vision

The end goal: the heartbeat chain is the **foundation of the contract**, and
eventually anchored so a **neutral third-party umpire can adjudicate whose fault
a dispatch failure was** (SCADA offline? LTN never dispatched? provider relay
dropped it?). What that requires beyond today's code:

1. **Per-beat signatures.** Each party signs its beat with its identity key
   (SCADA: deed key; LTN/aggregator: TradingRights-backed key). Without this the
   chain proves nothing against a motivated party.
2. **A real linked chain.** Each beat references the peer's previous beat so gaps
   are detectable and neither side can deny a beat it received. Today's
   `MyDigit`/`YourLastDigit` is a **single decimal digit (0–9)** — fine as a
   liveness toggle, far too weak to be umpire-grade (trivial collisions, forgeable,
   no cryptographic link). It needs to evolve to a signed nonce/hash chain. See
   [[../findings#f-009]].
3. **A neutral, tamper-evident anchor.** A blockchain (or a notary / the ear's
   signed log) provides the impartial ledger. Cost-wise, the likely shape is
   **periodic on-chain commitment** (e.g. a Merkle root of a contract window's
   beats captured by the ear) rather than every beat on-chain.

This is why `MyHex`/`YourLastHex` were introduced at the application level in the
first place — they are the *skeleton* of a co-constructed, mutually-acknowledged
chain. The umpire vision is the contract layer's, **not** the supervisor layer's.

## Connection to asset health monitoring

The contract heartbeat and the asset-health dashboard should be **one signal,
several consumers** — do not build a separate health ping:

- **Liveness/uptime** — beat cadence and gaps give per-asset online/offline
  directly (the same signal the contract uses → single source of truth).
- **Performance/compliance** — `WattHoursUsed` vs contracted per window is an
  SLA-compliance metric, not just telemetry.
- **Fault/SLA-breach events** — `TerminatedByScada` / `CompletedFailureBy*`
  status transitions are dashboard alerts *and* the umpire's evidence.
- **Capture path:** the gwbase topology fans every message into the **ear**
  (`ear_tx`, the universal audit tap). Contract heartbeats land there, making the
  ear both the persistent contract ledger and the dashboard's data source — and
  the natural place to compute the periodic on-chain commitment. (Supervisor
  `heartbeat.a` liveness is a lower-level "is the gwbase actor process up"
  signal — useful for fleet ops, but not the asset-accountability signal.)

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
