# Sensor freshness

Status: Accepted · Pass 1 · Updated 2026-10-14

> What this is: how a channel becomes unknown to control code, and how
> a pico becomes dead, with the one bound both rest on. The ranking of
> what a loss costs is [`sensing-hierarchy.md`](sensing-hierarchy.md);
> this spoke is the mechanism under it. Distilled from the spruce-unlimbo
> work of 2026-09 (OPS-392).

## The bound

One rule, two altitudes. A channel is **fresh** when its latest read time
is inside 2.1 of its capture periods; a pico is **alive** when its latest
post is inside 2.1 of its expected post period. Stale and dead are the
same fact, no signal inside the nyquist window, and they share one
definition: the multiple is written once and imported by
`ScadaData.flatlined` (`actors/scada_data.py:281`) and `PicoLiveness`
(`actors/pico_liveness.py`); neither keeps its own number.

Why 2.1 and not 2 or less: a sensor that returns from a fault to within
its async delta is not posted async, so it is heard again only at the
next sync post. A bound at or below two periods flatlines a channel that
missed one sync. The tenth of a period above two covers the jitter in
that next post (0.8 s measured on Wiznet tank picos at 60 s; 6 s is
allowed). Why not looser: nothing in the data asks for it, and a looser
bound only delays the moment control code learns it is blind.

A `None` read time is stale: a channel flushed by `ChannelFlatlined` and
a channel never read are the same to a reader.

Open: on the renovation branch `PicoLiveness.MISSING_MULTIPLE` is 2.5
and `flatlined` has a local `nyquist = 2.1`; the shared definition goes
in with OPS-532. On `main` and `actual-spruce` the tank-module actor has
`NYQUIST_MULTIPLE = 2.1` (`actors/api_tank_module.py`, OPS-592) and the
btu actor keeps 2.5.

## Who declares a loss

- **The power meter declares its own, in seconds.** The driver thread
  keeps, per channel, the monotonic time of the last read that returned
  a value, and declares the channel lost once that is older than
  `power_meter_lost_after_s` (10 s; `actors/power_meter.py:319`): its
  latest and last-reported values go to `None`, aggregate power goes to
  `None` if the channel is transactive, and one `ChannelFlatlined` goes
  to the scada. Monotonic, because a wall clock stepped back by NTP
  would hold a deadline open. Counting reads does not work: a connect
  attempt can block 3 s and a poll skipped for reconnect backoff returns
  at once. An eGauge read that cannot connect returns `Ok` with value
  `None`, so without this the last good watts would be re-sent as a
  fresh reading for ever. The first good read after a loss is reported at
  once, aggregate power with it whatever its value. Read, start and
  hardware-ID warnings go out as Warning glitches, one a day per kind and
  channel.
- **A pico actor declares its pico and each of its channels.**
  `ApiBtuMeter` and `ApiTankModule` keep one `PicoLiveness` per pico and
  one per captured channel; a post feeds `heard` to the pico and to the
  channels it has values for, and only those. `check_liveness`
  (`api_btu_meter.py:451`, `api_tank_module.py:429`) runs on the 10 s
  tick. A dead pico: one `PicoMissing` to the pico-cycler and a
  `ChannelFlatlined` per channel, repeated once a minute while the
  silence lasts; while the pico is missing the per-channel check is
  skipped. A quiet channel on a live pico: one `ChannelFlatlined` for
  it, repeated once a minute, and never a `PicoMissing`. A single quiet
  channel does not cycle the rail. The BTU meter also raises a
  `quiet-channel` Warning glitch, once a day per channel.
- **Everything else is caught by the backstop.** `MultipurposeSensor`
  sends no `ChannelFlatlined`; a dead ADS is seen by the bound at 2.1
  periods, 630 s for a 300 s channel. The backstop compares wall-clock
  times, as the snapshot always has; a clock step can delay or hasten
  it, accepted at that bound.

## What a reader sees

`ChannelFlatlined` sets the channel's latest value and read time to
`None` (`scada.py`, `scada_data.py`). The heat-pump accessors `lwt`,
`ewt`, `hp_odu_pwr_w` and `hp_idu_pwr_w` return `None` when
`ShNodeActor.channel_is_live` (`actors/sh_node_actor.py:348`) is false,
so `lift_f` and `total_hp_pwr_w` do, and control code treats `None` as
unknown. A channel the layout does not have returns `None` before the
bound is asked. `flatlined` is safe for report-on-change channels
because every capturing actor also reports once per capture period.

Zone temperatures, setpoints and tank depths read through
`channel_temperature` keep their last value whatever its age; a
freshness rule there is its own change.

**The defrost question falls back to the last real reading.**
`hp_in_defrost` (`actors/hydronic/house0.py:537`) returning `False` for
unknown power would, about 10 s into a meter loss, release the hold on
the buffer and valve a defrosting heat pump onto the store. So for this
one question `ScadaData.last_real_value` (`scada_data.py:200`) answers
when the accessor gives `None`: the value a flush copied aside, or the
aged value still in place. With neither, `False`, as at a house with no
defrost signature. The fallback lives in `ScadaData` because local
control and the leaf ally share it. The callers' 20-minute defrost
timeout bounds a `True` that rests on it. Nothing else reads
`last_real_value`.

## Implausible readings

Both pico actors drop a temperature outside the plausible range, which is
what a thermistor at a pico rail posts. The BTU meter raises an
`open-thermistor` Warning glitch on the first such reading, once a day
per channel, and feeds `heard` before it filters, so a rail-stuck channel
is never flatlined; the tank module filters before `heard`, so a dropped
reading already counts against the channel.

## The field log

`SCADA_UNKNOWN_CHANNEL_LOGGING=true` has the scada log every 15 s the
channels with no value and the channels past the bound
(`ScadaData.unknown_channels`, `scada_data.py:293`).
Set it in the box's `.env` for a field log.

## Known gaps

A derived channel's period is its emit period, or for one that emits
on a trigger the longest period among its inputs
(`ScadaData.capture_seconds`, `scada_data.py:257`), so the bound reads
it as it does a data channel.

- Contract energy is integrated from the last reported power; aggregate
  `PowerWatts` cannot say unknown; a derived heat call keeps its last
  value, on which `DistPumpMonitor` can set the pump-doctor relays; a
  read that raises restarts the scada. All in
  [OPS-555](https://linear.app/gridworks/issue/OPS-555).
