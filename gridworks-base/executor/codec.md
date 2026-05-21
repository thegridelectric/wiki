# gridworks-base — Codec layer / Sema (§4)

Sub-spec of the gridworks-base rebuild spec — **start at
[`primary.md`](primary.md)**. Section numbers are global; this file holds
§4. The codec is wholly independent of the transport
([`transport.md`](transport.md)).

---

## 4. The codec layer (Sema)

Sema is a schema system for **named, versioned message types** with
JSON-on-the-wire serialization. It is wholly independent of the
transport.

### 4.1 SemaType

A `SemaType` is a typed message value. Every concrete subclass declares,
as class-level defaults:

- `type_name: string` — dotted LeftRightDot identifier
  (e.g. `heartbeat.a`).
- `version: string | null` — typically a zero-padded integer string
  (`"000"`, `"001"`). May be null for un-versioned helper types.

Plus its named fields, each with a value type (primitive, enum,
property-formatted string, or nested SemaType).

Construction is **strict** — no extra fields, no permissive coercion.
Instances are immutable.

**Public methods on every SemaType:**

| Method                                | Direction | Purpose                                                              |
| ------------------------------------- | --------- | -------------------------------------------------------------------- |
| `to_bytes() -> bytes`                 | encode    | JSON bytes, PascalCase keys, omits null fields                       |
| `to_dict() -> dict`                   | encode    | Same as above but a dict                                             |
| `from_bytes(bytes) -> Self`           | decode    | Parse JSON bytes; key casing must be recursively PascalCase          |
| `from_dict(dict) -> Self`             | decode    | Validate against the schema; raise on extras or wrong shape          |
| `type_name_value() -> string`         | introspect| The class-level `type_name` default                                  |
| `version_value() -> string \| null`   | introspect| The class-level `version` default                                    |
| `upgrade() -> SemaType`               | migrate   | Produce the next-version instance from this one (subclass overrides) |
| `to_latest(registry) -> SemaType`     | migrate   | Walk `upgrade()` until the version matches the registry's current    |

**Wire convention:** JSON keys are PascalCase
(`TypeName`, `Version`, `MyHex`, ...). Internal field names are
snake_case. The codec converts between the two via the obvious
boundary-respecting transformation. Decoding rejects dicts that contain
any non-PascalCase keys (recursively) — a hard invariant of the wire
format.

`exclude_none=True`: optional fields that are null are omitted entirely
from the wire form.

### 4.2 SemaCodec

A `SemaCodec` is a registry plus a bidirectional transformer. Each
codec instance holds:

- `registry: { type_name -> latest SemaType class }`
- `old_versions: { type_name -> { version -> historical SemaType class } }`

Both are populated at construction time by auto-discovery: the registry
from the `types` module's exported names, the historical versions from
files under a sibling `old_versions/` directory.

**Decode modes:**

| Mode       | Behavior on unknown type                | Behavior on unknown version of known type   |
| ---------- | --------------------------------------- | ------------------------------------------- |
| `strict`   | Raise                                   | Raise                                       |
| `degraded` | Return a `DegradedSemaType` wrapper     | Return a `DegradedSemaType` wrapper         |

**Decode algorithm** (`from_dict`):

1. Reject non-dict input. Require a `TypeName` key. Require recursive
   PascalCase.
2. Look up `TypeName` in the registry.
   - Missing: raise (strict) or return `DegradedSemaType` (degraded).
3. If `Version` matches the registry class's `version_value()`, validate
   and return the typed instance — the fast path.
4. Otherwise check `old_versions[type_name][version]`:
   - Found: validate to that historical class; if `auto_upgrade` (the
     default), call `to_latest(registry)` to walk forward through
     `upgrade()` to the current version.
   - Not found: raise (strict) or return `DegradedSemaType` (degraded).

`from_bytes` is `from_dict ∘ json_parse`. `to_bytes` defers to the
type's own `to_bytes`.

### 4.3 DegradedSemaType

A best-effort decode result when the schema is unknown or the version
is unsupported. It is NOT a `SemaType` and MUST NOT drive control
logic. Fields: `type_name`, `version`, `raw` (the original dict),
`known_fields`, `unknown_fields`.

Useful for:

- Logging and diagnostics on messages from a peer running a future
  schema.
- Forwarding/relaying without round-tripping through a strict decode.

### 4.4 Versioning model

- Versions are zero-padded integer strings: `"000"`, `"001"`, …
- The latest version of each type lives under the canonical class
  exported from the `types` package; superseded versions live under
  `types/old_versions/`.
- Each historical class overrides `upgrade()` to produce its successor.
- `to_latest(registry)` walks the chain forward and asserts the chain
  terminates after at most `(latest - current)` steps — a defense
  against cycles or buggy `upgrade()`s.
- Versions are integers under string disguise (so `"010"` sorts
  correctly as text); a renaming or breaking change requires a new
  `type_name`, not just a version bump.

### 4.5 Property formats

Common scalar shapes are encoded as named property formats and validated
on the way in:

| Format            | Pattern / range                                              |
| ----------------- | ------------------------------------------------------------ |
| `LeftRightDot`    | `^[a-z][a-z0-9]*(\.[a-z0-9]+)*$` — dotted lowercase identifier |
| `HexChar`         | A single character matching `[0-9a-fA-F]`                    |
| `UTCSeconds`      | Unix seconds, year 2000–3000                                 |
| `UTCMilliseconds` | Unix milliseconds, year 2000–3000                            |
| `UUID4Str`        | RFC 4122 UUID v4 (lowercase canonical form)                  |

Sema is the authority on `LeftRightDot`. The transport layer mirrors
the pattern with hyphens instead of dots (`LRH`) for routing-key
tokens; the two must remain in sync.

