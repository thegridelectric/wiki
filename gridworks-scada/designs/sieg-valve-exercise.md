# Sieg valve exercise (design — basic stub)

Status: Draft · Pass 0 · Updated 2026-06-10 · Linear: OPS-396

> What this is: move the sieg valve on a schedule over the summer so it is
> less likely to seize up. Basic stub; cadence and guards are the design
> work.

## Precedent

`gw_spaceheat/actors/procedural/` — ProceduralHost plus the pump
doctor/monitor pattern (e.g. `dist_pump_doctor.py`: procedural,
non-transactive, bounded attempts, Glitch on failure). A
**SiegValveExerciser** belongs in that family: periodically run the valve
through a sweep and return it to the posture position.

## Open

- Cadence (daily? weekly?) and sweep range (full 70 s travel vs partial).
- Return-to-posture: ends at the position the sieg-summer-posture design
  dictates (open, in summer).
- Guards: only while local control is Standby? never during a dispatch
  contract? (same non-transactive constraint family as the oil-boiler
  diagnostic, [OPS-215](https://linear.app/gridworks/issue/OPS-215)).
- Seizure signature: motion commanded but no flow/temp response → Glitch /
  alert, so a stuck valve is found in July, not at first heat call in
  October.
