# Accuracy when voltage and current are read by different processors

Status: Draft · Pass 0 · Updated 2026-11-21

> What this is: a research note on how accurately real power and energy
> can be metered when the voltage and the current are sampled by
> different processors. Not normative. It frames the timing budget, what
> delivers it, where the CT sets the floor, and what the industry does.

## The question reduces to a shared timebase

Real power is the average of v(t) times i(t). If the current samples are
timestamped Δt late relative to the voltage, the meter sees the
fundamental displaced by a phase θ = 2π·60·Δt. At 60 Hz, 1 ms is 21.6
degrees and 10 µs is 0.22 degrees. The relative error in real power is
about θ·tan φ, where φ is the displacement angle between fundamental
voltage and current. For a resistive load φ is zero and the error is only
θ²/2. Revenue-grade standards (ANSI C12.20) test at power factor 0.5 as
well as 1.0, and at 0.5 the error grows linearly with the offset.

| clock offset Δt | error at pf 1.0 | error at pf 0.9 | error at pf 0.5 |
|---|---|---|---|
| 1 ms | 7% | 18% | 65% |
| 100 µs | 0.07% | 1.8% | 6.5% |
| 10 µs | 0.0007% | 0.18% | 0.65% |
| 5 µs | negligible | 0.09% | 0.33% |

A 0.5% class meter at pf 0.5 has a budget of about 5 to 8 µs. A 0.2%
class, about 3 µs.

## What delivers the timebase

- **GPS PPS**: 50 to 100 ns. Two to three orders of magnitude inside the
  budget, plus absolute UTC for the ISO interval boundaries and a
  location proof. The location and UTC benefits justify it; the metering
  accuracy does not need it.
- **A shared sync wire** between the two processors (a GPIO pulse once a
  second): under 1 µs. The cheapest answer when both processors are in
  one enclosure.
- **PTP (IEEE 1588) with hardware timestamping** over Ethernet: sub-µs.
  Works across boxes; needs PTP-capable NICs.
- **NTP** over LAN or Wi-Fi: 100 µs to several ms. Fails the budget at
  any power factor below about 0.95.

Drift between syncs: a 20 ppm crystal drifts 20 µs per second, so with a
once-per-second pulse the current processor measures its own rate against
the pulse and corrects, rather than resetting. After rate correction the
residual is temperature drift, well under 1 µs per second.

## The CT sets the real floor

A clamp CT of the SCT-013 kind introduces 1 to 3 degrees of phase shift
of its own, varying with burden and current level: 50 to 140 µs of
equivalent timing error. A 5 µs sync is an order of magnitude under the
CT's phase error. Metering ICs correct the CT shift with a per-channel
phase calibration register; a split design needs the same per-CT
calibration constant. The clamp's magnitude accuracy (1 to 2%
uncalibrated) and the conductor's position in the window are the other
CT errors, and timing does not touch them. Per-unit calibration against a
reference does.

## The voltage need not be sampled at the same instants

Residential mains voltage is a near-pure sinusoid, total harmonic
distortion typically 1 to 3%. The voltage processor can publish a model
once a second: frequency, phase at a reference timestamp, RMS magnitude,
optionally the low harmonics as phasors. The current processor evaluates
the model at each of its own sample timestamps and accumulates v·i
locally. The one requirement is the common timebase above.

The cost of the model is the voltage harmonics left out. On a load whose
current is mostly harmonics (the spruce Grundfos UPMS 20-78, crest factor
2.8), the harmonic real power is voltage THD times harmonic current
fraction: up to 1 to 3% of real power at worst-case phase alignment,
usually much less. That caps a fundamental-only model near 1% on
distorted loads. Publishing a handful of voltage harmonic phasors per
second removes the cap. The sub-metering tier is served by the
fundamental model; the settlement tier wants the harmonics or a single
chip.

## Sample rate on the current side

The ADS1115 at 860 SPS gives 14 samples per cycle and a Nyquist limit at
430 Hz, the 7th harmonic. A pulsed current has energy well above that,
which aliases. RMS over many cycles still averages acceptably because 860
is not a multiple of 60 and the samples walk through all phases; real
power against a clean voltage model also averages acceptably, since the
aliased harmonics contribute almost no real power against a clean
voltage. Revenue-grade metering chips sample at 4 to 8 kSPS with
simultaneous V and I conversion; that is the bar for the settlement tier.

## Where the industry sits

Revenue meters and consumer energy monitors (eGauge, Emporia, IoTaWatt,
Sense, OpenEnergyMonitor) sample V and I on one board, usually one
metering IC, so the V-to-I phase is calibrated inside the chip. Split
measurement with a shared timebase is how synchrophasor units (PMUs)
work, with GPS, at utility scale and price. No low-cost product is known
to split V and I across processors by design. That is a gap, not
evidence against it: a one-wire or PPS sync plus a published voltage
model is simple, and the reason it is not done is probably that nobody
needed the current side to be a separate cheap node before.

## What this says for GridWorks

- A voltage node per house (one divider or transformer, one processor, a
  PPS or sync output) and current nodes wherever the CTs are (a pico on a
  Gw101, the Gw108's ADC) is a sound architecture for the sub-metering
  tier at the 1% level with today's parts.
- It reaches the settlement tier if the current side samples at a few
  kSPS, the CTs are calibrated per unit, and the voltage side publishes
  harmonics.
- The GPS chip is justified by location verification and UTC; timing
  accuracy follows for free.
- Whether the MarketMaker lives in the voltage node is a separate
  question from accuracy. The voltage node is the natural place because
  it is the one per-house device every current node depends on.

## Not yet checked

- The figures above are derived, not measured: no two-processor capture
  has been run. The first experiment is two picos on one sync wire, one
  on a voltage divider and one on a CT, against the eGauge.
- Whether any current metering IC accepts an external voltage phasor in
  place of a sampled voltage channel.
- The displacement angle of the Grundfos fundamental (needs a voltage
  capture alongside the CT).
