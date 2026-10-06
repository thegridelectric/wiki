# Mix or not, and how hot is hot enough

Status: Draft · Pass 0 · Updated 2026-10-06

> What this is: the first draft of a whitepaper on two linked questions about
> a heat pump with thermal storage. Discharge: should the water going to the
> distribution system be mixed down to the required source water temperature,
> or sent as hot as the store has it? Charge: how hot does the store need to
> be, and did we overheat it in the shoulder season? Every declaration in the
> paper is a claim tested against fleet data; the claims register below is
> the paper's spine. Nothing here is settled yet.

## The question

John Siegenthaler's position is that the temperature going into the
distribution system should be regulated in a tight band. A full store is no
reason to send hot water upstairs; the hot water should be saved.

Our practice is to send whatever the store has. A heat call with hot water is
short. The water then sits in the emitters, keeps giving heat to the room, and
comes back much colder than it would in a constant heat call.

The design question: do we regulate the water temperature going upstairs, do
we not care, or do we prefer not to regulate it?

Required source water temperature (RSWT) is the supply temperature at which a
zone stays in near-constant heat call and holds its setpoint.

## Discharge: mix or not

### Arguments for not mixing

- **Storage.** Colder return water means a colder tank when the store is
  spent, so more usable energy per tank.
- **Hot water should not be spent warming return water.** The hottest water
  in the store was the least efficient to make. A mixing valve uses it to warm
  return water that the heat pump could reheat efficiently later. Letting the
  heat go into the building and the return come back cold avoids that.
- **Capacity.** A heat pump with a ceiling on leaving water temperature cannot
  deliver its full lift when return water comes back near that ceiling.
  Colder return water lets it deliver more heat at the same COP.
- **Cost and control complexity.** Remotely controllable mixing valves cost
  $500–800. A home-built three-way valve needs PID control, and injection
  mixing means balancing two pumps. Not mixing keeps the scada simple.
- **No single target.** RSWT is per zone, so steady state across zones needs
  per-zone hardware.

### Arguments that mixing is better, or at least not worse

- **COP does not depend on entering water temperature.** COP follows lift
  (leaving water temperature minus outside air temperature). The belief that
  cold return water improves COP does not survive the data seen so far.
- **A BTU in the store is a BTU.** Once the store is charged, no COP attaches
  to discharge. The only thing that can differ between the two modes is how
  much heat comes out of the water.
- **Heat below RSWT arrives either way.** Water sitting in the emitters keeps
  giving heat below RSWT in both modes. That heat should be counted, for
  example by modeling one more pass at the same ΔT (120 → 105 → 95 °F), not
  by treating water just under RSWT as worthless.
- **Return temperature without mixing is hard to predict.** It can be 80, 100
  or 120 °F depending on how long the water sat, and multiple zones make it
  worse. Mixing gives a consistent return and a slow, steady flow into the
  store that speeds up as the store cools.
- **Stratification.** Zone circulators at 4 gpm in fast bursts could
  de-stratify the store where a slow steady return would not.
- **Predictability for the FLO.** Predicting the return temperature needs the
  heat-call fraction, which itself depends on the supply temperature. A
  regulated supply breaks that circle.

### A third option: alternate the supply end of a series loop

John Siegenthaler notes that where a zone has many emitters in series, the
end of the loop that receives the hot water can be alternated to improve
comfort. This addresses the uneven comfort of hot water reaching one end of a
loop first, without regulating the supply temperature.

### What the discussion settled and what it left open

- **Mixing is once-through.** Mixed water goes out at RSWT and returns one
  ΔT lower, a single pass through the store at a slow rate. Unmixed water in
  near-constant heat call is the multi-pass case: it returns still hot and is
  used again.
- **The deciding quantity** is the tank temperature when the store can no
  longer heat the house, times the gallons. The question is which mode ends
  with colder water in the tank.
- **The thought experiment.** One full tank at 170 °F, heat pump off, two
  modes. Measure the time until a zone is two degrees below setpoint.
- **The floor used for "usable" moves the answer.** A store's stated capacity,
  and its cost per kWh, can shift by a factor of two with the choice of floor
  temperature. The paper states its floor and why.
