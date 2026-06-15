# New sema words to review — JM sign-off tracker

Status: Draft · Pass 0 · Updated 2026-06-14 · Linear: OPS-40

> What this is: the simulated-test-environment spoke that **tracks Jessica's
> review** of every sema word this design (and the shared OPS-407 hardware-layout
> pass) added or bumped. Per the `jm/sim-vocab` commit permission (GridWorks_CLAUDE
> "Sema-words commit permission"), Claude may commit bounded, test-passing vocab —
> **but the words are not finalized until Jessica reviews them.** This table is that
> review gate. The **Reviewed by JM** column starts empty; Jessica fills a date as
> each word is signed off. Review covers both the **schema** (fields/refs/axioms)
> and the **`description` / `extended_description`** prose. The design rationale
> behind the sim-boundary words (the `sim.plant.flux` flux-is-coupling + Tesla
> reasoning) lives in `gleanings.md` "Sim-sensor words"; the device-type model
> rationale lives in `executor/hardware-layout.md`.

**Legend.** *Status* — `non-draft` (has a scada/gwsproto runtime class) or `draft`
(placeholder, no runtime). *Landed* — the commit hash, or `PENDING` if not yet
authored. **Reviewed by JM** — empty until signed off.

## Device-type model — the cac→DeviceType vocabulary (OPS-407)

The headline of the recent commits: UUID `cac_id` identity is gone; a component
carries an open `pascal.case` `DeviceType` (a `gw1.device.type` value), and the
layout enforces membership. The full durable rationale is in
`executor/hardware-layout.md` "The device-type model".

### The key + the records

| Word | Ver | Status | Landed | Reviewed by JM |
| --- | --- | --- | --- | --- |
| `gw1.device.type` (enum — the universal device key) | 000 | non-draft | `a8e0401` (trimmed `3c88996`/`d4a3e26`) | |
| `gw1.scada.device.type.gt` (gw108 record) | 000 | draft | `2d55705` | |
| `electric.meter.device.type.gt` | 000 | draft | `2d55705` | |
| `ads111x.based.device.type.gt` | 000 | draft | `2d55705` | |

### Components carrying `DeviceType` (gap-fill — new words)

| Word | Ver | Status | Landed | Reviewed by JM |
| --- | --- | --- | --- | --- |
| `dfr.config` | 000 | non-draft | `64bce72` | |
| `dfr.component.gt` | 000 | non-draft | `64bce72` | |
| `ads.channel.config` (`ThermistorDeviceType`) | 000 | non-draft | `64bce72` | |
| `ads111x.based.component.gt` | 000 | non-draft | `64bce72` | |
| `thermistor.data.method` (enum) | 000 | non-draft | `64bce72` | |
| `maker.api.attribute.gt` | 000 | non-draft | `b7d2cae` (round-trip verified) | |
| `hubitat.gt` | 000 | non-draft | `b7d2cae` (round-trip verified) | |
| `hubitat.poller.gt` | 000 | non-draft | `b7d2cae` (round-trip verified) | |
| `hubitat.component.gt` | 000 | non-draft | `b7d2cae` (round-trip verified) | |
| `hubitat.poller.component.gt` | 000 | non-draft | `b7d2cae` (round-trip verified) | |

*Round-trip verified* = generated from gwsproto, published to the dev rabbit
broker, captured, and decoded clean through the sema runtime (2026-06-14). That
experiment caught + fixed a gwsproto bug: the Hubitat component classes inherited
`Version "002"` from `ComponentGt` instead of declaring their own `"000"` (dfr/ads
had it right); fixed by overriding `Version="000"`.

### Components re-bumped to drop `cac_id` / carry `DeviceType`

