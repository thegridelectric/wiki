# What the CT reports

Status: Draft · Pass 0 · Updated 2026-11-23

> What this is: the decision spoke of hello-gw108-ct. A one-turn CT with no
> voltage reference gives a current waveform, and the actor has to report
> one quantity from it. Decided 2026-11-22 against the spruce captures:
> the actor reports the fundamental RMS of the CT current, and the line
> voltage from the eGauge with a per-model constant in the layout turns
> it into an estimate of pump power. This spoke also has the checks that
> make that constant trustworthy.

## Decision

The CT quantity is the **RMS of the 60 Hz fundamental** of the CT
voltage over a capture of a few seconds, fitted by least squares at the
mains frequency (the fit `starter-scripts/ct_waveform.py` already does).
The derived indicator thresholds it. A second derived channel, the
power estimate, is

```
P_est = V_rms × I1_rms × c_model
```

- `V_rms` is the line voltage the eGauge reports once a second. For
  this estimate the eGauge is a weak voltage beacon: it gives RMS voltage
  and frequency, and no phase, since its clock is NTP-grade against the
  scada's and its samples cannot be lined up with the CT's. The eGauge's
  own power and power factor for the pump's register are not inputs; the
  CT path stands on its own, as it will in a house with no eGauge CT on
  each pump.
- `c_model` is a layout constant per pump model: the CT ratio, burden
  and ADC gain times an assumed cos φ1, calibrated once against a
  trusted reference on the same pump. The assumption has a physical
  basis: the pump's current pulse comes from a rectifier charging its
  capacitor, which conducts only near the voltage crest, so φ1 is small
  and cos φ1 close to 1 and steady.

## Why the fundamental

Real power is the mean of instantaneous voltage times current over whole
cycles. On-grid the voltage is a sine
(`../../education/voltage-stays-a-sine.md`), and every harmonic of the
current integrates to zero against a sine. What survives is

```
P = V_rms × I1_rms × cos φ1
```

where I1 is the fundamental of the current and φ1 its angle to the
voltage. The pulses that give this pump its crest factor of 3 deliver no
power; only the 60 Hz component does. Where the pulse sits matters: a
narrow pulse at the voltage crest delivers nearly V_peak times its
charge and the same pulse at a zero crossing delivers almost nothing,
with the same RMS in both places. Moving the pulse leaves I1's size
alone and moves its phase, so the whole effect is in φ1. Overlaying a
guessed sine on the current waveform and summing the products gives
exactly V_rms × I1_rms × cos φ1 for the φ1 the guess implies, so it
adds no information over the formula. A measured φ1 comes with a
voltage reference sampled on the same clock as the CT, such as a local
voltage input on a future Gw108 rev.

The spruce captures of 2026-11-20 (`data/spruce-2026-11-20/`, CT2 on the
secondary pump) bear this out. The fundamental tracks the eGauge watts
with one constant within 2% from 42 to 193 W; the AC RMS spreads 8%:

| eGauge W | AC RMS mV | fundamental mV | fundamental / W | RMS / W |
|---|---|---|---|---|
| 193 | 120.2 | 79.7 | 0.413 | 0.623 |
| 80 | 52.7 | 32.9 | 0.412 | 0.658 |
| 42 | 28.4 | 17.0 | 0.406 | 0.676 |
| 22 | 14.0 | 8.3 | 0.376 | 0.639 |
| 191 | 119.2 | 79.5 | 0.416 | 0.624 |

At 22 W the fundamental is 8 mV against the 3 mV noise floor, which is
where the 9% at the lowest speed comes from. The 60 Hz fit explains under
half the waveform's variance, because most of the variance is in the
pulse; that is a statement about the waveform's shape and says nothing
against the fundamental as the power-tracking quantity.

The candidates set aside: the peak about DC (within 8% of 1.8 mV per W,
but it depends on a sample falling on the crest at 14 samples per cycle,
and its scale moves with the pulse shape), and the AC RMS (the 8% spread
above, and its scale also moves with the shape, since the harmonics are
in it).

## What this reaches, and what it does not

- The indicator tier with room to spare: on against off is a factor of
  80 in RMS, more in the fundamental.
- The sub-metering tier's accuracy at the speeds seen, once `c_model`
  is calibrated against a trusted reference (next section).
- `P_est` is an estimate rather than a measurement of power: it holds
  under the assumption that φ1 stays at its calibration value; the
  channel's name and sema word must say estimate. Mains voltage is
  measured each second and is not part of the assumption. Residuals
  to expect: φ1 moving with speed or mains voltage, the pump's
  constant-power behaviour (current falls as voltage rises), the SCT013
  at under 1% of its 100 A rating with a 470 Ω burden, and the noise
  floor at the lowest speed.
- `c_model` is per pump model. The Bell and Gossett ecocircs, with three
  or four pulses per cycle, get their own constant from their own
  calibration run; the fundamental still holds as the quantity, since
  the argument above does not depend on the pulse shape.

## eGauge sanity checks

The eGauge's `05-secondary-pump` register is the cross-check on
`c_model`, and the captures disagree with it by a factor of four or
more. A fundamental
of 79.7 mV is 0.34 A at the bench constant of 0.235 V RMS per amp, about
41 VA at 120 V, against 193 W on the eGauge; a multimeter on the pump
supply on 2026-11-20 read 0.6 A at full speed, agreeing with the CT. The
tlayouts nameplate for the pump is 80 W. Until this is settled the
clamp-meter reading in step 2 below is the calibration reference for
`c_model`.

### Do this next

1. In the eGauge web UI (`eGauge8499.local` from the spruce box; admin
   login needed, no copy of it is in `experiments/.env` or the scada
   `.env`), read the configuration of register `05-secondary-pump`:
   which CT input it uses, that CT's rated amps, and which line voltage
   it multiplies against. Note the firmware version from the status page
   while there.
2. At the next site visit, a true-RMS clamp meter on the pump feed beside
   a live eGauge reading at full speed and at one low speed.
3. Resolve: if the eGauge register sees more than this pump or has the
   wrong CT scale, correct it and recalibrate; if the CT path reads low,
   `c_model` already covers it. Record the outcome here and refit the
   table above.

### What the eGauge offers, checked 2026-11-22

- Legacy XML at `/cgi-bin/egauge?inst` answers without login and lists
  the registers; every `/api/...` path answers 401 until the WebAPI
  login, so the unit runs the 4.x firmware line.
- The WebAPI `/capture` service (firmware 4.2 and later, confirmed
  against `webapi.egauge.net` and the egauge-python source) returns a
  one-shot buffer of raw samples per input channel, voltage or current,
  at about 2.5 kHz across channels with 1 µs ticks. The CT path does
  not use it: it would measure φ1 on the eGauge's own CT, and the CT
  path takes only voltage from the eGauge.
- `/local` gives per-line RMS voltage, frequency, real and apparent
  power per register once a second. Its line RMS voltage is the `V_rms`
  of the estimate. No phase angle is published.

## Open

- The sema word for the fundamental RMS and for the power estimate:
  search `sema/definitions/` first; `derived.channel.gt` is at v003.
- Where `c_model` lives in the layout and how the actor learns the pump
  model behind a CT.
- How the actor gets `V_rms`: from the scada's eGauge power meter actor,
  or its own read of `/local`; which line feeds the pump.
