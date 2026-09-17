# alertmanager — Prometheus Alertmanager as the notifier, one `gw.alert` word

Status: Draft · Pass 0 · Updated 2026-09-17 · Linear: OPS-547

**EDD: yes** the experiment *is* the verification: the new alerter, on
the dev broker with spruce's scada stopped, raises a spruce `NoData` as
a `gw.alert` that arrives in Alertmanager's alert list and pages the
Telegram test group, and the `Resolved` record on spruce's return
closes it. Spokes reach Verified only when that harness runs
(`experiments/2026-09-XX-alerter-to-alertmanager/`, date set when it
runs).

> **What this is.** The design that puts Prometheus Alertmanager on the
> alerts box as the notifier for every GridWorks alert, retires the
> hand-written Telegram dispatcher, and reshapes the alert vocabulary
> into one `gw.alert` word whose fields map onto Alertmanager's intake
> one for one. It sequences after the alerter's shadow deployment
> (OPS-545) and changes that design's notification path: not an A/B of
> two notifiers, but the new path from the first live detector.

## Why

The manager (`gridworks-alert-manager`, ~640 lines) does a job with a
well-known shape: token-guarded intake, Telegram sends, a reminder every
5 minutes, escalation to more recipients after 3 sends, an on-call
schedule read from a Google Sheet, daily mute cleanup, a history
endpoint. That list is close to a description of Alertmanager: routing
tree, grouping, `repeat_interval`, silences with expiry, resolved
notifications, inhibition, a native Telegram receiver, `resolve_timeout`
for alerts that never clear, and an HA pair if ever wanted. Hand-rolling
it is a known trap regardless of who writes it; field feedback in
September 2026 is that the pages are not working well. On Alertmanager
those complaints become config changes.

Alertmanager is one static binary with an HTTP intake
(`POST /api/v2/alerts`) and needs no Prometheus. Prometheus and Grafana
stay out until someone wants infrastructure time series; if that day
comes, Rabbit's own `rabbitmq_prometheus` plugin is the first source and
Alertmanager is already in place to receive its rules.

## Shape

```
gridworks-alerter ──gw.alert on alertsmic_tx──▶ broker ──▶ tap ──▶ Alertmanager ──▶ Telegram
prober (broker reachability, out of band) ───────────────────────▶ Alertmanager
```

Three parts, one section each below: the word both writers emit, the
notifier on the box, and the connection between the alerter and the
notifier. The prober is a later spoke, named so the intake is designed
for two writers.

## The word

One `gw.alert` (sema `3de1363`, staging), replacing `gw.house.alert`
and `gw.house.alert.cleared`, which were deleted before sema's launch.
Fields:

