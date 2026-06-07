# Concern: logging-for-observability — what gwbase should ship next

Status: Draft · Pass 0 · Updated 2026-05-29

> Open architectural question. Now that the three-tier actor model has
> landed as gwbase 0.5.0 ([`../../executor/actors.md`](../../executor/actors.md) —
> the `ActorBase` / `Orchestrator` / `GridworksActor` refactor + XDG paths +
> Sema-validated `g.node.gt.json` + Wave-1 logger), what
> further functional additions to gwbase are most valuable for a
> 100-house and eventually 1000+ fleet?
>
> The candidates here haven't converged into a design yet. Anchored
> candidates: structured logging that flows naturally into fleet
> observability, monitoring/alerting hooks, an LLM sense-making
> integration point.

## The question, stated cleanly

> **What observability and operability primitives should `gridworks-base`
> offer its consumers — at the `ActorBase` / `Orchestrator` /
> `GridworksActor` tiers — so that the fleet can be operated,
> monitored, debugged, and reasoned about without each actor
> reinventing the same primitives?**

Two framings of "primitive" worth distinguishing:

- **Direct primitives** the framework hands the actor (e.g. a typed
  logger, a `report_problem(...)` API, a counter increment).
- **Indirect primitives** that the framework hands the *infrastructure*
  on the actor's behalf (e.g. structured-event emission to a separate
  channel, opt-in periodic state dumps, health/readiness reporting
  to FIS or a sidecar).

Shipping either category cleanly is more valuable than shipping both
half-done.

## Candidate areas

### A. Logging that's bijective with sema events

Wave-1 ships `ActorBase.logger` writing a bijective human-readable format
that maps 1:1 onto a future `observability.log-entry/000` Sema type. The
as-built logger is specified in
[`../../executor/actors.md`](../../executor/actors.md) §5.5; the field-level
bijection it is designed to satisfy:

Per-record format: `<iso-ts> <LEVEL> <alias> > <message>[ key=val ...]`,
preceded by a `=== gwbase log: alias=… instance=… started=… ===` header and
followed by `  | …` continuation lines for exceptions.

| Format slot | `observability.log-entry/000` field |
|---|---|
| File header `alias=` | `Alias` |
| File header `instance=` | `InstanceId` |
| `<iso-ts>` | `TimestampMs` (ISO ↔ epoch_ms) |
| `<LEVEL>` | `Level` |
| `<alias>` (per-line) | `Alias` (redundant with header; for grep-ability) |
| `<message>` (up to first ` key=` or EOL) | `Message` |
| Trailing `key=val key=val` | `Extra` (dict) |
| Following `  \| …` continuation lines | `ExcInfo` |

The downstream release ships `gwbase log-to-sema <file>` / `gwbase sema-to-log`
to round-trip the two representations losslessly.

What still needs to converge:

- Where does the log-forwarder live (per-host agent? sidecar? broker
  publish from inside the actor?), and what's the format on the wire
  if it goes through the broker?
- How does this play with proactor's logging (which already has its
  own setup) — converge, ignore, or borrow?
- How loud is too loud? At what point does the logging budget
  itself stress the broker or local disk?

### B. Monitoring + alerting hooks

What the framework could provide:

- A typed **problem-event** primitive that actors emit when they
  notice something wrong: `self.report_problem(severity, kind, body)`.
  The framework routes it through the audit-tap / EAR path so that a
  separate collector / journalkeeper / alerting consumer can pick it
  up without the actor needing to know about the consumer.
- **Health/readiness reporting** — the framework periodically emits a
  heartbeat-with-state-summary so that a monitor can ask "is this
  actor healthy?" without polling the actor.
- **Latency / throughput metrics** — per-type-name histograms,
  emitted on a slow timer.
- A **`turn-on-deeper-tracking`** primitive — analogous to the
  industrial-process-engineering pattern: quiet steady state, plus an
  operator-triggered "give me more data on this actor for the next N
  minutes" mode that emits richer events for a window then quiets
  back down.

Open questions:

- Should the framework own the *transport* of these events (rabbit?
  ear?), or just the emission API and let the actor wire the
  destination?
