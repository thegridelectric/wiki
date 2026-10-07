# parameter-word

Status: Draft · Pass 0 · Updated 2026-10-06 · Linear: OPS-531

> What this is: a spoke of [`primary.md`](primary.md). The sema words
> this design needs: the parameter set that comes into the LTN, and the
> in-force set exchanged between LTN and SCADA. It also settles which
> parameter groups a set carries and what required source water
> temperature (RSWT) means in it, because the word cannot be authored
> until that is decided.

## Do this next

Decide, with the human, the three questions under "Open before
authoring". Nothing is authored in sema before then, and every new word
goes through the sema authoring gate with a registry search first.

## The words

- **The parameter set into the LTN**, from the fit subprocess or the
  operator: the values, the fit window, the method, the fit-quality
  figures, a created stamp, and a set id.
- **The in-force set between LTN and SCADA**, both directions: the
  successor of `flo.params.house0`'s parameter fields, or a new version
  of that word. It carries the whole set and its id, never a delta.

`flo.params.house0` is the word the LTN publishes for each FLO run
(`sema/definitions/types/flo.params.house0/007.yaml`). It mixes three
things in one flat word: house parameters, the forecasts for one run, and
the initial store state. The SCADA's copy travels as `ha1.params` inside
`layout.lite`. Both exist today; the new word replaces the house
parameters in each.

## What a set covers today

| Group | Fields | Set by | Covered by the automated fit |
|---|---|---|---|
| Forecast load | `AlphaTimes10`, `BetaTimes100`, `GammaEx6` | Hand | Yes: replaced by the regression's coefficients |
| RSWT curve | `IntermediatePowerKw`, `IntermediateRswtF`, `DdPowerKw`, `DdRswtF` | Hand | No |
| Emitter temperature drop | `DdDeltaTF` (SCADA), `ConstantDeltaT` (FLO) | Hand; 20 °F everywhere last season | No |
| COP | `CopIntercept`, `CopOatCoeff`, `CopLwtCoeff`, `CopMin`, `CopMinOatF` | Hand | No |
| Limits | `MaxEwtF`, `HpMaxKwTh`, `LoadOverestimationPercent` | Hand | No |

The regression's coefficients do not fit the alpha, beta, gamma fields:
it has six weather-and-lag terms, up to thirty hour-of-day terms, and an
energy ratio that scales its target
([`../../research/house-parameter-estimation.md`](../../research/house-parameter-estimation.md)
"What the method is").

## Open before authoring

1. **Which groups the word carries.** The fit produces only the load
   group. Either the word carries all groups, with the others still set
   by hand through the operator path, or it carries the fitted load model
   alone and the remaining groups stay where they are until each has an
   estimator. One in-force set with one id argues for all groups in one
   word.
2. **What RSWT is.** Today it is derived from forecast load through a
   quadratic drawn through three points (zero power at `−alpha/beta`, the
   intermediate point, the design-day point), and the two control modes
   use the result as three different things: the supply temperature the
   house needs, a buffer charge target in local control, and a penalty
   threshold on the top of the store in the FLO
   (`heating-system-design/mix-or-not/mix-or-not.md` "How RSWT is calculated").
   Once alpha and beta are replaced by a regression, the zero-power point
   `−alpha/beta` no longer exists. The word needs RSWT defined on its own
   terms: candidates are a directly estimated supply-temperature curve
   against load (fitted from hours of near-constant heat call at
   setpoint), kept separate from any charge target or penalty that
   control derives from it.
3. **The emitter temperature drop.** One field, with one meaning for both
   modes, estimated from data or set by hand. Today the SCADA scales
   `DdDeltaTF` with load and the FLO uses a constant.

Also open: whether house thermal mass leaves the FLO's parameters for the
energy prediction (the regression's lag terms stand in for it).

## Fit quality in the word

Each fit already produces coefficient standard errors, R², and the energy
ratio. The word carries these with the fit window (first and last day,
count of hours used after cleaning) and the method name and version, so a
reader of the in-force set can tell how it was made without the store.

## Build step

The words in sema, staging, under the sema gate; the on-disk files beside
the layout; the LTN loads the in-force set at boot.
