# spruce-egauge-register-map

Status: Draft · Pass 0 · Updated 2026-08-04 · Linear: OPS-483

**EDD: no** field fix + config correction; verified by a witnessed
heat-pump run showing plausible nonzero watts in the analytics DB, not a
standalone experiment.

> What this is: fix the spruce eGauge's HP power registers reading
> constant 0 through the scada — the pipeline works end-to-end (scada →
> S3 reports → analytics DB since the 08-03 layout deploy); the fault is
> device-side (register map and/or CT landings).

## Established (2026-08-04)

- `hp-ctrl-box-pwr` and `hp-odu-pwr` flow end-to-end but every reading
  is 0 — including overnight 08-03→04 while the primary pump ran
  (3–4.8 GPM by flow meter).
- The eGauge's lifetime counter for `06-hp-ctrl-box` is nonzero
  (3.07 kWh — that CT/register accrued at some point); `09-hp-odu` has
  never accrued (0.000 kWh — CT dead or not landed).
- The device's register list has been edited (deleted slots, shifted
  device ids), so the layout's modbus addresses (9010 ctrl-box, 9014
  hp-odu, 9016/9018 economy legs) may no longer match the device's map.

## Plan

1. With the primary pump running, compare live modbus reads against the
   eGauge's own `?inst` rates register-by-register — pins the true
   address map in one pass.
2. Correct the layout gens if addresses moved (tlayouts actual-spruce
   `gen_spruce.py` + `spruce_sema_gen.py`), regen, redeploy.
3. Verify/land the hp-odu and economy CTs at the panel (field).

Done-when: `hp-ctrl-box-pwr` and `hp-odu-pwr` report plausible nonzero
watts in the analytics DB during a witnessed heat-pump run.
