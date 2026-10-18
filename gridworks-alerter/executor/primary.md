# gridworks-alerter — spec (primary)

Status: Draft · Pass 0 · Updated 2026-10-17


## Summary

The alerter is the production system's alert generator: the primary place
that decides a condition anywhere in the fleet or the platform needs a
person, and says so. It listens to everything on the production rabbit
broker, every message every service and every house sends, the moment
it is sent, the same traffic the journal records. It keeps what it
needs in a store of its own (what exists, the latest state of each
thing, when each was last heard from, a few hours of readings, which
alerts are open), so it reads nobody else's database and no analysis
query can slow it down or raise an alert by mistake. Its kinds are
about houses and the platform, and they grow with the platform.

A set of rules runs over that store every few seconds. Each rule is one
alert kind, named for the condition a person acts on: no data from a
house, a zone at freeze risk, a heat pump commanded on and drawing no
power. When a condition starts to hold the alerter raises one alert;
when it stops, it resolves that same alert. It never repeats itself.
Which houses it watches is the registry's business: every house under
the fleet's roots that is pending or active. A house in service that
should not page right now, during a heat pump install or a visit, is
silenced by name; its alerts are still recorded, just not paged.

It runs as three services on its own box, apart from the journal, so a
journaling problem and an alerting problem are never one outage: the
listener, which hears the broker, keeps the store and runs the rules;
the tap, the only one that talks to the alert manager, which reads the
store and nothing else; and the prober, which checks the broker's doors
from outside, because the alerter cannot hear a broker outage on the
broker. The tap needs no broker, so "broker down" still reaches a
person. The box, who may log in and how it is operated are in
`gridworks-infra/alerts/instance-README.md`.

The alerter raises and resolves. It does not decide who is woken: that
is an alert manager's job, who is on call, how often an open alert
re-notifies, how it escalates, when a person acknowledges it. The
alert manager is Opsgenie. The alerter creates an alert there when a
condition starts, closes it when the condition ends, and the person on
call acknowledges in between. Every alert record is also published on
the broker, so the journal keeps it and the alerts page can show it.

## Invariants

What the alerter guarantees. A rebuild that keeps these is the
alerter; one that breaks any of them is a different system.

- **I-1.** **The store is the truth.** Every transition is recorded in the
  alerter's own store before it is broadcast or paged; paging reads the
  store alone; a restart of any part neither re-raises an open alert
  nor forgets one. The store is the alerter's own file: paging shares
  no database with analysis, so a heavy read elsewhere can neither slow
  a page nor fake one.
- **I-2.** **Transitions only; the alerter owns open and closed.** One
  `AlertId` per condition: a `Firing` when it starts to hold, rewritten
  under the same id when its cause moves, one `Resolved` when it stops.
  The alerter opens the alert in the alert manager and closes it; a
  person acknowledges and never has to close. Repeat cadence and
  escalation are the alert manager's.
- **I-3.** **Nothing durable on the broker.** The journal is the durable record
  of what the fleet said. The alerter's queue dies with it; a queue that
  fills while the alerter is down would be a second outage. What must
  survive a restart lives in the store.
- **I-4.** **Rules read the store; nothing polls a house.** Arrivals write the
  store as they come; a rule is a query over it on a tick, or a clear in
  dispatch on the arrival that ends the condition.
- **I-5.** **Last-heard is derived, never stored.** Always a query over
  arrivals, floored at the moment the alerter started hearing, so a
  wrong clock cannot look alive and a fresh alerter gives every house a
  full threshold before paging.
- **I-6.** **Meaning comes from the vocabulary.** Every message is decoded as
  the sema word it is, at the version it was sent; a body that does not
  decode is dropped and logged, and the consumer keeps going.
- **I-7.** **Which houses is the registry's decision.** The tracked set is the
  pending and active terminal assets under the fleet roots, and a
  silence is a named, recorded, broadcast list, never a hidden skip.

