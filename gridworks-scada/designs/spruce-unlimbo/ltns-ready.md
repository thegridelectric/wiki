# LTNs ready (spoke)

Status: Draft · Pass 0 · Updated 2026-10-14 · Linear: OPS-392

> What this is: the spruce-unlimbo spoke that gets the LTNs running
> against the new scada code before the fleet is on the production
> broker, and settles what the LTN takes from the scada. Until launch it
> lives here; the LTN work that can wait moves back to spruce-settled
> (OPS-532) when this spoke closes.

## Launch note

The LTNs need to run before we are on the production broker. The first
job is to test locally, and use that test to find the minimal updates
to the LTN that get it working. The spoke text is worked in-process
with the spoke itself: the local run says what the LTN needs, and that
is what gets written here.

The split is roughly: what do we need so that the reports are acked
and the LTNs do not crash. The LTNs do not have to work well with their
FLOs yet. Once the launch part is done, this file moves back over to
spruce-settled with whatever LTN work can wait until after launch.

The LTN and the scada always run from the same code at launch. When the
fleet starts publishing to the rabbit broker, the cloud-box LTN gets the
cert and the matching code. So a heartbeat version change on the scada
branch is not a wire break to build around: the LTN runs on the laptop
from the same branch against the dev rabbit broker, and there is nothing
to build now.

The cloud LTN will decode several versions of a word one day, the scada
never will. That decoder arrives when the LTN moves out of scada into
gridworks-base, not before.

## The two FLOs

- **Maple.** A new FLO that uses the house's resistive elements and
  accounts for the wider COP variation of the Mitsubishi heat pump (last
  season maple ran a two-stage Samsung). Its parameters are not the
  current `flo.params.house0/007` shape; expect a `008` or a new word.
- **Spruce.** A FLO and a parameter word for the Nolan house; none
  exists today. What it optimizes over (the buffer-less plant, the
  time-of-use windows already on `gw.nolan.operational.params`) is the
  design question.

## What the LTN takes from the scada

Owned here once the two LTNs run, not before, because each question is
answered by what the running LTN actually reads:

- What each LTN needs that the layout and ops words do not carry, and
  whether `flo.params.house0` gets a new version for the House0 fleet or
  a Nolan twin for spruce.
- The strategy selector and sieg-loop facts the LTN reads
  (`../spruce-unlimbo/control-strategy-selection.md` decision 4).
- Whether `layout.lite` is reshaped once more or replaced by the raw
  layout + ops words (`publish-layouts-and-operational-params.md`).
  The LTN reads `BufferShortCycling`, `TotalStoreTanks` and `Ha1Params`
  off it; `AcceptsDispatch`, `ServiceMode` and `SeasonalStorageMode`
  come from `gw.house.operating.status` (`ltn/ltn.py:767-776`).

## What the scada takes from the LTN

- **The weather forecast.** The LTN relays gwwf's `gw.weather.forecast`
  to its scada over the existing LTN→scada pipe, and the scada stops
  pulling weather itself (gwwf `executor/delivery.md` "LTN relay is
  primary"; the scada keeps the last-received forecast on disk as the
  same word and falls back to the gwwf API only when the relay goes
  quiet). Until the LTNs run, the scada's interim pull from gwwf is in
  `../spruce-unlimbo/nolan-local-control.md`.

## The FLO boundary

The direction is FLO as a service: the LTN hands the FLO its parameters
as one serialized sema message and gets a sema message back, so the FLO
can run in another process or on another machine with nothing shared
but the words. Work on the LTN is judged by whether it moves toward
that boundary.

**Review `td/generalized-flo` against it.** The branch (off `dev`,
eight commits to 2026-10-02) swaps the gridflo optimizer for the generic
one in `optimal-flexibility` and rewrites most of `ltn/ltn.py` and
`tests/actors/test_ltn.py`. A first look, not yet a review:

- The LTN builds and bids in a child process and passes the parameters
  as bytes, which keeps a serialized boundary.
- The bytes are the optimizer's own `HeatPumpWaterTankParams`
  (snake-case fields, `model_dump_json`), not a sema word. Whether
  `flo.params.house0` is still built and reported, and what the audit
  trail of a bid is without it, is the first review question.
