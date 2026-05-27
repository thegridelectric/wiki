# Sub-spec: adopt the XDG path convention

Status: Draft · Pass 1 · Updated 2026-05-27

> Sub-spec of [`primary.md`](primary.md). Default file locations move
> from `/etc/gridworks/...` to `~/.config/gridworks/<service>/...`
> (XDG). We want the **convention**, not proactor's full `Paths`
> abstraction (proactor's class has more indirection than is needed
> here). Companion sub-specs:
> [`service-settings.md`](service-settings.md) and
> [`init-json-validation.md`](init-json-validation.md).

## Symptom

`GNodeSettings.g_node_path` defaults to
`/etc/gridworks/g_node.json` (`config/g_node_settings.py:21`).
System-level path, requires root to provision, doesn't follow the
XDG Base Directory spec, and doesn't compose with per-service config
directories.

Proactor solved the convention question with its `Paths` class
(`gwproactor/config/paths.py:70-185`) — typical layout:

- `base = "gridworks"`, `name = "scada"`
- `config_dir = xdg.xdg_config_home() / base / name` → typically
  `~/.config/gridworks/scada/`
- `data_dir`, `state_home`, `log_dir`, `event_dir`, `certs_dir`,
  cascade from there.

The proactor `Paths` class adds more indirection than gridworks-base
needs (it composes config_home / data_home / state_home / etc. with
per-service offsets and bundles test-fixture overrides). gridworks-base
should adopt the **XDG convention** — `~/.config/gridworks/<service>/`
for config, `~/.local/share/gridworks/<service>/` for data, etc. —
without necessarily copying the full class.

## Proposed direction

Use the `xdg` package directly in `GNodeSettings` / `ServiceSettings`
(see [`service-settings.md`](service-settings.md)) to compute
defaults:

- `GNodeSettings.g_node_path` default becomes
  `xdg.xdg_config_home() / "gridworks" / <service> / "g_node.json"` —
  under `~/.config/gridworks/<service>/g_node.json` instead of
  `/etc/gridworks/g_node.json`.
- `ServiceSettings` (see [`service-settings.md`](service-settings.md))
  gets a small helper (e.g. a `service_name: str` field + a couple
  of `Path` properties / pydantic validators that resolve XDG roots)
  — enough to land config / data / state in the right place, but no
  full `Paths` abstraction unless one earns its keep later.
- `proactor` keeps its own `Paths` for now; we don't need a single
  shared class to share a convention. If proactor and base
  eventually converge, that's a later refactor.

## Open

- **How small can the gridworks-base helper be?** Two functions
  (`config_dir(service)`, `data_dir(service)`) might suffice; we can
  grow it only when an actual second use surfaces.
- **Migration of existing `/etc/gridworks/g_node.json` deployments.**
  Either ship a fall-back (read XDG first, then `/etc/`), or
  document a one-time `mv` for operators. Pick when we land the
  change.

## Together with the sibling sub-specs

```python
# Today (broken for non-GNodes, system-path for everyone)
class GNodeSettings(BaseSettings):
    rabbit: RabbitBrokerClient = ...
    g_node_path: Path = Path("/etc/gridworks/g_node.json")
    transport_class: TransportClass = TransportClass.Scada
    log_level: str = "INFO"

# Proposed (non-GNode-friendly + XDG-aligned)
class ServiceSettings(BaseSettings):
    rabbit: RabbitBrokerClient = ...
    service_name: str = "gridworks"  # used for XDG offsets
    alias: str
    log_level: str = "INFO"
    # config_dir = xdg.xdg_config_home() / "gridworks" / service_name
    # data_dir   = xdg.xdg_data_home()   / "gridworks" / service_name

class GNodeSettings(ServiceSettings):
    g_node_path: Path = ""  # validator: config_dir / "g_node.json"
    transport_class: TransportClass = TransportClass.Scada
```

ActorBase consumes `ServiceSettings`; GridworksActor consumes
`GNodeSettings`. Journalkeeper (and ear, future consumers) inherits
`ServiceSettings` cleanly with no fake GNode identity. No full
`Paths` class is introduced — just direct `xdg` use.
