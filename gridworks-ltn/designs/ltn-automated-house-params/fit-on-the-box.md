# fit-on-the-box

Status: Draft · Pass 0 · Updated 2026-10-14 · Linear: OPS-531

> What this is: a spoke of [`primary.md`](primary.md). Adopting the
> house-load regression as a daily subprocess on the LTN box: what it
> reads, the choices the estimation work left open, and the checks to run
> on the method before its output drives a house.

## Decision

**The fit runs on the LTN box, as its own daily process.** The LTN
reduces the messages it receives to hourly rows
([`working-store.md`](working-store.md)); the fit is a least-squares fit
over the window, small, and runs as a subprocess so a crash or a hang in
it cannot stall the LTN.

## What is adopted

The regression in the `gridworks-house-parameters` repo: its features,
its cleaning rules, weekly or daily refits on a trailing window, and the
fit-quality figures it produces
([`../../research/house-parameter-estimation.md`](../../research/house-parameter-estimation.md)).
The code moves beside the LTN and reads the working store in place of a
CSV or the data DB.

## Left open by the estimation work

- **Window.** No backlook length is chosen. The code can sweep it by
  forecast error and by coefficient stability. The working store's three
  weeks is the ceiling.
- **Cadence.** Weekly by default; daily is available.
- **Inputs for hours 2 to 48.** The forecast needs weather forecasts for
  every hour ahead, and its lagged-load terms need a value at each hour.
  The previous-hour load is fed forward from the prediction; the
  four-hour load average is not yet.
- **Cold-start priors.** What a new house runs on before its window is
  deep enough: for example a small, medium or large prior from the
  installer's heat-loss estimate.
- **Bounds on the result.** Declared in
  [`acceptance-and-reconciliation.md`](acceptance-and-reconciliation.md)
  "Bounds".
- **Weather the LTN does not have.** Observed outside temperature and
  wind, and solar irradiance
  ([`working-store.md`](working-store.md) "The hourly reduction").
- **Forecast skill as an input.** The fit trains on observed weather
  and runs on forecast weather, so the 48-hour load error includes the
  weather forecast's own error, which the backtest never sees. Before
  choosing a solar source, and for temperature and wind as well, score
  each candidate forecast as issued against a measured or reanalysis
  truth for Millinocket over last winter, by hour ahead. The source is
  chosen on that score and on whether its archive keeps forecasts as
  issued, since the fleet's NWS bundle has no solar field today. Survey
  in progress 2026-10-14.

## Checks before the fit drives a house

From a read of the code; each is confirmed or dismissed by a run.

1. **The backtest sees future load.** From the second hour ahead the
   four-hour load average keeps its observed value, and weather is
   observed, not forecast. The measured gain over the three-coefficient
   form is an upper bound until the backtest feeds both forward.
2. **Hours ahead are rows ahead.** Cleaning removes rows and the
   recursion steps by row position, so across a dropped hour the horizon
   and the previous-hour feature are misaligned.
3. **The energy ratio is computed after rows are dropped.** Heat pump and
   distribution energy balance over whole days; over surviving hours only
   the ratio can move, and it scales every prediction.
4. **Coefficient count against window length.** With hour-of-day terms
   the model has 37 coefficients; ten days is at most 240 rows.
5. **Under-heated hours are excluded.** Hours with a zone below setpoint
   are dropped, so the model describes satisfied demand.

## The comparison that decides adoption

We run the evaluation ourselves; the repo's backtest is a starting
point, not the evidence. The 2025–26 season is recorded: the parameters
each house ran on, the SCADA's hourly forecast of load and RSWT, and what
was measured. Each candidate model (the seven-term regression as
delivered, the three-coefficient form, and any variant we think better)
is replayed over that season with the weather forecast as it was issued
at each origin, never the observed weather, so the 48-hour load error
includes the forecast's own error. The lagged terms are fed forward from
the model's own predictions at every lead. The model adopted for a house
is the one that predicts 48-hour load best under those conditions, and
it must beat the hand-set values that were in force.

## Build step

The fit subprocess on the box, daily, writing its result to the
acceptance path.
