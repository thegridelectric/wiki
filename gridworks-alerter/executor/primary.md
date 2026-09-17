# gridworks-alerter — spec (primary)

Status: Draft · Pass 0 · Updated 2026-09-17

> What this is: house alerting as it runs on the `alerts` box — the
> gwbase alerter **gwalerter** (`thegridelectric/gridworks-alerter`),
> the **alert-manager** Telegram dispatcher
> (`thegridelectric/gridworks-alert-manager`), and the legacy detector
> **gwalert** (`thegridelectric/gridworks-alerts`) that gwalerter takes
> over one detector at a time (OPS-545). gwalerter is
> [`gwalerter.md`](gwalerter.md); gwalert is
> [`../legacy/gwalert.md`](../legacy/gwalert.md).

## What it is

Two systemd units on the Hetzner box `alerts` (`alerts.electricity.works`;
box facts, access profile and operating aliases live in
`gridworks-infra/alerts/instance-README.md`):

- **gwalert** (legacy) polls the journal database every five minutes and
  raises alerts to the manager and to Opsgenie; detail in
  [`../legacy/gwalert.md`](../legacy/gwalert.md).
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
- **Alerting is not on gjk.** A journaling problem and an alerting problem
  must not be one outage, so the alerter lives on its own box. Helsinki is
  fine: it reads a US database every five minutes and posts to Telegram;
  neither notices the latency.
- **Reads ride a public read-only façade, writes stay private** — the house
  API pattern (`wiki/api-pattern.md`).

## Channels

Telegram, through the manager, is the primary channel. Opsgenie remains a
parallel channel from gwalert; whether it goes once Telegram has run a
while is Open (check the bill). Email code exists but has no live call site.

## Known gaps / Open

- **Everyone on call needs a Telegram chat ID** in the routing sheet.
- **Ack and close lifecycle** of an alert, and web-side ack, are not
  specified here; the manager's owner defines them with the people who
  answer the pages. On the Opsgenie side the one rule that matters is
  in [`../legacy/gwalert.md`](../legacy/gwalert.md) "Invariants": close,
  do not only acknowledge, or the day's next outage at that house is
  silent.

## Sub-specs

- [`gwalerter.md`](gwalerter.md) — the broker alerter: inputs, store,
  fleet roots, alert words and kinds, operating notes.
- [`../legacy/gwalert.md`](../legacy/gwalert.md) — the legacy detector:
  journal reads, freshness, Opsgenie alias, known gaps.

## Relationships

- [OPS-545](https://linear.app/gridworks/issue/OPS-545) — the broker
  alerter, absorbing OPS-449 (alerts as sema-typed broker events).
- [OPS-438](https://linear.app/gridworks/issue/OPS-438) — leave Opsgenie.
- [OPS-317](https://linear.app/gridworks/issue/OPS-317) — the scada-health
  liveness signals a future alerter would consume instead of re-deriving
  from raw messages.
