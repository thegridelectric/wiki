# Unsorted (hub)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: a drop-box for things that show up mid-work that we
> deliberately don't think through yet. Items graduate to a real spoke,
> the cleanup queue, or the trash — they don't get designed here.

- [`pump-device-type`](pump-device-type.md) — Pumps need a type in the layout (2026-09-05); carries the measured Grundfos UPMS 20-78 F curve and stop machine (2026-09-06).
- [`hp-twin`](hp-twin.md) — the heat pump's digital twin under hp-boss; extends hp-boss-cleanup once heat pumps talk modbus (parked)
- [`command-interface`](command-interface.md) — how actors share what commands they take; sema holds the states but not the commands; candidate flat issue (2026-09-07)
- [`refactor-sieg`](refactor-sieg.md) — the sieg loop's first real exercise; carries the House0 rows of the hp-boss live test to uncomment (2026-09-07)
- [`relay-tests`](relay-tests.md) — what the hp-boss witness left unexercised, nine gaps each with its test (2026-09-07)
