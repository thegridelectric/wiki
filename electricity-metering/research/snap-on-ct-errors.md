# Snap-on (split-core) CT measurement error

Status: Draft · Pass 0 · Updated 2026-11-21

> What this is: a research note on the measurement errors of split-core
> (snap-on, clamp) current transformers: construction, conductor position,
> neighbouring conductors, low current, burden and phase shift, closure
> and temperature, and whether a snap-on CT can be part of a
> revenue-grade install. Read from datasheets, standards reproductions
> and published tests on 2026-11-21 by a research agent; quotes are
> verbatim from the sources named. Not normative.

## Plain conclusion

With a good revenue-grade split-core CT (Continental Control Systems
Accu-CT Opt C0.3 or C0.6, Dent CT-SRS, or equivalent), centred, closed
clean, on a correctly sized core:

| load | realistic total error | what dominates |
|---|---|---|
| 100% of rated | about ±0.5% | datasheet ±0.3 to 0.5% ratio, ±0.125 to 0.25° phase, up to ±0.1% position |
| 10% of rated | about ±1% with neighbours 25 mm away; several % if a heavy conductor touches | adjacent-conductor pickup, 0.16% of rated from a touching 100 A conductor is 1.6% of the reading |
| 1% of rated | ±1 to 2% in a clean panel | neighbours, and phase error at low power factor; the standards stop guaranteeing at 10% (IEEE) or 5% (IEC) |

With a cheap clamp (YHDC SCT-013 class, no per-unit calibration): ±3%
spec at 100% with measured batch offsets of +1.25% and −7%; at 10%
measured −1.2% and −3.2% and 3 to 4° of phase at an 18 to 22 Ω burden
(8 to 10° at 120 Ω), which is a 13% power error at power factor 0.45
unless the meter compensates; at 1% outside the datasheet range and
noise-limited.

For a 2 A circulator the practical answer is a 5 A-rated revenue-grade
split-core (Dent CT-SRS-005, 0.05 to 10 A; or CCS ACTL-0750-005), so the
pump sits at 40% of rating rather than 10%, with the meter programmed
with that CT's phase constant and the CT 25 mm from the heat-pump feeder.

## Split-core against solid-core

The joint is an air gap in the magnetic circuit. It raises magnetizing
current, so ratio and phase error grow, most at low current, and the gap
varies with each closure. Teng et al., *Measurement* 2022, on a 50 A
split-core prototype: "when the gap length changes with 0.104 mm, the
magnitude error and the phase error increase more than 5.09% and 78.7
mrad". Measurement Canada S-E-07 §1.0: "Specifications for current
transformers are applicable only for solid core devices."

Older and cheap split-core: CCS "Measurement errors due to CT phase
shift": solid-core "phase angle errors in the 0.2 degree to 0.5 degree
range"; split-core "ranging from 1.0 degree to 2.0 degrees" and "as high
as 6.0 degrees for the low current CTS-0750-xxx models". Magnelab
SCT-0750 datasheet: "Linearity accuracy ± 1%", "Phase angle < 2 degrees
(valid for 70A or higher)". Good modern split-core closes the gap to
solid-core class with lapped faces and per-unit calibration (Energies
2021, Lodz: a four-section winding meets 0.2S).

