# Estimates vs. reality — calibration log

Status: Draft · Pass 0 · Updated 2026-07-19

> Lessons drawn from these rows: [`estimating.md`](estimating.md).
>
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
| 2026-08-10 | OPS-436 — gwwf stand-up | 25 | 16 | 40 | 20.6 | yes |
| 2026-08-14 | OPS-420 mtls-fis-auth — design phase only | 6 | 4 | 9 | 4.1 | yes |
| 2026-08-14 | OPS-420 mtls-fis-auth — implementation/rollout | 16 | 9 | 30 | | |
| 2026-08-14 | OPS-422 stand-up-fis — v1 through staging battery | 18 | 10 | 28 | | |
| 2026-08-14 | OPS-496 sasl-mechanism-plugin | 6 | 3 | 12 | 1.25 | no (under) |
| 2026-08-14 | OPS-496 — claims connect wiring | 2.5 | 1 | 5 | 0.2 | no (under) |

## Active hours — scratch

Running per-day hours for work that is active (not yet wrapped). Times in ET.
At wrap: sum into the Actual column above, log on the Linear issue, delete
the rows here.

| Work | Day | Started |
| --- | --- | --- |
| OPS-392 relay path + witness windows (compacted) | 2026-08-10–12 | 12.25h |
| OPS-392 step 7 local control | 2026-08-12 | 12:03–14:15 (2.2h) |
| OPS-392 coherence review + ops-params spoke | 2026-08-12 | 16:20–17:30 |
| OPS-392 plant axiom + fixture round | 2026-08-12 | 14:15–16:20 (2.1h) |
| OPS-392 system-mode review | 2026-08-13 | 7:45–9:30 (1.75h) |
| OPS-392 layout.lite squash + nolan ops params | 2026-08-13 | 11:40–12:30 (0.83h) |
| OPS-392 gwsproto conformance sweep + squashes | 2026-08-13 | 14:36–16:00 |
| OPS-392 names disjoint + layout collapse | 2026-08-14 | 6h |
| OPS-420 review + grill + design/exploration writing | 2026-08-14 | ~11:30–15:15 (~3.75h) |
| OPS-420 fis.connect.claims + universe.run authoring | 2026-08-14 | 15:28–15:39 (0.2h) |
| OPS-420 staging flip + closing ritual | 2026-08-14 | 15:40–15:46 (0.1h) |
| OPS-420 cert-minting tutorial (notch-2 rollout) | 2026-08-14 | 16:13–18:52 (2.65h) |
| OPS-420 design breakdown into executor | 2026-08-14 | 18:56–18:58 (0.05h) |
| wiki estimates rename + session-hook fix | 2026-08-14 | 18:59–19:06 (0.15h) |
| OPS-422 scoping + FIS steps 1–2 | 2026-08-14 | 1.5h |




## How to use

- Add a row **when the estimate is made**, before starting the work; post the
  full scope as a comment on the Linear issue.
- Fill Actual from the issue's logged hours at wrap; mark In interval? yes/no.
- Never revise low/high after work starts — a busted bound is the data.
- Periodically (every ~10 rows): count the hit rate, note the bias, adjust the
  next intervals accordingly.
