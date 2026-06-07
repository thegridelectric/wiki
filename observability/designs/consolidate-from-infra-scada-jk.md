# Consolidate observability domain from infra + scada + journalkeeper

Status: Draft · Pass 0 · Updated 2026-05-30

> **What this is.** The design that builds the
> `wiki/observability/` domain's `executor/primary.md` by
> consolidating three substantial existing-content sources:
> `gridworks-infra/observability/` (the most developed planning
> content GridWorks has on observability), `gridworks-scada` (the
> already-existing `Glitch` + `ProblemEvent` Sema-typed events),
> and `gridworks-journalkeeper` (the already-running
> `alert_generator` consumer pattern). Once the design ratifies,
> its distillate updates `executor/primary.md` and this file is
> deleted per
> [`../../designs-process.md`](../../designs-process.md).

## Motivation

GridWorks observability content lives across at least three places
today, with no single authoritative spec:

1. **`gridworks-infra/observability/`** — substantial planning content
   (Reactive-Manifesto philosophy, three-layer
   Detection/Coordination/Fixes architecture, BugSnag + Loki +
   Tempo planned roadmap, full reference for the 10 SCADA alerts).
   Operations-oriented; written when the fleet was smaller.
2. **`gridworks-scada` + `gridworks-protocol`** — concrete actor-side
   primitives: `ProblemEvent` (`gridworks-protocol`, low-level,
   generic) and `Glitch` (`gridworks-scada-protocol`, higher-level,
   Node-attributed with LogLevel). Live in the SCADA + LTN emit
   paths.
3. **`gridworks-journalkeeper`** — the existing alerter
   (`alerts/alert_generator.py` on `origin/dev`, 5-minute loop,
   reads journaldb, posts to OpsGenie). 10 bespoke per-alert checks.

Plus a **gwbase-side concern** at
[`../../gridworks-base/research/concerns/logging-for-observability.md`](../../gridworks-base/research/concerns/logging-for-observability.md)
that captures what gwbase v-next should ship to enable fleet-wide
observability (logging that flows into the broker; verbosity-request
primitive; LLM sense-making integration).

This design pulls those threads together into the canonical
`wiki/observability/` spec and resolves the architectural
decisions needed to ship a coherent v1.

## Scope

### In MVP

- **Domain framing** — the three-layer architecture (Detection /
  Coordination / Fixes) lifted from
  `gridworks-infra/observability/README.md` becomes the spec's
  organizing frame.
- **Canonical problem-event Sema type** — design a
  `observability.problem-event/000` that subsumes both `Glitch`
  and `ProblemEvent` shapes. Existing emitters keep emitting until
  migrated; the journalkeeper-side alerter consumes both during
  transition.
- **Generic alerter framework** — lifts the structural pattern of
  `alert_generator` (look-back window + condition + alert-key +
  dedup-on-firing-state) into a reusable framework. Hosts the 10
  existing SCADA checks plus future ones. Per-service config-tunable.
- **Substrate** — alerter consumes the analytics-broker event
  stream (which is the prod broker today, per the analytics-broker
  deferral at
  [`../../rmqbot/designs/analytics-broker-shovel.md`](../../rmqbot/designs/analytics-broker-shovel.md)).
- **Log forwarder choice** — decide between per-host forwarder
  (Loki / similar) vs. logs-via-broker. See Architectural decisions
  below.

### Out of scope

- The actual deployment of monitoring tools (Grafana, Prometheus,
  BugSnag, S3 retention). Those land in `executor/` as
  configuration once the spec converges.
- The MQTT-side of monitoring (SCADA local broker telemetry) —
  proactor/scada concern.
- LLM sense-making implementation. The substrate (clean structured
  events + windowed consumer API) lands here; the LLM integration
  is a follow-on once the substrate exists.

## Inputs — what's already there

### `gridworks-infra/observability/` (the planning content)