- `Src` (the emitting service's alias).
- `Category`, versioned enum `gw.alert.category`: `Unknown`, `House`,
  `Fleet`, `PlatformService`. Nouns for the subject. `Fleet` is the
  first non-house category the alerter itself needs: every tracked
  house silent at once is a broker or ear condition, not six house
  conditions.
- `Kind`, a `oneOf` over `gw.house.alert.kind`, `gw.fleet.alert.kind`
  and `gw.platform.alert.kind`, each `Unknown`-first. Axiom 1:
  `Category` selects the enum, and the runtime decodes `Kind` with that
  enum (sema spec "Composition Rule"). Adding a category is a new enum,
  a new branch, and a new `gw.alert` version.
- `State`, literal enum `gw.alert.state`: `Firing`, `Resolved`. One
  word with a state: one journal table, one decoder, one bind, and
  `Resolved` becomes Alertmanager's `endsAt`.
- `AlertId` (uuid4), the same on the `Firing` and `Resolved` records.
- `AboutGNodeAlias`, optional; axiom 2: `House` requires it and it ends
  in `.ta`.
- `Subject`, optional string naming a service or host. Open: a
  `gw.platform.service` enum instead, if the router needs to match on
  it.
- `RaisedMs`; `ResolvedMs` optional, axiom 3: present iff `Resolved`.
- `Summary`, one line. `Evidence`, optional list of `channel.readings`.

Field list and `Category` values settled 2026-09-16.

Two principles the word and its detectors hold to:

- **No magic strings.** Every value with vocabulary behind it is a sema
  word: `Kind` is an enum, never a free label; evidence is
  `channel.readings`; a detector finds its channels through the house's
  `layout.lite` (the channel's telemetry name, its node's role), never
  by matching a hard-coded channel-name string. Hard-coded channel names
  in data services are the standing team rule's named enemy, and the
  detector port from gwalert (zone temperatures, flows, heat-pump power)
  is where this bites: each ported detector states which layout words
  it looks up, and a lookup that has no word yet is hand-coded with a
  note naming the missing word.
- **Identity is the full GNode alias.** A short name (`oak`, `spruce`)
  will stop being unique as the fleet grows: another town's `oak` has a
  different `AboutGNodeAlias`. The record carries the full alias; the
  short name is display only, derived at the notifier's edge for the
  headline, with the full alias and the registry's display name in the
  body so two houses with one short name are told apart where a reader
  acts.

## Alertmanager on the box

- Static binary under `/opt/alertmanager`, its own login
  `alertmanager`, unit `alertmanager.service`, `amtool` beside it for
  silences and config checks.
- Config `alertmanager.yml` committed in `gridworks-infra/alerts/`; the
  Telegram token by `bot_token_file` (mode 600, outside git, recorded in
  the instance-README as hand-placed state). A config change is a
  commit, a copy, `amtool check-config`, then a reload (SIGHUP).
- Intake bound to loopback only; nothing off the box can post.
- Routing: one route per `category`, a Telegram receiver per on-call
  group, `repeat_interval` 4 h to start, `resolve_timeout` 1 h,
  `send_resolved: true`. Escalation by count and the sheet-driven
  rotation are not carried over: for six houses, one Telegram group per
  route and the people in it handle rotation. A rotation, if wanted
  later, is a generator from the sheet into `time_intervals`, as a
  separate issue.
- Not an A/B. `NoData` pages through Alertmanager from the day the
  alerter goes live on hw1; gwalert's `no_data` check is switched off
  the same day so no house is paged twice. The OPS-545 shadow week
  compares *detection* against gwalert's history, not two notifiers.

## Connecting them: the tap

- A second console script in `gridworks-alerter` (`gwalerter-tap`, its
  own unit on the alerts box), same snapshot, same broker settings,
  binding `alertsmic_tx` by the `gw-alert` type segment. Lives in the
  alerter repo so the vocabulary snapshot is vendored once.
- It decodes each `gw.alert` (`expect=`), maps it, and posts to
  Alertmanager on loopback. Mapping: `alertname` = `Kind`; labels
  `category`, `subject` (the full `AboutGNodeAlias` or `Subject`, the
  dedup identity), `src`, `alert_id`; annotations `summary`, `house`
  (the short name for the headline: the segment before `.ta`), and
  `about` (the full alias plus the registry's display name, for the
  body); `startsAt` = `RaisedMs`; `endsAt` = `ResolvedMs` when
  `Resolved`. Alertmanager dedups on the label set, so a re-sent
  `Firing` is idempotent and a `Resolved` closes it, and two houses
  sharing a short name never collapse into one alert.
- Best effort with a retry on connection refused; the alerter's store
  and the journal are the durable record, so a dropped post is logged,
  not queued.
- `gridworks-alert-manager` retires when the Alerts web page reads the
  journal instead of the manager's history (its own issue).

## The prober

A small script on the alerts box, its own unit and timer, that opens
AMQPS to `hw1-1.electricity.works:5671` and reads the management API,
and posts a `gw.alert` (`PlatformService`, `BrokerUnreachable`)
straight to Alertmanager, never over the broker. A later spoke.

## The experiment

Re-runnable harness, on the laptop against `gw-dev-rabbit` and a local
Alertmanager, later on the alerts box against hw1:

1. Alertmanager up with the committed config, Telegram receiver pointed
   at a test group; `amtool alert add` proves the receiver.
2. The alerter and the tap up; the simulated spruce scada reporting;
   the alerter's log shows spruce tracked.
3. Stop the spruce scada. Within the silence threshold plus a tick the
   alerter's store holds a `Firing` `NoData` for `spruce.ta`, the tap's
   log shows the post, `amtool alert query` lists it with
   `category=House alertname=NoData subject=…spruce.ta`, and the test
   group receives the page.
4. Start the spruce scada. The `Resolved` record follows the first
   report; `amtool` shows the alert gone; the group receives the
   resolved notice.
5. Restart the alerter and the tap with the alert open: nothing
   re-pages, nothing is forgotten.

PASS is all five, logged to the experiment folder with the harness
script and the Alertmanager config used.

## Sequence

1. The alerter moves to `gw.alert` with `State`: snapshot regenerated
   with staged words allowed, store and NoData rule on one word, tests
   green, the OPS-545 no-data experiment re-run on the dev broker.
2. The tap in `gridworks-alerter`, with a test against gw-dev-rabbit
   posting to a local Alertmanager.
3. The experiment above on the laptop: PASS.
4. Alertmanager on the alerts box: login, binary, config, unit, token
   file; `amtool` sends a hand alert and it reaches Telegram.
5. The five words promoted to published; the tap's unit on the box; the
   experiment re-run against hw1 with spruce's real scada; gwalert's
   `no_data` off.
6. `gridworks-infra/alerts/instance-README.md` and
   `platform-inventory.md` updated; the executor's "Alert words" and
   the manager paragraphs rewritten to present tense.
7. The prober (own spoke when reached).

## Do this next

Step 1: regenerate the alerter's snapshot with staged words allowed
(the seed's published-only line is for the box, not the dev round),
swap the store and the NoData rule to one `gw.alert` with `State`,
regenerate tests, and re-run the OPS-545 no-data experiment on the dev
broker. Then step 2, the tap.
