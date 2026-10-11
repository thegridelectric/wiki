# pipelined-publish

Status: Draft · Pass 0 · Updated 2026-10-11 · Linear: OPS-583

**EDD: yes** a throughput run is the verification: the same synthetic
stream through the shovel before and after, on the dev broker and then
on the real pair, reports messages per second forwarded and shows the
order of messages is kept.

> What this is: the shovel publishes to the analytics broker without
> waiting for each confirm before sending the next, with a bounded
> number of messages in flight. The step to take when the shovel's
> publish side nears its ceiling, before running several shovels.

## Why

With prefetch 100 (gwbase's default from 0.5.17) the round trip to prod
no longer limits the shovel. The publish side does: `AnalyticsPublisher`
uses a blocking pika channel in confirm mode, so each publish waits for
the analytics broker's confirm before the next goes out. Measured
2026-10-11 against the dev broker with 16 kB messages: about 1,570
messages a second. TLS on the box lowers that. At 1,700 to 2,800
messages per home per day it is tens of thousands of homes, so this
waits until the shovel lag alert (OPS-585) says it is needed.

## The shape

1. **A window in flight.** The shovel publishes up to N messages
   (about 500) without waiting. Each stays in a map keyed by its
   delivery tag until its confirm arrives; a confirm with `multiple`
   releases every tag up to it. When the window is full the shovel
   stops taking from the buffer until confirms free room, so the window
   never grows into a second unbounded buffer.
2. **Its own thread and event loop.** gwbase builds a new consumer
   connection and event loop on every reconnect to prod, so the
   analytics connection cannot live on that loop. The publisher gets
   one thread and one pika `SelectConnection` loop for the life of the
   process; the consumer hands each message across with a thread-safe
   callback. That thread alone owns the buffer, the window and the
   analytics connection.
3. **Failure.** A dropped connection, a blocked-connection timeout or a
   nack puts every message still in the window back at the front of the
   buffer, in order, to be sent again after reconnecting. The buffer's
   bound and drop-oldest rule apply as they do now.
4. **The window rules in a plain class** with no pika in it (add, send,
   confirm, requeue), so they are unit-tested without a broker. The
   publisher ties that class to pika.

## What changes for consumers

Today a message reaches the analytics broker at most once. With a window
in flight, a message the analytics broker accepted but had not yet
confirmed when the connection dropped is sent again, so it arrives
twice. Snapshots and reports describe state, so a duplicate does no harm
to a page that shows current state; a consumer that counts messages
would count it twice.

## Size and risk

About 150 to 200 lines replacing about 80: the publisher, the window
class, and rewritten shovel unit tests, plus the throughput run. The
risk is in the thread handoff and the shutdown order, the same place the
gwbase 0.5.16 shutdown race was.

## Do this next

Measure the publish ceiling on the box, over TLS, and record it in
gridworks-infra `rmqtap/instance-README.md` "Capacity and faults". That
number sets the shovel lag alert's threshold and says how far off this
design is.

## Open questions

- The window size, from the measurement.
- Whether consumers need a sequence number from the shovel to drop
  duplicates, or tolerating them is enough.
