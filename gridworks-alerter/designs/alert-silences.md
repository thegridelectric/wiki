# alert-silences

Status: Accepted · Pass 1 · Updated 2026-10-15 · Linear: OPS-598

**EDD: yes** the verification is a silence placed on a house with an
open alert on the alerts box: the tap stops paging it within one
reconcile pass, the silence is journaled, and when the silence ends
with the alert still open the page arrives.

The silences are one sema word: the list of houses whose alerts are
not paged right now. The alerter stores silences, applies them at paging
only, and broadcasts them so the fleet's readers can see which houses
are quiet on purpose and why.

## Why

Elm has been offline for weeks while a new heat pump goes in. The
legacy gwalert is quiet about it by accident: its house set is rebuilt
every loop from what the journal DB saw in the last few hours, so a
house that stops reporting drops out of every check with no record
that it did. It also keeps a hard-coded short-name list,
`ignored_house_aliases = ['moss', 'orange']`, with a TODO to move it
to the `.env`. Neither says anywhere that elm is in a heat pump
install, or when that ends.

The new alerter tracks every Pending or Active terminal asset under
the fleet roots and has no silence of any kind, so `alerter-tap` would
page elm on its first reconcile. The registry's Suspended status is
the wrong tool: elm is in service, its heat pump is being replaced,
and the registry has no status write anyway (its write loop takes
create and reparent only). The alertmanager proposal (OPS-547) lists
"a home is silenced during a visit" among what triage needs and has no
mechanism for it.

A silence has to be transient, precise, sema-typed and visible: a
record someone can read next week that says which houses are quiet on
purpose, seen by the alerts page and by the ticketing system the
hundred homes will need.

## Shape

**One word, `gw.hack.alert.silences`, two fields.** `Src`, the service that
published the list (the alerter for the file, the ticketing system
later), and `SilencedGNodeAliases`, a list of terminal asset aliases,
the field `gw.alert` names a house by. That is the whole word for now:
no start, no end, no id, no kind. The list is a snapshot: the file on
the box, the record on rabbit and the row in the journal are the same
instance, a consumer replaces its copy and never merges, and a house
missing from the latest list is no longer silenced. Lifting elm is
deleting its line.

The `gw.hack` prefix and the word's extended description say what it
is: a stopgap that becomes obsolete when a real alert management
system is set up, kept out of the `gw.alert` family so nothing later
has to be built around it.

The word is this small on purpose. Paging is moving to a router
(OPS-547), and every router surveyed (Alertmanager, Grafana, Datadog,
Icinga, Zabbix, Opsgenie) has its own silence object with spans,
authors and ids; those belong to it when it arrives. What stays ours
whatever the router is the list itself: which houses are quiet on
purpose, as a sema word a person or the ticketing system places, that
the journal keeps and the alerts page shows. A later version adds
fields (a reason, a span, a ticket) without changing where the list
lives or who applies it.

Axiom: every alias identifies a TerminalAsset, as `gw.alert`'s
`AboutGNodeAlias` axiom states it. The sema spec is change-controlled:
the word is authored under the registry and authoring spokes, with the
summary-then-wait gate, before anything below is coded.

**Evaluate and record is the actor's job and does not change.** When a
detector raises, the actor writes the Firing record to the store and
broadcasts it on the mic exchange, in that order; the Resolved record
the same. A silenced house's NoData is raised, journaled and resolved
exactly as any other: elm has no data and the record says so, and the
alerts page can show elm firing and silenced at once, which is the
truth. Every detector-side system surveyed does the same: evaluate and
record, mute only the notification.

**The tap applies the list.** The tap is a poller of the store with no
broker connection, so the one alert meaning the broker is down can
still reach a person. Its reconcile pass takes the store's open alerts
minus those whose `AboutGNodeAlias` is in the list. Nothing else in
the tap changes: when a house leaves the list with its alert still
open, the next pass pages it, and a page already open when a house is
added is closed with the silence as its note. `BrokerUnreachable` and
the fleet kinds have no house and are never silenced.

