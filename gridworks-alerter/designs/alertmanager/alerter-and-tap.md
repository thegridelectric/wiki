# alerter-and-tap — the alerter on `gw.alert`, and the tap to Alertmanager

Status: Draft · Pass 0 · Updated 2026-09-17

> **What this is.** Spoke 1 of the alertmanager design: the alerter
> moves from the deleted house words to one `gw.alert` with `State`,
> and a tap carries each record from the broker to Alertmanager. Proven
> on the laptop against `gw-dev-rabbit` and a local Alertmanager.

## The alerter on `gw.alert`

- Snapshot regenerated with staged words allowed: the seed's
  published-only line is the box rule, not the dev round. The seed
  drops `gw.house.alert` and `gw.house.alert.cleared` for `gw.alert`.
- The store's `alerts` table and the NoData rule work on one word: a
  raise stores and broadcasts a `Firing` record; a clear stores and
  broadcasts a `Resolved` record with the same `AlertId`. The house is
  identified by its full `AboutGNodeAlias` everywhere in the store.
- No channel-name strings anywhere in a detector; NoData needs none,
  and each later detector states the layout words it looks up.
- Suite green, then the OPS-545 no-data experiment re-run on the dev
  broker (`experiments/2026-09-15-alerter-no-data/`) with `gw.alert`
  records in the log and the store.

## The tap

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
- A test against `gw-dev-rabbit` posting to a local Alertmanager.

## The experiment (laptop)

Re-runnable harness against `gw-dev-rabbit` and a local Alertmanager
(the committed config from spoke 2, Telegram receiver pointed at a test
group):

1. Alertmanager up; `amtool alert add` proves the receiver.
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

## Do this next

Regenerate the alerter's snapshot with staged words allowed, swap the
store and the NoData rule to one `gw.alert` with `State` (full alias as
identity), get the suite green, and re-run the OPS-545 no-data
experiment on the dev broker. Then the tap.
