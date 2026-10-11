# Contract refusal: one reason, answered at the offer

Status: Draft · Pass 0 · Updated 2026-10-10 · Linear: OPS-392

> What this is: the spoke that gives the scada one place to decide, and
> one message to say, why it will not take a dispatch contract. It
> replaces the "No deed, no boot" change (rolled back 2026-10-10, see
> "What was tried").

## ▶ Do this next

Grill the design below (plan mode, `/grill-me`) until the precedence
table and the two sema edits are agreed; then raise the sema edits with
the human (both words are `staging`, so they are edited in place). Code
starts only after the spoke is Accepted.

## The problem

A scada refuses a dispatch contract for several reasons, and today each
reason has its own site, its own source, and its own answer to the LTN:

| Reason | Where it is decided | Source | What the LTN hears |
|---|---|---|---|
| Admin holds the scada | `scada.py` `process_slow_contract_heartbeat`, "Ignoring new contract, in Admin" | `top_state` | nothing |
| Standby, NoAggregator | `leaf_ally_loader.py` `process_message` | the ops word | a `TerminatedByScada` heartbeat, after the scada has already taken the contract |
| ServiceContractBroken | the cold latch writes it into the ops word; then as above | the ops word | as above |
| No ta.deed | before the rollback: `process_slow_contract_heartbeat` on `validation_state` | the deed file | a `slow.contract.rejection` carrying `ValidationState` |

Three things are wrong with this.

**The refusal is answered after acceptance.** On a `Created` heartbeat
the scada makes the offer its `latest_scada_hb`, fires
`DispatchContractLive`, and sends the contract to the leaf ally; the
loader wrapper then refuses it with `AllyGivesUp`, and
`process_ally_gives_up` sends the LTN a terminating heartbeat. The LTN
cannot tell a refusal from a contract that ran and was ended. The
heartbeat store and the auto state both move for a contract the scada
never meant to hold.

**The deed fact has no honest home in the ops word.** The deed is
issued by a validator; the ops word is written by a person. The
rolled-back change made the person restate the deed in the word
(`NoTaDeed`) and added a boot check to keep the copy true. A copy of
"exists" cannot carry the deed's content, is reconciled only when it is
made (at boot; a deed that goes away mid-run is not noticed), and makes
every test that builds an app supply a deed so the copy validates (45
test files changed for one rule).

**Admin is silent.** A scada under Admin drops the offer without a
word. The LTN resends or waits out the grace period.

## The design

### One derived property

The scada gets one property, `dispatch_refusal`, returning
`DispatchRefusalReason | None`. It is computed when asked, never
stored, from facts in precedence order:

1. `top_state` is Admin → `InAdmin` (new enum value; see Sema).
2. the ops word says `Standby` → `Standby`.
3. the deed does not grant dispatch → `NoTaDeed`. The deed file is read
   at this moment, so the check is live, not a boot snapshot.
4. the ops word carries a reason → that reason (the authored
   `OperatorHold`, or the latched `ServiceContractBroken`).
5. otherwise `None`: the scada takes the contract.

The ops word carries one optional `DispatchRefusalReason`, for the
reason a person authors or the scada latches; it never carries a
derived reason (an axiom, see Sema). The docstring of the property is
the one place that states the precedence.

Every reader of the word's refusal reads the property instead:
`house_operating_status` (so the LTN's standing view and the per-offer
answer come from the same function), the stored-contract decision at
restart, and `derived_generator`'s energy estimate.

### The deed check has content

`deed_grants_dispatch(deed, layout, is_simulated)` in `sema_to_dc.py`,
beside the other cross-word checks, is true when:

- a deed is on file and its `TaId` and `TaAlias` both name the layout's
  terminal asset;
- its `ValidationState` is not `UnValidated`;
- a simulated scada holds a `ValidatedSimulatedAsset` deed and a real
  scada does not (the deed word's axiom 1 keeps a simulated deed out of
  the world universe; this is the scada-side half).

A deed carries no signature yet. When it does, this function is where
the verification goes.

### Reject at the offer

```
process_slow_contract_heartbeat, Status Created:
    reason = self.dispatch_refusal
    if reason is not None:
        send the LTN  slow.contract.rejection(ContractId, DispatchRefusalReason=reason)
        return        # no latest_scada_hb, no ally, no state change
    accept as today
```

The LTN's `contract_handler.process_slow_contract_rejection` already
drops the pending offer so it is not resent or reloaded; it logs the
reason field.

The loader wrapper's gate goes: a contract cannot reach the ally while
the scada refuses, so the wrapper has nothing to decide and shrinks to
a factory.

### Termination stays for contracts already held

