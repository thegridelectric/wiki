# The shovel — rebuild spec

Status: Draft · Pass 0 · Updated 2026-10-11

What this is: the faithful-rebuild spec for `gridworks-shovel`, the
service that mirrors one broker's audit tap onto another broker, one
way.

## Overview

The shovel is a gwbase `ActorBase` tap on the source broker: it binds a
queue with `#` to `ear_tx` as its own principal (cert and claims through
the FIS gate) and acks each message as it is heard. On the destination
broker it holds one publishing connection with publisher confirms and
republishes every message, routing key and body verbatim, to `shovelmic_tx`,
the destination's non-internal ingress exchange, which fans into that
broker's internal `ear_tx`. Unparseable routing keys cross too: a mirror
passes everything on.

It exists so that consumers which serve a website or an outside party
never hold a credential on the control broker, and so that nothing they
write can reach it: the shovel only consumes on the source and only
publishes on the destination. FIS cannot make a read-only identity
(every principal may read, every Service may publish anywhere), so
separate brokers joined one way are the only structural containment.

It is a GridWorks service rather than the RabbitMQ shovel plugin because
the gate's mechanism needs a claims payload the plugin's Erlang client
cannot send, so the plugin could log in only as a password user.
Federation is out because it pulls: the destination would hold a source
credential. The shovel mirrors the whole of `ear_tx`, not a subset:
snapshots are most of the stream by bytes, and a subset would put the
source broker in the loop for every new consumer need.

## Invariants

- **One way.** The shovel's source credential is a consume-only use of a
  principal; its destination credential is a password user that may write
  to `shovelmic_tx` and nothing else.
- **Verbatim.** Routing key and body cross unchanged. AMQP properties
  set by the original publisher (`app_id`, `user_id`, `correlation_id`)
  do not; the destination sees the shovel as the publisher.
- **Lossy by design, never a queue on the source.** The source side acks
  on receipt, and the shovel declares its own source queue capped at
  `SHOVEL_SOURCE_QUEUE_MAX_LENGTH` (10,000), oldest dropped, so a slow
  shovel loses messages there rather than filling the source broker. A
  publish the destination holds blocked (a memory or disk alarm) fails
  after `SHOVEL_BLOCKED_TIMEOUT_SECONDS` (10). While the destination is
  unreachable or failing, messages are held in a bounded in-memory buffer
  (`SHOVEL_BUFFER_SIZE`, default 5000) and dropped oldest first; the
  shovel retries every `SHOVEL_RECONNECT_SECONDS` and drains the buffer in
  order when the destination is back. The audit archive and the journal
  are the durable records.
- **One thread touches the destination connection.** pika's blocking
  connection is not thread-safe; every use of it happens on the consumer
  thread, and the CLI's periodic tick marshals the idle keepalive there.
- **No topology is declared on the destination.** The destination's
  exchanges come from its definitions file,
  `broker/analytics_definitions.json` in the repo, tested against
  `gwbase.topology` so `ear_tx` keeps the source's shape.

## Settings

Prefix `SHOVEL_`; `rabbit` (from `ServiceSettings`) is the source,
`analytics` the destination, both `RabbitBrokerClient` blocks.
`SHOVEL_PREFETCH_COUNT` (gwbase, default 100) is the source prefetch: the
source is a transatlantic round trip away, and at prefetch 1 the shovel
would cap near 9 messages a second. `amqps` on
the destination verifies the broker against the system CA bundle (the
analytics broker's certificate is publicly issued). The env template:
`service/template.env`.

## Operations

`shovel listen` runs it; `shovel config` prints the settings. The log is
the gwbase actor log, `~/.local/state/gridworks/shovel/log/<alias>.log`,
with an hourly line of heard, forwarded, dropped and buffered counts and
a warning when an hour passes with nothing heard. Deployment: one login
`shovel` on the analytics box, `service/shovel.service` (gridworks-infra
`rmqtap/instance-README.md`).

## Glossary

- **mic exchange** — `shovelmic_tx` on the destination: the shovel's own
  publish exchange in gwbase's grammar (`<name>mic_tx`), non-internal,
  bound `#` into `ear_tx`.

## Open

- **Retention on the destination `ear_tx`.** Messages fly past on both
  brokers. A queue with retention would give consumers a replay window: a
  week is about 2 GB today and about 30 GB at 100 homes, where a volume,
  not a bigger box, is the answer.
- **Publisher properties.** Only routing key and body are copied. Copying
  `app_id`, `user_id` and `correlation_id` waits on a consumer that reads
  them.

## TOC

- This file. One instance in production, `hw1.shovel`, on the analytics
  box (gridworks-infra `rmqtap/instance-README.md`).
