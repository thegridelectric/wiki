# Hello Gw108 CT (hub)

Status: Draft · Pass 0 · Updated 2026-11-24 · Linear: OPS-703

**EDD: yes** every step is witnessed on spruce against the running scada:
the CT ADC read behind the mux, the actor's CT and indicator channels
in the journal beside the eGauge, the pico read on a Gw101 bench.

**▶ Active spoke: [`scada-ct-behind-mux.md`](scada-ct-behind-mux.md)**

> What this is: the hub for turning the Gw108 CT inputs into a working
> indicator for Grundfos circulator pumps. Spruce has a one-turn SCT-013
> on CT1 (store pump) and CT2 (secondary pump, a Grundfos UPMS 20-78); the
> Rev C board put the CT ADS1115 behind mux channel 4, which the scada
> cannot yet address for a CT. The work is five steps: the scada reads a
> CT behind the mux, a decision on what quantity a CT alone reports, a
> first-pass actor reports that quantity and a derived on/off indicator,
> the capture script moves into tlayouts and speaks sema, and the same
> read is evaluated on a pico and pico2 on a Gw101.

## Spokes

Reference: [`data/`](data/), the spruce captures of 2026-11-20 (one-cycle
folds and raw samples per CT, the workbook that lines them up with the
eGauge and the secondary flow, the RMS-against-power plot).

- **[`scada-ct-behind-mux.md`](scada-ct-behind-mux.md)**: the CT
  capability word gains mux fields and the scada's I2C bus actor selects
  the CT ADC's mux channel the way it does for the DACs.
- [`what-the-ct-reports.md`](what-the-ct-reports.md): the quantity a
  one-turn CT with no voltage reference reports (the fundamental RMS,
  decided 2026-11-22), the power estimate, and the eGauge checks.
- [`ct-actor.md`](ct-actor.md): the first-pass actor that samples a CT
  and reports that quantity and a derived indicator for the Grundfos
  signature.
- [`tlayouts-capture-script.md`](tlayouts-capture-script.md): the
  waveform capture script moves from starter-scripts into tlayouts and
  emits `gw.adc.waveform` instead of CSV.
- [`pico-evaluation.md`](pico-evaluation.md): whether the capture and the
  indicator run on a pico or pico2 on a Gw101.

## Notes

- The spruce secondary pump (Grundfos UPMS 20-78) draws a pulsed current
  with one local maximum per 16.7 ms cycle: crest factor 2.8, a 60 Hz fit
  explaining under half the variance. The RMS of that 60 Hz fundamental
  tracks eGauge power with one constant within 2% from 42 to 193 W, the
  AC RMS within 8%, the peak about DC within 8% of 1.8 mV per W; the
  decision and the table are in `what-the-ct-reports.md`. The idle CT1
  noise floor is 3 mV RMS. Other ECM circulators, the Bell and Gossett
  ecocircs in particular, are expected to show three or four maxima per
  cycle; the indicator must not assume the Grundfos shape.
- The eGauge `05-secondary-pump` register and the CT disagree by a factor
  of four on the pump's current; the checks are in
  `what-the-ct-reports.md` "eGauge sanity checks".
- Bench facts for the board and the CT inputs (the 470 Ω burden per input
  behind a reversed-numbered DIP switch, the bias shortfall) are the scada
  executor `gw108-rev-c-board.md`; the SCT-013 scale, 0.235 V RMS per amp
  with clipping at 0.5 V, is the bench constant in `what-the-ct-reports.md`.
- The capture tool today is `starter-scripts/ct_waveform.py` (folds
  samples at the fitted mains frequency, writes CSV under the box's state
  dir). The sema word `gw.adc.waveform` v000 already describes one burst
  of raw conversions with chip settings and host-timed offsets.
- This is the short-term design inside the larger metering project
  (settlement-grade metering at the transactive-load boundary, good-enough
  sub-metering for the in-house MarketMaker, indicator metering from white
  wires and pumps). The CT here is an indicator, not a meter.