| File | What it has |
|---|---|
| `README.md` | Three-layer architecture (Detection / Coordination / Fixes), Reactive-Manifesto philosophy, tool inventory with status flags |
| `logging/README.md` | Planned BugSnag → Loki → Tempo + OpenTelemetry stack; references the existing "MorningReport of Glitch" pattern |
| `custom-tools/scada-alerts.md` | Full reference for the 10 alerts in journalkeeper's `alert_generator.py` |
| `custom-tools/{backoffice,visualizers,gridworks_webapp}.md` | Existing custom dashboards |
| `metrics/README.md`, `linear.md` | Coordination tools |

Strategy: copy the README's framing verbatim into the new
`executor/primary.md` as the architectural lead; copy the alert
reference + custom-tools docs into the new domain's
`research/`; preserve provenance via cross-refs back to infra.
Infra copies stay in place; we don't delete them.

### `gridworks-scada` + `gridworks-protocol` (existing actor-side
primitives)

- **`ProblemEvent`** — `gridworks-protocol/src/gwproto/messages/event.py:52-62`.
  TypeName `gridworks.event.problem`, Version `001`. Fields:
  `ProblemType` (Problems enum: error|warning), `Summary`,
  `Details`, `Src`, `TimeCreatedMs`, `MessageId`. Lower-level,
  generic.
- **`Glitch`** — `gridworks-scada-protocol/src/gwsproto/named_types/glitch.py`.
  TypeName `glitch`, Version `000`. Fields: `FromGNodeAlias`
  (LeftRightDot), `Node` (SpaceheatName), `Type` (LogLevel:
  Critical | Error | Warning | Info | Debug | Trace), `Summary`,
  `Details`, `CreatedMs`. Higher-level, Node-attributed.

Emit pattern (typical, from `ltn.py:1789`):
`glitch = Glitch(...)` →
`self.services.send_threadsafe(Message(Payload=glitch))`. SCADA
sends to its LTN; LTN forwards via its broker.

### `gridworks-journalkeeper` (existing consumer-side alerter)

`alerts/alert_generator.py` on origin/dev:

- Monolithic `AlertGenerator` class; 5-minute loop
- Reads journaldb directly via SQLAlchemy (`gjk.api_db.get_db`)
- 10 bespoke per-alert checks (Critical Glitches, No Data, Zone
  Below Setpoint, Zone Freezing, Distribution Pump, Store Pump,
  HP Not Coming On, Not in ATN, HP On-Peak, Rebooting)
- Per-house dedup via `alert_status` + `houses_with_an_active_alert`
- Sinks to OpsGenie via team-id routing
- Per-house state persisted in postgres `homes` table
- `point_at_prod_observe.py` + `point_at_dev_hack.py` scripts —
  catch-all subscribers used for inventory + dev-stack tracing

### Cross-cutting: gwbase v-next concern

[`../../gridworks-base/research/concerns/logging-for-observability.md`](../../gridworks-base/research/concerns/logging-for-observability.md)
captures what gwbase v-next would ship to enable fleet-wide
observability primitives. Specifically (R5 in that concern):

- Sema type `observability.problem-event/000` (subsumes Glitch +
  ProblemEvent shape)
- Sema type `observability.verbosity-request/000`
- gwbase: `ActorBase.report_problem(...)` hook → emits typed event
- gwbase: `Orchestrator.on_verbosity_request(...)` hook + default
  behavior
- wiki/observability/: alerter-framework design (this design)

This observability design and the gwbase v-next work co-evolve:
the Sema types + gwbase hooks land in a gwbase release; this
design's alerter framework consumes them.

## Architectural decisions

### A1. Canonical problem-event Sema type

**Decision**: mint `observability.problem-event/000` (sema-typed)
that subsumes Glitch + ProblemEvent. Specific field shape:

```
TypeName       : "observability.problem-event"
Version        : "000"
FromAlias      : LeftRightDot       (subsumes Glitch.FromGNodeAlias and ProblemEvent.Src)
Node           : str (optional)     (lifts Glitch.Node; None for non-scada emitters)
Level          : LogLevel           (Critical | Error | Warning | Info | Debug | Trace)
ProblemType    : ProblemKind        (transport | dispatch | hardware | data | ...)
Summary        : str
Details        : str
CreatedMs      : UTCMilliseconds
```

`LogLevel` is the richer of the two (subsumes `Problems.error`/
`warning`). `ProblemType` is a new dimension classifying the
domain of the problem (probably ~6-8 values).

Migration:

- Glitch + ProblemEvent stay as legacy emitters during transition
- journalkeeper-side consumer accepts all three (Glitch,
  ProblemEvent, observability.problem-event) and normalizes
  internally
- New gwbase actors emit observability.problem-event natively via
  the `ActorBase.report_problem(...)` hook
- Glitch + ProblemEvent are deleted once no live emitter remains

### A2. Alerter framework

**Decision**: build a generic alerter framework that consumes the
broker event stream. Each alerter is a small declarative unit:

```python
class Alerter:
    name: str
    lookback: timedelta
    condition: Callable[[EventWindow], list[AlertCandidate]]
    dedup_key: Callable[[AlertCandidate], str]
    sink: AlertSink   # OpsGenie / Linear / email / ...
```

The framework handles:

- Broker subscription + event windowing (per `lookback`)
- Dedup against previously-fired alerts (using `dedup_key`)
- Alert-state lifecycle (firing / acked / resolved)
- Sink dispatch

The 10 existing journalkeeper alerts port to this shape; new
alerters slot in by declaring a new `Alerter`. Per-service config
overrides (currently hardcoded `whitewire_threshold_watts` per
house, `ignored_house_aliases`, etc.) flip to a config file
adjacent to the alerter declarations.

### A3. Log forwarder — per-host forwarder

**Decision**: per-host log forwarder (Promtail or similar),
shipping to a central log collector (Loki). NOT logs-via-broker.

Rationale:

- Logs are high-volume; sending each line as a broker event would
  swamp the broker
- The bijective-human-format gwbase logger
  ([`../../gridworks-base/executor/actors.md`](../../gridworks-base/executor/actors.md) §5.5)
  is round-trippable to Sema events; the forwarder converts at the
  log-collector ingress, not the broker
- Broker stays focused on event-stream traffic (problem-events,
  state updates) — not log-line traffic

Logs-via-broker remains a windowed option: the
`observability.verbosity-request` primitive temporarily lights up
broker-side log forwarding for a single actor for a bounded window
(per the gwbase concern doc). That's a different mechanism with a
different cost model.

### A4. Detection / Coordination / Fixes — keep the frame

The infra README's three-layer model maps cleanly onto the
fleet-wide gwbase model. Adopt verbatim as the spec's organizing
frame:

```
Detection   = gwbase actors emit observability.problem-event via report_problem();
              Prometheus metrics from app + infra surfaces;
              BugSnag exceptions (third-party tool, integrated optionally);
              verbosity-request lets operators temporarily turn the volume up
Coordination = Linear + OpsGenie + (eventual) LLM-summarized
              event-stream windows
Fixes       = code PRs, hardware visits, design changes
```

### A5. LLM sense-making — substrate now, integration later

Two LLM use cases (per the concern doc): pattern-matching across a
window of events ("anything anomalous?"), and incident-response
summarization (given problem-event + state snapshot + recent message
history). Neither requires LLM in the hot path.

Design provides the **substrate** (structured events, windowing
convention, actor state snapshot capability). LLM integration is
deferred until the substrate is shipping and we have a concrete use
case + tooling story.

## Migration sequencing

### Stage 1 — port + organize (this design, immediate)

- Create `wiki/observability/executor/primary.md` as
  acceptable-minimum from this design's distillate
- Copy infra `observability/` docs into `wiki/observability/research/`
  with provenance back-refs (infra stays as-is)
