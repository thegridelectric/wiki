# zone-freeze-risk — a zone below the freeze-risk threshold

Status: Draft · Pass 0 · Updated 2026-10-19

> What this is: the port of gwalert's `check_zone_freezing`
> (`alert_generator.py:783`) to the alerter as `ZoneFreezeRisk`.

Wait on `jm/spruce-unlimbo` in gridworks-scada: that merge has the
scada raise a zone under the freeze line as a Critical glitch, so the
condition is judged on the box and paged through `critical-glitch.md`.
This spoke is deleted when it merges.

## gwalert today

Reads the zone channels and picks a role by name suffix (`-temp`,
`-floor-temp`, `-gw-temp`), converts by the channel's unit
(`units.py`), and alerts when the latest value is below 40 F, inline.
Skips houses in Standby. Missing data logs. Alias
`zone_freezing_<zone>`; one alert per zone per day by alias.

## The port

- **Reads:** the latest reading of each zone's air, floor or gw
  temperature channel from `readings`, the channel's unit and role from
  the stored `layout.lite` (its data channels and the zone each
  belongs to). Preference air, then floor, then gw, as gwalert.
- **Fires** when the preferred reading is below `zone_freeze_risk_f`
  (40, a setting) and the house's system mode is not Standby;
  **resolves** when a later reading on the same channel is at or above
  it. `AboutGNodeAlias` the house; the zone and the reading in
  `Evidence`.
- **Layout:** a house with no zone temperature channel has no
  `ZoneFreezeRisk`. 40 F is not freezing; the name says risk and the
  kind's description states the number.
- **Tests:** below threshold fires once; a reading back above resolves
  under the same `AlertId`; Standby suppresses; a house without a zone
  sensor is absent; a restart with the alert open neither re-raises nor
  forgets.

## Do this next

Nothing until the merge; then delete this spoke and switch gwalert's
`check_zone_freezing` off once `CriticalGlitch` pages for it.
