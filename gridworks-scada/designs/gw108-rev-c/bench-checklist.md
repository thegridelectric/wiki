# Bench checklist

Status: Draft · Pass 0 · Updated 2026-11-20

> What this is: one table per component class. A row is done when the
> component answers the starter script on spruce, is seen doing its job in
> the house (field), is stated in the Rev C device-type record, and is used
> by the spruce layout. A check mark goes in the cell; the dates are in the
> bench log.

## Do this next

Spruce runs the scada on the Rev C layout since 16:20 (scada
`jm/gw108-revc` at `e9bf4a93`, tlayouts `37b18dc` plus the iso-valve
commit). Next: roll the iso-valve-on-Valve3 layout and repeat the valve
test under admin with the store pump on: charge valve and iso valve
closed gives no store flow (proven 16:36); then the iso valve open with
the charge valve closed, which gave no flow on Valve2, is the witness
that Valve3 is the iso valve. Then release admin, and the third column
of every table below gets its check from the roll. Open after that:
store flow 3.66 gpm with the heat pump loop running against 5.8 gpm
alone; the secondary pump at 4.5 V under admin alone showed 0 W; the
secondary 0-10 V actor belongs under hp-boss (local-control executor,
"Open"); CT1 reads 46 mV RMS under the scada against 27 mV on the bench
at one turn, so the turns want confirming.

Not at spruce: Valve 2, Valve 4, Valve 5, the element relays, Pump 1,
BoilerIntercept, the Misc relays, CT2..CT4. The secondary pump's power
comes from the eGauge; CT1 on the store pump enters the layout only when
the CT word has mux fields.

Legend: an empty cell is not done; ✅ is done; a note names a known fault.

Bench log (spruce, scada stopped):

- 2026-11-20: bus scan shows 0x20, 0x21, 0x48, 0x49, 0x60, 0x70. Native
  inputs read: zones all 1 (idle), shutdown 1, GPIO 19 reads 1 (Valve 4
  de-energized, a load is wired). th1..th4 read 67 to 71 °F; th5..th8 are
  unwired and read 3.296 V. CTs read behind mux channel 4: ct1, ct2, ct4 at
  about 1.05 V (the bias at rest), ct3 at 2.20 V (a load on it). DACs read
  back; Dac2 channel C held 3040 raw from before the import. The DAC
  "starter script" cells mean read back only; a driven 0-10 V output is
  still to be seen.
- 2026-11-20, window 2: thermostats one at a time with the scada stopped.
  Bedrooms drops GPIO 17 (14:15:13), living room GPIO 27 (14:21:34),
  garage GPIO 10 (14:30:44); each call brings dist flow at the Caleffi
  (1.5 to 1.8 gpm one zone, 2.5 gpm two) and flow stops within seconds of
  the release. Upstairs never drops GPIO 22 and lights no board LED;
  George suspects the thermostat. Board LEDs for zones 1 and 2:
  [`images/zones-1-and-2.png`](images/zones-1-and-2.png). Zone 1
  relay pair: failsafe on, scada on (14:33:23), dist flow 1.6 gpm with
  every thermostat idle, scada off (14:34:38) and flow to 0, failsafe off;
  pin readback matched each command. Zones 2, 3, 4 the same (scada on
  14:35:57, 14:38:01, 14:40:07; flow 1.5, 1.8, 1.9 gpm; 0 within seconds
  of scada off). Zone 3 flowing under the relay puts the upstairs fault on
  the thermostat side of GPIO 22.
