Status: Draft · Pass 0 · Updated 2026-09-20

# Defrost signatures

What this is: what a heat pump defrost looks like in the channels the scada
reads, per heat pump model, so that code deciding "the heat pump is off" or
"the heat pump has lift" can tell a defrost from either. One section per
model as each is measured.

A defrost is the heat pump running its cycle in reverse to melt ice off the
outdoor coil. It takes that heat from the water loop: leaving water comes
back colder than entering water, and electrical power falls far under its
heating level, while the scada's command is still "on". Code that reads low
power as off, or negative lift as a fault, misreads every defrost.

## Mitsubishi Ecodan at maple

Measured from 67 defrosts in the journal readings for 2026-03-26 →
2026-05-15 (`experiments/2026-09-20-maple-starts-heating/` "Defrost
profile"; harness `defrost_hunt.py`, events in `maple-defrost-events.json`).
Channels: `hp-odu-pwr`, `hp-lwt`, `hp-ewt`, `hp-scada-ops-relay6`, `oat`.
The monobloc has no indoor-unit power; `hp-odu-pwr` is the whole heat pump.

Two phases, then a restart:

1. **Reverse cycle, about 5 minutes.** Power falls from heating level
   (4.1 kW median) to 0.5–1.5 kW inside a minute. LWT falls about 20 C
   (48 → 28 C in the traced case) and sits 12 C under EWT at the median,
   24 C at worst.
2. **Compressor stopped, about 130 s.** Power 45–170 W. LWT drifts back
   toward EWT.
3. **Restart.** Power returns to 2–3 kW and climbs; lift is back at 2 C
   about 8 minutes after the defrost began (p90 9.4 minutes).

| | Median | Spread |
| --- | --- | --- |
| Outdoor air at start | 0.2 C | −10.2 to 7.5 C; 90 % under 3.5 C |
| Lift at or below zero | 446 s | longest 608 s |
| Longest stretch under 100 W | 121 s | p90 132 s |
| Longest stretch under 500 W | 137 s | p90 255 s; longest 950 s |
| Defrost to defrost, one run | 49 min | p90 90 min (20 pairs) |

58 of the 67 began between 20:00 and 08:59 ET.

For comparison, a commanded off at maple (2026-09-20 13:26:26) took
`hp-odu-pwr` from 2.9 kW to under 100 W in 4 s, where it stayed; after the
command returned, the heat pump drew power again 3 min 45 s later.

### What follows for the code

- Power under a threshold does not mean off while the command is on: it is
  a defrost, or the heat pump stopping its own compressor, for up to about
  four minutes (p90 255 s under 500 W).
- The command and low power agreeing means off, at once.
- Negative lift with the command on and power that was at heating level in
  the last quarter hour is a defrost, not a sensor fault.
- The rule that separated defrosts from the rest in this data: lift ≤ −5 C
  held ≥ 120 s with power dipping under 1 kW. Sub-minute negative lift at
  full power (48 cases) is a sensor transient; shallow lift (0 to −2 C)
  with power near zero (37 cases) is the heat pump stopping its compressor
  by its own control.

## Open

- LG (beech) and Samsung (spruce) signatures: not measured.
- Whether the first-phase power (0.5–1.5 kW) tracks outdoor temperature or
  ice load.
- The sub-minute negative-lift transients at full power, several on the
  half hour: cause not traced.
- What a Siegenthaler valve should do during a defrost: at full send the
  cold leaving water goes to the buffer; at full keep the heat pump takes
  its defrost heat from the small loop alone.
