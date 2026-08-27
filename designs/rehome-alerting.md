# rehome-alerting

Status: Draft · Pass 0 · Updated 2026-08-27 · Linear: OPS-506

**EDD: no** build-out; verified when a synthetic alert raised on the new box
reaches Telegram, and `journalctl` on the box shows both units restarting
cleanly after a reboot.

> What this is: move the house alerting — the gwalert detector and the
> alert-manager Telegram dispatcher — off the legacy `journaldb` EC2 box onto
> a Hetzner box of its own, reading the one journal database. Owner: Thomas.
> The box exists; the work is the two services.

## Why now

- Both services today live on `journaldb`, a legacy AWS box whose only
  remaining job is to feed them the old journal. Rehoming them is what lets
  journaldb and journalmaker be terminated (~$44 / month plus the 150 GB
  volume and its snapshots).
- On 2026-08-27 the box showed gwalert active but **alert-manager not
  running**: no tmux server (the box rebooted 2026-07-17 and tmux does not
  survive a reboot), nothing listening on `:8000`. gwalert sends to Opsgenie
  first and only logs when the manager is unreachable, so alerts have been
  reaching Opsgenie and not Telegram since then. A systemd unit fixes this
  class of failure permanently.
- gwalert's only real dependency is the journal. Its backoffice-DB setting
  (`GWALERT_GBO_DB_URL`) is defined in `config.py` and read by nothing.

Nothing here waits on the OPS-498 back-fill: the detector looks at the last
few hours, which the live keeper already journals.

## The box

`alerts` — Hetzner cx23 (2 vCPU / 4 GB, €6.49 / month; cpx11 is no longer
orderable in EU locations), Helsinki (`hel1`), Ubuntu 24.04,
persistent primary IPv4 **62.238.124.242** (`auto-delete=false`), Hetzner
cloud firewall `alerts` (inbound ssh + ICMP only). DNS
`alerts.electricity.works` → that address (Route 53, zone `electricity.works`,
TTL 300). Same access profile as gjk: one login named for the box (`alerts`),
per-person keys only (`alerts-{jessica,thomas,joe}`), root opens with
`alerts-jessica`, password auth off. Recorded in
`gridworks-infra/alerts/instance-README.md` and `platform-inventory.md`.

Europe is fine for this service: it reads a US database every five minutes
and posts to Telegram; neither notices 90 ms. It is deliberately not on gjk,
so a journaling problem and an alerting problem cannot be one outage.

## 1. alert-manager into the org, under systemd

- Move `thdfw/alert-manager` to `thegridelectric/alert-manager` (transfer,
  keeping history). The box runs committed code at a pushed SHA only.
- Add `service/alert-manager.service`: `Restart=always`, boot-enabled,
  `MemoryMax=512M` (the OPS-451 lesson), `EnvironmentFile` for the Telegram
  token and the bearer token gwalert presents. Listens on loopback `:8000`.
- The Google-Sheets entrypoint (`alert-manager-sheet`) is not running today;
  leave it out unless it is wanted.

## 2. gwalert on the new box, reading `tsdb`

- Same repo, same `service/gridworks-alerts.service`; `.env` with
  `GWALERT_DB_URL` pointing at the journal DB as **`gw_analyst`** (read-only;
  its 2-minute statement timeout suits these queries), and
  `GWALERT_ALERT_MANAGER_URL=http://localhost:8000`.
- The queries move from the old journal's schema to JournalKeeper's
  `gridworks.*` tables (`readings` joined through `reading_channels`;
  `messages` for glitches and `layout.lite`). This is the substantive change.
  `docs/alerts.md` in the repo is the list of detectors to port; the
  freshness detector should ignore forecast channels, whose timestamps are
  in the future.
- Delete the `gbo_db_url` setting and the Opsgenie keys from the config once
  Telegram delivery is proven; until then keep Opsgenie as the fallback it is
  today.

## 3. Cut over

1. Both units running on `alerts`; raise a synthetic alert (a test hook in
   gwalert, or a hand `POST /new-alert`) and see it in Telegram.
2. `sudo reboot` the box; both units come back without a hand.
3. Stop `gridworks-alerts.service` on journaldb. Nothing else reads the old
   journal for alerting; journaldb and journalmaker are then retire-able
   (their own step in the legacy retirement, with the `hourly_electricity`
   slice preserved first).

## Open

- Whether Opsgenie stays as a second channel or goes once Telegram is
  reliable (it may carry a subscription cost; check the bill).
- OPS-449 (alerts as sema-typed broker events) is the next step *on this
  box*, not part of this rehome.
