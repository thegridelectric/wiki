# Leaf ally

Status: Accepted · Pass 1 · Updated 2026-10-14

> What this is: the transactive side of the scada's handoff. The leaf
> ally runs the house under a slow dispatch contract; this spoke states
> how it comes to its first judgment, what it depends on, and the order
> the scada guarantees at startup. The gate that decides whether a
> contract reaches it is `dispatch-gate.md`; the non-transactive side
> is `local-control.md`.

## The ally never decides about data

The scada refuses before a contract reaches the ally, so the ally never
gives a contract up for want of data. The ally does *depend* on data:
`is_buffer_empty` answers False without a forecast and `is_buffer_full`
falls back to MaxEwtF, so a first judgment before the first forecast
picks the wrong state. The ally states that dependency in its own code,
as awaits.

**`initialize` is the only Initializing judgment** (both House0
allies; `all_tanks.py` "def initialize", `buffer_only.py`
"def initialize"). `wake_up` sends SuitUp, moves Dormant to
Initializing, initializes the actuators, and spawns one task that
awaits `first_forecast`, then `buffer_fresh_once`, re-checks that the
state is still Initializing, reads the temperatures and judges. No
other path judges while Initializing: `process_slow_dispatch_contract`
returns in that state, and `main` skips its 60 s judgment there.
`StopNonElectricBackup` returns the ally to Initializing and spawns
`initialize` as `wake_up` does; the state check inside the task covers
that transition and GoDormant, either of which can arrive during the
awaits.

`engage_brain` in Initializing with no forecast is a reachable path:
the LTN keeps the scada's layout.lite across scada restarts and its
price-driven offer path never asks for a fresh one, so an offer can
reach a freshly booted scada before its first forecast. The await is
the guarantee; the branch sends the Warning glitch
`judged-without-forecast` and returns, a defect report rather than a
decision.

**The task is the ally's.** It is kept on `initialize_task`
(`spawn_initialize` / `cancel_initialize`) and cancelled before it is
replaced; GoDormant cancels it; a done-callback sends the Error glitch
`leaf-ally-initialize-failed` when it ends in an exception. Not
`services.add_task`: the proactor copies its task list once at join, so
a task added later is never joined and its exception is lost.

**Two readiness events on `ScadaData`**, one per shared fact, both
`asyncio.Event`, both one-shot. Every actor runs on the one loop and
reads the one data object, so no message is involved.

- `first_forecast`: set by the derived generator right after it stores
  the first `HeatingForecast` (`derived_generator.py` "first_forecast.set").
- `buffer_fresh_once`: set by the scada the first time `buffer_fresh`
  is true, on its reading path (`scada.py` "buffer_fresh_once.set").
  It is the one-shot of the `ScadaBlind` predicate, so a scada that is
  not blind has, by construction, a buffer the ally can judge. Later
  blindness is the per-heartbeat gate's, which ends the contract with
  `ScadaBlind`.

Forwarding later forecasts to the ally as a trigger, and retiring the
60 s pass, is OPS-532's event-driven redesign.

## The startup order

The LTN cannot offer until it has the scada's layout.lite, sent by
`send_startup_announcements` once the upstream link can publish. The
derived generator's first act is the forecast fetch.
`announce_at_first_broker_link` (`scada.py`
"async def announce_at_first_broker_link") awaits both: the link, and
`first_forecast`. Holding the deed and the operating status back with
the announcement costs nothing: the operating status goes out from
`state_tracker` on its own. With this order both of the ally's awaits
return at once in the normal case, and the scada's ordering is a
guarantee rather than an assumption the ally cannot see. The order does
not make an early offer impossible (an LTN that already has the
layout.lite offers at the next price); the ally's await covers that
case.

**The resume runs as its own task.** The stored-contract resume at
boot, `resume_at_first_forecast` (the `contract_resumer` task spawned
from `start_tasks`), awaits `first_forecast` too: waking the ally under
a resumed contract with no forecast is the same wrong first judgment
through another door. It is not awaited inside `state_tracker`, where
it would stall consistency enforcement and the operating-status reports
for as long as the first fetch takes; in that window an LTN
continuation heartbeat for the loaded contract would get an Active
reply while LocalControl runs the house, and the loaded heartbeat sent
later would be dropped by the LTN as out of order. Until the task has
run, continuation heartbeats for the loaded contract are logged and
dropped (`scada.py` "Dropping continuation hb").

**One sender, one ender.** `send_contract_to_ally` checks
`dispatch_refusal` first and is the one way a contract reaches the
ally: the offer handler, the contract-live transition after Admin, the
resume, and the consistency resend when the ally is found Dormant.
`end_contract(reason, cause)` is the one way a held contract ends: the
ally's give-up, the per-heartbeat refusal and `admin_wakes_up` all call
it (`dispatch-gate.md` "The answer").

## Open

- `NolanLeafAlly` suits up on a contract and does nothing with it;
  spruce's ops file says `OperatorHold` until the Nolan ally is built.
- Both House0 allies wrap `process_slow_dispatch_contract` in a logged
  try/except, so a failing cold-zone lookup drops a contract silently.

## Tests

| Behavior | Test |
| --- | --- |
| The ally awaits its inputs: with the first fetch held open and an offer taken, Initializing with SuitUp sent and no judgment through `main` passes or a second contract; opening the pin judges at once with a forecast; GoDormant while held cancels the task; the announcement waits for the first forecast; the first forecast is retried with a Warning per miss | `tests/actors/test_ally_initialize.py` |
| A resumed contract waits for the first forecast: not given up, no heartbeat out, an LTN continuation dropped; then the loaded heartbeat and the judgment | `tests/actors/test_startup_contract_load.py` |
