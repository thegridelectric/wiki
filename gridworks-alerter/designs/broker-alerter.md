# broker-alerter — the house alerter as a broker citizen

Status: Draft · Pass 0 · Updated 2026-09-16 · Linear: OPS-545

**EDD: yes** the shadow run *is* the verification: the new alerter runs beside
gwalert on the alerts box against the live hw1 broker, and each detector
reaches Verified only when a week of shadow output matches or beats gwalert's.

> What this is: the design for replacing gwalert's journal-DB polling with a
> gwbase actor on the hw1 broker that owns its inputs (its own queue), its
> state (sqlite), and its outputs (sema-typed alert events). Written at
> handoff on 2026-09-15 from the triage that motivated it; the next session
> starts at "Do this next".

## Why

Alerting is production. The journal DB is where people and the web page do
analysis. gwalert reads that database, so on 2026-09-15 a CSV pull from the
web page (`gw_visualizer`, four connections, statements to 125 s) stretched
gwalert's fetch from ~10 s to 5 min and three houses were paged for "no data"
while every report was on schedule (OPS-543). The same day spruce paged at
every restart because a detector guessed a channel's unit from its name
(OPS-544). Both were patched in place, and both are structural:

- The alerter consumes a store it does not own, on the observability plane,
  with no isolation from that plane's load.
- It decodes readings without their vocabulary. Units, roles and house
  membership are re-derived from column strings and channel-name substrings
  instead of arriving typed with the message.
- Its state is process memory, so a restart re-fires every standing alert
  and forgets every window.

The `executor/primary.md` invariant "alerting is not on gjk" drew the line at
the box; this design draws it at the data path.

## Shape

- **A gwbase actor** (`ActorBase`, a service, not a GNode) on the alerts box,
  connected to the hw1 broker over AMQP as `hw1.alerts`, a service under the
  universe root. Whether it earns a GNode alias is a question for the design,
  not a default. It lives in its own repo, `gridworks-alerter` (package
  `gwalerter`), named like the other gwbase services; `gridworks-alerts`
  stays gwalert's home until gwalert is retired, and
  `gridworks-alert-manager` is untouched. Two repos because the two run
  side by side on the box for the shadow week and share nothing but
  thresholds.
- **The standard gwbase queue**, `<alias>-F<3-hex>`, auto-delete, as every
  actor declares, bound to the scada topics JournalKeeper already
  journals: `report.event`, `snapshot.spaceheat`, `glitch`, `layout.lite`,
  plus the liveness signals of OPS-317 when they exist. Nothing durable on
  the broker: the journal is the durable record, and a queue that fills
  while the alerter is down is a second outage. Restart is handled in the
  store, not the broker.
- **Sema at the boundary.** Every message is decoded through the vendored
  snapshot classes; a channel's unit and role come from the layout the scada
  sent, never from a lookup table someone else populates. The `units.py`
  table added under OPS-544 is the thing this retires.
