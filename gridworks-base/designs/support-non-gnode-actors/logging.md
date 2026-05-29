# Sub-spec: `ActorBase.logger`

Status: Draft · Pass 1 · Updated 2026-05-29

> Sub-spec of [`primary.md`](primary.md). Adds a contextualized,
> structured Python `logging.Logger` to `ActorBase` at construction
> time, writing a bijective human-readable format to an
> XDG-state-home log file. The format is designed so that a future
> broker-forwarding handler can attach to the same logger without any
> actor-side code change.
>
> The property the design wants: **`self.logger.debug(...)` lights up
> the broker stream when verbosity is bumped, with zero changes in
> subclass code.** The broker-forwarding handler itself is downstream
> work — captured in
> [`../../research/concerns/logging-for-observability.md`](../../research/concerns/logging-for-observability.md).

## Symptom

Today gwbase actors get `LOGGER = logging.getLogger(__name__)` at
module level (e.g. `actor_base.py:43`), with no framework-side
configuration. Format and destination are left to whoever runs the
process. There's no `service_alias` / `instance_id` context on log
records, so when many actors run side-by-side, log-line attribution
is by-convention only.

Plus a deeper friction for the planned downstream observability
work: operator-or-LLM-triggered verbose-mode-on (per a future
`observability.verbosity-request`) wants to **forward** the actor's
debug-level log records to the broker for the window. With
module-level loggers, that wiring is per-actor and brittle.

## Proposed direction

`ActorBase.__init__` builds and attaches a logger on `self`:

```python
class ActorBase:
    def __init__(self, *, settings: ServiceSettings):
        self.settings = settings
        self.alias = settings.service_alias
        self.instance_id = settings.instance_id or str(uuid.uuid4())

        # Configure per-actor logger
        self.logger = _build_actor_logger(
            service_name=settings.service_name,
            service_alias=self.alias,
            instance_id=self.instance_id,
            log_level=settings.log_level,
            log_format=settings.log_format,
        )

        # ... rabbit plumbing follows
```

`_build_actor_logger(...)` is a small helper in
`gwbase/logging_setup.py`:

```python
def _build_actor_logger(
    *,
    service_name: str,
    service_alias: str,
    instance_id: str,
    log_level: str,
    log_format: Literal["json", "human"],
) -> logging.Logger:
    """Build a per-actor logger that:
      - is named `gwbase.actor.<service_alias>`
      - has a FileHandler writing to
        log_dir(service_name) / f"{service_alias}.log"
      - has a ContextFilter that injects service_alias and instance_id
        into every LogRecord
      - uses a JsonLinesFormatter when log_format == "json"
      - uses a HumanFormatter when log_format == "human"
      - is set to the configured log_level
    """
    paths.mkdirs(service_name)

    logger = logging.getLogger(f"gwbase.actor.{service_alias}")
    logger.setLevel(getattr(logging, log_level.upper()))

    file_handler = logging.FileHandler(
        paths.log_dir(service_name) / f"{service_alias}.log",
    )
    formatter = (
        _JsonLinesFormatter() if log_format == "json"
        else _HumanFormatter()
    )
    file_handler.setFormatter(formatter)
    file_handler.addFilter(_ContextFilter(service_alias, instance_id))
    logger.addHandler(file_handler)

    return logger
```

Where:

