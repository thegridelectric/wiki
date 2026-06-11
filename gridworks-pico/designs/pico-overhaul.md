# pico-overhaul (design)

Status: Draft · Pass 0 · Updated 2026-06-11 · Linear: OPS-402

> What this is: a placeholder for the one large overhaul of
> gridworks-pico. **NEEDED FOR SCALING — and needed BEFORE SEPTEMBER
> 2026**: the code has gotten fractured enough that even provisioning
> firmware onto one more new pico is confusing, and the fall brings
> new installs. No details yet; a big TODO.

## The standing constraints (decided 2026-06-10/11)

- **No firmware downloads to picos, ever.** Firmware changes happen at
  bench/provisioning only — so the code must be provisioning-grade:
  good enough to ship and leave alone, with no OTA crutch to hide
  behind. (The retired OTA path is what let pico code quality go
  unexamined.)
- A pico loses its brain if power-cycled while writing flash, and bus
  power-cycles are routine by design (shared 5 V bus, pico-cycler
  relay). The overhaul includes **auditing every flash write**.
- Field history to beat: a couple of picos lost per season, each
  recovered by an in-person micropython reflash.

## TODO

Everything else. Scope this design before September 2026.
