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
| 2026-07-22 | OPS-392 — dev-spruce layout readiness | 10 | 6 | 18 | 8.5 | yes |
| 2026-07-22 | OPS-458 — ear poetry to uv | 2 | 0.5 | 3 | 0.5 | yes (at bound) |
| 2026-08-06 | OPS-490 — ads-noise semafy pilot | 4 | 2 | 9 | 9.5 | no (over) |
| 2026-08-10 | OPS-392 — summer hack through scada | 24 | 14 | 42 | | |
| 2026-08-10 | OPS-436 — gwwf stand-up | 25 | 16 | 40 | | |

## Active hours — scratch

Running per-day hours for work that is active (not yet wrapped). Times in ET.
At wrap: sum into the Actual column above, log on the Linear issue, delete
the rows here.

| Work | Day | Started |
| --- | --- | --- |
| OPS-392 hack through scada | 2026-08-10 | 16:30–18:20 (1.8h) |
| OPS-392 hack through scada | 2026-08-10 | 21:30–23:30 (2h) |
| OPS-392 spruce window | 2026-08-11 | 09:30–11:25 (2h) |
| OPS-436 gwwf design | 2026-08-10 | 15:00–18:15 (3.25h) |
| OPS-436 gwwf design | 2026-08-10 | 23:00–00:15 (1.25h) |
| OPS-436 gwwf stand-up | 2026-08-11 | 09:15–10:00 (0.75h) |
| OPS-436 gwwf sema authoring | 2026-08-11 | 10:00–10:40 (0.7h) |
| OPS-436 delivery grill | 2026-08-11 | 10:40–11:10 (0.5h) |
| OPS-436 build step 0: snapshot + gwbase + logging | 2026-08-11 | 11:15–11:35 (0.3h) |




## How to use

- Add a row **when the estimate is made**, before starting the work; post the
  full scope as a comment on the Linear issue.
- Fill Actual from the issue's logged hours at wrap; mark In interval? yes/no.
- Never revise low/high after work starts — a busted bound is the data.
- Periodically (every ~10 rows): count the hit rate, note the bias, adjust the
  next intervals accordingly.