- **`_SemaBijectiveFormatter`** emits human-readable lines whose
  structure maps 1:1 onto a future `observability.log-entry/000`
  Sema type (designed in the
  [`logging-for-observability`](../../research/concerns/logging-for-observability.md)
  concern). The goal: easy to `tail -f` and visually grep, AND
  losslessly round-trippable to the Sema JSON form via documented
  parser. NO free-form prose; every visible slot has a Sema field
  it corresponds to.

  File header written at logger open:
  ```
  === gwbase log: alias=d1.example.svc instance=f47ac10b-58cc-4372-a567-0e02b2c3d479 started=2026-05-28T14:00:00.000Z ===
  ```

  Per-record format:
  ```
  <iso-ts> <LEVEL> <alias> > <message>[ <key=val>...]
  ```

  Examples:
  ```
  2026-05-28T14:25:46.001Z INFO  d1.example.svc > started consumer
  2026-05-28T14:25:46.123Z DEBUG d1.example.svc > processed batch n=42 dt_ms=18
  2026-05-28T14:25:47.001Z ERROR d1.example.svc > postgres write failed retry=3 last_error=connection_lost
    | Traceback (most recent call last):
    |   File "journal_actor.py", line 87, in _persist
    |   ...
    | RuntimeError: connection lost
  ```

  Bijection to `observability.log-entry/000`:
  | Format slot | Sema field |
  |---|---|
  | File header `alias=` | `Alias` |
  | File header `instance=` | `InstanceId` |
  | `<iso-ts>` | `TimestampMs` (ISO ↔ epoch_ms) |
  | `<LEVEL>` | `Level` |
  | `<alias>` (per-line) | `Alias` (redundant with header; written for grep-ability) |
  | `<message>` (up to first ` <kw>=` or EOL) | `Message` |
  | Trailing `key=val key=val` | `Extra` (dict) |
  | Following `  \| ...` continuation lines | `ExcInfo` |

  The downstream observability release will ship
  `gwbase log-to-sema <file>` and `gwbase sema-to-log` tools that
  round-trip the two representations losslessly.

- **`_ContextFilter`** is a `logging.Filter` subclass that adds
  `service_alias` and `instance_id` attributes to every LogRecord.
  The formatter reads them.

## Future broker-forwarding hook (sketch)

The downstream observability release adds a `BrokerLoggingHandler`
(designed in
[`../../research/concerns/logging-for-observability.md`](../../research/concerns/logging-for-observability.md)):

```python
class BrokerLoggingHandler(logging.Handler):
    """Wraps log records into observability.log-entry sema events
    and publishes them to the actor's broker connection. Rate-limited
    to prevent flooding. Attached to self.logger only when verbosity
    is in Detailed or Trace mode."""

    def __init__(self, actor: "Orchestrator"):
        super().__init__()
        self._actor = actor
        self._rate_limiter = TokenBucket(refill_per_s=100, capacity=200)

    def emit(self, record: logging.LogRecord) -> None:
        if not self._rate_limiter.try_consume():
            return
        event = ObservabilityLogEntry(
            service_alias=record.service_alias,
            instance_id=record.instance_id,
            level=record.levelname,
            message=record.getMessage(),
            timestamp_ms=int(record.created * 1000),
            ...
        )
        self._actor._send_observability(event)
```

When `observability.verbosity-request` is received and accepted (via
`Orchestrator.on_verbosity_request`, designed in the concern doc):

1. Bump `self.logger.level` down (e.g. INFO → DEBUG).
2. Attach `BrokerLoggingHandler(self)` to `self.logger`.
3. Schedule a `_revert_verbosity` callback at the requested
   `duration_seconds`.
4. On revert: detach the handler; restore original level.

**Subclass code does nothing.** `self.logger.debug("...")` calls
already routing to the local file are now ALSO routed to the broker
for the window. This is the load-bearing property this sub-spec's
substrate (file destination, format, context filter) is designed to
preserve.

## Cross-cutting concerns

- **Log rotation.** Standard `logging.handlers.RotatingFileHandler`
  vs cloud-side `logrotate`. The MVP uses the OS's logrotate
  (cloud-side hosts) and a rotating handler on the SCADA Pi
  (constrained disk). Open question on the SCADA side: rotation
  policy (size, count, retention).
- **Exception logging.** `_JsonLinesFormatter` emits `exc_info` as a
  structured field when present. Subclasses use
  `logger.exception(...)` normally.
- **Performance budget.** A FileHandler write per log line is fine
  at the levels we'd normally use (INFO+). At Trace, on a busy
  actor, the write rate can be substantial — the future broker
  handler will be rate-limited to protect the broker, but the
  local-file write rate is unbounded. Acceptable for windowed
  Trace; not for steady-state Trace. Document the constraint.

## Cross-references

- [`xdg-paths.md`](xdg-paths.md) — where `log_dir(service_name)`
  is defined.
- [`service-settings.md`](service-settings.md) — `log_level` and
  `log_format` fields on `ServiceSettings`.
- [`../../research/concerns/logging-for-observability.md`](../../research/concerns/logging-for-observability.md)
  — open architectural concern capturing the downstream
  observability work this logger is designed to flow into
  (`observability.log-entry/000` sema type, BrokerLoggingHandler,
  verbosity-request integration).

