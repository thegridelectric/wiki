# The layout's purpose & boundary (spoke)

Status: Accepted · Pass 2 · Updated 2026-06-29 · Linear: OPS-407

> What this is: the session's core output — what a hardware layout IS and is NOT, the three-artifact
> split, and the consequences (channel.config collapse, sema axioms as sole validity authority,
> forward-only transforms, sieg as its own layout). Decided through an extended design dive 2026-06-27/28.

## Purpose — the layout is static physical topology

**A hardware layout is the static physical topology and the immutable physical specs: what is wired.**
That includes the **plumbing** (pipes, tanks, pumps, flow positions, whether a Siegenthaler loop is
plumbed) **and the control nodes** (the command-tree / FSM-actor structure: hp-boss, sieg-loop,
pico-cycler, the local-control substates) **and** per-device physical facts (tank gallons, HP nameplate,
the eGauge register map, ADS terminal blocks). It changes **only when hardware is rewired.**

The discriminator is one question:

> **Can you change this without rewiring hardware?** If yes, it is **operational**, not topology — it
> does not belong in the layout.

## Three artifacts, not two

| artifact | holds | changes when | updated how |
|---|---|---|---|
| **deployment config** (`.env`/settings) | broker creds, paths, GNode aliases, connection | redeploy | file |
| **hardware layout** (`hardware-layout.json`) | static physical topology + control nodes + physical specs; `SiegLoopPlumbed` | **rewiring** | file |
| **operational params** ([`operational-params.md`](operational-params.md)) | report tuning, `SystemMode`, `UseSiegLoop`, `CriticalZoneList`, `ZoneKwhPerDegFList`, FLO knobs | tuning, live | **via the LTN** ([OPS-408](https://linear.app/gridworks/issue/OPS-408)) |

By the rewiring test, several things in the layout/config today **fail it and move to operational**:
`ZoneKwhPerDegFList` + `CriticalZoneList` (in `gw.house0.hydronic` today), `SystemMode` (in config
today), and the per-channel **report tuning** (`CapturePeriodS`/`AsyncCapture`/`AsyncCaptureDelta`/
`PollPeriodMs`, today in every component's `channel.config`). `PollPeriodMs` goes too, **optional** — it is
tunable without rewiring, bounded below only by the hardware floor `MinPollPeriodMs` (which *stays* on the
device type); the `CaptureAndPollingConsistency` axiom moves with it (reshaped conditional). Most of
`actors/config.py` is in fact operational (the COP curve, heating/RSWT model, control/mode knobs) — the
full inventory + the artifact + assembly are built **this pass** in the
[`operational-params.md`](operational-params.md) spoke; only the LTN live-update *transport* stays separate
([OPS-408](https://linear.app/gridworks/issue/OPS-408), Thomas).

**Carve-out the other way — a few config fields go to the LAYOUT, not operational** (they *fail* the
rewiring test — swapping them *is* rewiring): `hp_model` and `hp_max_kw_el` (HP nameplate — already
`# TODO: move to layout`), and `whitewire_threshold_watts`. They are physical specs, not tunable knobs.

## Consequence — the `channel.config` base type is **removed**

Once report tuning leaves, a bare `channel.config` would be **just `ChannelName`** — and a bare
`{ChannelName}` ConfigList is information-free redundancy (the channel→component binding is already carried
by `DataChannel.CapturedByNodeName`). So the endpoint is not "collapse the base to `ChannelName`" but
**delete the base type entirely**. The only thing that earns a place in a component's `ConfigList` is the
**specialty family types** — and they keep their *hardware-binding* fields, not tuning. E.g.
`ads.channel.config/001` (unpublished → mutable in place) becomes `ChannelName` + `TerminalBlockIdx` +
`ThermistorDeviceType` + `DataProcessingMethod/Description`, no capture params.

**Decision (2026-06-28, sharpened 2026-06-29): a component carries a `ConfigList` only when it has
per-channel hardware binding** (ADS terminal blocks, eGauge registers, thermistor types). For a component
with no per-channel binding, the channel→component binding is **solely `DataChannel.CapturedByNodeName`** —
a bare `{ChannelName}` ConfigList is information-free redundancy and a drift risk (the no-dead-information
maxim). When all bare-base users are reworked, **nothing references `channel.config` → the base type is
removed.**

**The 9-component drop worklist.** Nine component types currently `$ref` the bare `channel.config` in their
ConfigList (latest versions). Every one of them keeps its per-channel binding (where any) at the
**component level** via named fields, not inside the ConfigList items — so each cleanly **drops its
`ConfigList`** (new version); **none needs a new specialty type:**

| Component (latest ver) | Component-level binding (kept) | Action |
|---|---|---|
| `gw108.gpio.sensor.component.gt/002` | `GpioPin`, `SenseMode` | drop ConfigList |
| `hubitat.component.gt/000` | `Hubitat` | drop ConfigList |
| `hubitat.poller.component.gt/000` | `Poller` (per-attribute map) | drop ConfigList |
| `pico.btu.meter.component.gt/001` | `Flow/Hot/Cold/CtChannelName` | drop ConfigList |
| `pico.flow.module.component.gt/001` | `FlowNodeName` | drop ConfigList |
| `pico.tank.module.component.gt/012` | `SensorOrder`, Pico HwUids | drop ConfigList |
| `sim.pico.tank.module.component.gt/001` | `SensorOrder`, Pico HwUids | drop ConfigList |
| `sim.sensor.component.gt/000` | (none) | drop ConfigList |
| `web.server.component.gt/002` | `WebServer` | drop ConfigList |

(`pico.btu.meter` / `pico.flow.module` carry component-level `AsyncCaptureDelta*` *firmware* fields — those
stay on the component; they are not the `channel.config` capture params and are out of scope for this
collapse.) The specialty `ConfigList`-bearing types that **remain** are `ads.channel.config`,
`i2c.thermistor.channel.config`, `electric.meter.channel.config`, `dfr.config`, and `relay.actor.config`.

**Axiom change:** the global `ComponentDataChannelBijection` (C == D over all ConfigLists) is replaced by
a **per-component local bijection** — *for a component that has a `ConfigList`, its `ChannelName` set equals
exactly the DataChannels whose `CapturedByNodeName` is that component's node.* Composes with the kept
`ChannelCaptureConsistency` + `CapturedByNodeName` referential integrity. **Plus a new
`CaptureNodeHasComponent` axiom** recovers what the bare-base drop silently removed — the guarantee that a
captured channel is bound to a *real, hardware-bearing* component (the global bijection used to give this
for free): *for every `DataChannel`, if `CapturedByNodeName` is present, that ShNode SHALL have a non-null
`ComponentId`* (`DerivedChannel`s exempt). The semantic by-*kind* capability check stays pass-two. See
[`axioms.md`](axioms.md).

## sema axioms are the sole layout-validity authority

The dc `HardwareLayout` is **assembled from axiom-valid sema** (below), so it can never see an invalid
layout. Therefore the dc-side structural checks (`check_transactive_metering_consistency`, the
`1 ≤ tanks ≤ 6` guard, …) are pure duplication — "old, incomplete, drift" — and are **dropped**. The dc
has **no structural validation**. Two guards:

- **Drop a dc check only once its sema axiom exists** — this is the same workstream as Task b (port →
  then drop); dropping ahead of the axiom opens a hole. (Cardinality has landed → its dc guard can go.)
- The one genuinely-new check is a *different* concern — the **assembly** check ("do the operational
  params cover every channel the layout declares?"), which belongs with `ops_and_sema_to_dc`, not sema.

This also retires a wrinkle: the dc Python guards were why the **gen** had to be the counterexample
fixture factory (they raised before sema could validate). Gone, that's purely a sema concern.

## Forward-only transforms — the dc is an output, never a source

Keeping the dc does **not** require `dc_to_sema` (the reverse we dropped). The dc is *generated*; the
fleet is **re-authored** via the sema gen, not extracted from the concept-incomplete dc (which is exactly
why `dc_to_sema` failed — the dc is missing heat-call, transactive-power, the static/operational split).

```
per-home config ──gen──▶ ( static-layout sema , operational params )          ← authoring (fresh)
( static-layout sema , operational params ) ──ops_and_sema_to_dc──▶ runtime dc  ← assembly
existing dc fixtures: reference ONLY (UUIDs via LayoutIDMap + the diff-and-adopt oracle)
```

The three-artifact split adds a *second authored input*; it turns `sema_to_dc` into
**`ops_and_sema_to_dc`** — the only new transform, still purely forward. No `dc_to_sema`, no `dc_to_ops`.

**Sequencing — the whole artifact is built this pass.** Because pass-one **reshapes the components now**
(the `channel.config` collapse — `ads.channel.config` etc. lose their capture params), the capture params
lose their home *now*. So the [`operational-params.md`](operational-params.md) spoke builds
`operational-params.json` + `ops_and_sema_to_dc` this pass (the components can't be reshaped without it)
and migrates the rest (`SystemMode` from config, `CriticalZoneList`/`ZoneKwhPerDegFList` from the layout,
FLO knobs) within the pass. Only the LTN live-update transport stays separate
([OPS-408](https://linear.app/gridworks/issue/OPS-408)).

## Sieg is its own layout; the board is not a layout factor

- **`gw.house0.sieg.layout` is a distinct layout type** (maple, beech). The reason is the *optimization*,
  not just the plumbing: a Siegenthaler loop lets the FLO modulate heat-pump leaving-water-temp
  continuously — a **different forward-looking dispatch space** (a richer Dijkstra graph), which is a
  control-architecture difference, over the "split" line. `SiegLoopPlumbed` = topology (the layout);
  **`UseSiegLoop` = operational toggle** (the FLO can decline the loop even when plumbed). FLO/Dijkstra
  context: `wiki/heating-system-design/knifes-edge-development/knifes-edge-mc-cost-model.md`,
  `wiki/gridworks-ltn/executor/primary.md` §3 (the optimizer core is private — Thomas's `space-heating-flo`).
- **The sensing/actuation board (gw108 vs hand-made) is NOT a layout factor.** Beech-on-gw108 is the
  *same* layout as beech-on-hand-made — the board is decoupled from topology. This is exactly what the
  board-resident model ([`i2c-board-components.md`](i2c-board-components.md)) is for; "redo beech with a
  gw108" is the concrete forcing function for that decoupling. nolan differs from house0 for real
  topology reasons (radiant floor, single tank, control/optimization shape), not its board.

## When are there different layouts? — the dial

A layout type is a **named, bounded family with a parameter space**; choosing the boundary is choosing
what variation the parameters absorb. **Absorb as a parameter** when all hold: it shares the command-tree
+ HSM *definitions*; the variation is a bounded present/absent of control nodes + actuators/channels (a
different **capability cover**); its invariants are **conditional axioms**. **Split into a new layout**
when the control architecture (incl. the optimization) differs, or the conditionals stop being
comprehensible. zones/tanks/sourcing = parameters; sieg = its own layout (the optimization argument);
nolan vs house0 = separate layouts.
