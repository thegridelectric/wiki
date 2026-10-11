# partitioned-instances

Status: Draft · Pass 0 · Updated 2026-10-11 · Linear: OPS-584

**EDD: yes** a throughput run on the real pair is the verification: a
synthetic stream through two or more shovel instances reports messages
per second forwarded and shows each sender's messages arrive in order,
and stopping one instance silences only its slice.

> What this is: the mirror's throughput past what one shovel can do.
> Several shovel processes run side by side, each its own FIS principal
> with its own cert, each binding a disjoint slice of prod's `ear_tx`.
> A step for when the fleet's stream approaches one shovel's ceiling,
> not before.

## When it is needed

One shovel's ceilings, in order (gridworks-infra
`rmqtap/instance-README.md` "Capacity and faults"):

1. Source prefetch: lifted from 1 to 100, so the round trip to prod is
   no longer the limit.
2. Publish side: one confirm awaited per message, about 1,570 messages a
   second against the dev broker (2026-10-11), lower over TLS on the
   box. At 1,700 to 2,800 messages per home per day that is tens of
   thousands of homes.
3. Publishing without waiting on each confirm, with a bounded window in
   flight, raises 2 several times over in one process. Cheaper than
   this design and the step to take first (OPS-583).

This design is for after 3, or for when one process is no longer
enough for another reason (CPU on the box, one connection's bandwidth).
The shovel lag alert (OPS-585) says when.

## The shape

- N shovel instances on the tap box, each a separate systemd unit and a
  separate FIS Service principal (`hw1.shovel-0`, `hw1.shovel-1`, ...),
  each with its own cert, so each cert still belongs to one program.
- Each instance binds a disjoint slice of `ear_tx` by routing key, so
  every message is taken by exactly one instance. A shared queue would
  scramble order across instances; one `#` queue each would duplicate
  everything.
- The slices are by sender, so each sender's messages stay in order:
  one instance's messages from a given scada or service arrive as they
  were sent.
- All instances publish to the same `shovelmic_tx` on the tap with the
  same `shovel` login, or one login each if per-instance accounting is
  wanted.

## The hard part: slicing by sender

RabbitMQ topic bindings match words, not hashes. A slice by sender has
to be written as binding patterns, and the sender sits at a different
position in the two routing-key grammars (`gw.<scada-alias>.to...` and
`<rc>.<from-alias>.<rc>...`). Options:

- **By alias list:** each instance binds an explicit list of sender
  aliases. A pattern matches whole dot-separated words and an alias is
  one word, so a list cannot say "every alias starting with a". Topic
  bindings also cannot say "everything no other instance takes", so
  there is no catch-all: a sender missing from every list, such as a
  new house, is not mirrored. The lists come from the fleet registry
  and must be kept complete.
- **A consistent-hash exchange** on prod (`rabbitmq_consistent_hash_exchange`
  plugin) between `ear_tx` and the instances, hashing on the routing
  key. Even spread and no lists, but it is a new exchange and plugin on
  the prod broker, and a hash on the whole key splits a sender's
  message types across instances (order is still kept within a type).

## What it costs

- A dead instance blacks out its slice until restarted, so more
  instances add capacity but no redundancy.
- N principals and certs to mint, record in the cert inventory and
  renew.
- The shovel alerts in OPS-585 become per instance.

## Do this next

Nothing until the shovel lag alert (OPS-585), or a measurement,
shows the single shovel nearing its ceiling. Then measure the shovel on
the box and choose a slicing option.

## Open questions

- Alias lists against the consistent-hash exchange.
- Whether per-sender order is required by any consumer, or per-type
  order is enough (it decides whether hashing the whole key is
  acceptable).
