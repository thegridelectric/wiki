# gwalerter — the broker alerter

Status: Draft · Pass 0 · Updated 2026-10-09

> What this is: the house alerter as a gwbase actor on the fleet broker
> (`thegridelectric/gridworks-alerter`, package `gwalerter`): its inputs,
> its store, which houses it watches, its detectors, and the alert words
> it emits. Built beside gwalert and taking over one detector at a time
> (OPS-545); a detector reaches Verified by a shadow week against hw1.

## What it is

An Orchestrator-tier gwbase actor of transport class `Alerter`
(`ServiceSettings`; a service, not a GNode, alias `<universe>.alerts`)
with the standard auto-delete queue on the universe's broker. It taps
the ear exchange with a `#` binding beside the class binding the tier
makes, and gates on the parsed envelope's type name, the way
JournalKeeper does. Nothing is durable on the broker: the journal is
the durable record, a queue that fills while the alerter is down would
be a second outage, and restart is handled in the store. Three message
types reach the store:

- `report.event` — each scada's readings, unrolled to one row per value.
- `layout.lite` — the scada's hardware layout, kept latest per scada.
- `g.node.forest` — the registry's topology broadcasts, projected by
  immutable `GNodeId`.

Every message is decoded through the vendored sema snapshot
(`src/gwalerter/sema`, generated from `sema_seed_request.yaml` by
`scripts/regen_sema_snapshot.sh`), each message at the version it was
sent, never upgraded: the seed names `report.event` 002 through 004, the
versions the fleet's scadas send, and an arrival at any of them counts.
(A 003 report may carry a MessageId that differs from Report.Id; 004's
identity axiom would reject it upgraded, and the report is valid as
sent.) A body that fails to decode is logged and dropped; the actor
keeps consuming.

## Which houses

The fleet is a registry subtree. `GWALERTER_FLEET_ROOTS` (comma-separated
root aliases, no default; `hw1.isone.me.versant.keene` for Millinocket)
names it, and every TerminalAsset in the projection under those roots
whose status is Pending or Active is tracked: a house pages from the day
it reports, before the registry settles its position, and a Suspended
house is out of service on purpose and does not page. A house that must
not page lives outside the roots.
Membership is a registry fact, edited where the registry is edited; the
alerter keeps no roster. A scada's house is the `.ta` sibling under its
parent alias, the aliasing the registry's `g.node.gt` axioms state. A
scada heard from that reports for no tracked house is logged once per
boot, so a forgotten install is visible.

At boot the CLI posts a `g.node.forest.request` for the roots to the
registry's HTTP read (`GWALERTER_GNR_URL`, no default) and upserts the
answer; if the registry is unreachable the actor still runs and converges
from the broadcasts. An older forest never overwrites a row a newer one
wrote (`SendTimeMs`).

## The store

sqlite in the service's XDG data dir, behind SQLAlchemy, the schema
applied by the alembic chain under `src/gwalerter/migrations/` when the
store opens; nothing calls `create_all`, and the tests build their
database through the chain. One table per sema word the alerter keeps:

- `g_nodes` — the projection; payload is the `g.node.gt` wire form.
- `layouts` — latest per scada, by type name and version.
- `readings` — scada alias, channel, value, the scada's read time and
  the alerter's arrival time. Rows that arrived before the window
  (`readings_window_s`, 4 h) leave on every report.
- `alerts` — each alert's `Firing` record and, once it ends, its
  `Resolved` record, keyed by `AlertId` and indexed by what the alert is
  about (category, house alias or subject, kind): the open-alert state
  that survives a restart.
- `arrivals` — the latest arrival from each alias under the fleet
  roots, any message type, read off the routing envelope with the body
  undecoded: one row per alias, overwritten on each arrival. Whether a
  house's scada and LTN are speaking is read from here. The actor binds
  the audit exchange with `#` and `amq.topic` fans every MQTT publish
  into it, so everything a house's scada or LTN sends is counted, most
  of it never journaled.

Last-heard is a query, the latest arrival across readings and layouts,
never a column; a scada with a wrong clock cannot look alive. Across a
restart the projection, layouts and alert state survive; the readings
window refills from live traffic, so a detector that needs a window waits
one window before it can fire. Rows load back as codec-validated
instances or typed records, never tuples.

## Alert words

