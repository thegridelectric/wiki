# Sub-spec: Sema-validate init-JSON at the boundary

Status: Draft · Pass 1 · Updated 2026-05-27

> Sub-spec of [`primary.md`](primary.md). Boundary-validation fix:
> every JSON file loaded into the runtime at startup crosses a trust
> boundary, and Sema types exist exactly for this — but `ActorBase`
> reads `g_node.json` via raw `json.loads` + dict-key access.
> Companion sub-specs: [`service-settings.md`](service-settings.md)
> and [`xdg-paths.md`](xdg-paths.md).

## Principle

Every JSON file loaded into the runtime at startup crosses a trust
boundary — its contents come from disk (or env, or the network) and
the only thing standing between a typo / malformed provisioning /
drifted schema and a confusing mid-run crash is **boundary
validation**. Sema types exist exactly for this. Any init-JSON the
runtime depends on should be parsed *via the matching Sema type*,
not via raw `json.loads` + dict-key access.

## Concrete instance — `g_node.json`

`ActorBase.__init__` does
`json.loads(settings.g_node_path.read_text())` and then
`g_node_data["Alias"]`, `g_node_data["GNodeId"]`,
`g_node_data["GNodeClass"]` (`actor_base.py:89-93`). The full
`GNodeGt` Sema type (`sema/types/g_node_gt.py`) has eight fields plus
five axioms — including "Alias ends with `.scada` iff GNodeClass is
Scada," "GNodeClass is non-empty and whitespace-free," and "Physical
GNodes (non-Logical) must have a PositionPointId." None of these are
enforced at boundary today.

Failure modes that get past ActorBase silently:

- Typo'd JSON key (`"alias"` instead of `"Alias"`) → KeyError mid-run
  with no schema context.
- `GNodeClass = "Scada"` with `Alias = "d1.journal"` (no `.scada`
  suffix) → ActorBase happily constructs; the misalignment surfaces
  when something downstream cares.
- Missing `BaseClass` / `Status` (required in GNodeGt) → not noticed.
- Drifted file from an old schema version → not noticed.

The journalkeeper-on-base-0.4.0 refactor (this finding's source) used
a hand-synthesized `g_node.json` with exactly the three fields
ActorBase reads. That file would **fail** real `GNodeGt` validation
(missing `BaseClass`, `Status`, `TypeName`, `Version`). That's the
point: if the boundary were Sema-validated, the contradiction this
service hits — "I'm not a GNode but I'm presenting a fake
g_node.json" — would be caught at construction time and force the
`ServiceSettings` split (see [`service-settings.md`](service-settings.md))
that's actually correct.

## Plan

```python
# In ActorBase.__init__ (after service-settings split: only for GridworksActor):
from gwbase.sema import SemaCodec, GNodeGt

g_node_data = json.loads(settings.g_node_path.read_text())
sema_obj = SemaCodec().from_dict(g_node_data, mode="strict")
if not isinstance(sema_obj, GNodeGt):
    raise ValueError(
        f"g_node.json at {settings.g_node_path} is not a valid GNodeGt: "
        f"got {type(sema_obj).__name__}"
    )
self.alias = sema_obj.alias
self.g_node_id = sema_obj.g_node_id
self.g_node_class = sema_obj.g_node_class
```

## Generalizing

The principle generalizes. Other init-JSON instances worth auditing:

- `hardware-layout.json` (scada / proactor) — loaded at startup,
  drives actor topology, no Sema type that I could find. Probably
  should be one. (Cross-cutting with [`xdg-paths.md`](xdg-paths.md)
  / proactor `Paths`.)
- Any `.env`-style file that goes through pydantic-settings already
  has typed validation, so those are fine — pydantic is the boundary
  enforcer there.