**Visible: broadcast, journaled, displayed.** The actor broadcasts the
list on its mic exchange like `gw.alert`
(`rjb.<alerter>.alerts.gw-hack-alert-silences`), once at boot and on every
change, so JournalKeeper journals each snapshot and the history of
silences is the journal's. The web frontend's alerts page reads the
latest snapshot from the journal and marks a silenced house beside
its alerts, the way Zabbix marks a host in maintenance. Writes go over
rabbit and reads through a façade, the house API pattern. The page's
move from the stopped dispatcher's history to the journal is OPS-547's
open item and is where silences appear.

**Operator interface now: the one file.** The alerter's config folder
holds the list as a sema-typed JSON file named by the convention,
`<subject>-<type.name>-<version>.json`, with the alerter as subject:

```
~/.config/gridworks/alerter/hw1.alerts-gw.hack.alert.silences-000.json
```

The actor reads it at boot and on a change (a poll on the tap's
cadence), decodes it through the codec, expects `GwHackAlertSilences`,
replaces the store's table and broadcasts the snapshot. Editing the
file is the whole operator interface until a ticketing system exists.
Later the same word arrives on rabbit from the hundred-homes ticketing
and fleet-management system, the file goes away, and the word, the
store, the tap and the broadcast do not change.

## Settle in the design, not by default

- A silence names a terminal asset, never a scada or a short name.
  The `gw.alert` axiom that `AboutGNodeAlias` identifies a
  TerminalAsset holds here too.
- A silence is applied at paging only. Silencing inside a detector
  makes the record lie, and the record is what the alerts page and
  the journal show.
- The store, not the tap, is the truth about silences, for the same
  reason it is the truth about alerts: a tap restart re-reads it.
- The file is read by the actor process, which owns the store; the
  tap reads silences from the store like alerts.
- The list is owned by the vocabulary and the journal; the notifier
  of the day applies it. Today that is the tap. If a router takes
  over paging (OPS-547, Alertmanager), the mute moves to the router,
  which mirrors the snapshot through its own silences API (one
  silence per record, a matcher on the house label, a far-future end
  or a renewal per snapshot for an open-ended one), and the router's
  UI is not where a silence is placed.
- Open: whether each entry has a `Reason` beside the alias. "elm
  silenced" on the alerts page without "new heat pump install" is the
  legacy gap in a new file; the cost is a list of two-field entries
  instead of strings.

## Do this next

1. ✅ `gw.hack.alert.silences` 000 published (sema `8d0f793`) and
   vendored into the alerter's seed.
2. ✅ Alerter (`jm/alert-silences`, ci.sh green): the `silences` table and migration,
   `Store.replace_silences` / `silenced_aliases`; the file loader; the
   tap's reconcile filter; the broadcast. Tests first for each: a
   listed house keeps its firing alert off Opsgenie, a house dropped
   from the file is paged on the next pass, the snapshot is broadcast
   at boot and on change.
3. ✅ Elm's silence placed on the alerts box and `alerter-tap` live
   (2026-10-15, `experiments/2026-10-15-alert-silences-go-live/`): no
   elm page, the snapshot in the ear's eventstore. Not in the journal:
   JournalKeeper drops every type its seed does not vendor, and its
   seed has neither `gw.alert` nor `gw.hack.alert.silences`.
4. ✅ JournalKeeper journals the alerter's words (gjk `c28fb46`, deployed
   2026-10-15 16:45Z): beech stopped for 15 minutes, its NoData Firing
   and Resolved records are two journal rows keyed at RaisedMs and
   ResolvedMs, and the tap paged and closed Opsgenie. The silences
   snapshot is a journal row too, from the alerter's 17:13Z restart
   broadcast (elm silenced).
5. The alerts page shows silences, with OPS-547's journal move. Do this
   next: it is the remaining step; the Summary wording the page shows is
   the short form (alerter `380f754`).
