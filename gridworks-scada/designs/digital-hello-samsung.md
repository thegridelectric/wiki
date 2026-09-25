Status: Draft · Pass 0 · Updated 2026-09-25 · Linear: OPS-559
**EDD: yes** six experiments on spruce's real Samsung; each is Verified only when it has run on the unit and its record is kept.

# digital-hello-samsung

| Unit | Make / model | Serial | Layout node |
| --- | --- | --- | --- |
| Outdoor unit (monobloc) | Samsung AE055FCYDCG | 1AW2PAFY600005K | `hp-odu` |
| Indoor control box | Samsung AE055FEYMCG | 1AW3PAOY600002Y | `hp-ctrl-box` |

What this is: a series of experiments taking the scada from on/off
control of spruce's Samsung EHS mono (ODU AE055FCYDCG, control box
AE055FEYMCG) toward continuous control: the scada sets pump speed, caps
the compressor, and reads the unit's own data. The call contact stays the
on/off authority throughout. Device facts and their sources are in
[`../executor/heat-pump-comms/samsung-ae055feymcg.md`](../executor/heat-pump-comms/samsung-ae055feymcg.md)
("Pump speed", "Compressor cap (FR control)", "Modbus via MIM-B19N",
"S-NET Pro service tool"); local copies of the manuals are in
`heat-pumps/samsung-ae055/`.

The control hypothesis the experiments test: the call contact says run or
stop, FR control (experiment 2) caps how hard, SG Ready step-up
(experiment 6) or a Modbus write (experiment 4) raises the leaving-water
target when our store should take more heat, and the MIM (experiment 3)
reads the unit's own state.

Before any FSV change, photograph every FSV screen (or, once experiment 5
is done, export the set from S-NET).

## Experiment 1: the scada sets pump speed

The control box's pump speed chases Tw2 − Tw1 and swings whenever the
plant moves the entering temperature. Take speed away from it while it
keeps deciding when the pump runs.

- **Setup.** Read the pump's nameplate (make, model) and its datasheet:
  PWM profile (heating or solar), signal voltage and frequency, and what
  it does with no signal. Choose the scada's PWM source (the gw108 has
  0–10 V DACs, so a 0–10 V-to-PWM converter, or a Pi PWM pin with level
  shifting). Pick a speed floor that keeps `primary-flow` above 1.8 gpm
  with margin.
- **Run.** Breakers off; unplug the pump's PWM lead from CNS001 and wire
  it to the scada's PWM source (never drive into CNS001 or CNS002); set
  FSV 4051 = 0. Step the speed through several levels across a run and a
  defrost.
- **Record.** `primary-flow`, `hp-lwt`, `hp-ewt`, `hp-idu-pwr`,
  `hp-odu-pwr` against commanded PWM; any E911; what the pump does when
  the scada's signal is removed.
- **Done when.** Flow follows the commanded PWM, the Samsung runs and
  defrosts without faults, and a lost signal leaves the pump at a safe
  speed.

## Experiment 2: the FR control input caps the compressor

- **Setup.** Wire a scada 0–10 V output to CNS003 "FR_CONTROL" (pin 1
  signal, pin 2 GND), breakers off; set FSV 5051 = 1.
- **Run.** During a steady run, step the voltage (for example 10, 5, 0 V)
  and hold each long enough for power to settle.
- **Record.** `hp-odu-pwr` and `hp-lwt` at each level; whether the panel
  shows "DR"; behaviour at 0 V (50 %) and with the wire removed.
- **Done when.** Compressor power tracks the voltage repeatably and the
  unit returns to normal when the signal is removed or 5051 is reset.

## Experiment 3: the MIM-B19N reads the unit

- **Setup.** Confirm on the unit that the outdoor main PCB's connector ①
  (R1/R2) and ⑤ (DC 12 V) take the MIM's supplied cables; photograph.
  Find the touch-panel setting for the indoor unit's "Use of central
  control" (E604 if off).
- **Run.** Breakers off; mount the MIM at the outdoor unit, cable R1/R2
  and 12 V, set an address; run RS-485 A/B to the spruce Pi through a
  USB-RS485 adapter (9600 8E1). Poll register 1 until tracking completes,
  then read the status registers. Write NASA message IDs into the
  6000/7000 config registers for points the table lacks (compressor
  frequency 0x8238 first).
- **Record.** Every register read against the scada's own channels
  (`hp-lwt`, `hp-ewt`, `hp-odu-pwr`, `oat`) and the defrost register
  against
  [`../executor/heat-pump-signatures/defrost-signatures.md`](../executor/heat-pump-signatures/defrost-signatures.md).
- **Done when.** The Pi reads status, temperatures, defrost and
  compressor frequency that agree with the scada's channels. No writes.

## Experiment 4: testing the leaving-water target

