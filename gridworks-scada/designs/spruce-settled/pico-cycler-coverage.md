# Pico-cycler coverage (spoke)

Status: Draft · Pass 0 · Updated 2026-09-10 · Linear: OPS-532

> What this is: the in-process tests the pico-cycler command work owed
> itself after the dev-broker rung (`experiments/2026-09-07-admin-reboots-picos/`),
> which today have only the broker run behind them. All in
> `tests/actors/test_pico_cycler_command.py` unless noted.

## Do this next

1. The real overlap: cycle A closes, a command opens cycle B, A's reboot
   timer fires into B (short `RELAY_OPEN_S` / `PICO_REBOOT_S`, the
   relay's reports handed back). The two guard tests today only swap the
   cycle id under one wait.
2. The full loop through the sim pico: relay confirms, cycler closes, the
   sim source loses power and posts again `SimRebootS` later, and that
   reading, not a timer, confirms the cycle.
3. The journal path: the cycler's `fsm.full.report` delivered to the
   scada lands in `report.FsmReportList` under the dispatch's id.
4. The GPIO relay's state committing before its pin write (the FSM
   fires, then actuates; the i2c path is command-and-confirm), in
   `tests/actors/test_relay_gpio_sim.py`.
5. The admin acknowledgement end to end: a command from the panel, the
   ack tracked by `TriggerId`, the toast.

The tank actor's flatline gate is covered already
(`tests/actors/test_pico_liveness.py`).
