# broker-alerter — the house alerter as a broker citizen

Status: Draft · Pass 0 · Updated 2026-09-15 · Linear: OPS-545

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
  alerter's open-alert state). Last-heard is a query over readings and
  layouts, not a column; when the liveness word of OPS-546 exists it gets
  its own table and `NoData` reads it there. The scaffold's `houses`
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

- **Vocabulary.** An alert word, a cleared word, and an alert-kind enum are
  new sema words and the spec is change-controlled: discuss before authoring.
  Decide what evidence an alert carries (channels, values, window) so the
  page and the history are self-explaining.
- **Layout bootstrap.** `layout.lite` arrives only on scada boot. The store
  persists the latest per house, but the first boot needs a seed: a one-time
  pull from the journal, or a layout request the scadas do not yet answer.
- **Dead-man's switch.** Alerting and the houses share one broker, so a
  broker outage is silent. The manager pages if the alerter's heartbeat
  stops, over a path that is not the broker (loopback on the box is enough).
- **Which houses are expected is answered by the liveness projection
  (OPS-546), not a rule in the alerter.** Today a house with no
  rows is silently absent from every check (elm, off for the summer). The
  projection is its own design, worked in parallel; until its word is
  published the alerter seeds its expected-house set from the `layout.lite`
  messages in its store, and swapping that seed for the projection is one
  lookup. Standby and MonitorOnly are fields of the record, not exceptions
  in a detector.
- **The house list comes from the registry, as a projection.** The set of
  GNodes the alerter watches is the registry's, consumed the way the gnr
  executor says every copy is: `g.node.forest` broadcasts plus
  `g.node.forest.request` on the hw1 broker, idempotent upserts keyed on
  id, healed by the snapshot broadcast, never gnr's Postgres. This is the
  same seam JournalKeeper's `gw_data.g_nodes` rows use. Registry
  membership says which scadas exist; the liveness projection (OPS-546)
  says which are live; a house in the registry that is not live is what
  `NoData` means. Until the forest broadcast is consumed, the seed is the
  stored `layout.lite` set.
- **Layouts come from their authority, after the spruce merge.** The
  terminal-asset registry (the layout and operational-params sibling of
  the grid-node registry, still a Draft design with no issue) is the
  durable source of every hardware layout, and it will egress like GNR: a
  broadcast on commit plus a request, consumed here as a projection into
  `layouts`. Not before the spruce merge: the layout words
  (`gw.house0.layout` and the families arriving this fall) settle on that
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
2. No-data as the first detector: "no `report.event` from a house in ten
   minutes" read off the queue, the house set seeded from stored
   `layout.lite`, the manager only logging what it receives. Needs the
   alert vocabulary (alert, cleared, kind), which is a spec discussion.
3. Shadow run for a week beside gwalert on the alerts box against hw1;
   compare event for event.
4. Adopt the liveness projection (OPS-546) as the house set
   when its word is published; the seed from step 2 goes.
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
- Related issues: OPS-449 (manager interface, absorbed), OPS-546
  (liveness projection, adopted at step 4), OPS-317 (liveness signals,
  consumed through the projection), OPS-438 (leave Opsgenie).

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
the same `AlertId`. Nothing repeats from the alerter. The manager
(`gridworks-alert-manager`, which already tracks count, sends, state and
acknowledgement) owns the repeat cadence and escalation; if it is ever
replaced by a bought service, the alerter does not change. The alerter's
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

## Findings from reading gwalert (2026-09-15)

Recorded here so the port does not carry them over; the kinds table
below cites them by row.

- **No-data skips the house that most deserves it.** The house list is
  the rows the 2 h query returned, so a house with no reading in the
  window is never checked. The new rule reads last-heard from the store.
- **The on-peak check scans the whole 2 h window**, so it can fire on
  samples from earlier in the window rather than on what is happening now,
  and the per-house flag means only the first offending hour alerts. The
  port fires on live readings only.
- **Pump power never gates the pump alerts**; it only words the message.
  The kinds are named for the flow condition for that reason.
- **`no_more_oil` is dead code**: the method returns before any check.
- **`not_in_atn` is disabled** in gwalert's main loop and handles only
  two boss aliases.
- **`hp_on` means the opposite of its name** (commanded on, drawing
  nothing).

## Proposal: the alert vocabulary

Written before the sema spec was read this session, so it is a starting
point for the spec discussion, not a draft word. The next session checks
each line against the registry and authoring rules for types and enums
and corrects it there.

What gwalert sends the manager today is four fields over HTTP: a free-text
message, the house alias, an alert alias, and a time. The alert alias is
one of eleven snake_case strings (`no_data`, `zone_setpoint`,
`zone_freezing`, `dist_pump`, `store_pump`, `hp_on`, `hp_onpeak`,
`not_in_atn`, `rebooting`, `no_more_oil`, `critical_glitch`), sometimes
with a zone or an hour appended to make it unique per instance. The
nearest published word is `glitch/000` (FromGNodeAlias, Node, Type as a
`log.level`, Summary, Details, CreatedMs), which is a scada reporting on
itself; an alert is a service reporting on a house, and its evidence is
readings.

