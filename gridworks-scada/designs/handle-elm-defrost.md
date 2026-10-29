Status: Draft · Pass 0 · Updated 2026-10-29 · Linear: OPS-639
**EDD: yes** Verified when elm runs cold nights with the strategy on, the secondary pump stays off from the start of each Arctic defrost through the unit's restart, and the journal shows it.

# handle-elm-defrost

What this is: a secondary-pump strategy for elm that keeps the secondary
pump off for the whole of an Arctic defrost, chosen in the operational
params the way `SiegLoopStrategy` chooses the sieg loop's behaviour, so it
can be switched on and off while we experiment. The secondary pump then
plays the part a Siegenthaler valve at full keep plays in a sieg house:
during a defrost the heat pump takes its heat from its own small loop,
and the buffer is left alone.

**▶ Do this next: settle the open decisions below (Pass 1), then write the sema word.**

## Why

The defrost as the scada sees it is in
[`../executor/heat-pump-signatures/defrost-signatures/arctic-high-temp.md`](../executor/heat-pump-signatures/defrost-signatures/arctic-high-temp.md):
a ramp down, about 30 s near 300 W, 1–4.5 minutes at 1.1–1.7 kW with
leaving water at or below entering water, about 3 minutes stopped, then a
restart. hp-boss runs the secondary pump on hp-watch's reading of
`hp-odu-pwr` alone (`pump_wanted`, `gw_spaceheat/actors/hp_boss/hp_boss.py:317`),
with a 700 W on line and a 400 W off line for this unit. Across one
defrost the pump therefore goes off, on and off again. Through the
1.1–1.7 kW stretch it runs at full speed (6.7 gpm at 4.0 V) and sends
about 30 gallons of ~104 °F water into the top of the buffer, which works
against stratification. With six defrosts a cold night, that is a
recurring mixing event on top of the pump-speed question.

## The strategy

A new property on elm's family params (`gw.house0.no.sieg.family.params`),
proposed as `SecondaryPumpStrategy` with a new enum
`secondary.pump.strategy`:

| Value | Behaviour |
| --- | --- |
| `FollowHpPower` | today's behaviour: the pump follows hp-watch |
| `HoldOffThroughDefrost` | as `FollowHpPower`, except that a drop under the off line while the call is on holds the pump off until the unit has restarted |

The hold, for `HoldOffThroughDefrost`:

1. **Enter** when hp-watch goes `HpDetectedOff` while hp-boss has the call
   relay closed. A commanded off is not a defrost; the pump goes off as it
   does today.
2. **Stay off** through the 1.1–1.7 kW stretch, ignoring hp-watch's
   `HpDetectedOn`.
3. **Exit** on the restart: the first time power is above the on line
   after at least 120 s under the off line (the stopped phase). Then the
   pump follows hp-watch again.
4. **Time out** at 15 minutes after entry (the unit's 8-minute defrost cap
   plus the 3-minute stop, with margin), so a drop that was not a defrost
   never strands the pump off while the unit heats.
5. **Clear** when the call opens.

Each entry, exit and timeout is logged, and the hold is visible in the
journal so the experiment can line it up with `hp-odu-pwr`.

## Where it goes

- **Sema:** the enum and the family-params property, through the sema
  protocol (spec first, registry). Elm's family params today hold
  `KeepBufferFull` and `SeasonalStorageMode`; `gw.house0.family.params`
  holds `SiegLoopStrategy` (default `StratProtect`) and is the pattern.
- **tlayouts:** `elm_gen.py` sets the strategy; switching it is a regen
  and roll, no code change.
- **scada:** hp-boss reads the strategy at load and applies the hold in
  `pump_wanted` / `enforce_pump`. The hold is keyed on the unit's
  `DeviceType` (`ArcticMAHRW030ZA`) for its thresholds, beside `HP_TRAITS`
  in `gw_spaceheat/actors/hp_boss/sensing.py`.

## The experiment

Roll elm with `HoldOffThroughDefrost` for at least two nights with
outdoor air near freezing, then compare with `FollowHpPower` nights
(2026-10-27/28 are the baseline). Pass when, for every defrost:

- `secondary-flow` is near zero from the first drop under 400 W through
  the restart;
- the buffer's top temperature (`buffer-depth1`) holds through the
  defrost instead of falling;
- the defrost lasts about as long as on baseline nights (1–4.5 minutes at
  1.1–1.7 kW) and never reaches the 8-minute cap;
- no glitch or protection shows on the unit.

A defrost that runs longer with the pump held off means the unit was
taking real heat from the buffer, and the hold is costing defrost time.

## Open decisions

- Names: `SecondaryPumpStrategy`, `FollowHpPower`,
  `HoldOffThroughDefrost`.
- Whether the strategy belongs on `gw.house0.no.sieg.family.params` only,
  or on any family with a secondary pump.
- Whether `DEFROST_SIGNATURES` (`sensing.py`) gets an Arctic row for
  this. Its record is a draw and a watt line the draw falls under, and
  the Arctic's defrost sits above the off line for minutes, so the record
  shape may not fit it.
- When the Modbus reads (OPS-638) show 2110 bit 7 (four-way valve 1)
  during a defrost, whether the hold enters and exits on that bit instead
  of on power.
