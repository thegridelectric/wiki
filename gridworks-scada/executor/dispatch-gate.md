# Dispatch gate

Status: Accepted · Pass 1 · Updated 2026-10-14

> What this is: the one place the scada decides, and the one vocabulary
> it uses to say, why it will not take or keep a slow dispatch contract.
> The cold latch that writes one of the reasons is
> [`cold-house.md`](cold-house.md); the freshness bound under
> `ScadaBlind` is [`sensor-freshness.md`](sensor-freshness.md); the
> operating status that reports the answer is
> [`local-control.md`](local-control.md) "The operating status".
> Distilled from the spruce-unlimbo work of 2026-10 (OPS-392).

## The three authorities

The scada does two distinct things with dispatch: it **refuses** slow
dispatch contracts from the start, offer by offer, and it **breaks** a
contract it already holds. The authorities over both fall in two
groups, by when the fact is knowable.

**On file, decisive before boot.** Three files, three owners. Each
refuses from the first offer, and a person can read the refusal off the
box without the scada running.

| Authority | Owner | What it decides |
|---|---|---|
| The `ta.deed` on file | a TaValidator | whether this terminal asset has standing to trade: refuses, and breaks a held contract if it goes away |
| `DispatchHold` in the `gw.operational.params` file | a person, and one latch | whether the operator is holding the house out, and whether the service contract stands broken: refuses from the start |
| The layout's disabled channels | the layout author | whether a channel the family's control requires is disabled, which blinds the scada for the whole run (`ScadaBlind`) |

**Observed while running.** The code owns these: whether a channel the
family's control requires has gone stale (`ScadaBlind`: refuses, and
breaks a held contract), and the moment the service contract breaks
(the cold latch), which breaks the held contract and is written into
the ops word's `DispatchHold` so every later offer is refused.

The authorities interact in one direction only. The running code
decides when the service contract breaks and writes that into the ops
word; nothing else writes across. The deed is never copied anywhere,
and the ops word never copies the layout.

## The answer

`dispatch_refusal`, a property on the Scada actor
(`actors/scada.py` "dispatch_refusal"), returns
`DispatchRefusalReason | None`. It is computed at the moment it is
asked, never stored. Every reader of "does this scada dispatch" reads
it: the offer handler, the per-heartbeat check on a held contract, the
stored-contract decision at restart, and `house_operating_status`, so
the LTN's standing view and the per-offer answer come from one
function. The derived generator reads the ops word's hold directly for
its energy estimate: whether to estimate does not depend on the
sensing.

Ordered by permanence, most permanent first, so a log line names the
reason that will still be true tomorrow:

| # | Fact | Reason | Source |
|---|---|---|---|
| 1 | the deed does not grant dispatch | `NoTaDeed` | the deed file, read now |
| 2 | the ops word's `DispatchHold` says the operator holds the house | `OperatorHold` | the ops word |
| 3 | the ops word's `DispatchHold` says the service contract is broken | `ServiceContractBroken` | the ops word; set by the code |
| 4 | a channel the family's control requires is disabled in the layout or not fresh | `ScadaBlind` | the hydronic predicate |
| 5 | an admin session runs the house | `InAdmin` | `top_state`, read now |
| | none of the above | `None`: the scada takes the contract | |

`Standby` is not a reason: the ops word's axiom makes Standby imply
`OperatorHold`, so a standby house refuses as a held house.
`NoAggregator` is not a reason until the LTN can prove it is the
aggregator; nothing authors or sets it.

**Admin ends a held contract on the way in.** `admin_wakes_up` calls
`end_contract` with `InAdmin` before `AutoGoesDormant`: the terminating
heartbeat goes to the LTN, is stored so a restart finds a finished
contract, and is flushed so the scada holds none. The auto state goes
from LeafTransactiveNode straight to Dormant; local control is not
woken on the way. An offer during the session gets a rejection with
`InAdmin`. On the exit (timeout or release) the scada reports that it
accepts dispatch again and wakes into LocalControl with no contract;
the LTN offers again at the next top of hour, so an admin session costs
the rest of the hour in local control. `end_contract(reason, cause)` is
the scada's one way to end a held contract; the ally's give-up and the
per-heartbeat refusal are its other callers.

**The deed check has content.** `deed_grants_dispatch(deed, layout)`
(`sema_to_dc.py`), beside the other cross-word checks, is true when a
deed is on file, its `TaId` and `TaAlias` both name the layout's
terminal asset, and its `ValidationState` is not `UnValidated`. The
deed file is read at each check, so a deed that goes away mid-run is
noticed at the next heartbeat. The deed word's own axiom keeps a
simulated deed out of the world universe; the scada adds no clause
about simulation, since a hardware-in-the-loop house is a real asset.
A deed has no signature yet; when it does, this function is where the
verification goes.

## The two messages

Two facts, two messages, one vocabulary:

- **A rejection before the contract exists.** On a `Created` heartbeat
  with `dispatch_refusal` not `None`, the scada sends
  `slow.contract.rejection` with the reason and returns. Nothing else
  moves: no heartbeat is stored, no timer starts, the auto state stays
  where it is, no grace period follows. The LTN drops its pending
  heartbeat and may offer again at its next price.
- **A termination after.** `AllyGivesUp` → `TerminatedByScada` is the
  one path for ending a contract the scada holds, and the terminating
  heartbeat names the reason in the same enum: the cold latch
  (`ServiceContractBroken`), a stored contract not resumed at restart
  because the property refuses, the deed lost mid-contract
  (`NoTaDeed`), the buffer gone stale mid-contract (`ScadaBlind`).

The per-heartbeat check on a held contract evaluates `dispatch_refusal`
at each LTN heartbeat, the same moment it re-reads the deed. Nothing is
written to the params file by these checks; the deed and the sensing
are the truth and may come back.

## ScadaBlind

One predicate in the hydronic layer, `buffer_fresh(data, layout)`
(`actors/hydronic/shared.py`): every channel the family's control needs
to judge the buffer has a read time inside the channel's nyquist bound
([`sensor-freshness.md`](sensor-freshness.md) "The bound"). A `None`
read time is stale, which covers a channel flushed by `ChannelFlatlined`
and one never read. The family's set is `dispatch_channels(layout)`,
keyed on the layout word beside the predicate: Nolan the band (depth1
and depth3), House0 the effective buffer depths. It is the one
availability word; readers ask it, never a flag of their own.

Readers: the gate (reason 4, at the offer and at each heartbeat), local
control (its `MissingData` / `DataAvailable` judgment), the derived
generator (its energy passes answer `None` until the buffer is fresh),
and the leaf ally through the one-shot `buffer_fresh_once` on
`ScadaData`, set by the scada's reading path the first time the
predicate is true. One-shot is right there: later blindness is the
per-heartbeat gate's, which ends the contract.

**A disabled required channel blinds at boot.** It never arrives, so
there is nothing to wait for; the refusal is immediate and lasts the
run. A layout with no buffer tank has no dispatch channels to be fresh
and is blind for the run; the families that have no tanks name their
own set when they arrive.

`ScadaBlind` is a derived scada-level fact and goes on
`gw.house.operating.status` beside `TopState`, so the LTN's standing
view says blind and the per-offer rejection is the backstop.

## The ops word

`gw.operational.params` has one dispatch field, `DispatchHold`, a
`gw.dispatch.hold`: two booleans, each a fact its writer owns.
`OperatorHold` is the person's; `ServiceContractBroken` is the cold
latch's, written by `process_break_service_contract` through a temp
file and a rename, and cleared only by a person editing the file. The
word says what it is: a hold the file places on dispatch, one of three
authorities, not the answer. Accepting dispatch is derived everywhere;
no file states it. Axiom: Standby implies `DispatchHold.OperatorHold`.

The words, all `staging`: `gw.dispatch.refusal.reason` (values
`NoTaDeed`, `OperatorHold`, `ServiceContractBroken`, `ScadaBlind`,
`InAdmin`; default `OperatorHold`, the no-harm decode fallback),
`gw.dispatch.hold`, `gw.operational.params` with `DispatchHold`
required, `slow.contract.rejection`, and `slow.contract.heartbeat`
with the reason beside the free `Cause` on a `TerminatedByScada`.

**The roster glitch names the dispatch clause.** When the disabled set
intersects the family's `dispatch_channels`, the daily
`disabled-roster` Warning says those channels are required for
dispatch and the scada refuses every offer.

## Open

- Nolan's transactive path is not built: `NolanLeafAlly` suits up on a
  contract and does nothing with it. Spruce's ops file says
  `OperatorHold`, which is true: the operator holds the house out
  because nothing can serve a contract.

## Tests

| Behavior | Test |
| --- | --- |
| The precedence table, each row on both families; a refused offer gets a rejection and nothing moves; an accepted offer reaches the ally | `tests/actors/test_dispatch_refusal_gate.py` |
| An UnValidated scada refuses every offer with a rejection | `tests/actors/test_contract_rejection.py` |
| The deed is the deed: validation state derives from it, another asset's deed is no deed | `tests/actors/test_startup_announcements.py` |
| A stored contract resumed or ended at restart by the property | `tests/actors/test_startup_contract_load.py` |
| `buffer_fresh` and `buffer_fresh_once` on both families; the energy passes wait for a fresh buffer | `tests/actors/test_readiness_events.py` |
| Admin mid-contract: the LTN receives `TerminatedByScada` with `InAdmin`, an offer during the session is rejected with `InAdmin`, and after the timeout the scada is in LocalControl with no contract and takes the next offer | `tests/actors/test_dispatch_refusal_gate.py` |
| The roster glitch names the dispatch clause for a disabled dispatch channel, and no clause for another | `tests/actors/test_ally_initialize.py` |
