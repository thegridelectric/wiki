Status: Draft · Pass 0 · Updated 2026-09-25

# Heat pump comms

What this is: how the scada talks to each heat pump model it commands,
from the vendor's side of the wire: which terminals or bus, which vendor
settings, which documents are authoritative, and what has been proven
against a real unit. One spoke per model. The scada side (hp-boss, the
call relay, the command tree) is in
[`../control-hierarchy.md`](../control-hierarchy.md).

## Two ways in

- **Call contact.** A relay closes a thermostat input on the heat pump's
  controller. The unit keeps its own protections and water laws; the
  scada only says run or stop. Every commanded heat pump starts here, and
  the contact stays as the failsafe path once a bus exists: a dead
  controller opens it and the heat pump stops.
- **Digital bus.** Modbus RTU over RS-485, read and write: setpoints,
  mode, on/off, and the unit's own sensor readings. Some vendors speak it
  natively on the heat pump; others need a vendor accessory that bridges
  their internal bus. `Hydronic.HpCommandNodeName` in the layout names the
  node that takes commands (`hp-odu` for native Modbus, `hp-ctrl-box` when
  a bridge hangs off the control box). No scada Modbus driver exists yet
  (Open).

Vendor facts carry a provenance tag: **[documented]** (vendor manual,
page cited), **[community]** (open-source or forum source), **[told]**
(a person, stated where), **[field]** (observed on our unit, dated).
A claim reaches Verified only when an experiment reads or writes it on a
real unit.

## Spokes

| Model | Site | Doc | Status |
| --- | --- | --- | --- |
| Samsung EHS mono AE055 (control box AE055FEYMCG) | spruce | [`samsung-ae055feymcg.md`](samsung-ae055feymcg.md) | Draft |

## Open

- Vendor landscape and which models have a sanctioned bus path:
  [`../../research/awhp-control-box-landscape.md`](../../research/awhp-control-box-landscape.md);
  a model moves from there into a spoke when we start commanding it.
