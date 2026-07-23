# Publish backpressure for marshaled sends

Status: Draft · Pass 0 · Updated 2026-06-09 · Linear: OPS-384

> What this is: a parked follow-up to the thread-safe-publish fix ([OPS-383](https://linear.app/gridworks/issue/OPS-383)).
> It records the one trade-off that fix introduced — loss of inline
> backpressure — and the open question of whether/how to bound the publish
> queue. **Backlog: no code until a high-throughput path actually needs it.**

## Problem

[OPS-383](https://linear.app/gridworks/issue/OPS-383) made `ActorBase.send` thread-safe by marshaling every publish onto the
consumer thread's ioloop via `add_callback_threadsafe` instead of calling
`basic_publish` inline on the caller's thread. That removed the **implicit
backpressure** the inline publish gave: a synchronous `basic_publish` slowed the
caller when the broker/socket was slow, so a producer could not outrun the
transport.

With marshaling, `send` just enqueues a callback and returns. If the **sustained
publish rate exceeds the ioloop's drain rate**, the callback queue (and pika's
outbound frame buffer behind it) grows without bound — frames accumulate in
memory. The pressure harness made this concrete: blasting MB-scale bodies at the
fixed code buffers gigabytes if the broker can't keep up, which is why the green
rerun deliberately used small bodies.

This is a **non-issue for gwbase's real traffic** — heartbeats, snapshots, and
`sim.timestep` are low-rate and small. It only bites a sustained high-throughput
producer, which is precisely the "powerful simulated experiments" path we want
gwbase to handle well — hence worth parking, not forgetting.

## Open (deferred — not yet decided)

- **Observe first.** Add observability on publish-queue depth (and/or pika's
  outbound buffer) so the condition is *visible* before it causes an OOM. This
  is the cheap, no-regret first step whenever this is picked up.
- **Bounding policy.** If a bound is needed: drop-oldest, drop-newest, or block
  the caller (restoring backpressure)? Each interacts differently with the
  best-effort `send` contract (invariant #9) — blocking reintroduces
  backpressure but can stall a caller; dropping preserves liveness but loses
  messages (acceptable only for best-effort traffic, not acked critical paths).
- **Bound value.** A sensible queue cap / memory budget, likely per-actor.
- **Measure.** Re-stand-up the [OPS-383](https://linear.app/gridworks/issue/OPS-383) pressure-harness pattern (it was
  disposable) to validate whatever policy lands under load.

**Not in scope:** changing the threading model. The marshaling decision stands;
this is purely about bounding the queue *behind* it.

## Pointers

- The trade-off is recorded as a caveat in
  [`../executor/transport.md`](../executor/transport.md) "Threading and lifecycle".
- Originating fix: [OPS-383](https://linear.app/gridworks/issue/OPS-383) (thread-safe `ActorBase.send`).