One word, `gw.alert` (`sema/definitions/types/gw.alert/000.yaml`), with
its enums `gw.alert.category`, `gw.alert.state` and a kind enum per
category (`gw.house.alert.kind`, `gw.fleet.alert.kind`,
`gw.platform.alert.kind`), and the tap's words,
`gw.opsgenie.alert.create`, `gw.opsgenie.alert.close` and
`gw.opsgenie.alert` with `gw.opsgenie.priority` and
`gw.opsgenie.alert.status`. All are published, and the alerter's
snapshot is a published-only build. An alert is a service reporting on something from the evidence
it received; `glitch` is a node reporting on itself, which is why it did
not grow to cover this.

- `Src` (the alerter), `Category` (House, Fleet, PlatformService),
  `Kind` from the enum the category selects, `State` (Firing,
  Resolved), `AlertId`, `RaisedMs`, `ResolvedMs` on a Resolved record
  only, `Summary`, `Evidence` (a list of `channel.readings`).
- What it is about: a House alert carries `AboutGNodeAlias`, the house's
  terminal asset read off `g_nodes` at raise time so a rename never
  strands an alert; any other category names a service or host in
  `Subject`.
- Each kind enum is versioned, one value per detector, `Unknown` first
  and default, so a decoder on an older version meets a later kind as
  something a notifier drops, never as a no-data page.

The alerter emits transitions only: a `Firing` record when a condition
starts to hold, a `Resolved` record with the same `AlertId` and
`RaisedMs` when it stops. Repeat cadence, escalation and acknowledgement
are the notifier's. No severity field: the kind is what the notifier
routes on. Thresholds live in the kind's description and the alerter's
configuration, never in the record.

The record leaves the alerter as a broadcast on its own mic exchange
(`alertsmic_tx`) with `AboutGNodeAlias` as the radio channel, else
`Src`, so a House record's key reads
`rjb.<alerter>.alerts.gw-alert.<house alias>` and a consumer binds by
house on the tail. The mic exchange fans into the ear exchange, so
JournalKeeper can journal the words and a notifier tap hears them.
Sending is best-effort by gwbase contract: the store already holds the
record, so a failed send is logged, not retried.

## Alert kinds

Named for the condition a human acts on, never the detector's mechanism;
a tuned threshold does not rename a kind. Each row: the kind, its
meaning, gwalert's alias, and what reading gwalert found.

| Kind | Means | gwalert | Note from the read |
| --- | --- | --- | --- |
| `NoData` | A tracked house has sent nothing for longer than the silence threshold (10 min). | `no_data` | gwalert's house list is the rows its 2 h query returned, so a house with no reading in the window is never checked; the new rule reads last-heard from the store. |
| `ScadaRebootLoop` | The scada has booted repeatedly in a short span (more than 5 layouts in 5 min). | `rebooting` | Reads off layout arrivals directly. |
| `CriticalGlitch` | The scada reported a glitch at Critical level; the summary is the evidence. | `critical_glitch` | A scada reporting on itself; the alert relays it to a human. |
| `ZoneBelowSetpoint` | A critical zone is more than the tolerance (2 F) below its setpoint, and the setpoint was not just raised. | `zone_setpoint` | Suppressed in Standby. Zone name rides in the evidence. The port gates on the zone's setpoint-phase state, not the last value on the setpoint channel: a learned setpoint is checked only while its phase is `LastHeatCallEndTemp`; `Unknown` and `Suspect±` are no check at all. gwalert reads the last value and cannot tell silence from persistence; its tolerance equals the learner's, so the two trip together and gwalert paged spruce 2026-10-08 on a room whose setpoint the scada had just dropped. |
| `ZoneFreezeRisk` | A zone is below the freeze-risk threshold (40 F). | `zone_freezing` | 40 F is not freezing; the name says risk, the description carries the number. |
| `NoDistFlow` | A sustained heat call ended and no distribution flow was seen since before it started, on three cycles running. | `dist_pump` | Pump power never gates the alert in gwalert, only the message wording; the name follows the condition (flow), not the suspect (pump). |
| `NoStoreFlow` | The store pump has been commanded on for more than 10 min with no store flow. | `store_pump` | Assumes a store pump exists, which the fall layouts do not all have. |
| `HpNotResponding` | The heat pump has been commanded on for more than 15 min and draws no power. | `hp_on` | gwalert's alias reads as the opposite of what it means. |
| `HpRunningOnpeak` | The heat pump drew power during a weekday on-peak hour. | `hp_onpeak` | gwalert scans the whole 2 h window and its per-house flag lets only the first offending hour alert; the port fires on live readings only. |
| `LocalControlActive` | The house has fallen back to local control; the LTN is not dispatching it. | `not_in_atn` | Disabled in gwalert; "Atn" is the legacy name for the LTN. |
| (none) | | `no_more_oil` | Dead code in gwalert; not ported until someone defines it. |
| `AllHousesSilent` (Fleet) | Every tracked house is silent at once. | (none) | Vocabulary only; the broker-down case is `BrokerUnreachable`, and this kind waits for a cause that is not the broker. |
| `BrokerUnreachable` (PlatformService) | A door of the fleet's broker fails the prober's check three probes running; `Subject` is the door as host:port. | (none) | gwalert polls the journal and has no broker check. Raised by the prober, not a detector over the store; while one is open, `NoData` holds. |

