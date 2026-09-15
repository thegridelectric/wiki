# broker-alerter — the house alerter as a broker citizen

Status: Draft · Pass 0 · Updated 2026-09-15 · Linear: OPS-545

**EDD: yes** the shadow run *is* the verification: the new alerter runs beside
gwalert on the alerts box against the live hw1 broker, and each detector
reaches Verified only when a week of shadow output matches or beats gwalert's.

> What this is: the design for replacing gwalert's journal-DB polling with a
> gwbase actor on the hw1 broker that owns its inputs (a durable queue), its
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
  not a default.
- **One durable named queue** on `hw1__1`, bound to the scada topics
  JournalKeeper already journals: `report.event`, `snapshot.spaceheat`,
  `glitch`, `layout.lite`, plus the liveness signals of OPS-317 when they
  exist. Durable so that a restart replays the gap instead of starting blind.
- **Sema at the boundary.** Every message is decoded through the vendored
  snapshot classes; a channel's unit and role come from the layout the scada
  sent, never from a lookup table someone else populates. The `units.py`
  table added under OPS-544 is the thing this retires.
- **A sqlite store**, as the LTNs keep: the latest `layout.lite` per house,
  a rolling window of readings (a few hours covers every detector; all but
  the glitch window read 5–15 minutes), and alert state (open, cleared,
  when, evidence). Restart-safe by construction.
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
- **Which houses are expected.** Today a house with no rows is silently
  absent from every check (elm, off for the summer). Expected-to-report
  belongs with the Standby signal in `layout.lite`, not with a row count.
- **Setpoints that report only on change** (spruce, last between July and
  September) need latest-known values, not a window; the store gives that
  for free but the detector must ask for it.
- **The manager.** Whether it stays a separate process or becomes the same
  actor's paging half. Keep it separate at first; it is the thing that pages
  and should not restart when a detector changes.

## Sequence

Strangler, not rewrite. gwalert keeps running throughout.

1. Vocabulary discussion and the sema words (alert, cleared, kind).
2. Actor skeleton on the alerts box: queue bound, sqlite store, layout
   persisted, heartbeat to the manager, alert events emitted but the manager
   only logs them. No-data is the first detector.
3. Shadow run for a week beside gwalert; compare event for event.
4. Port one detector at a time with its tests; the manager pages from the
   new source for each detector as it reaches Verified.
5. Retire gwalert's DB connection when the last detector moves; drop the
   `gw_alerts` role and the façade.

Rough cost: one session for the design proper, two to three days to a
shadow-running actor with no-data, one to two weeks for the full port with
tests.

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
- Related issues: OPS-449 (manager interface, absorbed), OPS-317 (liveness
  signals, consumed), OPS-438 (leave Opsgenie).

## Do this next

Run `/grill-me` on the "Shape" and "Settle" sections with Jessica, then take
the vocabulary question to the sema spec discussion. Nothing in
`gridworks-alerts` changes until the words exist.
