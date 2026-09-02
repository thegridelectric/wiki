# gridworks-alerts changelog

One entry per commit in `thegridelectric/gridworks-alerts` and
`thegridelectric/gridworks-alert-manager` (git = the what, this = the why).

## 2026-08-31 — gridworks-alert-manager: Caddy read: TLS for the GET routes only (`d9176af`, merged `57318cf`)

`service/Caddyfile`: TLS at `https://alerts.electricity.works` for the
GET routes only (`/health`, `/alerts-history`); the write route stays
loopback and 404s at the edge. This is how the web dashboard's alerts
view reaches the manager — web-api2's backend proxies through the façade
with the bearer token, so the secret never reaches a browser. Installed
on the box (caddy via apt, firewall opened 80/443); web-api2's
`BACKEND_ALERT_MANAGER_URL` repointed and verified end-to-end.

## 2026-08-31 — Merge pull request #6 from thegridelectric/td/rehome-alerts (`44fad0c`)

The rehome lands on `main`: gwalert reads JournalKeeper's `gridworks.*`
tables and runs as a systemd unit on the `alerts` box. Includes the
jm/rehome-alerts-fixes commits (PR #5) and two of Thomas's on top:

- `d65e4e5` "Spruce now sends readings" — spruce joins the normal
  readings path; the `snapshot.spaceheat` special case is deleted. Also
  fixes restart-blindness: each cycle now fetches the latest
  `layout.lite` per house with no time window (layout.lite only arrives
  on scada boot, so the old 2-hour lookback left Standby and critical
  zones unknown after any gwalert restart).
- `eb0b95b` "Spruce is monobloc and has no smart thermostats" — a
  `houses_with_monobloc` list replaces hardcoded spruce checks (TODO:
  carry HpModel in layout.lite); zone temperature falls back to the
  `gw-temp` channel where there is no smart thermostat.

Cut-over completed 2026-08-31: synthetic alert → Telegram → 👍 (three
times), real cycles ~37k readings in ~6 s, reboot test passed after
`enable`-ing the unit (first reboot caught it merely `start`ed), legacy
gwalert on journaldb stopped and disabled. Opsgenie stays as the
parallel channel for now.

## 2026-08-30 — gridworks-alerts: dev and prod have gw_alerts db reader (`476b8be`)

The dev default named a `gw_reader` role that gridworks-data never
creates. gwalert's own role is `gw_alerts` (read-only, 2-minute statement
timeout; roles are named by consumer), created by gridworks-data in dev
and prod alike. Default,
`.env.example` and README corrected under the password-equals-role-name
convention.

## 2026-08-30 — gridworks-alert-manager: Bind loopback, always check the bearer token, add the systemd unit (`cc2a196`)

The manager ran in tmux bound to `0.0.0.0` with auth off when the token
was unset. Now: `host` defaults to `127.0.0.1` (only gwalert on the box
raises alerts; public reads go through a TLS proxy in front of the GET
routes, per the house API pattern), the bearer token is always checked
with a dev default that pairs with gwalert's, and
`service/alert-manager.service` (`User=alerts`, `MemoryMax=512M`,
`Restart=always`) replaces the tmux session. README deploy section
rewritten for the `alerts` box (https clone, root installs the unit).

## 2026-08-30 — gridworks-alerts: Run as alerts on the alerts box; dev-pair defaults; synthetic alert flag (`f86239f`)

On top of the tsdb port (`td/rehome-alerts`): the unit runs as `alerts`
in `/home/alerts`; config defaults become a working dev pair (the
gridworks-data dev container as `gw_reader`, alert-manager on loopback
with the shared dev token) instead of the production host with a
`PASSWORD` placeholder; `GWALERT_SYNTHETIC_ALERT=true` sends one
start-up alert to the manager only (never Opsgenie) to prove the
delivery path without the database — replacing the hand edit that
proved it on the box on 2026-08-29. README clones by https.
