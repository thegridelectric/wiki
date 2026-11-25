# The Gw108 Rev C board

Status: Verified · Pass 0 · Updated 2026-11-24 · Reviewed 2026-11-20@a9a18a2 (`experiments/2026-11-20-spruce-gw108-revc-bench/`)

> What this is: the Gw108 Rev C scada board as spruce runs it: its
> device-type record, what spruce wires to it, the facts a build has to
> know, and the bench witness behind each. Board-resident components in
> general are `hardware-layout.md` "I²C and board-resident components".

Spruce runs a Gw108 Rev C; its record is `Gw108RevC` in `gw1.device.type`,
authored at `tlayouts/src/tlayouts/device_types/gw108.revc-gw1.scada.device.type.gt-000.json`.
Every fact the record states for a part spruce uses was seen working on the
spruce bench through `starter-scripts/gw108_test_code.py` with the scada
stopped, the actuation witness being the TCA9555 input registers, which
read the pin level back for the output ports. Parts spruce leaves unwired
(Valve 2, Valve 4, Valve 5, the four heating elements, Pump 1,
BoilerIntercept, the Misc relays, CT3 and CT4) stand in the record on the
board's README and bench code alone.

## What the board has

Two TCA9555 expanders on the default bus, active
high: 0x20 is the zones (port 0 bits 0..5 Zone1..6Failsafe, port 1 bits
0..5 Zone1..6Scada) and 0x21 the plant, under the Rev C silk names at these
bits: port 0 HpDryContact, HeatingElement2, HeatingElement1, Valve5,
BoilerIntercept, Misc1, Misc2, Pump1; port 1 FcmMisc, Valve1, Valve2,
Valve3, Pump2, Pump3, HeatingElement4, HeatingElement3. Native GPIO (BCM):
inputs Zone1..6Whitewire on 17, 27, 22, 10, 9, 11, Shutdown 18,
Valve4Energized 19; outputs TstatPower 4, Valve4 13, Vdc 23 (the switched
5 V bus), Watchdog 24, PowerOff 25. Two thermistor ADS1115 at 3.3 V with
5.65 kΩ series resistance: Thermistors1 at 0x49 (th1..th4) and
Thermistors2 at 0x48 (th5..th8). Three MCP4728 at 0x60 behind the TCA9548A
`DacMux` at 0x70: Dac1 on mux channel 1 (zones 1..3), Dac2 on 2 (zones
4..6), Dac3 on 3 (Pump1..3 on A..C). The CT ADS1115 `Ct` at 0x48 sits
behind `DacMux` channel 4, which the record states with the capability
word's `MuxName` and `MuxChannel`, and the board word's axiom 4 checks the
CtAdc against `Muxes` as it checks each DAC.

## Spruce's use of it

HpDryContact is the heat-pump call; Pump2 the
store pump; Pump3 the secondary pump, with its 0-10 V on Dac3 channel C;
Valve1 the charge valve; Valve3 the iso valve. CT1 clamps the store pump
and CT2 the secondary pump, one turn each. The secondary pump's power
stays on the eGauge.

## Facts a build has to know

Valve 4 is the one natively driven relay;
GPIO 19 reads 0 when it is energized, and reads 0 with no load on it, so
the reading means something only with a valve wired. The backup toggle
`SW1` sets which of Valve 4 and Valve 5 is powered at rest (boiler or tank
element); its middle position de-energizes both and is never used, and a
layout that states the backup kind can check the toggle through GPIO 19
before any relay actuates. Two 24 VAC inputs: Zones feeds the thermostats,
the zone outputs and Pump 1; AUX feeds every other output, the FCM
included; one supply feeds both by bridging them, as at spruce. The FCM
DB25 is numbered long row first; a cable end built to the alternating-row
convention puts an output on another FCM terminal, which is the first
thing to check on a board swap. The CT inputs have a 470 Ω burden per
input on the board, enabled by a DIP switch numbered in reverse (switch 1
is CT4); the bias node is off, so the range is about 30 % short of 1 V
peak to peak. Silk errata: the Misc1 and Misc2 R and COM labels are
reversed; the backup toggle labels are reversed; thermostat LEDs stay lit
without the power-stealing jumpers.

## Bench witness

Each zone thermostat drops its whitewire
GPIO on a call and brings distribution flow at the Caleffi (1.5 to 1.9 gpm
one zone, 2.5 gpm two); zones 1 to 4 each flow under their scada relay
with the failsafe energized and stop within seconds of release.
HpDryContact starts the heat pump (primary flow 10.7 gpm). Pump2 gives
5.8 gpm with Valve1 open; Pump3 7.8 gpm, and 4.1, 7.8 and 9.3 gpm at Dac3
raw 2048, 3040 and 4095. CT1 reads 27 mV RMS with the store pump on at one
turn; pump current is pulse shaped (crest factor 2.8), so a CT reader
wants a peak or sampled-RMS detector, and a sine assumption misreads it.
Zone 3's whitewire never dropped, with the relay path proven, which puts
that fault on the thermostat side of GPIO 22.

## Open

Whether the simulated twin `SimGw108` follows Rev C or stays on
the Rev B record. The CT clamp vocabulary and the per-channel CT config
(OPS-714). The CT bias and the 10 µF `1V65` fix (starter-scripts executor
"The gw108 CT chain").
