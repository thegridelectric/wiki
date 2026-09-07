# component-id-on-wire (unsorted item)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: an unsorted item; hub [`primary.md`](primary.md).

**Is ComponentId redundant on the wire once ComponentBinding holds?**
Parked: NO for now, deliberately — the node Name is the unique
identity WITHIN the house, while ComponentId identifies the physical
instance, so replacement history is trackable (same name, new uuid).
Revisit only if instance tracking finds a better home.
