# no-store-flow — store pump on, no store flow

Status: Draft · Pass 0 · Updated 2026-10-16

> What this is: the port of gwalert's `check_store_pump`
> (`alert_generator.py:941`) as `NoStoreFlow`, only where a store pump
> exists.

## gwalert today

Reads `relay9` as the store pump relay by number, `store-pump-pwr` and
`store-flow` by name; fires when the relay has been energized for more
than 10 minutes (inline) and the flow (`/100`, inline) stays below 0.5
gpm. Same `max([])` risk as the distribution check. Assumes relay 9,
a store pump and a store flow meter.

## The port

- **Reads:** the store pump's relay from the layout's relay config by
  role, never by number; the store flow channel with its unit from the
  layout; latest states and readings from `readings`.
- **Fires** when the store pump has been commanded on for
  `store_pump_on_s` (600) with flow below `store_flow_min_gpm` (0.5);
  **resolves** when flow appears or the command ends.
- **Layout:** the fall's installs include houses with no store tanks and
  no store pump; for them this kind does not exist. The rule asks the
  layout, and a house without a store pump is absent, not logged.
- **Tests:** on and dry fires at the threshold; flow resolves; a
  layout without a store pump is absent; restart with the alert open.

## Do this next

Tests, rule, witness on a mocked layout with and without a store pump,
shadow week, gwalert's check off.
