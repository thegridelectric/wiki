# Board facts: Rev C against Rev B

Status: Draft · Pass 0 · Updated 2026-11-20

> What this is: the Rev C facts read from Joe's bench code and README,
> stated against the Rev B device-type record. Each fact is a candidate
> for the Rev C record once the bench checklist sees it work.

Sources: `gridworks-hardware/PCBs/KiCad/FullScada1/test_code/app.py`,
[`gw108-revc-readme-joe.pdf`](gw108-revc-readme-joe.pdf).

## Native GPIO (BCM)

| Name | Pin | Dir | Rev B | Notes |
|---|---|---|---|---|
| Zone1..6Whitewire | 17, 27, 22, 10, 9, 11 | in | same | zone heat-call sense |
| Shutdown | 18 | in | same | |
| Valve4Energized | 19 | in | new | 0 = energized; reads 0 with no load on Valve 4 |
| TstatPower | 4 | out | same | |
| Valve4 | 13 | out | new | the one relay driven natively |
| Vdc | 23 | out | same | switched 5 VDC |
| Watchdog | 24 | out | same | |
| PowerOff | 25 | out | same | |
| spare outputs | 1, 12, 16, 20, 21 | out | new | unnamed on the silk |

## Expanders and relays

Two TCA9555 at 0x20 (zones) and 0x21 (plant), on the default bus, as on
Rev B. Register 2 is port 0, register 3 is port 1. Bit positions are
unchanged from Rev B; the names move to the Rev C silk.

| 0x21 reg | bit | Rev C name | Rev B name | Default |
|---|---|---|---|---|
| 2 | 0 | HpDryContact | HeatPumpEnable | |
| 2 | 1 | HeatingElement2 | BufferTop | |
| 2 | 2 | HeatingElement1 | BufferBottom | |
| 2 | 3 | Valve5 | BoilerBufferValve | energized when the backup toggle says tank element |
| 2 | 4 | BoilerIntercept | BoilerIntercept | NC: signal goes to the boiler |
| 2 | 5 | Misc1 | Misc1 | R and COM silk reversed |
| 2 | 6 | Misc2 | Misc2 | R and COM silk reversed |
| 2 | 7 | Pump1 | PrimaryPump | powered from the Zones 24 VAC input |
| 3 | 0 | FcmMisc | FcmMisc | |
| 3 | 1 | Valve1 | IsoValveFailsafe | |
| 3 | 2 | Valve2 | IsoValve | energized by default; the relay turns it off |
| 3 | 3 | Valve3 | DischargeValve | |
| 3 | 4 | Pump2 | StorePump | |
| 3 | 5 | Pump3 | SecondaryPump | |
| 3 | 6 | HeatingElement4 | StoreTop | |
| 3 | 7 | HeatingElement3 | StoreBottom | |

Zone relays on 0x20: reg 2 bits 0..5 are Zone1..6Failsafe, reg 3 bits
0..5 are Zone1..6Scada, as on Rev B.

Valve 4 is energized by default when the backup toggle says boiler. The
toggle's silk labels are reversed and its middle position de-energizes
both Valve 4 and Valve 5; that position is never used.

## ADCs

| Name | Where | Address | Channels | Rev B |
|---|---|---|---|---|
| Thermistors1 | default bus | 0x49 | th1..th4 | "Thermistors" at 0x49 |
| Thermistors2 | default bus | 0x48 | th5..th8 | new |
| Ct | DacMux channel 4 | 0x48 | ct1..ct4 | on the default bus at 0x48 |

Series resistance for the thermistor dividers and the ADC reference stay
to be confirmed on the bench (Rev B record: 5.65 kΩ, 3.3 V).

CT inputs: 470 Ω burden resistors on board, off by default, enabled per
input by a DIP switch whose numbering is reversed (switch 1 is CT4). The
bias voltage is wrong on Rev C, so the range is about 30% short of 1 V
peak-to-peak and the software needs a different bias constant.

## DACs

Three MCP4728 behind the TCA9548A mux at 0x70, each at 0x60: Dac1 on mux
channel 1 (zones 1..3 on channels A..C), Dac2 on channel 2 (zones 4..6),
Dac3 on channel 3 (Pump1, Pump2, Pump3 on A, B, C). As on Rev B.

## Power

Two 24 VAC inputs: Zones feeds the thermostats, the zone outputs and
Pump 1; AUX feeds every other 24 VAC output, the FCM included. One supply
can feed both by bridging the two inputs.

## Errata (Joe's list)

- Thermostat LEDs stay lit without the power-stealing jumpers; 12 mA of
  stealing lights them faintly; 24 mA trips the GPIO input but not a
  failsafe-wired zone relay.
- CT DIP switch numbering reversed; CT bias voltage wrong.
- Backup toggle labels reversed; unusable middle position.
- GPIO 19 reads energized with no load on Valve 4.
- MISC 1 and MISC 2 R and COM labels reversed.
- The FCM DB25 pinout follows the standard long-row-first numbering,
  unlike earlier revs.