## The processes

Three processes under the `alerter` login, sharing one sqlite store:

- **`gwalerter rabbit`** (`alerter-rabbit.service`): an Orchestrator-tier
  gwbase actor of transport class `Alerter` (`ServiceSettings`; a
  service, not a GNode, alias `<universe>.alerts`) with the standard
  auto-delete queue on the universe's broker. It taps the ear exchange
  with a `#` binding beside the class binding the tier makes, and gates
  on the parsed envelope's type name. Nothing
  is durable on the broker: the journal is the durable record, a queue
  that fills while the alerter is down would be a second outage, and
  restart is handled in the store. Its detectors run on a thread beside
  the consumer and write the store; it broadcasts each alert record.
- **`gwalerter tap`** (`alerter-tap.service`): the only process that
  talks to Opsgenie; reads the store, never the broker ([`tap.md`](tap.md)).
- **`gwalerter probe`** (`alerter-probe.service`): checks the broker's
  two doors from outside the broker path
  ([`broker-unreachable.md`](broker-unreachable.md)).

Three message types reach the store, each decoded through the vendored
sema snapshot (`src/gwalerter/sema`, generated from
`sema_seed_request.yaml` by `scripts/regen_sema_snapshot.sh`) at the
version it was sent, never upgraded: `report.event` (each scada's
readings, unrolled to one row per value; the seed names 002 through 004,
the versions the fleet's scadas send, and an arrival at any of them
counts), `layout.lite` (the scada's hardware layout, kept latest per
scada) and `g.node.forest` (the registry's topology broadcasts,
projected by immutable `GNodeId`). A body that fails to decode is
logged and dropped; the actor keeps consuming.

## Which houses

The fleet is a registry subtree. `GWALERTER_FLEET_ROOTS` (comma-separated
root aliases, no default; `hw1.isone.me.versant.keene` for Millinocket)
names it, and every TerminalAsset in the projection under those roots
whose status is Pending or Active is tracked: a house pages from the day
it reports, before the registry settles its position, and a Suspended
house is out of service on purpose and does not page. A house that must
not page lives outside the roots.
Membership is a registry fact, edited where the registry is edited; the
alerter keeps no roster.

A tracked house can be silenced: its alerts are still raised, stored,
broadcast and resolved, and the tap does not page them. The silences
are one `gw.hack.alert.silences` instance, the list of terminal asset
aliases not paged right now, read from the one file `silences_path`
names (in the alerter's config folder, named by the sema file
convention, `<alias>-gw.hack.alert.silences-000.json`) at boot and on
every detector tick; a changed file replaces the store's list and the
snapshot is broadcast on the mic exchange, as it is once at startup, so
JournalKeeper journals it. A missing file silences nothing; a file that
does not decode leaves the last loaded list standing, logged once. A
house is silenced by adding its alias to the file and paged again by
removing it. The word is a stop gap until an alert manager service
owns silencing; the fleet's readers see which houses are quiet on
purpose from the journal. A scada's house is the `.ta` sibling under its
parent alias, the aliasing the registry's `g.node.gt` axioms state. A
scada heard from that reports for no tracked house is logged once per
boot, so a forgotten install is visible.

At boot the CLI posts a `g.node.forest.request` for the roots to the
registry's HTTP read (`GWALERTER_GNR_URL`, no default) and upserts the
answer; if the registry is unreachable the actor still runs and converges
from the broadcasts. An older forest never overwrites a row a newer one
wrote (`SendTimeMs`).

## The store

One sqlite file, shared by the three processes, one table per sema
word the alerter keeps:

- `g_nodes` — the projection; payload is the `g.node.gt` wire form.
- `layouts` — latest per scada, by type name and version.
- `readings` — scada alias, channel, value, the scada's read time and
  the alerter's arrival time. Rows that arrived before the window
  (`readings_window_s`, 4 h) leave on every report.