The control box picks its leaving-water target one of two ways. In Auto
the water law sets it from outdoor temperature ("When Water Law is
active, the target supply water temperature will be determined
automatically depending on the outdoor temperature"); in Heat, the
working assumption is a fixed target set by the user. The water law's
heating FSVs (MIM-E03FN manual "Water Law for Heating
(FSV#2011~2041)"; cooling has a matching set, 2051–2081):

| FSV | What it sets | Default |
| --- | --- | --- |
| 2011 | Cold end of the outdoor range | −10 °C (range −20 to 5) |
| 2012 | Warm end of the outdoor range | 15 °C (range 10 to 20) |
| 2021 / 2022 | Water law 1 (floor): water-out target at the cold / warm end | 40 / 25 °C |
| 2031 / 2032 | Water law 2 (FCU / radiator): the same | 50 / 35 °C |
| 2041 | Which law heating uses: 1 = WL1 floor, 2 = WL2 FCU/radiator | 1 |

**Spruce's existing FSV 2091 and the water law.** Spruce runs with FSV
2091 = 1 (external thermostat), and under thermostat operation the
target water temperature follows the water law named in 2041 (heating)
or 2081 (cooling): "Types of WL used by room thermostat operation will
follow the FSV settings defined in #2041 (heating) and #2081 (cooling)
respectively" (installer guide PDF p.136). The same note allows a user
shift of the target within −5 to +5 °C during thermostat operation.
Spruce's call contact closes B21, the zone-1 *cooling* input, so which
curve sets the target on a call depends on the unit's mode: the heating
law (2041) or the cooling law (2081). Reading the zone's mode and the
current 20xx values off the panel (Setup, below) says which target the
unit aims for today.

- **Setup.** Experiment 3 done (the Pi reads the MIM). Read off the
  touch panel: the zone's mode, the current water-out target, and FSVs
  2011–2041 and 2081.
- **Run.**
  1. *Clarify the two targets.* With the call contact closed, put the
     zone in Auto, then in Heat, at the panel. In each, read the MIM's
     "Water-out set temperature" register and `hp-lwt`: Auto should
     track the water law at the current `oat`, Heat a fixed value set
     at the panel.
  2. *Write the fixed target.* In Heat, write the water-out set
     temperature register (EHS heat 15–65 °C, °C × 10), read it back,
     and watch `hp-lwt` move toward it; check what the panel shows. Try
     the same write in Auto and record whether it is ignored,
     overwritten or takes effect.
  3. *Write the mode.* Write the mode register (0 Auto, 1 Cool, 4 Heat)
     and read it back; confirm the panel follows. Cool only with the
     call contact open, then straight back to Heat.
- **Record.** Every write and read-back with timestamps, `hp-lwt`,
  `hp-ewt`, `hp-odu-pwr`, the panel's display, and anything the panel
  or MIM overwrites. Write only on change, 10 ms or more after the
  previous response.
- **Done when.** We know which mode uses the water law and which a
  fixed target, whether the MIM can set that target, and whether it can
  switch Auto, Heat and Cool, with the unit back in its starting mode
  and target afterward.

## Experiment 5: the S-NET laptop

- **Setup.** A MIM-C02N (borrowed from F.W. Webb or bought); a Windows
  laptop with the Prolific USB-serial driver, then S-NET Pro 2
  (www.DVMdownload.com).
- **Run.** Breakers off; TX+ to F1, TX− to F2 at the control box;
  re-energize; connect.
- **Record.** Firmware versions, the live point list, an FSV export
  (XML), and the NASA.ptc message list from the S-NET install.
- **Done when.** S-NET shows the unit live and the FSV export is saved
  in `heat-pumps/samsung-ae055/`.

## Experiment 6: SG Ready step-up raises the target

FR control only lowers the compressor's ceiling; below it the unit's
own water law sets how hard it runs. SG Ready step-up is the hardwired
lever the other way: it raises the unit's leaving-water target, so the
heat pump delivers hotter water into our store and usually runs harder
to do it. Whether power actually rises depends on the entering
temperature, flow and the unit's own limits; the experiment measures it.
The MIM's water-out set temperature register (experiment 4) would set
the same target directly and in 0.1 °C steps; SG Ready is the hardwired
version that needs no MIM.

- **Setup.** Two scada relays as dry contacts on the control box's
  low-voltage strip: signal 1 on terminals 1–2, signal 2 on 3–4. Set FSV
  5091 = 1 with both contacts open (normal operation); note FSV 5092
  (heating shift, default 2 °C, 2–5 °C) and 5093 (DHW shift).
- **Run.** During a steady heating run, close signal 2 alone (one step
  up), hold, then close both (two steps up), then open both. Signal 1
  alone is forced thermo off; the scada never closes it except to test
  that mode on purpose.
- **Record.** `hp-lwt`, `hp-ewt`, `hp-odu-pwr` at each mode; what the
  touch panel shows; how the step-up interacts with the FSV 2091 call
  contact (does it change anything while the contact is open?).
- **Done when.** One and two steps up raise the leaving-water target by
  the FSV 5092 shift and power rises with it, and opening both contacts
  returns the unit to normal.

## Open

- An added pump instead of taking over the built-in one's PWM: the
  control box's pump output enables it, the scada sets its speed, the
  flow sensor still proves flow. The control box stays either way: the
  outdoor unit needs it on F1/F2 (E101), and it holds the flow sensor,
  the water temperatures and freeze prevention (E908/E909).
- Modbus writes beyond experiment 4 (DR, FSVs) and how all writes share
  on/off authority with the FSV 2091 contact.
- Whether the UK-bought MIM-B19N behaves the same on the US AE055.
- Layout: `Hydronic.HpCommandNodeName` names `hp-ctrl-box` for the MIM,
  which physically sits at `hp-odu`.
