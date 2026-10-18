# scada-reboot-loop — layouts arriving in a loop

Status: Draft · Pass 0 · Updated 2026-10-16

> What this is: the port of gwalert's `check_rebooting`
> (`alert_generator.py:1213`) as `ScadaRebootLoop`.

## gwalert today

Buckets `layout.lite` message times into 5-minute bins and alerts when
a bin holds more than 5, inline numbers. Alias `rebooting`.

## The port

- **Reads:** layout arrivals. The store keeps the latest layout per
  scada, not each arrival, so the rule needs the arrival times: add a
  `layout_arrivals` query over the `arrivals` table if envelope-level
  rows are enough (one row per alias is overwritten today, so they are
  not), or a small `layout_arrivals` table (scada, received_ms) pruned
  to the window. State the choice here before the migration.
- **Fires** when more than `reboot_loop_count` (5) layouts arrive from
  one scada inside `reboot_loop_window_s` (300); **resolves** when a
  full window passes with fewer.
- **Layout:** none assumed; every scada sends a layout at boot.
- **Tests:** six layouts in five minutes fires once; a quiet window
  resolves; five does not fire; restart with the alert open.

## Do this next

Settle the arrivals question, then tests, rule, witness, shadow week,
gwalert's check off.
