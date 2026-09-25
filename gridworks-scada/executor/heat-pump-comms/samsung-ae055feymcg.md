Status: Draft · Pass 0 · Updated 2026-09-25

# Samsung AE055FEYMCG (spruce)

What this is: how the scada talks to spruce's Samsung EHS mono heat pump,
through the call contact it uses now and through the MIM-B19N Modbus
module that comes next, with the Samsung documents behind each claim.
Provenance tags are defined in [`primary.md`](primary.md).

## The equipment

- **Outdoor monobloc AE055FCYDCG** (layout node `hp-odu`): compressor,
  R-32, 54,600 Btu/h heat and cool, MCA/MOP 32/40 A. [documented:
  nameplate]
- **Indoor control box AE055FEYMCG** (layout node `hp-ctrl-box`): control
  electronics, water-pump feed and a 2/4 kW backup heater; no compressor.
  The call contact lands here; the MIM-B19N attaches at the outdoor unit
  (see "Modbus via MIM-B19N"). [documented: nameplate]
- **Touch panel** on the control box is the wired remote controller
  (bezel label AE055FEYMCG/AA) and holds the SmartThings pairing. [field]
- **NASA** is Samsung's name for the RS-485 protocol on the F1/F2 bus
  between the outdoor unit, the control kit and accessories. Samsung does
  not publish it; community projects decode it. [community]

## Sources

