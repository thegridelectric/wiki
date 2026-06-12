Status: Draft · Pass 0 · Updated 2026-06-11

# The hardware layout

What this is: how a house's hardware is described, loaded, and generated —
the layout object, its load pipeline, and the (hacky) generation tooling.
**Current state only.** The rework (Sema layout types with axioms, the
`names/` system, doing multiple house types right) is spruce-unlimbo
Chunk B (OPS-334) — tracked there, not speculated here. Components
themselves are `executor/components.md`.

**First pass.** This is a first pass written to help *work with* the
system, not a critiqued design. Future TODO: review it with a critical eye
for design, the way `scada-ltn-link-state.md` was. But the layout is **not
as hair-on-fire** as the link-state machinery — it works, and it's **a bit of
both**. Much of the apparent complexity is the cost of a *consistent*
**interlinked database**: nodes, components, device types, channels, and
derived channels all cross-reference each other by name/id, and the axioms are
the referential-integrity constraints (a captured channel's
`CapturedByNodeName` resolves to *and matches* the capturing node;
`AboutNodeName` resolves; `InputChannelNames` exist; a device type bijects
with its make/model). That interlinking is worth paying for. The rest is
incidental cruft (the hardcoded buckets, the copy-paste tlayouts, the
config-list zoo, the dangling strategy names — the OFI targets). So the
critical pass is: **sharpen and simplify wherever it doesn't lose important
information** — keep the relational integrity, trim the cruft. Lower priority
than the link-state machinery.

## What a layout is

A layout is the node→component→device-type→channel graph for one house,
plus house-level facts. `HardwareLayout` (`data_classes/hardware_layout.py`)
is the base; `House0Layout` (`data_classes/house_0_layout.py`) adds House0
fields: `ZoneList`, `CriticalZoneList`, `TotalStoreTanks` (1–6),
`ZoneKwhPerDegFList`, `TankTempCalibrationMap`, `FlowManifoldVariant`,
`UseSiegLoop`, and the three GNodes (`MyScadaGNode`,
`MyTerminalAssetGNode`, `MyLeafTransactiveNodeGNode`). On disk it's
`<house>.generated.json` (e.g. `oak.generated.json`).

## Load pipeline

`HardwareLayout.load()` ingests the JSON and builds the graph:
`load_cacs()` → `load_components()` (pairs each component with its Cac,
instantiates the runtime `Component` subclass) → `load_nodes()` (links
`ShNode.ComponentId` → component) → `load_data_channels()` →
`load_derived_channels()` → `resolve_links()`. Devices arrive in
**per-family buckets** — `Ads111xBased*`, `ElectricMeter*`,
`ResistiveHeater*`, `Other*`, each a `*Cacs` + `*Components` pair — and
the loader iterates a list of bucket names. The bucketing is **intentional,
not arbitrary** (Jessica, 2026-06-11): a family gets its own bucket exactly
when its device type carries information the code needs — i.e. a specialized
`*.cac.gt` (`ads111x.based`, `electric.meter`, `resistive.heater`).
Everything whose device type is the generic `component.attribute.class.gt`
lands in `Other*`. So the three buckets are the three specialized device
types; the only residual wart is that the loader's bucket list is hardcoded
rather than derived from which device types are specialized.

