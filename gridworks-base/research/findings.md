# Findings register

Status: Draft · Pass 0 · Updated 2026-05-22

Actionable backlog for `gridworks-base`: bugs, smells, and small/medium
cleanups. Append-only IDs (`F-NNN`), never reused. Big/cross-cutting work
lives as an epic in [`concerns/`](concerns/) (create as needed).

Provenance: findings raised from reading source without tracing all callers
are marked **(inferred)** — confirm before acting.

---

## Area: transport portability

These three findings are framed by the question *"what's the cheapest set of
changes that keeps a future transport swap (NATS JetStream, Kafka, AMQP 1.0,
…) tractable without doing the swap now?"* The codebase today is
**architecture-aware** (clean `RoutingEnvelope`, portable routing-key helpers
in `transport_encoding.py`, transport-neutral heartbeat content) but
**pika/AMQP is wired directly into `ActorBase`** — the handshake (declare,
bind, qos, consume) **is** the actor lifecycle, not a layer beneath it.

The long-term move that matters most is **F-009 signed-handshake** (see
[`../../gridworks-scada/research/findings.md`](../../gridworks-scada/research/findings.md))
— once liveness/contract guarantees live in cryptographic state instead of
broker semantics, transport becomes commodity. Until then, the goal is just
to **not ossify** AMQP assumptions further.

### F-001 — `amq.topic` is hardcoded in `ActorBase`
- **Type:** coupling leak
- **Severity:** med
- **Effort:** small (~1 day)
- **Location:** `gwbase/actor_base.py:638, 665` (inferred)
- **Concern:** —
- **What:** The string `"amq.topic"` — RabbitMQ's built-in MQTT-plugin
  bridge exchange — is baked into actor code, and the public method
  `subscribe_amq_topic()` exposes the broker brand in the API surface.
  This is the one place where the choice of RabbitMQ leaks past the
  `topology.py` layer into per-actor code.
- **Fix idea:** Move the exchange name into settings (e.g.,
  `settings.wrapped_exchange = "amq.topic"`) and rename the method to
  `subscribe_wrapped()` (or `subscribe_edge_bridge()`). Preserves the
  MQTT↔AMQP seam without naming the broker in the API.
- **Why now:** Cheap, isolated, and locks no future decisions. The rename
  alone makes the seam legible.
- **Status:** open

### F-002 — Replace `pika.BasicProperties` with a neutral `MessageMetadata`
- **Type:** coupling leak
- **Severity:** med
- **Effort:** small–med (~1–2 days)
- **Location:** `gwbase/actor_base.py:675–688` (inferred)
- **Concern:** —
- **What:** Outgoing message metadata (`reply_to`, `app_id`, `type`,
  `correlation_id`) is constructed directly as `pika.BasicProperties` at the
  publish site. Other transports (NATS headers, Kafka headers, AMQP 1.0
  application-properties) carry the same conceptual sidecar in different
  envelopes; today we have no neutral representation of *what metadata the
  application actually needs*.
- **Fix idea:** Introduce a small `MessageMetadata` dataclass
  (`correlation_id`, `reply_to`, `app_id`, `category: MessageCategory`,
  optional `transport_headers: dict`). Publish/subscribe paths use the
  dataclass; the transport boundary translates to/from
  `pika.BasicProperties`. No abstract `Transport` interface yet — just one
  dataclass and two translation functions.
- **Why now:** Documents the actual metadata contract (currently implicit in
  pika types), and is the single most useful preparatory step for any
  future transport without committing to one.
- **Status:** open

### F-003 — Stand up an in-memory `MockTransport` for tests
- **Type:** test-infrastructure gap
- **Severity:** med
- **Effort:** med (~2–3 days)
- **Location:** `tests/_stubs.py`, `tests/conftest.py` (inferred)
- **Concern:** —
- **What:** All tests provision a live RabbitMQ (`declare_topology` /
  `provision_topology` call pika directly). This makes unit tests slow,
  parallelism awkward, and — most importantly — makes any future transport
  experiment expensive: there's no way to prototype a Kafka or NATS adapter
  as a weekend spike because tests can't run without Rabbit.
- **Fix idea:** Implement an in-memory broker that models queues,
  exchanges, bindings, and routing-key matching (topic wildcards `*`/`#`).
  Tests pick it via fixture. Live-Rabbit integration tests stay, but become
  a smaller, slower tier.
- **Why now:** Pays back continuously regardless of any transport decision.
  Also tightens the implicit contract about what the transport must
  provide, which is the precondition for ever swapping it.
- **Status:** open

---

## Explicitly NOT recommended right now

- **Extract a full `MessageTransport` ABC.** Premature — the actor
  framework is young, F-009 signed-handshake work is ahead of it, and
  abstracting before a second concrete implementation is in sight tends to
  fossilize the wrong interface.
- **Generalize pika callback signatures across the board.** Big surface,
  small payoff until there's a real second transport.
- **Build a second transport adapter speculatively.** Wait for a forcing
  function (scale, federation pain, or a concrete blockchain-integration
  requirement from the market-maker work).