- This design file gets deleted once executor lands per
  designs-process

### Stage 2 — gwbase Sema types + report_problem hook

- Land `observability.problem-event/000` in sema (via
  `/make-sema-word`)
- Land `ActorBase.report_problem(...)` in gwbase (Wave-2 per
  [`../../gridworks-base/research/concerns/logging-for-observability.md`](../../gridworks-base/research/concerns/logging-for-observability.md))
- Glitch + ProblemEvent stay as legacy emitters

### Stage 3 — alerter framework + journalkeeper migration

- Build the generic alerter framework
- Port the 10 existing checks to alerter declarations
- Replace journalkeeper's `alert_generator.py` with the framework

### Stage 4 — log forwarder + log collector

- Stand up Loki (or chosen alternative) + Promtail / equivalent
- Configure SCADA Pi + cloud hosts to forward gwbase bijective-format
  logs

### Stage 5 — verbosity-request primitive

- Land `observability.verbosity-request/000` sema type
- gwbase: `Orchestrator.on_verbosity_request(...)` hook +
  BrokerLoggingHandler
- Substrate for the LLM sense-making integration

Stages 2-5 are independent commits-of-resources; can be sequenced
flexibly per gwbase release planning.

## Open

- **`ProblemKind` enum values** — what set? Strawman:
  `transport | dispatch | hardware | data | safety | config |
  other`. Need a working pass once we have lived examples of every
  problem.
- **Alerter framework — boundary between framework and consumer-of-events.**
  Does the framework own its own broker subscription, or take an
  injected event stream (so tests can drive synthetic event
  sequences)? Probably the latter; lock during implementation.
- **Per-service alerter config storage** — file format, location,
  validation. Probably YAML co-located with the alerter declarations.
- **Glitch + ProblemEvent deprecation timeline** — when does
  emission stop? Tied to gwbase v-next release + SCADA/LTN
  conversion.
- **Alert-state persistence** — journalkeeper today stores per-house
  alert status in postgres. New framework: stays in postgres, or
  moves to Redis / in-memory + persistent snapshot? Probably stays
  in postgres for simplicity.
- **OpsGenie integration** — replicate the existing team-id /
  priority / unique-alias pattern. Capture the contract.
- **MorningReport** — the existing custom dashboard that summarizes
  glitches. Does it survive into the new world, or get subsumed by
  the alerter framework's UI surface? Probably the latter; defer.
- **gwbase release shape** — when does the
  `observability.problem-event` Sema type + `report_problem` hook
  land? Coordinated with gwbase Wave-2.

## Cross-references

- [`../../gridworks-base/research/concerns/logging-for-observability.md`](../../gridworks-base/research/concerns/logging-for-observability.md)
  — the gwbase-side concern this design pairs with (Sema types,
  ActorBase hooks, verbosity-request)
- [`../../gridworks-base/executor/actors.md`](../../gridworks-base/executor/actors.md) §5.5
  — Wave-1 logging substrate (bijective format); the field-level Sema
  bijection lives in
  [`../../gridworks-base/research/concerns/logging-for-observability.md`](../../gridworks-base/research/concerns/logging-for-observability.md)
- [`../../rmqbot/designs/analytics-broker-shovel.md`](../../rmqbot/designs/analytics-broker-shovel.md)
  — analytics broker deferred; alerter consumes prod broker for
  now
- [`../../gridworks-journalkeeper/`](../../gridworks-journalkeeper/)
  — current home of `alert_generator.py`; receives the alerter
  framework migration
- [`../../gridworks-scada/`](../../gridworks-scada/) +
  `gridworks-protocol` — current homes of `Glitch` + `ProblemEvent`;
  receive the lift into sema's `observability.problem-event/000`
- `gridworks-infra/observability/` — source of the planning content
  + the canonical 10-alert reference
- [`../../designs-process.md`](../../designs-process.md) —
  design-spec lifecycle convention this design follows
