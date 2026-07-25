# Estimates vs. reality — calibration log

Status: Draft · Pass 0 · Updated 2026-07-19

> What this is: a running record of work estimates and what actually happened,
> to train a genuine 90% confidence interval. Every estimate is an interval
> [low, high] such that we expect the actual to land inside it 9 times out
> of 10. When the log has enough rows, ~90% of Actuals should sit inside
> their interval — more misses means overconfident (widen), many fewer means
> sandbagging (tighten). Units are working hours. The full scope behind each
> estimate lives in a comment on the Linear issue, posted at estimate time;
> this table is only the scoreboard.

| Est. date | Work | Point (h) | 90% low (h) | 90% high (h) | Actual (h) | In interval? |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-07-19 | OPS-419 step 7 — populate + deploy registry | 13 | 8 | 24 | 7.5 | no (under) |
| 2026-07-22 | OPS-392 — dev-spruce layout readiness | 10 | 6 | 18 | | |
| 2026-07-22 | OPS-458 — ear poetry to uv | 2 | 0.5 | 3 | 0.5 | yes (at bound) |

## Active hours — scratch

Running per-day hours for work that is active (not yet wrapped). Times in ET.
At wrap: sum into the Actual column above, log on the Linear issue, delete
the rows here.

| Work | Day | Started | Stopped | Hours |
| --- | --- | --- | --- | --- |
| OPS-392 dev-spruce readiness | 2026-07-22 |  | | |
| OPS-392 dev-spruce readiness | 2026-07-23 | 9:40 | | |


## How to use

- Add a row **when the estimate is made**, before starting the work; post the
  full scope as a comment on the Linear issue.
- Fill Actual from the issue's logged hours at wrap; mark In interval? yes/no.
- Never revise low/high after work starts — a busted bound is the data.
- Periodically (every ~10 rows): count the hit rate, note the bias, adjust the
  next intervals accordingly.
