# log-sema round-trip tools

Status: Draft · Pass 0 · Updated 2026-05-30

> Two CLI tools shipped with gwbase that round-trip between the
> bijective human-readable log format (per
> [`../executor/actors.md`](../executor/actors.md) "Settings, file locations, and logging")
> and `observability.log-entry/000` Sema events: `gwbase log-to-sema`
> parses the human format into Sema events; `gwbase sema-to-log`
> goes the reverse. Lossless by design — the human format was
> designed for exactly this round-trip.

## Why both tools

- **`log-to-sema`** is the load-bearing one. Use cases:
  - The future broker-forwarding handler
    ([`logging-for-observability`](../explorations/logging-for-observability.md))
    publishes one Sema event per log record — internally it calls
    the same parser
  - Ops imports a captured `.log` file into the analytics-broker
    event stream for backfill / replay
  - Test fixtures: load a recorded log, re-emit as events to
    exercise an alerter or consumer
- **`sema-to-log`** is the symmetry: take an
  `observability.log-entry/000` event stream (from the broker, from
  postgres, from a captured fixture) and render it as a human-format
  log file for `tail -f`-style inspection. Less heavily used; ships
  for completeness and audit symmetry.

## CLI surface

```
gwbase log-to-sema <file> [--out -|<file>]
gwbase sema-to-log  <file> [--out -|<file>]
```

- Default input source is a positional file path
- `--out -` writes to stdout (default); `--out <file>` to a file
- Input format is auto-detected by the leading line (file header
  for human format; JSON for sema events)
- Streaming: both tools process line-by-line; safe to pipe through
  unix tools without buffering the whole file

Both subcommands sit under the existing `gwbase` CLI namespace.

## Bijection contract

The exact field mapping lives in
[`../explorations/logging-for-observability.md`](../explorations/logging-for-observability.md)
("Bijection to `observability.log-entry/000`"). Both tools MUST
satisfy:

```
sema-to-log(log-to-sema(human_format_file)) == human_format_file
log-to-sema(sema-to-log(sema_event_stream))  == sema_event_stream
```

CI test asserts both directions on a fixture corpus.

## Error handling

- **Malformed line in human-format input**: emit a structured
  parse-error event (`observability.log-entry` with `Level=Error`
  and a `parse_error` extra field) AND continue. The malformed
  line is included verbatim in the parse-error event's `Message`.
- **Malformed JSON in sema input**: same shape — emit a
  parse-error log line in the output AND continue.
- **Unknown Sema type in sema input**: emit a degraded line
  noting the unknown type; continue.
- Tools never raise on input data; only on filesystem / IO
  errors.

## Versioning

- The bijection is keyed to `observability.log-entry/000`. When
  that Sema type bumps to `/001`, `log-to-sema` accepts both
  versions (auto-upgrade `000` → `001` per the Sema codec's
  auto-upgrade pattern). `sema-to-log` emits whichever version the
  input declares.
- The human-format file header includes the format version
  (currently implicit `gwbase log` v1). Future format revisions
  bump it; both tools support the last N versions.

## Out of scope

- Not a log aggregator; not a forwarder. Just round-trip parsers
  with a CLI surface. The broker-forwarding handler in gwbase
  Wave-2 uses the SAME parser internally but is its own component.
- Not a query / filter tool. Pipe through `jq` / `grep` / `awk`
  for slicing.

## Open

- **Package boundary** — does the parser live in
  `gwbase/observability/log_sema_codec.py` (importable separately
  from the CLI) or only in the CLI module? Probably separate
  module — the broker-forwarding handler needs it programmatically.
- **Streaming sema format** — JSON-lines (one event per line) is
  the obvious choice; confirm during implementation.
- **Trace-level performance** — at sustained high log volume,
  parser overhead matters. Likely fine; profile if it bites.
- **stdin input** — `gwbase log-to-sema - --out -` (read from
  stdin) might be a nice shell pattern. Add if requested.

## Cross-references

- [`../executor/actors.md`](../executor/actors.md) "Settings, file locations, and logging"
  — the bijective format this tool round-trips
- [`../explorations/logging-for-observability.md`](../explorations/logging-for-observability.md)
  — the v-next concern that names these tools in its shipping list
- `../../observability/designs/consolidate-from-infra-scada-jk.md`
  — the observability design where the broker-forwarding handler
  (which uses this codec) lands
