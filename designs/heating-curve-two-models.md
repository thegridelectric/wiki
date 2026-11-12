# Heating curve: two models, two words

Status: Draft · Pass 0 · Updated 2026-11-11 · Linear: OPS-668

**EDD: no** a word splits in two along a seam the code already has;
verified by the sema and scada suites, the four test ops files and oak
rolled to the new pair with its FLO still bidding.

> What this is: `heating.curve` describes two house models in one word,
> the quadratic heat-load curve the scada runs and the regression load
> forecast with a radiator RSWT model the LTN runs, and says nothing
> about which field serves which. Each model gets its own word in
> `gw.operational.params`.

## Why

The scada's derived generator reads the quadratic coefficients and the
anchor points, through `Ha1Params`, for required energy and the heating
forecast. The LTN reads the regression coefficients, rho, mass flow and
the design-day room temperature for its load and RSWT forecasts, and
falls back to the quadratic only when it has no history. These are two
models with two consumers, and they are allowed to disagree: the scada
may keep a simpler model than the optimizer. One word for both forced
`Baseline*` prefixes on half the fields, left `GammaEx6` meaning one
thing in one model and another in the next, and makes every reader of
the word hold fields it never uses.

## The change

- **`heating.curve` keeps the quadratic.** The word returns to its
  quadratic heat-load fields under their own names (no `Baseline`
  prefix, since nothing else is in the word) plus the intermediate and
  design-day anchor points and `MaxEwtF`. The `GammaEx6` description
  states the unit the formula implies, kW per mph per degree F. It is
  the word `make_ha1_params` reads, field for field.
- **A new word for the regression load forecast.** The seven scaled
  coefficients (intercept, indoor-outdoor delta-T, wind times delta-T,
  solar, four-hour mean outdoor temperature, previous-hour load,
  four-hour mean load), `RhoTimes100`, and the radiator RSWT model's
  inputs (`DdPowerKw`, `DdRswtF`, `DdRoomTempF`, `MassFlowKgH`). Sema
  words are flat, so the two design-day anchors appear in both words.
  Working name `gw.load.forecast.model`; the name is open below.
- **`gw.operational.params` gains the second field** beside
  `HeatingCurve`, both required. Both words are staging, so this is an
  in-place edit of 000 on all three, in one wave with the gwsproto
  twins, the scada snapshot, the four test ops files and tlayouts.
- **Readers move.** `make_ha1_params` reads `HeatingCurve` unchanged.
  The LTN's `load_forecast_kwh` and `rswt_forecast_f` read the new
  word; `baseline_load_kwh` reads `HeatingCurve`.
- **Axioms on `heating.curve`** are added in the same edit:
  `IntermediateRswtF < DdRswtF` and `DdRswtF <= MaxEwtF`, both
  invariants the anchors have always had and the word never stated.

## Open

- The new word's name. `gw.load.forecast.model` says what it is;
  `gw.house.load.regression` says how. The registry's first-segment
  convention groups by owner, so `gw.` is right either way.
- Whether the radiator RSWT inputs belong in the regression word or in
  a third word of their own. They are consumed together by the LTN
  today, which argues for one word; a third word is right the day a
  second RSWT model appears.
- Whether the quadratic's anchor points stay required once the LTN no
  longer reads them. The scada's heating forecast still does, so yes
  for now.

## Next

Author the two words under the sema protocol: spec read-receipt for
types, then the schemas and the registry edit on a sema branch, the
gwsproto twins against the regenerated snapshot, and the LTN and
`make_ha1_params` reads. The twins and the reader moves are a good
piece for a second pair of hands once the words exist.
