# pico-sensor-fault-reporting (design)

Status: Draft · Pass 0 · Updated 2026-09-21 · Linear: OPS-556

**EDD: yes** the bench harness (OPS-554) is the verification: a thermistor
lead pulled from a live BTU pico shows up as a fault in the scada within
one second and stays visible every capture period until the lead goes
back; the spruce store pipes, both disconnected on 2026-09-21, are the
field picture.

> What this is: the BTU-meter firmware stops hiding a dead thermistor. Two
> changes made together so the next pico release is the final shape: a
> plausibility gate on the temperature read, and an explicit per-channel
> fault in the post. The scada-side rule that catches the same case for a
> pico that is never upgraded is in the sensor-freshness spoke of OPS-392.

## The problem

At spruce on 2026-09-21 both store-pipe thermistors were disconnected, one
reading 0 V and the other 3.3 V. The report events show what the scada
heard:

- Until 16:15 UTC `store-cold-pipe` posted 135 to 146 C, thirty to a
  hundred times per five-minute period. A near-rail voltage passes the
  firmware's gate and rail noise crosses the 0.2 C async delta constantly.
- From 16:15 both temperature channels vanished from the posts while
  `store-flow` kept arriving every period. The firmware's
  `celsius_from_volts` returns `None` below 0.001 V or above 3.299 V, and
  `report()` omits a `None` channel from both the sync and the async post.
- The scada holds each channel's last value: nothing distinguishes a
  channel that is quiet because it is steady from one that is gone, and
  the BTU actor's liveness is per pico, fed by the flow channel.

So a dead sensor is either wrong data or silence, and the scada learns of
it, at best, from the snapshot's age rule 630 s later, and never in
`latest_channel_values`.

## The changes

Both in `btu_meter/async_btu_main.py`; the same shape for the CT input.

### 1. A plausibility gate on the read

`measure_temp` classifies before it converts. A read within a margin of
either rail is a fault, not a temperature; a converted temperature outside
the range water in a pipe can have (about -30 C to 130 C) is a fault too.
The margin and the range are named constants, not literals. The read
returns either a temperature or a fault; `None` goes away as a third,
silent state.

### 2. The fault rides the post

Today `multichannel.snapshot` carries three parallel lists: channel name,
integer measurement, unit. A faulted channel cannot be expressed, so it is
dropped. The change gives the post a way to say "this channel, no
reading, because X":

- **Vocabulary.** `multichannel.snapshot` is not a sema word yet (gwsproto
  holds a hand-derived class). Registering it, and the shape a fault takes,
  is a sema addition and is discussed before any edit (sema spec is
  change-controlled). The shape to discuss: a fourth parallel list of
  per-channel status, an enum with `Ok` and the fault kinds, with the
  measurement for a faulted channel carrying the raw millivolts so a human
  can tell open from short. Open below.
- **Timing.** A faulted channel is posted every sync like any other, so the
  scada hears it once per capture period. A transition, good to fault or
  fault to good, is posted async at once, so the scada learns within a
  second, not a period. The transition is the async trigger; a fault does
  not re-post async while it persists.
- **Scada.** `ApiBtuMeter` reads the status: a fault sends the scada one
  `ChannelFlatlined` for the channel (the message that already clears a
  channel from `latest_channel_values`) and no `SyncedReadings` value for
  it; a return to `Ok` reports the value at once. The flood of near-rail
  readings ends with change 1, on its own.

## Tank module

The tank module posts raw microvolts and the scada converts, so the rail
is already visible there: spruce's `fancoil-depth3` shows 3,299,997 µV
and -123 C in the same report. The gate for that path belongs in the
scada's conversion, not in tank firmware, and is a scada change outside
this design. No tank firmware change here.

## Not in this design

- The ADC supply voltage as measured or configured, and integer ADC math
  in the BTU meter: OPS-402 "Not now".
- Per-channel liveness in the pico actors: OPS-392, sensor-freshness. It
  stays necessary after this design, for picos on older firmware and for
  a pico whose post loses a channel for any other reason.
- What control code does with a store-pipe channel that is `None`.

## Verification

Bench (OPS-554): a scenario that pulls one thermistor lead on a live BTU
pico. Green when the listener sees the fault within one second of the
pull, sees it again on every sync while the lead is out, sees the
temperature within one second of the lead going back, and sees no
temperature for that channel in between. Red on firmware at `td/pico-easy-fixes`
today, which posts nothing for the channel.

Field: spruce, store pipes as George has them. After the release the
snapshot shows both store-pipe channels absent while disconnected and both
present within a second of reconnection.

## Open

- The fault enum: which kinds are worth distinguishing at the pico
  (`RailLow`, `RailHigh`, `OutOfRange`), or one `NoReading` with the
  millivolts beside it.
- Whether the status list is a new version of a registered
  `multichannel.snapshot` or a new post word; the sema discussion decides.
- The rail margin and the temperature range, as numbers.

## Do this next

Open the sema conversation on the post's shape (vocabulary bullet above);
with the word agreed, write the bench scenario red, then change 1 and
change 2 together on the firmware branch, then the `ApiBtuMeter` reader.
