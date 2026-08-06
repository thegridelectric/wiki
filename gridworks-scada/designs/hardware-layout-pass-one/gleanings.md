# Gleanings — domain context, working method, deferred sweeps (spoke)

Status: Accepted · Pass 1 · Updated 2026-06-29 · Linear: OPS-407

> What this is: parked notes off the build path — durable domain context, the sema-source-of-truth
> working method, the landed channel-config-overhaul, open questions (transactive-energy reporting),
> and the deferred sweeps. The durable facts ultimately land in
> [`../../executor/hardware-layout.md`](../../executor/hardware-layout.md).

## Working method — sema is the source of truth

For all three mutating layout types (`gw.nolan.layout`, `gw.house0.layout`, `gw1.simple.sim.layout`)
the loop is: **(1)** edit the type in sema (definition yaml + registry; `build_indexes.sh` +
`regenerate_runtime.py`; `pytest`); **(2)** **hand-rewrite the matching gwsproto named-type**
(`named_types/`) to mirror the sema change — gwsproto types are written **by hand**, not generated from a
snapshot; **(3)** **validate the hand-written type against the sema CLI** — serialize an instance and run
`sema validate <payload.json>`, which decodes it through the **canonical sema runtime** (fields, property
formats, axioms, version; exit 0 = conforms). Sema is the source of truth, so `sema validate` — not any
generated copy — is what proves the gwsproto type is correct; **(4)** run the scada boot / round-trip.

**gwta is a separate consumer, not a step in this loop.** `sema/build_gwta_snapshot.sh` builds a
*restricted snapshot* for gridworks-terminalasset; it does **not** feed gwsproto and is **not** how the
gwsproto types are produced or checked. Do not reach for gwta when updating gwsproto.

gwsproto uses short local class names (`House0Layout`, `SimpleSimLayout`, `NolanLayout`), and carries **one
version per type at a time** (the current replaces the prior; no retained `XxxNNN` classes the way sema
keeps them). Immutability tracks **pushed-to-GitHub** (unpushed sema words are mutable in place).

## Field reality

- The first five homes run the **House0** layout: **beech, elm, oak, fir, maple** — electronics
  hand-made by George, not gw108. Common: three store tanks + a buffer; Hubitat hubs driving Honeywell
  thermostats; varied heat pumps. **Siegenthaler loops on beech and maple** (a mechanical variation,
  not a software distinction). Zone count varies (beech/maple 2, oak/elm/fir 4).
- **Spruce is a one-off:** gw108 electronics, plain radiant floor. The next ~12 new-builds use
  store-under-floor, so Spruce's specifics shouldn't be over-generalized.

So House0 is the **fleet** layout (5 homes, one hardware generation, ~47 ShNodes); Spruce is a **single
experimental** gw108 layout (~30 ShNodes). That asymmetry is why house0 earns its own word.

**Naming — Nolan ↔ Spruce (keep both; not PII):** the gw108 house is **Nolan** in code and sema
(`gw.nolan.layout`, Strategy `"Nolan"`) and **Spruce** colloquially — next in the tree-name series
(beech, elm, oak, fir, maple → spruce). Same house. Ms. Nolan was a Millinocket widow in the original
house; Matt Polstein built the Nolan house — an honored legacy, not a name to scrub.

**Simulated tanks + the simple-sim layout:**
- `sim.pico.tank.module.component.gt` exists to **unit-test `api_tank_module.py`** — same channels as a
  real `PicoTankModule3` but its `DeviceType` marks it a sim sensor.
- **Nolan has exactly 1 storage tank** (buffer + tank1); the **simple sim is 1 storage tank, 360
  gallons**. The simplified **sim House0** ([`axioms.md`](axioms.md)) is no-buffer + single tank.
  Tank gallons are articulated fragilely — firm this up when building the sim layouts.

## Channel-config overhaul (scada half) — landed 2026-06-26

