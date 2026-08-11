# gw108 board documentation (spoke)

Status: Draft · Pass 0 · Updated 2026-08-11 · Linear: OPS-392

> What this is: spruce-unlimbo spoke holding the gw108 board facts the relay
> port needs — schematic-verified signal chains, the expander map, and the
> relay naming/state-machine decisions they feed. Working notes while the
> design is alive; on completion the machine-readable facts distill into the
> layout board record / sema device-type words, and the electrical narrative
> goes to component documentation (home under discussion — Drive today).
> Schematic source: `gridworks-hardware/PCBs/KiCad/FullScada1/Gw108_RevC/`.

## The zone signal chain (schematic-verified 2026-08-06, RevC)

Each zone's wall-thermostat white wire enters on the thermostats sheet and
splits two ways:

- **Sense:** an optocoupler (`24vac_optocoupler` module) drives
  `NZONE<n>_W_3V3` to a pi GPIO — active-low, so **GPIO 0 = thermostat
  calling, 1 = idle**. This matches the scada layout's
  `HeatCallInterpretation.DigitalZeroIsActive`.
- **Pass-through:** the same 24 VAC line exits as `ZONE<n>_W_24VAC`, wired
  on the top sheet into the zone-relays sheet as `TSTAT<n>_W`.

On the zone-relays sheet each zone has three `signal_relay` SPDT modules:
`Z<n>_FailSafe`, `Z<n>_OnOff`, `Z<n>_LED` (indicator). The FailSafe relay
selects the zone's call source — **NC (de-energized) = the wall thermostat's
line, NO (energized) = the OnOff relay's switched 24 VAC** — and its output
`Z<n>_W_OUT` goes to the field terminal driving the zone actuator.

Two consequences:

- **The white-wire sense taps upstream of the FailSafe selector**, so it
  always reports the wall thermostat's contact, whoever owns the zone. A held
  zone with a calling stat shows a call on the visualizer while nothing
  reaches the floor — benign, and only the 0x20 registers distinguish it
  (verified at the pins during the 2026-08-06 white-wire-calls check).
- **Failsafe direction is thermostat-wins:** board dead or expander reset ⇒
  FailSafe de-energizes ⇒ the wall thermostat drives the zone.

**All six zone optos exist on the board** (`NZONE1–6_W_3V3`, BCM GPIO
17/27/22/10/9/11). The unlimbo layout gen (`gw108_nolan_zones.py`) maps only
zones 1–4 — zones 5/6 fold in at the port.

