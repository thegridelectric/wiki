# The CT actor: the CT quantity and a derived indicator

Status: Draft · Pass 0 · Updated 2026-11-23

> What this is: the third step of hello-gw108-ct. A first-pass scada actor
> that samples a CT input, reports the quantity chosen in
> `what-the-ct-reports.md` and a derived on/off indicator for a Grundfos
> circulator pump.

## What is known

- The Grundfos UPMS 20-78 current is pulsed, one maximum per cycle. The
  RMS of its 60 Hz fundamental tracks eGauge power with one constant
  within 2% from 42 to 193 W (`what-the-ct-reports.md`); the AC RMS
  spreads 8%, and the pump off sits at the 3 mV RMS noise floor. The
  actor fits the fundamental over a capture of a few seconds, as the
  starter script does, and reports its RMS.
- The power estimate is a derived channel, the eGauge's line RMS
  voltage times the fundamental RMS times `c_model`, a per-model layout
  constant calibrated against a trusted reference
  (`what-the-ct-reports.md` "Decision"); its name says estimate. The
  actor needs the line voltage once a second beside its own capture.
- Other ECM circulators (Bell and Gossett ecocirc) are expected to show
  three or four maxima per cycle. The indicator threshold and any
  per-model scale belong in the layout, not in the actor.

## Open

- How the two channels are declared: the CT quantity, and the derived
  indicator (`derived.channel.gt` exists at v003).
- Sampling cadence against the scada's thermistor poll and the DAC writes
  on the same mux.
