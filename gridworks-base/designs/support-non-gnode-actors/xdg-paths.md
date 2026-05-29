# Sub-spec: adopt the XDG path convention

Status: Draft · Pass 1 · Updated 2026-05-28

> Sub-spec of [`primary.md`](primary.md). Default file locations move
> from `/etc/gridworks/...` to XDG locations under
> `~/.config/gridworks/<service-name>/` (config),
> `~/.local/share/gridworks/<service-name>/` (data), and
> `~/.local/state/gridworks/<service-name>/` (state — incl. logs).
> Implemented via a **small inline helper** in `gridworks-base`, not
> a shared package — proactor keeps its own `Paths` class.

## Symptom

`GNodeSettings.g_node_path` defaults to
`/etc/gridworks/g_node.json` (`config/g_node_settings.py:21`).
System-level path, requires root to provision, doesn't follow the
XDG Base Directory spec, and doesn't compose with per-service config
directories. Plus the filename is half-snake-legacy (`g_node.json`)
rather than sema-typed (`g.node.gt.json`) per the
`GridWorks_CLAUDE.md` "Sema-typed JSON files" convention.

Proactor solved the XDG convention question with its `Paths` class
(`gwproactor/config/paths.py:70-185`) — typical layout:

- `base = "gridworks"`, `name = "scada"`
- `config_dir = xdg.xdg_config_home() / base / name` → typically
  `~/.config/gridworks/scada/`
- `data_dir`, `state_home`, `log_dir`, `event_dir`, `certs_dir`,
  cascade from there.

But proactor's full class is more than gwbase needs — TLS sub-paths,
event_dir, hardware_layout colocation, model-validators chaining TLS
into MQTT clients. Per the 2026-05-27 grill, **gwbase inlines a small
helper** rather than depending on a shared package (P2 over P1).

## Proposed direction — small inline helper

```python
# gwbase/config/paths.py
import xdg

BASE = "gridworks"


def config_dir(service_name: str) -> Path:
    """e.g. ~/.config/gridworks/<service_name>/"""
    return xdg.xdg_config_home() / BASE / service_name


def data_dir(service_name: str) -> Path:
    """e.g. ~/.local/share/gridworks/<service_name>/"""
    return xdg.xdg_data_home() / BASE / service_name


def state_dir(service_name: str) -> Path:
    """e.g. ~/.local/state/gridworks/<service_name>/"""
    return xdg.xdg_state_home() / BASE / service_name


def log_dir(service_name: str) -> Path:
    """e.g. ~/.local/state/gridworks/<service_name>/log/"""
    return state_dir(service_name) / "log"


def g_node_gt_path(service_name: str) -> Path:
    """e.g. ~/.config/gridworks/<service_name>/g.node.gt.json"""
    return config_dir(service_name) / "g.node.gt.json"


def mkdirs(service_name: str) -> None:
    """Create config/data/state/log dirs for this service if they
    don't exist. Safe to call repeatedly."""
    for d in (
        config_dir(service_name),
        data_dir(service_name),
        state_dir(service_name),
        log_dir(service_name),
    ):
        d.mkdir(parents=True, exist_ok=True)
```

That's it. Five functions + `mkdirs`. No class hierarchy, no TLS sub-paths
(TLS comes later when FIS-mTLS lands; add then), no event_dir (that's
a proactor concept), no hardware_layout colocation (scada-only,
proactor's concern).

## Integration with `ServiceSettings` / `GNodeSettings`

`ServiceSettings.service_name` becomes the input to all XDG-helper
calls:

```python
class ServiceSettings(BaseSettings):
    service_name: str = "gridworks"  # XDG path segment
    ...


class GNodeSettings(ServiceSettings):
    g_node_path: Path = Field(
        default_factory=lambda data: g_node_gt_path(data["service_name"])
    )
    transport_class: TransportClass = TransportClass.Scada
```

And the logging hookup (see [`logging.md`](logging.md)) uses
`log_dir(settings.service_name)` for file destinations.

## What proactor's `Paths` has that gwbase deliberately omits

| Proactor field | Why gwbase omits |
|---|---|
| `certs_dir` + `TLSPaths` | gwbase is plaintext-AMQP today. FIS-mTLS lands via FIS-side changes; revisit at that point. |
| `event_dir` | Proactor's event-persistence pattern; gwbase's EAR is the analog at a different layer. |
| `hardware_layout` field | SCADA-only; lives in proactor's domain. |
| `duplicate()` for re-deriving with a new `name` | Not needed at gwbase level. If a use case surfaces, add then. |
| Model-validator chaining TLS paths into MQTT clients | No MQTT or TLS in scope at gwbase. |
| Pydantic cascade across 9 dir fields | Five functions is enough; the cascade is implicit (state → log; config → g_node_gt_path). |
