# Contract refusal: one reason, answered at the offer

Status: Accepted · Pass 1 · Updated 2026-10-14 · Linear: OPS-392

> What this is: the spoke that gives the scada one place to decide, and
> one vocabulary to say, why it will not take or keep a dispatch
> contract.

## ▶ Do this next

Build items 1, 2, 3 and the gates half of 5 are on `jm/spruce-unlimbo`
(`8c6078fa`). The async plan ("The ally awaits its inputs", "The
startup order") had an adversarial read on 2026-10-14 and its findings
are folded into those sections. Next: build in this order, tests first:

1. The two readiness events on `ScadaData` and their setters;
   `buffer_temps_available` goes, its readers ask `buffer_fresh`.
2. The weather-source gate on `SimWeatherSource` and the two live
   tests in "Tests", written to fail against the current tree.
3. The derived generator's first-forecast retry.
4. `initialize` as the ally's only Initializing judgment; the
   announcement and the resume as tasks; one helper for every contract
   sent to the ally.

Item 4 of "The build" (Admin ends a live contract) was built and taken
back out; it is decided on its own, after this.

For this design, interact with Jessica at each step before moving
forward.

## The model: three authorities, one answer

The scada does two distinct things with dispatch: it **refuses** slow
dispatch contracts from the start, offer by offer, and it **breaks** a
specific slow dispatch contract it already holds. The authorities over
both fall in two groups, by when the fact is knowable:

**On file, decisive before boot.** Three files, three owners. Each
refuses from the first offer, and a person can read the refusal off
the box without the scada running.

| Authority | Owner | What it decides |
|---|---|---|
| The `ta.deed` on file | a TaValidator | whether this terminal asset has standing to trade: refuses, and breaks a held contract if it goes away |
| `DispatchHold` in the `gw.operational.params` file | a person, and one latch | whether the operator is holding the house out, and whether the service contract stands broken: refuses from the start |
| The layout's disabled channels | the layout author | whether a channel the family's control requires is disabled, which blinds the scada for the whole run (`ScadaBlind`) |

**Observed while running.** The code owns these: whether Admin has the
house (`InAdmin`: refuses, and breaks a held contract); whether a
channel the family's control requires has gone stale (`ScadaBlind`:
refuses, and breaks a held contract); and the moment the service
contract breaks (the cold latch), which breaks the held contract and is
written into the ops word's `DispatchHold` so every later offer is
refused.

The authorities interact in one direction only. The running code decides
when the service contract breaks and writes that into the ops word;
nothing else writes across. The deed is never copied anywhere, and the
ops word never copies the layout.

The scada answers one question from these, at the moment it is asked:
`dispatch_refusal`, a property on the Scada actor returning
`DispatchRefusalReason | None`. It is computed, never stored. Every
reader of "does this scada dispatch" reads it: the offer handler, the
per-heartbeat check on a held contract, the stored-contract decision at
restart, and `house_operating_status`, so the LTN's standing view and
the per-offer answer come from the same function. `derived_generator`
keeps reading the ops word's hold for its energy estimate: whether to
estimate does not flip on an Admin session.

## The precedence table

Ordered by permanence, most permanent first, so a log line names the
reason that will still be true tomorrow:

| # | Fact | Reason | Source |
|---|---|---|---|
| 1 | the deed does not grant dispatch | `NoTaDeed` | the deed file, read now |
| 2 | the ops word's `DispatchHold` says the operator holds the house | `OperatorHold` | the ops word |
| 3 | the ops word's `DispatchHold` says the service contract is broken | `ServiceContractBroken` | the ops word; set by the code |
| 4 | a channel the family's control requires is disabled in the layout or not fresh | `ScadaBlind` | the hydronic predicate; set by the code |
| 5 | `top_state` is Admin | `InAdmin` | the Scada actor |
| | none of the above | `None`: the scada takes the contract | |

`Standby` is not a reason. The ops word's axiom makes Standby imply
`OperatorHold` (see "Sema brief"), so a standby house refuses as a held
house. `NoAggregator` is not a reason either until the LTN can prove it
is the aggregator; nothing authors or sets it today.

**Every family has a leaf ally.** Nolan's transactive path is not
built yet, and its `NolanLeafAlly` today suits up on a contract and
does nothing with it, while spruce's ops file refuses with
`NoAggregator` to cover for that. Both go. Until the Nolan ally is
built, spruce's ops file says `OperatorHold`, which is true: the
operator holds the house out because nothing can serve a contract.
`NolanLeafAlly` keeps the handshake shape and raises
`NotImplementedError` from `wake_up`, pinned by a test, so the stub
cannot grow back into accepting. The scada's in-process dispatch
catches an actor's raise, logs it and sends an Error glitch, so a
contract that reaches the stub is loud and the scada stays up.

