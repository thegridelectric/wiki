# Atomic report event axiom

Status: Draft · Pass 0 · Updated 2026-10-23 · Linear: OPS-619

**EDD: no** a fix to one report shape and the twin that should have refused
it, verified by the suite and the next branch boot journaling its 5-minute
report with a valve move in it.

> What this is: the sieg loop's own `fsm.atomic.report` for a valve move
> the strategy chose has no event, the journal refuses the whole
> `report.event` that contains it, and the scada's twin never noticed because
> its axioms are stubs. The fix, and the same latent defect in hp-boss.

## The field evidence

Two `report.event` messages failed to decode at the JournalKeeper on
2026-10-23 with the same error:

```
Codec decode failed from hw1.isone.me.versant.keene.oak.scada: SemaError("Validation failed:
1 validation error for ReportEvent
Report.FsmReportList.20.AtomicList.6
  Value error, Axiom 2 failed: event fields must be present if and only if report_type is Event.
```

Oak at 05:45:03Z (01:45 ET) and again at 07:10:06Z, maple at 07:15:00Z
(03:15 ET, `FsmReportList.14.AtomicList.6`). The payloads are in the S3
eventstore (`gwdev` bucket):

```
hw1__1/eventstore/20261023/hw1.isone.me.versant.keene.oak.scada-report.event-1792734305589-hw1.ear.json
hw1__1/eventstore/20261023/hw1.isone.me.versant.keene.maple.scada-report.event-1792739701308-hw1.ear.json
```

In both, the failing entry is a seven-atomic full report from `sieg-loop`:
six relay atomics (the keep-send relay, the on-off relay closing, the
on-off relay opening, each with its pin report) and then the loop's own:

```
MachineHandle auto.lc.n.sieg-loop   StateEnum sieg.valve.state   ReportType Event
EventEnum None   Event None   FromState FullyKeep   ToState FullySend
```

It is the boot move to full send that `HoldFullSend` makes: oak's motor
stopped at 01:44:29 ET and the 01:45 report failed; maple reached
`ResetToFullySend` at 03:13:44 ET and the 03:15 report failed. The
journal's runtime enforces `fsm.atomic.report/001` axiom 2 (EventEnum,
Event, FromState and ToState present if and only if ReportType is Event)
and refuses the whole `report.event`, so every house on
`jm/spruce-unlimbo` loses the five-minute report in which its valve
finished a move the strategy chose. On `HoldFullSend` that is the boot
move; on `StratProtect` it would be every automatic move.

## Why the scada lets it through

Three things line up behind it:

- `gw_spaceheat/actors/sieg_loop/__init__.py` `move_ended` builds the
  loop's atomic with `Event=move.event`, and a `Move` the strategy chose
  has `event` None by design (the `Move` docstring in `valve.py`: "event
  is the boss's command when the move was commanded, None when the
  strategy chose it").
- The scada's gwsproto twin `fsm_atomic_report.py` has both axioms as
  empty stubs, so the scada never notices. The scada protocol says every
  sema axiom is mirrored as a `check_axiom_n` validator.
- `tests/actors/test_sieg_loop.py` line 496 asserts EventEnum and Event
  are None for that very report, so the suite pins the defect.

A fourth instance waits in `hp_boss.py` line 278: the `StratProtect`
two-minute sieg-ready timeout path calls `transition(HpOff, None)`, an
Event report with no event. Nobody has hit it yet.

## The fix

1. Implement axiom 1 and axiom 2 in the twin, numbered as the snapshot's
   `fsm.atomic.report/001` has them. The scada then refuses to build such
   a report, and the sieg test fails on its own.
2. The loop's own atomic for a strategy-chosen move reports the move the
   strategy chose, in the vocabulary the boss would have used: EventEnum
   `move.sieg.valve`, Event `MoveToFullSend` for a run toward send,
   `MoveToFullKeep` toward keep, `StopValve` for a stop. The `Move`
   record keeps `event` None as the commanded-or-not flag; the reported
   event comes from the run's direction. An alternative not taken: naming
   the valve's internal `SiegValveEvent` (ResetToFullySend and friends),
   which has no sema enum, so EventEnum would name vocabulary that exists
   nowhere.
3. hp-boss's timeout path reports `TurnOff`, which is what it does.
4. Tests: the sieg test at line 496 flips to assert the event; a new test
   validates the boot-move full report through the twin with the axioms
   live; an hp-boss test for the timeout path's report.

Then push and roll; the branch houses stop dropping reports from the
next boot.

## Open

- Whether the `Move` record should instead take a real event at creation
  for automatic moves, making `event` the single truth and dropping the
  commanded-or-not reading of None. The fix above keeps the record as it
  is.