**Load-time validations that bite (House0Layout `__init__`):** tank count
1–6; `TankTempCalibrationMap` M/B must match the tanks' derived channels
(identity/affine strategy); the system model requires `usable-energy` and
`required-energy` derived channels by exact name. These run at construction
— a layout that violates them fails to load (this is the class of failure
behind this morning's `AsyncCaptureDelta` greening, one layer up).

## Generation — two layers, the lower one hacky

- **In-repo `layout_gen/`** is the programmatic builder. `LayoutDb`
  (`layout_db.py`) accumulates bucket-keyed lists; per-device generators
  (`relay.py`, `multi.py` TSnap, `simulated_tanks.py`, `derived_channels.py`,
  `flow.py`, `egauge.py`, `dfr.py`, `tank3.py`, `gw108_nolan_zones.py`) each
  append nodes/components/cacs/channels — **the caller passes the bucket
  name** (no type-based dispatch). `fixture_layouts.py` assembles the
  house0 and nolan *test* fixtures; `genlayout.py` is the `mktest` CLI.
  `simulated_tanks.py` already emits `SimPicoTankModuleComponentGt` — the
  seed the dashboard experiment builds on.
- **The `tlayouts` sibling** (`/Users/jessica/GridWorks/tlayouts/`) is the
  real-house generator: one `gen_<house>.py` per house (oak, beech, elm,
  fir, maple, orange, almond, spruce, beachrose), each calling the same
  `layout_gen` device builders with house-specific config (zones, tank
  calibrations, hardware UIDs). Its own README says "hacky and temporary."
  It **runs in the scada venv** (imports `gw_spaceheat`/`layout_gen`
  directly, no packaging). The hackiness is concrete: 9 near-identical
  copy-paste gen scripts with no shared base, and per-house divergence in
  code rather than data — e.g. `gen_spruce.py` drops `add_relays()`
  entirely, uses one tank + BTU meters, default (zero) tank calibrations.
  `oak` is the full House0 (20 relays via the i2c multiplexer, 4 Pico tank
  modules, power meter, HpBoss) — the layout the dashboard experiment uses.

## Names — `gwsproto/names/`

Node and channel names are layered: `core/` (system actors:
primary_scada, ltn, power meter), `hydronic_spaceheat/` (the shared
heating vocabulary — zones, tanks, flows, pipes), and per-house-type
`house0/` and `nolan/`. `H0N`/`H0CN` (house-0 node/channel names) expose
static names (relays, pumps, pipe temps, powers) plus zone-/tank-indexed
names populated at instantiation from `ZoneList`/`TotalStoreTanks`. Names
are **invariant across hardware substitution** — swapping a sensor changes
the *capturing node*, not the channel name (`dist-swt` stays `dist-swt`).
This layered names system is half of the "multiple house types, done
right" rework.

## The rework (pointer, not spec)

Where this is headed — `layout.lite` (`named_types/layout_lite.py`, a Sema
type with axioms) is the seed; the full direction is **`house0.layout` /
`gw.nolan.layout` as Sema types with axioms**, retiring tlayouts'
lock-step branching, on the layered `names/` system. That is spruce-unlimbo
**Chunk B / OPS-334** — the layout pipeline. The `gw`/`gw1` prefix on these
types is deliberate vocabulary namespacing (GridWorks's `gw1.actor.class`,
`gw1.unit`, `gw.nolan.layout` leave room for other orgs' own words).

## Hacky/irregular bits (current)

- Per-family buckets are intentional (specialized device type ⇒ own bucket),
  but the loader's bucket list is hardcoded, not derived from which device
  types are specialized.
- **Most of `layout_gen/` is hacky and irregular exactly at the
  spruce-unlimbo pain points** — multi-house-type handling (house0 / nolan /
  gw108), caller-passed bucket names, per-device generators that diverge in
  *code* not data. That mess is precisely what Chunk B's rework (`names/` +
  Sema layout types) targets; it is the reason the layout pipeline blocks
  moving spruce out of limbo.
- `tlayouts`: copy-paste gen scripts, per-house divergence in code not data,
  runs only inside the scada venv.
- **The derived-channel strategy names dangle.** `identity`, `affine`,
  `system-model`, `heat-call`, `simple-falling-edge-setpoint` (and the old
  `linear-fit` / `layer-by-layer` they replaced) are used as strings with
  **no canonical semantics home** (Jessica, 2026-06-11) — nothing specs what
  each strategy computes. The rework also grew companion fields
  (`EmissionMethod`, `EmitPeriodS`) — surfaced while migrating the stale
  `oak` layout, where the strategy renames + new required fields are a slice
  of the layout-augments fold, not a version bump. And because the names have
  no sema home, the only record of *what word became which*
  (`linear-fit`→`affine`, `layer-by-layer`→`system-model`) is the public data
  stream and the repos — so migrating `oak` meant **inferring** the rename by
  diffing current vs stale layouts. That inference is costlier and less sure
  than if the strategy carried its own versioned sema definition; it's a
  concrete case of "I'll just use the sema for this" being the cheaper, surer
  path. (Surfaced by the migration experiment — the EDD habit paying off.)
  **OFI:** give the strategy names a sema home — a versioned `strategy` enum
  (or a small type) — so a rename is an authoritative lookup, not an
  inference.
- `SynthChannels` list still instantiated though `DerivedChannels` is the
  real mechanism (`layout_db.py`).
- Nolan-only derived channels (heat-call, setpoint) with no House0
  counterpart — a deeper strategy divergence.
- Spruce is special-cased (no relays, one tank, BTU meters) — house0-shaped
  injection into it fails to load.

## Opportunities for improvement (OFIs)

- **`ChannelConfig` needs a rethink and overhaul (Jessica, 2026-06-11).** It is
  the thing at the center of the config-list mess: a zoo of per-component
  config types (`ChannelConfig`, `ElectricMeterChannelConfig`,
  `AdsChannelConfig`, `I2cThermistorChannelConfig`, `RelayActorConfig`,
  `DfrConfig`), `TelemetryName` overloading unit *and* meaning, and channel
  *identity* tangled with capture *policy* (`AsyncCaptureDelta`,
  `CapturePeriodS`, `PollPeriodMs`) in one object. The cost is not only machine
  (fragmentation, the snapshot-cadence liveness coupling) — it is human: "what
  is a channel config" takes seven drills of inference instead of one click at
  a sema type. The overhaul: a single sema-typed `channel.config` shape, with
  `TelemetryName → gw1.unit`, and identity separated from capture policy.
  Detail in `components.md` ("The config list — current shape, and a critique").
- **Strategy-name semantics need a sema home** (also noted in the hacky-bits
  above) — a versioned `strategy` enum/type so a rename is a lookup, not an
  inference.
