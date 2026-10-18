# The tap — paging the store's open alerts

Status: Draft · Pass 0 · Updated 2026-10-17

> What this is: `gwalerter tap`, the alerter's paging process: how the
> store's open alerts become Opsgenie alerts and closes, who owns open,
> closed and acknowledged, and how silences are applied. The kinds it
> pages are in their own spokes; what is true of every kind is in
> [`primary.md`](primary.md).

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
re-raise after a resolve a new one. The headline is the house's display
name and the summary, cut to Opsgenie's 130 characters; `Entity` is the
full `AboutGNodeAlias` (else `Subject`, else `Src`), so two houses with
one short name are two alerts. Every alert is `P1`, a starting value.
Opsgenie is told once, from the first `Firing` the tap sees; a `Firing`
rewritten for a moved cause reaches the store and the broadcast, not
the page. A `Resolved` record becomes a `gw.opsgenie.alert.close` of
the alias with its summary as the `Note`. Who is paged, how often an
open alert re-notifies and how it escalates are Opsgenie's policy.

Open and closed in Opsgenie mean the condition holds, and the alerter
owns both: the tap closes an alert when the store resolves it, and a
person closing one by hand only gets there first. The alerter emits
transitions under one `AlertId` per condition; nothing repeats from
it. Acknowledging is the person's
mark and the alerter never touches it, so an alert that closed without
an acknowledgement is Opsgenie's history of an outage nobody looked at.
A human-owned close would let a second outage fold into a stale open
alert and page nobody, and at a hundred homes would leave every broker
blip's alerts for the on-call to sweep.

The tap keeps the set of alerts Opsgenie has been told are open and
each pass reconciles it: an open alert about an unsilenced house that
Opsgenie has not taken is created, one Opsgenie holds about a house
since silenced (`Store.silenced_aliases`) is closed with a note saying
so while the alert stays open in the store, and one Opsgenie holds that
the store has resolved is closed with its `Resolved` record
(`Store.resolved_record`). A house dropped from the silence list with
its alert still open is paged on the next pass. At boot the told set is
empty, so the first pass re-creates every open alert and Opsgenie folds
each into the alert it already has; that is what makes a tap restart
neither re-page nor forget. A post that fails after three attempts on a
transport error is logged and left for the next pass; an error status
from Opsgenie is logged and not retried.