Three words, all flat, composing by `$ref` only:

- **An alert-kind enum**, PascalCase like every registry enum value, one
  value per detector, each named for the condition a human acts on rather
  than the detector's mechanism. The zone or hour that gwalert appends to
  the alias is evidence, not kind. Names and descriptions are proposed in
  "Alert kinds, named by what they mean" below; the descriptions are the
  enum's per-value descriptions.
- **An alert word** (`gw.alert` or the name the registry convention
  gives it): the alerter's alias as `Src`; the house as `AboutGNodeAlias`;
  the kind; an `AlertId` (uuid4) that the cleared word repeats; `RaisedMs`;
  a one-line human `Summary`; and `Evidence` as a list of channel readings
  in the `channel.readings` word the report already uses, so the page and
  the history can show the values that fired it without a second lookup.
  A zone or hour rides in the evidence's channel names.
- **A cleared word**: `AlertId`, `Src`, `AboutGNodeAlias`, the kind,
  `ClearedMs`, and the same evidence shape for the readings that cleared
  it. Separate from the alert word because the manager and the history
  treat them differently and neither needs the other's fields.

Open for the discussion: whether `glitch` should instead grow to cover
this (it should not; the subject differs), whether the manager's routing
needs a severity field beyond the kind, and whether the alert carries the
detector's threshold so the summary is reproducible from the record.

## Alert kinds, named by what they mean

Read from gwalert's detectors on 2026-09-15. Each row: the proposed value,
what it means (the enum description), the current alias, and what the
read found about the detector. Every threshold stays out of the name and
in the description, so a tuned threshold does not rename a kind.

| Proposed | Means | Today | Note from the read |
| --- | --- | --- | --- |
| `NoData` | A registered, live house has sent no readings for longer than the silence threshold (10 min). | `no_data` | See Findings. Alternatives considered: `HouseSilent`, `ScadaSilent`; `NoData` is what the on-call already says. |
| `ScadaRebootLoop` | The scada has booted repeatedly in a short span (more than 5 `layout.lite` in 5 min). | `rebooting` | Reads off the store's layout arrivals directly. |
| `CriticalGlitch` | The scada reported a glitch at Critical level; the summary is the evidence. | `critical_glitch` | A scada reporting on itself; the alert relays it to a human. |
| `ZoneBelowSetpoint` | A critical zone's temperature is more than the tolerance (2 F) below its setpoint, and the setpoint was not just raised. | `zone_setpoint` | Suppressed in Standby. Zone name rides in the evidence. |
| `ZoneFreezeRisk` | A zone's temperature is below the freeze-risk threshold (40 F). | `zone_freezing` | 40 F is not freezing; the name says risk, the description carries the number. |
| `NoDistFlow` | A sustained heat call ended and no distribution flow was seen since before it started, on three cycles running. | `dist_pump` | Pump power never gates the alert today, only the message wording; the name follows the condition (flow), not the suspect (pump). |
| `NoStoreFlow` | The store pump has been commanded on for more than 10 min with no store flow. | `store_pump` | Same shape as `NoDistFlow`; assumes a store pump exists, which the fall layouts do not all have. |
| `HpNotResponding` | The heat pump has been commanded on for more than 15 min and draws no power. | `hp_on` | The current alias reads as the opposite of what it means. |
| `HpRunningOnpeak` | The heat pump drew power during a weekday on-peak hour. | `hp_onpeak` | See Findings. |
| `LocalControlActive` | The house has fallen back to local control; the LTN is not dispatching it. | `not_in_atn` | Disabled in gwalert today. "Atn" is the legacy name for the LTN. |
| (dropped) | | `no_more_oil` | Dead code: the method returns before any check, and the condition below it never tested the buffer. Not ported until someone defines it. |

## Do this next


Step 2 of the sequence, and the sema spec gate comes first: read
`sema/spec/primary.md`, then the `sema/spec/registry/` and
`sema/spec/authoring/` spokes for types and enums, and post the summary of
that kind's registry, authoring, dependency and axiom rules before any
word is drafted. Then take "Proposal: the alert vocabulary" above through
that discussion, correct it in place, and only after the words are agreed
add them to the registry. In parallel and not gated on the words, in
`gridworks-alerter`: first move the store onto SQLAlchemy models with an
alembic migration chain (the weather service's `alembic/` and
`tests/conftest.py` are the pattern), then the no-data rule, reading
last-heard off the store against the ten-minute threshold and emitting
transitions only, with the manager only logging, and a test that drives
it from stored `report.event` messages through a restart.