- **Working consensus before the data:** not mixing is probably not a large
  storage win and probably not a loss.
- **Data, not simulation, is what will persuade.** A week with a valve
  against a week without is confounded by weather and occupancy. The first
  route is the natural experiment in existing data: periods of intermittent
  heat call against periods of constant heat call.

## Charge: how hot is hot enough

If sending hot water upstairs brings no real storage win, the cost of the
practice sits on the charge side. Every extra degree in the store was made at
a worse COP, and in the shoulder season the on-peak load is small.

For each shoulder day at a house the analysis takes:

- how hot the store was charged, and the lift it took;
- how much of that energy the on-peak period drew;
- what was left above RSWT when the heat pump came back on;
- the electricity the surplus cost, from the COP-versus-lift relation.

Surplus stored heat is not lost apart from standing losses, so the analysis
separates carry-over to the next day from true waste. If the store was
overheated, the remedy is a charging rule or better parameters, not a valve.

### The parameters that decide the charge

How hot the store is charged follows from four groups of house parameters.
The values below are what each house ran on in the 2025–26 season, read from
the journal DB (fields as stored; `AlphaTimes10` 98 is alpha 9.8).

| Group | What it sets | What the season's record shows |
|---|---|---|
| `AlphaTimes10`, `BetaTimes100`, `GammaEx6` | Forecast heating load | Set by hand and revised downward mid-season in four of five houses: beech 98 → 90 → 86, fir 140 → 75, maple 95 → 120 → 97 → 63, oak 93 → 76. Elm stayed at 70. |
| `DdPowerKw`, `DdRswtF`, `IntermediatePowerKw`, `IntermediateRswtF` | Required source water temperature as a function of load | Design-day power cut in every house (beech 9.8 → 8.6, elm 10 → 7, fir 14 → 7.5, maple 12 → 6.3, oak 10.75 → 7.6). Design-day RSWT moved repeatedly: beech 160 → 150 → 170 → 140 → 155, maple 180 → 200 → 170 → 160 → 145, oak 160 → 140, fir 160 → 150. The intermediate point is 1.5 kW in every house except beech from late January (3.6 kW). |
| `DdDeltaTF` | Temperature drop across the emitters | 20 °F in every house, all season, never changed. |
| `CopIntercept`, `CopOatCoeff`, `CopLwtCoeff`, `CopMin`, `CopMinOatF` | Heat pump COP | Carried in every `flo.params.house0`; not yet examined. |

The downward revisions fall between early December and late January. The
fall shoulder ran on the first, higher values in every house, with forecast
load up to twice what the later values give (fir). That is the period to
test first for an overheated store.

Spruce's set from January is identical to beech's.

### How RSWT is calculated

From a code read of the scada (`gridworks-scada`, branch `jm/spruce-unlimbo`)
and the FLO (`gridworks-innovations/gridworks-flo`, `main`). Last season's
houses ran earlier code, so each point needs checking against the commit a
house ran; the FLO's is recorded in `FloGitCommit`. Paths: `DG` is
`gw_spaceheat/actors/derived_generator.py`; `FPH` is
`src/gridflo/asl/types/flo_params_house0.py`.

Both modes share one construction:

- **Load.** `alpha + beta × OAT + gamma × windspeed × (65 − OAT)`, floored at
  zero (`FPH:150-152`).
- **RSWT from load.** A quadratic of delivered power against supply
  temperature is fitted through three points: zero power at `−alpha/beta`,
  the intermediate point, and the design-day point (`DG:714-738`,
  `FPH:102-111`). RSWT is that curve inverted at the forecast load
  (`DG:1057-1060`, `FPH:144-148`). At beech in January (alpha 9.0, beta
  −0.15) the zero-power point is 60 °F.

So RSWT is not measured anywhere. It is the forecast load read through a
curve drawn from two hand-set points and the load coefficients. A load
forecast that runs high gives an RSWT that runs high, by construction.

The two modes then diverge:

