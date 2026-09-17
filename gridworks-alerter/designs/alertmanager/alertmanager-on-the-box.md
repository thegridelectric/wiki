# alertmanager-on-the-box — Alertmanager stood up on the alerts box

Status: Draft · Pass 0 · Updated 2026-09-17

> **What this is.** Spoke 2 of the alertmanager design: Prometheus
> Alertmanager running on the alerts box as its own unit, configured
> from a committed file, paging a Telegram group. Needs only the box, so
> it runs in parallel with spoke 1; the two meet at the box experiment.

## Stand-up

Root steps are the human's, by the gwbase box pattern (gwbase executor
`service-deployment.md`) and `gridworks-infra/box-access.md`:

1. Login `alertmanager` (`adduser --disabled-password`), per-person keys
   only, `/etc/sudoers.d/alertmanager` granting exactly `systemctl
   start|stop|restart|status|enable|disable alertmanager`, NOPASSWD.
2. The static binary release under `/opt/alertmanager` (`alertmanager`
   and `amtool`), owned by root, version pinned in the instance-README.
3. Config `alertmanager.yml` from `gridworks-infra/alerts/` copied to
   `/etc/alertmanager/`; the Telegram token at
   `/etc/alertmanager/telegram.token` (mode 600, owner `alertmanager`,
   outside git, recorded as hand-placed state). Data dir
   `/var/lib/alertmanager` for silences and notification log.
4. Unit `alertmanager.service` from `gridworks-infra/alerts/`:
   `--config.file`, `--storage.path`, `--web.listen-address=127.0.0.1:9093`
   (intake on loopback only; nothing off the box can post),
   `Restart=always`, `MemoryMax=256M`. `systemctl enable --now`.
5. `amtool check-config` and `amtool alert add` from the box: a hand
   alert reaches the Telegram test group.

## Config

Committed in `gridworks-infra/alerts/alertmanager.yml`; a change is a
commit, a copy, `amtool check-config`, then a reload (SIGHUP).

- `global.resolve_timeout: 1h`; `route` grouped by `category` and
  `subject`, `repeat_interval: 4h`, one child route per `category`.
- Receivers: one `telegram_configs` per on-call group, `bot_token_file`,
  `send_resolved: true`; the message template shows the `house`
  annotation in the headline and the `about` annotation in the body.
- No escalation by count and no sheet-driven rotation (hub "Notes").

## The experiment (box)

The laptop experiment of spoke 1, re-run on the box against hw1 with
spruce's real scada, after the five words are promoted to published and
the tap's unit is installed beside the alerter's. PASS is the same five
checks; on PASS, gwalert's `no_data` check is switched off the same day.

## After

`gridworks-infra/alerts/instance-README.md` gains the unit, the login,
and the hand-placed state; `platform-inventory.md` gains Alertmanager on
the alerts row.

## Do this next

Stand-up steps 1 to 5, then the config commit in `gridworks-infra`.
