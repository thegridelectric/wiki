Status: Draft · Pass 0 · Updated 2026-10-29

# Arctic MAHRW030ZA defrost (elm)

`DeviceType.ArcticMAHRW030ZA` (sema enum `gw1.device.type`, bound to
`hp-odu` in `tlayouts/elm_gen.py`): the Arctic Heat Pumps R32
high-temperature monobloc, model MAHRW 030ZA/(BEH2)-R32.

What this is: what an Arctic defrost looks like in the scada's channels
at elm, so code reading `hp-odu-pwr` while the call is on can tell a
defrost from a stop. The monobloc has no indoor unit, so `hp-odu-pwr` is
the whole unit. The primary circulator sits outside the monobloc and its
power is not in `hp-odu-pwr`.

Measured from six defrosts in the journal readings, 2026-10-27 20:30 →
2026-10-29 10:00 ET, all between 22:58 and 05:46 with outdoor air around
30–40 °F; the 2026-10-29 05:31 event was traced sample by sample and the
other five match it. Channels: `hp-odu-pwr`, `hp-lwt`, `hp-ewt`,
`primary-flow`, `secondary-flow`. Device facts are from the unit's manual
and Modbus map in `heat-pumps/arctic-high-temp/` (cited as "Man p.<PDF
page>" and "MB p.<PDF page>").

## The sequence

| Phase | Length | `hp-odu-pwr` | Water |
| --- | --- | --- | --- |
| 0. Ramp down | about 80 s | smooth fall from 4.4 to 2.0 kW | lift still positive |
| 1. Switch | 20–40 s | 300–350 W | LWT falls about 13 °F in 13 s and ends 1–3 °F under EWT |
| 2. Defrost run | 1–4.5 min | climbs back to 1.1–1.7 kW and holds | LWT ≈ EWT (lift −1 to +1.5 °F); EWT drifts down about 4 °F |
| 3. Stopped | about 3 min | 25–80 W | primary flow holds at 5.6 gpm |
| 4. Restart | about 3 min to full power | jumps to about 2 kW, ramps to about 4 kW | LWT climbs from about 102 °F |

Heat delivery is near zero for about 9 minutes, and the unit is back at
full power about 13 minutes after the ramp down began.

The 13 °F fall in phase 1 is mostly the heating lift going to zero as the
compressors stop: 13 °F at 5.6 gpm is about 10.7 kW of heat, a COP near
2.4 on 4.4 kW. Only the 1–3 °F undershoot below EWT is heat drawn from the
water.

The draw on the water in phase 2 is small next to the Ecodan at maple,
whose LWT sits about 20 °F under EWT through its reverse cycle. The unit
is a two-stage cascade: "The first heating system is using R32
refrigerant" and "The second heating system is using R515B low pressure
refrigerant" (Man p.10). Each stage has a four-way valve ("on off 1 four
way valve" and "Four way valve", Man p.47; "BIT7: Status of four-way
valve 1" and "BIT8: Status of four-way valve 2", MB p.15). Neither
document names the defrost method. A near-zero lift in phase 2 fits the
R32 stage reversing alone and taking its defrost heat from the exchanger
between the stages. That is an inference until the valve bits are read
over Modbus (OPS-638).

## What starts and ends it

Defrost parameters are user parameters on the bus (MB p.6):

| Reg | Doc text | Default |
| --- | --- | --- |
| 2014 | "Compressor cumulative running time entre deforst" | 45MIN |
| 2015 | "Outdoor coil temperature to enter defrost mode" | -3℃ |
| 2016 | "Maximum defrost time" | 8min |
| 2017 | "External coil temp. to exit defrost mode" | 13℃ |
| 2020 | "Temp. difference between outdoor temp. and coil temp. to length defrost" | 10℃ |

At elm, defrosts came after 47–52 minutes of compressor run time
(`hp-odu-pwr` above 700 W) whether that run took 0.8 h or 3 h of wall
time: the 45-minute default plus the 80 s ramp down. A stretch of 212
run-minutes over the mild day of 2026-10-28 had none, which fits entry
also needing the coil at or below −3 °C. Defrosts of 1–4.5 minutes sit
inside the 8-minute cap. The documents give no post-defrost hold-off;
the 3-minute stop in phase 3 is measured only.

## What follows for the code

- A drop under 400 W while the call is on is a defrost when it follows a
  smooth ramp down from heating power and the unit is back above 1 kW
  within about a minute (phase 2). The unit then stops for about
  3 minutes and restarts by itself.
- hp-watch reads phases 1 and 3 as `HpDetectedOff` and phase 2 as
  `HpDetectedOn`, so hp-boss turns the secondary pump off, on and off
  again across one defrost. Through phase 2 the secondary pump at 4.0 V
  (6.7 gpm) sends about 30 gallons of ~104 °F water into the top of the
  buffer.
- `DEFROST_SIGNATURES` in `gridworks-scada/gw_spaceheat/actors/hp_boss/sensing.py`
  has no Arctic row, so the scada never judges this unit in defrost.

## Open

- Which stages reverse, from 2110 bits 7/8 with compressor bits 1/2, and
  the outdoor coil (2056) against 2015/2017 through a defrost.
- Whether a defrost ever reaches the 8-minute cap in deep cold, and what
  2018/2019 do below −10 °C ambient.
- The primary circulator's draw: it is outside the monobloc, so its power
  is read on its own channel.
