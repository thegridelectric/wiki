# scada-measures-gw108-cts

Status: Draft · Pass 0 · Updated 2026-10-09 · Linear: [OPS-581](https://linear.app/gridworks/issue/OPS-581)

**EDD: yes** a capture on spruce with a clamp-meter reading of the same
pump at the same minute is the verification; the vocabulary and the
actor reach Verified only when a scada reading matches the meter.

> What this is: the scada reads the gw108's four current-transformer
> channels and reports current, through vocabulary that says what each
> channel measures. The measurement chain itself (board circuit, capture
> word, bench) is settled and recorded in the starter-scripts executor
> "The gw108 CT chain"; this design carries the component vocabulary and
> the scada actor that were out of scope there.

## The vocabulary: three levers and a scale

What a CT channel can measure is set by three things (a conversation
with Joe, 2026-09-02): the CT's winding ratio, the number of passes of
the power conductor through the CT, and the burden resistor across the
CT's leads. The board offers 470 Ω behind a per-channel jumper; any
resistor can be added at the terminals; some CTs (the eGauge-style
voltage-output kind on spruce's secondary pump) carry their burden
inside and must run with the board jumper open.

Encapsulate the three as `CurrentTransformerMeasurementScale` =
burden × passes / ratio (the board's default is 470 × 1 / 2000 = 0.235
V per A). With the built-in burden a channel reads up to roughly 540 W
before the ADC rails, far above a sub-100 W pump, which is the reason
for rescaling by passes or burden.

Words this implies, none yet in the registry (check `sema/definitions/`
before authoring; `i2c.ct.interface.capability` exists for the board
side):

- `BoardBurdenResistors` on the board record (the jumpered 470 Ω per
  channel, present or not).
- `AddedBurdenResistors` on the channel instance.
- which CT is installed, with its winding ratio and, for voltage-output
  CTs, its rated output; the MakeModel head-fake carries neither.
- how it is installed: passes of the conductor, and which conductor.
- the derived scale the reading pipeline uses.

## Gates before the actor

- **The board fix.** An empty CT input reads most of its neighbour's
  signal because the shared 1.65 V bias node is held only by two 100 kΩ
  resistors; a 10 µF capacitor from that node to ground stiffens it
  (the finding and the circuit are in the starter-scripts executor).
  Until spruce's board carries the capacitor, channel readings are not
  independent and no scale can be trusted.
- **The field answers.** Which conductor each CT clamps and how many
  passes, the CT2 label's rated output, the JP4 shunt fitted for CT1.
- **The scale capture.** One capture on CT2 with a clamp-meter reading
  of the secondary pump's amps at the same minute, which pins the
  scale for that channel directly.

## The actor (Open)

What the scada does with a channel once the scale is known: sample the
ADS1115 (single-shot conversions, bus-timed at about 390 per second on
the 100 kHz bus), fold a second or two onto one mains period, report an
RMS current on a channel named in the layout. Open: whether the actor
reports RMS only or also publishes `gw.adc.waveform` captures on
demand; where the fold runs; how the channel is named and configured in
the hardware layout (`CtAdc` on the board record is the hook).

## ▶ Do this next

Get the 10 µF capacitor onto spruce's board and re-run the empty-input
check from the bench rung (`experiments/2026-09-07-gw108-ct-testing/`):
P0 with nothing attached should fall to noise while P3 keeps the CT's
waveform. That capture is the gate for everything above.
