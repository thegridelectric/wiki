# gridworks-base — Application layer & diagnostics (§5–§6)

Sub-spec of the gridworks-base rebuild spec — **start at
[`primary.md`](primary.md)**. Section numbers are global; this file holds
§5 (the application layer) and §6 (diagnostics). Transport mechanics are in
[`transport.md`](transport.md); the codec in [`codec.md`](codec.md).

---

## 5. The application layer

### 5.1 ActorBase (transport-only base class)

`ActorBase` is the "I am a RabbitMQ-connected actor" base class. It
provides:

- Identity (§2), routing-class derivation, queue name allocation.
- Connection / channel / queue / consume lifecycle (§3.8).
- Reconnect-with-backoff in a dedicated consumer thread.
- Envelope-construction helpers (`direct_envelope`,
  `broadcast_envelope`, `wrapped_envelope`) that fill in
  `from_alias`/`from_class`.
- `send(envelope, body, correlation_id?)` that publishes pre-encoded
  bytes.
- Subclass hooks: `local_start()`, `local_stop()`,
  `local_rabbit_startup()` (for extra queue bindings, e.g. broadcast
  subscriptions and the AMQP↔MQTT scada bridge — §3.5).

`ActorBase` is abstract on a single framework method:

```
dispatch_message(envelope: RoutingEnvelope, body: bytes) -> None
```

The transport calls this for every parsed delivery. It is *not* the
method that applications implement — that's `process_message`, defined
one layer up on `GridworksActor` (§5.2). `dispatch_message` exists so
intermediate layers (control-plane filtering, future routing
middlewares) can interpose between the transport and the application
without applications needing to know.

`ActorBase` deliberately **knows nothing about codecs**. It holds no
SemaCodec; it never calls `to_bytes` / `from_bytes`. Any subclass that
wants to talk in typed messages owns its own codec instance.

### 5.2 GridworksActor (the canonical default)

`GridworksActor` is the canonical actor for GridWorks applications.
Virtually every application class inherits from it (including
Supervisor and TimeCoordinator implementations, which themselves
participate in the control plane further upstream). It is a thin
layer on top of `ActorBase` that handles its control-plane traffic
internally so applications do not have to re-implement it:

- `heartbeat.a` **from this actor's supervisor** (`my_super_alias`) —
  automatically answered with a pong; semantic hook
  `on_supervisor_heartbeat(from_alias)` is then called. A `heartbeat.a`
  from any *other* sender — e.g. a subordinate's heartbeat arriving at its
  supervisor — is **not** consumed; it falls through to `process_message`
  so the application can observe it. (This is what lets a supervisor watch
  its subordinates' heartbeats while still auto-ponging its own
  supervisor.)
- `sim.timestep` from this actor's time coordinator — updates the
  simulated clock; semantic hook
  `on_simulated_time(time_unix_s, from_alias, is_new)` is called.

Construction additionally requires `my_super_alias` and
`my_time_coordinator_alias` (the application supplies them — typically
from its own configuration).

`GridworksActor` owns a **private** `SemaCodec` instance for these
two types. The subclass's own codec does not need to register them.

The dispatch rule (implemented inside `GridworksActor.dispatch_message`):

```
dispatch_message(envelope, body):
    if envelope.type_name == "heartbeat.a" and envelope.from_alias == my_super_alias:
        decode (private codec); pong + on_supervisor_heartbeat   # internal
    elif envelope.type_name == "sim.timestep":
        decode (private codec); update clock + on_simulated_time # internal
    else:
        process_message(envelope, body)   # incl. heartbeat.a from non-supervisors
```

(In the implementation the `from_alias` check happens just after decode,
inside the control-plane handler; the effective routing is as above.)

Final application classes implement `process_message`. They do **not**
override `dispatch_message`.

Behavioral rules of note:

- A `heartbeat.a` from `my_super_alias` is handled internally (pong +
  `on_supervisor_heartbeat`). A `heartbeat.a` from any *other* alias is
  **not** swallowed — it falls through to `process_message`, so an actor
  (e.g. a supervisor) can observe heartbeats from its subordinates.
- A `sim.timestep` with `time_unix_s` less than the latest observed
  value is dropped (anti-rewind).
- A `sim.timestep` whose value equals the latest is still surfaced via
  `on_simulated_time` with `is_new = false` — the hook can rely on this
  to distinguish a clock advance from a re-announcement.
- The pong (`heartbeat.a` back to the supervisor) is sent as a direct
  message, encoded by the private codec.
- `send_ready(time_unix_s?)` constructs a `Ready` message and sends it
  direct to the time coordinator. Defaults to the latest observed
  simulated time.

### 5.3 Example: hello_rabbit

The minimal end-to-end shape:

```
class HelloGNode(GridworksActor):
    def __init__(self, settings):
        super().__init__(
            settings=settings,
            my_super_alias="d1.super1",
            my_time_coordinator_alias="d1.time",
        )

    def process_message(self, *, envelope, body):
        return                              # ignore everything

# settings carry transport_class=LeafTransactiveNode, alias "d1.hello"
gn = HelloGNode(settings=...)
gn.start()                                  # spawns consumer thread, binds queue

hb = HeartbeatA(my_hex="0", your_last_hex="a")
gn.send(
    envelope=gn.broadcast_envelope(type_name=hb.type_name),
    body=hb.to_bytes(),                     # SemaType serializes itself
)

gn.stop()
```

(The demo runs as a `LeafTransactiveNode`, not a `Scada` — scada is
MQTT-native and has no AMQP exchanges, §3.5.)

What the broker sees:

- A new queue `d1.hello-Fxxx` declared and bound to `ltn_tx` with
  pattern `rj.*.*.*.*.d1-hello`.
- One message published to exchange `ltnmic_tx` with routing key
  `rjb.d1-hello.ltn.heartbeat-a` and body
  `{"MyHex":"0","YourLastHex":"a","TypeName":"heartbeat.a","Version":"..."}`.
- The queue auto-deletes when the actor stops.

---

## 6. Diagnostics

Both ends of the boundary expose enums rather than raising on
transport-or-decode failure paths, so the broker event loop is never
disrupted by application bugs.

`OnSendMessageDiagnostic`: `MESSAGE_SENT`, `CHANNEL_NOT_OPEN`,
`STOPPED_SO_NOT_SENDING`, `STOPPING_SO_NOT_SENDING`, `UNKNOWN_ERROR`.

`OnReceiveMessageDiagnostic`: `MESSAGE_DELIVERED`,
`ROUTING_KEY_PARSE_ERROR`, `UNHANDLED_CATEGORY`.

The latest diagnostic is stored on the actor and is intended for test
assertions and operational logging.
