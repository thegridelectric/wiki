# gw108 provisioning

Status: Draft · Pass 0 · Updated 2026-08-10

> What this is: the persistent and semi-persistent configuration a gw108
> board needs before deployment, and the settings decisions behind the
> defaults — the things a fresh board or a board rework must get right.

## ADS1115 thermistor path: 8 SPS, 1 Hz poll, no software averaging

The chosen configuration for the zone-thermistor read path is 1 Hz
polling with single-shot conversions at 8 SPS — the chip's slowest
data rate (SPS = samples per second, set in the config word of every
conversion; 128 SPS is the chip default). At 8 SPS each conversion
integrates ~125 ms inside the chip: hardware averaging with no
software state, no EMA. The data rate is not persistent chip state,
so nothing on the chip needs provisioning — this section records the
decision. Basis (the ads-noise experiment, spruce wired thermistors):
vs 128 SPS raw, 8 SPS cuts electrical noise ~40 % on quiet channels
while faithfully rendering real slow signal — a thermistor mounted
near a fan coil shows *higher* sd at 8 SPS because known real
temperature variation is being caught, which is exactly what a zone
temperature reader is for.

**The SPS ↔ poll-rate coupling.** A chip's channels share its input
mux, so a sweep serializes: sweep time ≈ channels × (1000/SPS +
gated-read overhead) ms — measured 135 ms/read at 8 SPS, 16 ms at
128 (overhead ~10 ms). The operational pair must leave slack: at
8 SPS a 4-channel sweep is ~540 ms of the 1000 ms poll period
(~54 % occupancy); a 2 Hz poll would exceed the period outright and
needs 16 SPS (~290 ms of 500 ms), the fallback if a faster poll is
ever wanted. In sema the coupling is a layout axiom (sweep time ≤
0.6 × the minimum poll period, ~10 ms overhead —
ThermistorSweepFitsPoll, stashed with `gw.nolan.layout`'s deferred
axioms). The chip's supported data-rate menu (8/16/32/64/128/250/
475/860 SPS) is carried as `SupportedDataRatesSps` on the board
record's thermistor interface capability; the operational choice
(8 SPS, 1 Hz) is `DataRateSps` on the reader component plus
`PollPeriodMs` on the zone channels, and must satisfy both the menu
and the axiom (ThermistorReaderMenuMembership).

**One ADS master at a time.** Any bench or diagnostic tool that reads
an ADS SHALL run with the scada (and anything else that reads that
chip) stopped — including the `gwspaceheat-restart` watchdog timer,
which restarts a stopped scada within seconds. Two concurrent readers
re-point the chip's input mux under each other and produce
cross-channel reads: large paired spikes and config-readback
mismatches that look exactly like hardware failure.

## MCP4728 DACs: write EEPROM power-on defaults

Each MCP4728 channel loads its EEPROM value into the output on power-up.
Factory EEPROM is not a safe default: a board power cycle drops every
0-10 V output (pump speed commands) to the factory value until software
re-asserts. Provisioning SHALL write sane power-on defaults — value plus
vref/gain — to EEPROM per channel (`save_settings()` in the gw108 test
code) so a power cycle comes up driving each actuator at a safe speed.
Do this before any workflow that power-cycles boards in the field
(deliberate cycles included: the board's i2c chips run on the pi's
3.3 V rail, so cutting pi power is a power-on reset for every chip —
and a soft `reboot` is not, since the rail stays up).

**The EEPROM is readable, so provisioning is verifiable.** The chip's
24-byte sequential read returns each channel's EEPROM contents (value
+ vref/gain/power-down) alongside its live input register. The scada
SHALL verify at startup: read the EEPROM, compare per channel against
the defaults the component record declares, and on mismatch emit a
note (the provisioned state has drifted or was never written) and
reprogram, then re-verify. The declared defaults live on the gw108
component record — per DAC, per channel: value, vref, gain — which is
what makes the mismatch check possible.
(`starter-scripts/program_dac_eeprom.py` is the hand-run form: it
prints each chip's register + EEPROM state before and after
programming.)

Fleet state (2026-08-10): spruce dac2 — the Z6 zone DAC, carrying the
secondary pump since the rewire — has EEPROM defaults written
(`starter-scripts/program_dac_eeprom.py`, the hand-run form). dac1 is
unwritten; dac3's i2c interface is dead and cannot be programmed.
Remaining boards ride the field-visit checklist (OPS-487).
