# In-memory `MockTransport` for tests

Status: Draft · Pass 0 · Updated 2026-05-27

> Test-infrastructure fix: all tests provision a live RabbitMQ, which
> makes unit tests slow, parallelism awkward, and any future transport
> experiment expensive.

## Transport-portability framing

Sibling of [`decouple-amq-topic`](decouple-amq-topic.md) and
[`neutral-message-metadata`](neutral-message-metadata.md) — see
those for the broader "don't ossify AMQP assumptions" framing.

## What

- **Type:** test-infrastructure gap
- **Severity:** med
- **Effort:** med (~2–3 days)
- **Location:** `tests/_stubs.py`, `tests/conftest.py` (inferred)

All tests provision a live RabbitMQ (`declare_topology` /
`provision_topology` call pika directly). This makes unit tests slow,
parallelism awkward, and — most importantly — makes any future
transport experiment expensive: there's no way to prototype a Kafka
or NATS adapter as a weekend spike because tests can't run without
Rabbit.

## Plan

Implement an in-memory broker that models:

- queues
- exchanges
- bindings
- routing-key matching (topic wildcards `*`/`#`)

Tests pick it via fixture. Live-Rabbit integration tests stay, but
become a smaller, slower tier.

## Why now

Pays back continuously regardless of any transport decision. Also
tightens the implicit contract about what the transport must
provide, which is the precondition for ever swapping it.
