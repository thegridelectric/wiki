# hp-running-onpeak — heat pump power in a weekday on-peak hour

Status: Draft · Pass 0 · Updated 2026-10-19

> What this is: the port of gwalert's `check_hp_on_during_onpeak`
> (`alert_generator.py:1167`) as `HpRunningOnpeak`.

## gwalert today

Reads `hp-odu-pwr` and `hp-idu-pwr` by name (monobloc list for the
indoor unit), on-peak hours 7 to 11 and 16 to 19 ET on weekdays, a
2-minute grace at the top of each peak, 1 kW from `v/1000`. Scans the
whole 2-hour window and lets only the first offending hour alert per
house. Alias `hp_onpeak_<hour>`.

## The port

- **Reads:** the heat pump's power channels and model from the layout,
  and the live readings.
- **Fires** when power exceeds `hp_on_kw` (1) inside an on-peak hour
  past its `onpeak_grace_s` (120); **resolves** when power drops below
  or the hour ends. The on-peak schedule comes from the tariff in the
  house's operational params, the same schedule the LTN's dispatch
  uses.
- **Layout:** a house with no heat pump is absent.
- **Tests:** power in peak fires once per hour; power off resolves;
  the grace holds; a weekend never fires; a monobloc reads the outdoor
  unit only.

## Do this next

Scada `main`'s operational params encode the tariff, and the on-peak
schedule is read from there. The pattern in the hub, with the witness
on a sped-up clock.
