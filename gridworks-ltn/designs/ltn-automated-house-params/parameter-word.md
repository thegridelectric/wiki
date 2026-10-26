# parameter-word

Status: Draft · Pass 0 · Updated 2026-10-14 · Linear: OPS-531

> What this is: a spoke of [`primary.md`](primary.md). The sema words
> this design needs: the parameter set that comes into the LTN, and the
> in-force set exchanged between LTN and SCADA. It also settles which
> parameter groups a set carries and what required source water
> temperature (RSWT) means in it, because the word cannot be authored
> until that is decided.

## Do this next

Settle the five items under "Decisions for the human". Nothing is
authored in sema before then, and every new word goes through the sema
authoring gate with a registry search first.

## Today's path, as read 2026-10-14

The spoke's first draft named `ha1.params` as the SCADA's authored copy.
The code on scada `main` has moved on; this is the path now:

- **Authored home:** `gw.operational.params` on disk beside the layout.
  The house parameters sit in two sub-words, `heating.curve/000`
  (alpha, beta, gamma, the two RSWT anchors, `DdDeltaTF`, `MaxEwtF`) and
  `cop.curve/000`, plus three top-level fields (`HpMaxKwEl`,
  `HpTurnOnMinutes`, `LoadOverestimationPercent`). `FamilyParams` is a
  `oneOf` over `gw.house0.family.params` and `gw.nolan.family.params`.
- **Runtime twin:** the SCADA builds an `ha1.params` from those at boot
  (`actors/scada_data.py:160`) and sends it to the LTN inside
  `layout.lite` (`actors/scada.py:2185`). The LTN never reads the
  operational params file; its only source is that twin
  (`actors/ltn/ltn.py:784`).
- **Runtime change:** the LTN's `set_alpha` family of hooks sends a
  `scada.params` with a whole new `ha1.params`; the SCADA swaps its copy
  and persists each changed field as a `SCADA_*` environment variable
  (`actors/scada.py:827-851`). This is the in-force mechanism of the
  2025–26 season, and the one this design replaces.
- **Every generated operational-params file in `tlayouts/output/` has the
  same heating curve**: alpha 5.5, beta −0.10, gamma 0, anchors
  (1.5 kW, 100 °F) and (5.5 kW, 150 °F), `DdDeltaTF` 20, `MaxEwtF` 170
  (maple 145). No house is characterised in the authored file; the
  hand-set values of last season went in through the runtime path and the
  env vars.

## Who reads which field

| Field | SCADA readers | LTN / FLO readers | What it describes |
|---|---|---|---|
| `AlphaTimes10`, `BetaTimes100`, `GammaEx6` | `derived_generator` load forecast and the `−alpha/beta` RSWT anchor | `get_RSWT`; FLO load forecast | the house envelope |
| `IntermediatePowerKw/RswtF`, `DdPowerKw/RswtF` | `derived_generator` RSWT quadratic | `get_RSWT`; FLO | emitters: supply temperature the house needs per kW |
| `DdDeltaTF` | `derived_generator`, scaled with delivered power | FLO `ConstantDeltaT` | emitters: drop across them |
| `MaxEwtF` | hydronic, leaf ally, local control, sieg strat-protect | — | a plant limit on water temperature |
| `HpTurnOnMinutes` | leaf ally, local control | FLO | heat pump fact |
| `HpMaxKwEl`, `cop.curve` | — | FLO | heat pump facts |
| `LoadOverestimationPercent` | `derived_generator` | — | a control knob |

The thermal model is read by both ends: the SCADA forecasts load and
RSWT hourly for `heating.forecast`, and the LTN does the same for the FLO.
Whatever the fit produces, both ends evaluate it.

## Proposal

**Three kinds of thing are mixed in today's set, and the word follows
the kinds, not the file.**

1. **The house load model** — what the fit produces. A new word,
   family-free: the regression's named coefficients (intercept, ΔT,
   wind×ΔT, solar, previous-hour load, 4-h OAT mean, 4-h load mean),
   the optional hour-of-day terms as a list keyed by day kind and hour,
   the energy ratio that scales the target, and the fit record: method
   name and version, window first and last day, hours used after
   cleaning, R², per-coefficient standard errors. Replaces alpha, beta,
   gamma everywhere.
2. **The supply curve** — what the emitters need, hand-set until an
   estimator exists. A new word, family-free: supply temperature against
   load through three explicit points: the zero-load supply temperature
   (today the quadratic uses the OAT at which load is zero, `−alpha/beta`,
   as a water temperature; the physical value is the indoor setpoint, and
   the word states it), the intermediate point and the design-day point;
   plus the emitter drop at design load. Not in it: `MaxEwtF`, which is a
   plant limit, not a curve.
3. **Heat pump facts and control knobs** — `cop.curve`, `HpMaxKwEl`,
   `HpTurnOnMinutes`, `MaxEwtF`, `LoadOverestimationPercent`. Not house
   parameters: they stay in `gw.operational.params` and are not part of
   the in-force set this design exchanges. The COP terms and the two heat
   pump numbers are device facts that belong with the heat pump's
   device-type record once one exists.

**The in-force set** is one word holding the load model and the supply
curve by `$ref`, with a set id, a created stamp, and the source (fit or
operator). It is what the LTN accepts, publishes, and exchanges whole with
the SCADA. `heating.curve/000` and `ha1.params` retire from the path once
both ends evaluate the new words; `flo.params.house0` drops its parameter
fields and references the set by id.

**Per family: nothing.** The load model describes the envelope and the
supply curve describes the emitters; neither knows whether the plant has
a buffer, a sieg loop, a store tank or a slab. What is family-shaped is
what control derives from RSWT: a buffer charge target, a store-top
penalty, a slab target. Those derivations stay in the family's control
code, and the family params words (`BufferFullF`, `BufferChargeF`,
`SeasonalStorageMode`) stay where they are. Five families get one
thermal word, not five.

**Shared evaluator.** The SCADA's hourly forecast and the LTN's FLO input
both need to run the model forward 48 hours. One framework-free package
evaluates a load model and a supply curve from a weather forecast; the
SCADA's `derived_generator` and the LTN import it. That package is also
the piece the gwbase LTN picks up unchanged.

## Decisions for the human

1. **Groups in the set:** load model + supply curve only, heat pump
   facts and knobs stay in operational params. (Proposal above; the
   alternative is everything in one word with one id.)
2. **Coefficient shape:** fixed named fields for the seven main terms,
   a list for hour-of-day terms. The alternative, a list of
   `{Name, Coefficient, StdErr}` for every term, survives feature changes
   without a new version but validates nothing about the model's form.
3. **The supply curve's zero-load point** stated explicitly as the
   indoor setpoint rather than inherited from the load model.
4. **The emitter drop:** one field, the drop at design load, meaning the
   drop scales with delivered power (flow held constant). The SCADA does
   this today; the FLO's constant is the approximation that retires.
5. **House thermal mass** (`HouseAvailableKwh` in the FLO): the
   regression's lag terms stand in for it. Open; the FLO comparison in
   fit-on-the-box decides.

Also open, for fit-on-the-box: solar irradiance has no fleet source, and
the LTN needs a solar forecast to run the model forward. Whether the
weather bundle gains it, or the load model ships without the solar term
until it does, is decided there.

## Fit quality in the word

Each fit already produces coefficient standard errors, R², and the energy
ratio. The word carries these with the fit window (first and last day,
count of hours used after cleaning) and the method name and version, so a
reader of the in-force set can tell how it was made without the store.

## Build step

The words in sema, staging, under the sema gate; the on-disk files beside
the layout; the LTN loads the in-force set at boot.
