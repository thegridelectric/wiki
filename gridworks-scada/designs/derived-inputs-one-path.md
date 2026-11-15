# Derived inputs on one path

Status: Draft · Pass 0 · Updated 2026-11-14 · Linear: OPS-682
**EDD: no** — a refactor of in-process routing, verified by the suite and
the key test: the rolling distribution energy on the orange pair with the
dist temperatures read on scada2 (`tests/actors/test_dist_energy_from_scada2.py`),
which must pass unchanged with the direct posts gone.

> What this is: the derived generator gets every reading that feeds one of
> its channels by one route, a channel subscription at the primary scada,
> whatever device captured the reading and whichever scada runs that
> device. The device actors stop posting to the generator directly and
> `feeds_derived` retires.

## Today: two paths and a guess

A device actor the primary scada runs posts each reading twice when the
reading feeds a derived channel: once to the scada, once to the derived
generator (`HydronicLayout.feeds_derived`, used by `power_meter.py`,
`sim_sensor.py`, `gpio_sensor.py`, `i2c_thermistor_reader.py`,
`api_flow_module.py`, `api_btu_meter.py`). A device actor scada2 runs
cannot reach the generator: scada2 re-sends every `SyncedReadings` to the
primary with the destination rewritten, so a second post to the generator
arrives at the primary as a duplicate reading. The primary therefore posts
a scada2 reading on to the generator itself (`actors/scada.py`
`process_synced_readings`, since PR #609) and decides which readings are
scada2's by walking the capturer's node hierarchy to its parent scada.

Two routes for one fact, kept from overlapping by inference from layout
naming. A capturer with no hierarchy parent reads as remote. The scada
knows what the device actors do with their readings, and the device
actors know a derived generator exists. The installed houses read
`dist-swt` and `dist-rwt` on scada2, so the gap stayed hidden until the
rolling distribution energy came out at zero all day on oak.

## The design

One route. The primary scada already forwards readings of a channel to
whoever subscribed to it (`ChannelSubscribe`, `channel_subscribers`,
`forward_to_channel_subscribers`; `hp_watch` subscribes to the heat
pump's power this way).

- At start, the derived generator sends the primary one `ChannelSubscribe`
  per input channel of every enabled derived channel it creates. Its
  inputs that are themselves derived channels need no subscription: the
  generator emits those and dispatches them to its own handlers already
  (`emit_derived`).
- The primary forwards each reading of a subscribed channel as a
  `SingleReading`, whatever its capturer. It stops inferring the
  capturer's scada; the block added in PR #609 goes.
- The device actors stop posting to the generator. `derived_input_channels`
  leaves the six actors and `feeds_derived` leaves the layout, with
  `tests/test_misc/test_feeds_derived.py`.
- Readings keep their source: `forward_to_channel_subscribers` passes the
  capturing node as `from_node`, as today, so the generator's
  `process_message` resolves the same node it does now.

What does not change: the generator's handlers, the rolling-energy
integration, the emission of derived readings to the scada, scada2's
forwarding.

## Behaviour differences to list and pin

Under the scada protocol a change that reshapes a path lists every
behaviour difference and pins each with a test. Known so far:

1. A reading captured by a primary-run device reaches the generator after
   the scada has processed the `SyncedReadings`, not alongside it. Same
   values, same read time; the order within the primary's queue changes.
   Test: the flow-math and sieg flow tests keep passing; a test asserts
   the generator sees a reading exactly once.
2. A reading of an input channel the generator has not subscribed to
   (a disabled derived channel's input) no longer reaches it at all,
   where today `feeds_derived` already excludes disabled channels. Test:
   `test_pico_disabled.py` keeps passing.
3. A subscription is sent at `start`, so a reading that arrives before
   the generator starts is not forwarded. Today a device actor can post
   before the generator starts and the message waits in the queue. Test:
   boot order on the orange pair; if the generator starts after a device
   actor, the subscription is sent in `__init__` instead, or the primary
   replays the latest held value on subscribe (it holds
   `latest_channel_values`).
4. A `SingleReading` replaces a batched `SyncedReadings` on the direct
   path; the generator already unpacks both.

A reader who did not write the change checks this list against the diff
before merge.

## Sequencing

After scada PR #609 and Olly's PR #618 merge. #618 rewrites the device
actors' driver construction (`power_meter.py` among them) and this change
touches their reporting, so it waits for a clean base. The test from
PR #609 is the acceptance test here and needs no change.

## Do this next

Wait for #609 and #618 to merge. First build
step: the generator subscribes in `start`, the primary's forwarding
condition drops to "subscribed", the six direct posts stay for one commit
so a test can assert exactly one delivery per reading, then they go.

## Open

- Whether the primary replays the held latest value on subscribe (item 3).
  `hp_watch` does not need it; the generator's rolling energy needs a
  minute of history anyway, so probably not.
