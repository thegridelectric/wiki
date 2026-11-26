# Katahdin boiler intercept

Status: Draft · Pass 0 · Updated 2026-11-26 · Linear: [OPS-725](https://linear.app/gridworks/issue/OPS-725)

**EDD: no** verified by the Katahdin fmu tests: with every relay at rest a
cold boiler fires, with the intercept relay energized it does not, and the
energy balance closes in both.

> What this is: the plan to give the simulated Katahdin plant a boiler that
> fires and an intercept relay that stops it, so the scada's boiler backup
> can be coded against the plant. It follows the first merge of the plant
> (gridworks-terminalasset PR 6) and does not gate it.

## The gap

In the field, a Katahdin's oil boiler fires on its own aquastat. The Gw108
`BoilerIntercept` relay is normally closed on two wires to the boiler's TT
terminals. At rest the aquastat signal passes to the boiler. Energized, the
scada has interrupted it and the boiler stays off. `gw.boiler.backup` names
the relay `InterceptRelayName`, and `gw.katahdin.layout` axiom 35 requires
its de-energized state to be `Boiler`.

In the plant, the Katahdin boiler is water and iron on its branch behind
V5, with no burner (`modelica/KatahdinComponents.mo:223`,
`modelica/Katahdin.mo:355`). No model input exists for the relay, and
`state_effects` in `src/gwta/katahdin.py` has no row for
`boiler-intercept-relay`. So a simulated Katahdin's boiler is always cold,
and the scada's intercept relay changes nothing.

## Proposed

1. **The Katahdin boiler becomes `Hydronic.Boiler`**, the block the Beech
   plant uses: a burner that fires while it is called and its water is
   below its aquastat setting.
2. **The plant gets a `boilerScadaControl` input** with Beech's meaning: 0
   the boiler's own aquastat, 1 the scada, which keeps it off.
   `katahdin.py` maps `boiler-intercept-relay` to it: `Boiler` is 0,
   `Scada` is 1.
3. **Burner parameters start as Beech's placeholders.**
4. **Tests.** A cold boiler fires at rest, stays off with the relay
   energized, and the energy balance closes in both.

## Open

- What moves water through the boiler at a Katahdin while it fires. To
  read from the Gw110 schematic.
- Whether larch senses boiler power. It has no channel for it today.
- Whether both Katahdin models get the boiler, or only the components
  plant once it is the one the FMU is built from.