| grade | ratio | phase | range | source |
|---|---|---|---|---|
| cheap clamp (SCT-013-000) | ±3% | not specified | 10 to 120% | datasheet via search excerpt: "Non-linearity: ±3% (within 10% ~ 120% of rated input current)" |
| class 1 (CCS ACTL-0750 standard) | ±0.75% | ±0.50° | 1 to 120% | install guide: "Accuracy: ±0.75% from 1% to 120% of rated primary current" |
| IEEE 0.6 / IEC 0.5S (ACTL-0750 Opt C0.6) | ±0.50% | ±0.25° | 1 to 120% | "Phase angle: ±0.25 degrees (15 minutes) from 1% to 120% of rated current" |
| IEEE 0.3 / IEC 0.5S (ACTL-1250 Opt C0.3) | ±0.30% | ±0.125° (10 to 120%) | 1 to 120%, −30 to +75 °C | datasheet §2.1: "±0.30% from 1% to 120% of rated current, from -30°C to +75°C" |
| IEC 0.2 / IEEE 0.3 (Dent CT-SRS) | ±0.2% at rated, typical | < 0.2° | 5 A model 0.05 to 10 A | "Ratio Error +/-0.2% at rated current (typical)", "Phase Error < 0.2°" |
| Accuenergy AcuCT-R | 0.5% | not stated | 5 to 120% | "IEC 61869-2 Class 0.5 (from 5% - 120% of rated current)" |

## Conductor position in the window

- The one quantified manufacturer figure: CCS ACTL-1250 Opt C0.3 §2.1,
  "Conductor Position Sensitivity: typical ±0.06%, maximum ±0.10%" and
  "The phase angle error varies by less than 0.01 degrees (0.6 minutes)
  at different positions." Window 45 × 32 mm, ferrite core.
- Installation rule, CCS "CT Installation and Wiring": "For best
  accuracy, the CT opening shouldn't be more than 50% larger than the
  phase conductor." If it cannot be centred, seat it in the bottom of the
  U-shaped half, away from the hinge.
- Large rectangular windows are much worse: a 5000 A pass-through CT
  (Sensors 2024, MDPI 24/17/5524, from the search summary, article not
  opened) went from about 3.8% centred to about 47.6% at the extremes.
- No published angle-of-conductor test was found.

## Neighbouring conductors

- OpenEnergyMonitor, "Interaction between CT sensors" (2018-03-31), an
  SCT-013-000 with a 100 A conductor touching its outside: "it indicated
  160 mA with 100 A touching". That is 0.16% of rating but an absolute
  offset: on a 2 A circuit it is 8% of reading.
- Two CTs touching against 50 mm apart on about 50 A: "The effect is
  about a 0.2% increase in the indicated current when the C.T's are
  touching."
- CCS install guide: "try to separate the CTs on different phases by 1.0
  inch (25 mm) to minimize magnetic interference."
- No standards-based external-field limit exists for split-core CTs.

## Low current and what the classes guarantee

- IEEE C57.13 class 0.3 (PJM Metering Task Force deck, slide 10): "A 0.3
  class current transformer will provide +/-0.3% accuracy measuring 100%
  of the rated current and +/-0.6% accuracy measuring 10%". GE ITI deck:
  "No accuracy guaranteed at current levels less than 10%".
- Classes 0.15 and 0.15S (GE ITI slides 33, 35): "±0.15% Accuracy from
  100% up to RF", "±0.3% Acc. from 5% - 100%"; 0.15S "±0.15% Accuracy
  from 5% up to RF" and "No accuracy guaranteed at current levels less
  than 5%". No IEEE metering class reaches 1%.
- IEC 61869-2 0.5S (vendor reproduction of Table 202): ratio ±1.5 / 0.75
  / 0.5 / 0.5 / 0.5% at 1 / 5 / 20 / 100 / 120%; 0.2S ±0.75 / 0.35 /
  0.2%. Plain class 0.5 has no 1% point.
- ANSI C12.20 is a meter standard and says nothing about meter-plus-CT
  system accuracy. Schneider white paper: combining by root sum square,
  "a Class 0.2 meter and 0.15% instrument transformers would be 0.292%."
- Low power factor amplifies low-current phase error: PJM "Instrument
  Transformer Errors" worksheet, at 2% of rated current the watt-hour
  error is 0.21% at PF 1.0 but 10.32% at PF 0.017.

## Burden and phase shift

