# gridworks-alerter changelog

One entry per commit in `thegridelectric/gridworks-alerter`,
`thegridelectric/gridworks-alerts` and `thegridelectric/gridworks-alert-manager`
(git = the what, this = the why).

<!-- pending commit -->
## 2026-09-17 — gridworks-alerter: One gw.alert word with State (OPS-547)

Sema `dev` reshaped the alert vocabulary (`3de1363`): the two house
type words are gone and one `gw.alert` carries both transitions with
`State` Firing/Resolved, a `Category` that selects the `Kind` enum, and
the full GNode alias as identity. The alerter's snapshot is regenerated
from a clean worktree at that commit with `--allow-staged` (dev-only
until the five words promote); the store's `alerts` table, the NoData
rule, the actor's emit and the tests move to the one word. A record
with no house (Fleet, PlatformService) keys its broadcast on the
alerter's own alias. The initial migration is edited in place: no box
holds this store yet.

## 2026-09-16 — gridworks-alerts: improve logging (`e3e9b47`)

The `[ALERT]` line printed the message without the house, and each
alert printed it twice (once in `send_alert`, once in
`send_opsgenie_alert`), which read as two firings when reconstructing
the 2026-09-15 spruce outage from the journal. One line now:
`[ALERT] spruce: No data coming in since 10.7 minutes`, and the
Opsgenie acceptance line names the alias it posted.

## 2026-09-15 — gridworks-alerter: Track Pending houses as well as Active (OPS-545, `5c8afb2`)

The store tracked only Active terminal assets, and every hw1 GNode in
the production registry is Pending: on the alerts box the alerter would
have tracked nothing. A house pages from the day it reports, before the
registry settles its position, so `TRACKED_STATUSES` is Pending and
Active; a Suspended house is out of service on purpose and stays quiet.
The forest test covers all three.

## 2026-09-15 — gridworks-alerter: Snapshot from the published alert words; the box surface (OPS-545, `6b0ef69`)