| | Local control (scada) | FLO |
|---|---|---|
| Load used for RSWT | Inflated by `LoadOverestimationPercent` first (`DG:1054`); 0 all last season | Raw load |
| Emitter ΔT | Scales with load: `DdDeltaTF / DdPowerKw × power` (`DG:1040-1046`) | Constant `ConstantDeltaT`, default 20 °F (`FPH:78, 127-128`); `DdDeltaTF` has no effect |
| Cap | None on RSWT | RSWT capped at 160 °F (`FPH:226-246`) |
| How RSWT acts | As tank thresholds: buffer "full" is the highest RSWT of the next three hours, limited by `MaxEwtF` (`hydronic/house0.py:597-601`); buffer "empty" is the same figure, or that minus ΔT in one mode, limited by `MaxEwtF − 10` (`hydronic/shared.py:233-241`) | As a soft cost only, when discharging with the store's top layer below RSWT (`flo.py:297`); exponential in the shortfall (`flo.py:373`) |
| Time window | Next three hours for the buffer; the highest RSWT over the coming on-peak hours for usable energy | Hour by hour |
| Usable-energy floor | Return temperature derived from RSWT, with a 10 °F ramp below it (`DG:1203-1255`) | Not applicable |
| On-peak hours | Hardcoded 7–11, 12–15, 16–19 for required energy (`DG:950-1038`) | From the price forecast |

The stored data agrees with the scada's ΔT rule: on 2026-01-05 beech's
`heating.forecast` shows `RswtDeltaTF` 23.0 at `AvgPowerKw` 10.35, which is
20 / 9.0 × 10.35.

Three consequences for the charge question:

- In local control, RSWT is a tank-temperature target, so an RSWT that runs
  high charges the buffer hotter directly.
- The emitter ΔT is 20 °F by parameter in both modes, at design-day power in
  the scada and always in the FLO. Claim 2 tests that number.
- The same word means different things in the two modes: a supply
  temperature the house needs, a buffer charge target, and a penalty
  threshold on the top of the store.

### Where the record is

All of the following are in the journal DB (`gridworks.messages`), 2025-10-01
to 2026-04-30 checked. The S3 eventstore was not examined.

| Word | Sender | What it carries for this analysis | Coverage |
|---|---|---|---|
| `flo.params.house0` | LTN | The whole parameter set for each FLO run: the four groups above, the outside-temperature, wind and price forecasts used, the initial store temperatures and thermoclines, `ConstantDeltaT`, the RSWT penalty settings, `FloGitCommit` | 14,868 messages. Present only while the FLO ran: fall to about December 8, then from March (oak from December 23). No FLO parameters exist for mid-December to early March in beech, elm, fir or maple. |
| `layout.lite` → `Ha1Params` | Scada | The scada's own copy of the load and RSWT groups (`ha1.params`), plus `MaxEwtF`, `HpMaxKwTh` and `LoadOverestimationPercent` (0 throughout) | All season, every house. This is the only parameter record for the winter months the FLO did not run. |
| `heating.forecast` | Scada, hourly | 24-hour arrays the scada computed from its parameters: `AvgPowerKw`, `RswtF`, `RswtDeltaTF`, with the `WeatherUid` of the forecast used | 26,979 messages, every house (spruce from January 23). |
| `weather.forecast` | Scada, hourly | The weather forecast behind each `heating.forecast` | Same count, paired by `WeatherUid`. |
| `report.event` | Scada | Measured supply, return and flow, tank and buffer temperatures, zone temperature, setpoint and heat call, and the scada's own `required-energy` and `usable-energy` channels | All season. |
| `scada.params` | LTN and scada | Changes to scada thresholds such as `BufferEmpty` | 8 messages, March 3–5 2026 only. |

No FLO output (plans or bids) appears in the journal under a parameter,
forecast, bid or contract type name.

The LTN and the scada each hold their own copy of the parameters and the
copies were edited separately: on 2025-12-31 the LTN at beech sent
`DdRswtF` 150 while the scada's layout held 170.

### A first comparison: beech, 2026-01-05