## Detectors

A detector is a rule over the store, evaluated on the actor's detector
thread every `detector_tick_s` (10 s) once the actor is consuming, so a
transition raised while the channel is down is never recorded and lost.
The alerter never polls a house: arrivals write the store on the
consumer thread, and the tick reads it. Each rule records a transition
in `alerts` before the actor broadcasts it, and the store stays the
truth. Raise latency is the threshold plus at most one tick; a clear
does not wait for a tick, it happens in dispatch on the arrival that
clears it. Thresholds are settings (`template.env`), never in the
record.

A detector's first bar is a witness on the dev broker before its shadow
week: a mocked scada built through the snapshot classes, a bus tap
writing every alert word to `instances/`, the alerter from its CLI with
sped-up thresholds and the fleet root narrowed to the mocked house, and
the alerter restarted while the alert is open. The shape is
`experiments/2026-09-15-alerter-no-data/`.

- `NoData` (`no_data.py`): every tracked house whose last-heard is older
  than `no_data_silence_s` (600) and has no NoData alert open is raised
  once, empty evidence, the summary naming the house and its last-heard
  time. Last-heard is the store's query floored at the alerter's boot
  time, so a fresh alerter gives every house one threshold to speak
  before paging. The first report or layout from the house's scada
  resolves it with that arrival as evidence (the report's readings;
  empty for a layout). Open-alert state is the store's, which is what
  makes a restart neither re-raise nor forget. Witnessed PASS on the dev
  broker on `gw.alert` 2026-09-28 (`gridworks-alerter` `7e8c646`),
  restart with the alert open included; the shadow week against hw1 is
  what makes it Verified.

  A report is the only arrival for the rule: the scada publishes a
  report only while its link to the LTN is active (an Event in its
  proactor, held on disk otherwise), so a stopped report means the
  house's data is not reaching the cloud, whichever side stopped it.
  The summary names the cause from whether the house's two parties have
  been heard at all: the scada (the `.scada` sibling) and the LTN (the
  terminal asset's parent alias) are each "speaking" when anything
  arrived from them inside `heard_period_s` (60, the expectation that
  each is heard at least once a minute) times the Nyquist factor 2.1
  (`NYQUIST`, as the scada sizes its own monitored-name timeouts). No
  message type is looked at and no per-type cadence is assumed, since
  the scada's and LTN's chatter is configurable and will change. Never
  the silence threshold, under which a scada dead for nine minutes would
  still read as speaking:

  | Scada speaking | LTN speaking | Summary clause |
  | --- | --- | --- |
  | no | no | `scada and ltn both silent` |
  | no | yes | `scada silent; ltn speaking` |
  | yes | no | `scada speaking; ltn silent` |
  | yes | yes | `scada and ltn both speaking; reports not arriving` |

  The first row is the house side (the prober's BrokerUnreachable holds
  NoData for the MQTT door); the second the pi or its network; the third
  the LTN process or box, with reports safe on the scada's disk; the
  fourth a fault between two live parties, the scada's link never going
  active or its own report path, on a house that looks healthy from
  outside. The rule re-reads the clause on every tick and, when it
  moves, rewrites the open alert's `Firing` record in the store and
  broadcasts it again under the same `AlertId`. Resolve names only the
  return of reports.

  While the broker is down the rule does nothing: no raise and no
  clause update, since `evaluate` returns before the house loop on an
  open `BrokerUnreachable`, and the actor skips the tick while it is
  not consuming. An open NoData keeps the clause it had and the
  `arrivals` rows stop moving. On the broker's return the floor moves,
  so nothing new can raise for a full threshold, but the next tick
  re-reads the clause before the first arrivals land, and for up to one
  Nyquist window (126 s) an open alert may read "scada and ltn both
  silent" and then correct itself. A summary flicker, not a page; if
  the shadow week shows it, the hold is one window on the clause after
  the floor moves.

  What remains a page at scale: a homeowner's internet outage (rows one
  and two) becomes a displayed fact, routine at a hundred homes, the
  readings held on the scada and uploaded on return, nothing to act on
  from the cloud. An LTN not up (row three, and a fleet of them when an
  LTN box goes down) is always a page: the LTN is the house's controller
  and the platform's responsibility. A scada speaking but not sending
  its reports (row four) is always a page: a fault in our code or broker
  path on a house that looks healthy from outside, which nothing but an
  alert finds.

