# gwalerter — the broker alerter

Status: Draft · Pass 0 · Updated 2026-09-15

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
`scripts/regen_sema_snapshot.sh`); older `report.event` versions upgrade
on decode. A body that fails to decode is logged and dropped; the actor
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
- `alerts` — each raised alert word and, once it ends, its cleared word:
  the open-alert state that survives a restart.

Last-heard is a query, the latest arrival across readings and layouts,
never a column; a scada with a wrong clock cannot look alive. Across a
restart the projection, layouts and alert state survive; the readings
window refills from live traffic, so a detector that needs a window waits
one window before it can fire. Rows load back as codec-validated
instances or typed records, never tuples.

## Alert words

Three published words (`sema/definitions/types/gw.house.alert/000.yaml`,
`gw.house.alert.cleared/000.yaml`, `enums/gw.house.alert.kind/000.yaml`).
An alert is a service reporting on a house; `glitch` is a node
reporting on itself, which is why it did not grow to cover this.

- `gw.house.alert`: `Src` (the alerter), `AboutGNodeAlias` (the house's
  terminal asset, read off `g_nodes` at raise time so a rename never
  strands an alert), `Kind`, `AlertId`, `RaisedMs`, `Summary`, `Evidence`
  (a list of `channel.readings`, empty for kinds whose evidence is not
  readings). Axiom: `AboutGNodeAlias` ends in `.ta`.
- `gw.house.alert.cleared`: the same `AlertId`, `Src`, `AboutGNodeAlias`,
  `Kind`, `ClearedMs`, `Evidence`.
- `gw.house.alert.kind`: versioned, one value per detector, `Unknown`
  first and default so a decoder on an older version meets a later kind
  as something a manager drops, never as a no-data page.

The alerter emits transitions only: one alert when a condition starts to
hold, one cleared when it stops, both with the same `AlertId`. Repeat
cadence, escalation and acknowledgement are the manager's. No severity
field: the kind is what the manager routes on. Thresholds live in the
kind's description and the alerter's configuration, never in the record.

The alert leaves the alerter as a broadcast on its own mic exchange
(`alertsmic_tx`) with the house alias as the radio channel, so the key
reads `rjb.<alerter>.alerts.gw-house-alert.<house alias>` and a manager
binds by house on the tail. The mic exchange fans into the ear exchange,
so JournalKeeper journals the words and the manager hears them as a tap.
Sending is best-effort by gwbase contract: the store already holds the
transition, so a failed send is logged, not retried.

## Alert kinds

Named for the condition a human acts on, never the detector's mechanism;
a tuned threshold does not rename a kind. Each row: the kind, its
meaning, gwalert's alias, and what reading gwalert found.

| Kind | Means | gwalert | Note from the read |
| --- | --- | --- | --- |
| `NoData` | A tracked house has sent nothing for longer than the silence threshold (10 min). | `no_data` | gwalert's house list is the rows its 2 h query returned, so a house with no reading in the window is never checked; the new rule reads last-heard from the store. |
| `ScadaRebootLoop` | The scada has booted repeatedly in a short span (more than 5 layouts in 5 min). | `rebooting` | Reads off layout arrivals directly. |
| `CriticalGlitch` | The scada reported a glitch at Critical level; the summary is the evidence. | `critical_glitch` | A scada reporting on itself; the alert relays it to a human. |
| `ZoneBelowSetpoint` | A critical zone is more than the tolerance (2 F) below its setpoint, and the setpoint was not just raised. | `zone_setpoint` | Suppressed in Standby. Zone name rides in the evidence. |
| `ZoneFreezeRisk` | A zone is below the freeze-risk threshold (40 F). | `zone_freezing` | 40 F is not freezing; the name says risk, the description carries the number. |
| `NoDistFlow` | A sustained heat call ended and no distribution flow was seen since before it started, on three cycles running. | `dist_pump` | Pump power never gates the alert in gwalert, only the message wording; the name follows the condition (flow), not the suspect (pump). |
| `NoStoreFlow` | The store pump has been commanded on for more than 10 min with no store flow. | `store_pump` | Assumes a store pump exists, which the fall layouts do not all have. |
| `HpNotResponding` | The heat pump has been commanded on for more than 15 min and draws no power. | `hp_on` | gwalert's alias reads as the opposite of what it means. |
| `HpRunningOnpeak` | The heat pump drew power during a weekday on-peak hour. | `hp_onpeak` | gwalert scans the whole 2 h window and its per-house flag lets only the first offending hour alert; the port fires on live readings only. |
| `LocalControlActive` | The house has fallen back to local control; the LTN is not dispatching it. | `not_in_atn` | Disabled in gwalert; "Atn" is the legacy name for the LTN. |
| (none) | | `no_more_oil` | Dead code in gwalert; not ported until someone defines it. |

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
  clears it with that arrival as evidence (the report's readings; empty
  for a layout). Open-alert state is the store's, which is what makes a
  restart neither re-raise nor forget. Witnessed PASS on the dev broker
  2026-09-15, restart with the alert open included; the shadow week
  against hw1 is what makes it Verified.

## Operating

- Settings: `GWALERTER_*` from env and `.env` (`template.env`);
  `service_alias` is `<universe>.alerts` under the universe root.
- Run: `gwalerter rabbit` (the systemd unit `alerter-rabbit.service`);
  stop is systemd's SIGTERM, which the actor takes without a hook: every
  store write is one sqlite transaction and the broker holds nothing.
- Schema change: edit `db_models.py`, `uv run alembic revision
  --autogenerate -m "..."`, review the file; the chain applies on open.
- Vocabulary change: edit the seed, `scripts/regen_sema_snapshot.sh`,
  `./ci.sh`. The seed takes published words only.
- CI: `ci.sh` runs ruff, pyright and pytest; the live-broker test
  self-skips without `gw-dev-rabbit`.

## Open

- The detectors after `NoData`, and each Verified by a week of shadow
  output beside gwalert on the alerts box against hw1.
- Layout seeding at first boot; the dead-man's switch; the journaled
  OPS-317 liveness signals as the source of "live". The design carries
  these.
