# Sensing hierarchy

Status: Draft · Pass 0 · Updated 2026-10-07

> What this is: the scada's sensing channels ranked by how much damage
> a lost or wrong reading does, with what the scada does about each
> today. It is the record the team reads before deciding how hard a
> channel's loss should be fought, reported, or paged on. It is not a
> sema word yet; the ranking has to settle in use first.

## How to read it

A channel is **lost** when nothing reads it (a dead eGauge, a quiet pico,
a thermistor at a rail) and **wrong** when it keeps reporting a value
that is not the plant's. The two fail differently: a loss can be
noticed and handled, a wrong value is acted on. Each row names who
reads the channel, what happens today on each failure, and the harm at
the end of that path. The rank is by the harm, not by how often the
failure has been seen.

Three kinds of harm, worst first:

1. **Equipment** damaged or faulted: a compressor run into a dead heat
   exchanger, a store overheated.
2. **Contract**: the transactive boundary misreported, a dispatch
   contract broken or refused on a false reading.
3. **Comfort and cost**: a cold house unseen, a store destratified, a
   charge missed or made on-peak.

The harms are not interchangeable: a comfort fault is recovered by the
next cycle, an equipment fault is not.

## The ranking

| Rank | Channel | Read by | Lost | Wrong | Harm |
|---|---|---|---|---|---|
| 1 | `hp-odu-pwr` (Nolan) | `HpWatch` ([`local-control.md`](local-control.md) "The heat-pump watch") | `Unknown` within 10 to 15 s; the secondary pump and iso valve run until a read returns. The buffer destratifies for the length of the outage; the heat pump is protected. | Stuck high, or standby above the off line: the pump runs between cycles; the watch warns after ten minutes (`hp-watch-held-on`). Stuck low: `HpDetectedOff` with the compressor running, the pump off, no flow through the heat exchanger. | Equipment |
| 1 | `hp-odu-pwr`, `hp-idu-pwr` (House0) | The sieg loop's start-up trigger and the defrost signature ([`sieg-loop.md`](sieg-loop.md)) | `None` after `ChannelFlatlined` or 2.1 capture periods; the loop is blind, which is full send. The defrost question falls back to the last real reading, bounded by a 20-minute timeout. | Stuck low during a defrost: the store valved onto a defrosting heat pump. Stuck high: the loop thinks the heat pump is running. | Equipment |
| 2 | `hp-lwt`, `hp-ewt` (House0) | The sieg loop and strat-protect | `None` is blind, which is full send. `MultipurposeSensor` sends no `ChannelFlatlined`; the 2.1-period backstop catches a dead ADS. | The sieg valve set against a temperature the loop is not at; the lift judgment wrong. | Equipment |
| 3 | Aggregate power (`PowerWatts` to the LTN) | The contract handler | Energy under contract integrated from the last reported power; `PowerWatts` cannot say unknown ([OPS-555](https://linear.app/gridworks/issue/OPS-555)). | The transactive boundary misreported for the length of the fault. | Contract |
| 4 | Critical-zone temperatures and setpoints | The cold watch ([`cold-house.md`](cold-house.md)) | A zone with no reading is logged and skipped: a cold zone unseen. | Reads low: a false cold, the dispatch contract broken and refused until a params file is pushed. Reads high: a cold house unseen. | Contract, comfort |
| 5 | Buffer `depth1`, `depth3` (the band) | Nolan local control, `MissingData` at 5 minutes | `ScadaBlind`: the call runs on the schedule alone. | Reads high: the buffer never charged, the house cools until the cold watch sees it. Reads low: the call on through every off-peak hour. | Comfort |
| 6 | Store temperatures (House0) | Usable energy ([`required-energy.md`](required-energy.md)), `fill_missing_store_temps` | Open: what the energy judgment does with a missing depth is not written here yet. | The on-peak readiness judged on a store that is not there: a cold house on-peak, or a charge missed. | Comfort |
| 7 | Zone heat calls (whitewire inputs, derived) | House0 distribution, `DistPumpMonitor` | A derived heat call left at its last value, on which the pump doctor can set the working relays (OPS-555). | A call that is not there runs the distribution pump; one unseen leaves a zone unserved. | Comfort |
| 8 | Flows (`dist-flow`, `sieg-flow`, `store-flow`, `primary-flow`) | BTU heat power; the dist pump doctor's recovery threshold | Open: which control decision reads a flow directly is not written here yet. | Heat power misreported; the pump doctor misjudges recovery. | Comfort |
| 9 | `forecast-oat`, `forecast-ws` (cloud) | Required energy | `compute_required_energy_wh` returns `None` without a forecast. | A wrong load forecast charges the store for a day that is not coming. | Cost |

## What the rank asks of each channel

The rank sets the bar for three things, none of them decided per row
yet:

- **How fast the loss is noticed.** A rank-1 channel is lost in seconds
  (the power meter declares a channel lost at 10 s); a rank-9 channel
  can wait a capture period.
- **What the scada does while the channel is lost.** A rank-1 loss
  takes the safe posture for the equipment whatever it costs in comfort
  (the pump runs). Lower ranks hold their last value or go blind.
- **Who hears about it.** A rank-1 or rank-2 loss that lasts is a
  condition a person should know about the same day; whether it is
  Warning or Critical is open (`primary.md` "Cross-cutting commitments"
  for the glitch levels).

## Open

- The House0 rows for store temperatures and flows need their consumers
  traced; the "Lost" cells say so.
- Whether "wrong" is detectable at all per channel: a plausibility
  range, a cross-check against a sibling channel (two store depths, LWT
  against EWT), or nothing.
- Whether the rank becomes a field on the channel's layout word once it
  has settled.
