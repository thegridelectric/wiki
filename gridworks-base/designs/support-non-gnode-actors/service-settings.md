# Sub-spec: `ServiceSettings` / `GNodeSettings` split

Status: Draft · Pass 1 · Updated 2026-05-28

> Sub-spec of [`primary.md`](primary.md). Identity / settings split
> for `ActorBase` so non-GNode rabbit+sema consumers don't carry
> GNode identity. Tightly coupled with
> [`primary.md`](primary.md) "Three-tier inheritance" (the matching
> class hierarchy split) and
> [`init-json-validation.md`](init-json-validation.md) (the binding
> invariant validation).

## Symptom

`ActorBase.__init__` (`actor_base.py:89-93`) reads three fields
(`Alias`, `GNodeId`, `GNodeClass`) from `settings.g_node_path` on
disk and stores them as `self.alias` / `self.g_node_id` /
`self.g_node_class`. `GNodeSettings.g_node_path` defaults to
`/etc/gridworks/g_node.json` (`config/g_node_settings.py:21`).

A service that isn't a GNode (journalkeeper, ear's actor-side,
future analytics consumers) still has to provide a
`g.node.gt`-shaped file just to construct the actor — and the
on-disk JSON is **fake**: ActorBase reads three strings and never
validates the file as a real `GNodeGt`.

Per the 2026-05-27 grill, the Sema tightening of `Logical` (sema
`ced7cec`) clarifies that **only SCADA + forecasting services are
Logical GNodes** — so journalkeeper et al. cannot satisfy the
GNode shape even in principle. The fix isn't to make the fake file
real; it's to stop requiring it.

## Proposed direction — `ServiceSettings`

Split the settings shape so identity scope matches base-class scope.

```python
# gwbase/config/service_settings.py
from pydantic_settings import BaseSettings, SettingsConfigDict

from gwbase.transport_format import LeftRightDot, UUID4Str
from gwbase.config.rabbit_settings import RabbitBrokerClient


class ServiceSettings(BaseSettings):
    """Minimum to ride gwbase's rabbit + sema toolkit without
    being a GNode. Used by ActorBase directly (journalkeeper, ear
    actor-side, future audit-tap consumers).
    """

    rabbit: RabbitBrokerClient = RabbitBrokerClient()
    service_alias: LeftRightDot                     # MUST be LeftRightDot
    instance_id: UUID4Str | None = None             # auto-uuid per boot if None
    service_name: str = "gridworks"                 # XDG path segment
    log_level: str = "INFO"
    log_rotate_bytes: int = 10_000_000              # 10MB per file
    log_rotate_count: int = 5                       # 5 backup files

    model_config = SettingsConfigDict(
        env_prefix="GWBASE_", env_nested_delimiter="__", extra="ignore",
    )


# gwbase/config/g_node_settings.py
class GNodeSettings(ServiceSettings):
    """ServiceSettings + GNode-only durable identity (loaded from
    g.node.gt.json on disk). Used by GridworksActor.
    """

    g_node_path: Path = Field(
        default_factory=lambda data: (
            xdg_config_home() / "gridworks" / data["service_name"]
            / "g.node.gt.json"
        )
    )
    transport_class: TransportClass = TransportClass.Scada

    model_config = SettingsConfigDict(
        env_prefix="GNODE_", env_nested_delimiter="__", extra="ignore",
    )
```

Notes on the field choices:

- **`service_alias: LeftRightDot`** — typed at the wire-grammar
  layer (see [`../init-json-validation.md`](init-json-validation.md)
  and the wire-format spec). 
- **`instance_id: UUID4Str | None`** — auto-uuid per boot when not
  provided (matches existing `g_node_instance_id` behavior at
  `actor_base.py:96`).
- **`service_name: str`** — distinct from `service_alias`. It's the
  path segment for XDG defaults (`~/.config/gridworks/<service_name>/`).
  Journalkeeper: `"journalkeeper"`. SCADA: `"scada"`. LTN: `"ltn"`.
  Not Sema-typed; just a directory name.
- **`log_rotate_bytes` / `log_rotate_count`** — new in Wave-1; size-based
  rotation defaults sensible for the SCADA Pi (10MB × 5 = 50MB cap).
  Cloud-side services can override or disable.
- Log *format* is fixed to a bijective human-readable shape (see
  [`logging.md`](logging.md)) — easy to `tail -f`, lossless
  round-trip to `observability.log-entry/000` Sema events via the
  future `gwbase log-to-sema` tool (designed in the
  [`logging-for-observability`](../../research/concerns/logging-for-observability.md)
  concern).

## ActorBase init

