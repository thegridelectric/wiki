# Hardware layout — pass one

Status: Accepted · Pass 1 · Updated 2026-06-15 · Linear: OPS-407

**EDD: yes** the verification that matters is a real round-trip: scada `layout_gen` emits a
layout, publishes to the dev rabbit broker, and gridworks-terminalasset decodes it through its
sema snapshot. (In-suite `layout_gen`-green for both real layouts is the sub-gate.)

> What this is: the first critical pass on the scada hardware-layout / components model — drop
> UUID `cac_id`s for a readable `gw1.device.type` `DeviceType`, simplify components, restructure
> `layout_gen`, fill the sema vocabulary against real layouts. A **shared dependency**
> (simulated-test-environment + spruce-unlimbo Chunk B), its own flat issue OPS-407.

## Orient (read this, not the history)

**Done:** the device-type model (`cac_id` → open `pascal.case` `DeviceType`); the full migrated
sema **component** vocabulary (dfr / ads / Hubitat / sim / gw108 / pico / electric-meter / …);
`g.node.gt`; and the scada↔gwta **component** round-trip — every component + node: gwsproto emits →
gwta's sema snapshot decodes (27/27). `gw.nolan.layout` is un-drafted (axioms parked in its
`stash_axioms.md`).

**Where to look** (don't mine this doc for the play-by-play):
- **Changelogs** — the commit-by-commit story: `wiki/{sema, gridworks-scada,
  gridworks-terminalasset}/changelog.md`.
- **`executor/hardware-layout.md`** — the durable spec: the device-type model **and** "The three
  layout families" (the builders, the `temp`/`set`/`heat-call` zone invariant, the per-layout
  sensor + heat-call mechanisms, and required-vs-optional being the *layout's* call).
- **The code you'll refactor (read to prepare):** `gw_spaceheat/layout_gen/` — `layout_db.py`
  (the `LayoutDb` + `add_stubs`) and the per-device builders (`relay`, `dfr`, `multi`, `flow`,
  `btu`, `egauge`, `gw108_nolan_zones`, `tank3`, `derived_channels`); and the loaded data classes
  `packages/gridworks-scada-protocol/src/gwsproto/data_classes/{hardware_layout.py,
  house_0_layout.py}` — the load pipeline + the structural validations the sema layout axioms
  mirror. **The device-type model below is the lens for that refactor** — read it first.

**Device-type model in one breath:** a component carries an open `pascal.case` `DeviceType` (a
`gw1.device.type` value) and no `cac_id`; the *layout type* enforces enum membership; specialized
`<family>.device.type.gt` records exist only where a category carries real data.

## ▶ DO THIS NEXT — port the layouts to gwsproto, then loop (types ⨯ data_classes ⨯ layout_gen)

**Tests green FIRST.** Make the scada suite pass: regenerate `tests/config/{nolan,house0}-layout.json`
and fix the `tests/named_types/*` sample dicts (`ComponentAttributeClassId` → `DeviceType`). This
needs the tank-sensor wiring (the `*-device` channels — `simulated_tanks.py` was deleted), which is
the first slice of the build below, so this and the next step converge.

**Then port sema → gwsproto, making the gwsproto runtime the authority.** Author the sema layout
types first — `gw.nolan.layout` exists; create `gw.house0.layout` + `gw1.simple.sim.layout` the
same way (their component sets; axioms → each `stash_axioms.md`; un-drafted; runtimes) — then
**hand-copy all three layout runtimes into gwsproto at the start** (the `g.node.gt` pattern; a
`GwNolanLayout` scaffold exists). **From here the gwsproto runtime layout types are the authority**
for the layouts — this work is fully embedded in scada; sema is upstream, not in the loop.

**Then iterate the three co-evolving faces in a loop, keeping every test green each turn:**
1. the **gwsproto layout types** — the authority, the contract a layout must satisfy;
2. **`data_classes/hardware_layout.py` + `house_0_layout.py`** — the loaded layout objects and
   their structural validations; use/edit these to match the types;
3. **`layout_gen`** → split into `house0_layout_gen` / `nolan_layout_gen` /
   `simple_sim_layout_gen` over shared tools, **names-driven** (compose `hydronic_spaceheat` + the
   per-layout names package), emitting layouts that validate against the types. Intent + per-layout
   mechanisms: `executor/hardware-layout.md` "The three layout families".

Small turns — after each change regenerate the fixtures and keep `pytest` green for both real
layouts, never a long red. Then **re-snapshot gwta** and **prove it** with the round-trip
(scada emits each layout → gwta decodes).

**The ConfigList revamp IS pulled forward** into this work — a single `channel.config` shape with
`TelemetryName → gw1.unit` + `gw1.quantity`. The earlier "defer it" was gated on having a harness
to validate a `TelemetryName`-everywhere change; the round-trip + sim layout being built here *is*
that harness, so it folds into the loop above (it touches the layout types, the data classes, and
`layout_gen` alike).

Immutability this session = pushed-to-GitHub (unpushed sema words are mutable in place).

**Owed within the layout work:** the `DeviceTypeRecordAlignment` axiom (a component's specialized
record must be the right family for its `DeviceType`) is not yet on any layout.

## Gleanings — domain context (durable)

> **Naming — Nolan ↔ Spruce (keep both; not PII):** the gw108 house is **Nolan** in code and sema
> (`gw.nolan.layout`, Strategy `"Nolan"`, `gw108_nolan_zones.py`) and **Spruce** colloquially —
> next in the tree-name series (beech, elm, oak, fir, maple → spruce). Same house. Ms. Nolan was a
> Millinocket widow in the original house; Matt Polstein bought the property, let her stay through
> her passing, then built the Nolan house — an honored legacy, not a name to scrub.

**Field reality:**
- The first five homes run the **House0** layout: **beech, elm, oak, fir, maple** — electronics
  hand-made by George, not gw108. Common: three store tanks + a buffer; Hubitat hubs driving
  Honeywell thermostats; varied heat pumps. **Siegenthaler loops on beech and maple** (a mechanical
  variation, not a software distinction).
- **Spruce is a one-off:** gw108 electronics, plain radiant floor. The next ~12 new-builds use
  store-under-floor, so Spruce's specifics shouldn't be over-generalized.

So House0 is the **fleet** layout (5 homes, one hardware generation, ~47 ShNodes: Hubitat/Honeywell,
dual Krida I2C relays, DFRobot DACs); Spruce is a **single experimental** gw108 layout (~30
ShNodes). That asymmetry is why house0 earns its own `gw.house0.layout` word.
