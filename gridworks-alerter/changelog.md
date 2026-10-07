# gridworks-alerter changelog

One entry per commit in `thegridelectric/gridworks-alerter`,
`thegridelectric/gridworks-alerts` and `thegridelectric/gridworks-alert-manager`
(git = the what, this = the why).

## 2026-10-07 — gridworks-infra: update to alerts instance (`2905106`)

The alerts box instance-README and `platform-inventory.md` record that
`alert-manager.service` is stopped on purpose: it paged unreliably, so
pages go out through Opsgenie only (sent by gwalert), no Telegram
messages are sent, and `/health` and `/alerts-history` answer 502
through the Caddy façade, so the web Alerts page shows no history. Why
in the box record: the next person on the box must not "fix" a stopped
unit by starting it. The proposal for what replaces the manager is
OPS-547.

## 2026-10-07 — The broker alerter, squashed again: the prober, the store-only tap, the re-floor on resume (`7e8c646`)

`jm/gw-alert` squashed a second time to one commit, so the branch still
merges to `main` as one unit: the three entries below (`42a4802`, the
prober, and the store-only tap) are its content, each with its why.

## 2026-10-07 — The tap pages from the store alone; the actor re-floors NoData when it resumes hearing (folded into `7e8c646`)

The broker-down witness (`experiments/2026-10-07-alerter-broker-down/`)
failed on two counts around a prober that passed: the tap, a consumer
of the mic exchange, died at connect for the whole outage and paged
`BrokerUnreachable` four minutes late, and the detector thread skipped
every tick while the actor was not consuming, so NoData never re-floored
and fired a false page five seconds after the reconnect. The tap loses
its broker consumer, queue, binding and decode path and becomes a
poller of the store (`Tap.run` is reconcile then wait; `tap_reconcile_s`
default 300 → 10, the longest a page now waits). The actor floors the
NoData rule's last-heard at each `local_rabbit_startup`, which gwbase
calls on every (re)connect. Why these and not the design's first fixes
(connect-retry around the consumer, a `hearing` argument on the rule):
the store already held every record the consumer heard, so the consumer
was a fast path over the real path, and the skip while deaf is right on
its own; only the re-floor was missing. Tests first: a tap with no
broker reachable creates a store-held alert (`test_tap.py`), and an
actor that resumes consuming past the threshold raises nothing until a
full threshold later (`test_no_data.py`); `broker_up` moves to conftest.
Template, README and CLI prose follow. The broker-down witness re-run on
this commit is PASS on all four steps (`evidence/2026-10-07-pass/`).

## 2026-10-07 — The prober: BrokerUnreachable from outside the broker path, NoData holds while it is open (folded into `7e8c646`)

`gwalerter probe`, the third process (`alerter-probe.service`): every
minute it checks the broker's two doors as a client, an AMQPS round
trip and an MQTT connect on the scadas' listener, and a door that fails
three probes running raises a `gw.alert` (PlatformService,
BrokerUnreachable, Subject the door) into the store; the first success
resolves it. It has no Opsgenie client: the tap's reconcile pass pages
what the store holds, with no broker involved. The NoData rule raises
nothing while a BrokerUnreachable alert is open and re-floors last-heard
when it resolves. Settings `probe_*` (URL, MQTT host/port/TLS,
interval, failures to raise), the unit, the aliases, `template.env`.
README gains "What it alerts on" (the two live conditions and the kinds
the vocabulary already holds for the detectors still in gwalert) and
corrects tracked houses to Active and Pending. Why: the alerter is a
broker consumer, so a broker outage is silent to it and would otherwise
surface as one NoData page per house; the design's prober closes that
gap, and the store route gives it the same record shape and pager as
every other alert. Folded into the PR before the squash.

## 2026-10-07 — The broker alerter: gw.alert on a detector thread, the store, and the Opsgenie tap (OPS-545, folded into `7e8c646`)

One commit on `jm/gw-alert` squashing the seven that followed `5c8afb2`
(2026-09-28 to 2026-10-07), so the branch merges to `main` as one unit
and the box clones one SHA. The seven, oldest first, each with its why:

**The alerter speaks one gw.alert word** (was `d29d9a6`).
Sema `dev` reshaped the alert vocabulary (`3de1363`): the two house
type words are gone and one `gw.alert` carries both transitions with
`State` Firing/Resolved, a `Category` that selects the `Kind` enum, and
the full GNode alias as identity. The seed takes `gw.alert` in place of
the house words, and `scripts/regen_sema_snapshot.sh` passes its
arguments through to `sema snapshot prepare`, so a dev round builds with
`--allow-staged`. The snapshot is regenerated that way from sema
`3b4260d` (the gw.alert axiom template fix) and is marked dev-only until
the five words promote. The `alerts` table gains `category` and
`subject`, takes a nullable `about_g_node_alias`, renames the cleared
columns to `resolved_ms` / `resolved_payload`, and indexes the open
alert by all of them; the initial migration is edited in place, since no
box holds this store yet. The store's open, raise and clear take and
return `Alert`, and refuse a record in the wrong `State`. NoData raises a
`Firing` record and resolves it with a `Resolved` record carrying the
same `AlertId` and `RaisedMs`. The actor broadcasts each record on
`AboutGNodeAlias`, else on `Src`, so a record with no house keys on the
alerter's own alias. The tests move to the one word and add a
Firing/Resolved codec round trip that trips axioms 1 and 3.

