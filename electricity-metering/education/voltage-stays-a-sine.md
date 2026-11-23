# Why the voltage stays a sine wave when the current does not

Status: Draft · Pass 0 · Updated 2026-11-21

> What this is: an education note. It answers one question that comes up
> when a current waveform looks nothing like a sine (an ECM circulator,
> crest factor 2.8, one spike per cycle): does the voltage at the same
> outlet get distorted too? On-grid, almost not at all. This note says why,
> with numbers, and where the answer stops holding.

## The grid is a stiff voltage source

A load distorts the voltage only through the source impedance in front of
it. At a residential service entrance that impedance is the pole
transformer plus the service drop, on the order of 0.05 to 0.1 Ω at 60 Hz,
and the inductive part scales with frequency, so about 0.3 Ω at the third
harmonic.

A harmonic current drawn by one load produces a harmonic voltage equal to
that current times the source impedance at that harmonic. A circulator
pulling 1 A of third-harmonic current across 0.3 Ω drops about 0.3 V of
third harmonic on a 120 V fundamental: 0.25% distortion. The pump's own
current is half or more harmonic by RMS; the voltage distortion it causes
is a quarter of a percent. The current can be spiky because the voltage
does not care what one small load does.

## The harmonics that are there come from everyone

Residential voltage does have harmonics, typically 1 to 3% total harmonic
distortion, mostly the 3rd, 5th and 7th. They come from the sum of every
rectifier load on the feeder and from the transformer itself, and they
are present whether or not any one house's pump runs. The common large
shape is flat-topping: every rectifier on the feeder draws at the crest,
so the peaks clip a little. That is still a smooth, slowly changing
shape, and it changes over seconds to minutes, not cycle to cycle.

## What this means for metering

- A voltage node can treat the mains as a sine plus a few harmonic
  phasors, published once a second, and a current node evaluates that
  model at its own sample times. The circulator's spiky current does not
  disturb the model measurably.
- A fundamental-only model leaves the 1 to 3% of voltage harmonics out.
  Against a load whose current is mostly harmonic, that is the worst-case
  real-power error; publishing the 3rd, 5th and 7th closes it.

## Where the answer stops holding

- **Weak sources.** A long rural service drop, a small transformer shared
  at the end of a feeder, a generator, or an off-grid inverter has a much
  higher source impedance, and there the loads do visibly distort the
  voltage. A standalone microgrid is this case: an inverter-fed island can
  show several percent of distortion that moves with the load, and the
  voltage model has to follow it faster than once a second.
- **Large harmonic loads on a shared service.** Several kilowatts of
  rectifier load on one small transformer start to show in the voltage
  for the neighbours. One circulator is not that.