- 2026-11-20, window 2, FCM: Pump3 (0x21 port 1 bit 5) closes and its
  relay-side LED lights (toggled 14:50 to 14:52, George watching); the
  labelled PUMP 3 LED in the FCM box stays dark and the secondary pump
  does not run with dac1 A at 3040 on the Z1 wire. Cause: the FCM end of
  the DB25 cable is wired to the Rev B alternating-row pinout; Rev C uses
  the standard long-row-first pinout (Joe's errata). Every FCM output
  (Valve 1..4, Pump 2, Pump 3, Misc, both pump 0-10 V pairs) waits on
  the FCM end being rewired to the Rev C pinout. The starter script
  clears both expanders on import: a relay held from one process is
  dropped by the next; keep a hold-and-test in one process.
- 2026-11-20, window 2, AUX: with the FCM end rewired to the Rev C pinout
  for one load at a time, Valve 1 (charge-discharge valve, pins 20 and 8,
  15:06) and Pump 2 (RIB, pins 6 and 19, 15:11) each close with their
  LEDs lit and 0 V across the output pins; the load does not move. The
  AUX 24 VAC IN terminals have nothing wired to them. Rev C feeds every
  non-zone output (pumps, valves, elements, misc, the whole FCM) from
  AUX; the Zones input feeds only the thermostats, the zone outputs and
  Pump 1. The zone side worked all afternoon on Zones alone.
- 2026-11-20, window 2, AUX wired (Zones bridged to AUX): the FCM end
  rewired one load at a time to the Rev C pinout. Store pump on Pump 2
  runs (15:16); with the charge-discharge valve closed it deadheads
  (0.66 gpm blip then 0), with Valve 1 energized it gives 5.8 gpm
  (15:19). Valve 1 travels when energized (15:17). Secondary pump on
  Pump 3 gives 7.8 gpm and the heat pump dry contact starts the heat
  pump, primary flow 10.7 gpm (15:33), Jessica driving from the REPL.
  Valve 4 picked up its default energization when AUX came live: GPIO 19
  went from 1 this morning to 0.
- 2026-11-20, window 2, Pump 3 complete on the DB25: COM 13, 24 VAC 25,
  0-10 V minus 12, plus 24. The secondary pump's speed is Dac3 channel C
  (`set_pump3_analog`), not the Z1 output it had on Rev B.
  Driven from the REPL at 15:49 to 15:50: secondary flow 4.1 gpm at
  2048 raw, 9.3 gpm at 4095, the first driven DAC output witnessed. The
  scale is 400 raw per volt; spruce's declared default is 7.6 V (3040,
  `secondary-010v` in the operational params) and the EEPROM power-on
  from `program_dac_eeprom.py` is 7.55 V (3020), which that script can
  now put on dac3 channel C.
- 2026-11-20, window 3, secondary pump current (George's multimeter on
  the pump supply, Jessica at the REPL): 0.2 A at about 5 V (2000 raw),
  0.6 A at 8.5 V (3400 raw). The SCT-013 on a 470 Ω burden gives 0.235 V
  RMS per amp, so these are 0.05 and 0.14 V RMS at the CT, under the
  0.5 V clipping point; the 470 Ω burden is the right one for this pump.
  At 4095 raw (full scale) the meter reads 0.64 A, so the pump's current
  flattens above 8.5 V: full speed is reached near the top of the 0-10 V
  range and the last 1.5 V buys little. Peak CT signal at this pump is
  about 0.15 V RMS.