- Where does the data ultimately land — analytics broker, postgres,
  S3, Grafana, …? (Partly the observability domain's question, not
  gwbase's.)
- What's the alerting *cadence* model — every problem event alerts
  immediately, or batched-and-summarized?

### C. LLM sense-making integration point

User-stated direction:

> "Use existing tooling and code for straightforward things but at
> least an occasional 'turn on more verbose tracking and look for
> concerns' using LLM, somewhat like how industrial process
> engineering will occasionally turn on additional data."

Two distinct LLM uses to consider:

1. **Pattern-matching across logs / events** — the LLM is fed a
   window of structured events and asked "anything anomalous here?"
   Not real-time; deliberate, on-demand, scoped to a window. The
   gwbase contribution is making the log/event stream *clean and
   structured enough* that an LLM can ingest a window without
   pre-processing each time.
2. **Sense-making in incident response** — when something breaks,
   the LLM is given a problem-event + the surrounding context window
   + a state snapshot and asked to summarize what likely happened.
   The gwbase contribution is the **structured context** — what's in
   scope, what's not, what state was being held, what the recent
   message history was.

The framework doesn't *invoke* the LLM. It produces the substrate
the LLM consumes. Important: this keeps the LLM out of the hot path
(no per-message LLM dependency, no per-message latency hit), which
matches the "occasional" framing.

What gwbase would need to ship for either to work well:

- Structured logging (A) and structured problem-events (B) — both
  already on the list.
- A **standard way to snapshot an actor's salient state** that can
  be included alongside a problem-event or pulled on demand. Today
  this is per-actor ad-hoc.
- A **windowing convention** — "give me the last N minutes of
  events from this alias" — that consumers (and LLMs) can use
  uniformly.

### D. Other candidates worth at least asking about

- **Connection-loss handling** — pika auto-reconnect is rudimentary.
  Does gwbase need a more opinionated reconnect / backoff /
  circuit-breaker layer?
- **Graceful shutdown** — drain-pending-messages contract for
  testable shutdowns.
- **Test harness** — `mock-transport-for-tests` is a design in
  flight ([`../../designs/mock-transport-for-tests.md`](../../designs/mock-transport-for-tests.md));
  does it grow as part of v-next?
- **Settings-discovery / `.env` conventions** — do we want a standard
  way for an actor to print its effective settings on demand?
- **Versioning / capability negotiation** — does an actor declare
  which gwbase version it's built against, and does that matter?

## Existing pieces to build from

### `gridworks-infra/observability/`

Substantial planning content already lives there:

- **`README.md`** — three-layer architecture (Detection: Bugsnag /
  Prometheus / home-made → Coordination: Linear / OpsGenie →
  Fixes). Reactive-Manifesto philosophy.
- **`logging/README.md`** — planned logging stack: BugSnag (errors;
  in progress) → Loki (logs; planned) → Tempo + OpenTelemetry
  (traces; future). Notes the existing "MorningReport of Glitch"
  pattern.
- **`custom-tools/scada-alerts.md`** — full reference for the
  10 alerts in `gridworks-journalkeeper/alerts/alert_generator.py`.

### Existing scada-side primitives

Two Sema-typed events already exist:

- **`ProblemEvent`** — `gridworks-protocol/src/gwproto/messages/event.py:52-62`.
  TypeName `"gridworks.event.problem"`. Lower-level, generic.
- **`Glitch`** — `gridworks-scada-protocol/src/gwsproto/named_types/glitch.py`.
  TypeName `"glitch"`. Higher-level; node-attributed; richer LogLevel.

**Emit pattern (LTN `ltn.py:1789`):** `glitch = Glitch(...)` →
`self.services.send_threadsafe(Message(Payload=glitch))`. SCADA sends
to its LTN; LTN forwards via its broker.

**For gwbase:** lift the Glitch shape up to a sema-typed event in
gwbase or gridworks-protocol so ALL gwbase actors emit consistently
— not just scada + ltn. Likely a new sema type
`observability.problem-event/000` generalizing both Glitch and
ProblemEvent. Keep ProblemEvent + Glitch as legacy aliases during
migration.

### Existing consumer-side alerter

`gridworks-journalkeeper/alerts/alert_generator.py` (on origin/dev,
not on the jm/db_v2 branch). Monolithic `AlertGenerator` class;
5-minute loop; reads journaldb directly via SQLAlchemy
(`gjk.api_db.get_db`). 10 checks. Alerts sink to OpsGenie via
team-id routing.

**Observations:**

1. Tightly coupled to journaldb schema + scada-protocol `Glitch`
   type. Generalizing to other gwbase services will require
   broker-stream consumption rather than journaldb-direct.
2. Alert thresholds + schedule hardcoded; per-house tuning limited.
3. The alert→Opsgenie routing is fine but firing logic is bespoke
   per-alert. A generic alerter framework would factor the check
   structure: look-back window + condition + alert-key +
   dedup-on-firing-state.
4. Spruce gets a parallel data-fetch path
   (`get_data_from_journaldb_spruce`) — legacy / transition wart.

## Reconciliation — likely directions

**(R1) The ProblemEvent / Glitch hierarchy already exists.** gwbase
should host a generalized version — `observability.problem-event/000`
(sema-typed) — that subsumes both. Migration: ProblemEvent and
Glitch become legacy emitters that produce the same canonical
event-shape; journalkeeper consumes both transparently.

**(R2) Fleet-wide alerter framework is the consumer-side missing
piece.** Decouples alerter logic from journaldb schema; consumes the
analytics-broker event stream. Hosts the 10 existing checks plus new
ones; per-service config-tunable.

**(R3) Verbosity-request fits cleanly between A (logging) and B
(monitoring/alerting).** It's the bridge — operator-or-LLM requests
verbose-mode-on for a specific actor, the actor emits richer events
into the observability stream for the window, the alerter / LLM
analyzes during the window.

**(R4) The detection→coordination→fixes architecture from
`gridworks-infra/observability/README.md` is the right frame** for
`wiki/observability/`'s `executor/primary.md`. Reactive Manifesto +
three-layer separation maps cleanly to gwbase's fleet-wide model:

```
Detection  = gwbase actors emit ProblemEvent/Glitch-shape events;
             prometheus metrics; BugSnag exceptions.
             Verbosity-request lets operators turn the volume up.
Coordination = Linear + OpsGenie + (eventual) LLM-summarized
             windows of the event stream.
Fixes      = code PRs, hardware visits, design changes.
```

**(R5) Rough shipping list once this converges into a design:**

- Sema type `observability.problem-event/000` (subsumes Glitch +
  ProblemEvent shape).
- Sema type `observability.verbosity-request/000`.
- gwbase: `ActorBase.report_problem(...)` hook → emits typed event.
- gwbase: `Orchestrator.on_verbosity_request(...)` hook + default
  behavior (logging-level bump, richer event emission, start +
  expired events).
- wiki/observability/: alerter-framework design (R2).

**(R6) Migration sequencing for journalkeeper:**

- The same release also lifts journalkeeper's `alert_generator` into
  a generic alerter framework. Combined with the gwbase
  `ServiceSettings` cleanup, journalkeeper's next release covers
  both architectural moves at once.
- **Substrate update (2026-05-29):** the analytics broker is
  [deferred](../../../rmqbot/designs/analytics-broker-shovel.md);
  journalkeeper consumes `ear_tx` directly on the prod broker via a
  non-durable, auto-delete queue with a read-only RMQ user. The
  alerter-framework consumes that stream rather than journaldb
  directly — substrate is the prod broker for now, not a separate
  analytics broker.

## Out of scope for this concern

- The actual *infrastructure* (Grafana, Prometheus, S3 buckets, etc.)
  — those belong in `wiki/observability/executor/` once design
  converges.
- The *MQTT*-side of monitoring (SCADA local broker telemetry) —
  proactor/scada concern; this doc focuses on the rabbit-AMQP side.
- Anything FIS-side authorization-related (logged into FIS
  observability separately).

## Next move

Convert this concern to a `wiki/gridworks-base/designs/` design once
(R1)-(R6) are agreed on, with the shipping-list (R5) as the
"What success looks like" section.