### 4.6 Built-in types

The bundled type catalog (in `gwbase.sema.types`):

- `heartbeat.a` — ping/pong field pair (`MyHex`, `YourLastHex`).
- `sim.timestep` — simulated-clock advance (`TimeUnixS`, optional
  `WillStartNewTimestep`).
- `ready` / `sim.ready` — child actor readiness announcement
  (`FromGNodeAlias`, `FromGNodeInstanceId`, `TimeUnixS`).
- `g.node.gt` — durable GNode definition (id, alias, class, status).
- `g.node.instance.gt` — runtime GNode instance.
- `gridworks.header` — header fields of the `gw` application envelope
  (see §4.7): `Src`, `Dst`, `MessageType`, `MessageId`, `AckRequired`.
- `gw` — the application envelope itself: `Header` (`GridworksHeader`)
  plus `Payload` (an opaque PascalCase dict whose `TypeName` matches
  `Header.MessageType`).

Each type's authoritative shape is described in YAML under
`sema/definitions/types/<type-name>/<version>.yaml`; the runtime classes
are intended to be code-generated from those YAML files. A
reimplementation should either generate code from the same YAML or
hand-port the types and treat YAML as the source of truth for the wire
shape.

### 4.7 The `gw` application envelope (and wrap/unwrap helpers)

The `gw` Sema type is an **application-layer envelope**, distinct from
the transport-layer `RoutingEnvelope`. It carries a `GridworksHeader`
plus an opaque `Payload` dict so a message can traverse multiple hops
(rabbit → MQTT bridge → SCADA device, etc.) while retaining
end-to-end addressing and an ack flag.

Wire form:

```
{
  "TypeName": "gw",
  "Header": {
    "TypeName":    "gridworks.header",
    "Version":     "001",
    "Src":         "<sender-alias>",
    "Dst":         <opaque-addressing-value>,
    "MessageType": "<inner-type-name>",
    "MessageId":   "<uuid>",
    "AckRequired": <bool>
  },
  "Payload": { "TypeName": "<inner-type-name>", ... }
}
```

**Invariants:**

- `Header.MessageType == Payload.TypeName`.
- The `WrappedRoutingEnvelope.type_name` equals both (the routing key
  carries the inner type, not `"gw"`).

**Helpers** (in `gwbase.sema.wrapped`) — pure functions that depend on
the `Gw` and `GridworksHeader` SemaTypes but on **no codec registry**.
Applications import them directly:

```
wrap_bytes(*, src, dst, inner_type_name, inner_payload_dict,
           message_id, ack_required=False) -> bytes
unwrap_bytes(body: bytes) -> (GridworksHeader, inner_payload_dict)
```

`wrap_bytes` validates that `inner_payload_dict["TypeName"] ==
inner_type_name` and constructs the JSON envelope. `unwrap_bytes`
parses, validates the outer `TypeName == "gw"`, parses the header
against `GridworksHeader`, and enforces the
`MessageType == Payload.TypeName` invariant.

The inner payload remains a **dict** at this boundary. The application
decodes it to a typed value with its own `SemaCodec` afterwards (only
if needed — relays may forward without ever decoding). This is what
keeps the wrap/unwrap helpers free of any per-type registry, and lets
an application send/receive wrapped messages without ever holding the
private control-plane codec.

**Why a separate module, not a method on `SemaCodec`:** the wrap/unwrap
operation is structurally independent of the inner type — it does not
need to know what inner types exist. Hanging it off a Codec class
would falsely imply a registry dependency and would force applications
to share a codec just to send a `gw` envelope.

**Send-side usage** (one call):

```python
self.send(
    envelope=self.wrapped_envelope(
        type_name=inner.type_name,
        to_class=TransportClass.Scada,
    ),
    body=wrap_bytes(
        src=self.alias,
        dst=peer_alias,
        inner_type_name=inner.type_name,
        inner_payload_dict=self._codec.to_dict(inner),
        message_id=str(uuid.uuid4()),
        ack_required=True,
    ),
)
```

**Receive-side usage:**

```python
def process_message(self, *, envelope, body):
    if envelope.category == MessageCategory.GridworksWrapped:
        header, payload_dict = unwrap_bytes(body)
        inner = self._codec.from_dict(payload_dict)
        ...
```

### Open design question — should the envelope be universal?

As FIS lands we will want per-message identity (`GNodeInstanceId`) — and
possibly message signing — on (ideally) *every* message, for audit and
non-repudiation. That raises a structural fork:

- **(A) Universal envelope.** Wrap *every* message body in
  `GridworksHeader` + `Payload`, decoupling the envelope from the routing
  category and the transport path. Uniform, and it survives any hop —
  **but** every `rj`/`rjb` body stops being "a single JSON that *is* the
  sema type," gains overhead, and duplicates routing-key fields.
- **(B) Bare types + properties sidecar — current lean.** Keep `rj`/`rjb`
  bodies as **bare sema types** (the JSON *is* the type — valued for its
  clean simplicity), carry `GNodeInstanceId`/signing in AMQP
  `BasicProperties.headers` on the fabric ([`transport.md`](transport.md)
  §3.7), and keep the `gw` **body** envelope only for the cross-MQTT hop
  where properties don't survive (gwproactor/scada already publish `gw`).
  Two mechanisms, but each body stays as clean as it can be.

**Status: Open — not decided.** We are *not* sold on (A)'s universality;
the clean "JSON-is-the-type" property of bare `rj`/`rjb` messages is worth
preserving, so (B) is the working lean. Resolve when FIS is implemented and
the cross-system wire change can be versioned and coordinated with
gwproactor / gridworks-marketmaker. Whatever is chosen, any body field that
duplicates the routing key MUST stay consistent with it (the key is
authoritative).