- **A sqlite store**, as the LTNs keep: the latest `layout.lite` per house,
  a rolling window of readings (a few hours covers every detector; all but
  the glitch window read 5–15 minutes), and alert state (open, cleared,
  when, evidence). Readings are rows shaped like the journal's readings
  table (house, channel, value, read time), not stored `report.event`
  messages: a detector asks for a channel's latest value or its last
  N minutes, never for a report, and the journal already keeps the
  messages. No hourly aggregates: nothing a detector reads is hourly, and
  aggregates are the journal's business. SQLAlchemy in front of sqlite
  and alembic for the schema, as the weather service does with its
  Postgres, so every schema change is a tracked migration and the tests
  run the real migration chain rather than `create_all`. The scaffold
  commit used bare `sqlite3`; the swap is the next code step. One table
  per sema word, nothing invented: `g_nodes` (`g.node.gt` rows upserted by
  id from the registry's forest broadcasts: which scadas exist),
  `layouts` (one row per scada holding whichever hardware layout word the
  scada has, by type name and version: `layout.lite` off the broker
  today, the registry's record later, same row shape), `readings`
  (`channel.readings` unrolled to house, channel, value, read time; the
  window), and `alerts` (the alert word plus its cleared time; the
  alerter's open-alert state). Which houses the alerter pages for is
  a registry subtree, not a table of its own: the one fleet setting is
  a root-set (`GWALERTER_FLEET_ROOTS`, no default, in the service's
  `.env`; `hw1.isone.me.versant.keene` for the Millinocket fleet), and
  the alerter tracks every Pending or Active TerminalAsset in the forest
  under those roots (the Millinocket houses are Pending until the
  registry settles their positions, and they page all the same). A house that must not page (a bench house, a side
  project) lives outside the roots. Membership is then a registry fact,
  edited where the registry is edited, and the alerter holds no
  hand-kept roster. `g_nodes` is the registry's projection rule applied
  here: upsert by `GNodeId` from `g.node.forest` broadcasts (already
  reaching the queue through the `#` binding) and bootstrap or resync
  at boot with a `g.node.forest.request` for the roots to the
  registry's HTTP read, never the registry's Postgres. The alert
  word's `AboutGNodeAlias` is read off `g_nodes` at raise time, so a
  rename never strands an alert. A scada's house is found in `g_nodes`
  by its parent alias plus `.ta`, the aliasing the registry states; a
  scada heard from whose terminal asset is not under the roots is
  logged once and not tracked, so a forgotten install is visible. The
  journaled liveness signals of OPS-317 say who is live; the roots say
  who this alerter is responsible for.
  Last-heard is a query over readings and layouts, not a column; once
  the `ally.inactive` / `ally.active` signals of OPS-317 are journaled,
  live state is read off them and `NoData` reads it there. The scaffold's `houses`
  table goes with the SQLAlchemy move. Channel unit and role are read off
  the stored layout through one accessor that dispatches on the layout
  word with `isinstance`; a new layout family is a new branch there and
  nothing else. Across a restart the layouts and alert state survive;
  the readings window refills from live traffic and "last heard" restarts
  from boot time, so a detector that needs a window waits one window
  before it can fire.
- **Sema-typed outputs.** The alerter emits an alert event and a cleared
  event on the broker. The manager consumes them to page; JournalKeeper
  journals them like anything else, so the web page's alerts history reads
  from the journal DB on the observability side and the bearer-token façade
  on the alerts box goes away. This absorbs OPS-449 (the gwalert ↔ manager
  interface) as one part.
- **No-data is a queue fact.** "No `report.event` from a house in ten
  minutes" needs no query. A dropped broker connection is a different fact
  and pages as the alerter itself.

## Settle in the design, not by default

Settled points live in `executor/gwalerter.md`; what remains open:

- **Layout bootstrap.** `layout.lite` arrives only on scada boot. The store
  persists the latest per scada, but the first boot needs a seed: a one-time
  pull from the journal, or a layout request the scadas do not yet answer.
- **Dead-man's switch.** Alerting and the houses share one broker, so a
  broker outage is silent. The manager pages if the alerter's heartbeat
  stops, over a path that is not the broker (loopback on the box is enough).
- **Live is read off the OPS-317 liveness signals.** The fleet roots say
  who the alerter is responsible for; the journaled signal set (startup,
  shutdown, peer.active, `ally.inactive` / `ally.active`) says who is
  live, and the mode from the last `layout.lite` is a field of that view,
  so Standby and MonitorOnly are fields, not exceptions in a detector.
  Until those signals are journaled last-heard is the store's own query.
- **Layouts come from their authority, after the spruce merge.** The
  terminal-asset registry (the layout and operational-params sibling of
  the grid-node registry, still a Draft design with no issue) is the
  durable source of every hardware layout, and it will egress like GNR: a
  broadcast on commit plus a request, consumed here as a projection into
  `layouts`. Not before the spruce merge: the layout words settle on that
  branch, and the alerter needs nothing from the authority to strangle
  no-data, since `layout.lite` on the wire carries the unit and role it
  reads today.
- **Setpoints that report only on change** (spruce, last between July and
  September) need latest-known values, not a window; the store gives that
  for free but the detector must ask for it.
- **The manager.** Whether it stays a separate process or becomes the same
  actor's paging half. Keep it separate at first; it is the thing that pages
  and should not restart when a detector changes.

## Sequence

Strangler, not rewrite. gwalert keeps running throughout.

1. ✅ The actor: `gridworks-alerter` on gwbase, its queue on the dev broker
   bound to `report.event` and `layout.lite`, the sema snapshot vendored
   first, a sqlite store holding the latest `layout.lite` per house and a
   rolling readings window, pyright in `ci.sh`. Stands on its own with no
   detector (`f569fde`; the live-broker test is the proof).
2. ✅ The store on SQLAlchemy and alembic with `g_nodes`, `layouts`,
   `readings` and `alerts`; the forest projection and the fleet roots
   setting (`2a1d706`); the Orchestrator tier and the Alerter transport
   class (`d5b8387`); no-data as the first detector (`410d52e`,
   witnessed in `experiments/2026-09-15-alerter-no-data/`); the alert
   words published (sema `74393a7`).
3. Shadow run for a week beside gwalert on the alerts box against hw1;
   compare event for event.
4. Read "live" off the OPS-317 liveness signals once they are journaled;
   the roster stays the house set.
5. Port one detector at a time with its tests; the manager pages from the
   new source for each detector as it reaches Verified.
6. Retire gwalert's DB connection when the last detector moves; drop the
   `gw_alerts` role and the façade.

Rough cost: two to three days to a shadow-running actor with no-data, one
to two weeks for the full port with tests.

## Pointers for the next session

- Spec and gaps: `wiki/gridworks-alerts/executor/primary.md` "Invariants"
  and "Known gaps / Open" (the 2026-09-15 additions are the case for this).
- The triage record: OPS-543 and OPS-544 comments, and
  `wiki/gridworks-alerts/changelog.md` entries dated 2026-09-15.
- Current alerter: `gridworks-alerts/src/gwalert/alert_generator.py`
  (detectors from `check_no_data` down; `_alert_reading_channel_filter` is
  the list of channels the detectors actually use).
- Box: `gridworks-infra/alerts/instance-README.md` (deploy recipe first).
- Broker conventions: GridWorks_CLAUDE "GNode aliases carry their universe
  as segment 0" and the gwbase executor on service deployment; the LTN's
  sqlite pattern in `gridworks-scada` ltn.
- Related issues: OPS-449 (manager interface, absorbed), OPS-317
  (liveness signals, read for "live" at step 4), OPS-438 (leave
  Opsgenie).

## Raising, repeating, clearing

Detection and notification are two jobs, and the split is the standard
one: a detector evaluates a rule continuously and an alert is *firing*
for as long as the condition holds; a separate notifier owns everything
about people — grouping, deduplication, repeat cadence, escalation,
acknowledgement, silences. Prometheus and Alertmanager are that split
exactly (a rule is firing or resolved; Alertmanager's `repeat_interval`
decides when a still-firing alert is re-sent, 4 h by default, and a
resolved notification closes it); PagerDuty and Opsgenie deduplicate on
an alert key and escalate by policy. Nobody puts "notify me again" in
the detector.

So the alerter emits **transitions only**: one alert word when a
condition starts to hold, one cleared word when it stops, both carrying
the same `AlertId`. Nothing repeats from the alerter. The notifier owns
the repeat cadence and escalation: today the manager
(`gridworks-alert-manager`); OPS-547 replaces it with Prometheus
Alertmanager and folds the pair into one `gw.alert` word with a `State`,
and the alerter does not otherwise change. The alerter's
own state (which alerts are open) lives in its sqlite store so a restart
neither re-raises nor forgets an open alert.

Two consequences to settle with the manager's owner:

- **Repeat cadence** is the manager's setting per kind, not the
  alerter's. A starting point in the industry's range: re-notify an
  unacknowledged alert at 30 min, then hourly, then every 4 h; an
  acknowledged one never; a cleared one once, as "cleared".
- **A missing cleared word** must not leave an alert open forever. The
  dead-man's switch covers the alerter dying; the manager should also
  expire an open alert it has not heard about for a long window (the
  Alertmanager `resolve_timeout` idea) and say so.

**`NoData` under this pattern.** Raise when a registered, live house has
sent nothing for 10 min (the threshold stays where gwalert has it); clear
on the first message from that house, with the message's arrival as the
evidence. The manager re-notifies on its cadence while it stays open and
sends the cleared notice when data resumes. A house the registry marks
as not expected to report (Standby, decommissioned) is not a `NoData`
case; that is a field on the liveness record, not a rule here.

## The alert vocabulary and kinds

Published 2026-09-15 and described in `executor/gwalerter.md` "Alert
words" and "Alert kinds". The gwalert detector findings that shaped the
kinds are there too.

## Do this next

Settled and built, in `executor/gwalerter.md`: the store, the registry
projection, the fleet roots, the alert words, the output transport
(`TransportClass.Alerter`, gridworks-base 0.5.13 on `main`), the actor
on the Orchestrator tier (`d5b8387`), and the `NoData` rule with its
detector thread, witnessed PASS on the dev broker
(`experiments/2026-09-15-alerter-no-data/`, restart-with-alert-open
included). A dev registry runs from `grid-node-registry` with `gnr api`
and `gnr rabbit` against the seeded `d1` universe.

The three alert words are published and both snapshots (the alerter's
and the experiments repo's) are regenerated from the published set.

**DO THIS NEXT: the shadow deployment**, on the alerts box beside
gwalert, per the gwbase box pattern (gwbase executor
`service-deployment.md`) and `gridworks-infra/box-access.md`: its own
login, its own unit, its own aliases, gwbase's file log plus journald.

Before the box:

1. Push sema `dev` (the words and their publication, `74393a7`) and land
   the alerter's `jm/scaffold` on `main`: the box clones `main` at a
   pushed SHA and nothing else.
2. Broker: the hw1 broker (`rmqbot`, vhost `hw1__1`, AMQPS `hw1-1:5671`)
   takes gwbase 0.5.13's `hybrid_definitions.json` by the rmqbot
   instance-README "Reload the rabbit definitions" recipe (`docker
   restart`, never compose up), then `list_exchanges -p hw1__1` shows
   `alerts_tx` and `alertsmic_tx`. A runtime user for the alerter,
   `hw1.alerts`, by the `rmq-docker/README.md` user recipe (root on
   rmqbot; password to 1Password only).
3. Registry read: `fetch_forest("https://gnr.electricity.works",
   ["hw1.isone.me.versant.keene"])` from the laptop returns the six
   houses (all Pending); that URL is `GWALERTER_GNR_URL`.

On the box (root steps are Jessica's; the exact commands are the gnr
box's "Build a gnr box from nothing", steps for the login, keys, sudoers
and unit install, with `alerter` for `gnr`):

4. Login `alerter` (`adduser --disabled-password`), per-person keys only
   (`alerter-{jessica,thomas,joe}`), `/etc/sudoers.d/alerter` granting
   exactly `systemctl start|stop|restart|status|enable|disable
   alerter-rabbit`, NOPASSWD. The GridWorks CA
   (`gridworks-infra/authority/ca.crt`) into the system trust if the
   alerts box lacks it (gwalert never spoke to the broker; the gnr box
   recipe step installs it).
5. As `alerter`: `uv` user-local; `git clone
   https://github.com/thegridelectric/gridworks-alerter.git` (https, full
   clone, `main`); `uv sync --frozen`; `.env` mode 600 from
   `template.env`: `GWALERTER_SERVICE_ALIAS=hw1.alerts`,
   `GWALERTER_RABBIT__URL` (amqps, `hw1-1.electricity.works:5671`, vhost
   `hw1__1`, the `hw1.alerts` credential),
   `GWALERTER_FLEET_ROOTS=hw1.isone.me.versant.keene`,
   `GWALERTER_GNR_URL=https://gnr.electricity.works`,
   `GWALERTER_SUPER_ALIAS=hw1.super`,
   `GWALERTER_TIME_COORDINATOR_ALIAS=hw1.time` (the aliases the hw1
   registry answers to), thresholds at their defaults. `.bashrc` gets
   `. ~/gridworks-alerter/service/bash_aliases` (`alstart` / `alstop` /
   `alrestart` / `alstatus` / `allog` / `aljournal`).
6. Root: `cp ~alerter/gridworks-alerter/service/alerter-rabbit.service
   /etc/systemd/system/ && systemctl daemon-reload && systemctl enable
   --now alerter-rabbit`. A unit change is re-copy plus daemon-reload.
7. Logs, two places by the pattern: the actor's rotating file
   `~alerter/.local/state/gridworks/alerter/log/hw1.alerts.log` (bind
   line, every raise and clear, every dropped body) and `journalctl -u
   alerter-rabbit` for the CLI's boot lines (forest request, "Tracking
   [...]" naming the six houses) and any crash. First-start check: the
   journal shows the six houses, the file shows the `ear_tx` bind, the
   management UI shows queue `hw1.alerts-F…` consuming, and ten minutes
   later no NoData word for any reporting house.
8. `gridworks-infra/alerts/instance-README.md` gains the third unit, the
   second login, and the hand-placed state (keys, sudoers, `.env`, the
   aliases line, the CA cert); `platform-inventory.md` gains `hw1.alerts`
   on the alerts row.

The shadow week:

9. Notification for `NoData` goes through Alertmanager from day one
   and gwalert's `no_data` check is switched off the same day (OPS-547);
   the week compares detection, not notifiers. Each NoData raise and
   clear in the alerter's `alerts` table (sqlite at
   `~alerter/.local/share/gridworks/alerter/alerter.sqlite`) and file
   log against gwalert's no-data alerts in the manager's history and
   Opsgenie, event for event; a raise the alerter makes that gwalert
   does not is examined, not assumed wrong (elm's summer silence is the
   known case gwalert misses). JournalKeeper does not journal the alert
   words until its seed carries them, so the week's record is the
   alerter's own store; adding the words to gjk's seed comes when the
   web Alerts page moves to the journal.
10. `NoData` reaches Verified when the week matches or beats gwalert;
    then the manager consumes the alerter's words for that kind and the
    next detector starts.
