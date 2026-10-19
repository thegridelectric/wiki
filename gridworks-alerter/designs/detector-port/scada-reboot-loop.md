# scada-reboot-loop — layouts arriving in a loop

Status: Draft · Pass 0 · Updated 2026-10-19

> What this is: the port of gwalert's `check_rebooting`
> (`alert_generator.py:1213`) as `ScadaRebootLoop`.

## gwalert today

Buckets `layout.lite` message times into 5-minute bins and alerts when
a bin holds more than 5, inline numbers. Alias `rebooting`.

## The port

- **Reads:** layout arrival times. The store keeps the latest layout
  per scada and one arrival row per alias, so neither has the times
  this rule counts. Add a `layout_arrivals` table (scada, received_ms),
  pruned to the window, by migration.
- **Fires** when more than `reboot_loop_count` (5) layouts arrive from
  one scada inside `reboot_loop_window_s` (300); **resolves** when a
  full window passes with fewer.
- **Tests:** six layouts in five minutes fires once; a quiet window
  resolves; five does not fire; restart with the alert open.

## Do this next

The `layout_arrivals` migration, then the pattern in the hub.
