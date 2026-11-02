# Seasonal fills as scada events (backlog design)

Status: Draft · Pass 0 · Updated 2026-11-01 · Linear: OPS-652

> What this is: a small scada design that turns a forecast the scada
> fills from its seasonal template into an event the scada reports, so
> the fill is a fact the fleet record keeps rather than a document only
> the scada ever had.

## The problem

When the pull from the forecast box fails, or the stored forecast does
not cover the next hours or lacks a series the consumers read,
`weather_source.py` `seasonal_fill` builds a `gw.weather.forecast` from
the location's seasonal template on the bundle's slice grid, every series
marked `SeasonalTemplate` fidelity, and mints a `ForecastUid` for it. The
scada's derived channels run on that fill. The id names a document no
forecast box published and no archive can resolve, and nothing upstream
learns the scada ran on a template that hour.

The LTN never runs the FLO on a fill: a `ForecastPair` with
`SeasonalTemplate` fidelity means no run that hour, so the LTN side needs
no event. The scada side does.

## The change

- The fill is a scada event, a sema word (to author: the bundle name,
  the slice grid it was laid on, the template's location alias, the
  fidelity, the window it covered, and why the fill was taken), stored
  by the scada's event persister and sent up when the link to the LTN
  is live again, the way every stored event goes.
- The filled forecast keeps `SeasonalTemplate` on each series and takes
  no `ForecastUid` of its own, or takes one the event also names, so an
  id in the fleet record always resolves to a document the record
  holds. Decide which when the event word is authored.
- One test: a pull failure with a stored template produces the fill for
  the derived channels and exactly one event, which reaches the LTN
  after the link comes back.

## Open

- Whether the event is per fill or per outage (a fill every pull cycle
  while the box is down is many events).
- Whether `gw.weather.forecast` should refuse `SeasonalTemplate` fidelity
  at the word level once the scada stops minting fills as forecasts.
