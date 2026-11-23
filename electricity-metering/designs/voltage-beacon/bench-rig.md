# The bench rig: two picos, one sync wire, against the eGauge

Status: Draft · Pass 0 · Updated 2026-11-23

> What this is: the first step of voltage-beacon. Two picos on one sync
> wire, one reading a Class 2 AC adapter through a divider (the beacon),
> one reading a CT on a known circuit (the CT node), and the eGauge on
> the same circuit as the reference. The first witnessed real-power
> number from a split voltage and current, and the measurement of what
> the split costs.

## Do this next

Choose the circuit and the parts: a resistive load first (a space heater
or the store's heating element, power factor near 1, so the sync error
barely shows), then the spruce secondary pump (the Grundfos, crest
factor 3, the hard case). Parts: two picos, a 9 or 24 VAC adapter, a
resistor divider into a pico ADC, a CT with a burden into the other
pico's ADC, one GPIO wire between them for the once-a-second pulse.
Write the capture so each pico timestamps its samples against the
pulse, and compute power three ways: with the sync, with the sync offset
by a known 1 ms, and with no sync (NTP-grade). Compare each to the
eGauge over ten minutes. Order the satellite boards in the same order
(`satellite-drumbeat.md` "Kit to buy").

## Then

- Fit the voltage as a sine per second on the beacon pico and send the
  model (frequency, phase at the pulse, RMS) to the CT pico; the CT pico
  computes power from the model and its own samples. Compare to the
  waveform-shipping result.
- Run across a day to see mains frequency wander and the adapter's
  phase drift with line voltage.
- Measure the adapter's phase lead and magnitude against the eGauge's
  voltage, to size the per-unit calibration.

## Open

- The pico ADC's sample rate and jitter for both roles; whether the CT
  pico needs a few kSPS to hold the Grundfos.
- Which eGauge register is the reference and whether its CT scale is
  trusted (the factor-of-four question in hello-gw108-ct).
