# eGauge read glitches

Status: Draft · Pass 0 · Updated 2026-10-26 · Linear: OPS-629

**EDD: yes** the verification is a fleet journal sweep after the fix
that finds no same-instant multi-channel eGauge spike, and a local test
that feeds the driver an out-of-range and a mirrored read and sees the
power meter publish nothing for that poll. The elm field record below is
the bug report.

> What this is: elm's eGauge produced two single-sample glitches on
> 2026-10-26 that the scada published as readings. The small design that
> makes the power meter own clean readings, with a belt-and-suspenders
> bound on the heat-pump consumer. Code read on `main` at `50da8d28`,
> `gw_spaceheat/drivers/power_meter/egauge_4030__power_meter_driver.py`
> and `gw_spaceheat/actors/power_meter.py`; elm runs `legacy` at
> `9956250a`, which has the same read path.

## The field record (elm, 2026-10-26, ET)

Found by reading elm's `report.event` readings from the journal with
`experiments/spot_check.py` and listing the raw samples per channel. No
problem event or glitch was looked for at the time, and `journalctl -u
gwspaceheat` on the box has no clip or out-of-range line at either
instant. Whether a `meter-read-warning` glitch reached the journal is
unverified.

| time | hp-odu-pwr | hp-idu-pwr | oil-boiler-pwr | pumps | next sample |
|---|---|---|---|---|---|
| 11:44:28 | 32767 | -32768 | 32767 | about ±2550 | normal |
| 12:52:16 | 1820 | -1828 | 1826 | normal | normal |

Every eGauge channel moved in the same poll, and the indoor-unit channel
mirrored the outdoor one negative. The heat pump was off both times (0
to 2 W before and after). The nameplate on elm's `hp-odu` is 6000 W.

## What the code does with such a read

- The driver reads each channel as one f32 at its register address,
  takes `int()`, and if the result is outside int16 clips it to
  [-32768, 32767] and attaches an `EGaugeReadOutOfRange` warning
  (`read_power_w`). So 32767 is the driver's own clip of a float far out
  of range, and the 12:52 values, inside int16, pass with no warning.
- `PowerMeterDriverThread.update_latest_value_dicts` stores the clipped
  value as the channel's latest reading and sends one
  `meter-read-warning` glitch per warning. The reading then goes out on
  the async path (a 300 W capture delta is exceeded) and into the
  journal.
- Downstream, `HpWatch.process_power` moves to HpDetectedOn on any
  single sample above `on_above_w`, and the derived generator's
  strategies read whatever the meter published.

A clipped read is not a reading. The mirrored negative on a second
register says the whole poll was bad.

## Principle

The power meter actor is responsible for publishing only readings it
believes. Consumers (the derived generator, hp-watch, hp-boss) do not
clean data; they trust what the meter publishes. One belt-and-suspenders
check stays on the heat-pump consumer: an `hp-odu-pwr` sample above 1.5
times the about node's `NameplatePowerW` is discounted, because a
compressor cannot draw it.

## Plan

1. **Sweep the journal.** For every eGauge house (beech, oak, fir,
   maple, elm, spruce) over the journal's whole span: samples at ±32767,
   and polls where two or more eGauge channels jump by more than their
   nameplate in the same second. Count per house per day, and look up
   `meter-read-warning` glitches at those instants. Output: a table in
   the experiment folder, and the answer to whether this is one eGauge,
   one firmware, or the fleet.
2. **Reproduce locally.** A driver test (the sim or dummy modbus client)
   that returns an out-of-range f32, a NaN, and a mirrored pair, and a
   power-meter test that asserts no reading is published for that poll
   and one glitch is. Both fail today.
3. **The meter owns the read.** In the driver, an out-of-range or NaN
   f32 is a failed read: value `None` with the warning. The driver stops
   clipping. In the power meter, a poll in which more than one channel
   moves by more than its nameplate is dropped whole with one glitch,
   rate-limited. The channel's last good value stands; the lost-channel
   path handles a meter that stays bad.
4. **Belt and suspenders on hp-watch.** A sample above 1.5 times
   `NameplatePowerW` of the `hp-odu` node is ignored for state, with a
   warning once per spell.
5. **Verify.** Deploy to the houses the sweep names, run the sweep again
   over a week, and expect zero.

## Open

- Root cause in the eGauge or the Modbus client: a misaligned TCP frame
  would explain every register going bad at once, and the mirrored
  negative looks like a register pair read one register off. Compare the
  pymodbus version and the eGauge firmware across the houses the sweep
  names.
- Whether the in-range kind (12:52) is catchable by the meter at all, or
  only by the cross-channel coincidence.
- Whether the `meter-read-warning` glitch is journaled and visible
  anywhere a person looks.
