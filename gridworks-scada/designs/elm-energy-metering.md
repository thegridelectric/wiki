# Elm energy metering

Status: Draft · Pass 0 · Updated 2026-10-29 · Linear: OPS-642

**EDD: yes** the verification is a night at elm where the journal's
watt-hour channels for the heat pump and the circulators agree with the
eGauge's own cumulative counters read at the start and end of the
window.

> What this is: watt-hour channels at elm so a heat pump cycle's
> electricity is a journal fact. Split out of OPS-628.

## Why

The eGauge at elm reports power only. Energy per cycle today is an
integral over captured power deltas, which under-counts short cycles
and depends on the capture cadence. The eGauge keeps cumulative energy
registers for every CT, so the number exists on the meter and is not
read.

## The change

- Energy channels on the eGauge component for `hp-odu`, and for each
  circulator the layout declares, reading the meter's cumulative
  registers in watt-hours.
- The power meter actor reports them on the same cadence as power;
  the journal keeps them as readings.
- Required energy and any COP work read the watt-hour channels rather
  than integrating power.

## Open

- Which eGauge registers hold the cumulative values for the CTs elm
  has, and their unit and scaling.
- Whether the channel is cumulative (a counter the consumer differences)
  or per-period (the scada differences it). Cumulative survives a scada
  restart without a gap.
