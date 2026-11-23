# Voltage beacon (hub)

Status: Draft · Pass 0 · Updated 2026-11-23 · Linear: OPS-706

**EDD: yes** every step is witnessed against the eGauge on a real
circuit: the bench rig's power number, the sync between nodes, the
model's accuracy across a day of mains drift.

**▶ Active spoke: [`bench-rig.md`](bench-rig.md)**

> What this is: the hub for the first of GridWorks' two metering
> products (`../../README.md` "The chosen architecture"). The voltage
> beacon is a low-voltage device with no mains on the board. It reads a
> listed Class 2 adapter for the mains voltage, keeps the drumbeat,
> publishes the voltage model every CT node needs, computes power from
> CT waveforms sent to it or lets a CT node compute from the model, and
> hosts the economy market maker. It is designed as the first half of
> our own boundary meter (OPS-707): the voltage input is swappable, and
> the clock, the published model, the sync interface and the host are
> the part that does not change.

## Spokes

- **[`bench-rig.md`](bench-rig.md)**: two picos, an adapter, one sync
  wire, a CT, against the eGauge. The first witnessed power number from
  a split voltage and current.
- `voltage-model-and-sync.md` (to open): the published model
  (frequency, phase at a reference time, RMS, the low harmonics, on the
  drumbeat) and the sync interface as sema words; the cadence against
  mains frequency wander.
- [`satellite-drumbeat.md`](satellite-drumbeat.md): how a satellite
  CT node gets on the drumbeat over Wi-Fi or Ethernet; the ESP32-P4
  PTP bench.
- `clock.md` (to open): the beacon's own oscillator, the wired pulse to
  docked nodes, drift between syncs; GPS for UTC and location, and
  whether the beacon needs it at all.
- `voltage-input.md` (to open): the Class 2 adapter and divider, its
  per-unit phase and magnitude calibration, the fundamental-only model
  it supports; the metering front end as the alternative input inside
  the boundary meter.
- `ct-node-interface.md` (to open): docked nodes (CT ports in the
  panel, wired sync) and remote nodes (a pico by a far load, radio
  sync); what a node sends and receives.
- `power-on-or-off-beacon.md` (to open): a node ships timestamped
  current waveforms and the beacon multiplies, or a node takes the
  model and ships power; both, with waveform-on-request as the audit.
- `marketmaker-host.md` (to open): the economy market maker on the
  beacon's processor; what that asks of the processor and the radio.

## Notes

- Why a low-voltage device reaches the field in weeks and a meter takes
  a year: no mains on the board means no listing of its own, the same
  footing as the Gw108 today. The moment a mains-sensing part goes on
  the board it joins the meter's certification timeline, so the beacon
  stays on the adapter.
- The adapter path's residual is about ±0.3° of phase after per-unit
  calibration over the US line-voltage range, and no harmonics; the CT
  nodes are floored by their clamps at 3 to 4° anyway
  (`../../research/split-voltage-current-accuracy.md`, the
  OpenEnergyMonitor adapter reports). Sub-metering tier, about 1%.
- **Timing budget, decided 2026-11-22.** The aim is an order of
  magnitude under the best metering we want, class 0.2. The error a
  sync offset Δt puts into real power is about θ·tan φ with
  θ = 2π·60·Δt, so it depends on the load's displacement angle: 5 µs
  is 0.11°, negligible on a resistive load, 0.09% at power factor 0.9
  and 0.33% at the 0.5 test point of ANSI C12.20 (the table in
  `../../research/split-voltage-current-accuracy.md`). An order of
  magnitude under 0.2% at power factor 0.5 is 0.3 µs; at 0.9 about
  1 µs. So the budget for a node claiming settlement grade is **about
  1 µs**: the GPS pulse at 60 ns and a wired PPS to docked nodes meet
  it. The radio path to remote nodes is **about 10 µs**, which is
  0.65% at power factor 0.5 and 0.2% at 0.9: sub-metering tier, and a
  remote node never claims settlement grade. The boundary meter's own
  reading is outside this budget: voltage and current share one clock
  inside the metering chip. The CT's own 3 to 4° of phase error,
  calibrated per unit, is larger than either budget.
- GPIO sync lines cannot be assumed for every CT node: a load far from
  the panel has no wire back. So the beacon has a GPS receiver for UTC
  and a sync source of its own, and transfers time to remote nodes over
  its radio; wired PPS stays for the nodes docked in the panel. The GPS
  also gives the location proof the vision wants: the place on the grid
  topology, so a fix within 30 m is enough and a window antenna serves.
- GPS, checked 2026-11-22 against the u-blox MAX-M10S data sheet and
  integration manual: time pulse accuracy 30 ns RMS, 60 ns at 99%;
  tracking sensitivity -167 dBm; 25 mW in continuous tracking; UART and
  I2C; it powers and supervises an active antenna itself; and its PPS
  keeps running on the module's own oscillator without a fix, drifting
  off the true second until lock returns. Module about $20 at 100
  units; the SparkFun breakout $45.95; a 28 dB active antenna on a 5 m
  cable $21.50. Timing-grade receivers (ZED-F9T, about 8 times the
  price) add a fixed-position mode that keeps a valid pulse on one
  satellite, which matters only if a window antenna sees fewer than
  four. A basement panel has no sky, so the antenna run to a window or
  outside is an install cost to design for; metallized glass blocks it.
  With a cheap TCXO the pulse leaves a 10 µs budget within tens of
  seconds to minutes of losing the fix, so the beacon states its timing
  quality (locked, holdover with an age, invalid) in what it publishes.
- No purchasable class 0.2 meter publishes a shared timebase or hosts
  user code (`../../hardware/existing-meters.md`), which is why the
  beacon is ours whichever meter is bought.
