# zone-below-setpoint — a critical zone below its setpoint

Status: Draft · Pass 0 · Updated 2026-10-19

> What this is: the port of gwalert's `check_zone_below_setpoint`
> (`alert_generator.py:702`) as `ZoneBelowSetpoint`.

Scada `main` (merged 2026-10-26, `50da8d28`) raises a critical zone
below its setpoint as a Critical glitch, so the condition is judged on
the box and paged through `critical-glitch.md`. This spoke is deleted
once `main` is on the boxes.

## gwalert today

Groups zone channels by name, roles by suffix (`-set` for the
setpoint, air then floor for the temperature; spruce alone prefers gw
by a hard-coded table, `alert_generator.py:95`), the critical zones
from `layout.lite`'s `critical_zone_list` matched by a `zone[6:]` slice,
and alerts when the temperature is more than 2 F (hard-coded) below the
last value seen on the setpoint channel. Spruce's setpoint channels
report only on change and last reported in the summer, so the check
logs "Missing setpoint channel" for spruce every cycle; and because
gwalert cannot tell a persisted setpoint from a fresh one it paged
spruce on 2026-10-08 on a room whose setpoint the scada had just
dropped.

## The port

- **Reads:** the critical zones from the stored layout; each zone's
  setpoint and temperature from `readings`, units from the layout; and
  the zone's setpoint phase from the scada's state reporting, so a
  learned setpoint is checked only while its phase is
  `LastHeatCallEndTemp` and `Unknown` or `Suspect±` is no check at all.
  The word that reports the phase is to be named here before the rule
  is written; if none is published yet, this spoke waits on it rather
  than reading the last setpoint value.
- **Fires** when the temperature is more than `zone_setpoint_tolerance_f`
  (2, a setting) below the setpoint and the setpoint was not raised
  inside `zone_setpoint_grace_s`; **resolves** when the zone is back
  within tolerance or the setpoint drops. Not in Standby.
- **Layout:** only zones with a setpoint source; a house with none has
  no `ZoneBelowSetpoint`. No per-house role table.
- **Tests:** below tolerance fires; back in tolerance resolves; a raised
  setpoint inside the grace does not fire; phase `Unknown` never fires;
  a non-critical zone never fires; restart with the alert open.

## Do this next

Nothing until the merge; then delete this spoke and switch gwalert's
`check_zone_below_setpoint` off once `CriticalGlitch` pages for it.
