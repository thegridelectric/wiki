# Heat pump lift against data

Status: Draft · Pass 0 · Updated 2026-11-01 · Linear: [OPS-650](https://linear.app/gridworks/issue/OPS-650)

**EDD: yes** the verification is a measured lift per house per hour from
the journal, compared with the 20 F the FLO assumes; the design holds if
the fleet's lift sits within a band the FLO's store model is insensitive
to, and otherwise says what replaces the constant.

> What this is: test the bruce FLO's assumption that a heat pump raises
> the water it charges the store with by a constant `hp_constant_lift_f`
> (20 F at every house), using a season of `hp-lwt`, `hp-ewt`,
> `primary-flow` and heat pump power from the journal DB. The assumption
> is stated in `executor/bruce-flo.md` "The heat pump".

## Why it matters

The lift is the one plant fact in the FLO that reaches the tank layer
directly: heated water enters the store at the drawn layer's temperature
plus the lift, and that placement decides how much heat the store takes
before its top hits the ceiling. A wrong lift mis-sizes the store in the
plan, so the bid promises a quantity the plant cannot place or leaves
room unused. Physically the lift is thermal output over primary flow
times the specific heat; with a fixed-speed primary pump it falls as the
heat pump modulates down and as outdoor temperature falls.

## The data

Per house, every minute the heat pump runs, from the journal DB
(`DB_ANALYST_URL` in `experiments/.env`; the pull is
`experiments/spot-check-recipe.md`):

- `hp-lwt` and `hp-ewt`: the measured lift is their difference.
- `primary-flow`: with the lift, the delivered thermal power.
- `hp-odu-pwr` plus `hp-idu-pwr`: the electrical draw, so the COP comes
  along for free.
- Outdoor temperature from the weather forecast the house used.
- The heat pump's device type, from the house's layout, so the Samsung
  houses and elm's Arctic are read apart.

Minutes within `HpTurnOnMinutes` of a start are excluded; the lift is
read in steady running.

## The questions

1. **Distribution.** Per house and per device type: the lift's median,
   its spread, and how much of the running time lies within ±5 F of
   20 F.
2. **What it depends on.** Lift against outdoor temperature and against
   electrical draw, per house. A flat line says the constant is fine; a
   slope says which variable the FLO's lift should take.
3. **Sensitivity.** Run the FLO on one house's real params at the
   measured 10th, 50th and 90th percentile lift and compare the
   recommended quantity at the forecast price and the plan's first
   hours. The band the plan is insensitive to is the band the constant
   may sit in.

## Outcomes

- **The constant holds**: the lift stays in the insensitive band across
  houses and weather. The 20 F moves from a fleet-wide constant to a
  per-house value on the ops word's FLO tuning sub-word, read from this
  analysis, and the executor says so.
- **The constant fails**: the lift varies with output or outdoor
  temperature beyond the band. The FLO's lift becomes a derived
  quantity, heating capacity over primary flow, from
  `hp.device.type.gt` `HeatingCapacityBtuHr` and a primary-flow fact
  the layout states, with the capacity's dependence on outdoor
  temperature as the device record's addition. That change is raised
  with the FLO's author before any word is edited.

## Plan

1. Pull one week of cold weather and one of mild for every house with a
   heat pump that ran (the 2025–26 season has both), into
   `experiments/<date>-hp-lift/`.
2. The distribution and dependence plots, one page per house.
3. The sensitivity run on oak's params from the ltn journal.
4. Write the outcome into `executor/bruce-flo.md` and close.

**Do this next:** create the Linear issue and the experiment folder, then
the pull.