- 2026-11-20, window 3, CT1 (16:00 to 16:05, Claude driving from one
  process, REPL stopped): only CT1 is plugged in, on the CT1 terminal,
  DIP switch 4 on (switch numbering reversed, so that is CT1's burden).
  ct2 and ct3 are open inputs and read a flat 1.24 V and 2.07 V whatever
  the secondary pump does. ct1 with the secondary pump running and the
  store pump off: a flat 1.105 V, noise 0.5 mV RMS. With Valve 1
  energized and Pump 2 on, ct1 jumps to a mean of 1.13 V with 41 mV RMS
  about the mean and 0.22 V peak to peak (1.02 to 1.25 V), the same at
  every Dac3 B setting from 1600 to 4095 (the store pump has no 0-10 V
  wire); back to the flat 1.105 V within 3 s of Pump 2 off. CT1 is on
  the store pump and tells on from off by a factor of 80 in RMS. CT1
  was double-wound for this read (two turns). Rewound to one turn and
  rerun at 16:06: 27 mV RMS, 0.15 V peak to peak (1.03 to 1.18 V), two
  reads 8 s apart within 0.1 mV; off-state noise 0.6 mV RMS. One turn
  is the install. The
  waveform is not a sine: the ADS1115 at 860 SPS through the mux gives a
  real conversion every 1.9 ms (about 520 a second, 8 or 9 per 60 Hz
  cycle), and the samples cluster at two levels with short excursions
  to the extremes, the shape of a rectifier-fed ECM pump drawing narrow
  current pulses that the sampling catches only sometimes. A sampled RMS
  is a stable on/off signal but not a current meter; amps from a CT need
  a per-pump calibration against a clamp meter, or faster sampling.
  Samples: `experiments/2026-11-20-spruce-gw108-revc-bench/evidence/ct-window3/`.
- 2026-11-20, window 3, Valve 2 (iso valve): confirmed by George with
  the meter across DB25 pins 9 and 22, Jessica at the REPL. Valve 4 is
  not used at spruce. The secondary pump's power is read on the eGauge,
  so no CT goes on it for now.
- 2026-11-20, 16:20 to 16:47, the roll and admin: see the experiment
  README "Window 4". The iso valve is Valve3, George's wiring; on the
  Valve3 layout (`fd77bfc`, rolled 16:46) the iso valve opens, seen by
  Jessica and George. Admin released after that; spruce runs on local
  control on Rev C from the evening of 2026-11-20.
- 2026-11-20, 16:16:43: the zone watch saw GPIO 22 (upstairs) drop to
  0 for 2 s with nobody at that thermostat, the first call seen on it.
  Upstairs can call; the morning's "thermostat suspected" stands only
  for why it did not call when asked.

## Native GPIO

| Component | Starter script | Field | Device record | Spruce layout |
|---|---|---|---|---|
| Zone1..6Whitewire (17, 27, 22, 10, 9, 11) | ✅ | ✅ zones 1, 2, 4; upstairs (22) seen once at 16:16; 9, 11 unwired | ✅ | |
| Shutdown (18) | ✅ | | ✅ | |
| Valve4Energized (19) | ✅ | | ✅ | |
| TstatPower (4) | | | | |
| Valve4 (13) | | not used at spruce | | |
| Vdc (23) | | | | |
| Watchdog (24) | | | | |
| PowerOff (25) | | | | |

## Zone relays (0x20)

| Component | Starter script | Field | Device record | Spruce layout |
|---|---|---|---|---|
| Zone1..6Failsafe | ✅ zones 1..4 | ✅ zones 1..4; 5, 6 unwired | | |
| Zone1..6Scada | ✅ zones 1..4 | ✅ zones 1..4; 5, 6 unwired | | |

## Plant relays (0x21)

| Component | Starter script | Field | Device record | Spruce layout |
|---|---|---|---|---|
| HpDryContact | ✅ | ✅ heat pump starts, primary flow 10.7 gpm | | |
| HeatingElement1..4 | | | | |
| Valve1, Valve2, Valve3, Valve5 | ✅ Valve1, Valve2 | ✅ Valve1 charge-discharge valve travels; Valve3 iso valve (George's wiring; Valve2's relay took under admin with no effect on the store loop); Valve2, Valve5 unused | | |
| BoilerIntercept | | | | |
| Pump1, Pump2, Pump3 | ✅ Pump2, Pump3 | ✅ Pump2 store pump 5.8 gpm with Valve1 open; Pump3 secondary pump 7.8 gpm; Pump1 unused | | |
| Misc1, Misc2, FcmMisc | | | | |

## Thermistor ADCs

| Component | Starter script | Field | Device record | Spruce layout |
|---|---|---|---|---|
| Thermistors1 (0x49, th1..th4) | ✅ | | ✅ | |
| Thermistors2 (0x48, th5..th8) | ✅ | | ✅ | |

## DACs

| Component | Starter script | Field | Device record | Spruce layout |
|---|---|---|---|---|
| Dac1 (zones 1..3) | ✅ read back | | ✅ | |
| Dac2 (zones 4..6) | ✅ read back | | ✅ | |
| Dac3 (pumps 1..3) | ✅ channel C driven | ✅ secondary pump 4.1 gpm at 2048, 7.8 at 3040, 9.3 at 4095 | ✅ | |

## CT ADC (last)

| Component | Starter script | Field | Device record | Spruce layout |
|---|---|---|---|---|
| Ct (mux channel 4, 0x48, ct1..ct4) | ✅ | ✅ ct1 store pump on/off, 27 mV RMS on, one turn; ct2 on the secondary pump, one turn, read under the running scada with `starter-scripts/ct_waveform.py` (20:11 to 20:13): raw peak about DC 342, 161, 82, 39, 337 mV at 193, 80, 42, 22, 191 W on the eGauge, peak/power within 8% of 1.8 mV/W; the current is pulse-shaped (crest factor 2.8, a 60 Hz fit explains under half the variance), so the reading wants a peak or sampled-RMS detector; resting DC 1.64 V on ct1 and ct2 with the scada up; ct3, ct4 unwired. Workbook: `scratch/2026-11-20-spruce-ct2-waveform.xlsx` | | |
