# gridworks-alerts — spec (primary)

Status: Draft · Pass 0 · Updated 2026-06-26

> **First pass — acceptable minimum.** Captures what the `gridworks-alerts`
> service IS today (a first-pass extraction by Thomas, downloaded 2026-06-26), so
> the domain has a spec. **Important framing:** this is the *existing* Opsgenie
> alerting cleanly extracted into its own `uv` repo — it does **not** yet begin
> the Opsgenie migration ([OPS-438](https://linear.app/gridworks/issue/OPS-438)).
> Most depth is Open; the code is the authority for details.

## What it is

A standalone service that monitors the residential heating fleet and raises
alerts for faults. One repo (`gridworks-alerts`, package `gwalert`), deployed on
an Ubuntu EC2 under **systemd**, dependencies via **uv**.

## Architecture (what IS)

- **A single `AlertGenerator`** (`src/gwalert/alert_generator.py`, ~1180 lines) on
  a `while True: … time.sleep(main_loop_seconds)` loop.
- **DB-polling, not event-driven.** It reads directly from two Postgres DBs over
  SQLAlchemy: `GWALERT_DB_URL` (**journaldb** — the messages) and
  `GWALERT_GBO_DB_URL` (**backofficedb** — the house registry). It re-derives alert
  conditions per house from raw `MessageSql` rows each loop.
- **Notification = Opsgenie.** `send_opsgenie_alert(...)` (Opsgenie REST,
  `GenieKey` auth) is the workhorse, called from ~20 condition sites. Dedup is
  delegated to Opsgenie via the `alias` (`YYYY-MM-DD-<house>-<alert>`).
- **Config** via `.env` (`GWALERT_*`, pydantic-settings `SecretStr`):
  `GWALERT_DB_URL`, `GWALERT_GBO_DB_URL`, `GWALERT_OPS_GENIE_API_KEY`,
  `GWALERT_EMAIL_SENDER`, `GWALERT_EMAIL_PASSWORD`.

## Known gaps / Open (the honest list)

- **Still 100% Opsgenie — the migration ([OPS-438](https://linear.app/gridworks/issue/OPS-438))
  has not started.** The hard part lives *in* Opsgenie: **dedup, escalation,
  acknowledge, on-call routing**. None of that is in this repo, so replacing
  Opsgenie means *building* that layer, not just swapping a notifier.
- **Email is dead code.** `send_email_alert` (gmail SMTP, sender==receiver) exists
  but its call sites are commented out; Opsgenie is the only live channel.
- **Missing-data faults are silent.** Several conditions
  `print("… Missing data!") # TODO: create an alert?` — the very silent-failure
  case the alerter exists to catch is logged to stdout, not alerted.
- **Near-zero test coverage** on the ~1180-line alert logic (only `test_version`,
  `test_message_types`). For the thing we trust at 3 a.m., this is the priority.
- **Hardcoded fleet specifics** — `opsgenie_team_id`, `ignored_house_aliases =
  ['moss','orange','spruce']`, magic numbers (`max_time_no_data = 10*60 # TODO
  nyquist`); won't scale to the +14 homes (ties to the generalize-for-configs
  theme). `print()` throughout instead of logging.
- **DB-schema coupling** to journaldb (the coupling [OPS-333](https://linear.app/gridworks/issue/OPS-333)
  set out to remove); a future path is consuming the durable liveness signals
  (`ally.inactive` etc., [OPS-317](https://linear.app/gridworks/issue/OPS-317))
  off the `ear` tap rather than re-deriving from raw messages.

## Relationships

- [OPS-438](https://linear.app/gridworks/issue/OPS-438) — migrate off Opsgenie
  (the forward work; this repo is its starting point, not its completion).
- [OPS-333](https://linear.app/gridworks/issue/OPS-333) — decouple alerts from
  JournalKeeper.
- [OPS-317](https://linear.app/gridworks/issue/OPS-317) — the scada-health
  liveness signals a future alerter would consume.
