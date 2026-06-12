Status: Draft · Pass 0 · Updated 2026-06-11

# Close the gw.nolan.layout Sema type

> What this is: spruce-unlimbo spoke (Chunk B), **back-burnered** — finalizing
> the `gw.nolan.layout` Sema type. Parked here so it stops being a dangling
> task; not now.

## State

The type exists: `sema/definitions/types/gw.nolan.layout/000.yaml` — **draft**,
version 000, ~25 axioms (GNode uniqueness, ShNode requirements, channel
semantics, relay-board bijection, zone/tank structure). The schema is
essentially complete; it's just marked draft. A `jm/nolan` branch holds WIP
(a `gw1.scada.device.type.gt` 000→001 ref bump, axioms-into-registry). The
published sibling to compare against is `layout.lite`.

## Closing it (when picked up)

1. Finalize in `sema/definitions/registry.yaml` (draft → published state).
2. Regenerate: `scripts/build_indexes.sh` + `scripts/regenerate_runtime.py`.
3. Validate the generated type against real layouts.

Sema-canon work — read `sema/CLAUDE.md` and follow `/make-sema-word`.

## Ordering

**After the layout-augments fold.** The layout type references the folded
component/derived-channel types, so close it against the shape we actually
land on, not a moving target. Tracked alongside the `layout-augments-fold`
spoke.
