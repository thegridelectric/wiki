# broker-alerter — the house alerter as a broker citizen

Status: Accepted · Pass 1 · Updated 2026-10-07 · Linear: OPS-545

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
  `gridworks-alert-manager` plays no part (its unit is stopped). Two repos because the two run
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
- **Sema-typed outputs.** The alerter emits `gw.alert` records on the
  broker, `Firing` when a condition starts and `Resolved` when it stops,
  and records each in its store first. The Opsgenie tap pages from the
  store, never from the broker ("Paging through Opsgenie");
  JournalKeeper journals the broadcasts like anything else, so the web page's alerts history reads
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
5. Port one detector at a time with its tests; as each reaches Verified
   the Opsgenie tap pages for that kind and gwalert's check for it is
   switched off the same day.
6. Retire gwalert's DB connection when the last detector moves; drop the
   `gw_alerts` role and the façade.

Rough cost: two to three days to a shadow-running actor with no-data, one
to two weeks for the full port with tests.

## Pointers for the next session

- Spec and gaps: `wiki/gridworks-alerter/legacy/gwalert.md` "Invariants"
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
the repeat cadence and escalation, and the notifier is Opsgenie
("Paging through Opsgenie"). The alerter's
own state (which alerts are open) lives in its sqlite store so a restart
neither re-raises nor forgets an open alert.

Two consequences:

- **Repeat cadence** is an Opsgenie policy setting, not the alerter's.
  A starting point in the industry's range: re-notify an unacknowledged
  alert at 30 min, then hourly, then every 4 h; an acknowledged one
  never.
- **A missing `Resolved` record** must not leave an alert open forever.
  The tap reconciles what Opsgenie has been told against the alerter's
  store, so an alert the store has resolved is closed at the next pass
  even if its record was missed on the broker.

## Paging through Opsgenie

Two small things carry a detected condition to a person.

- **The Opsgenie tap** is the tap of `executor/gwalerter.md` "The tap"
  (`gridworks-alerter` `src/gwalerter/tap.py`): a poller of the
  alerter's store and nothing else. Every `tap_reconcile_s` it reads the
  store's open alerts, creates in Opsgenie each one it has not told
  (alias the `AlertId`, so a retold alert folds into the one Opsgenie
  holds) and closes each it told that the store has since resolved. The
  tap has no broker connection: the one alert whose meaning is "the
  broker is down" must reach a person while the broker is down, and the
  broker-down witness showed a tap that consumed the mic exchange dying
  at connect for the whole outage and paging four minutes late. The
  store is already the truth about which alerts are open, so the
  consumer was a fast path over a backstop that was the real path. The
  cost is latency of one poll, and the poll is cheap (a local sqlite
  read), so the cadence is seconds, against thresholds that are minutes.
  The API key and the team paged are required settings with no default.
  The tap is a separate process so that paging does not restart when a
  detector changes. Tests pin the mapping, the close, the reconcile, the
  retry and a tap with no broker paging a store-held alert
  (`tests/test_tap.py`); witnessed against Opsgenie itself in
  `experiments/2026-10-07-alerter-to-opsgenie/`.
- **The prober**, its own small unit on the alerts box. Alerting and the
  houses share one broker, so a broker outage is silent on the broker
  path: the prober checks the hw1 broker from outside that path and
  posts to Opsgenie directly, never through the broker or the alerter.

  It checks the two doors the fleet uses, as a client of each, and
  nothing else:

  - **AMQPS round trip** (`hw1-1.electricity.works:5671`, vhost
    `hw1__1`, its own scoped user): connect, declare an exclusive
    auto-delete queue, publish one message to it through the default
    exchange, and receive it back. The round trip matters because a
    broker under a memory or disk alarm still accepts connections while
    it blocks every publisher; a connect-only check passes through that
    outage.
  - **MQTT connect** on the TLS listener the scadas use (8883): TLS
    handshake, CONNECT, CONNACK. The MQTT plugin and its listener can
    fail while AMQP is healthy, and that is the door every house comes
    through.

  The management API is not checked: it is a third listener that can be
  up while both doors are shut, and its being down is not an outage.

  One probe a minute. A check that fails three probes running opens an
  Opsgenie alert under a fixed alias for that check
  (`hw1-broker-amqp`, `hw1-broker-mqtt`), so a long outage is one alert;
  the first success closes it. The page says the check is made from the
  alerts box, since a network fault at that box looks the same as a
  broker fault from there. Starting values, tuned once it runs.

