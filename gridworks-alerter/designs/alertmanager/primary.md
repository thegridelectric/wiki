# alertmanager (hub) — Prometheus Alertmanager as the notifier, one `gw.alert` word

Status: Draft · Pass 0 · Updated 2026-09-17 · Linear: OPS-547

**EDD: yes** the experiment *is* the verification: the new alerter, with
spruce's scada stopped, raises a spruce `NoData` as a `gw.alert` that
arrives in Alertmanager's alert list and pages the Telegram test group,
and the `Resolved` record on spruce's return closes it. A spoke reaches
Verified only when that harness runs against it
(`experiments/2026-09-XX-alerter-to-alertmanager/`, date set when it
runs).

> **What this is.** The design that puts Prometheus Alertmanager on the
> alerts box as the notifier for every GridWorks alert, retires the
> hand-written Telegram dispatcher, and reshapes the alert vocabulary
> into one `gw.alert` word whose fields map onto Alertmanager's intake
> one for one. It sequences after the alerter's shadow deployment
> (OPS-545) and changes that design's notification path: not an A/B of
> two notifiers, but the new path from the first live detector.

**▶ Active spoke: [`alerter-and-tap.md`](alerter-and-tap.md)**

## Spokes

1. **[`alerter-and-tap.md`](alerter-and-tap.md)** — the alerter moves
   to `gw.alert`; the tap that posts it to Alertmanager; the laptop
   experiment.
2. [`alertmanager-on-the-box.md`](alertmanager-on-the-box.md) —
   Alertmanager stood up on the alerts box; runs in parallel with
   spoke 1, since it needs only the box; the two meet at the box
   experiment.
3. The prober: broker reachability checked from outside the broker's
   path, posted straight to Alertmanager. Its own spoke when reached.

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

## Notes

- Not an A/B. `NoData` pages through Alertmanager from the day the
  alerter goes live on hw1; gwalert's `no_data` check is switched off
  the same day so no house is paged twice. The OPS-545 shadow week
  compares *detection* against gwalert's history, not two notifiers.
- `gridworks-alert-manager` retires when the Alerts web page reads the
  journal instead of the manager's history (its own issue).
- Escalation by count and the sheet-driven rotation are not carried
  over: for six houses, one Telegram group per route and the people in
  it handle rotation. A rotation, if wanted later, is a generator from
  the sheet into Alertmanager `time_intervals`, as a separate issue.
