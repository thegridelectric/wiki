# gridworks-alerter — spec (primary)

Status: Draft · Pass 0 · Updated 2026-09-15

> What this is: house alerting — the **gwalert** detector
> (`thegridelectric/gridworks-alerts`, package `gwalert`), its gwbase
> successor **gwalerter** (`thegridelectric/gridworks-alerter`), and the
> **alert-manager** Telegram dispatcher (`thegridelectric/gridworks-alert-manager`)
> — as they run on the `alerts` box. This hub describes gwalert and the
> manager; gwalerter, built beside gwalert and taking over one detector at
> a time (OPS-545), is [`gwalerter.md`](gwalerter.md). Most detector depth
> is Open; the code is the authority for detail.

## What it is

Two systemd units on the Hetzner box `alerts` (`alerts.electricity.works`;
box facts, access profile and operating aliases live in
`gridworks-infra/alerts/instance-README.md`):

- **gwalert** polls the journal database every five minutes, re-derives the
  alert conditions per house, and raises each alert to the manager over
  loopback with a bearer token. Each cycle reads in two steps: first one
  aggregate row per house (the newest reading on the channels the
  detectors use, inside a 2-hour window) for the no-data check, then the
  full 2-hour readings window for every other detector.
- **alert-manager** listens on loopback `:8000`, dispatches alerts to Telegram
  by the on-call routing in its Google Sheet, and keeps the alert history.
  A Caddy front at `https://alerts.electricity.works` exposes the GET routes
  only (`/health`, `/alerts-history`); the write route never leaves the box.
  The web frontend's Alerts page reads the history through that façade via
  the web-api2 backend, which holds the token.

## Invariants

- **The box runs committed code at a pushed SHA.** Both units are
  boot-enabled with `MemoryMax=512M`, `Restart=always`. Verification of a
  deploy: a synthetic alert (`GWALERT_SYNTHETIC_ALERT=true` sends one
  start-up alert to the manager only, never to Opsgenie) reaches Telegram,
  and a reboot brings both units back unaided.
- **One journal, read as `gw_alerts`.** gwalert reads JournalKeeper's
  `gridworks.*` tables (`readings` joined through `reading_channels`;
  `messages` for glitches and `layout.lite`) as the read-only `gw_alerts`
  role, 2-minute statement timeout. Roles are named by consumer and created
  by gridworks-data in dev and prod alike; the password-equals-role-name
  convention holds in dev. Passwords live in 1Password, never in a repo.
- **Alerting is not on gjk.** A journaling problem and an alerting problem
  must not be one outage, so the alerter lives on its own box. Helsinki is
  fine: it reads a US database every five minutes and posts to Telegram;
  neither notices the latency.
- **Layout is fetched fresh every cycle.** `layout.lite` arrives only on
  scada boot, so gwalert takes the latest per house with no time window;
  a lookback window would leave Standby and critical zones unknown after
  any gwalert restart.
- **Reads ride a public read-only façade, writes stay private** — the house
  API pattern (`wiki/api-pattern.md`).
- **Data freshness is judged inside the query's own window.** The no-data
  check compares a house's newest reading with the end of the window it
  was queried in, never with the clock after the query returns. A query
  fixes its window end before it runs and drops rows stamped later, so
  measuring against a later clock ages fresh data by the query's own
  duration; on 2026-09-15 a fetch that took five minutes paged three
  houses whose data was on schedule. The check has its own cheap query so
  the full-window fetch cannot delay it.
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

## Channels

Telegram, through the manager, is the primary channel. Opsgenie remains a
parallel channel from gwalert; whether it goes once Telegram has run a
while is Open (check the bill). Email code exists but has no live call site.

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
- **Everyone on call needs a Telegram chat ID** in the routing sheet.
- **Ack and close lifecycle** of an alert, and web-side ack, are not
  specified here; the manager's owner defines them with the people who
  answer the pages.

## Sub-specs

- [`gwalerter.md`](gwalerter.md) — the broker alerter: inputs, store,
  fleet roots, alert words and kinds, operating notes.

## Relationships

- [OPS-545](https://linear.app/gridworks/issue/OPS-545) — the broker
  alerter, absorbing OPS-449 (alerts as sema-typed broker events).
- [OPS-438](https://linear.app/gridworks/issue/OPS-438) — leave Opsgenie.
- [OPS-317](https://linear.app/gridworks/issue/OPS-317) — the scada-health
  liveness signals a future alerter would consume instead of re-deriving
  from raw messages.
