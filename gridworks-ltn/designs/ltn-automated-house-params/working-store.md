# working-store

Status: Draft · Pass 0 · Updated 2026-10-06 · Linear: OPS-531

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
Observed weather and solar irradiance have no source on the LTN's path
yet; the estimation work used open-meteo for irradiance.

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

## Build step

The SQLite working store as derived projections of the words the LTN
already consumes, the hourly reduction, and the three-week trim.

## Verified by

Deleting the SQLite file loses nothing the LTN needs to keep running. A
three-week-plus-one-day run shows the trim holding.