```python
class ActorBase(ABC):
    def __init__(self, *, settings: ServiceSettings):
        self.settings: ServiceSettings = settings
        self.alias: str = settings.service_alias
        self.instance_id: str = settings.instance_id or str(uuid.uuid4())

        # No g_node_id, no g_node_class, no TransportClass-derived
        # exchange names, no g_node.json read. Those move up.

        # self.logger configured here — see logging.md
        self.logger = _make_actor_logger(settings, self.alias, self.instance_id)

        # Rabbit connection plumbing follows...
```

## GridworksActor init (the binding)

`GridworksActor.__init__` enforces the invariant — `GNodeGt.alias`
loaded from disk MUST equal `settings.service_alias`. Mismatch is a
provisioning drift error, caught at boot.

```python
class GridworksActor(Orchestrator):
    def __init__(self, *, settings: GNodeSettings, ...):
        super().__init__(settings=settings, ...)

        g_node_data = json.loads(settings.g_node_path.read_text())
        g_node_gt = GwBaseSemaCodec().from_dict(g_node_data, mode="strict")
        if not isinstance(g_node_gt, GNodeGt):
            raise ValueError(
                f"{settings.g_node_path} is not a valid GNodeGt: "
                f"got {type(g_node_gt).__name__}"
            )

        # Binding: alias from provisioning artifact MUST match
        # alias from runtime settings.
        if g_node_gt.alias != settings.service_alias:
            raise ValueError(
                f"GNodeGt.alias {g_node_gt.alias!r} != "
                f"settings.service_alias {settings.service_alias!r} — "
                f"provisioning drift between {settings.g_node_path} and "
                f"runtime settings"
            )

        self.g_node_id: str = g_node_gt.g_node_id
        self.g_node_class: str = g_node_gt.g_node_class
        self.transport_class: TransportClass = settings.transport_class
```

Aliasing properties on `GridworksActor` keep existing callers
working:

```python
    @property
    def g_node_alias(self) -> str:
        return self.alias

    @property
    def g_node_instance_id(self) -> str:
        return self.instance_id
```

So `send_ready(...)` at `gridworks_actor.py:155-172` (uses
`self.alias`, `self.g_node_instance_id`) keeps compiling unchanged.

## Connection handshake (`client_properties`)

Every connection sends:

- `ServiceAlias` — LeftRightDot identity (always)
- `ServiceInstanceId` — ephemeral UUID, fresh per boot (always)
- `GNodeClass` — present **iff** this connection is a GNode

The presence/absence of `GNodeClass` is what tells FIS whether
to treat the principal as a GNode (single-writer per `GNodeId`,
cross-checked against the GNode registry) or as a service (static
permission grant). See
[`../../../../gridworks-fleet-index-service/research/concerns/principal-model.md`](../../../../gridworks-fleet-index-service/research/concerns/principal-model.md)
for the FIS-side design.

```python
# in ActorBase (any rabbit+sema actor)
params.client_properties = {
    "ServiceAlias": self.alias,             # LeftRightDot
    "ServiceInstanceId": self.instance_id,  # ephemeral; new every boot
}
```

```python
# in GridworksActor (add GNodeClass marker)
def _decorate_client_properties(self, base: dict) -> dict:
    return {**base, "GNodeClass": self.g_node_class}
```

mTLS authenticates the durable identity (cert subject); the
handshake carries the ephemeral instance identifier for FIS to
authorize against (per FIS Invariant #3).

## Source-of-truth model

- **`ServiceSettings.service_alias` is the runtime source.** Set via
  env (`GWBASE_SERVICE_ALIAS=...`) or config file.
- **`g.node.gt.json` is the durable provisioning artifact.** Must
  AGREE with the runtime — disagreement is a startup error.
- For non-GNode services: there is no `g.node.gt.json` — the runtime
  alias is unambiguously the source.

## Caller migration

For services that subclassed `ActorBase` while passing a
`GNodeSettings`: keeps working (covariant — `GNodeSettings extends
ServiceSettings`). One-line type-hint change to `settings:
ServiceSettings` when the service genuinely is non-GNode.

Journalkeeper migration (deferred — same release that picks up the
observability primitives from
[`logging-for-observability`](../../research/concerns/logging-for-observability.md)):

```python
# Before (forced to fake g_node.json)
class JournalkeeperActor(ActorBase):
    def __init__(self, settings: GNodeSettings):   # fake!
        super().__init__(settings=settings)

# After
class JournalkeeperActor(ActorBase):
    def __init__(self, settings: ServiceSettings):
        super().__init__(settings=settings)
        # plus observability primitives from the downstream concern
```