## The tap

`gwalerter tap` is the alerter's second process: the only thing that
talks to Opsgenie, and a poller of the store with no broker connection.
The one alert that means the broker is down has to reach a person while
the broker is down, and the store is already the truth about which
alerts are open, so the tap reads it and nothing else: every
`tap_reconcile_s` (10) it takes the store's open alerts
(`Store.open_alerts`, the same sqlite the actor and the prober write)
and maps each onto the tap's outbound words, which the post writes into
Opsgenie's Alert API shape (`opsgenie_url`, `GenieKey` auth with
`opsgenie_api_key`, every alert to the team `opsgenie_team_id`). The
cadence is the longest a page waits; it is a local read, so seconds,
against thresholds that are minutes. An open alert becomes a
`gw.opsgenie.alert.create` whose `Alias` is the `AlertId`, which
Opsgenie deduplicates on: a `Firing` told twice is one alert, a
re-raise after a resolve a new one. The headline `Message` is `[house]
summary` for a house alert (the segment before `.ta`, display only),
else the summary, cut to Opsgenie's 130 characters; `Entity` is the
full `AboutGNodeAlias` (else `Subject`, else `Src`), so two houses with
one short name are two alerts; `Source` is `Src`; `Tags` the category
and kind; the named details `Kind`, `Category`, `Subject`, and for a
house alert `House` and `About` (the full alias plus the registry's
display name), which the post writes into Opsgenie's flat `details`
map under their lower-case names. Every alert is `P1`
(`gw.opsgenie.priority`), a starting value. A `Resolved` record becomes
a `gw.opsgenie.alert.close` of the alias with its summary as the
`Note`. What Opsgenie holds is read back as `gw.opsgenie.alert` (alias,
status, count, created, closed by), the word a shadow-week comparison
reads lists of. Who is paged, how often an open alert re-notifies and
how it escalates are Opsgenie's policy.

The tap keeps the set of alerts Opsgenie has been told are open and
each pass reconciles it: an open alert Opsgenie has not taken is
created, one Opsgenie holds that the store has resolved is closed with
its `Resolved` record (`Store.resolved_record`). At boot the told set is
empty, so the first pass re-creates every open alert and Opsgenie folds
each into the alert it already has; that is what makes a tap restart
neither re-page nor forget. A post that fails after three attempts on a
transport error is logged and left for the next pass; a refusal (4xx)
is logged and not retried. Tests pin the mapping, the reconcile, the
retry and a tap with no broker reachable paging a store-held alert
(`tests/test_tap.py`). Witnessed PASS on the laptop against Opsgenie
itself, restart with the alert open included:
`experiments/2026-10-07-alerter-to-opsgenie/`.

## The prober

`gwalerter probe` (`src/gwalerter/prober.py`) is the alerter's third
process and the one detector that reads no broker. The alerter and the
houses share one broker, so a broker outage is silent on the broker
path: the alerter hears nothing and sees every house as silent at once.
The prober checks the broker's two doors from outside that path, as a
client of each, every `probe_interval_s` (60): an AMQPS round trip on
`probe_amqp_url` (connect, declare an exclusive auto-delete queue,
publish one message to it through the default exchange, receive it
back; a connect-only check passes through a memory or disk alarm that
blocks every publisher) and an MQTT connect on `probe_mqtt_host:port`,
the TLS listener the scadas use (handshake, CONNECT, an accepted
CONNACK; the prober carries no username or password, its cert and
instance id are its login, and a refused CONNACK is the door shut: what
refuses the prober at the gate, FIS down or the gate broken, refuses
every scada). Both doors present the prober's cert and one instance id,
the AMQPS claims' and the MQTT client id, so the gate leases the prober
once; a client id that is not a uuid4 is refused as malformed, and a
second uuid4 would supersede the first. The
management API is not checked: a third listener that can be up while
both doors are shut. A door that fails `probe_failures_to_raise` (3)
probes running raises one `gw.alert` (`PlatformService`,
`BrokerUnreachable`, `Subject` the door as host:port, never the URL)
into the store with `Store.raise_alert`; the first success resolves it
with `Store.clear_alert`. The prober has no Opsgenie client: the tap
pages the record on its reconcile pass from the store, so the page
arrives within `tap_reconcile_s` with no broker involved. The probe is
made from the alerts box, so a network fault there looks the same as a
broker fault, and the summary says so. Witnessed PASS on the laptop
against the dev broker and Opsgenie itself, a four-minute broker stop
with the tap paging both doors while it was down and no `NoData` after
its return: `experiments/2026-10-07-alerter-broker-down/`
(`evidence/2026-10-07-pass/`). Witnessed PASS against prod on
2026-10-11: the hw1 broker's listeners down for 9 min 20 s, both doors
raised 3 min 36 s after they stopped and resolved 17 s after startup, no
`NoData` meanwhile (`experiments/2026-10-11-prod-broker-outage-drill/`).

