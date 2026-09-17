# gwalert — the legacy detector

Status: Draft · Pass 0 · Updated 2026-09-17

> What this is: the legacy house-alert detector **gwalert**
> (`thegridelectric/gridworks-alerts`, package `gwalert`) as it runs on
> the `alerts` box, until gwalerter has taken over its detectors one at
> a time (OPS-545). The hub is [`../executor/primary.md`](../executor/primary.md);
> most detector depth is Open and the code is the authority for detail.

## What it is

gwalert polls the journal database every five minutes, re-derives the
alert conditions per house, and raises each alert to the alert-manager
over loopback with a bearer token and in parallel to Opsgenie. Each
cycle reads in two steps: first one aggregate row per house (the newest
reading on the channels the detectors use, inside a 2-hour window) for
the no-data check, then the full 2-hour readings window for every other
detector.

## Invariants

- **One journal, read as `gw_alerts`.** gwalert reads JournalKeeper's
  `gridworks.*` tables (`readings` joined through `reading_channels`;
  `messages` for glitches and `layout.lite`) as the read-only `gw_alerts`
  role, 2-minute statement timeout. Roles are named by consumer and created
  by gridworks-data in dev and prod alike; the password-equals-role-name
  convention holds in dev. Passwords live in 1Password, never in a repo.
- **Layout is fetched fresh every cycle.** `layout.lite` arrives only on
  scada boot, so gwalert takes the latest per house with no time window;
  a lookback window would leave Standby and critical zones unknown after
  any gwalert restart.
- **Data freshness is judged inside the query's own window.** The no-data
  check compares a house's newest reading with the end of the window it
  was queried in, never with the clock after the query returns. A query
  fixes its window end before it runs and drops rows stamped later, so
  measuring against a later clock ages fresh data by the query's own
  duration; on 2026-09-15 a fetch that took five minutes paged three
  houses whose data was on schedule. The check has its own cheap query so
  the full-window fetch cannot delay it. Verified on the live fleet
  2026-09-16: spruce's scada stopped for 15 minutes paged Opsgenie 14.7
  minutes after the stop, the cycle after the one that saw the data 9.9
  minutes old (`experiments/2026-09-16-gwalert-no-data-page/`). Worst
  case from data stop to page is the threshold plus one cycle plus the
  scada's report cadence, about 15 minutes.
- **Opsgenie de-duplicates by a per-day alias.** gwalert posts every
  alert with alias `{YYYY-MM-DD}-{house}-{alert_alias}` (ET). While an
  alert with that alias is open, a repeat post folds into it (Opsgenie
  increments its count) and notifies nobody; acknowledging does not free
  the alias, closing does. This is intended: one page per condition per
  house per day, and the on-call closes the alert when the outage is
  over so a second outage the same day pages again. On 2026-09-15 spruce
  lost data at 09:55 and again at 16:14 ET; the second post folded into
  the morning's acknowledged, still-open alert. The journal names the
  house and the alias on two lines per alert:
  `[ALERT] spruce: No data coming in since 15.0 minutes` then
  `Opsgenie accepted alert 2026-09-16-spruce-no_data`, so an outage is
  reconstructed from `journalctl -u gridworks-alerts` on the box and the
  alert's count in Opsgenie.
- **Temperatures are read by the channel's unit, never by name.** A
  journal channel names its unit twice: `unit_type` is the sema word the
  spelling belongs to (`gw1.unit`, `spaceheat.telemetry.name`) and `unit`
  the member. The ingest keeps both beside the readings and every
  temperature threshold converts through one table (`gwalert/units.py`).
  Zone channels are chosen by role suffix (`-set`, `-temp`, `-floor-temp`,
  `-gw-temp`); freezing prefers air, then floor, then gw; setpoint uses
  air, then floor. The fleet today mixes `AirTempFTimes1000` (smart
  thermostats) with `FahrenheitX100` and `CelsiusTimes100` (spruce, no
  thermostats); a detector that guessed the scale from the name paged
  spruce at every restart.
- **Building the detector does not run it.** `AlertGenerator()` binds
  settings and the session factory only; the entrypoint calls `main()`.
  Tests construct the object without a database.

## Known gaps / Open

- **Thin test coverage** on the detector logic; the no-data and zone
  temperature checks have unit tests, the pump and heat-pump detectors
  (`/100`, `/1000` literals on flow and power) do not. For the thing we
  trust at 3 a.m., this is the priority.
- **Setpoints that report only on change never reach the 2-hour window.**
  Spruce's `zoneN-…-set` channels last reported between July and early
  September, so the setpoint check logs "Missing setpoint channel" for
  spruce every cycle. The check needs each channel's latest reading
  regardless of window, the way the freshness query already works.
- **A house with no reading in the window is silently absent** from every
  check, the no-data check included: the house list is derived from the
  rows returned, not from the registered channels. A house that goes dark
  pages once at ten minutes and then drops out of the list; a house dark
  for more than two hours at gwalert start never pages at all (elm, off
  for the summer, is absent from the cycle log for this reason). Deciding
  which houses are expected to report belongs with the Standby signal in
  `layout.lite`, not with a row count.
- **The full-window fetch is slow and shares the database with people.**
  About 40k rows take ~10 s at baseline on the box and reached 165–322 s on
  2026-09-15 while `gw_visualizer` (the web backend, CSV pulls from the
  web page) ran heavy reads; server-side execution stays under 2 s, so the
  time is transfer and client-side handling. Options: fetch only the
  windows each detector reads (most use 5–15 minutes), or alert on the
  cycle's own duration so a degraded alerter pages as itself.
- **Hardcoded fleet specifics** in the detector: a `houses_with_monobloc`
  list stands in for an `HpModel` carried in `layout.lite`; zone
  temperature falls back to the `gw-temp` channel where a house has no smart
  thermostat; magic thresholds throughout. Hard-coded channel-name strings
  in data services are the named enemy of the "data analysis never slows the
  production system" rule.
- **Missing-data conditions** log rather than alert in several detectors
  (as read 2026-06-26; re-verify against the tsdb port). Forecast
  channels, whose timestamps are in the future, are excluded from the
  readings query itself.
