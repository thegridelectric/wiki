# Replace `pika.BasicProperties` with neutral `MessageMetadata`

Status: Draft · Pass 0 · Updated 2026-05-27

> Coupling-leak fix in `gwbase/actor_base.py`: outgoing message
> metadata is constructed directly as `pika.BasicProperties` at the
> publish site, with no neutral representation of *what metadata the
> application actually needs*.

## Transport-portability framing

Sibling of [`decouple-amq-topic`](decouple-amq-topic.md) and
[`mock-transport-for-tests`](mock-transport-for-tests.md) — see that
file for the broader "don't ossify AMQP assumptions" framing.

## What

- **Type:** coupling leak
- **Severity:** med
- **Effort:** small–med (~1–2 days)
- **Location:** `gwbase/actor_base.py:675–688` (inferred)

Outgoing message metadata (`reply_to`, `app_id`, `type`,
`correlation_id`) is constructed directly as `pika.BasicProperties`
at the publish site. Other transports (NATS headers, Kafka headers,
AMQP 1.0 application-properties) carry the same conceptual sidecar
in different envelopes; today we have no neutral representation of
*what metadata the application actually needs*.

## Plan

Introduce a small `MessageMetadata` dataclass:

- `correlation_id`
- `reply_to`
- `app_id`
- `category: MessageCategory`
- optional `transport_headers: dict`

Publish/subscribe paths use the dataclass; the transport boundary
translates to/from `pika.BasicProperties`. No abstract `Transport`
interface yet — just one dataclass and two translation functions.

## Why now

Documents the actual metadata contract (currently implicit in pika
types), and is the single most useful preparatory step for any
future transport without committing to one.

## Explicitly NOT recommended (right now)

These are tempting adjacent moves that this design **does not**
include:

- **Extract a full `MessageTransport` ABC.** Premature — the actor
  framework is young, signed-handshake work is ahead of it, and
  abstracting before a second concrete implementation is in sight
  tends to fossilize the wrong interface.
- **Generalize pika callback signatures across the board.** Big
  surface, small payoff until there's a real second transport.
- **Build a second transport adapter speculatively.** Wait for a
  forcing function (scale, federation pain, or a concrete
  blockchain-integration requirement from the market-maker work).
