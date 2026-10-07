# House parameter estimation: what the fit repo holds

Status: Draft · Pass 0 · Updated 2026-10-06

> What this is: a memo on the house-load regression in the
> `gridworks-house-parameters` repo (read at commit `f63e1b2`), the hand-off
> from the estimation work to the LTN that will run it (OPS-531). It says
> what the method is, which of the FLO's house parameters it covers, what
> the LTN work takes on from here, and where the fleet's stored messages
> record the parameters each house ran on. The method sections are from
> reading the code; no fit was run.

## What the method is

An hourly ordinary-least-squares regression that predicts a house's heating
load for the next 48 hours.

- **Target.** Distribution energy per hour, scaled so that it sums to the
  heat pump's thermal output over the training window:
  `dist_kwh × (sum(hp_kwh_th) / sum(dist_kwh))`
  (`house_parameters.py:505-507`). The scale factor is stored with each fit
  as `energy_ratio`.
- **Features** (`house_parameters.py:62-69`):
  - `deltaT`: mean zone setpoint minus outside air temperature, floored at 0;
  - `windspeed_times_deltaT`;
  - `solar_w_m2`, from open-meteo;
  - `previous_dist_kwh_scaled`: the previous hour's scaled load;
  - `OAT_avg_4h`: mean outside temperature over the previous four hours;
  - `dist_kwh_scaled_avg_4h`: mean scaled load over the previous four hours;
  - optional hour-of-day indicators, weekday and weekend separately, for 15
    chosen hours (30 more coefficients; on by default).
- **Prediction** is the fitted linear form floored at 0. Beyond the first
  hour the previous-hour load is the model's own previous prediction.
- **Cleaning before the fit** (`house_parameters.py:236-492`):
  - values outside a valid range per channel become missing, as do outside
    temperature jumps over 25 °F in an hour;
  - gaps under four hours are interpolated; longer gaps are dropped;
  - hours are dropped when the oil boiler ran, when any zone was 1 °F or
    more below setpoint, when a setpoint changed, or when a thermostat looks
    broken (no heat call while 3 °F cold, or a heat call while 3 °F warm).
- **Training window and cadence.** The fit uses the last N calendar days and
  refits weekly by default. `main.py` runs N = 10; `sweep_n` exists to
  compare N from 5 to 200 by forecast error and by how much the `deltaT`
  coefficient moves between refits. The repo records no chosen N.
- **Fit quality carried with each fit:** coefficient standard errors, R², and
  `energy_ratio` (`house_parameters.py:21-28`).
- **Backtest.** For every hour it takes the latest fit trained before that
  day, predicts 48 hours, and scores against actual load (MAE and RMSE,
  overall and by hours ahead), beside a baseline.
- **Baseline.** The older three-coefficient form
  `alpha + beta × OAT + gamma × windspeed × (65 − OAT)`, refit on the same
  window. It is not the alpha, beta and gamma values that were in force in
  any house last season.

## Which FLO parameters this covers

The FLO takes its house parameters in `flo.params.house0`
(`sema/definitions/types/flo.params.house0/007.yaml`). The regression
replaces one group of them and leaves the others untouched.

| Group in `flo.params.house0` | What it sets in the FLO | In the fit repo |
|---|---|---|
| `AlphaTimes10`, `BetaTimes100`, `GammaEx6` | Forecast heating load | Replaced by the new regression |
| `IntermediatePowerKw`, `IntermediateRswtF`, `DdPowerKw`, `DdRswtF` | Required source water temperature as a function of load | Not addressed |
| `DdDeltaTF` | Temperature drop across the emitters | Not addressed |
| `CopIntercept`, `CopOatCoeff`, `CopLwtCoeff`, `CopMin`, `CopMinOatF` | Heat pump COP | Not addressed |

How hot the FLO charges the store depends on all four groups. A load forecast
that runs high asks for too much energy. A required source water temperature
that runs high, or an emitter temperature drop that is wrong, asks for that
energy at too high a temperature. The fit repo can only speak to the first.

