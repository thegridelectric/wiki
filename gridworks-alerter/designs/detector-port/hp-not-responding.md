# hp-not-responding — heat pump commanded on, no power

Status: Draft · Pass 0 · Updated 2026-10-20

> What this is: the port of gwalert's `check_hp`
> (`alert_generator.py:1023`) as `HpNotResponding` (gwalert's alias
> `hp_on` reads as the opposite of what it means).

## gwalert today

Reads `hp-idu-pwr`, `hp-odu-pwr`, relay 5 (state `Scada`) and relay 6
(contacts closed), all by name; fires when both relays have been held
for more than 15 minutes, the power data is at most 15 minutes old, and
the power has not reached 1 kW (`v/1000`) in 15 minutes. Skips any
house whose alias contains `maple`; a house in `houses_with_monobloc`
(spruce, added by name when its layout arrives) has no indoor unit.
Relay 6 is read with no presence check, so a house without it raises a
`KeyError` that ends the rest of that cycle's checks.

The check fires only while the house is under its LeafTransactiveNode.
Since the move to the timeseries DB (2026-08-29) the relay table is
built from `readings` rows alone, and the only reading that yields the
`Scada` value the relay 5 gate requires is the `top-state` channel at
`LeafTransactiveNode` (`enum_decode.py`, `map_top_state_for_relay5`);
the failsafe relay's own RelayState channel reads `Energized` or
`DeEnergized`. A house in LocalControl, Admin or Dormant fails the gate
every cycle and prints "The HP should not be on". Observed at oak on
2026-10-20: relay 6 closed at 02:39 under LocalControl, the outdoor
unit stayed at standby power until 07:00, and the check printed that
line at every five-minute cycle (OPS-609). The port keys on the command
(relay 6 held closed), whoever gave it.

## The port

- **Reads:** which relays are the heat pump's scada-ops and failsafe
  relays from the stored layout's relay config, their latest states
  from `readings`; the heat pump's power channels and the HP model
  (monobloc or split) from the layout, never a house list; the layout
  also says whether the house has a heat pump at all.
- **Fires** when the heat pump has been commanded on for
  `hp_not_responding_s` (900, a setting) with power below `hp_on_kw`
  (1); **resolves** when power rises above it or the command ends.
- **Layout:** a house with no heat pump, or no power channel, has no
  `HpNotResponding`. No alias string matching.
- **Tests:** commanded on, no power, fires at the threshold; power
  returns, resolves; a monobloc layout reads the outdoor unit only; a
  layout without a heat pump is absent; a missing relay is absent, not
  an exception.

## Do this next

Start with a review of how the heat pump's behaviour is captured in sema:
the HP model, the relay roles, the power channels and the states the
scada reports. Find where each is stated in the layout word; a fact
not there is a sema word change and comes before the rule. Then
tests, rule, witness, shadow week, gwalert's check off.
