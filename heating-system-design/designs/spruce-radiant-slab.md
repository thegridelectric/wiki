# spruce-radiant-slab

Status: Draft · Pass 0 · Updated 2026-10-15 · Linear: OPS-601

**EDD: yes** the fit itself is the verification: the model's coefficients
stand only when a re-runnable pull and fit under
`experiments/spruce-radiant-slab/` reproduces them from journal data.

> What this is: a simple model of spruce's radiant floor, fitted to the
> data spruce has already reported. The experiment folder holds the
> model, the pulls, the workbook and the findings; this file names the
> aim and what to do next.

## Aim

Two numbers per slab zone, measured rather than assumed: how fast heat
moves from the slab into the room per degree of floor-minus-air, and how
much heat the slab stores per degree of floor sensor. Each with a
confidence interval and the window it came from. The Knife's Edge homes
put the thermal store in concrete under a radiant floor, so their sizing
and control start from these numbers.

## Do this next

Widen the data the fit uses, in two steps. First add a model of the
home's heat use against outside temperature, so hours with a room
losing heat to the weather can enter the fit; actual outdoor
temperature exists only from 2026-08-13 (hourly `gw.weather.observation`
from `hw1.isone.weather`), spring has only the scada's `forecast-oat`.
Second, fit over every span the journal offers, not just Oct 7. The
living-room two-stage fit (G over C from the free float, C from the
charge) is in `experiments/spruce-radiant-slab/`, "Found".

Also wanted: a workbook per window of the buffer tank heating up on
its elements alone, spring 2026, from the journal (channels
`elt-buffer-top-pwr`, `elt-buffer-bottom-pwr`, `buffer-depth1/2/3` in
FahrenheitX100, `dist-flow`). The elements run in fixed blocks, 12:00
to 16:00 and 20:00 to 07:00 ET, both near 4.1 kW, the top dropping out
near 155 °F. Found 2026-10-15, all three depths reporting and no
distribution flow; cleanest first, temperatures depth1/2/3 °F:

| window (ET) | rise |
|---|---|
| 2026-04-08 20:01 to 23:47 | 91/86/85 to 162/162/160 |
| 2026-03-06 12:01 to 15:37 | 98/92/90 to 162/162/158 |
| 2026-02-27 12:01 to 16:00 | 89/88/86 to 158/157/154 |
| 2026-01-28 12:01 to 15:46 | 105/103/98 to 162/162/159 |

Spruce has no heat pump data before June, so a heat pump contribution
cannot be excluded by data.

## Scope

- In: the two-lump floor-and-room model per slab zone, the pull from the
  journal DB, the fit, and its residual check against the charging hours.
- Out: the garage zone (until its columns are in the workbook), a layout
  or sema word for the fitted coefficients, and any change to the scada.