The three alert words are published (sema `74393a7`), so the regen
script drops `--allow-staged` and the seed states that the alerter takes
published words only: a prod service's snapshot must never carry a word
the hybrid broker cannot serve. The regenerated snapshot differs only in
the three status lines and the now-empty staging index, which goes.
With it, the deploy surface the gwbase box pattern asks for:
`service/bash_aliases` (spelling over systemctl and tail, matched by the
box's sudoers drop-in), `Type=simple` and `MemoryMax=512M` on the unit
as the alerts box runs its other units, and the console script
configuring the root logger to stdout so the boot lines (forest request,
tracked houses) reach journald; the actor's own log stays gwbase's
rotating file under the XDG state home.

## 2026-09-15 — gridworks-alerter: NoData rule on a detector thread, alert state in the store (OPS-545, `410d52e`)

The first detector. `no_data.py` holds the rule: a tracked house whose
last-heard (the store's query, floored at boot time) is older than
`GWALERTER_NO_DATA_SILENCE_S` and has no NoData alert open is raised
once; the first report or layout from its scada clears it with that
arrival as evidence. The store gains `open_alert`, `raise_alert`,
`clear_alert` and `alerts` over the existing `alerts` table, and every
transition is recorded before it is broadcast, so a restart neither
re-raises nor forgets. The actor runs the detectors on their own thread
every `GWALERTER_DETECTOR_TICK_S` once it is consuming and broadcasts
each word on its mic exchange with the house alias as the radio channel;
arrivals clear in dispatch. Tests drive the rule with a fixed clock
through a typed report builder in `conftest.py`; the real-broker witness
is `experiments/2026-09-15-alerter-no-data/` (PASS, including the
restart with the alert open; experiments `58cf200`, which also puts the
alert words in that repo's snapshot).

## 2026-09-15 — gridworks-alerter: Orchestrator tier with the Alerter transport class (OPS-545, `d5b8387`)

`AlerterActor` moves from a bare ear tap to the Orchestrator tier with
`TransportClass.Alerter` (gridworks-base 0.5.13), so it can broadcast
its alert words on its own `alertsmic_tx` exchange, which fans into the
ear exchange for the manager and JournalKeeper; a bare tap can send only
wrapped messages, which need a destination class. It still taps the ear
exchange with `#` for readings, layouts and forests, now bound
explicitly beside the class binding the tier makes. The tier's control
plane needs `GWALERTER_SUPER_ALIAS` and `GWALERTER_TIME_COORDINATOR_ALIAS`,
no defaults. The gwbase pin rises to 0.5.13.

## 2026-09-15 — gridworks-alerter: Store on SQLAlchemy and alembic; registry projection and fleet roots (OPS-545, `2a1d706`)

The scaffold's bare `sqlite3` store becomes SQLAlchemy models with the
schema applied by an alembic chain when the store opens, so every schema
change is a tracked migration and the tests build the database through
the real chain, never `create_all`. One table per sema word the alerter
keeps: `g_nodes` (the registry's `g.node.forest` projected by immutable
id, an older forest never overwriting a newer one), `layouts`,
`readings` (with the arrival time, so last-heard is a query over
readings and layouts and a scada with a wrong clock cannot look alive),
and `alerts` for the detector step. The scaffold's `houses` table goes.
Which houses the alerter pages for is a registry subtree, not a roster:
`GWALERTER_FLEET_ROOTS` names the fleet and every Active TerminalAsset
under those roots is tracked; a bench house outside the roots never
pages, and a new install is added where the registry is edited, not on
the box. At boot a `g.node.forest.request` to `GWALERTER_GNR_URL` seeds
the projection; the broadcasts keep it current. A scada heard from that
reports for no tracked house is logged once per boot. The seed vendors
`g.node.forest/002` and `g.node.forest.request/000`.

## 2026-09-15 — gridworks-alerter: Vendor the house alert words (staging) (OPS-545, `40caf22`)

The seed request adds `gw.house.alert` and `gw.house.alert.cleared` at
000 and the snapshot is regenerated from the sema commit that adds them.
The words are staging, so the seed's published-only rule is widened for
the dev-broker phase and the regen script passes `--allow-staged` (the
snapshot carries `indexes/staging.yaml` naming the three words); both
narrow back to the published set when the words are promoted before the
shadow run against hw1. The `gw` prefix strips locally, so the classes
are `HouseAlert`, `HouseAlertCleared`, `HouseAlertKind`.

## 2026-09-15 — gridworks-alerter: scaffold the broker alerter (OPS-545, `f569fde`)

New repo `gridworks-alerter` (package `gwalerter`), the gwbase successor
to gwalert that will strangle it one detector at a time. This first
commit is the actor and its store, no detector: an `ActorBase` tap that
binds the audit exchange the way JournalKeeper does and keeps
`report.event` and `layout.lite` off the parsed envelope, a vendored
sema snapshot (every published `report.event`, `layout.lite` 011 and
012; the sema CLI refuses staging words by default and the alerter is
a prod service, so 013 waits for promotion), and a sqlite store holding
the latest layout per house, a rolling readings window, and last-heard
per house. No durable queue: the journal is the durable record, and a
queue that fills while the alerter is down is a second outage. The
store's `HouseRecord` is the interim until the OPS-317 liveness signals
are journaled. `ci.sh` runs ruff, pyright and pytest; the live-broker test
self-skips without `gw-dev-rabbit`.

## 2026-09-15 — gridworks-alerts: Zone detectors convert temperatures by the channel's unit (`1eda244`)

After every gwalert restart spruce paged "zoneN is below 40F" for three
zones in the mid-60s F. The freezing and setpoint detectors chose a
zone's temperature channel by substring ("temp" without "gw") and
divided by 1000 as if every such channel were a smart-thermostat
`AirTempFTimes1000` reading; spruce's floor-temp and set channels are
`FahrenheitX100`, so 6566 read as 6.6 F. The ingest now keeps each
channel's `unit` beside its readings, temperatures are converted to F
by unit through one table covering every unit the journal carries, and
zone channels are chosen by role suffix (`-set`, `-temp`, `-floor-temp`,
`-gw-temp`) rather than substring. Unit tests per unit and per role. The
freshness query's duration is logged beside the full fetch's. (OPS-544)

## 2026-09-15 — gridworks-alerts: Constructing AlertGenerator no longer starts the loop (`c257966`)

`AlertGenerator.__init__` called `main()`, so building the object ran
the polling loop against the database with the real send path: the
class could not be constructed in a test or a shell. The entrypoint now
calls `main()` explicitly; the no-data tests construct the object
normally (binding the session factory makes no connection). (OPS-543)

## 2026-09-15 — gridworks-alerts: reduce freshness check time from 10s to .77s with an aggregate query (`4a5dc67`)

The freshness check gets its own query, `fetch_latest_data`: one
aggregate row per house (newest alert-channel reading in the window,
0.77 s and five rows measured from the laptop, against the 40k-row full
fetch), run first in the loop and measured against its own window end.
The full fetch still feeds every other detector but can no longer delay
or distort the no-data verdict. A house with no reading in the window
stays absent from the check, as it was from the full fetch. Unit tests
cover the race, alert-once, and clearing. (OPS-543)

## 2026-09-15 — gridworks-alerts: Judge data freshness against the fetch window end, not the clock after the fetch (`9dac6ad`)

On 2026-09-15 13:55 UTC the no-data check paged on-call for oak, beech
and spruce while every 5-minute report was in the journal on schedule.
The fetch fixes its query window's end at fetch start and drops rows
stamped after it, but freshness was measured against the wall clock
after the fetch returned. Fetches had grown from ~10 s to 165–322 s
(heavy `gw_visualizer` reads on the same database), and data is
naturally up to 5 min old at fetch start, so a fetch over ~5 min always
crossed the 10-minute threshold. The fetch now records its window end
and the check measures against that. (OPS-543)

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
