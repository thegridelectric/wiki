# zone-freeze-risk — a zone below the freeze-risk threshold

Status: Draft · Pass 0 · Updated 2026-10-16

> What this is: the port of gwalert's `check_zone_freezing`
> (`alert_generator.py:783`) to the alerter as `ZoneFreezeRisk`.

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
- **The scada's zone-freezing glitch** judges the same condition on
  the box. Decide here which pages: proposed, the alerter's kind pages
  (it resolves; a glitch is a moment), and the glitch is evidence.
- **Tests:** below threshold fires once; a reading back above resolves
  under the same `AlertId`; Standby suppresses; a house without a zone
  sensor is absent; a restart with the alert open neither re-raises nor
  forgets.

## Do this next

Tests first, then the rule as `zone_freeze_risk.py` beside `no_data.py`,
the dev-broker witness, the shadow week, then comment gwalert's
`check_zone_freezing` out of `main`.