The scada's `heating.forecast` for the afternoon of that day gave `RswtF`
162–177 °F, `AvgPowerKw` 7.7–10.4 and `RswtDeltaTF` 17–23 °F. The measured
day (first look below) had the main zone at its 68 °F setpoint all day, in
constant heat call for 14 hours on supply water of 130–156 °F, delivering
3.9–7.0 kWh per hour to distribution. On this one day the scada's RSWT sat
20–40 °F above a supply temperature at which the house held setpoint, and
its forecast load ran above measured distribution energy. This is a lead
with the same unit caveats as the first look, not a result.

## Claims register

Every declaration the paper makes is tested against data from all houses
before it stands.

| # | Claim from the meeting | Test against data | Status |
|---|---|---|---|
| 1 | COP depends on lift, not on entering water temperature | Repeat George's plot per house and per heat pump model | George's plot only; I have not seen which house |
| 2 | Steady-state ΔT across distribution is about 20 °F | Flow-weighted ΔT in constant-call hours, by supply temperature, every house | Doubtful; see above |
| 3 | Shorter heat calls return colder water | Return temperature against heat-call fraction at fixed supply temperature | Not visible on Jan 5; needs low-call days |
| 4 | Burst return temperature is close to random (80–120 °F) | Spread of return temperature by heat-call fraction; Thomas's scatter, per house | Thomas's scatter only |
| 5 | Bursts do not overheat the house | Room temperature overshoot above setpoint against supply temperature | Joe's table and George's plot, beech only |
| 6 | LGs lose capacity when return water is 150–155 °F | Heat output against entering water temperature when leaving water is at its cap | Untested |
| 7 | A 100 °F return instead of 120 °F raises usable store by about 30% | Arithmetic on actual charged tank temperatures | Depends on top temperature: 33% at 180 °F, 40% at 170 °F |
| 8 | Water below RSWT still delivers useful heat | kWh delivered and room temperature trend in hours with supply below RSWT | Untested |
| 9 | Fast burst flow de-stratifies the store | Tank depth temperatures during bursts against steady draw | Untested |
| 10 | The 11 AM drop in heat calls at beech is solar gain | Compare sunny and overcast days at the same outside temperature | Untested; Thomas offered a cooler store as the alternative |
| 11 | We charged the store hotter than on-peak needed in the shoulder | Per shoulder day: charge temperature, on-peak draw, surplus above RSWT, COP cost | Untested; this is the charge half |
| 12 | Alternating the supply end of a series-emitter zone improves comfort (Siegenthaler) | Needs per-emitter or per-room temperatures along a series loop | Probably no data in the fleet |

The "see above" in claim 2 points to the first look in the next section.

## First look: beech, 2026-01-05

A throwaway look at one day, pulled from the journal DB (`report.event`,
midnight to midnight ET). It is a lead, not a result: units were inferred
from value ranges (temperatures °C×1000, flow gpm×100), not decoded through
sema, and a zone counts as calling when its whitewire power is above 20 W.

| Hours | Count | Flow-weighted supply | Flow-weighted return | ΔT |
|---|---|---|---|---|
| Zone 1 calling ≥95% of the hour | 14 | 145 °F | 125 °F | 20 °F |
| Zone 1 calling 60–95% | 10 | 164 °F | 136 °F | 27.5 °F |

- **The day has no hours of infrequent heat call.** The lowest hourly
  heat-call fraction is 61%, so the water never sits upstairs long enough to
  come back cold.
- **Return follows supply.** In the intermittent hours the return is warmer
  (136 °F), not colder, because the supply was hotter.
- **The heat pump ran in eight of the ten intermittent hours**, so that
  return water was not going to the store.
- **Steady-state ΔT is not a flat 20 °F.** Within the constant-call hours it
  rose with supply temperature:

| Supply temperature | ΔT |
|---|---|
| 130–138 °F | 15.5–17.5 °F |
| 144–156 °F | 17.8–23.7 °F |

Near RSWT, where a mixing valve would hold the supply, beech shows about
16–17 °F. The storage argument for not mixing needs days this one does not
provide: a hot store in milder weather with infrequent heat calls.

## Open

1. **Scope of the data.** Proposed: the 2025–26 heating season, every house
   with distribution supply, return and flow channels.
2. **Series emitters.** Does any zone in the fleet have emitters in series
   with a temperature sensor at more than one of them? Claim 12 has no test
   without one.
