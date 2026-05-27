# Sub-spec: `ServiceSettings` / `GNodeSettings` split

Status: Draft · Pass 1 · Updated 2026-05-27

> Sub-spec of [`primary.md`](primary.md). Identity/settings split for
> `ActorBase` so non-GNode actors don't carry GNode identity.
> Companion sub-specs: [`xdg-paths.md`](xdg-paths.md) and
> [`init-json-validation.md`](init-json-validation.md).

## Symptom

`ActorBase.__init__` reads three fields (`Alias`, `GNodeId`,
`GNodeClass`) from `settings.g_node_path` on disk
(`actor_base.py:89-93`) and stores them as `self.alias` /
`self.g_node_id` / `self.g_node_class`. `GNodeSettings.g_node_path`
defaults to `/etc/gridworks/g_node.json`
(`config/g_node_settings.py:21`).

A service that isn't a GNode (e.g. journalkeeper, ear, future
analytics consumers) still has to provide a `g.node.gt`-shaped file
just to construct the actor — and the on-disk JSON is **fake**:
ActorBase reads three strings and never validates the file as a real
`GNodeGt` (the full `GNodeGt` Sema type at `sema/types/g_node_gt.py`
has eight fields + five axioms, none of which ActorBase touches).
Journalkeeper had to synthesize
`{"Alias": "d1.journal.dev.bright-frost", "GNodeId": "00000…0001",
"GNodeClass": "journalkeeper"}` to get the constructor to run.

This is two problems wearing one hat:

- (a) the *concept* "every actor is a GNode" is wrong;
- (b) even if it were right, the file isn't serving its stated
  purpose (the docstring at `actor_base.py:86` calls it "durable
  GNode identity provisioned on disk as a g.node.gt JSON," but
  ActorBase doesn't use the GNode-ness — just three opaque strings).

## Proposed direction — `ServiceSettings`

Split the settings shape so identity scope matches base-class scope.

```python
# ServiceSettings: minimum to be an actor on the broker
class ServiceSettings(BaseSettings):
    rabbit: RabbitBrokerClient = RabbitBrokerClient()
    alias: str                  # service identity (e.g. "journalkeeper-bright-frost")
    instance_id: str | None = None  # auto-uuid per boot if None
    log_level: str = "INFO"

# GNodeSettings: extends ServiceSettings with GNode-only durable identity
class GNodeSettings(ServiceSettings):
    g_node_path: Path = Path("/etc/gridworks/g_node.json")  # to be XDG'd; see xdg-paths.md
    transport_class: TransportClass = TransportClass.Scada
    # alias/g_node_id/g_node_class still loaded from g_node_path on construction
```

Then:

- `ActorBase` takes `ServiceSettings`; reads `self.alias` from
  `settings.alias` directly (no file). Drops `self.g_node_id` and
  `self.g_node_class` — those are GNode-only concepts.
- `GridworksActor` takes `GNodeSettings`; loads the on-disk
  `g.node.gt` and asserts the fields. `self.g_node_id` and
  `self.g_node_class` live there.
- Existing code that subclassed `ActorBase` while passing a
  `GNodeSettings` keeps working (covariant), so this is additive.
- Caller migration is one line per subclass: change the type hint on
  `settings` if the service is non-GNode.

## Notes — needs more thought

- The FIS handshake sends `client_properties` derived from
  `g_node_id` / `g_node_class`. Does FIS care if those are absent
  for a non-GNode service, or do we want a separate non-GNode
  handshake?
- `queue_name = self.alias + adder` (`actor_base.py:103-104`) still
  works for any alias; no change needed.
- `TransportClass` belongs on `GNodeSettings`, not `ServiceSettings`
  — a non-GNode service doesn't have a TransportClass at all (it
  isn't one of the listed GNode roles).

## Alternatives considered and rejected

- **Make `g_node_path: Path | None`.** Solves the file requirement
  but not the conceptual lie (the GNodeId/GNodeClass storage on
  every actor remains as a half-populated artifact for non-GNode
  actors).
- **Read identity from env vars only, no file.** Loses the
  "out-of-band durable provisioning" property that the file form
  gives prod ops for GNodes. Worth keeping for `GridworksActor`.
