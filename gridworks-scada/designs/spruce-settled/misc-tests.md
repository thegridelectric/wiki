# Miscellaneous tests owed (spoke)

Status: Draft · Pass 0 · Updated 2026-09-13 · Linear: OPS-532

> What this is: small tests that fixes have earned and not yet got.
> Each line names the code, the behavior to pin and why it was skipped
> when the fix went in. A line leaves when its test is in the suite.

## Owed

- **`DerivedGenerator.evaluate_strategy` compares kWh with kWh.** The
  buffer's usable energy (kWh, simulated layers through the return-water
  model) against the required-energy channel (Wh, produced by
  `compute_required_energy_wh`); the fix divides the channel value by
  1000. Pin: with a required energy just above the buffer's usable
  energy in kWh the advisory fires once; just below, it does not; a
  required energy expressed in Wh no longer trips it. Skipped at fix
  time (2026-09-13) because the method is guarded by an hourly clock
  and needs a fixture with `MaxEwtF` and a return-water model that
  converges; the test builds that fixture and drives the clock.

## Do this next

Write the `evaluate_strategy` test on the House0 sim fixture.
