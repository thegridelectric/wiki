# Thread-safe publishing in ActorBase (always-marshal)

Status: Accepted · Pass 1 · Updated 2026-06-09 · Linear: OPS-383

> `ActorBase.send()` calls `basic_publish` on whatever thread the caller is
> on, but pika is not thread-safe and the channel is owned by the consumer
> thread's ioloop. Fix: route **every** publish onto the ioloop thread via
> `connection.add_callback_threadsafe()`, keeping the single connection.

## Problem

The `SelectConnection` ioloop runs inside `consuming_thread`
(`src/gwbase/actor_base.py:137,502`). `send()` calls
`self._single_channel.basic_publish(...)` **directly, on the caller's
thread** (`actor_base.py:678`). pika is **not thread-safe** — a
connection/channel may only be touched from the thread running its ioloop.

So a `send()` is safe only when it originates on the ioloop thread:

- **Safe** — a send triggered by an inbound message (`on_message →
  dispatch_message → process_message`, all on the ioloop thread). The
  control-plane pong / `send_ready` paths reached via dispatch are safe.
- **Unsafe** — a send from any other thread: an actor's own timer / sensor
  loop, a Supervisor *initiating* heartbeats, a TimeCoordinator emitting
  `sim.timestep` on a clock, `send_ready()` on a schedule, or a caller on the
  main thread (the tests publish from the main thread —
  `tests/test_hello.py:45`, `tests/test_actor_base.py:109`).

There is no `add_callback_threadsafe`, lock, or other marshaling today.

**Symptom:** works almost always, then under load/timing yields frame
corruption / "stream connection lost" / silent drops — and because the
connection is shared, a corrupted publish can break **consuming** too, not
just the one message. This is plausibly the same class of instability
historically remembered as "leaks."

## Decision

**Option (a): always-marshal onto the ioloop, single connection.** `send()`
schedules the publish via
`self._consume_connection.add_callback_threadsafe(cb)`, where `cb` performs
the `basic_publish` on the ioloop thread.

Rejected — **Option (b): a dedicated publisher connection** (a long-lived
`BlockingConnection` used only from the app thread). It works, but adds a
second connection to open / close / reconnect — exactly the lifecycle
surface that produced the original leaks. (a) *reduces* surface area; (b)
adds to it.

(a) is the canonical pika guidance and the smaller change, and its one
trade-off — `send()` can no longer return a synchronous `MESSAGE_SENT` —
is a non-issue here: delivery is best-effort by contract (executor
invariant #9), and critical messages are guarded by **end-to-end
application acks**, not broker publisher-confirms.

## Implementation plan

In `src/gwbase/actor_base.py`:

- `send()` builds the `BasicProperties` + resolves the publish exchange
  (the existing wrapped→`amq.topic` / `NO_PUBLISH_EXCHANGE` / `<rc>mic_tx`
  logic stays), then schedules the actual `basic_publish` via
  `self._consume_connection.add_callback_threadsafe(...)` instead of calling
  it inline.
- **Marshal uniformly** — route *every* send through `add_callback_threadsafe`,
  including control-plane sends already on the ioloop thread.
  `add_callback_threadsafe` is safe to call from the ioloop thread (it just
  queues for the next iteration), so one uniform path beats branching on
  "am I already on the ioloop." Cost is a one-loop-iteration latency on the
  reactive sends — negligible at these volumes.
- **Guard the *schedule* call itself.** `add_callback_threadsafe` raises
  (`ConnectionWrongStateError`, or `AttributeError` when the ioloop/`_impl`
  is gone) if the connection is closed/`None` mid-reconnect or shutdown.
  Because `send` MUST never throw (executor invariant #9), the schedule call
  is wrapped (try/except → return a diagnostic), not just the deferred
  publish. (Refinement folded in Pass 1.)
- **Dual channel-open check — synchronous pre-check AND in-callback
  re-check.** Keep a cheap synchronous "channel open?" pre-check so `send`
  can still return `CHANNEL_NOT_OPEN` for the common already-closed case
  (this also keeps `tests/test_tiers.py::test_tap_can_send_wrapped_but_not_direct`
  green — it asserts `CHANNEL_NOT_OPEN` synchronously). Then **re-check inside
  the scheduled callback** (log + drop) because the connection may drop / be
  reconnecting between schedule time and callback execution. Both checks are
  required; neither alone is sufficient. (Refinement folded in Pass 1.)
- **Return contract becomes best-effort.** `send()` returns after
  *scheduling*, not after publishing. Keep the early `STOPPING/STOPPED`
  guards, the `NO_PUBLISH_EXCHANGE` check, and the synchronous channel-open
  pre-check above; the `MESSAGE_SENT` outcome is now advisory (the real
  publish happens later on the ioloop). Update the docstring + executor
  `transport.md` §3.8 "Send" to say so.

## Consequences

- One connection, all publishes serialized onto the ioloop thread — safe
  regardless of which thread calls `send()`.
- `send()` is now genuinely fire-and-forget (matches invariant #9's "returns
  a diagnostic, never raises, best-effort" intent).
- Control-plane sends gain a one-iteration scheduling hop — immaterial.
- **Caveat — backpressure removed (recorded, not a blocker).** The inline
  `basic_publish` gave the calling thread implicit backpressure (a slow broker
  slowed the publisher). Always-marshal removes it: publishers enqueue onto the
  ioloop callback deque and return immediately, so under *sustained* overload
  (publish rate > ioloop drain rate) that deque can grow unbounded → memory
  growth. A non-issue for gwbase's real traffic (heartbeats / snapshots /
  timesteps are low-rate), but the high-throughput experiment path could hit
  it. Measure ioloop drain time / memory in the green rerun. If it ever bites,
  the fix is a *bounded* publish queue (drop-or-block policy), **not** a
  different threading model.

## Validation

The premise was checked against reality before ratifying — a disposable
pressure harness (`tests/pressure.py`, NOT pytest-collected, never runs in CI)
hammers `send` from many non-ioloop threads against the dev broker and scores
sender-connection health. On the **current** direct-publish code it reproduces
the race on demand: 48 threads, 128 KB–512 KB bodies, a 10 µs GIL switch
interval → **~100 % delivery loss**, a pika internal `AttributeError` raised
*inside* `basic_publish`, and a forced reconnect (the corrupted publish broke
*consuming* too). The `--switch-interval` knob *accelerates* the latent race
(the same large-body blast at Python's 5 ms default stayed clean) — it
compresses rare field timing into a reliable repro, it does not manufacture a
bug. The harness reruns green against the fixed code, then is deleted (its
distillate moves here / into `transport.md` §3.8).

## Scope

A **separate small change**, not part of gwbase 0.5.0. Lands as its own
patch release when picked up. Update `actor_base.py` `send()` + the
`transport.md` §3.8 send description. The non-ioloop load test that proves it
is the **disposable** `tests/pressure.py` harness above — run red (done) → run
green (after the fix) → delete; no permanent CI test is added.