- Phase error grows with burden and falls with current. OpenEnergyMonitor
  SCT-013-000 report (Issue 6, Conclusions): "The maximum phase error of
  4º from the latest batch with the 18 Ω burden is insignificant" ...
  "the error of nearly 10º with a 120 Ω burden could be troublesome". At
  22 Ω the curve is "commendably flat (within a band factionally more
  than 1 degree wide)"; "It was difficult to make meaningful measurements
  below 250 mA". Frequency response at 39 Ω, 30 A: "phase error remained
  below 1 degree and amplitude error remained below 1% up to the 13th
  harmonic".
- 470 Ω and 33 Ω were not tested in any source found. By the measured
  trend, 33 Ω sits near the 22 Ω result (4 to 5°) and 470 Ω well past the
  220 Ω case, saturating in the low tens of amps. This is inference.
- Why it matters: CCS example, a 3.3° lagging error at PF 0.45 gives a
  13.1% power overread.
- Compensation: Dent CT-SRS footnote, class is met "When CT phase shift
  is set as follows: 5A = -0.10°, 50A = -0.23°", a per-model constant in
  the meter. ATM90E32AS application note §4.2.7: "Metering calibration
  flow is gain first then phase angle", phase calibrated at PF 0.5
  lagging, and §6.1 splits the current range into three segments with
  their own phase coefficients, because phase error varies with current.
  ADE7753 (search excerpt): "A phase error of 0.1° to 0.3° is not
  uncommon for a current transformer (CT)"; its PHCAL register is meant
  "only for small phase errors in the range of 0.1° to 0.5°".
- The burden resistor itself: 1% tolerance and ±100 ppm/°C
  (OpenEnergyMonitor, "Sources of Error in the emonTx").

## Closure, temperature, aging

- CCS install guide: "Make sure the mating surfaces are clean. Debris
  will increase the magnetic gap, decreasing accuracy." Gap sensitivity
  per Teng et al. above. No manufacturer publishes a reclose
  repeatability spec and no open-close cycling study was found.
- Temperature: CCS ACTL-1250 C0.3 holds ±0.30% over −30 to +75 °C but
  tightens phase only to +55 °C; ACTL-0750 C0.6 relaxes phase to ±0.50°
  "below 0°C from 1% to 10% of rated current". Teng et al.: temperature
  variation changed errors "not exceeding 2.30 mA/A and 1.6 mrad". No
  manufacturer gives a %/°C coefficient.
- "The Accu-CT can be damaged by impacts or by being dropped. This can
  result in reduced accuracy"; "excessive DC will degrade the AC
  accuracy." Aging: no quantitative source found.

## Can a snap-on CT be revenue grade

- Products exist and are UL 2808 Listed as field-installed CTs: CCS
  ACTL-0750/1250 (E363660), Dent CT-SRS, Accuenergy AcuCT-R (E469633).
  Classes reached: IEEE C57.13 0.3 and IEC 0.2 / 0.5S.
- ANSI C12.20 is a meter class. The only split-core C12.20 claim found is
  eGauge's: "certified for ANSI C12.20 0.5% accuracy when used with
  eGauge meters", a system certification of meter plus its CT.
  Measurement Canada excludes split-core CTs from utility billing
  outright. No US utility billing document that accepts split-core CTs
  was found.
- Price: CCS 2014 MSRP "$43.50" standard and "$57.00" Opt C0.6 with
  calibration certificate; Accuenergy AcuCT-R about $48 to $82 in 2026
  listings (search excerpts).
- Conditions the datasheets attach: conductor centred, clean faces, 25 mm
  between CTs, frequency-matched calibration, the temperature window, the
  meter programmed with the CT's phase constant, indoor use, no DC, no
  impacts.

## Not opened

IEEE C57.13 and IEC 61869-2 texts (paywalled; limits from Measurement
Canada S-E-07, a GE ITI utility training deck and vendor reproductions),
the ADE7753 datasheet, the Sensors 2024 cable-position paper, the YHDC
SCT-013 datasheet (image-only), Magnelab revenue-grade datasheets.