**Silkscreen labels (2026-08-11):** the zone terminals are labeled
"Zone Controls" with R and W per Z1–Z6, and "Zone 0-10V Analog
Outputs" with + and − per Z1–Z6. R/W is heating-thermostat
convention — serviceable for a cooling call, but not great. The
upcoming board rev (the one addressing the i2c bus power issues) can
relabel; with zone = thermal space and zone-call-circuit = the
board-position chain (the design's naming split), the Z1–Z6 positions
are circuit numbers, not zone numbers, and the silkscreen could say
so.

## Expander map

Authored source: `starter-scripts/gw108_test_code.py`; the board's
`gw1.scada.device.type.gt` record matches it. TCA9555 registers: 0/1 input
ports (pin readback), 2/3 output ports (commanded), 6/7 config (all-1s =
power-on-reset signature — the OPS-452 detection).

**0x20 — zones.** Port 0 bits 0–5 = zone 1–6 FailSafe coils; port 1 bits
0–5 = zone 1–6 OnOff coils (energized = call asserted).

**0x21 — plant.**

| port.bit | relay | port.bit | relay |
| --- | --- | --- | --- |
| 0.0 | hp-scada-ops (dry contact) | 1.0 | fcm-misc |
| 0.1 | buffer-elt-upper | 1.1 | iso-valve-failsafe |
| 0.2 | buffer-elt-lower | 1.2 | iso-valve (energized = OPEN) |
| 0.3 | boiler-buffer-valve | 1.3 | discharge-valve |
| 0.4 | boiler-intercept | 1.4 | store-pump |
| 0.5 | misc-relay1 | 1.5 | secondary-pump |
| 0.6 | misc-relay2 | 1.6 | store-elt-upper |
| 0.7 | primary-pump | 1.7 | store-elt-lower |

A gw108 relay's native address is **(chip, port, bit)** — there is no board
relay index. House0 channel names embed the krida relay index
(`...-failsafe-relay14`); the gw108 naming should not invent one.

## DAC map (authored source: `starter-scripts/gw108_test_code.py`)

Three MCP4728 4-channel DACs sit behind the TCA9548A i2c mux: dac1 = mux
channel 1, dac2 = mux channel 2, dac3 = mux channel 3, all at the chip's
0x60. Operating configuration is vref INTERNAL, gain 1; the board stage
brings that to the 0-10V field terminals (observed: 10V at raw ≈4000,
linear).

- **Zone analog outputs:** zones 1–3 = dac1 channels a/b/c; zones 4–6 =
  dac2 channels a/b/c (Z6 = dac2 channel_c).
- **Plant:** dac3 — channel_a = primary, channel_b = store, channel_c =
  secondary 0-10V terminals.
- **Spruce deviation (2026-08-10 rewire):** the secondary pump's speed
  wire lands on the Z6 output — dac2 channel_c — because dac3's i2c
  interface died 2026-07-30 (analog stage kept driving; only the i2c face
  is dead). `spruce_summer_hack.py` and the EEPROM provisioning
  (`starter-scripts/program_dac_eeprom.py`) both carry this.

**EEPROM power-on defaults are component-record state.** Each MCP4728
channel loads its EEPROM value (output code + vref/gain) on power-up
(`wiki/hardware/gw108-provisioning.md`), so the programmed defaults are
persistent per-chip configuration the gw108 component record must declare
at the semafy — per DAC, per channel: value, vref, gain. And because the
EEPROM is readable (the 24-byte sequential read carries it), the declared
defaults are verifiable: the scada reads at startup, notes any mismatch,
reprograms, and re-verifies (requirement in the provisioning doc).

**The ADS1115s carry no persistent counterpart** — their data rate is a
per-conversion config word, so it rides the thermistor-reader component
config, not chip provisioning. The semafy carries it on three levels: the
chip's supported data-rate menu (8–860 SPS) as an ADS1115 device-type
fact; the operational choice (8 SPS, 1 Hz poll — provisioning doc) as
component-record fields; and the SPS ↔ poll-rate
coupling as an axiom on the component word (per-chip sweep time —
channels × conversion + overhead — bounded by a slack fraction of the
poll period).

## Relay naming + the zone state machine (settled 2026-08-11)

House0 precedent (`layout_gen/relay.py`): per zone a
`zone<n>-<name>-failsafe-relay` (DoubleThrow; de-energized =
`WallThermostat`, energized = `Scada`) and `zone<n>-<name>-ops-relay`
(`RelayClosedOrOpen`), plus `hp-scada-ops-relay` for the HP contact — the
gw108 realizes all of these.

Both decisions settled in
[`zone-relays-and-thermostat-model.md`](zone-relays-and-thermostat-model.md):
the enum renames to `ZoneCallSource` (`WallThermostat | Scada`) —
season-neutral, since the same relay pair carries spruce's cooling
calls (House0's legacy `HeatcallSource` stands until that layout
regenerates) — and the four-value view (`WallThermostat-Idle` ·
`WallThermostat-Calling` · `ScadaHeld` · `ScadaCalling`) is a DERIVED
channel (circuit FSM state × white-wire sense), not an FSM state.
Field prototype of both: `starter-scripts/spruce_status.py` (read-only
gw108 state check).

## Open

- **Declare the eGauge poll period on the spruce eGauge component.** The
  pico-blackout postmortem's timing argument
  (`experiments/2026-08-10-hp-snafu-and-pico-blackout-postmortem/`) had to
  infer ~1 s read cadence from observed sample spacing; the poll period
  is an operational choice that belongs on the component record, the
  same pattern as the ADS 8 SPS / 1 Hz choice above. Once declared,
  reading staleness is a citable bound instead of an inference.

## Where this content lands

- **Layout board record / sema device-type words:** the facts code resolves —
  addresses, (chip, port, bit) maps, energized meanings, opto GPIO pins and
  sense. Machine-readable, versioned, referenced by the layout.
- **Component documentation (with the schematic; not sema):** the electrical
  narrative — module composition, tap points, failsafe rationale. A sema word
  restating the schematic would duplicate the drawing; the KiCad source and
  this page's distillate are that story's home.