| Word | Ver | Status | Landed | Reviewed by JM |
| --- | --- | --- | --- | --- |
| `electric.meter.component.gt` | 002 | non-draft | `2d55705` | |
| `gw108.gpio.sensor.component.gt` | 002 | non-draft | `2d55705` | |
| `gw108.vdc.relay.component.gt` | 002 | non-draft | `2d55705` | |
| `gw108.gpio.relay.component.gt` (placeholder) | 002 | draft | `2d55705` | |
| `web.server.component.gt` | 002 | non-draft | `2d55705` | |
| `i2c.thermistor.reader.component.gt` | 002 | non-draft | `2d55705` | |
| `i2c.multichannel.dt.relay.component.gt` | 005 | non-draft | `2d55705` | |
| `pico.tank.module.component.gt` | 012 | non-draft | `2d55705` | |
| `pico.btu.meter.component.gt` (`FlowMeterType`→`pascal.case`) | 001 | non-draft | `abc369f` | |
| `pico.flow.module.component.gt` (`FlowMeterType`→`pascal.case`) | 001 | non-draft | `abc369f` | |
| `sim.sensor.component.gt` | 000 | non-draft | `9f9c5d0` | |
| `sim.relay.component.gt` | 000 | non-draft | `2d55705` | |

## Sim-boundary words (the new sim vocabulary)

| Word | Ver | Status | Landed | Reviewed by JM |
| --- | --- | --- | --- | --- |
| `sim.plant.flux` | 000 | non-draft | committed | |
| `sim.plant.actuation` | 000 | non-draft | committed | |
| `change.relay.pin` (enum) | 000 | non-draft | committed | |
| `gw1.actor.class` (+SimSensorActor/SimRelayActor) | 012 | non-draft | committed (green) | |

## ActorClass cascade + layout words

| Word | Ver | Status | Landed | Reviewed by JM |
| --- | --- | --- | --- | --- |
| `spaceheat.node.gt` | 302 | non-draft | committed | |
| `layout.lite` (re-bumped in the cac→DeviceType sweep) | 015 | non-draft | `2d55705` | |
| `new.command.tree` (clean single-node) | 002 | non-draft | committed | |
| `scada.control.capabilities` (folded in place; was limbo) | 001 | non-draft | committed | |
| `gw.nolan.layout` (kept draft; `DeviceTypeMembership` axiom) | 000 | draft | `0cd2175` | |

## Config + enum words (the shared layout vocabulary)

| Word | Ver | Status | Landed | Reviewed by JM |
| --- | --- | --- | --- | --- |
| `egauge.register.config` | 000 | non-draft | `f68d6f3` | |
| `electric.meter.channel.config` | 000 | non-draft | `e775e57` | |
| `i2c.thermistor.channel.config` | 001 | non-draft | nolan round-trip | |
| `gpio.sense.mode` (enum) | 000 | non-draft | `9df37f8` | |
| `gw1.heat.call.interpretation` (enum) | 000 | non-draft | committed | |

## Legacy CAC words — may never use (bottom)

These predate the device-type model. The cac→DeviceType migration replaced their
role; they are kept registered but **we may never use them again** — review only if
we decide to retain the CAC shape for anything.

| Word | Ver | Status | Landed | Reviewed by JM |
| --- | --- | --- | --- | --- |
| `component.attribute.class.gt` (generic CAC) | 001 | non-draft | `e3cd6d8` | |
| `electric.meter.cac.gt` | 001 | non-draft | `4d58ee6` | |

**`spaceheat.make.model` is NOT tracked here.** It is frozen base vocabulary; the
early `008` bump (which added `GRIDWORKS__SIM_SENSOR` / `GRIDWORKS__SIM_RELAY_BANK`
make-models) was **superseded by `gw1.device.type`** when make/model-as-identity was
retired. The enum stays registered in sema but is abandoned for this work — not a
word to review, so it carries no row.

**Ref-only fixes in the `gw.nolan.layout` draft (no new word — no review row):**
`data.channel.gt` 001→002; `i2c.multichannel.dt.relay.component.gt` ref bumps;
`pico.tank.module.component.gt` ref bumps; enum ref `heatcall.interpretation` →
`gw1.heat.call.interpretation/000`; `relay.actor.config` axiom pin 002→003.
