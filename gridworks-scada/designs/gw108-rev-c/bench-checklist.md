# Bench checklist

Status: Draft · Pass 0 · Updated 2026-11-20

> What this is: one table per component class. A row is done when the
> component answers the starter script on spruce, is seen doing its job in
> the house (field), is stated in the Rev C device-type record, and is used
> by the spruce layout. A check mark goes in the cell; the dates are in the
> bench log.

## Do this next

The relay window, with the scada stopped and George off the box. Starter
script first: it drives one bit and nothing else, so the flow or the
contact that follows names the relay. The scada repeats the same
actuations later, under admin on the rolled layout, as the third
column's witness.

1. Start the pico API (`starter-scripts/start_api.sh`, stdout to a file)
   so the dist BTU posts are the flow record; start the zone watch
   (`experiments/2026-11-20-spruce-gw108-revc-bench/runbook.sh` step 3).
2. Thermostats up, one zone at a time: the zone's whitewire input drops
   to 0 in the watch log.
3. Each zone scada relay energized for about two minutes with pin
   readback, dist flow seen, de-energized before the next.
4. The heat pump dry contact, then Valve4 on GPIO 13 with GPIO 19 read
   during.
5. Each confirmed relay fills its cell here and the Rev C column of the
   roster table in [`spruce-layout.md`](spruce-layout.md).

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
  [`images/zones 1 and 2.png`](images/zones%201%20and%202.png). Zone 1
  relay pair: failsafe on, scada on (14:33:23), dist flow 1.6 gpm with
  every thermostat idle, scada off (14:34:38) and flow to 0, failsafe off;
  pin readback matched each command.

## Native GPIO

| Component | Starter script | Field | Device record | Spruce layout |
|---|---|---|---|---|
| Zone1..6Whitewire (17, 27, 22, 10, 9, 11) | ✅ | ✅ zones 1, 2, 4; upstairs (22) not seen, thermostat suspected; 9, 11 unwired | ✅ | |
| Shutdown (18) | ✅ | | ✅ | |
| Valve4Energized (19) | ✅ | | ✅ | |
| TstatPower (4) | | | | |
| Valve4 (13) | | | | |
| Vdc (23) | | | | |
| Watchdog (24) | | | | |
| PowerOff (25) | | | | |

## Zone relays (0x20)

| Component | Starter script | Field | Device record | Spruce layout |
|---|---|---|---|---|
| Zone1..6Failsafe | ✅ zone 1 | ✅ zone 1 | | |
| Zone1..6Scada | ✅ zone 1 | ✅ zone 1 | | |

## Plant relays (0x21)

| Component | Starter script | Field | Device record | Spruce layout |
|---|---|---|---|---|
| HpDryContact | | | | |
| HeatingElement1..4 | | | | |
| Valve1, Valve2, Valve3, Valve5 | | | | |
| BoilerIntercept | | | | |
| Pump1, Pump2, Pump3 | | | | |
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
| Dac3 (pumps 1..3) | ✅ read back | | ✅ | |

## CT ADC (last)

| Component | Starter script | Field | Device record | Spruce layout |
|---|---|---|---|---|
| Ct (mux channel 4, 0x48, ct1..ct4) | ✅ | | | |