- `alerts` — each alert's `Firing` record and, once it ends, its
  `Resolved` record, keyed by `AlertId` and indexed by what the alert is
  about (category, house alias or subject, kind): the open-alert state
  that survives a restart.
- `silences` — the terminal assets in the latest
  `gw.hack.alert.silences` snapshot, replaced wholesale on each load.
- `arrivals` — the latest arrival from each alias under the fleet
  roots, any message type, read off the routing envelope with the body
  undecoded: one row per alias, overwritten on each arrival. Whether a
  house's scada and LTN are speaking is read from here. The actor binds
  the audit exchange with `#` and `amq.topic` fans every MQTT publish
  into it, so everything a house's scada or LTN sends is counted, most
  of it never journaled.

The store is the truth: every transition is recorded here before it
is broadcast, the tap pages from here alone, and a restart of any
process neither re-raises nor forgets. Last-heard is a query, the latest arrival across readings and layouts,
never a column; a scada with a wrong clock cannot look alive. Across a
restart the projection, layouts and alert state survive; the readings
window refills from live traffic, so a detector that needs a window waits
one window before it can fire.

## Alert words

One word, `gw.alert` (`sema/definitions/types/gw.alert/000.yaml`), with
its enums `gw.alert.category`, `gw.alert.state` and a kind enum per
category (`gw.house.alert.kind`, `gw.fleet.alert.kind`,
`gw.platform.alert.kind`), and the tap's words,
`gw.opsgenie.alert.create` and `gw.opsgenie.alert.close` with
`gw.opsgenie.priority`. All are published, and the alerter's snapshot
is a published-only build. A House alert's `AboutGNodeAlias` is the
house's terminal asset read off `g_nodes` at raise time, so a rename
never strands an alert.

The alerter emits transitions: a `Firing` record when a condition
starts to hold, rewritten under the same `AlertId` when its cause
moves, and a `Resolved` record with that `AlertId` and `RaisedMs` when
it stops. Repeat cadence, escalation and acknowledgement are the
notifier's.

The record leaves the alerter as a broadcast on its own mic exchange
(`alertsmic_tx`) with `AboutGNodeAlias` as the radio channel, else
`Src`, so a House record's key reads
`rjb.<alerter>.alerts.gw-alert.<house alias>` and a consumer binds by
house on the tail. The mic exchange fans into the ear exchange, so
JournalKeeper can journal the words and a notifier tap hears them.
Sending is best-effort by gwbase contract: the store already holds the
record, so a failed send is logged, not retried.

## Alert kinds

Named for the condition a human acts on, never the detector's
mechanism; a tuned threshold does not rename a kind. Two kinds are
raised, each with its own spoke:

| Kind | Means |
| --- | --- |
| `NoData` (House) | A tracked house has sent nothing for longer than the silence threshold. |
| `BrokerUnreachable` (PlatformService) | A door of the fleet's broker fails the prober's check three probes running; `Subject` is the door as host:port. Raised by the prober, not a rule over the store; while one is open, `NoData` holds. |

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

Kinds live: [`no-data.md`](no-data.md) (house),
[`broker-unreachable.md`](broker-unreachable.md) (platform, raised by
the prober rather than a rule over the store).

## Operating

- Settings: `GWALERTER_*` from env and `.env` (`template.env`);
  `service_alias` is `<universe>.alerts` under the universe root;
  `silences_path` names the silences file.
- Deploy: `tools/box-deploy.sh alerter` (pull, sync, restart all three
  units); every unit is boot-enabled with `Restart=always`.
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

## Sub-specs

- [`no-data.md`](no-data.md) — the `NoData` kind: rule, cause clause,
  behaviour across a broker outage.
- [`broker-unreachable.md`](broker-unreachable.md) — the
  `BrokerUnreachable` kind and the prober.
- [`tap.md`](tap.md) — paging the store's open alerts through Opsgenie;
  silences.