**The deed check has content.** `deed_grants_dispatch(deed, layout)` in
`sema_to_dc.py`, beside the other cross-word checks, is true when a
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
- **A termination after.** `AllyGivesUp` → `TerminatedByScada` remains
  the one path for ending a contract the scada holds, and the
  terminating heartbeat names the reason in the same enum. Its cases:
  the cold latch (`ServiceContractBroken`), a stored contract not
  resumed at restart because the property now refuses, the deed lost
  mid-contract (`NoTaDeed`), the buffer going stale mid-contract
  (`ScadaBlind`), and Admin waking mid-contract (`InAdmin`).

The per-heartbeat check on a held contract evaluates `dispatch_refusal`
at each LTN heartbeat, the same moment it re-reads the deed. Nothing is
written to the params file by these checks; the deed and the sensing are
the truth and may come back.

**Admin mid-contract ends the contract.** `admin_wakes_up` with a live
contract goes through `process_ally_gives_up` with `InAdmin` before
`AutoGoesDormant`. The silent resume in `auto_wakes_up` (a heartbeat
found after Admin times out) becomes unreachable and goes. The cost is
re-offer latency: the LTN consumed its next-contract energy when it made
the offer, so after Admin times out the house sits in local control
until the next price tick. That is accepted for now; see "Open".

## ScadaBlind: one predicate

Today four separate "enough data" judgments exist, two per family, each
with its own five-minute clock: local control's blind check in each
family, the House0 ally's bail clock, and nothing at all in the Nolan
ally. Under a contract local control is Dormant, so no one evaluates
blindness while dispatch is live.

They collapse to one predicate in the hydronic layer, `buffer_fresh` on
`hydronic/nolan.py` and `hydronic/house0.py`: every channel the family's
control needs (Nolan: the band, depth1 and depth3; House0: the
effective buffer channels) has a read time inside the channel's
nyquist bound, 2.1 capture periods. A `None` read time is stale, which
covers a channel flushed by `ChannelFlatlined` and one never read. The
Nolan band's private fixed 300 s clock goes; House0's presence-only
check goes.

Readers: local control (`MissingData` / `DataAvailable`, as now), the
gate (reason 4 above, at the offer and at each heartbeat), and the
ally, which no longer judges for itself.

**A disabled required channel blinds at boot.** It never arrives, so
there is nothing to wait for; the refusal is immediate and lasts the
run. The daily `disabled-roster` Warning glitch adds one clause when
the disabled set intersects the family's required channels: these
channels are required for dispatch, the scada is blind and refuses
every offer. The required set is named once, beside the predicate; the
layout's disabled set is about what the house can serve and is larger.

`ScadaBlind` is a derived scada-level fact. It also goes on
`gw.house.operating.status` beside `TopState`, so the LTN's standing
view says blind and the per-offer rejection is the backstop.

## The ally awaits its inputs

The House0 ally once gave a contract up when it held no heating
forecast, a guard against the race between the first forecast and the
first contract. This spoke removes the race instead of dodging it: the
ally never decides about data and never gives up for want of it. The
scada refuses before a contract reaches the ally. The ally does
*depend* on data: `is_buffer_empty` answers False without a forecast
and `is_buffer_full` falls back to MaxEwtF, so a first judgment before
the first forecast picks the wrong state. (No decision on the ally's
path reads `required_energy`; `required_kwh` has no caller.) The
Initializing gate, bail clock, `missing_inputs` and the forecast check
in `wake_up` are gone (`8c6078fa`); the rest of the polled Initializing
goes with the build below.

**`initialize` is the only Initializing judgment.** `wake_up` sends
SuitUp, moves Dormant to Initializing, initializes the actuators, and
spawns one task:

```python
async def initialize(self) -> None:
    await self.data.first_forecast.wait()
    await self.data.buffer_fresh_once.wait()
    if self.state != LeafAllyAllTanksState.Initializing:
        return
    self.get_temperatures()
    self.engage_brain()
```

Four other paths judge while Initializing today, and each goes:

- `process_slow_dispatch_contract` calls `engage_brain` right after
  `wake_up` (`all_tanks.py:196`), and a second contract while
  Initializing reaches the same call. The handler skips `engage_brain`
  while Initializing; the task judges.
- `main` calls `engage_brain` every 60 s in every state but Dormant
  (`all_tanks.py:376`). It skips Initializing too.
