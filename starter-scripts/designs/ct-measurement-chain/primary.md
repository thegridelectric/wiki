# CT measurement chain (hub)

Status: Draft · Pass 0 · Updated 2026-09-07

**EDD: yes** bench captures on the real gw108 (honeysuckle, then spruce)
are the verification; spokes reach Verified only when a capture runs
against the chip.

> What this is: the gw108's current-transformer channels become a
> measured, described chain: a published sema word that carries a couple
> of wavelengths of ADC readings from one CT channel (terminal asset
> alias, message id, created-at, sample rate, the readings), the
> vocabulary that describes what a CT channel measures, and the bench
> runs that validate the chain. Runs from the `starter-scripts` venv with
> hard-coded addresses; the scada actor is out of scope here and follows
> only after the CT jumper is on spruce.

## The chain (verified from the RevB schematic and the board record, 2026-09-07)

Each CT terminal pair drives a 470 Ω burden biased at 1.65 V, RC-filtered
and clamped, read single-ended by an ADS1115 at address 72 on the default
bus (the board record's `CtAdc` capability, 3.3 V reference, four
channels). A CT channel carries the AC waveform centered on 1.65 V. The
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

- **A published word, not staging.** The capture word carries the
  terminal asset alias, a message id, a created-at, and a couple of
  wavelengths of readings from one channel. Published means immutable, so
  the bench captures settle its fields (raw codes or volts, sample rate,
  count, PGA range) before the word gate.
- **Bench before the scada.** All runs use the `starter-scripts` venv and
  hard-coded addresses (the existing `gw108_test_code.py` pattern); the
  hand-coding carries the note naming the missing word. The scada actor
  and its component records come after George puts the CT jumper on
  spruce.
- **Order of runs:** honeysuckle first (no CT installed, so the capture is
  noise around the 1.65 V bias: it validates the sampling path and the
  fold); then a 40–60 W incandescent bulb on spruce as the pure resistive
  reference (near-sinusoidal); then spruce's secondary pump.

## Spokes

- the capture word (word gate in a sema-claiming session; sketch above)
- the bench sampler and fold (starter-scripts; experiments folder for
  each run's evidence)
- the CT component vocabulary (Joe's levers)

## ▶ Do this next

**First, the estimate.** Before any code: agree a point and a 90% interval
(hours) with Jessica for the whole design (sampler + fold, the three bench
runs, the word gate with mirror, the CT vocabulary), add the row to
`admin/jess-estimates.md`, create the Linear design issue and post the
scope there. Then build the sampler in `starter-scripts`: continuous-conversion mode on the
CT ADS1115 at 860 SPS, poll the conversion register, write timestamped raw
codes; a laptop-side fold that fits the frequency and plots the composite
waveform. Run it on honeysuckle. Then settle the word's fields from that
capture and open the word gate.
