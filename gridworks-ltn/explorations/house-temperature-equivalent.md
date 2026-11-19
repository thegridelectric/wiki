# house-temperature-equivalent

Status: Draft · Pass 0 · Updated 2026-11-18

> What this is: an open question for the LTN's load forecast. The LTN
> gives the FLO one house temperature, used as the inside of the
> inside-to-outside temperature gap. Today that number is the plain
> mean of every zone's thermostat reading. Zones whose thermostats are
> set low and which draw almost no heat pull the mean down and the
> forecast load with it. The question is the house-temperature
> equivalent when zones have different heat demand as a function of
> their room temperature. A stopgap for oak is named at the end.

## The evidence (oak, 2026-11-18, 16:00 to 17:30 ET)

| zone | temp | setpoint | `Critical` | `KwhPerDegF` | heat calls in 24 h |
|---|---|---|---|---|---|
| living room | 59.9 F | 60 F | true | 1.0 | 13 |
| garage | 49.1 F | 45 F | false | 0.0 | 0 |
| gear room | 57.0 F | 50 F | true | 0.0 | 0 |
| upstairs | 62.0 F | 62 F | true | 1.0 | 18 |

The LTN logged the house at 57.0 F, the plain mean. Against a 48 F
forecast outdoors the load model sees a 9 degree gap and forecast
53.5 kWh over 48 hours. The two rooms people live in sit at 60 and
62 F; the garage and gear room are held low and never called for heat.

Where the mean comes from: `actors/ltn/ltn.py` `average_house_temperature_f`
takes the zone temperatures from `_get_zone_info`, which also reads each
zone's `KwhPerDegF` and discards it. The load model is `load_forecast_kwh`
in `actors/ltn/flo_request.py`; its main term is the gap between the
house temperature and the forecast outdoor temperature, floored at zero.

## The question

A house's zones have different heat demand as a function of their room
temperature: a zone at setpoint with a large emitter and a cold wall
behind it draws heat in proportion to its own gap to outdoors, a zone
held at 45 F behind an insulated door draws nearly none. The single
number the load model wants is the room temperature that, applied to
the whole house's loss coefficient, reproduces the sum of the zones'
losses. That is a demand-weighted mean: each zone's temperature
weighted by its share of the house's heat loss per degree. The share is
what we do not have.

## Candidates

1. **Plain mean of all zones.** Today. Equivalent to assuming every
   zone has the same demand as a function of outdoor temperature. At
   oak: 57.0 F.
2. **Mean over `Critical` zones.** Drops the garage; keeps the gear
   room, which is marked critical with a 50 F setpoint. At oak: 59.6 F.
3. **Mean weighted by `KwhPerDegF`.** The layout already authors a
   per-zone thermal mass, 1.0 for oak's living room and upstairs, 0.0
   for the other two. At oak: 61.0 F. Thermal mass is not loss
   coefficient, but the gen authors it per zone with the intent "how
   much this zone matters", and it is the only per-zone weight on
   file.
4. **Mean weighted by observed heat-call share** over a trailing
   window. Closest to true demand; needs a window from the journal or a
   running tally in the LTN, and a zone that is warm and quiet gets no
   weight for the wrong reason.
5. **A per-zone loss share in the layout word.** The right durable
   answer: `gw1.hvac.zone` gains a field for the zone's share of the
   house's heat loss per degree, fitted from data the way the house
   parameters are (OPS-531). The LTN weights by it.

The fleet's layouts disagree on which existing field means "counts":
beech's `up` zone is critical with mass 0.0; fir's sunroom is not
critical with mass 0.5; spruce's garage is not critical with mass 1.0.
Candidate 2 and candidate 3 give different answers on three of the six
houses, so neither field is today a clean statement of demand share.

## The oak idea

Candidate 3 is a one-line change in `average_house_temperature_f`
(weight each zone's temperature by its `KwhPerDegF`; a zone of mass 0
drops out; all masses 0 falls back to the design room temperature as
now) plus a test. It moves oak from 57 to 61 F and raises its forecast
load about 40 percent. It is a stopgap because `KwhPerDegF` is thermal
mass, not loss share, and because the fleet's masses were not authored
with this use in mind; the back-test decides whether it also holds on
the evenly heated houses.

## How this would be settled

1. Back-test candidates 1 to 4 over the journal for oak and maple
   (evenly heated, two zones both mass 1.0) across a cold week: the
   candidate house temperature at each hour fed to `load_forecast_kwh`,
   against the next hour's measured distribution energy.
2. Ship the stopgap for oak if the back-test does not contradict it.
3. Spec candidate 5 as the durable answer: the field, who fits it, how
   the LTN reads it. Fold into OPS-531's parameter work or stand alone.

## Open

- Whether the FLO should also see per-zone temperatures and setpoints
  rather than one number (OPS-114 and OPS-315 raise neighbours of this).
- How a zone whose setpoint is raised for a day (the gear room boosted
  from 45 to 60 F, OPS-315) should enter the weighting.