## What the hand-off delivers

The hand-off is accepted as it stands. The right column is the starting
point for the LTN work, not a list of defects.

| Hand-off item | State in the repo |
|---|---|
| Hourly channels read | In code: `hp-ewt`, `hp-lwt`, `primary-flow`, `dist-swt`, `dist-rwt`, `dist-flow` (the distribution flow of record; `dist-flow2` is a spare meter), `oil-boiler-pwr`, and each zone's `temp`, `set`, `heat-call` (`get_data.py:24-37`). The store channels are requested and not used. |
| Weather fields, naming any the fleet does not collect | Outside temperature, wind speed, solar irradiance. The database path fills none of the three (`house_parameters.py:150-152`; README note). Solar irradiance comes from open-meteo and has no fleet source. |
| Regression form | Written in the README. `deltaT` uses the average setpoint, not the average inside temperature. |
| Backlook window | Not decided in writing. |
| Retraining frequency | Weekly by default, daily available. |
| How the sema word conveys fit quality | Not addressed. The candidates are the three quantities each fit already carries. |
| Code beside the FLO in `gridworks-innovations` | It is in its own repo. |
| Script deriving hourly rows from the messages table (`report.event`) | The script reads the readings tables (`gridworks.retrieve_readings_1s`, `gridworks.readings`) through `GW_DATA_DB_URL`, not the messages table. |
| A weather sample; runnable end to end | No data is committed (`data/` is ignored). The default source is a CSV that is not in the repo, so a fresh clone cannot run. |
| Cold-start priors | Absent. |
| Acceptable ranges for fitted parameters | Absent from the code. |

## What the LTN work checks when it adopts the fit

These come from reading the code. Each needs confirming with a run, and each
is the LTN design's to settle.

1. **The backtest sees future load.** In the 48-hour recursion only the
   previous-hour load is replaced by the prediction
   (`house_parameters.py:694-699`). `dist_kwh_avg_4h` keeps its observed
   value at every hour ahead, so from the second hour on the forecast is
   given the average of loads it is supposed to be predicting. Weather is
   also observed, not forecast. The reported
   improvement over the baseline is therefore an upper bound.
2. **Hours ahead are rows ahead.** Cleaning removes rows, and the recursion
   steps by row position (`house_parameters.py:695-696`), so after a dropped
   hour "48 hours ahead" spans more than 48 hours and the previous-hour
   feature is not the previous hour.
3. **The energy ratio is computed after rows are dropped.** Heat pump output
   and distribution output balance over whole days, since the store shifts
   heat between hours. Summing each over only the surviving hours can move
   the ratio, and the ratio scales every prediction.
4. **Coefficient count against window length.** With the hour-of-day
   indicators on, the model has 37 coefficients. A 10-day window has at most
   240 hourly rows before cleaning.
5. **Under-heated hours are excluded.** Dropping hours with a zone below
   setpoint removes the hours where the system was at its limit. The model
   then describes satisfied demand only.

## Where the in-force parameters are recorded

The fit repo's baseline is a refit, so it does not show what any house ran
on. The fleet's messages do. The journal DB holds, for the 2025–26 season:

- `flo.params.house0` from each LTN, with the whole set for every FLO run
  (present only in the months the FLO ran);
- the scada's own copy in `layout.lite` → `Ha1Params`, all season;
- the scada's hourly `heating.forecast` (`AvgPowerKw`, `RswtF`,
  `RswtDeltaTF`), computed from that copy.

The record shows the parameters were set by hand and revised several times a
season: forecast-load coefficients and design-day power came down in every
house between December and January, design-day RSWT moved up and down, and
`DdDeltaTF` stayed at 20 °F everywhere. The LTN and the scada hold separate
copies that were edited separately. The values, the coverage and the test of
whether the early values over-heated the store are in
`heating-system-design/mix-or-not.md` "Charge: how hot is hot enough".

## Open

- Who estimates the required-source-water-temperature points, `DdDeltaTF` and
  the COP terms, and whether they join the automated fit or stay by hand.
