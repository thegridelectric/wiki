# alerter-and-tap — the alerter on `gw.alert`, and the tap to Alertmanager

Status: Accepted · Pass 1 · Updated 2026-09-30

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

- `gwalerter tap`, a second subcommand of the alerter's console script
  and its own unit on the alerts box (`alerter-tap.service`), same
  snapshot, same `.env`; a plain consumer with its own durable queue
  (`<alias>-tap`) on `alertsmic_tx`, bound by the `gw-alert` type
  segment (`rjb.*.*.gw-alert.#`). Lives in the alerter repo so the
  vocabulary snapshot is vendored once.
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
- **The open set is re-posted.** Alertmanager forgets a firing alert
  that is not re-posted within `resolve_timeout`, and the alerter says
  each transition once, so the tap keeps the open alerts and re-posts
  them every `tap_resend_s` (300, under the 1 h timeout). At boot it
  reads that set from the alerter's store (`Store.open_alerts`; the tap
  opens the same sqlite beside the actor, which is also where it finds
  each house's display name), so a tap restart neither re-pages nor
  drops an alert still firing.
- Best effort with a retry on connection refused (three attempts); the
  alerter's store and the journal are the durable record, so a dropped
  post is logged, not queued.
- Tests: the mapping and the open-set cadence against a recording httpx
  transport; the consumer against `gw-dev-rabbit`.

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

## Settled for the swap

1. **The radio channel of a non-house record** is `AboutGNodeAlias`
   when present, else `Src`: a `House` record keys on the house, so a
   manager binding by house on the tail still works; a `Fleet` or
   `PlatformService` record keys on the alerter's own alias
   (`hw1.alerts` on hw1), the one LeftRightDot the record is sure to
   carry (`Subject` is free text and cannot be a key).
2. **The `alerts` table**: `about_g_node_alias` nullable; `category` and
   `subject` columns join `kind`; the open-alert index becomes
   `(category, about_g_node_alias, subject, kind, resolved_ms)`;
   `cleared_ms` / `cleared_payload` become `resolved_ms` /
   `resolved_payload`. No box holds this store, so the initial migration
   is edited in place; the chain starts growing at the first deployed
   store.
3. **The regen runs from a clean sema worktree** at `origin/dev`
   (`git worktree add <scratch>/sema-dev origin/dev`, then
   `SEMA_REPO=<scratch>/sema-dev scripts/regen_sema_snapshot.sh
   --allow-staged`), never from the sibling checkout, which sits on
   whatever branch another session left it on. The snapshot README
   records the sema commit. This is the practice for every consumer
   regen.
4. **Promotion comes after the dev round.** The five staged words move
   to published only once this spoke's laptop experiment has PASSED;
   the published regen and the box follow.

## Do this next

The swap (steps 1–7, `d29d9a6`) and the tap are built and the laptop
experiment PASSED on 2026-09-30
(`experiments/2026-09-30-alerter-to-alertmanager/`): the five checks
with a loopback webhook standing in for the Telegram group. This spoke
is done once two things close:

1. The Telegram test group: a bot token file and the group's chat id,
   then `run.sh` once more with `TELEGRAM_CHAT_ID` and
   `TELEGRAM_TOKEN_FILE` set, so the page is seen in a group and not
   only in the receiver's log. The receiver stays in the harness as the
   record of what was sent.
2. ✅ Promotion: the five words are published (sema `632b58e`) and the
   alerter's snapshot is a published-only build. Then the box: spoke 2,
   `alertmanager-on-the-box.md`.
