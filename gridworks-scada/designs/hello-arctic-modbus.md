Status: Draft · Pass 0 · Updated 2026-10-29 · Linear: OPS-638
**EDD: yes** each experiment is Verified only when it has run against elm's real Arctic over its RS-485 port and the capture is kept.

# hello-arctic-modbus

| Unit | Make / model | Enum | Layout node |
| --- | --- | --- | --- |
| Monobloc | Arctic Heat Pumps MAHRW 030ZA/(BEH2)-R32 | `DeviceType.ArcticMAHRW030ZA` | `hp-odu` |

What this is: the first Modbus conversation with elm's Arctic, starting
with reads only. The scada knows the unit today from `hp-odu-pwr` and the
water temperatures; the unit's own registers say directly what those
channels only suggest: defrost, which compressor is running, the coil
temperature, protections. The register map is read in
`heat-pumps/arctic-high-temp/arctic-high-temp-modbus.md`, from the
manual and Modbus PDFs beside it (cited here as "Man p.<PDF page>" and
"MB p.<PDF page>"). The defrost as the scada sees it is in
[`../executor/heat-pump-signatures/defrost-signatures/arctic-high-temp.md`](../executor/heat-pump-signatures/defrost-signatures/arctic-high-temp.md).

Transport, from the map: Modbus RTU over RS-485 at 2400 baud, 8N1, slave
address 1–16 on DIP switch SW2; function 03 reads, 06/16 write. Every
register is one 16-bit integer word. The doc does not say how negative
temperatures are encoded.

**▶ Do this next: experiment 1.**

## Experiment 1: read the settings once

Read 2000–2039 and record them before anything else. The values that
matter first:

| Reg | What | Doc default |
| --- | --- | --- |
| 2001 | system mode | "must be 1, other modes are unstable" |
| 2003 | heating setpoint | |
| 2010 | heating start "return difference" | 5 |
| 2014 | "Compressor cumulative running time entre deforst" | 45MIN |
| 2015 | "Outdoor coil temperature to enter defrost mode" | -3℃ |
| 2016 | "Maximum defrost time" | 8min |
| 2017 | "External coil temp. to exit defrost mode" | 13℃ |
| 2018 / 2019 | extended defrost interval below an ambient | -10℃ / 45MIN |
| 2020 | "Temp. difference between outdoor temp. and coil temp. to length defrost" | 10℃ |
| 2027 | maximum water temperature | 55 °C |

Pass: every register reads, and 2014–2017 match the defaults or the
differences are recorded. The measured defrost cadence (47–52
run-minutes) assumes the 45-minute default.

## Experiment 2: log through a cold night

Poll the status block (2050–2120) every 10 s through a night with
outdoor air near freezing, beside the journal's `hp-odu-pwr`, `hp-lwt`
and `hp-ewt`. The registers that settle the open questions:

| Reg | What |
| --- | --- |
| 2110 bits 1/2, 7/8 | compressors 1/2 on; "BIT7: Status of four-way valve 1", "BIT8: Status of four-way valve 2" (MB p.15) |
| 2110 bits 3–5, 2064 | fan state and speed |
| 2110 bits 9/10, 12 | crankcase heaters, chassis heater |
| 2056 | inverter-stage outdoor coil temperature |
| 2072 | fixed-speed stage coil temperature |
| 2055 / 2057 | inverter-stage discharge / suction |
| 2068 | inverter compressor actual frequency |
| 2074 | fixed-speed compressor current |
| 2050 / 2051 / 2052 | water inlet / outlet, ambient |
| 2111–2117 | faults and protections |
| 2118 bit 5 | flow switch |

There is no defrost flag and no operating-state word in the map. A
defrost reads as a four-way valve reversed while a compressor runs.

Pass: each defrost in the journal (the five-phase `hp-odu-pwr` sequence)
lines up with a valve reversal, and the log answers:

- Which stages reverse. Only valve 1 (the R32 stage) fits the small draw
  on the water in phase 2.
- Whether 2056 crosses 2015 (−3 °C) at entry and 2017 (13 °C) at exit.
- What the unit is doing in the 3-minute stopped phase after a defrost
  (fan, valves, heaters).
- Whether any protection bit sets during the events read as defrost.

## Experiment 3: the slow start

One call on 2026-10-28 04:54 took 6 minutes to start against the usual
65 s. The documented candidate is 2010, the heating start "return
difference", default 5: the compressor waits until the controlled water
is 5 °C under setpoint. The manual says only "The water pump should
start immediately, and the compressor should start shortly after" (Man
p.27). Log a call that starts with warm return water; pass when the log
names which temperature the band acts on, or shows the delay comes from
something else (crankcase preheat on 2110 bit 9, a restart timer).

## Open

- **The primary circulator's draw.** The circulator is outside the
  monobloc, and the spec says "The power/current input does not include
  water pump power/current input" (Man p.11). The manual's recommended
  pump draws 150–197 W (Man p.12). George to confirm the circulator's
  make and model at elm, and that the eGauge CT on it reads its draw
  correctly.
- Who wires the RS-485 port at elm, to which pi, and the SW2 address.
- Which writes are safe to try after the reads (the defrost parameters
  2014/2015 are writable); none are planned in this design.
