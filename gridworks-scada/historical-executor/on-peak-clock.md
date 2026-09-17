# The on-peak clock as the fleet ran it (2024-11 to the renovation deploy)

Status: Draft · Pass 0 · Updated 2026-09-16

> What this is: the time-of-use clock the deployed scada code ran on the
> fleet, three separate hand-written tables of Versant's on-peak hours
> and the slip in one of them, so a reader of control and setpoint data
> from that window can tell the code's behaviour from the house's. The
> current rule reads the ops word's `OnPeakWindows` (`actors/hydronic/
> shared.py`) and the changelog carries the change; this page holds what
> the fleet ran before it.

## The rule the fleet ran

The tariff's on-peak hours lived in the code as three independent
tables, none of them read from configuration:

- **Control clock** (`sh_node_actor.py`, `is_onpeak`, from `f2344d90`,
  2024-11-13): on-peak is weekday hours 7 to 11 and 16 to 19, judged
  now or two minutes ahead. Every local-control and leaf-ally decision
  that asks "are we on-peak" reads this one: charge or hold the heat
  pump, fall to the oil boiler, the cold-house override.
- **Setpoint memory** (`just_before_onpeak`, from `09108081`,
  2024-12-17, first inline in `home_alone.py`): the TOU impls remember
  each zone's thermostat setpoint just before a peak so that a
  thermostat raised during the peak does not read as a cold house. The
  refresh fired when the hour was 6 or 16 and the minute past 57, so at
  6:58 and at 16:58. The morning time is two minutes before the 7:00
  peak. The evening time is an hour into the 16:00 peak: the hour
  should have been 15. There was no weekday check, so the refresh also
  ran at weekends, harmlessly.
- **Energy planning** (`derived_generator.py`, the required-energy and
  storage-target methods, from `3505b6e4`, 2024-11-19): "which peaks
  are coming" is a second inline table (after 20:00 or before 7:00 on a
  weekday prepares for both peaks; noon to 16:00 prepares for the
  afternoon one; the forecast slice 12 to 15 is the pre-peak charging
  window).
- **LTN fuel substitution** (`ltn/contract_handler.py`, from
  `250d1dda`, 2026-02-04): a third copy of the control clock, gating
  whether an on-peak price above the fuel-substitution threshold sends
  the house to oil.

## Its signature in the data

- On weekday evenings the remembered setpoint for the cold judgment is
  the thermostat's value at 16:58, not at 15:58. A thermostat raised
  between 16:00 and 16:58 became the memory, so a house left cool
  against the raised setpoint could read as cold and trigger the
  on-peak heat-pump override in that hour; after 16:58 the lower of
  memory and current setpoint governed, as designed. Mornings ran as
  designed.
- The three tables agreed on the hours, so no data window shows one
  clock on-peak and another off. A future tariff change would have
  needed three edits.

## What replaced it

Scada `jm/spruce-unlimbo` (2026-09-16, the "layout answers its own
store tanks" cluster): `is_onpeak`, `just_before_onpeak` and the
setpoint memory read the ops word's `OnPeakWindows` (`gw.tou.window`,
Start inclusive, End exclusive, listed days); "just before" is the two
minutes before a window opens on a day that has one. The energy
planner's table and the LTN's copy are unchanged there and are the
price-forecast service's to retire (OPS-437). This page's window closes
on the date that commit reaches the fleet boxes; record it here then.
