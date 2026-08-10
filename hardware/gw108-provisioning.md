# gw108 provisioning

Status: Draft · Pass 0 · Updated 2026-08-06

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
temperature reader is for. The 8 SPS gated-read cost bounds a
4-channel sweep at ~2 Hz — ample for the 1 Hz poll.

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

Fleet state: spruce's DACs have not had EEPROM defaults written yet —
that step is on the field-visit checklist (OPS-487).