- The `SyncedReadings` re-judgment while Initializing
  (`all_tanks.py:172`) goes.
- `StopNonElectricBackup` returns the ally to Initializing
  (`all_tanks.py:71`) with no task. That transition spawns `initialize`
  as `wake_up` does. The state check inside `initialize` is for this
  and for GoDormant: either can arrive during the awaits.

`engage_brain` in Initializing with no forecast is a real path, not an
unreachable one: the LTN keeps the scada's layout.lite across scada
restarts (`ltn.py:522`) and its price-driven offer path never asks for
a fresh one (`ltn.py:1256`), so an offer can reach a freshly booted
scada before its first forecast. The await is the guarantee; the branch
logs a Warning glitch and returns, a defect report rather than a
decision.

**The task is the ally's.** It is kept on `self` and cancelled before
it is replaced, as the scada keeps `contract_task` and
`_admin_timeout_task` (`scada.py:1245`); GoDormant cancels it; a
done-callback logs and sends an Error glitch when it ends in an
exception. Not `services.add_task`: the proactor copies its task list
once at join (`proactor_implementation.py:881`), so a task added later
is never joined and its exception is lost.

**Two readiness events on `ScadaData`**, one per shared fact, both
`asyncio.Event`, both one-shot. Every actor runs on the one loop and
reads the one data object, so no message is involved. `asyncio.Event`
binds its loop at first await on 3.12, so constructing one in
`ScadaData` is safe.

- `first_forecast`: set by the derived generator right after it stores
  the first `HeatingForecast` (`derived_generator.py:1102`).
- `buffer_fresh_once`: set by the scada the first time `buffer_fresh`
  is true, on its reading path (`process_synced_readings`,
  `process_single_reading`). It is the one-shot of the `ScadaBlind`
  predicate, so a scada that is not blind has, by construction, a
  buffer the ally can judge. One-shot is right: later blindness is the
  per-heartbeat gate's, which ends the contract with `ScadaBlind`.

**One availability word.** `buffer_temps_available` (the `ScadaData`
flag written at `house0.py:744`, read by the derived generator, the
House0 local controls and both House0 allies) asks the same question
as `buffer_fresh` at a later point in the pipeline, with one extra
filter: that every buffer value converted to a plausible °F. Only the
House0 surface writes it; a Nolan scada never sets it, so on spruce it
is False for the whole run and the derived generator's two reads on it
return early. It goes: every reader asks `buffer_fresh`, and the
plausibility filter moves into `channels_fresh` if a reading can be
fresh and unconvertible, else is dropped. `is_buffer_ready` (charge
for the coming on-peak window) and the LTN's `get_buffer_available_kwh`
(stored energy) are other questions and keep their names.

A layout with no buffer tank is ScadaBlind for the run (`shared.py:33`:
a channel the layout lacks is stale), against the rule that scada code
never assumes a buffer. The dispatch-channel set is per family
(`house0.py:40`, `nolan.py:12`), so the fall layouts each name theirs;
in Open.

**A first forecast is not certain.** `get_forecasts` returns silently
when the weather source gives None (`derived_generator.py:1074`), which
it does when the bundle on file no longer matches the pulled forecast
and a fresh bundle is unreachable (`weather_source.py:262`); an
exception kills the fetch and the proactor only logs it. The generator
retries until the first forecast is stored, with a Warning glitch per
miss. The retry is the generator's, not the ally's, and no bail clock
returns; the seasonal template keeps a forecast the normal case, the
retry is for the abnormal one.

Forwarding later forecasts to the ally as a trigger, and retiring the
60 s pass, is OPS-532's event-driven redesign; this spoke takes the
first judgment only.

## The startup order

The LTN cannot offer until it has the scada's layout.lite, sent by
`send_startup_announcements` once the upstream link can publish. The
derived generator's first act is the forecast fetch: the scada keeps
pulling from the gwwf API for now, and the LTN relay that replaces the
pull is `ltns-ready.md`'s ("What the scada takes from the LTN").
`announce_at_first_broker_link` awaits both: the link, and
`first_forecast`. Holding the deed and the operating status back with
the announcement costs nothing: the operating status goes out from
`state_tracker` on its own. With this order both of the ally's awaits
return at once in the normal case; the ally states its needs in its
own code, and the scada's ordering is a guarantee rather than an
assumption the ally cannot see. The order does not make an early offer
impossible (an LTN that already has the layout.lite offers at the next
price); the ally's await covers that case.

