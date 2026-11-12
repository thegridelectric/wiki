# working-store

Status: Draft · Pass 0 · Updated 2026-11-06 · Linear: OPS-531

> What this is: a spoke of [`primary.md`](primary.md). The LTN's small
> SQLite working store: what it holds, how hourly rows are reduced from
> the messages the LTN receives, and the rule that nothing the LTN needs
> to keep running lives in it.

## Decisions

- **One SQLite file per LTN, never a shared database.** One LTN per
  house, one store per LTN. A fleet-wide database grows in ways nobody
  planned and its schema becomes meaning that cannot move. Every table
  is a projection of a sema word, the schema is derived from the word
  and never authored by hand, and the LTN may change its own store's
  structure freely: nothing else depends on it.
- **Bounded retention, as a rule.** The store holds a working window,
  three weeks of hourly rows reduced from the messages the LTN receives,
  plus forecasts, prices, and the live bid and contract state. Nothing
  older, and nothing in it is a source of truth. A question further back
  is answered by the journal or the eventstore, not by the LTN.
- **A lost store starts empty.** Deleted, it refills from live messages
  over three weeks; until the window is deep enough the LTN runs on the
  set it has. No recovery reads the ear capture or the journal.

## The hourly reduction

The fit needs one row per hour. The estimation code builds these rows
from the readings tables of the data DB; the LTN builds the same rows
from the `report.event` messages it receives from its SCADA.

Per hour, from the SCADA's channels:

- heat pump thermal energy: `primary-flow`, `hp-lwt`, `hp-ewt`;
- distribution energy: `dist-flow`, `dist-swt`, `dist-rwt` (`dist-flow`
  is the flow of record; `dist-flow2` is a spare meter);
- oil boiler power: `oil-boiler-pwr`;
- per zone: mean temperature, mean setpoint, heat-call fraction.

Per hour, from weather: outside air temperature, wind speed, solar
irradiance. The LTN already fetches temperature and wind forecasts.
Observed temperature and wind have no source on the LTN's path yet.
Observed irradiance has no measured source anywhere until the weather
service's observed channel gets one (OPS-621, waiting on a Wunderground
key or a GridWorks pyranometer); the first-pass fit takes Open-Meteo's
past hours as its solar column, fetched by the LTN itself, as the
estimation work did. That column is a model output and is never
published as an observation.

Open:

- Where the LTN gets observed outside temperature, wind and irradiance
  for the hours it reduces, and whether irradiance is worth a new
  dependency on the control plane.
- Channel names are read from the layout the SCADA sends, not from
  constants in the LTN. The layouts arriving this fall have no buffer
  tank, and one has no water store; the reduction uses only heat pump,
  distribution and zone channels, which every layout has.
- The three-week window against the fit's backlook: the store's window
  is the upper limit on the fit window
  ([`fit-on-the-box.md`](fit-on-the-box.md) "Window").
- **The forecast's own history comes from the store.** The load model
  has autoregressive terms: the previous hour's load, the four-hour mean
  load and the four-hour mean outdoor temperature. At the bid minute the
  LTN reads the last four hourly rows for them. Today those four hours
  are two in-memory lists in `actors/ltn/ltn.py` (`last_four_dist_kwh`,
  `last_four_oat_f`) that start empty on every LTN restart, so the first
  run after a restart falls back to the baseline model and the next
  three run the regression on means over fewer hours than it was fitted
  on. The store retires both lists, and the hourly row is where the
  typing of those inputs is settled: energy in kWh as a float, outdoor
  temperature in °F as a float, an hour with no reading as an absent
  row, not a `None` inside a tuple inside an optional list.

## Build step

The SQLite working store as derived projections of the words the LTN
already consumes, the hourly reduction, and the three-week trim.

## Verified by

Deleting the SQLite file loses nothing the LTN needs to keep running. A
three-week-plus-one-day run shows the trim holding.
