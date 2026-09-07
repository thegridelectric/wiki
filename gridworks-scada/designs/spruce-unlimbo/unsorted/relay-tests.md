# relay-tests (unsorted item)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: an unsorted item; hub [`primary.md`](primary.md). The
> tests the hp-boss witness of 2026-09-07 did not give us. That witness
> (`experiments/2026-09-07-hp-boss-admin-drive/`, rung 3 on honeysuckle)
> covered one path: admin to hp-boss to the call relay on a Nolan
> layout, the relay confirming at the pin, release back to LocalControl.
> Everything below is what stays unexercised, each with the test that
> closes it. Parked 2026-09-07.

## The gaps, each with its test

1. **The sieg-loop strategy end to end.** `PreparingToTurnOn` waiting on
   `SiegLoopReady` has only run in-process with the ready message
   delivered by hand (`tests/actors/test_hp_boss.py`). Test: the
   House0 rows of `tests/actors/test_hp_boss_live.py` uncommented, with
   the sieg-loop actor on the sim plant actually sending `SiegLoopReady`
   (carried in `refactor-sieg.md`). A second case: no ready message
   arrives and `TURN_ON_ANYWAY_S` closes the relay anyway, with the
   constant shortened through settings rather than the clock.
2. **Failed confirmation and the retry loop.** The relay's
   command-and-confirm path (`actors/relay.py` `_attempt_command`,
   `_verify_and_report`) has never failed in a test: readback
   disagreeing with the write, a bus op timeout, the `_i2c_command`
   enforcement target retried on the next verify pass, the Critical
   glitch sent to the boss. Test: a sim i2c bus that can be told to
   fail the next read or write; assert the glitch, the state staying
   put, and the commit on the retry once the fault clears.
3. **Superseded commands.** A newer command arrives while an older one
   is still unconfirmed; `_commit_command` must drop the older one
   (`self._i2c_command is not command`). Test: two dispatches in quick
   succession with the sim bus slowed; assert one report per TriggerId
   and the final state matching the last command.
4. **Boot adoption on a readback board.** `_boot_adopt` reads the pin
   and adopts the state without writing (`UNKNOWN_STATE` until then).
   Test: a sim bus preloaded with the pin high, the relay adopting
   `EnergizedState` at start and reporting a self-loop, and a command
   received before adoption deferred, not lost.
5. **The relay report reaching hp-boss.** hp-boss receives
   `FsmFullReport` (the `case FsmFullReport()` in `hp_boss.py`) and
   does nothing visible with it. Proposal: hp-boss notes confirmation
   and alerts when the relay reports failure, unchanged across gw108,
   Krida and the Krida-retired boards (why it must not wait:
   `executor/control-hierarchy.md` "Fixed sub-trees vs floating
   actuators"). Test, once that lands: a report with a failed
   transition produces an alert; a good one is noted.
6. **The heat pump answering.** Nothing is wired to the bench relay;
   the pin was the witness. The honest on/off signal is
   `hp-odu-pwr`. Test on the sim plant: the plant's heat pump model
   draws power after the call closes and stops after it opens, with
   the delay a real unit shows; the assertion is on the power channel,
   not the relay state.
7. **Steady state.** Every run lasted under a minute. Test: a sped-up
   sim run through several TOU windows, LocalControl commanding
   hp-boss at each boundary, the relay state matching the schedule
   throughout, no enforcement retries, no admin involvement.
8. **The commandable node.** `Hydronic.HpCommandNodeName` dispatch
   (native modbus `hp-odu`, or `hp-ctrl-box` via the MIM) has no
   layout to run on. Test when a fixture carries it: hp-boss commands
   that node instead of the relay, and the `CommandableHeatPump` axiom
   rejects a layout naming a node that is not under hp-boss. Rides
   `hp-twin.md`.
9. **Krida and the no-report boards.** `_krida_actuate` is commanded
   belief with no report to the boss. Test on a House0 fixture: the
   relay state changes on command, no `FsmFullReport` is sent, hp-boss
   does not wait for one. Krida-retirement decides how long this
   matters.

## Where they run

Items 2, 3, 4 and 9 are in-process on the sim board and belong beside
`tests/actors/test_hp_boss.py` as a relay test file of their own. Items
1, 6 and 7 need the live harness and the sim plant. Item 5 waits on the
hp-boss proposal; item 8 on a fixture. The witness on real hardware for
any of them stays the bench (honeysuckle), per the hub's EDD bar.