**`NoData` under this pattern.** Raise when a registered, live house has
sent nothing for 10 min (the threshold stays where gwalert has it); clear
on the first message from that house, with the message's arrival as the
evidence. Opsgenie re-notifies on its policy while the alert stays open,
and the `Resolved` record closes it when data resumes. A house the registry marks
as not expected to report (Standby, decommissioned) is not a `NoData`
case; that is a field on the liveness record, not a rule here.

## The alert vocabulary and kinds

The alerter runs on one `gw.alert` word with `State` and its enums, all
published (sema `632b58e`), and its snapshot is a published-only build.
Fields and kinds are in `executor/gwalerter.md` "Alert words" and "Alert
kinds" (the gwalert detector findings that shaped the kinds are there
too).

A gap the cold-house detector carries into this design: which sensor a
zone's setpoint is judged against depends on where the setpoint comes
from. A spruce zone's setpoint is learned by the scada from the gw-temp
reading at heat-call end, so only gw-temp is comparable to it; a
smart-thermostat zone's setpoint is comparable to that thermostat's air
reading. gwalert hard-codes spruce to gw-temp
(`gridworks-alerts/src/gwalert/alert_generator.py`
`SETPOINT_TEMPERATURE_ROLES_BY_HOUSE`) until the layout words carry a
zone's setpoint source and thermostat kind; the broker-alerter's
cold-house detector reads the choice off the layout instead.

## Do this next

Settled and built, in `executor/gwalerter.md`: the store, the registry
projection, the fleet roots, the alert words, the output transport
(`TransportClass.Alerter`, gridworks-base 0.5.13 on `main`), the actor
on the Orchestrator tier (`d5b8387`), and the `NoData` rule with its
detector thread, witnessed PASS on the dev broker
(`experiments/2026-09-15-alerter-no-data/`, restart-with-alert-open
included). A dev registry runs from `grid-node-registry` with `gnr api`
and `gnr rabbit` against the seeded `d1` universe.

Alongside the box work, on the laptop: the Opsgenie tap is built,
tested and witnessed against Opsgenie (a `Firing` record opens an
alert and its `Resolved` record closes it, across a tap restart:
`experiments/2026-10-07-alerter-to-opsgenie/`). The tap's outbound
and read-back shapes are sema words, published (sema `8a91cc0`):
`gw.opsgenie.alert.create`, `gw.opsgenie.alert.close`,
`gw.opsgenie.alert`, with `gw.opsgenie.priority` and
`gw.opsgenie.alert.status`. The tap constructs the create and close
through the snapshot and writes Opsgenie's request body from the word;
the experiment emits one `gw.opsgenie.alert` per alert the run touched
and a `gw.experiment.run` 001 carrying `Verdict` Pass; the alerter's
snapshot is published-only again.

The prober is built and tested (`src/gwalerter/prober.py`, `gwalerter
probe`, `alerter-probe.service`, the `probe_*` settings, the `NoData`
hold in `no_data.py`). The broker-down witness
(`experiments/2026-10-07-alerter-broker-down/`) first ran **FAIL** on
2026-10-07: the prober itself passed (one `BrokerUnreachable` per door
29 s after the stop, both resolved 6 s after the start), and two things
around it did not.

1. **The tap cannot page while the broker is down.** `Tap.run` connects
   to the broker first and reconciles after, so with the broker down it
   dies at connect, restarts, and never reads the store; both pages
   arrived four minutes late, at the first connect after the broker
   returned, and were closed 20 s later.
2. **The alerter's detector loop skips every tick while the actor is not
   consuming** (`AlerterActor.run_detectors`), so the `NoData` rule never
   ran during the outage, never saw the open `BrokerUnreachable`, never
   re-floored, and fired `NoData` 5 s after reconnecting with "since"
   the mock's last report before the stop.

Both failures have the same shape: the alerter treated its own
deafness as something to route around (exit and restart, skip the
tick) instead of a state to hold in. Two small changes close them,
smaller than a connect-retry loop in the tap or a new argument on the
rule:

(a) **The tap is store-only.** The broker consumer, its durable queue,
the mic binding and the decode path leave `tap.py`; `Tap.run` is a
loop of reconcile then wait `tap_reconcile_s`, and the default moves
from 300 s to 10 s. Fix as the design first wrote it (reconcile before
connect, retry the connect) would have kept the broker in the tap's
critical path for no gain, since the store already held every record
the consumer heard. Test: a tap with no broker reachable creates a
store-held alert through Opsgenie on its first pass. The actor's mic
broadcast of each record stays: that is for JournalKeeper and any
manager, not for the tap.

