# alertmanager — a proposal for routing alerts once triage has a home

Status: Draft · Pass 0 · Updated 2026-10-05 · Linear: OPS-547

**EDD: yes** the experiment is the verification: a `gw.alert` raised by
the alerter arrives in Alertmanager's alert list and reaches a receiver,
and its `Resolved` record closes it
(`experiments/2026-09-30-alerter-to-alertmanager/`, PASS on the laptop).
Nothing here is Verified until that harness runs on the alerts box.

> **What this is.** A suggestion, written for whoever takes alert
> routing on. It says where alerting stands, what is likely to change
> around it, what we would try, and what is already proven. Paging does
> not depend on it: the alerter pages through Opsgenie without anything
> below (OPS-545). Treat the proposal as a starting position to test
> and change, with the open questions at the end as the real work.

## Where alerting stands

- The alerter (`gridworks-alerter`) detects a condition and emits one
  `gw.alert` record when it starts (`Firing`) and one when it stops
  (`Resolved`). Detection is its whole job; who is told, how often and
  by what means belongs to whatever sits after it
  (`executor/gwalerter.md`).
- A tap process carries each record from the broker to a notifier.
  Today's notifier is Opsgenie, which pages the engineer on call.
- Opsgenie is being phased out, so that path has an end date and
  something has to replace it.
- The hand-written Telegram dispatcher (`gridworks-alert-manager`) is
  stopped. It paged unreliably, and its job list (dedup, repeat cadence,
  escalation, silences, resolved notices, history) is a known product
  category we no longer intend to build ourselves.

## Who the alerts will be for

Home alerts are moving from engineers to triage. GDS, a large company,
is expected to receive alerts for the homes and do the triage, working
each one as a ticket tied to the home, while platform alerts (a broker,
a service) stay with GridWorks engineers. A company of that size is
likely to arrive with its own ticket and on-call tools, and that is not
yet known.

What triage needs from alerting, whoever runs it: home alerts reach the
first-line person and platform alerts reach engineers; several alerts
from one home arrive as one; a home is silenced during a visit; an
acknowledgement is recorded; a phone call follows if no one responds; a
rota covers nights and weekends; each alert becomes a ticket with a
history.

## The proposal

Buy, or adopt from GDS, the system that does acknowledgement, escalation,
rotas and tickets, and put at most one small standard piece between the
alerter and it. Two shapes fit, and the choice between them is the first
decision:

1. **Alertmanager as the router.** The tap posts to Prometheus
   Alertmanager on the alerts box; Alertmanager groups, silences and
   routes by `Category`, and hands each alert on through a receiver: a
   webhook into the triage system for home alerts, another route for
   platform alerts to engineers.

   ```
   alerter ──gw.alert──▶ broker ──▶ tap ──▶ Alertmanager ──▶ triage system (home alerts)
                                                        └──▶ engineers (platform alerts)
   ```

   This fits if there is more than one destination, or if the triage
   system is weak at grouping and silencing.
2. **No router.** The tap posts straight to the triage system's alert
   intake, as it does to Opsgenie now. This fits if one system takes
   every alert and already groups, silences and routes well. Then
   Alertmanager is not installed, and its mapping and client come out
   of the tap.

Our lean is shape 1, lightly held: Alertmanager is one static binary
with an HTTP intake, needs no Prometheus, and its routing tree,
grouping, silences with expiry and `resolve_timeout` cover the first
three triage needs with configuration and no code. It never becomes a
ticket system or an on-call rota, and nothing here builds those. An
earlier draft sketched three small services of our own on top of it (an
acknowledgement bot, phone escalation, a rota generator); the proposal
is to not build them.

## What is proven

- The word: `gw.alert` with `Category`, `Kind`, `State` and `AlertId`
  is published (sema `632b58e`); its fields map onto Alertmanager's
  intake one for one (`executor/gwalerter.md` "Alert words").
- The tap: built and tested in `gridworks-alerter`
  (`src/gwalerter/tap.py`), with the label and annotation mapping in
  `executor/gwalerter.md` "The tap". It keeps the open set across a
  restart, so a restart neither re-pages nor forgets.
- The path, on the laptop: alerter to tap to a local Alertmanager to a
  webhook receiver, `Firing` and `Resolved`, with a tap restart while an
  alert is open (`experiments/2026-09-30-alerter-to-alertmanager/`,
  which also holds the `alertmanager.yml` used).

Not proven: anything on the alerts box, and any real receiver.

## If shape 1 goes ahead: the box

The stand-up follows the gwbase box pattern (gwbase executor
`service-deployment.md`, `gridworks-infra/box-access.md`); root steps
are a human's.

- Login `alertmanager`, per-person keys, a sudoers drop-in for exactly
  the unit's `systemctl` verbs.
- The release binary and `amtool` under `/opt/alertmanager`, version
  pinned in the instance-README; data in `/var/lib/alertmanager`.
- Config, unit and install recipe committed in `gridworks-infra/alerts/`
  so a change is a commit, a copy, `amtool check-config` and a reload.
  Secrets by file reference, outside git, recorded as hand-placed state.
- Intake on loopback only (`127.0.0.1:9093`); the tap is the only
  writer.
- A starting config: `resolve_timeout: 1h`, routes grouped by `category`
  and `subject`, `repeat_interval: 4h`, one child route per `category`.
- The experiment re-run on the box against hw1 is what makes it
  Verified.

## Open

- What GDS will receive alerts in, and whether they bring it or we
  choose it. This decides between the two shapes.
- What replaces Opsgenie for paging GridWorks engineers, and whether
  the triage system covers that too.
- Who is told what: the routing tree by category and hour. The
  dispatcher's Google-Sheet rotation is the record of how the team has
  wanted this to work.
- Whether `Subject` becomes a `gw.platform.service` enum once a router
  has to match on it.
- The Alerts web page reads the stopped dispatcher's history and is
  dark; its move to the journal is its own piece of work.
- The broker prober (OPS-545) posts to Opsgenie directly; whether it
  moves to the router's intake.

## Do this next

Find out what GDS will use to receive and work alerts, then choose
between the two shapes with that in hand. Nothing is installed on the
box before that choice.