**Move to gwbase 0.5.14** (was `f4d6893`).
Picks up the gwbase release that stops logging the broker password:
`ActorBase.connect_consumer` logged the full AMQP URL at every connect,
so this service wrote its broker credential into its file log and
journald. Floor raised and lock refreshed; nothing else moved.

**The tap: gw.alert into Alertmanager** (was `bee0564`).
`gwalerter tap`, a second subcommand and systemd unit
(`alerter-tap.service`): a plain consumer with its own durable queue on
`alertsmic_tx`, bound by the `gw-alert` type segment, that decodes each
record through the snapshot, maps it onto Alertmanager's v2 intake
(labels `alertname`=Kind, `category`, `subject`, `src`, `alert_id`;
annotations `summary`, `house`, `about`; `endsAt` from `ResolvedMs`) and
posts on loopback, retrying a refused connection three times then
dropping with a log line. Alertmanager forgets a firing alert not
re-posted within `resolve_timeout` and the alerter says each transition
once, so the tap re-posts its open set every `tap_resend_s` (300) and
seeds that set from the alerter's store at boot (`Store.open_alerts`),
which is what makes a tap restart neither re-page nor forget. Witnessed
PASS on the laptop, `experiments/2026-09-30-alerter-to-alertmanager/`.

**Snapshot from the published alert words** (was `f0064a6`).
The vendored snapshot regenerated from sema `632b58e`, where `gw.alert`
000 and its four enums are published, without `--allow-staged`: the
first published-only build of the alerter, so `indexes/staging.yaml`
and the README's dev-only warning are gone and the box can run it. No
generated class changed; only the registry copy, the expanded seed and
the README moved.

**The tap pages through Opsgenie** (was `409637f`).
The tap posts to Opsgenie's Alert API instead of Alertmanager's intake:
a `Firing` record creates an alert aliased by its `AlertId` (Opsgenie's
dedup key), the `Resolved` record closes that alias with its summary as
the note, and a reconcile pass against the store replaces the re-post
cadence (Opsgenie has no `resolve_timeout`, but a post can fail and a
record can be missed). `Store.resolved_record` reads the stored
`Resolved` payload for that close. The Alertmanager mapping, client and
settings are gone with the Alertmanager proposal handed off; the tap
settings are the API key, the team and the host, key and team required.
Why: the design pages through Opsgenie, which the fleet is already on
call for, and a notifier the alerter does not own is one fewer process
on the alerts box.

**The tap speaks the gw.opsgenie words** (was `3dde59b`).
The tap's outbound shapes are sema words: a `Firing` record maps onto
`gw.opsgenie.alert.create` and a `Resolved` record onto
`gw.opsgenie.alert.close`, both constructed through the snapshot, and
the Opsgenie request body is written from the word at the post (the
named details into Opsgenie's flat string map under their lower-case
names). The two NamedTuples that stood in for the words are gone, and
the priority is the `gw.opsgenie.priority` enum. The snapshot carries
the three Opsgenie words with `gw.opsgenie.alert` (the alert as Opsgenie
lists it back, for the shadow-week comparison); they are staging, so
this snapshot is a dev-only build (`indexes/staging.yaml`) and the
words are promoted before the branch merges to `main`. Why: sema is
mandatory at every inter-app boundary, and the tap's boundary with
Opsgenie is one.

**Published-only snapshot with the gw.opsgenie words** (was `4b90170`).
The snapshot is regenerated from sema `8a91cc0`, where the five
Opsgenie words are published; the dev-only marker
(`indexes/staging.yaml`) is gone and the seed is back to its default.
Why: the box clones `main` and runs a published-only build, and this
is the snapshot it gets.

## 2026-10-06 — gridworks-alerts: Decode gw2.lc.top.state (OPS-392, `5a23fb7`)

A scada on `jm/spruce-unlimbo` reports its local control top state as
`gw2.lc.top.state` (Dormant, Normal, ScadaBlind, Standby, InBackup),
which the decoder did not know, so the top-state channel came through
as a bare integer. The `gw1.lc.top.state` list stays for scadas still
on `main`.

## 2026-09-28 — gridworks-alerts: Judge spruce's learned setpoints against the gw-temp sensor (`e252ea0`)

Spruce's zones have mechanical dials, so the scada learns each zone's
setpoint as the gw-temp reading at the end of a heat call. The cold-house
detector judged that setpoint against the floor sensor, which sits about
2 F under gw-temp there, and paged on a bedroom that was at setpoint the
first time the learned setpoint appeared in the journal (19:48 ET). The
detector now picks the temperature it judges by house:
`SETPOINT_TEMPERATURE_ROLES_BY_HOUSE` puts gw-temp first for spruce; every
other house keeps air then floor. Hard-coded per house because the layout
vocabulary does not yet carry a zone's setpoint source; the note in the
broker-alerter design records what retires it. Two tests replay the
spruce readings, one as spruce (no alert) and one as maple (alert).
Deployed to the alerts box the same evening.

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
