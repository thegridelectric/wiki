# LTNs ready (spoke)

Status: Draft · Pass 0 · Updated 2026-10-05 · Linear: OPS-532

> What this is: the spruce-settled spoke that gets a maple LTN and a
> spruce LTN running on the new code, each with a FLO and the parameters
> it needs, and then settles what the LTN takes from the scada. Opens
> after the fleet runs under local control; the second segment of
> spruce-unlimbo's `layout.lite/013` work transfers here when its first
> segment closes (the transfer note is in that spoke).

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
