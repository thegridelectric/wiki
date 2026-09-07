# CT measurement chain (hub)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-518

**EDD: yes** bench captures on the real gw108 (honeysuckle, then spruce)
are the verification; spokes reach Verified only when a capture runs
against the chip.

> What this is: the gw108's current-transformer channels become a
> measured, described chain: a published sema word that carries a couple
> of wavelengths of ADC readings from one CT channel (terminal asset
> alias, message id, created-at, sample rate, the readings), the
> vocabulary that describes what a CT channel measures, and the bench
> runs that validate the chain. The bench harness lives in `experiments/`
> (the box's one clone, hard-coded addresses) and speaks the word through
> the vendored snapshot; the scada actor is out of scope here and follows
> only after the CT jumper is on spruce.

## The chain (verified from the RevB schematic and the board record, 2026-09-07)

Each CT terminal pair drives a 470 Ω burden biased at 1.65 V, RC-filtered
and clamped, read single-ended by an ADS1115 at address 72 on the default
bus (the board record's `CtAdc` capability, 3.3 V reference, four
channels). The burden is a per-channel jumper (JP1 to JP4 on the ADC
sheet): bridged, the board's 470 Ω is across the CT; open, the board has
no burden and whatever is wired at the terminals is. The chip's
ALERT/RDY pin is unconnected, so no conversion-ready signal reaches the
pi. A CT channel carries the AC waveform centered on 1.65 V. The
chip's ceiling is 860 samples per second, 14 samples per 60 Hz cycle,
three cycles in 43 samples. 860 is not a multiple of 60, so consecutive
cycles land at different phases: folding a second or two of samples onto
one period (frequency fitted from the data) gives a composite waveform
with hundreds of points per cycle. The chip's digital filter at 860 SPS
rolls off in the few-hundred-hertz range (number not verified; check the
datasheet before claiming which harmonics survive). For a 40–60 W bulb the
2000:1 CT into 470 Ω gives roughly 80–120 mV RMS; looping the wire twice
doubles it.

Three levers set what a channel can measure (from a conversation with
Joe, 2026-09-02): the CT's winding ratio, the loop count of the power wire
through the CT, and the burden (470 Ω built into the board; any resistor
can be added at the terminals). Encapsulate as
`CurrentTransformerMeasurementScale` = resistor × loops / ratio (today
470 × 1 / 2000 = 0.235; the built-in burden measures up to ~540 W, far
above sub-100 W pumps, hence the interest in rescaling). Vocabulary this
implies: `BoardBurdenResistors` on the board record; `AddedBurdenResistors`
per instance; which CT is installed, with its ratio (the MakeModel
head-fake carries neither); how it is installed (loop count); and the
derived scale the reading pipeline uses.

## Decisions (2026-09-07)

- **The capture word is `gw.adc.waveform/000`, staging until the bench
  settles it.** It carries the terminal asset alias, a message id, the
  message creation time (`MessageCreatedMs`, JournalKeeper's name), the
  chip (`i2c.adc.type`) and its bus address, the chip input, the PGA
  full scale in millivolts, the configured data rate, the wall clock of
  the first conversion, a host-timed microsecond offset per code, and
  the raw signed 16-bit conversion-register codes. Offsets ride along because
  the pi cannot see the chip's conversion-ready signal: the sampler takes
  single-shot conversions, one per bus request, so the spacing is bus-timed
  (about 390 per second at 100 kHz). The 2026-09-07 dry run showed that
  free-running the chip and polling for changed codes collapses duplicates,
  so that path is dropped and the offsets stay. Promotion to published
  comes after the spruce runs. The word is ADC-generic; CT meaning lives in the component
  vocabulary.
- **Bench before the scada, from `experiments/`.** The harness runs on
  the pi from its `~/experiments` clone with the scada venv's python and
  writes instances through the vendored class (`gwexp.sema`); no
  hand-built dicts. The scada actor and its component records come after
  George puts the CT jumper on spruce.
- **Order of runs:** the 2026-09-07 spruce dry run (open inputs, all four
  channels) validated the sampling path and the fold, so the honeysuckle
  run is not needed. Next: spruce's secondary pump on CT2 when it runs
  under the summer schedule (about noon); then the store pump on CT1 once
  its burden jumper is fitted; the 40–60 W incandescent bulb stays the
  pure resistive reference for scale, run when someone is at the house.

## Field facts (spruce, 2026-09-07)

Traced from the RevB board nets and the spruce layout generator's CT
notes; the numbers in the table are what George needs at the panel. The
board-side account (signal chain, jumper rule, the speed-ladder table)
lives in the scada design's gw108 board spoke; this hub keeps the field
checklist and the vocabulary work.

| Terminal | ADS1115 input | Burden jumper | What is clamped (spruce) |
| --- | --- | --- | --- |
| CT1 | AIN0 (P0) | JP4 | store pump: current-output CT, 100 A to 50 mA |
| CT2 | AIN1 (P1) | JP3 | secondary pump: eGauge-style voltage-output CT, 20 A rated |
| CT3 | AIN2 (P2) | JP2 | nothing |
| CT4 | AIN3 (P3) | JP1 | nothing |

The CT block is the screw-terminal strip labeled CT INPUTS on the board's
left edge below THERMISTOR INPUTS, channels top to bottom CT1..CT4, each a
+ (signal) and − (shared 1.65 V bias) pair. The burden jumpers are 2-pin
0.1" headers just right of the block, numbered the opposite way to the
channels; a shunt puts the board's 470 Ω across that channel. The dry run
saw P0 and P1 sitting cleanly on the bias with a 3 mV mains pickup and P2,
P3 floating off it with 15–30 mV of noise, which fits CTs wired to CT1 and
CT2 only. No shunts are fitted today.

**For George:**

- Fit a shunt on JP4 (CT1, store pump). Without it the current-output CT
  runs open-circuit and reads nothing useful.
- Leave JP3 open (CT2, secondary pump). Its burden is inside the CT; 470 Ω
  in parallel changes its scale.
- Read the CT2 label and report its rated output (millivolts at 20 A);
  the notes do not record it and the scale needs it.
- Confirm each CT clamps a single conductor (hot or neutral, not the whole
  cable) and report how many passes of the conductor go through the CT.
- Photos of both CT labels and of the CT block with jumpers.
- A clamp-meter reading of the secondary pump's amps while it runs, with
  the time, so a capture at the same minute gives the scale directly.

Expected signals on one pass: store pump ~0.5 A gives ~120 mV RMS on CT1
(2000:1 into 470 Ω); the secondary pump on CT2 gives a few millivolts per
tenth of an amp at a 333 mV-at-rated CT, so CT2 is the channel where extra
passes help. Keep passes at four or fewer so peaks stay inside the rails.
The 2026-09-07 speed ladder (bench README) shows CT2 tracking the pump
from 10 mV rms at minimum speed to 274 mV at maximum on one pass, with the
fold locking at every level, so extra passes are not needed for the
secondary pump; only the absolute scale is missing.
Cross-check: the secondary-btu pico reports `secondary-pump-ct`
(VoltsTimes100) from its own CT; 167 with the pump off is its resting
bias.

## Spokes

- the capture word `gw.adc.waveform` ✅ staged (sema branch
  `jm/adc-waveform-word`)
- **the bench: sampler, fold, and the three runs**
  (`experiments/2026-09-07-adc-waveform-bench/`, its README is the runbook)
- the CT component vocabulary (Joe's levers)

## ▶ Do this next

The chain is validated (2026-09-07 12:30, secondary pump running on
CT2: composite 181 mV rms, harmonic-rich, noise 26 mV; bench README
Found). What blocks the scale is in the field, so the next move is
George's checklist above, plus one added item: with the secondary pump
running and the store pump off, CT1 showed the same waveform as CT2, so
report which conductor each CT is actually on. When the answers are in:
one more P1 capture with a clamp-meter reading of the pump's amps at the
same minute, which pins `CurrentTransformerMeasurementScale` for CT2.
