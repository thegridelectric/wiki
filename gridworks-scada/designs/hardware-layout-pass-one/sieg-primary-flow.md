# Siegenthaler / primary-flow behavior test (spoke — deferred)

Status: Accepted · Pass 1 · Updated 2026-06-27 · Linear: OPS-407

> What this is: the deferred behavior test for the `sum`/topology + tank-calibration work. The
> `FlowTopology` structure landed; the EDD bar that verifies it rides the sim plant / `ScadaLiveTest`
> and so **waits for the simulated-plant focus** ([OPS-40](https://linear.app/gridworks/issue/OPS-40))
> — it cannot be verified before it. The minimal sim-run ([`sim-run.md`](sim-run.md)) is the precursor.

## The landed structure

`gw.house0.hydronic` carries `SiegLoopPlumbed` (was `FlowManifoldVariant`), `UseSiegLoop`, and
`PrimaryFlowSource` (`Measured` | `DerivedSiegSum`), with the source⟶channel agreement axiom. The three
configs the code must handle:

| home | `SiegLoopPlumbed` | `UseSiegLoop` | `PrimaryFlowSource` |
|------|---|---|---|
| oak/elm/fir | false | false | Measured |
| beech | true | false | Measured |
| maple | true | true | DerivedSiegSum |

## The three configs under test (all MUST pass)

| # | config | source | assert |
|---|--------|------|------|
| 1 | no loop (oak/elm/fir) | Measured (own meter) | `primary-flow` DataChannel arrives intact; no derivation runs |
| 2 | loop, not controlled (beech) | Measured (`primary-btu`) | `primary-btu` emits `primary-flow` directly as a DataChannel |
| 3 | loop, controlled (maple) | DerivedSiegSum | `sieg-btu`→`sieg-flow` + `sieg-send`→`sieg-send`; the `sum` strategy emits `primary-flow = sieg-send + sieg-flow` |

**Config 3 recipe:** load the maple-shaped layout; confirm `primary-flow` is a `sum` DerivedChannel
(`InputChannelNames=[sieg-send, sieg-flow]`, `OutputUnit=GpmX100`) and **absent** from DataChannels.
Feed `sieg-btu` → `sieg-flow`; feed `sieg-send` → `sieg-send`; assert `derived_generator` emits
`primary-flow = sieg-send + sieg-flow`. Edge cases: only one input seen → no emission (or a defined
partial — pin it down); one-fresh-one-cached → uses the cached latest
(`self.data.latest_channel_values`).

**Also exercise the affine tank-calibration path (unverified end-to-end).** Feed `api_tank_module`
device readings (`*-depth{n}-device`, WaterTempCTimes1000) through `handle_affine` and assert the
calibrated `*-depth{n}` (FahrenheitX100) equals `M*x + B` for a **non-zero B** — the suite has only ever
run `B=0` (identity), so the v001 `affine` math has no test yet.

**Compliance tests WAIT for the data-classes → sema-types transition** — "fully compliant" is defined by
the axioms being lifted into sema, so writing the assertions now chases a moving target. The layout
*fixtures* are durable and fine to shape now; the *assertions* follow the sema authority. The behavior
test rides `ScadaLiveTest` (`tests/utils/scada_live_test_helper.py`, in-process LTN↔SCADA, no broker;
see [`../../executor/testing.md`](../../executor/testing.md) "The harness"); the simulated plant is the
device-reading source that feeds it.
