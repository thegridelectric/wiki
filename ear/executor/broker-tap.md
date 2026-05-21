# Ear — The Broker Audit Tap

> The **ear** is GridWorks' most fundamental data-persistence mechanism: a
> universal, passive tap that copies every message crossing the broker into
> a single exchange, from which it is shovelled off-broker for persistence
> and analytics. This note specifies the *broker-side tap* only. The
> persistence/replay semantics and the analytics consumers (journalkeeper)
> are separate concerns — see "Scope boundaries" below.

## What the tap is

For every AMQP routing class `<rc>` that runs as an actor (the
`AMQP_ACTOR_CLASSES` set in `gwbase/topology.py`), the generated broker
topology binds:

```
<rc>mic_tx  → ear_tx   (routing key "#")
amq.topic   → ear_tx   (routing key "#")     # MQTT-bridged + wrapped (gw) traffic
```

`ear_tx` is a **durable, internal, topic** exchange. Every message any actor
publishes — AMQP via its `mic_tx`, or MQTT/wrapped via `amq.topic` — is
copied into `ear_tx`. That makes `ear_tx` the single, complete tap point for
everything crossing the broker.

## Why the tap is *passive*

On the **control broker**, `ear_tx` has **no bound consumer**. A topic
exchange that routes a copy and finds no matching queue simply discards it,
so the `#` fan-in costs almost nothing when nothing is draining it. The cost
and the blast radius of audit/analytics come from *consumers* connecting to
the control broker and draining the tap — not from the passive exchange
itself.

This yields the governing principle:

> **No analytics entity connects to the production control broker.**
> The control broker hosts only real-time grid-ops participants (the
> `_tx`/`mic_tx` control plane, `amq.topic` for scada, and FIS — which *is*
> grid ops, being the connection authority). `ear_tx` exists there only as a
> passive, well-defined **shovel source**.

## Dev vs. prod

- **Dev:** the `ear_tx` tap exists for local inspection. There is **no
  `dummy_ear_q`** by default — bind a throwaway queue to `ear_tx` by hand
  when debugging.
- **Prod:** `ear_tx` exists as a **passive shovel source**. A RabbitMQ
  **shovel** (prod-side, push) forwards `ear_tx` to a **separate analytics
  broker**, where journalkeeper and other analytics consumers live.
  Nothing analytics-side ever opens a connection into the control broker.
  FIS's asynchronous auth events land on that same analytics plane.

## Scope boundaries

**Emitted by the gwbase definitions generator** (`gwbase/topology.py` →
`rabbit/rabbitconfig/*.json`), in both dev and prod:

- `ear_tx` (durable, internal, topic)
- `<rc>mic_tx → ear_tx (#)` for every `AMQP_ACTOR_CLASSES` member
- `amq.topic → ear_tx (#)`

See `wiki/gridworks-base/executor/transport.md` §3.5 and
`provisioning.md` §3.6 for how `ear_tx` sits in the generated topology
(start at that domain's `primary.md`).

**Out of gwbase scope** (provisioned as deployment/analytics infra):

- The **shovel** from `ear_tx` to the analytics broker (names the analytics
  broker; prod-side push config).
- The **analytics broker** itself.
- **journalkeeper**, which **self-provisions** its own queue + binding *on
  the analytics broker* — never on the control broker.

## Open / TBD

- **Ear as persistence source-of-truth + replay.** The reason ear is called
  "fundamental persistence" is that the captured stream is intended to be
  the authoritative, replayable record of everything the system did. The
  retention model, ordering/idempotency guarantees, and replay semantics
  belong in a fuller `wiki/ear/executor/primary.md` — not yet written.
- **Sampling vs. complete capture** at high prod volume (the `#` tap is
  complete today; whether prod ever needs sampling is unresolved).