(b) **The actor re-floors the rule when hearing resumes.** gwbase calls
`local_rabbit_startup` at the end of every `start_consuming`, so each
reconnect reaches it; the actor moves `NoDataRule.heard_floor_ms` to
now there, exactly as the rule does when the last `BrokerUnreachable`
resolves. `run_detectors` keeps skipping while the actor is not
consuming: while it is deaf every house looks silent for the actor's
reason, and there is nothing to detect. The skip's old justification (a
record raised while the channel is down would never be sent) is no
longer the reason, since the store-driven tap pages such a record; the
reason is the deafness. The rule's `evaluate` keeps its signature.
Test: an actor that resumes consuming past the threshold raises nothing
until a full threshold later.

The two holds in the rule are different facts and both stay: the
actor's consuming state says "I cannot hear", the prober's open
`BrokerUnreachable` says "the houses cannot speak", and they diverge
when the MQTT door is down while AMQPS is up (the actor consumes, every
house goes silent, and without the store check the rule would page the
whole fleet for one broker fault).

Both went in with their tests (now in `7e8c646`), and the witness re-run
on that code is **PASS** on all four steps (both pages 36 s after the
stop with the broker down, both closed 14 s after its return, no
`NoData`; `evidence/2026-10-07-pass/`). One hold the run cannot
exercise is the rule's hold on an open `BrokerUnreachable` while the
actor itself hears (MQTT door down, AMQPS up); a one-door outage would
be its own run, not a gate for the shadow deployment.

**DO THIS NEXT:**

**The shadow deployment**, on the alerts box beside
gwalert, per the gwbase box pattern (gwbase executor
`service-deployment.md`) and `gridworks-infra/box-access.md`: its own
login, its own unit, its own aliases, gwbase's file log plus journald.

Before the box:

1. ✅ `jm/gw-alert` is squashed to one commit (`7e8c646`: the move to
   `gw.alert`, the Opsgenie tap on the words, the published-only
   snapshot, the prober, the store-only tap and the re-floor on resume)
   and pushed. ◐ Merge it to `main`: the box clones `main` at
   a pushed SHA and nothing else.
2. Broker. ✅ Definitions: the hw1 broker (`rmqbot`, vhost `hw1__1`,
   AMQPS `hw1-1:5671`) took gwbase 0.5.13's `hybrid_definitions.json`
   on 2026-09-17 by the rmqbot instance-README "Reload the rabbit
   definitions" recipe; the diff against the previous file was exactly
   the two exchanges and the `alertsmic_tx → ear_tx` binding, and
   `list_exchanges -p hw1__1` shows 20 including `alerts_tx` and
   `alertsmic_tx`; every AMQP and MQTT client reconnected. ◐ Runtime
   user `hw1.alerts` by the `rmq-docker/README.md` user recipe (root on
   rmqbot; password to 1Password only), the first scoped service user
   on hw1 (every other service connects as `smqPublic`). The actor
   declares its consume exchange and its own queue on connect, binds the
   queue to `alerts_tx` and `ear_tx`, consumes it, and publishes on
   `alertsmic_tx`; binding needs write on the queue and read on the
   exchange, so the three regexes are:

   ```shell
   sudo docker exec rmq1 rabbitmqctl set_permissions -p hw1__1 hw1.alerts \
       '^(hw1\.alerts-.*|alerts_tx)$' '^(hw1\.alerts-.*|alertsmic_tx)$' \
       '^(hw1\.alerts-.*|alerts_tx|ear_tx)$'
   ```

   Run after the ✅ above, before step 5's `.env`.
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

9. gwalert keeps paging Opsgenie for no-data through the week and the
   alerter pages no one; the week compares detection. Each NoData raise and
   clear in the alerter's `alerts` table (sqlite at
   `~alerter/.local/share/gridworks/alerter/alerter.sqlite`) and file
   log against gwalert's no-data alerts in Opsgenie, event for
   event; a raise the alerter makes that gwalert
   does not is examined, not assumed wrong (elm's summer silence is the
   known case gwalert misses). JournalKeeper does not journal the alert
   words until its seed carries them, so the week's record is the
   alerter's own store; adding the words to gjk's seed comes when the
   web Alerts page moves to the journal.
10. `NoData` reaches Verified when the week matches or beats gwalert;
    then the Opsgenie tap goes live for that kind, gwalert's `no_data`
    check is switched off the same day so no house is paged twice, and
    the next detector starts.
