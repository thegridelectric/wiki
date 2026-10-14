# sensor-freshness

Status: Accepted · Pass 1 · Updated 2026-10-14 · Linear: OPS-392

> What this is: a spoke of [`primary.md`](primary.md). A channel becomes
> unknown to control code, and a pico dead, under one bound; a pico
> channel that goes quiet, or keeps reading a rail, is noticed on its
> own. It comes before [`basic-sieg.md`](basic-sieg.md), whose fail-open
> layer 2 ("an input missing") rests on it. A launch item. The built
> behaviour is spec in `executor/sensor-freshness.md`.

## The changes

Each gets its tests first.

### 1. One bound, one definition

Freshness and liveness share the nyquist multiple 2.1 and one definition
of it: written once in a module both import, from which
`PicoLiveness.flatline_seconds` and `ScadaData.flatlined` compute their
bound and keep no number of their own. A channel is fresh inside 2.1
capture periods; a pico is alive inside 2.1 post periods; the same fact,
no signal inside the nyquist window.

2.1 and not 2 or less: a sensor that returns from a fault to within its
async delta is not posted async, so it is heard again only at the next
sync post. A bound at or below two periods flatlines a channel that
missed one sync; the tenth above covers the jitter in that next post
(0.8 s measured on Wiznet tank picos at 60 s). Not looser: nothing in
the data asks for it, and the old liveness 2.5 was history, not a
derivation. Part of OPS-592, which puts the same multiple on `main` and
`actual-spruce`.

### 2. A channel that keeps reading implausibly is gone

Both pico actors drop a temperature outside the plausible range, which is
what a thermistor at a pico rail posts. One such reading is noise: it is
dropped and the channel still counts as heard. Five in a row mean the
sensor is giving no information: from the fifth the channel stops being
heard, so its liveness flatlines it 2.1 periods after the last post that
counted and the rest of the system treats it as gone. The actor raises
one `open-thermistor` Warning glitch at the fifth, once a day per
channel, so a single spike raises nothing. The first plausible reading
resets the count and is heard as usual. The BTU meter raises on the first
reading and never flatlines a rail-stuck channel, and the tank module
counts one reading against the channel; the rule makes the two actors
alike.

## Tests

`tests/actors/test_pico_liveness.py`:

- **one-bound-shared**: for the same capture period,
  `PicoLiveness.flatline_seconds` equals the seconds `ScadaData.flatlined`
  allows, and both are 2.1 periods; a reading or post at 2.0 periods is
  fresh and alive, one at 2.2 is stale and missing. Fails before change
  1 on the equality clause. The per-channel liveness tests that wait past
  2.5 periods pass unchanged; the one that misses a single post and
  returns stays quiet, which is the clause the bound exists for.

`tests/actors/test_pico_channel_liveness.py`, on the Nolan sim's
`store-btu` and the House0 sim's `tank1`; `SimPicoSource` gains a
settable per-channel rail value first:

- **rail-five-in-a-row**: the sim pico posts a rail value for one channel
  on five posts running: one `open-thermistor` glitch, at the fifth and
  not before; one `ChannelFlatlined` for the channel within 2.1 periods of
  the last post that counted; the scada's `latest_channel_values` for it
  is `None`. Fails before change 2; reverted, the BTU channel is never
  flatlined.
- **rail-four-then-plausible**: four rail values, then a plausible one:
  no glitch, no `ChannelFlatlined`, and the plausible value is in
  `latest_channel_values`. A guard.

## Build status

- ✅ The power meter declares a lost channel at 10 s (`6e0efaac`); the
  heat-pump accessors return `None` for a stale channel and the pico
  actors keep a liveness per channel (`b86da812`); the unknown-channel
  field log (`6e0efaac`); read warnings and the `quiet-channel` glitch
  (`208b2769`).
- ◐ Change 1, change 2, and their tests.
- ◐ Verification: the baseline window has run; no loss has been staged.

## Verification (EDD)

Two claims, each in a bounded field window
(`experiments/beta-field-windows/`). The baseline window (beech,
2026-09-21, `b86da812`) only showed the meter's channels staying live.

- **A lost meter channel is unknown within seconds, beech.** Break the
  eGauge link for a minute with the heat pump idle: someone at the meter,
  or one `iptables` DROP rule for the eGauge's address, removed after and
  recorded in the box README as non-repo state. `hp-odu-pwr` leaves the
  snapshot within twenty seconds, returns on the first read after the
  link is back, and the journal shows no `hp-odu-pwr` reading stamped
  inside the gap.
- **A quiet channel on a live pico is flatlined and the pico is not
  cycled, spruce.** The store pipes as they stand: both thermistors
  disconnected, the BTU pico posting flow alone. In a window of at least
  15 minutes with `SCADA_UNKNOWN_CHANNEL_LOGGING` on: one
  `ChannelFlatlined` each for `store-hot-pipe` and `store-cold-pipe`
  within the bound of the window scada starting, no `PicoMissing` for
  `store-btu`, neither channel in the snapshot; reconnect one lead and
  its channel is back on the next post. Whether the pipes are left out of
  the post or posted at the rail decides which path shows: left out, the
  per-channel liveness; at the rail, only change 2.
- Beech cannot show the pico claim: its nine picos have been dark since
  2026-09-11 (an hourly `pico-zombies` glitch), its own field item.

## Do this next

Change 1: `one-bound-shared` failing, the one definition, `PicoLiveness`
and `flatlined` on it. Then change 2: the sim rail value,
`rail-five-in-a-row` and `rail-four-then-plausible` failing, the change
in both pico actors. Then the two windows; when both hold, mark the hub
line done and delete this spoke.