`AllyGivesUp` → `TerminatedByScada` remains the one path for ending a
contract the scada holds: the ally relinquishing (missing temperatures),
the cold latch, a stored contract not resumed at a restart because the
property now refuses, and one new case: the deed lost mid-contract
(`dispatch_refusal` returns `NoTaDeed` at the next heartbeat; nothing is
written to the params file, since the deed, not the word, is the truth
and may come back).

Two facts, two messages: a rejection before the contract exists, a
termination after.

### Sema

Three words change. All are `staging`, so each is edited in place; each
edit is raised with the human before it is made.

**`gw.dispatch.refusal.reason` 000.** The values sort by who owns each
fact, and the description says so:

- authored by the operator: `OperatorHold` (new) — the operator keeps
  the house in local control; it heats itself fully and takes no
  contract. The reason for a commissioning period, when local control or
  the FLOs are under adjustment.
- latched by the scada: `ServiceContractBroken`.
- derived at the offer: `Standby`, `NoTaDeed` (new), `InAdmin` (new;
  alternative: Admin stays silent).
- `NoAggregator` names a fact no record holds yet (no registry of
  aggregator agreements). It stays in the enum as the future derived
  value and nothing emits it until there is a record to derive it from.
  It is not an honest authored reason: the operator does not own that
  fact, and a reader of the data would conclude the market side was
  missing when the control side was being commissioned.

**`gw.operational.params` 000.** `AcceptsDispatch` and
`DispatchRefusalReason` spell one fact twice, and `Standby` is a third
spelling; axioms 3 and 4 exist only to reconcile them. New shape:

- `AcceptsDispatch` dropped. `DispatchRefusalReason` optional; absent
  means the author refuses nothing.
- `Standby` stays (it is a relay posture and a loop strategy, not only
  a refusal) and is no longer echoed into the reason. Axiom 3 becomes:
  if Standby, `DispatchRefusalReason` is absent.
- Axiom 4 dropped. New axiom: `DispatchRefusalReason` is never a derived
  value (`Standby`, `NoTaDeed`, `InAdmin`, `NoAggregator`); only
  `OperatorHold` and `ServiceContractBroken` are authorable.
- Axiom 6 (Standby holds a House0 loop at full send) is already in the
  word and is unchanged.

**`gw.house.operating.status` 000.** The emitted verdict: the same
collapse, `AcceptsDispatch` dropped, `DispatchRefusalReason` optional
and carrying the full derived value. `ValidationState` stays beside it
for now (the deed's raw state next to the verdict); dropping it is a
later edit once the verdict has run in the field.

**`slow.contract.rejection` 000.** `ValidationState` →
`DispatchRefusalReason`.

Readers that move with the shape: the latch's write path (`cold.py`,
`scada.py`), the four `AcceptsDispatch` readers named above,
`ltn.py` reading `AcceptsDispatch` off the status, the house gens in
tlayouts (every house takes `OperatorHold` for the commissioning
weeks). The tlayouts snapshot and the scada mirror regenerate in one
wave once the four edits are in.

### Tests

- The precedence table as one parametrized test: each row, the reason
  the property returns.
- `deed_grants_dispatch`: each clause, both families, real and
  simulated.
- Offer-time rejection over the in-process LTN+scada pair: the LTN
  receives the rejection with the reason, the scada's `latest_scada_hb`
  stays `None`, the auto state stays LocalControl.
- In flight: a deed removed between two heartbeats ends the live
  contract with `NoTaDeed`; the params file is unchanged.
- A deedless scada boots (the autouse fixture no longer has to seed a
  deed for tests that never dispatch). Only the dispatch tests seed
  one, through the config-dir fixture.

Verification (EDD): an LTN offering a contract over the dev broker to
a scada that refuses for each reason, the rejection seen at the LTN.

## What was tried

`1a5da0d5` (rolled back 2026-10-10, the branch reset to `b2bec9aa`;
the sema commit `07d6fb3` NoTaDeed and its tlayouts snapshot reset with
it, so the enum comes back as one edit; axiom 6, `b1d5c70`, stands):
`NoTaDeed` authored into the ops word, `check_dispatch_against_deed`
raising at app build when the word and the deed file disagreed, the
`validation_state` branch and `slow.contract.rejection` deleted, a
deed seeded into 45 test files. It made the params file self-describing
and removed the second refusal message, at the three costs above. The
review that found them is in the session record only; the costs are the
argument of this spoke.

## Open

- Does the leaf ally still refuse while it has no forecast
  (`nolan-local-control.md` "Weather forecast at the scada")? If so it
  is a fifth site and belongs in the table, as a termination (the
  contract is held) or as a derived reason.
- `InAdmin` or silence.
- The name `OperatorHold`, and whether the LTN needs to know a hold is
  temporary.
- Should a refusal also raise a glitch, or is the operating status
  enough? The deed case already has the `no-ta-deed` Warning at start.
