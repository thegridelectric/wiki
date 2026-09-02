# gridworks-alerts — spec (primary)

Status: Draft · Pass 0 · Updated 2026-09-02

> What this is: the house alerting service pair — the **gwalert** detector
> (`thegridelectric/gridworks-alerts`, package `gwalert`) and the
> **alert-manager** Telegram dispatcher (`thegridelectric/gridworks-alert-manager`)
> — as they run on the `alerts` box. Most detector depth is Open; the code is
> the authority for detail.

## What it is

Two systemd units on the Hetzner box `alerts` (`alerts.electricity.works`;
box facts, access profile and operating aliases live in
`gridworks-infra/alerts/instance-README.md`):

- **gwalert** polls the journal database every five minutes, re-derives the
  alert conditions per house, and raises each alert to the manager over
  loopback with a bearer token.
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

## Channels

Telegram, through the manager, is the primary channel. Opsgenie remains a
parallel channel from gwalert; whether it goes once Telegram has run a
while is Open (check the bill). Email code exists but has no live call site.

## Known gaps / Open

- **Near-zero test coverage** on the detector logic. For the thing we trust
  at 3 a.m., this is the priority.
- **Hardcoded fleet specifics** in the detector: a `houses_with_monobloc`
  list stands in for an `HpModel` carried in `layout.lite`; zone
  temperature falls back to the `gw-temp` channel where a house has no smart
  thermostat; magic thresholds throughout. Hard-coded channel-name strings
  in data services are the named enemy of the "data analysis never slows the
  production system" rule.
- **Missing-data conditions** log rather than alert in several detectors
  (as read 2026-06-26; re-verify against the tsdb port). The freshness
  detector should ignore forecast channels, whose timestamps are in the
  future.
- **Everyone on call needs a Telegram chat ID** in the routing sheet.
- **Ack and close lifecycle** of an alert, and web-side ack, are not
  specified here; the manager's owner defines them with the people who
  answer the pages.

## Relationships

- [OPS-449](https://linear.app/gridworks/issue/OPS-449) — alerts as
  sema-typed broker events; the next step on this box.
- [OPS-438](https://linear.app/gridworks/issue/OPS-438) — leave Opsgenie.
- [OPS-317](https://linear.app/gridworks/issue/OPS-317) — the scada-health
  liveness signals a future alerter would consume instead of re-deriving
  from raw messages.
