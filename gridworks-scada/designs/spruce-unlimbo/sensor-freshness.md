# sensor-freshness

Status: Accepted · Pass 1 · Updated 2026-09-24 · Linear: OPS-392

> What this is: a spoke of [`primary.md`](primary.md). Three chips that
> make "the heat pump's power or water temperature is unknown", and "this
> pico channel has stopped", visible to control code within seconds to
> minutes instead of never. It comes before
> [`basic-sieg.md`](basic-sieg.md), whose fail-open layer 2 ("an input
> missing") rests on it. A launch item.

## The problem

Control code asks `total_hp_pwr_w()`, `lwt()`, `ewt()` and `lift_f()` and
treats `None` as "unknown". Today none of them becomes `None` when the
sensor behind it stops.

1. **The power meter re-sends its last good value as a fresh reading.** An
   eGauge read that cannot connect returns `Ok` with value `None`
   (`drivers/power_meter/egauge_4030__power_meter_driver.py:258`, `:288`),
   with warnings on a connect attempt and none on a poll skipped for
   reconnect backoff.
   `update_latest_value_dicts` overwrites a channel only when a value came
   back (`actors/power_meter.py:285`), so `latest_telemetry_value` keeps
   the old watts, and the periodic report sends it with a new
   `ScadaReadTimeUnixMs` every `CapturePeriodS` (`:313`, `:371`). A meter
   lost mid-run reads as steady power for ever. A read that raises is a
   different case: the driver thread stops, the scada exits and the
   service restarts with no latest values, so nothing stale survives it.
2. **The accessors return the last value whatever its age.**
   `channel_temperature` (`actors/sh_node_actor.py:327`) and
   `hp_odu_pwr_w` / `hp_idu_pwr_w` (`actors/hydronic/house0.py:828-842`)
   read `data.latest_channel_values` and never look at
   `data.latest_channel_unix_ms`. `ScadaData.flatlined`
   (`actors/scada_data.py:197`: no reading inside 2.1 × the channel's
   `CapturePeriodS`) is consulted only when building a snapshot.
3. **Only the pico actors say when a channel is lost, and only when the
   whole pico goes quiet.** `ApiBtuMeter` and `ApiTankModule` send
   `ChannelFlatlined` to the scada, which sets the channel's latest value
   and time to `None` (`scada.py:328`, `scada_data.py:130`). They send it
   from `report_missing`, driven by one `PicoLiveness` per pico that is
   fed by every post (`api_btu_meter.py:306`, `api_tank_module.py:284`),
   so a pico that keeps posting one channel and drops another is never
   noticed. The BTU firmware does exactly that: a thermistor at either
   ADC rail reads `None` and `report()` omits the channel from the post
   while flow keeps arriving (spruce store pipes, 2026-09-21; the
   firmware side is OPS-556). `PowerMeter` and `MultipurposeSensor`
   (maple's `hp-lwt` and `hp-ewt`) never send it at all.

## The changes

Each gets its tests first ("Tests" says which fail before the change and
which are guards, and on which sim).

### 1. The power meter stops reporting what it did not read

- The driver thread keeps, per channel, the `time.monotonic()` of the last
  read that returned a value, set in `_preiterate` before `driver.start()`
  for the time before the first. Monotonic, because a clock stepped back by
  NTP would hold a wall-clock deadline open; wall time stays for reading
  stamps only. Counting reads
  does not work: a connect attempt can block 3 s, and polls skipped for
  reconnect backoff return at once.
- When that time is more than `POWER_METER_LOST_AFTER_S` = 10 s old the
  channel is lost: its `latest_telemetry_value` and
  `last_reported_telemetry_value` go to `None`,
  `last_reported_agg_power_w` goes to `None` if the channel is
  transactive, and the thread sends the scada one `ChannelFlatlined` for
  it, as `ApiBtuMeter.report_missing` does. One message per loss, not one
  per poll. The check runs once per iteration, and an iteration against a
  dropped link takes about 4 s, so a loss is declared 10 to 15 s after the
  last good read.
- `should_report_telemetry_reading` already declines a `None` value, so
  the periodic re-send stops.
- Recovery: the first good read finds `last_reported_telemetry_value`
  `None` and reports at once (`:368`), to the scada and, for a derived
  input, to the derived generator; with `last_reported_agg_power_w`
  cleared, aggregate power is reported on that poll too, whatever its
  value.
- Every channel on the meter is treated alike, the whitewire heat-call
  inputs included.
- The driver's read, start and hardware-ID warnings go to the scada as
  Warning glitches, at most one a day for each kind and channel.

### 2. The heat pump accessors return `None` for a flatlined channel

`lwt()`, `ewt()`, `hp_odu_pwr_w()` and `hp_idu_pwr_w()` return `None` when
`self.data.flatlined(channel)` is true, and so `lift_f()` and
`total_hp_pwr_w()` do. A channel the layout does not have returns `None`
as it does now, before `flatlined` is asked (it takes a channel object).
This is the backstop for every capturing actor that
sends no `ChannelFlatlined`, and for change 1 failing to fire (the driver
thread itself hung). Detection here is 2.1 capture periods: 630 s for a
300 s channel.

**The defrost question falls back to the last real reading.**
`hp_in_defrost()` (`hydronic/house0.py:568`) returns `False` for `None`
power, and local control and the leaf ally take `False` as leave to move
from the buffer to charging the store. Today a meter lost during a defrost
leaves the stale low watts in place, so the hold on the buffer stands,
bounded by the callers' `DEFROST_TIMEOUT_MINUTES` = 20
(`local_control/house0/all_tanks_tou.py:223-231`,
`leaf_ally/house0/all_tanks.py:340-348`). Returning `False` the moment
power goes unknown would release that hold about 10 s into the loss and
valve a defrosting heat pump onto the store, which is worse than today.

So for this one question the last real reading still answers.
`ScadaData` keeps `last_real_channel_values`: `flush_channel_from_latest`
copies a channel's value there before clearing it, and a channel that is
flatlined without having been flushed still has its value in
`latest_channel_values`. `hp_in_defrost()` takes each draw it watches
(`hp-idu-pwr`, or both for a total signature) live when the accessor gives
a value and from the last real reading when it gives `None`; with neither,
`False`, as at a house with no defrost signature. The fallback is the
plant's and not an actor's, since `ScadaData` is shared by local control
and the leaf ally, and it does not depend on anyone having asked the
question while the reading was live. The callers' 20-minute timeout bounds
a `True` that rests on it. Nothing else reads `last_real_channel_values`.

`flatlined` is safe for report-on-change channels because every capturing
actor also reports once per `CapturePeriodS`; a steady value still arrives
on that beat. It compares wall-clock times, as the snapshot's use of it
does; a clock step can delay or hasten this backstop, and that is accepted
for a 630 s bound.

### 3. The pico actors notice one channel going quiet

`ApiBtuMeter` and `ApiTankModule` keep one `PicoLiveness` per channel they
capture, beside the per-pico one, each with `expected_post_s` = that
channel's `CapturePeriodS`. A post feeds `heard` to the channels it
carries, and only those. The pico's sync post carries every channel that
has a value once per period, and its async posts carry only channels
that moved, so a live channel is heard at least once per period and a
channel absent from 2.5 periods of posts (750 s at 300 s) is gone.
`main` asks each channel's `report_due` on its 10 s tick: due means one
`ChannelFlatlined` for that channel, repeated once a minute while the
silence lasts as the per-pico report is; the next post that carries the
channel resets it. The per-pico report stays as it is, and a pico that is
missing altogether is not reported channel by channel as well: while
`missing()` is true the per-channel check is skipped. A `PicoMissing`
goes only for the whole pico; a single quiet channel does not cycle the
rail.

2.5 periods and not tighter: a channel that returns from a fault to
within the async delta of its last sent value is not posted async, so it
is heard again only at the next sync. A tighter bound would declare a
flickering sensor lost and found on each flicker.

`PicoLiveness` already takes the current time on every call and has its
tests (`tests/actors/test_pico_liveness.py`); this change adds instances,
not bookkeeping.

The BTU meter also raises a `quiet-channel` Warning glitch when a channel's
`ChannelFlatlined` goes out, at most once a day per channel.

**A channel that keeps reading implausibly is gone.** Both pico actors
drop a temperature outside the plausible range, which is what a thermistor
at a pico rail posts. One such reading is noise: it is dropped and the
channel still counts as heard. Five in a row mean the sensor is not giving
information and probably needs retiring. From the fifth, the channel stops
being heard, so its liveness flatlines it 2.5 periods after the last post
that counted and the rest of the system treats it as gone. The actor
raises one `open-thermistor` Warning glitch at the fifth, at most once a
day per channel, so a single spike raises nothing. The first plausible
reading resets the count and is heard as usual. Today the BTU meter feeds
`heard` before it filters, so a rail-stuck channel is never flatlined,
and the tank module filters before `heard`, so one implausible reading
already counts against the channel. This rule makes the two actors
alike.

## Not in this spoke

- `channel_temperature` itself, and so zone setpoints, zone temperatures
  and tank depths: they feed zone control and `fill_missing_store_temps`,
  and a freshness rule there is its own change with its own tests.
- `MultipurposeSensor` sending `ChannelFlatlined`. Change 2 covers a dead
  ADS at 2.1 capture periods.
- The pico saying so itself: a fault marker in the BTU post and a
  plausibility gate on the read are firmware, OPS-556. Change 3 stays
  necessary after it, for picos on older firmware and for a channel lost
  from a post for any other reason.
- A rail-voltage gate in the tank module's microvolt conversion (spruce's
  `fancoil-depth3` posts 3,299,997 µV and the scada converts it to
  -123 C). A scada change, its own item.
- Capture tuning: `AsyncCaptureDelta`, a finer delta under 1 kW, shorter
  capture periods. A dead meter produces no deltas, so none of these
  detects one.
- What the sieg loop does with `None`: `basic-sieg.md` change 6, layer 2.
  The loop's present `is_blind` and `hp_loop_is_getting_hot` already treat
  `None` as blind, which is full send.
- Four things a lost or misbehaving meter still does after this spoke,
  all today's behaviour, held in
  [OPS-555](https://linear.app/gridworks/issue/OPS-555): contract energy
  integrated from the last reported power (it should come from the meter's
  own energy register); aggregate `PowerWatts` that cannot say "unknown";
  a derived heat call left at its last value, on which `DistPumpMonitor`
  can set the pump doctor working relays; and a read that raises, which
  restarts the scada.

## Tests

`tests/actors/test_power_meter.py`, House0 sim; tests 1, 3 and 4 fail
before the change, 2 is a guard:

1. The sim driver returns no value for `hp-odu-pwr` for longer than
   `POWER_METER_LOST_AFTER_S` (shortened through settings): the scada's
   `latest_channel_values["hp-odu-pwr"]` is `None`, exactly one
   `ChannelFlatlined` arrived, and no `SyncedReadings` for the channel
   follows across a capture period. Reverted, the test sees the stale
   value re-sent.
2. No value for less than the deadline, then a good read: no
   `ChannelFlatlined`, value intact.
3. Lost, then a good read: the value is reported on that poll, to the
   scada and to the derived generator for a whitewire channel.
4. Lost, then a good read at the same watts as before the loss: a
   `PowerWatts` is sent on that poll.

`tests/actors/test_sensor_freshness.py`; tests 5 and 7 fail before the change,
6 and 8 are guards:

5. On the House0 sim: `hp-odu-pwr` last read more than 2.1 capture periods
   ago with its value still in `latest_channel_values`:
   `total_hp_pwr_w()` is `None`; the same for `hp-idu-pwr`. On the Nolan
   sim, which carries `hp-lwt` and `hp-ewt`: `lwt()`, `ewt()` and
   `lift_f()` the same way. A reading inside the window: the value.
6. On the House0 sim, `hp-lwt` never read: `lwt()` and `lift_f()` return
   `None` and do not raise. Every sim now carries `hp-lwt`, so a layout
   without the channel has no test.
7. The sims carry no defrost signature, so this one patches
   `DEFROST_SIGNATURES` for the sim heat pump. Power under the signature's
   `max_w` arrives at the scada and no actor calls `hp_in_defrost()`; the
   channel is then flushed by a `ChannelFlatlined`; the leaf ally's and
   local control's `hp_in_defrost()` are both `True`. The same with the
   channel flatlined by age and not flushed. Power over `max_w`, then
   lost: `False`. Never read: `False`. Power returns high after a loss:
   `False` on the next call. Fails before the change.
8. A zone temperature of the same age still comes back through
   `channel_temperature`: the change did not widen.

The existing accessor and defrost tests in
`tests/actors/test_hydronic_house0.py` set `latest_channel_values` alone;
they gain matching fresh read times.

`tests/actors/test_pico_channel_liveness.py`, on the Nolan sim's
`store-btu` (the House0 sims carry no sim BTU meter) and the House0 sim's
`tank1`. The test drives each actor's clock, ticks its sim source once a
second and checks liveness every ten, so no capture period is shortened.
Test 9 fails before the change; 10 and 11 are guards:

9. The sim pico's post drops one channel (the cold pipe; a tank depth)
   and keeps the others, for longer than 2.5 of that channel's capture
   periods: exactly one
   `ChannelFlatlined` for that channel, none for the others, no
   `PicoMissing`, and the scada's `latest_channel_values` for it is
   `None`. Reverted, the stale value stands.
10. The channel misses one post, then returns: no `ChannelFlatlined`;
    the returned value is in `latest_channel_values`. A channel dropped
    for nearly 2.5 periods is heard again only at the next sync post, up
    to a period later, and is rightly flatlined; one missed post is the
    case that must stay quiet.
11. The whole sim pico dies (its existing `SimLifeS` path): one
    `PicoMissing` and the per-pico `ChannelFlatlined` set as today, and
    no second `ChannelFlatlined` per channel from the new check.

Tests 12 and 13, on `store-btu` and `tank1` in the same file; 12 fails
before the change, 13 is a guard:

12. The sim pico posts a rail value for one channel on five posts running:
    one `open-thermistor` glitch, at the fifth and not before; one
    `ChannelFlatlined` for the channel within 2.5 periods of the last post
    that counted; the scada's `latest_channel_values` for it is `None`.
    Reverted, the BTU channel is never flatlined.
13. Four rail values, then a plausible one: no glitch, no
    `ChannelFlatlined`, and the plausible value is in
    `latest_channel_values`.

The sim power meter driver gains a settable "no value" mode for test 1,
and `SimPicoSource` gains a settable set of channels to omit from its
reading for tests 9 and 10, and a settable per-channel rail value for
tests 12 and 13; those are the missing simulations, and each goes in
before its tests.

## Build status

- ✅ Change 1, the power meter: `6e0efaac`. The sim meter's
  `no_value_channel_names`, tests 1–4 on the willow sim, the
  `power_meter_lost_after_s` setting (10 s).
- ✅ Changes 2 and 3 as first specified: `b86da812`. `ShNodeActor.channel_is_live`, the four
  accessors, `ScadaData.last_real_value` behind `hp_in_defrost()`; a
  `PicoLiveness` per captured channel in `ApiBtuMeter` and `ApiTankModule`,
  `check_liveness` as `main`'s check made callable, and `SimPicoSource`'s
  `omitted_names` with a `without` function per reading type.
- ✅ The field log: `SCADA_UNKNOWN_CHANNEL_LOGGING=true` has the scada log
  every 15 s the channels with no value and the channels past the flatline
  bound (`ScadaData.unknown_channels`, in `6e0efaac`).
  `experiments/house_window.sh` sets it for beech and spruce windows.
- ✅ Read warnings, `open-thermistor` and `quiet-channel` as Warning
  glitches with a once-a-day limit: `208b2769`.
- Not built: the five-in-a-row rule for implausible readings, and tests
  12 and 13. Today the BTU meter raises `open-thermistor` on the first
  implausible reading and never flatlines a rail-stuck channel.
- Suite at `b86da812`: 1053 passed, 1 skipped. The five spoke test files
  at `45a902c6`: 179 passed.
- ◐ Verification: the baseline window has run; no loss has been staged.

## Verification (EDD)

**Baseline, beech, 2026-09-21** (an earlier round of
`experiments/beta-field-windows/`): five minutes on `b86da812`
in Standby, clean, services restored. The meter's channels had values by
the second log line and kept them. Nothing was unplugged, so the claims
below are still open.

**Beech cannot carry the pico or water-temperature claims.** Its nine
picos have sent the journal nothing since 2026-09-11 about 10:40 ET
(`dist-flow2` a handful of readings since), and its `hp-lwt` and `hp-ewt`
come from the `primary-btu` pico, so they are dark too. The scada there
sends an hourly `pico-zombies` glitch naming all nine. While a whole pico
is missing the per-channel check is skipped by design, so change 3 shows
nothing at beech until its picos are back. Beech still serves the meter
claim. The cause at beech is not known; it is its own field item and not
this spoke's.

With nobody at the meter, the link can be broken from the box: one
`iptables` DROP rule for the eGauge's address for a minute inside a
window, then removed, and recorded in the box README as non-repo state.
Not yet done.

In a bounded beech window: unplug the eGauge's network for a minute with
the heat pump idle. `hp-odu-pwr` leaves the snapshot within twenty seconds,
returns on the first read after the cable goes back, and the journal shows
no `hp-odu-pwr` reading stamped inside the gap.

Round four (2026-09-23) ran five-minute windows at both houses, shorter
than the 750 s bound, so it could not show change 3. A channel's liveness
starts with the scada, so a channel never heard is flatlined 750 s in;
the change 3 window needs at least 15 minutes. Whether the spruce store
pipes are left out of the post or posted at the rail decides which path
the window shows: left out, change 3 as built; at the rail, only the
five-in-a-row rule.

For change 3, the spruce store pipes as they stand: both thermistors
disconnected, the BTU pico posting flow alone. Within 750 s of the window
scada starting, one `ChannelFlatlined` each for `store-hot-pipe` and
`store-cold-pipe` in the proactor log, no `PicoMissing` for `store-btu`,
and neither channel in the snapshot; reconnect one lead and its channel
is back in the snapshot on the next post.

## Found along the way

- **Derived channels age out of the snapshot after 126 s.**
  `ScadaData.capture_seconds` gives every derived channel 60 s (`TODO:
  fix` in the code), so `flatlined` calls a derived value stale 126 s
  after it was written unless it is re-emitted. In the baseline window
  `usable-energy` and beech's two derived heat calls read stale from
  14:22:07. The snapshot has used this rule all along; the new log made it
  visible. Not this spoke's change; it wants a home in `odds-and-ends.md`
  or its own item.
- **Ten days of dark picos at beech raised one Info glitch an hour.** The
  alerting side of that belongs to OPS-545 and OPS-317.

## Do this next

Build the five-in-a-row rule: the sim rail value, tests 12 and 13
failing, then the change in both pico actors.

Stage a meter loss in a bounded beech window: `./beech_window.sh on 10`,
break the eGauge link for a minute (someone at the meter, or the
`iptables` rule above), and read the `[UnknownChannels]` lines and the
journal against the beech claim in "Verification (EDD)". Then the spruce
store pipes for change 3, in a spruce window of at least
15 minutes with the same log. When both
hold, distill into `executor/` and mark the hub line done.
