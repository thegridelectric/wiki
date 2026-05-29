# Support non-GNode actors in `gridworks-base`

Status: Draft · Pass 1 · Updated 2026-05-29

> Today `ActorBase` requires every consumer of `gridworks-base` to
> present a `g.node.gt`-shaped JSON file at a system-level path, even
> when the service isn't a GNode. This design refactors gwbase into a
> three-tier class hierarchy — `ActorBase` → `Orchestrator` →
> `GridworksActor` — so non-GNode rabbit+sema consumers
> (journalkeeper, ear's actor-side, future analytics consumers) can
> use the transport tier deliberately, and orchestration participants
> (Supervisor, TimeCoordinator) can ride the middle tier without
> claiming GNode identity.
>
> Plus interlocking sharpenings that land in the same PR: XDG path
> conventions, Sema-typed wire-grammar enforcement at the envelope
> layer, Sema-validated `g.node.gt.json` provisioning, and Wave-1
> logging prereqs.

## Motivation

`ActorBase` was designed to serve both GNode and non-GNode actors —
Supervisor has long ridden `ActorBase` without being a GNode. But
`ActorBase.__init__` reads `g_node.json` and stores `g_node_id` +
`g_node_class`, which are GNode-only state. The class hierarchy was
right; the implementation leaked.

The `gridworks-journalkeeper → base 0.4.0` refactor exposed the
friction. Journalkeeper consumes the broker and persists to Postgres
but is **not a GNode** — no GNode role on the grid, no heartbeat /
time-coordinator participation. To get `ActorBase.__init__` to run,
journalkeeper had to synthesize a fake `g_node.json` with three
fields.

Two GridWorks system services — Supervisor and TimeCoordinator — sit
in a similar place: they participate in the orchestration rhythm
(heartbeat + sim.timestep) but are not GNodes either. Neither is in
`base.g.node.class` or `gw.g.node.class`. They need a place between
"raw rabbit toolkit" and "GNode identity bundle."

## Three-tier inheritance

```python
class ActorBase(ABC):
    """Raw rabbit + sema toolkit. ServiceSettings. Wire-grammar.
    Used by: journalkeeper, ear actor-side, audit-tap consumers."""

class Orchestrator(ActorBase, ABC):
    """ActorBase + GridWorks orchestration rhythm: heartbeat handler,
    sim.timestep tracker, supervisor + time-coord aliases.
    ServiceSettings (NOT GNodeSettings — no GNode identity).
    Used by: Supervisor, TimeCoordinator."""

class GridworksActor(Orchestrator, ABC):
    """Orchestrator + GNode identity (g.node.gt.json loaded +
    Sema-validated; g_node_id, g_node_class, transport_class; FIS
    handshake decoration).
    GNodeSettings.
    Used by: SCADA, LTN, MarketMaker, WeatherForecastService, etc."""
```

### Why `Orchestrator` (not `ControlPlane`)

The actual control in GridWorks — dispatch, relay, hierarchical state
machines — lives at the GNode tier in subclasses like `Scada` / `Ltn`.
The middle tier doesn't do control; it does *orchestration* —
heartbeat ceremony + sim.timestep pulse. Supervisor and
TimeCoordinator are orchestrators of the system rhythm; SCADAs /
LTNs / etc. participate in that rhythm.

### Where each behavior lives

| Behavior | ActorBase | Orchestrator | GridworksActor |
|---|---|---|---|
| Rabbit connect / consume / publish | ✓ | (inherits) | (inherits) |
| Envelope parsing + dispatch hook | ✓ | (inherits) | (inherits) |
| `self.alias` / `self.instance_id` | ✓ | (inherits) | (inherits) |
| `self.logger` | ✓ | (inherits) | (inherits) |
| FIS handshake (slim `client_properties`) | ✓ | (inherits) | (overrides to decorate) |
| `_orchestration_codec = GwBaseSemaCodec()` | — | ✓ | (inherits) |
| `dispatch_message`: filter orchestration types → forward to `process_message` | — | ✓ | (inherits) |
| `on_supervisor_heartbeat`, `on_simulated_time` hooks | — | ✓ | (inherits) |
| `_handle_heartbeat`, `_handle_timestep` | — | ✓ | (inherits) |
| `send_heartbeat_response` | — | ✓ | (inherits) |
| `send_ready` | — | ✓ | (inherits) |
| `my_super_alias`, `my_time_coordinator_alias` | — | ✓ | (inherits) |
| `_sim_time_unix_s` state | — | ✓ | (inherits) |
| `g.node.gt.json` load + Sema-validate | — | — | ✓ |
| `self.g_node_id`, `self.g_node_class` | — | — | ✓ |
| `self.transport_class` (used to derive `_consume_exchange` etc.) | — | — | ✓ |
| FIS `client_properties` decoration with `g_node_id`+`g_node_class` | — | — | ✓ |

### Subclass slots

| Subclass | Extends | Settings | Source of identity |
|---|---|---|---|
| Journalkeeper (deferred) | `ActorBase` | `ServiceSettings` | env-set `service_alias` |
| ear actor-side (TBD) | `ActorBase` | `ServiceSettings` | env-set `service_alias` |
| Supervisor (extracted) | `Orchestrator` | `ServiceSettings` | env-set `service_alias` |
| TimeCoordinator (extracted) | `Orchestrator` | `ServiceSettings` | env-set `service_alias` |
| SCADA | `GridworksActor` | `GNodeSettings` | `g.node.gt.json` ↔ `service_alias` |
| LTN | `GridworksActor` | `GNodeSettings` | `g.node.gt.json` ↔ `service_alias` |
| MarketMaker | `GridworksActor` | `GNodeSettings` | `g.node.gt.json` ↔ `service_alias` |
| WeatherForecastService | `GridworksActor` | `GNodeSettings` | `g.node.gt.json` ↔ `service_alias` |

### Why three tiers and not two-with-mixin

1. The world has three categories (no-orchestration /
   orchestration-non-GNode / orchestration-GNode), and three classes
   mirror that 1:1.
2. Heartbeat + sim-time machinery is *stateful* (`_sim_time_unix_s`,
   `_my_super_alias`), and mixins-with-state are where Python's MRO
   surprises bite.
3. The flexibility of mixins (orchestration behavior attachable to
   any class) isn't used — everyone who needs orchestration also
   needs rabbit.
4. Refactoring three tiers to mixins later is mechanical if the need
   arises.

## Invariants this design holds

1. **`ActorBase` is the rabbit-transport + sema-toolkit tier.** No
   GNode identity. No orchestration participation. Wire grammar
   includes Sema-shaped strings (`LeftRightDot`) enforced via a
   local variant — the transport layer is sema-shape-aware but does
   not import the sema codec.

2. **`Orchestrator extends ActorBase`** adds the GridWorks
   orchestration rhythm: heartbeat handler, sim.timestep tracker,
   supervisor / time-coordinator aliases. Stateful. Lives between
   raw transport and GNode identity.

3. **`GridworksActor extends Orchestrator`** adds the GNode
   identity tier: loads + Sema-validates `g.node.gt.json` as
   `GNodeGt`; carries `g_node_id`, `g_node_class`, `transport_class`;
   FIS handshake client_properties.

4. **`ServiceSettings`** is the minimum to ride gwbase's
   rabbit+sema toolkit without being a GNode. `service_alias`
   (`LeftRightDot`-typed), `instance_id` (UUID4Str, auto per boot
   if absent), `service_name` (XDG path segment), `rabbit`,
   `log_level`, `log_rotate_bytes` + `log_rotate_count`.

5. **`GNodeSettings extends ServiceSettings`** with the GNode-only
   durable identity: `g_node_path` (defaults via XDG to
   `~/.config/gridworks/<service-name>/g.node.gt.json`),
   `transport_class`. Loads identity values from the file at
   construction.

6. **The binding is enforced.** `GridworksActor.__init__` asserts
   `GNodeGt.alias == settings.service_alias` — drift between the
   provisioning artifact and the runtime settings fails at boot.

7. **The XDG convention governs default file locations.** Config:
   `~/.config/gridworks/<service-name>/`. Data:
   `~/.local/share/gridworks/<service-name>/`. State (incl. logs):
   `~/.local/state/gridworks/<service-name>/`. No more
   `/etc/gridworks/g_node.json` as a hard default.

8. **`g.node.gt.json` is parsed AS a `GNodeGt`** via the Sema codec,
   with axiom enforcement — and only by `GridworksActor`. A non-GNode
   service never needs the file. Filename follows the sema-typed JSON
   convention (`GridWorks_CLAUDE.md` Wiki essentials).

9. **`ActorBase` exposes `self.logger`** — a Python `logging.Logger`
   writing easy-to-read human-format lines to the XDG state-home
   log path. The line format is **bijective with a future
   `observability.log-entry/000` Sema type** (designed in
   [`../../research/concerns/logging-for-observability.md`](../../research/concerns/logging-for-observability.md)).
   Per-actor `service_alias` + `instance_id` written in the file
   header (and `service_alias` on each line, for grep). Subclass
   code uses `self.logger.debug(...)` etc. normally. A future
   broker-forwarding handler can attach to this logger without code
   changes in the actor.

## Sub-specs

- [`service-settings.md`](service-settings.md) — `ServiceSettings`
  / `GNodeSettings` split with `service_alias`↔`GNodeGt.alias`
  invariant binding; `Orchestrator` and `GridworksActor` constructor
  bodies.
- [`xdg-paths.md`](xdg-paths.md) — XDG-convention defaults via a
  small inline helper (no shared package); config / data / state-home
  derivation.
- [`init-json-validation.md`](init-json-validation.md) — Sema-validate
  `g.node.gt.json` as `GNodeGt` at the boundary; filename per
  sema-typed convention.
- [`logging.md`](logging.md) — `ActorBase.logger` configured at
  construction; XDG state-home file destination; bijective
  human-format that maps 1:1 to a future
  `observability.log-entry/000` Sema type.

Open follow-on questions (logging that flows into fleet observability,
monitoring/alerting hooks, LLM sense-making integration) are captured
separately in
[`../../research/concerns/logging-for-observability.md`](../../research/concerns/logging-for-observability.md).
A subsequent design will land once that concern converges.

## What success looks like (Wave-1 PR)

- Journalkeeper (and ear's actor-side, future audit-tap consumers)
  inherit `ActorBase` cleanly with no fake GNode identity, against
  `ServiceSettings`.
- Supervisor + TimeCoordinator inherit `Orchestrator` (no
  `g.node.gt.json` requirement) — they extract to their own repos
  (`gridworks-supervisor` new; `gridworks-timecoordinator` existing)
  in parallel.
- New SCADA / LTN / MarketMaker provisioning lands config under
  `~/.config/gridworks/<service-name>/g.node.gt.json` without root.
- A typo or drifted `g.node.gt.json` fails at boot with a clear
  Sema-axiom error, not silently mid-run.
- Wire-grammar `LeftRightDot` enforcement at envelope-parse time
  catches malformed aliases before AMQP connect.
- Every actor (GNode or not) has a contextualized logger writing in
  the bijective format that a future broker-forwarding handler can
  consume without code changes in the actor.

## Release shape

This design ships as **gwbase 0.5.0** — a single PR landing all six
pieces:

  1. Wire-grammar typing (Task #7)
  2. Settings split + ActorBase identity cleanup
  3. Orchestrator middle tier
  4. Sema-validate `g.node.gt.json` at the GridworksActor boundary
  5. XDG-located defaults
  6. ActorBase.logger contextualized + bijective human format +
     XDG state-home

**Supervisor / TimeCoordinator extractions** to own repos
(`gridworks-supervisor` new; `gridworks-timecoordinator` existing)
run parallel to this PR, not inside it. As part of the extraction,
they switch their base class to `Orchestrator` and drop their
`g.node.gt.json` files.

**Journalkeeper migration** is deferred to a separate release that
combines the `ServiceSettings`-based identity cleanup with whatever
observability primitives emerge from
[`logging-for-observability`](../../research/concerns/logging-for-observability.md).

