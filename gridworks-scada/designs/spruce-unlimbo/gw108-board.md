# gw108 board documentation (spoke)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

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

**Board revs (2026-08-11):** the deployed boards (spruce, the
honeysuckle bench) are **rev B**; the KiCad source cited above is the
in-progress **rev C**, whose silkscreen is likely to change
significantly. Board facts here and in the device-type record are
rev B facts unless marked otherwise. When rev C lands it gets its own
device-type record (positions and labels may move — a new record, not
an in-place edit of the rev B one), and per-rev documentation.

## Parked until after the first functional pass — board reference doc + terminal modeling

Parked 2026-08-11; pick back up once local control runs on spruce at
hack parity (still dev-broker-only).

- **A hyperlinked GW108 reference document** with annotated images:
  photos that circle a physical connector and relate it to its
  machinery (e.g. the Z2 "Zone Controls" R/W pair → the Z2
  FailSafe/OnOff relay coils at 0x20, their expander bits, the LED).
  Candidate home: a Drive doc on the Samsung PRIMARY pattern (public
  folder, no site/homeowner mentions), per-rev (rev B now; rev C gets
  its own when it lands), hyperlinked from this spoke and later from
  wherever the electrical narrative distills to. The wiki keeps the
  machine-readable facts; the doc carries the visual wiring narrative.
- **The R/W terminal pair per zone position.** Each Z1–Z6 "Zone
  Controls" position exposes R (24 VAC supply to the stat) and W (the
  call line, driven by `Z<n>_W_OUT` off the FailSafe selector — chain
  above). Proposed stance: terminals stay documentation, not
  vocabulary — the zone-call-circuit record already carries the
  semantic bindings (whitewire channel, failsafe/ops relay nodes,
  CircuitPosition), and no code consumes terminal identity. If a
  machine consumer appears (e.g. a wiring-checklist generator), a
  terminal-block section on the board device-type record is the shape;
  don't mint it before then.

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

## The CT signal chain (schematic-verified 2026-09-07, RevB nets; bench-verified on spruce)

Each of the four CT terminal pairs drives an ADS1115 at 0x48 (the board
record's `CtAdc`) single-ended, centred on the shared 1.65 V bias, with an
optional on-board 470 Ω burden selected by a 2-pin header jumper. The
chip's ALERT/RDY pin is not wired to the pi, so a reader takes single-shot
conversions and stamps them itself (about 390 per second on the 100 kHz
bus); the effective rate is the bus, not the chip.

| Terminal | ADS1115 input | Burden jumper | 470 Ω | spruce (2026-09-07) |
| --- | --- | --- | --- | --- |
| CT1 | AIN0 (P0) | JP4 | R6 | store pump, current-output CT (100 A : 50 mA); jumper NOT fitted |
| CT2 | AIN1 (P1) | JP3 | R5 | secondary pump, eGauge-style voltage-output CT (20 A rated); jumper open, correct |
| CT3 | AIN2 (P2) | JP2 | R4 | nothing |
| CT4 | AIN3 (P3) | JP1 | R3 | nothing |

Board location: the screw-terminal strip labeled CT INPUTS on the left edge
below THERMISTOR INPUTS, channels top to bottom CT1..CT4, each a + (signal)
and − (bias) pair. The jumpers sit just right of the strip and are numbered
the opposite way to the channels. A current-output CT needs its jumper
fitted (else its secondary runs open); a voltage-output CT needs it open
(its burden is internal, and 470 Ω in parallel changes its scale).

**What the bench established (`experiments/2026-09-07-adc-waveform-bench/`):**

- A voltage-output CT on CT2 works as wired, one pass through the CT, no
  jumper: the secondary pump's current waveform is recovered by folding
  two seconds of conversions on the fitted mains frequency. The waveform
  is harmonic-rich (fifth harmonic above the fundamental), so a CT
  channel's reading pipeline must report the composite waveform's rms,
  not a sine fit.
- The channel tracks the pump across its whole speed range (summer hack
  stopped, pump relay energized by the driver, DAC stepped on Dac2 C):

  | DAC V | secondary-flow gpm | waveform rms mV | fundamental pk mV | noise rms mV |
  | --- | --- | --- | --- | --- |
  | 3.0 | 0.64 | 10.0 | 3.4 | 3.4 |
  | 4.5 | 3.04 | 32.5 | 11.3 | 11.2 |
  | 6.0 | 5.13 | 87.5 | 37.3 | 23.3 |
  | 7.5 | 7.29 | 180.7 | 86.5 | 49.7 |
  | 9.0 | 9.00 | 274.0 | 152.8 | 47.6 |
  | 10.0 | 8.99 | 261.7 | 152.8 | 100.1 |

  Current rises about 27-fold from minimum to maximum speed while flow
  rises 14-fold (pump power grows faster than flow); 9 V and 10 V give the
  same flow and the same current.
- Open inputs (CT3, CT4) float off the bias with 15 to 30 mV of noise and
  no periodic content; a wired but idle channel sits on the bias with a
  3 mV mains pickup. That signature tells wired from unwired without
  opening the panel.

**Open:** the absolute scale for CT2 (its rated millivolts at 20 A, or one
clamp-meter reading against a ladder level); why CT1, unburdened and with
the store pump off, shows CT2's waveform (same conductor, or pickup from
the adjacent cable); the secondary-btu pico's own `secondary-pump-ct`
reads a constant 1.67 V with the pump running. The CT channel-config
vocabulary (ratio, passes, burden, the derived scale) is the
ct-measurement-chain design's (OPS-518).

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