**The resume runs as its own task.** The stored-contract resume at
boot awaits `first_forecast` too: waking the ally under a resumed
contract with no forecast is the same wrong first judgment through
another door. The resume is called at the top of `state_tracker`
(`scada.py:1616`); an await there would stall consistency enforcement
and the operating-status reports for as long as the first fetch takes
(a 20 s pull timeout, up to three pulls). In that window an LTN
continuation heartbeat for the loaded contract would get an Active
reply while LocalControl runs the house, and the loaded heartbeat the
resume sends later would be dropped by the LTN as out of order
(`ltn/contract_handler.py:167`). So the resume is a task of its own,
spawned from `start_tasks` beside `state_tracker`; until it has run,
continuation heartbeats for the loaded contract are logged and
dropped.

**Every contract the ally gets goes through one helper.** Two wake
paths send a contract to the ally without consulting
`dispatch_refusal`: `auto_wakes_up` after Admin (`scada.py:1156`) and
the consistency resend when the ally is found Dormant
(`scada.py:1479`). One helper on the scada sends every contract to the
ally and checks the refusal first; the offer handler and the resume
use it too.

## The ops word

`gw.operational.params` loses `AcceptsDispatch` and
`DispatchRefusalReason`. It gains one field, `DispatchHold`, a
`gw.dispatch.hold`: two booleans, each a fact its writer owns,
`OperatorHold` (the person) and `ServiceContractBroken` (the cold latch
writes it; a person clears it by editing the file). The word's name and
description say what it is: a hold the file places on dispatch, one of
three authorities, not the answer. The deed and the running scada can
refuse a house with no hold at all. Axiom: Standby implies
`DispatchHold.OperatorHold`. Accepting dispatch is derived everywhere.
`process_break_service_contract` keeps its shape and sets the boolean.

## Sema brief

What the words say, on `sema` branch `jm/contract-refusal`.

- **`gw.dispatch.refusal.reason`** (staging, in place). Values
  `NoTaDeed`, `OperatorHold`, `ServiceContractBroken`, `ScadaBlind`,
  `InAdmin`; default `OperatorHold`, the no-harm decode fallback. The
  scada's one vocabulary for declining or ending dispatch, stated by
  the rejection and the terminating heartbeat alike.
- **`gw.dispatch.hold`** (new, staging). Flat: `OperatorHold: bool` and
  `ServiceContractBroken: bool`, both required. Its description names
  the other two authorities.
- **`gw.operational.params`** (staging, in place). `DispatchHold:
  gw.dispatch.hold`, required; no `AcceptsDispatch` and no reason.
  Axiom 3 "Standby implies DispatchHold.OperatorHold"; the posture and
  full-send axioms are 4 and 5.
- **`slow.contract.rejection`** (staging, in place). `Reason:
  gw.dispatch.refusal.reason` in place of a validation state.
- **`slow.contract.heartbeat`.** 001 is published: the wire form the
  scada has sent since `8898a88c`, with its closure
  `slow.dispatch.contract` 000, `gw1.slow.dispatch.contract.status` 000
  (a leading `Unknown` default) and the integer format `decimal.digit`,
  all published. 002 is staging: `Reason` (optional,
  `gw.dispatch.refusal.reason`) beside the free `Cause`, present iff
  `TerminatedByScada` (axiom 6). Its axioms are numbered 1 to 5 in 001
  and 1 to 6 in 002; the gwsproto class numbers them differently and
  skips one, and its mirrors renumber to match.
- **`gw.house.operating.status`** (staging, in place). `AcceptsDispatch`
  and `DispatchRefusalReason` are the derived answer; `ScadaBlind: bool`
  is required. Axiom 2: Standby refuses as `OperatorHold`.

The gwsproto twins follow in the same wave as the snapshot refresh,
with `check_axiom_<n>` mirrors; the closure test names what is missing.
The gwsproto status enum's `enum_name` says `gw1.contract.status` and
must say `gw1.slow.dispatch.contract.status`; the heartbeat class moves
to 002.

## The build

In `gridworks-scada`, on `jm/spruce-unlimbo`, after the snapshot:

1. `buffer_fresh` on both hydronic classes; local control reads it;
   the Nolan clock and the House0 presence check go.
2. `deed_grants_dispatch` in `sema_to_dc.py`.
3. `dispatch_refusal` on the Scada actor; the offer handler, the
   per-heartbeat check, `resume_loaded_contract`,
   `house_operating_status` and `process_break_service_contract` read
   or write through it; the loader wrapper's gate goes.
4. `admin_wakes_up` ends a live contract; the resume in
   `auto_wakes_up` goes. `NolanLeafAlly.wake_up` raises; spruce's ops
   file says `OperatorHold` at the next layout push. (Deferred: decided
   on its own.)
