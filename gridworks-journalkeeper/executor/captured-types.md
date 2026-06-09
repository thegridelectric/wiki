# gjk captured types — coverage matrix

Status: Draft · Pass 0 · Updated 2026-06-09

> Part-II (contingent) companion to [`primary.md`](primary.md): the concrete
> set of message types gjk binds + persists today, how each is handled, and
> which versions it understands. **This drifts** — the authoritative list is
> generated, not this doc. Regenerate before trusting:
> - **bind/persist set** = `SemaMessagePersistor.all_known_message_types()`
>   (`src/gjk/sema_message_persistor.py`);
> - **decodable vocabulary** = `gjk.sema.codec.get_current_types()` (the
>   restricted snapshot under `src/gjk/sema/`);
> - **per-version handling** = the custom persistors' `persist_vNNN` methods.
> This table is a dated snapshot (2026-06-09) for orientation.

## The version insight

**Custom persistors are version-aware; the default path is version-agnostic.**
A custom persistor exposes one `persist_v<NNN>` per version it handles; if a
message arrives at a version with no matching method, dispatch falls back to
the default path (store payload as jsonb), which branches on nothing. So
"which versions gjk understands" is two questions:

- **Decode (Gate 3):** every version present in the Sema snapshot decodes.
- **Custom handling (Gate 4):** only the versions a custom persistor names get
  their richer treatment (e.g. fanning into `readings`); other versions of the
  same type still persist via the default path.

## Bound + persisted (the capture set)

`all_known_message_types()`, 2026-06-09 — what gjk binds (`#.<type>`) and
writes:

| `message_type_name` | persistor | versions (custom) | id source | created_at source |
|---|---|---|---|---|
| `report.event` | custom | v002, v003 | `message_id` | `time_created_ms` |
| `layout.lite` | custom | v007–v013 | `message_id` | `message_created_ms` |
| `flo.params.house0` | custom | v007 | `default_message_id` | `params_generated_s` |
| `weather.forecast` | custom | v000 | `default_message_id` | `forecast_created_s` |
| `report` | default | (version-agnostic) | `id` | `message_created_ms` |
| `glitch` | default | — | `default_message_id` | `created_ms` |
| `gridworks.event.problem` | default | — | `message_id` | `time_created_ms` |
| `energy.instruction` | default | — | `default_message_id` | `send_time_ms` |
| `scada.params` | default | — | `message_id` | `unix_time_ms` |
| `heating.forecast` | default | — | `default_message_id` | `forecast_created_s` |
| `ticklist.reed.report` | default | — | `default_message_id` | `scada_received_unix_ms` |
| `ticklist.hall.report` | default | — | `default_message_id` | `scada_received_unix_ms` |
| `latest.price` | default | — | `default_message_id` | persisted_at |
| `power.watts` | default | — | `default_message_id` | persisted_at |

Notes:
- **custom** types fan beyond `messages`: `report.event` → `readings`,
  `layout.lite` → `reading_channels`.
- A `default`-path type with no natural id/created_at field uses
  `default_message_id(from_alias, type_name, time_received)` and `persisted_at`
  for the timestamp (Invariant 5).
- `report` carries an "obsolete message type" note in code — kept for backfill.

## Decodable but NOT persisted

In the snapshot vocabulary (Gate 3 would decode them) but **not** in the
capture set (not bound) — so they never persist:

- **`atn.bid`** — deliberately omitted ("until bid works in SEMA"); `atn.bid`
  is frozen/decodable, new paths use `ltn.bid`.
- Plus the broader snapshot vocabulary (≈39 types as of 2026-06-09:
  `channel.readings`, `data.channel.gt`, `machine.states`,
  `snapshot.spaceheat`, … — see `get_current_types()`) that exists to support
  decoding/upgrades but isn't on the bind list.

## Wanted but not captured (gaps)

- **Degraded** — real Sema types absent from the snapshot, so skipped at Gate
  3: e.g. `gridworks.ack`, `slow.contract.heartbeat`. A snapshot regen would
  let gjk decode them *if* we choose to capture them.
- **Route-rejected** — dropped at Gate 2 by the gwbase routing bug (short-form
  class tokens): `s.*`, `ws.weather`, `broadcast.*` incl. `glitch`. `glitch`
  *is* in the capture set but never arrives intact. Tracked by the
  gridworks-base design `must-accept-current-ltn-messages`.

## Maintenance

This set grows via the snapshot regen + `all_known_message_types()` edits — see
the integrate design (`integrate-gwbase-sema-updates`) for the regen, and
`primary.md` Open questions for the scope decision that drives what belongs
here.