- `ltn/flo.py` on the branch is a stub typed on `FloParamsHouse0` that
  raises at construction.
- The branch and `jm/spruce-unlimbo` share no history since 2026-06-10
  and both rewrite `ltn/ltn.py` (the operating-status reads on one
  side, the optimizer swap on the other), so the review includes
  bringing the branch onto the launch line.

## The heat pump's electrical bounds

Two FLO inputs describe the heat pump's electrical envelope, and until
2026-10-14 neither reached the FLO from the house.

- **`HpMaxElecKw`** (`flo.params.house0`) is the heat pump's maximum
  electrical draw in kW; gridflo caps each hour's electrical input with it
  and scales the stability penalty by it. The house states this fact once,
  as `HpMaxKwEl` in `gw.operational.params` (9.66 at most houses, 10.0 at
  beech and maple); the scada copies it into `ha1.params`, which its own
  controllers read and which the LTN receives inside `layout.lite` and on
  every `scada.params` change. The LTN now copies `ha1.params.HpMaxKwEl`
  into `HpMaxElecKw`. Before, the gwsproto twin's class default of 9.66
  filled the field at every house, so the FLO planned against 9.66 at
  beech and maple while the scada's controllers used 10.0. gridflo's own
  copy of the type has the same 9.66 default; it has never fired, since
  the LTN always sends the field, and it stays for now.
- **`HpMinElecKw`** is the minimum electrical draw while running, in kW,
  negative to represent metered offsets at the lower bound. No layout or
  ops word states it; the LTN passes -0.5 from
  `actors/ltn/flo_tuning.py`, where every FLO input with no house source
  lives (the storage-loss percent, the per-step thermal caps, the two
  penalty families, the constant delta-T).

Cleanup, owned here: each `flo_tuning` constant is either a fact about
the house, which earns a field in `gw.operational.params` and flows
through `ha1.params` as `HpMaxKwEl` does, or a FLO tuning choice, which
stays with the FLO; one name per fact across the three words, so the
`HpMaxKwEl` / `HpMaxElecKw` pair converges when `flo.params.house0`
next versions.

## LTN code that scrapes where the layout answers

The LTN holds the full layout (`ltn_app.py:79`), so each of these is a
lookup:

- **House-available energy by channel-name scraping.**
  `get_house_available_kwh` (`ltn/ltn.py:1480-1512`) picks setpoint
  channels with `'zone' in x and 'set' in x`, derives the temperature
  channel by replacing `-set` with `-temp`, strips a six-character
  prefix, decodes every value with a fixed `/1000`, and skips `zone4` /
  `upstairs` by name. On a Nolan layout the replaced name matches no
  channel, so spruce contributes nothing; a temperature channel in
  another encoding is read wrong; and the skip is one house's special
  held in code. The lookup: each zone's primary circuit by
  `PrimaryCircuitPosition`, its `TempChannelName` and
  `SetpointChannelName` read through the channel registry, weighted by
  the zone's `KwhPerDegF`, with a zone that contributes nothing
  authored as `KwhPerDegF` 0. Test first: a Nolan layout with readings
  in their own encodings gives the right non-zero energy. The value
  feeds the FLO as `house_available_kwh`.
- **The dashboard's zone pattern.** `ltn/config.py:28-37` matches
  `^zone(\d)-(.*)-(temp|set|state)$` and
  `dashboard/channels/containers.py:107`, `:202` rebuild names from list
  order; the circuit's channel names give the same thing. Display only.
- **An orphaned setting.** `LtnSettings.seasonal_storage_mode`
  (`ltn/config.py:53`) is read only by a log line (`ltn.py:993`) that
  prints it in place of the value from the operating status.
- Nothing reads `Thermostat.ComponentId` or `ThermostatKind`
  (`thermostat-and-zone-control.md` "Thermostat chunk").

## Open

- Sequencing against `publish-layouts-and-operational-params.md`: the
  ops words freeze after the fleet runs them, and a FLO parameter word
  may want fields the ops words should own instead.