All in the Drive folder "Samsung AE055" (HeatPumps →
<https://drive.google.com/drive/folders/1XV80QPgqpyYvMaoQIR9PpGWmu6dSY9kD>):

- **"PRIMARY — Samsung AE055 control interface"** — the working summary:
  terminals, FSVs, service-mode entry, fuses, document index.
  > "that contact is the SOLE compressor on/off authority"
- **EHS installer reference guide.pdf** — the wiring authority. Printed
  p.117 (PDF p.118): external thermostat wiring B19–B24; PDF p.93:
  terminal function table; PDF p.135: FSV 2091/2092 semantics.
- **service_manual.pdf** — PCB connector maps (THERMOSTAT1_C/H pinout PDF
  p.79, CNS051), error codes, S-NET Pro2 FSV import/export.
- **User Manual.pdf** (DB68-13635A-03) — US touch-controller manual:
  service-mode entry p.18; field-setting tables for AE053FE/AE055FE from
  p.25.
- **MIM-E03FN user manual (EU)** — the EU control-kit manual; the closest
  public FSV table, and its values match the US unit's. Not a part we own.
- **Nameplate data — AE055FCYDCG + AE055FEYMCG (transcribed)**.
- Missing: the US installation manual for AE055FEYMCG / AE055FCYDCG,
  which carries this generation's exact FSV tables. Pull by model number
  from <https://www.samsunghvac.com/downloads>.

## Call contact

The path spruce runs on. The scada side (hp-boss, `hp-scada-ops-relay`,
the interlock and the failsafe direction) is in
[`../control-hierarchy.md`](../control-hierarchy.md) "Fixed sub-trees vs
floating actuators".
> "The call contact, its interlock, and the failsafe direction."

- A normally-open RIB closes **B20 (switched Live) → B21 (THERMOSTAT1
  cooling call)**. With **FSV 2091 = 1** that contact is the sole
  compressor on/off authority: closed runs the unit, open stops it.
  [documented: installer guide p.117; field]
- A second RIB **B20 → B22** would add the heating call. Cool and heat
  SHALL never be closed at once; Samsung says the product will not operate.
  Zone 2 has priority over zone 1. [documented: installer guide p.117]
- With FSV 2091 or 2092 non-zero the touch panel and SmartThings stop
  being the on/off authority; the panel looks passive. [field]
- **Field terminals (control box B-strip):** B19 Neutral · B20 Live 230 V
  · B21 / B22 thermostat 1 cool / heat (zone 1, UFH water laws) · B23 /
  B24 thermostat 2 cool / heat (zone 2, FCU water laws). Inputs are
  switched Live, AC 230 V, 22 mA; Samsung wire spec > 0.75 mm² (about
  18 AWG). [documented: installer guide p.117]
- **A floating input is undefined.** Setting 2091 = 1 with nothing wired
  gave a roughly five-minute pump and compressor run, and the 7 VDC read
  on a floating input is detector bias, not a low-voltage interface. Keep
  2091 = 0 until the wire is in. [field, 2026-07-15]
- **Low-voltage strip (1–10):** 1–2 SG READY_1 · 3–4 SG READY_2 · 5–6
  zone 2 room temp · 7–8 zone 1 flow temp · 9–10 zone 2 flow temp; feeds
  PCB header CNS051. [documented: control-box wiring label DB68-13602A]
- **SG Ready is not used** (FSV 5091 = 0). Four modes from two dry
  contacts: signal 1 short = forced thermo off; both open = normal;
  signal 2 short = heating/DHW setpoints one step up (FSV 5092/5093);
  both short = two steps up. No mode forces the unit on. [documented:
  installer guide PDF p.153, "Smart Grid Control"]

### Service mode (FSV edits at the touch panel)

Home → ^ chevron → Settings gear → Heat pump settings → scroll to the
bottom → Service information → when "Customer service contact" shows, tap
the screen rapidly 10–15 times. FSVs are under Field setting value →
Simple setting. Edits stick only after Apply/Save; some FSVs reboot the
panel. "FSV upload / FSV download (to Indoor)" are bulk transfers that
push values; leave them alone unless backing up or restoring. [field]

## FSVs

FSVs (field setting values) are the control box's settings, held in the
indoor unit's EEPROM (errors E162/E163 are the hydro unit's). They are
read and written at the touch panel ("FSV upload: Read indoor unit FSV
settings"; "FSV download (to Indoor)") and by S-NET Pro 2 over F1/F2,
which also exports and imports the whole set as XML. [documented:
MIM-E03FN manual; service manual §7-5, §7-6] The MIM-B19N's standard
registers hold no FSVs; whether its NASA message-ID registers reach them
is Open.

## Pump speed

The built-in circulator is an inverter pump: an electronically commutated
variable-speed pump. The control box powers it on B6 "INV WATER PUMP" and
sets its speed with a PWM signal on **CNS001** (pin 1 signal, BRN wire;
pin 3 GND). **CNS002** is a two-terminal tap of the same signal, unwired.
[documented: service manual PDF p.79; wiring label DB68-13602A] The
control box moves pump speed to hold Tw2 − Tw1 (leaving minus entering)
at a target. [documented: MIM-E03FN manual "Inverter Pump Installation
(Field Option) (FSV#4051~4054)"; installer guide PDF p.147]

| FSV | Meaning | Default |
| --- | --- | --- |
| 4051 | 0 fixed pump (no speed regulation); 1, 2, 3 inverter pump with maximum PWM 100 %, 85 %, 70 % | 1 |
| 4052 | ΔT target, Tw2 − Tw1 | 5 °C |
| 4053 | control factor: PWM change per step, 1–3 | 2 |
| 4054 | minimum PWM: 0 = 25 %, 1 = 35 %, 2 = 45 %, 3 = 55 % | 0 |

For an added pump the installer guide asks for a PWM pump of "Heating
Type", recommending GRUNDFOS UPMM 25-95. [documented: installer guide PDF
p.73] Too-high flow is corrected with a balancing valve; the flow limits
are in [`../heat-pump-signatures/running-signatures.md`](../heat-pump-signatures/running-signatures.md).

## Compressor cap (FR control)

With **FSV 5051 = 1** ("Frequency Ratio Control") the control box limits
the compressor's maximum frequency. Method 1 is a 0–10 V DC signal on
**CNS003 "FR_CONTROL"** (pin 1 input, pin 2 GND), 0 V = 50 %, 10 V =
150 %; the touch panel shows "DR". Method 2 is "Demand ratio (DR) control
through Modbus communication"; which register carries it is Open.
[documented: MIM-E03FN manual "FR Control"; installer guide PDF p.151;
service manual PDF p.79] It is a demand-response input: it caps the
unit's draw while the unit keeps running its own control.

The cap is a percentage of 60 Hz in 10 % steps of about 1 V (0–1 V 50 %,
5–6 V 100 %, 9–10 V 150 %), and never exceeds the unit's normal maximum
at the outdoor temperature: the guide's example unit normally runs to
90 Hz at −10 °C and 60 Hz at 10 °C; at FR 100 % it is held to 60 Hz at
every temperature. [documented: installer guide PDF p.151; the guide is
the EU R32 edition, so the US unit's numbers are unverified]

## Modbus via MIM-B19N

Samsung's sanctioned digital path. One MIM-B19N is on hand for spruce and
not yet wired. Source for this section unless tagged otherwise: the
MIM-B19N/B19NT installation manual DB68-07538A-02, mirrored at
<https://github.com/ZimKev/MIM-B19n_Modbus>. [documented]

- **Where it attaches: the outdoor unit, not the control box.** The
  manual mounts the module in a case on the side of the outdoor unit's
  electrical section and wires it to the outdoor unit: DC 12 V power and
  the R1/R2 bus ("Samsung Control Layer Protocol (R1/R2)"). The Modbus
  side is two-wire RS-485, terminals A and B, up to 1000 m to the master.
  The ZimKev install on an EHS split also mounts it in the outdoor unit.
  [community] On spruce's unit the outdoor main PCB (AE***FCYDCG/AA)
  carries R1/R2 on connector ① (pins 5–6, beside DRED signals) and a
  DC 12 V header ⑤. [documented: service manual PDF p.83] The control
  box has no R1/R2: its TB-C is F1/F2 to the outdoor unit, V1/V2 DC 12 V
  out, F3/F4 to the wired remote. [documented: service manual PDF p.80;
  wiring label DB68-13602A]
- **Serial settings:** Modbus RTU slave, 9600 baud, 8 data bits, even
  parity, 1 stop bit; big-endian 2-byte registers. Slave address 1–247,
  set on DIP and rotary switches. Function codes 3, 4, 6 and 16. Leave at
  least 10 ms after each response before the next request.
- **Start-up:** every register reads 0 until the module has tracked the
  units; bits 0–2 of register 1 go to 1 per indoor unit when it is ready.
  The indoor unit's "Use of central control" option (SEG5) must be Use (1)
  or the module reports E604. What that option is called on an EHS touch
  panel is Open.
- **Writes are commands.** Every write to a holding register sends a
  control command to the indoor unit; the holding register updates only
  when the unit reports back, so read status after writing. The master
  sends a write only when it means to change something.
- **Arbitrary NASA points:** writing a NASA message ID to the config
  registers at 6000 (outdoor) or 7000 (indoor) maps that point into the
  register table (e.g. 0x8238 → compressor frequency in register 5). The
  message IDs come from the NASA.ptc file in the S-NET Pro installation.
  [community]
- **Registers of note** (manual pp.13–16): communication status, unit
  type, integrated indoor and outdoor error codes, outdoor defrost
  operation (register 3); per indoor unit on/off, mode, water-in and
  water-out temperature, water-out set temperature (EHS heat 15–65 °C),
  hot-water on/off, mode and set temperature, quiet, away, and a
  remote-control restriction that locks the touch panel.
- **Coexistence.** With an upper-level controller connected, FSV 4061
  (2-zone control) must be off; the external-thermostat path (FSV 2091)
  already needs 4061 = 0. [documented: installer guide PDF p.147]
- **Samsung central controllers cannot share the bus** with the MIM (on/off
  controllers, touch central controllers, DMS). EHS is on the manual's
  supported list.
- The ODU ignores commands injected on F1/F2 without a MIM; control
  authority lives at the MIM layer. [community, two sources]
- The call contact stays wired as the failsafe once Modbus commands the
  unit (see [`primary.md`](primary.md) "Two ways in"). How the MIM and a
  2091 contact share authority is Open.

## S-NET Pro service tool

Samsung's Windows service software for NASA systems, "SNET Pro 2 Service
Software (NASA Systems)" on <https://www.samsunghvac.com/Downloads/software>.
The distributor (F.W. Webb) uses it from a Windows laptop to talk to these
units. [told, 2026-09-25] The service manual covers S-NET Pro2 FSV import
and export. [documented: service_manual.pdf]

- **Hardware:** the **MIM-C02N** communication converter (USB to
  RS-485), sold with the USB cable and a firmware-update cable that plugs
  straight onto a PCB. Its TX+ goes to F1 and TX− to F2 at any F1/F2
  point, or to R1/R2 (S-NET Pro 2 1.4.6 or newer), with field-provided
  wire. [documented: SNET Pro 2 user manual pp.3–5,
  <https://s3.amazonaws.com/samsung-files/Tech_Files/SNET+Pro+and+SNET+Pro+2+Service+Software/Snet+Pro+Service+Software_SNET+Pro+2+Instructions.pdf>]
  > "Connect TX+ and TX- on the converter to F1 and F2"
  A generic RS-485 adapter reportedly works for monitoring; the
  firmware-update cable is what the MIM-C02N adds. [community:
  OpenEnergyMonitor forum]
- **Access:** Samsung's US page lists S-NET Pro 2 for DVM S, CAC, DVM S
  Water and DVM Chiller and does not name EHS; the manual says software and driver
  come from www.DVMdownload.com; whether a non-contractor can get them is
  Open (the forum points to Samsung's partner portal, which needs company
  registration). [documented; community]

Useful to us for two things: seeing every NASA point live while mapping
what the MIM exposes, and backing up the FSV set before changing it.

## Fuses and safe work

- Control-box main board fuses (drawn on wiring label DB68-13602A):
  **F101** 250 V T5A near TB-A powers the board and display; a dark touch
  screen after a spark at the field terminals means check F101 first
  (replacement: glass 5×20 mm T5A 250 V, axial-lead because it is
  soldered in). **F151** 250 V T2A near CN100. **F500, F501** 250 V T20A
  near TB-B for heater and pump circuits. [documented; field]
- Attaching the RIB with power on sparked at the terminals and blew F101.
  [field, 2026-07-15]
- Line-voltage work: MAIN POWER and HEATER POWER are separate breakers,
  kill both; verify dead at B20→B19 with a live-dead-live meter check;
  land wiring cold; close the panel; re-energize. After the RIB is in,
  all switching happens from its low-voltage coil side.

## Open

- MIM-B19N at the monobloc: whether the supplied cables fit connectors
  ① and ⑤, and the EHS touch-panel name for "Use of central control".
- The layout names `hp-ctrl-box` as the MIM's commanded node; the module
  sits at `hp-odu`.
- Which registers the scada uses first; start with read-only (on/off
  state, leaving water, return water, outdoor air, compressor frequency)
  before any write.
- MIM-B19N compatibility with the US AE055FEYMCG control box.
- S-NET Pro download access for us, and whether F.W. Webb can lend a
  MIM-C02N or run a session at spruce.
- The US installation manual (see Sources).