The fleet being heard outranks the probe. Each tick the prober reads
the store's latest arrival from any alias (`Store.latest_arrival`, the
`arrivals` table the actor writes off every envelope); while anything
arrived inside the last `heard_period_s` (60), the broker is carrying
the fleet's data whatever the probe found, so a failing door is logged
but not counted, nothing is raised, and an open `BrokerUnreachable`
resolves with a summary saying the fault is the prober's own (its
login, its cert, the box's network). The failures that raise are the
ones running while the fleet is unheard, so "three probes running"
means three minutes of a shut door and a silent fleet together.

While a `BrokerUnreachable` alert is open, the NoData rule raises
nothing (`NoDataRule.broker_unreachable`, read off the store's open
alerts each tick); when the last one resolves, the rule moves its
last-heard floor to that moment, as at its own boot, so each house gets
one silence threshold to reconnect before it pages. The actor's own
hearing is the other hold, a different fact: the detector thread skips
its tick while the actor is not consuming, and each time consuming
starts (boot and every reconnect, gwbase's `local_rabbit_startup`) the
actor moves the same floor to that moment
(`AlerterActor.hearing_resumed`). The two diverge when the MQTT door is
down while AMQPS is up: the actor hears, the houses cannot speak, and
only the prober's alert holds the fleet off paging. A `NoData` already
open stays open and resolves on the house's first message. The prober's
records reach the store and the tap but not the broker, so JournalKeeper
does not see them (Open).

## Operating

- Settings: `GWALERTER_*` from env and `.env` (`template.env`);
  `service_alias` is `<universe>.alerts` under the universe root.
- Run: `gwalerter rabbit` (the systemd unit `alerter-rabbit.service`),
  `gwalerter tap` (`alerter-tap.service`) and `gwalerter probe`
  (`alerter-probe.service`);
  stop is systemd's SIGTERM, which the actor takes without a hook: every
  store write is one sqlite transaction and the broker holds nothing.
- Schema change: edit `db_models.py`, `uv run alembic revision
  --autogenerate -m "..."`, review the file; the chain applies on open.
- Vocabulary change: edit the seed, `scripts/regen_sema_snapshot.sh`,
  `./ci.sh`. The seed takes published words only.
- CI: `ci.sh` runs ruff, pyright and pytest; the live-broker tests
  self-skip without `gw-dev-rabbit`.

## Open

- The detectors after `NoData`, and each Verified by a week of shadow
  output beside gwalert on the alerts box against hw1.
- The tap creates an Opsgenie alert once, from the `Firing` record it
  first sees, so a cause clause that moves while the alert is open
  reaches the store and the mic but not the page; carrying it to Opsgenie
  is an update call and its own word.
- Paging by cause: the LTN rows are a cloud-side fault and the house
  rows a house-side one, which is what a paging rule routes on; a
  fleet-level rollup when many LTNs fall silent at once; and a faster
  LTN-silent kind with its own threshold (knowable in three minutes,
  where reports take ten). All belong to the tap's paging rules.
- Layout seeding at first boot; the dead-man's switch; the journaled
  OPS-317 liveness signals as the source of "live". The design carries
  these.
- The `layouts` table stores whichever layout word a scada last sent,
  but the snapshot vendors `layout.lite` only and `Store.record_layout`
  / `Store.layout` are typed `LayoutLite`; a `gw.house0.layout` or
  `gw.nolan.layout` is dropped at the codec today. The move is the seed
  plus a union type with `isinstance` dispatch, when a tracked house
  sends one; no schema change.
- The prober's `BrokerUnreachable` records reach the store and the tap
  but not the broker, so JournalKeeper does not see them; the alerter
  re-broadcasting them once the broker is back is open.
