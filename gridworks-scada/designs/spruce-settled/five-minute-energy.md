# Five-minute energy readings (spoke)

Status: Draft · Pass 0 · Updated 2026-09-27 · Linear: [OPS-532](https://linear.app/gridworks/issue/OPS-532)

> What this is: a spoke of [`primary.md`](primary.md). The machinery for
> the scada to produce energy (Wh) per five-minute interval at the
> transactive boundary, the quantity the market and settlement side
> works in, rather than only power on change. Opened 2026-09-27 to hold
> the item; the work comes after the launch.

## Why

The grid side of the mission settles on intervals, not on instants. The
scada today reports `PowerWatts` upstream on change and, from the launch
line, `transactive-power` at the 300 s boundary of the transactive
inputs' capture period (OPS-392). Neither is an energy figure: a consumer
that wants Wh per interval has to integrate power itself from a
change-driven series, and every consumer that does so does it slightly
differently. The scada owns the meter and its clock, so the scada is the
one place the integral can be taken once, correctly, at the boundary.

## Shape (to be decided)

- The power meter, already reading on its own thread and clock and
  already crossing the 300 s boundary, accumulates watt-seconds between
  boundaries and emits the interval's Wh at each crossing.
- A channel per transactive boundary for interval energy, created by the
  power meter like `transactive-power`, so the creator-at-boot check
  covers it.
- The sema word for the interval reading: whether an existing reading
  word with a period carries it or an interval-energy word is minted.
  Search `sema/definitions/` before deciding.
- What the LTN needs from it, and whether the interval ever needs to be
  other than five minutes (a layout or operational parameter, not a
  constant).

## Do this next

Nothing until the launch. When taken: read the executor's description of
the power meter and the `transactive-power` ownership it states, then
write the interval test first (patched clock, two boundaries, the Wh
between them equals the integral of the readings sent).

## Open

- Interval energy at the transactive boundary only, or per transactive
  input as well.
- How a missed reading inside the interval is treated (last value held,
  or the interval marked incomplete).
