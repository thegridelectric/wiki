# Fleet price response and ISO-NE peak hours

Status: Draft · Pass 0 · Updated 2026-09-24

What this is: what two Maine heating seasons of fleet data show about
avoiding high-price hours and ISO New England's monthly peak hours, the
caveats on that evidence, and pseudo-code for turning the analysis into
a re-runnable experiment.

## Question

A light plant's transmission and capacity charges are set by ISO New
England's peak hours: the monthly system peak for Regional Network
Service, the annual peak for capacity. Does a fleet of dispatched
air-to-water heat pumps with thermal stores stay off in those hours, and
why?

## Findings

Data: the journal DB's hourly cache (`gridworks.cached_hourly_data`) for
the Millinocket fleet, October 2024 to August 2026, three to six homes
reporting. Peak hours from EIA-930 hourly demand for the ISNE balancing
area. Searchable header in the EIA files: "Demand (MW) (Adjusted)".

**The fleet avoids the hours its price marks as high.** November to
March, in the hours where the cache holds the price each home was given:

| Season | Home-hours with a price | kWh in the home's top 10% price hours | in its top 20% | Average price | Energy-weighted price paid |
|---|---|---|---|---|---|
| 2024-25 | 4,102 | 0.3% | 0.7% | $190/MWh | $79/MWh |
| 2025-26 | 5,930 | 0.4% | 0.8% | $235/MWh | $124/MWh |

**The fleet stays off in ISO-NE peak hours when the peak is in its
price.** In 20 of 23 months the monthly peak hour fell inside a weekday
on-peak block of the Millinocket delivery tariff, and the fleet drew
0.02 to 0.13 kW per home against monthly means of up to 4 kW.

**It does not when the peak is not in its price.** Three winter monthly
peaks fell on Sundays, outside the tariff's on-peak blocks:

| Peak hour (ET) | ISNE demand | Fleet draw | Control |
|---|---|---|---|
| 2024-12-22 17:00 | 18,942 MW | one of three homes running, 6.1 kW | local control |
| 2026-01-25 13:00 | 20,279 MW | 6.2 kW per home, five homes | local control |
| 2026-02-08 17:00 | 20,145 MW | 4.8 kW per home, five homes | four local control, one dispatched |

Weekend hours in those seasons were used to test price signals other
than the real-time price, so a weekend peak was often not a high-price
hour in the signal the homes received.

**What follows.** An optimizer avoids the hours its price tells it are
expensive, and no others. A delivery tariff with fixed weekday blocks
catches the system peaks that happen to fall inside its blocks and
misses the rest. For a light
plant, the peak signal has to reach the optimizer through the price: a
day-ahead list of hours to stay off, priced into delivery, does this.

## Caveats

- EIA-930 hourly demand is not ISO-NE's settlement data. Confirm the
  three Sunday peak hours against ISO-NE's own monthly peak hours before
  citing them.
- The cache records a price for only part of each season; the price
  table is a sample.
- The cache's outdoor temperature is corrupt in places (500°F+, and
  40°F/160°F readings in February 2026), and it has no rows for June and
  July 2026.
- "Control" is the scada's `auto` state machine sampled in the hour:
  `Atn` / `LeafTransactiveNode` is dispatch; `HomeAlone` /
  `LocalControl` is local control.

## Reproducing it as an experiment

The runs above were throwaway spot-checks. As an experiment they become
a dated folder under `experiments/` with a re-runnable script, typed
records and a README. Pseudo-code:

```
inputs
  fleet        = the hw1 terminal assets to include
  window       = [start, end) in ET
  peak_source  = ISO-NE hourly system load (preferred) or EIA-930 ISNE
                 six-month files, Adjusted Demand, keyed by hour start UTC

records (typed; no sema word covers these yet, name the missing word)
  PeakHour(month, hour_start_utc, system_mw, is_annual)
  FleetAtHour(hour_start_utc, homes_reporting, kw_total, kw_per_home,
              control_by_home)
  PriceAvoidance(season, home_hours, kwh, pct_top10, pct_top20,
                 avg_price, paid_price)

1. peak hours
   for each month in window:
     peak = argmax(system_mw over the month's hours)
   annual peak = argmax over each calendar year (full years only)

2. fleet load at each peak hour
   rows = cached_hourly_data where time_bucket = peak.hour_start_utc
   kw_total = sum(hp_kwh_el)            # one-hour bucket, so kWh = kW
   also record the month's mean per-home kW for contrast

3. control mode at each peak hour
   for each home: first report.event in the hour,
     StateList entry with MachineHandle == "auto", last state
   (the enum is main.auto.state or gw1.main.auto.state by date;
    key on the handle)

4. price avoidance (heating months)
   per home, per month: rank hours by total_usd_per_mwh
   share of hp_kwh_el in rank >= 0.9 and >= 0.8
   energy-weighted price = sum(kwh * price) / sum(kwh)

5. report
   one table per record type; flag null prices, corrupt outdoor
   temperature and cache gaps rather than dropping them silently
```

A forward experiment for the next heating season tests the conclusion
directly:

```
each day
  take ISO-NE's forecast of likely monthly and annual peak hours
  add them to the homes' delivery price as a day-ahead stay-off list
at month end
  steps 1 and 2 on the actual peak hours
pass when the fleet draw in every monthly peak hour is at or near zero
  while the service level agreement on delivered heat holds
```
