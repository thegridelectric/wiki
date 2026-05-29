# Sub-spec: Sema-validate init-JSON at the boundary

Status: Draft · Pass 1 · Updated 2026-05-28

> Sub-spec of [`primary.md`](primary.md). Boundary-validation fix:
> the `g.node.gt.json` file is loaded into the runtime at startup
> and Sema-validated as a real `GNodeGt`, with axiom enforcement.
> Plus a binding invariant: `GNodeGt.alias` MUST equal
> `settings.service_alias`. Both lift the boundary check up from
> the half-implementation in `actor_base.py` today.

## Principle

Every JSON file loaded into the runtime at startup crosses a trust
boundary — its contents come from disk (or env, or the network) and
the only thing standing between a typo / malformed provisioning /
drifted schema and a confusing mid-run crash is **boundary
validation**. Sema types exist exactly for this. Any init-JSON the
runtime depends on should be parsed *via the matching Sema type*,
not via raw `json.loads` + dict-key access.

Plus a corollary for files that hold the *same fact* as runtime
settings: cross-check that the two agree at boundary, fail at boot
if they don't.

## Concrete instance — `g.node.gt.json`

`ActorBase.__init__` does
`json.loads(settings.g_node_path.read_text())` and then
`g_node_data["Alias"]`, `g_node_data["GNodeId"]`,
`g_node_data["GNodeClass"]` (`actor_base.py:89-93`).

The full `GNodeGt` Sema type (`sema/definitions/types/g.node.gt/004.yaml`)
has **seven required fields** plus **five axioms**:

- Required: `GNodeId`, `Alias`, `BaseClass`, `GNodeClass`, `Status`,
  `TypeName`, `Version`
- Axiom 1: ClassConsistency (Physical: GNodeClass == BaseClass.value;
  Logical: GNodeClass not a non-Logical base.g.node.class value)
- Axiom 2: PhysicalGNodeLocations (PositionPointId required for
  non-Logical)
- Axiom 3: AliasTransitionConsistency (PrevAlias differs from Alias)
- Axiom 4: GNodeClassNamespacing (non-empty, no whitespace)
- Axiom 5: AliasSuffixSemantics (`.ta` ↔ TerminalAsset;
  `.scada` ↔ Scada)

None of these are enforced at boundary today. Failure modes
that get past `ActorBase` silently:

- Typo'd JSON key (`"alias"` instead of `"Alias"`) → KeyError mid-run
- `GNodeClass = "Scada"` with `Alias = "d1.journal"` (no `.scada`
  suffix) → ActorBase constructs; misalignment surfaces downstream
- Missing `BaseClass` / `Status` → not noticed
- Drifted file from an old schema version → not noticed

Plus the journalkeeper-on-base-0.4.0 case: hand-synthesized
`g_node.json` with three fields would **fail** real `GNodeGt`
validation (missing `BaseClass`, `Status`, `TypeName`, `Version`).
**That's the point** — if the boundary were Sema-validated, the
contradiction "I'm not a GNode but I'm presenting a fake
g.node.gt.json" would have been caught at construction time and
forced the `ServiceSettings` split (see
[`service-settings.md`](service-settings.md)) that's actually correct.

## Filename convention

Per `wiki/GridWorks_CLAUDE.md` "Sema-typed JSON files" — on-disk JSON
instances of a Sema type SHALL be named `<sema-type-name>.json` with
dots preserved. The file becomes **`g.node.gt.json`**, NOT
`g_node.json` (legacy half-snake) and NOT `g_node_gt.json` (Python
transformation on disk).

Per [`xdg-paths.md`](xdg-paths.md), the default location is
`~/.config/gridworks/<service-name>/g.node.gt.json`.

## Plan — implementation in `GridworksActor.__init__`

```python
class GridworksActor(Orchestrator):
    def __init__(
        self,
        *,
        settings: GNodeSettings,
        my_super_alias: LeftRightDot,
        my_time_coordinator_alias: LeftRightDot,
    ):
        super().__init__(
            settings=settings,
            my_super_alias=my_super_alias,
            my_time_coordinator_alias=my_time_coordinator_alias,
        )

        # Load + Sema-validate g.node.gt.json
        try:
            g_node_data = json.loads(settings.g_node_path.read_text())
        except FileNotFoundError as e:
            raise ValueError(
                f"GridworksActor requires {settings.g_node_path} to "
                f"exist; provision via gridworks-provisioning first"
            ) from e
        except json.JSONDecodeError as e:
            raise ValueError(
                f"{settings.g_node_path} is not valid JSON: {e}"
            ) from e

        try:
            g_node_gt = GwBaseSemaCodec().from_dict(
                g_node_data, mode="strict"
            )
        except Exception as e:
            raise ValueError(
                f"{settings.g_node_path} failed GNodeGt Sema "
                f"validation: {e}"
            ) from e

        if not isinstance(g_node_gt, GNodeGt):
            raise ValueError(
                f"{settings.g_node_path} is not a GNodeGt: "
                f"got {type(g_node_gt).__name__}"
            )

        # Binding invariant: provisioning artifact MUST agree with
        # runtime settings.
        if g_node_gt.alias != settings.service_alias:
            raise ValueError(
                f"Provisioning drift: GNodeGt.alias "
                f"{g_node_gt.alias!r} in {settings.g_node_path} != "
                f"settings.service_alias {settings.service_alias!r} "
                f"in runtime config"
            )

        self.g_node_id: str = g_node_gt.g_node_id
        self.g_node_class: str = g_node_gt.g_node_class
        self.transport_class: TransportClass = settings.transport_class
```

The Sema axioms (1-5) all fire during `from_dict(...)` so a
provisioning artifact with `Alias=d1.house.scada` but
`GNodeClass=Scada` written by mistake (real near-miss in field
provisioning) becomes a boot error rather than a runtime
surprise.

## Migration

Per the 2026-05-27 grill: **there are no production `g.node.gt.json`
files yet** in the GNodeGt-conforming sense. Existing
`/etc/gridworks/g_node.json` files (if any) are 3-field placeholders
that wouldn't pass validation anyway. So this validation is safe to
land alongside the settings split + XDG paths — no fleet of legacy
files to break.

Provisioning (see `wiki/gridworks-provisioning/executor/primary.md`)
is the producer of valid `g.node.gt.json` files. Wave-1 lands the
validator; provisioning lands the producer.

## Generalizing

The principle generalizes. Other init-JSON instances worth auditing
(out of scope for this design — flagging for future):

- `hardware-layout.json` (scada / proactor) — loaded at startup,
  drives actor topology, no Sema type that I could find. Probably
  should be one. Lives in proactor's domain; cross-cutting.
- Any `.env`-style file that goes through pydantic-settings already
  has typed validation, so those are fine — pydantic is the
  boundary enforcer there.

