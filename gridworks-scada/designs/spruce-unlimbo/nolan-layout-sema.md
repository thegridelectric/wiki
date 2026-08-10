Status: Draft · Pass 0 · Updated 2026-08-10

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

Sema-canon work — follow the sema authoring discipline (`sema/spec/`).

## Ordering

**After the layout-augments fold.** The layout type references the folded
component/derived-channel types, so close it against the shape we actually
land on, not a moving target. Tracked alongside the `layout-augments-fold`
spoke.

## Zone-model gotchas (design input, 2026-08-10)

Captured from the spruce experiments/postmortem work; to be absorbed
when the zone model in `gw.nolan.layout` / `gw1.hvac.zone` is next
worked. Companion lessons (sensing modality, heating-vs-cooling role,
channel ownership by reference instead of name arithmetic) are on
OPS-407.

- **Zone ≠ thermostat.** The spruce living room has TWO thermostats
  serving one room — the radiant stat (today "zone2-living-rm") and
  the fan-coil stat (today "zone5-living-rm-fancoil"). The current
  model can only express that as two zones, which misdescribes the
  space. Decouple the concepts so the layout can point multiple
  thermostats at one zone.
- **Open: insist on a temperature sensor per ZONE, not per
  thermostat?** With stats decoupled from zones, the zone's
  temperature identity needs a home of its own.
- **A heat call is associated with an emitter, and emitters have
  capabilities.** A thermostat's call drives a distribution device,
  and the device's capabilities bound what the call may mean: a
  radiant floor CANNOT cool (cold water through a radiant floor is a
  mistake — condensation hazard, actively harmful); baseboard cannot
  cool; fan coils heat AND cool. Capabilities belong on the emitter;
  the call's interpretation (see `gw1.heat.call.interpretation`)
  depends on them.
- **Mode is currently system-level, and the capability model must
  meet it.** Heat-vs-cool mode today is a property of the heating
  system (`SystemMode` / seasonal storage mode at layout level), not
  per zone. Capability declarations turn mode changes into checkable
  safety semantics: a system entering cooling mode must not route
  cold water to heat-only emitters.
- **The zone naming convention is load-bearing and fragile.**
  Everything zone-ish is today recovered by parsing channel-name
  strings ("zone{i}-{name}-..."); analysis code has to hand-code
  thermistor-zone lists (see the experiments repo emitters' commented
  hand lists) until per-zone sensing is declared in the layout.
