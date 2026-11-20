# Starter script for Rev C

Status: Draft · Pass 0 · Updated 2026-11-20

> What this is: the bench tool for the checklist. The Rev B script moves
> to `starter-scripts/archived/gw108_revb_test_code.py` and a new
> `starter-scripts/gw108_test_code.py` is written for Rev C from Joe's
> `app.py`, headed with a note that it is for Rev C.

## Done 2026-11-20

On `jm/gw108-revc` of `starter-scripts`, commit `c2021df` and the
follow-up with pin readback:

1. `git mv gw108_test_code.py archived/gw108_revb_test_code.py`.
2. Write the Rev C script. Keep the Rev B script's working choices
   (`smbus2`, the `api.tank_module` thermistor helpers) and take the Rev C
   pins, relay names and ADC placement from Joe's `app.py`.
3. Run it on spruce from the box's `~/experiments` clone at a pushed SHA.
   Then start the [bench checklist](bench-checklist.md) with native GPIO.

## Shape

- Module-level setup: GPIO mode and pin setup, expander clear and
  direction, mux, ADCs, DACs. Importable from a REPL, as Joe's is.
- One function per Rev C silk name (`set_valve_2`, `set_pump_1`,
  `set_zone_failsafe(n, state)`), reading pin state back where the board
  supports it.
- Readers: `print_zones()`, `valve_4_energized()`, `thermistor_f(n)`,
  `ct_volts(n)`, `measure_waveform(ct)`.