5. The ally's gates, clock and `missing_inputs` go (done); `wake_up`
   and `StopNonElectricBackup` spawn `initialize`, the only Initializing
   judgment; the contract handler, `main` and `SyncedReadings` skip
   Initializing.
6. `first_forecast` and `buffer_fresh_once` on `ScadaData`;
   `buffer_temps_available` goes; the derived
   generator retries the first forecast; the announcement awaits
   `first_forecast`; the resume is its own task and awaits it too; one
   helper sends every contract to the ally.
7. The roster glitch's dispatch clause.

## Tests

- The precedence table as one parametrized test: each row, the reason
  the property returns, and `None` for a clean scada.
- `deed_grants_dispatch`: each clause, both families.
- Offer-time rejection over the in-process LTN+scada pair, each reason:
  the LTN receives the rejection with the reason, the scada's
  `latest_scada_hb` stays `None`, the auto state stays LocalControl,
  `contract_handler.prev` is untouched (no phantom grace period), and a
  second offer at the next price gets the same answer with no store
  movement.
- Admin mid-contract: the LTN receives `TerminatedByScada` with
  `InAdmin`, its heartbeat is `None`; after Admin times out the scada
  is in LocalControl with no contract; the next price's offer is
  accepted.
- In flight: a deed removed between two heartbeats ends the live
  contract with `NoTaDeed`; the params file is unchanged. The same for
  a buffer channel going stale, with `ScadaBlind`.
- `buffer_fresh`: both families, fresh, one stale, never read, flushed
  by `ChannelFlatlined`, and a disabled required channel at boot. The
  roster glitch names the dispatch clause in the last case.
- The ally awaits: with the weather source's first fetch held open by
  the sim pin (an `asyncio.Event` gate on `SimWeatherSource`, beside
  `delay_s`) and a contract delivered to the ally directly, the ally
  is in Initializing with SuitUp sent and the heat pump off, and makes
  no judgment through a 60 s `main` pass or a second contract; opening
  the pin runs the first judgment at once, with a forecast, and no
  Warning glitch. GoDormant while held cancels the task.
- Startup order: with the fetch held open and the LTN primed to offer
  at once, no layout.lite leaves the scada and `state_tracker` keeps
  reporting; opening the pin sends the announcement and the offer is
  accepted.
- Stored-contract resume: with the fetch held open, the loaded
  contract is not given up, no heartbeat leaves the scada, and an LTN
  continuation heartbeat is dropped; opening the pin sends the loaded
  heartbeat and the ally judges.
  `test_a_resumed_contract_with_no_forecast_stays_live`
  (`test_startup_contract_load.py:161`) expects the heartbeat while
  the fetch is held and is rewritten to this.
- First-forecast retry: the weather source answers None twice, then a
  forecast; `first_forecast` is set after the third fetch, with two
  Warning glitches.
- A deedless scada boots and refuses; only the dispatch tests seed a
  deed, through the config-dir fixture.
- Nolan: `NolanLeafAlly.wake_up` raises `NotImplementedError`; a
  contract handed to it produces an Error glitch and the scada keeps
  running.

## Verification (EDD)

An LTN offering a contract over the dev broker to a scada that refuses
for each reason, the rejection seen at the LTN with the reason; then a
contract taken and ended by each termination case. Runs in dev against
the simulated houses.

## Open

- Re-offer after Admin: whether the LTN re-offers when the operating
  status returns to Auto rather than waiting for the next price, or a
  contract can be re-established. Later work; a five-minute Admin
  session mid-hour is the case that will ask for it.
- `is_buffer_empty` answers False without a forecast, so the cold
  latch cannot judge the stores in the seconds before the first
  forecast. Closed in practice by the startup order; a forecast-free
  store judgment is the real fix and the water-tank-free fall layout
  will force it.
- A layout with no buffer tank is ScadaBlind for the run under the
  per-family dispatch-channel sets. The fall layouts each name the
  channels their control needs; the family that has no tanks at all
  decides what "blind" means there.
- Both allies swallow exceptions in `process_slow_dispatch_contract`
  with a logged try/except, so a failing cold-zone lookup silently
  drops a contract. A pipes-clearing item, not this spoke.
- Where this distills on completion: a new executor spoke,
  `dispatch-gate.md`, owning the three authorities, the predicate, the
  precedence table and the two messages; `cold-house.md`, `admin.md`
  and `sensing-hierarchy.md` each get a one-line pointer where they feed
  the gate.
