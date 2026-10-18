# hp-not-responding — heat pump commanded on, no power

Status: Draft · Pass 0 · Updated 2026-10-16

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

Find in the layout word where the HP model and the relay roles are
stated (if the model is not there, that is a sema word change,
raised first); then tests, rule, witness, shadow week, gwalert's check
off.
