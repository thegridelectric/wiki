# Decouple `amq.topic` from ActorBase

Status: Draft · Pass 0 · Updated 2026-05-27

> Coupling-leak fix in `gwbase/actor_base.py`: the RabbitMQ-specific
> exchange string and method name leak past the topology layer into
> per-actor code.

## Transport-portability framing

The codebase is **architecture-aware** (clean `RoutingEnvelope`,
portable routing-key helpers in `transport_encoding.py`,
transport-neutral heartbeat content) but **pika/AMQP is wired directly
into `ActorBase`** — the handshake (declare, bind, qos, consume) **is**
the actor lifecycle, not a layer beneath it. The long-term move that
matters most is the signed-handshake (lives in scada-side designs;
see [`../../gridworks-scada/`](../../gridworks-scada/)) — once
liveness/contract guarantees live in cryptographic state instead of
broker semantics, transport becomes commodity. Until then, the goal
of this design (and its siblings
[`neutral-message-metadata`](neutral-message-metadata.md) +
[`mock-transport-for-tests`](mock-transport-for-tests.md)) is to
**not ossify AMQP assumptions further**.

## What

- **Type:** coupling leak
- **Severity:** med
- **Effort:** small (~1 day)
- **Location:** `gwbase/actor_base.py:638, 665` (inferred)

The string `"amq.topic"` — RabbitMQ's built-in MQTT-plugin bridge
exchange — is baked into actor code, and the public method
`subscribe_amq_topic()` exposes the broker brand in the API surface.
This is the one place where the choice of RabbitMQ leaks past the
`topology.py` layer into per-actor code.

## Plan

Move the exchange name into settings (e.g.,
`settings.wrapped_exchange = "amq.topic"`) and rename the method to
`subscribe_wrapped()` (or `subscribe_edge_bridge()`). Preserves the
MQTT↔AMQP seam without naming the broker in the API.

## Why now

Cheap, isolated, and locks no future decisions. The rename alone
makes the seam legible.
