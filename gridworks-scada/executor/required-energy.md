# Required energy and usable energy

Status: Draft · Pass 0 · Updated 2026-10-04

> What this is: how the scada judges whether a House0 home's thermal store
> holds enough heat to ride through the coming on-peak hours. Two derived
> channels carry the judgment, `required-energy` and `usable-energy`, both in
> Wh, both computed by `DerivedGenerator`
> (`gw_spaceheat/actors/derived_generator.py`).

## What the two channels mean

- **`required-energy`** is the heat (Wh) the store should hold *now* so the
  house can go through the on-peak hours ahead without running the heat
  pump. It comes from the heating forecast and a clock; it never reads a
  tank temperature. It is zero when no on-peak period is near.
- **`usable-energy`** is the heat (Wh) the store can actually deliver to the
  house from its present temperatures, given how hot the supply water has to
  be to meet the forecast load.

The House0 strategies compare them. `is_storage_ready`
(`local_control/house0/all_tanks_tou.py`) and `is_buffer_ready`
(`buffer_only_tou.py`) are `usable >= required`; AllTanks also acts on a
shortfall above 3 kWh while charging. Both strategies, local-control and
leaf-ally, stay in `Initializing` until `required-energy` has a value. Under
`BufferOnly`, `evaluate_strategy` compares `required-energy` hourly with
what a full buffer could hold and sends an info Glitch suggesting all tanks
when the buffer cannot cover it.

Each channel is a system-model DerivedChannel whose `EnergyModel` parameter
names its model (`RequiredEnergyLayered`, `UsableEnergyLayered`); the House0
layout word requires both by exact name. The derived generator computes
each and sends a `SingleReading` to the primary scada.

## The heating forecast behind both

Per forecast hour, from the weather forecast and the home's `Ha1Params`:

- **Load** `AvgPowerKw` = `alpha + beta*oat + gamma*wind*(65 - oat)`, raised
  by the ops word's `LoadOverestimationPercent`, floored at zero
  (`required_heating_power`).
- **Required supply temperature** `RswtF`: the supply temperature at which
  the distribution system delivers that load, from a quadratic fitted to the
  home's design-day point (`required_swt`, `rswt_quadratic_params`).

## How required energy is calculated

`compute_required_energy_wh` returns `None` until buffer temperatures and a
heating forecast exist. The heating forecast is made from the weather
forecast, so a heating forecast with no weather forecast behind it is a
defect, and the pass raises a `RuntimeError` that says so at any hour.
Then:

1. **Sum the forecast load over three hour bands** across the whole forecast:
   morning (hours 7 to 11), midday (12 to 15), afternoon (16 to 19).
2. **Find the most the store can hold.** Start every layer at
   `MaxEwtF + 10` (three layers per tank; all store tanks under `AllTanks`,
   the buffer's three under `BufferOnly`) and drain it with the layered loop
   below; the total is `max_storage_kwh`.
3. **Pick the case by the clock:**
   - *Evening before a weekday, or a weekday before 07:00* (Sunday to
     Thursday from 20:00; Monday to Friday through 06:59): the store must
     cover the morning, plus whatever part of the afternoon the heat pump
     cannot put back during midday. The midday recharge is estimated as
     `0.8 * 4 h * HpMaxKwEl * COP` (80 % of full power to allow for defrosts
     and starts), with the COP taken at the coldest midday forecast
     temperature, less the midday load itself. Required =
     `morning + max(0, afternoon - (recharge - midday))`, capped at
     `max_storage_kwh`.
   - *Weekday midday* (12:00 to 15:59): required = the afternoon sum. No cap.
   - *Otherwise* (inside an on-peak period, or none coming soon): zero.

## The layered drain (usable energy, and the cap above)

The store is modeled as a stack of equal layers, hottest first. Each step
takes the top layer at temperature `T`, asks `rwt_f(T)` for the temperature
it returns at, credits `mass * c_water * (T - rwt)`, and pushes the returned
water onto the bottom of the stack. When the top layer can give up nothing
(`round(T) == round(rwt)`), the stack is mixed to its mean; if the mean can
give up nothing either, the drain ends. Usable energy runs this on the
measured layer temperatures (a missing layer is skipped and the water volume
is shared over the layers present); it is computed only when the ops word
says `AcceptsDispatch` and `ServiceMode` Heating.

`rwt_f(swt)` is the return temperature for supply water at `swt` against the
hardest upcoming on-peak hour. It takes the highest `RswtF` among forecast
hours inside the ops word's `Tariff.OnPeakWindows` (`in_onpeak_window`):
every window when the morning is still ahead (clock hour after 19 or before
12), only hours from 16:00 otherwise.

**Going into a weekend no on-peak hour counts**, since the forecast runs 48
hours and the windows are weekday ones: from Friday 19:00 to Saturday 06:59
it holds no on-peak hour at all, and from Saturday 12:00 to 15:59 none from
16:00. The windows' clock hours then count on any day
(`in_onpeak_clock_hours`), so Saturday 08:00 or Sunday 17:00 can set the
required temperature. The weekend is judged as if it were on-peak, which
counts less of the store as usable than a rule that knew no peak was coming
would.

Water at or above that required
temperature gives the full delta-T the distribution system produces at
`swt`; water more than 10 F below it gives nothing; between, the delta-T
scales linearly.

## The tariff is assumed, not read

Everything above about *when* is written for one tariff: weekdays, 07:00 to
12:00 and 16:00 to 20:00, with a four-hour midday gap. `rwt_f` asks the ops
word which forecast hours are on-peak, but keeps two clock-hour tests
("morning still ahead", "from 16:00"). `compute_required_energy_wh` reads
nothing from `Tariff.OnPeakWindows`: the three hour bands, the weekday
tests, and the `4` in the recharge estimate are literals. A home whose ops
word carries different windows gets on-peak control from the word
(`is_onpeak`, `just_before_onpeak`) and store sizing from the literals, and
the two disagree. The general rule the literals are a case of: before each
upcoming window, the store needs that window's load, less what the heat pump
can recharge in the gap before it. Moving the calculation onto that rule is
[OPS-551](https://linear.app/gridworks/issue/OPS-551).

**A tariff with no on-peak windows stops the pass.** `rwt_f` takes a `max`
over the hours that count, and the weekend rule above only widens the days,
not the hours. An ops word whose `Tariff.OnPeakWindows` is empty leaves
nothing to take the max of at any hour; one with no window reaching past
16:00 leaves nothing between 12:00 and 19:59. Either way `rwt_f` raises a
`ValueError` on every main-loop pass, for usable and required energy alike.
Every house's ops file and every scada test fixture carries both windows,
but the `gw.tou.tariff` word allows an empty list. Open: what the store
judgment means at a house with no on-peak hours (a flat rate), which the
general rule of OPS-551 has to answer; until then such a tariff needs a
named refusal at load, not an empty `max`.

Open: both calculations live in `DerivedGenerator`, which every layout
runs, but they model House0 water storage; the Nolan word requires neither
channel, though the Nolan sim fixture carries both.
