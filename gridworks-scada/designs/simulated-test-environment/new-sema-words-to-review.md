# New sema words to review — JM sign-off tracker

Status: Draft · Pass 0 · Updated 2026-06-13 · Linear: OPS-40

> What this is: the simulated-test-environment spoke that **tracks Jessica's
> review** of every sema word this design added or bumped. Per the `jm/sim-vocab`
> commit permission (GridWorks_CLAUDE "Sema-words commit permission"), Claude may
> commit bounded, test-passing vocab — **but the words are not finalized until
> Jessica reviews them.** This table is that review gate. The **Reviewed by JM**
> column starts empty; Jessica fills a date as each word is signed off. Review
> covers both the **schema** (fields/refs/axioms) and the **`description` /
> `extended_description`** prose. The design rationale behind the sim-boundary
> words (the `sim.plant.flux` flux-is-coupling + Tesla reasoning) lives in
> `gleanings.md` "Sim-sensor words".

**Legend.** *Status* — `non-draft` (has a scada/gwsproto runtime class) or `draft`
(placeholder, no runtime). *Landed* — the `jm/sim-vocab` commit hash, or `PENDING`
if not yet authored. **Reviewed by JM** — empty until signed off.

## Sim-boundary words (the new sim vocabulary)

| Word | Ver | Status | Landed | Reviewed by JM |
| --- | --- | --- | --- | --- |
| `sim.plant.flux` | 000 | non-draft | committed | |
| `sim.plant.actuation` | 000 | non-draft | committed | |
| `change.relay.pin` (enum) | 000 | non-draft | committed | |
| `gw1.actor.class` (+SimSensorActor/SimRelayActor) | 012 | non-draft | committed (green) | |
| `sim.sensor.component.gt` | 000 | non-draft | `9f9c5d0` | |
| `sim.relay.component.gt` | 000 | non-draft | PENDING (Phase-A) | |

## New MakeModels + CAC bump (Phase-A mini-sweep — pending)

| Word | Ver | Status | Landed | Reviewed by JM |
| --- | --- | --- | --- | --- |
| `spaceheat.make.model` (+GRIDWORKS__SIM_SENSOR, GRIDWORKS__SIM_RELAY_BANK) | 008 | non-draft | PENDING | |
| `component.attribute.class.gt` (refs make.model/008) | 002 | non-draft | PENDING | |

## ActorClass cascade (real types bumped to carry the sim actor classes)

| Word | Ver | Status | Landed | Reviewed by JM |
| --- | --- | --- | --- | --- |
| `spaceheat.node.gt` | 302 | non-draft | committed | |
| `layout.lite` | 014 | non-draft | committed | |
| `new.command.tree` (clean single-node) | 002 | non-draft | committed | |
| `scada.control.capabilities` (folded in place; was limbo) | 001 | non-draft | committed | |
| `gw.nolan.layout` (kept draft) | 000 | draft | committed | |

## Layout-vocabulary sweep (the shared-infra words; landed `6f73174` … `ee9d267`)

| Word | Ver | Status | Landed | Reviewed by JM |
| --- | --- | --- | --- | --- |
| `component.attribute.class.gt` (generic CAC) | 001 | non-draft | `e3cd6d8` | |
| `electric.meter.cac.gt` | 001 | non-draft | `4d58ee6` | |
| `egauge.register.config` | 000 | non-draft | `f68d6f3` | |
| `electric.meter.channel.config` | 000 | non-draft | `e775e57` | |
| `electric.meter.component.gt` | 001 | non-draft | `c6dbc80` | |
| `gw108.gpio.sensor.component.gt` | 001 | non-draft | `a793f88` | |
| `gw108.vdc.relay.component.gt` | 001 | non-draft | `33b3ad6` | |
| `web.server.component.gt` | 001 | non-draft | `5354e4a` | |
| `pico.btu.meter.component.gt` | 000 | non-draft | round-trip (beech) | |
| `i2c.thermistor.channel.config` | 001 | non-draft | nolan round-trip | |
| `i2c.thermistor.reader.component.gt` | 001 | non-draft | nolan round-trip | |
| `gpio.sense.mode` (enum) | 000 | non-draft | `9df37f8` | |
| `gw108.gpio.relay.component.gt` (placeholder) | 001 | draft | committed | |

**Ref-only fixes in the `gw.nolan.layout` draft (no new word — no review row):**
`data.channel.gt` 001→002; `i2c.multichannel.dt.relay.component.gt` 003→004;
`pico.tank.module.component.gt` 000→011; enum ref `heatcall.interpretation` →
`gw1.heat.call.interpretation/000`; `relay.actor.config` axiom pin 002→003.

**Dropped (not minted):** `gw1.scada.device.type.gt` — the CAC→device-type
transition is not happening yet (complex nested config, no fixture).