[OPS-427](https://linear.app/gridworks/issue/OPS-427) landed on `gridworks-scada` `jm/delete-cac-id`
and `sema` `jm/sim-vocab`. Scada suite green (112), sema green (241). Durable shape:

- **`channel.config` carries neither `Unit` nor `Exponent`** — across all six ChannelConfigBase-family
  types. A channel's identity is its `TelemetryName` (which already encodes scaling, e.g. `GpmTimes100`);
  its unit resolves from `TelemetryName`. `egauge.register.config` and `maker.api.attribute.gt` are out
  of the family and keep both.
- **The metered transactive set is declared once, not flagged per-node.** `InPowerMetering` is gone from
  `spaceheat.node.gt` (303) and `data.channel.gt` (003). In its place a single `derived.channel.gt` with
  **`Strategy="transactive-power"`** names the metered `PowerW` channels in `InputChannelNames`. The
  **power-meter actor** computes it (not derived-generator, so `power.watts` latency is unchanged).
  `Strategy` stays an open string (a sema enum is deferred — enums coerce unknown values to a default,
  so would be weaker than code-level validation).
- **Layout axiom (the metering boundary).** Exactly one `transactive-power` DerivedChannel; its inputs
  resolve to existing `PowerW` DataChannels; each input's about-node carries `NameplatePowerW`. Lives in
  `hardware_layout.check_transactive_metering_consistency`, mirrored in the sema layout words
  (`gw.house0.layout` axiom 5, `gw.nolan.layout` axiom 1).
- **No defaulted nameplates.** The metered set is config-declared; a transactive node MUST state its
  `NameplatePowerW`. `CoreChannelNames.transactive_power` is the channel name.
- **Removed as dead:** `TelemetryTuple` + its four unused `HardwareLayout` properties, the unused
  `asset-electric-power` name, the eGauge `NameplatePowerW=10` default.

## Open question — transactive-ENERGY reporting (2026-06-27)

The overhaul covers transactive *power*. Still open: **how to report transactive-energy.** The GridWorks
energy markets are **5 minutes**, so the likely shape is reporting energy **every 5 minutes** —
`TelemetryName.WattHours` if it is a DataChannel, or `gw1.unit.WattHours` if it is a DerivedChannel.
Think through DataChannel-vs-Derived, the emission period (5 min), and how it relates to the
`transactive-power` channel. The fuller transactive *audit declaration* (inspected-meter binding,
energy-from-register vs our integral, the committed/signed reported stream, single-CT preference,
directional combination) stays open in `explorations/metering.md`. **Also note:** all the old fixtures
are missing several important derived channels (transactive-power among them) — regenerating from sema
is what corrects them.

## Deferred sweeps (sequenced after the gen + sema_to_dc land)

- **The names sweep** — replace all `house_0_names` `H0N`/`H0CN` references (~61 files) with the new
  `gwsproto/names/` per-domain names, in one pass.
- **The reference sweep** — move the ~76 scada call-sites off the derived `self.layout` accessors onto
  `self.hydronic.*`, at dc-swap time.
- **The ConfigList revamp** — promoted to its own design,
  [OPS-489](https://linear.app/gridworks/issue/OPS-489/harmonize-units)
  (harmonize-units), riding the TelemetryName → `gw1.unit` +
  `gw1.quantity` cascade.
- **spruce → Nolan rewrite** — `gen_spruce.py` is a stale House0-based gen marked OLD/BROKEN; it should
  be `gw.nolan.layout`.
- **`channel_stubs()` / `ChannelStub`** in `house_0_names.py` — fully unused, still carrying the retired
  `in_power_metering`; delete when convenient.
- **`SendToDerived` removal** (still on `i2c.thermistor.channel.config`) and the old `layout_gen/`
  LayoutDb builders sweep (under rework on `jm/layout-augmments`).

## Pass-2 carry — drop H0N, knit the layout families

`required_topology_nodes` / `required_system_actor_nodes` are the first-guess production-necessity spec
but are written in `H0N` terms and enforced nowhere yet. Pass-2 drops `H0N` and works out what each
layout family shares vs differs on — only then can these become real per-layout axioms. **Proof the
guess is already too strict:** `maple` carries only an `hp-odu` (no `hp-idu`) yet is definitely still
House0, so `required_topology_nodes` (which lists `H0N.hp_idu`) is wrong as-is.

**The capturer↔channel *capability* axiom is the nuanced pass-two piece.** Pass-one recovers only the
*structural* guarantee that a captured channel is bound to a real, hardware-bearing component
(`CaptureNodeHasComponent` — see [`axioms.md`](axioms.md)). It deliberately does **not** assert the
*semantic* guarantee that the component is of a *kind* that can actually capture that channel
(a thermistor reads a temperature, a flow module reads a flow, a meter reads power). That by-kind
check is the component↔channel **capability** axiom, deferred to pass-two with the i2c board model
([`i2c-board-components.md`](i2c-board-components.md)) — it needs a channel-kind↔component-kind
capability map, which is exactly what the board-resident decomposition reorganizes, so encoding it now
would bake in a mapping pass-two is about to rewrite. The right altitude is the same one every
channel-existence axiom already sits at: require the *semantic* channel (about-node + unit), stay silent
on the hardware that produces it, until the capability layer lands. This is the more-nuanced sibling of
the `G/H` topology axioms above — both are "what must a real layout's nodes/components be" questions that
only become tractable once `H0N` is gone and the layout families are knit.
