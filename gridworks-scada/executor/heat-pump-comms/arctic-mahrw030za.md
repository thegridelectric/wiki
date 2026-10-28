Status: Draft · Pass 0 · Updated 2026-10-28

# Arctic MAHRW030ZA (elm)

What this is: how the scada talks to elm's Arctic R32 high-temperature
monobloc, through the dry-contact enable it uses now, with the wired
controller's settings that decide what the unit does while enabled, and
the Modbus path that comes later. Provenance tags are defined in
[`primary.md`](primary.md).

## The equipment

- **Outdoor monobloc MAHRW030ZA (BEH2)-R32** (layout node `hp-odu`):
  both compressors are outdoors; there is no indoor unit and no indoor
  control box, so the layout has no `hp-idu` node. Rated 75 °C outlet.
  [documented: manual Rev 2]
- **Wired controller** indoors, with its own on/off and the user and
  installer parameters below. [documented: manual Rev 2]
- **Circulating-pump output**, 240 VAC on field terminals 3 and 4: the
  unit can run the primary pump (unit side of the plate exchanger)
  itself, which is why elm's layout has no primary-pump relays.
  [documented: wiring page]

## Sources

In `heat-pumps/arctic-high-temp/` at the umbrella root: the R32 High
Temp Manual Rev 1 and Rev 2 (Rev 2 is the one read), the Modbus
register document, and `arctic-high-temp-modbus.md`, the register map
and the later Modbus plan.

## Call contact

The path elm runs on. The scada side (hp-boss, `hp-scada-ops-relay`,
the failsafe direction) is in
[`../control-hierarchy.md`](../control-hierarchy.md).

- **CN33** on the on/off board is the remote on/off input. Dry contact:
  the unit will not run while it is open and runs within its own
  settings while it is closed. [told: Arctic support, 2026-08-20] At
  elm the contact is `hp-scada-ops-relay` (Krida 6); the hp-failsafe
  relay (Krida 5, double throw) chooses between the scada's contact and
  the aquastat path. [field]
- The "add 240 VAC relay to convert to dry contact" note on the wiring
  page is terminals 1 and 2, the unit's backup-heater call output, not
  an input. [documented: wiring page]
- The unit starts about 65 s after the contact closes and its draw
  falls under 400 W about 60 s after it opens
  (`../heat-pump-signatures/startup-signatures.md` "Arctic MAHRW030ZA
  (elm)"). [field: 2026-10-26 to 28]

## Controller settings

- **Controller on/off** (long press, then OK). Our reading of "runs
  within its own settings when closed" is that CN33 enables a unit the
  controller has turned on, so the controller is left ON and never used
  to stop the unit. Unconfirmed (Open).
- **Mode** stays Heating. The unit's own outdoor-reset curve mode is
  documented as unstable, and the setpoint decision is ours anyway.
- **Heating setting temp** (user parameter, factory 47 °C) is the
  target the unit holds while enabled, with **heating system
  hysteresis** (factory 5 °C) the band below it. Set the target to what
  the store wants (`arctic-high-temp-modbus.md` argues for 75 to 80 °C
  water). The target is capped by **max water temperature**, installer
  parameter 17, factory 55 °C: raise that first, to what the store and
  pipework are rated for, then the setting. [documented: manual Rev 2]
- **Water pump working way** (user parameter, factory 2) with the pump
  interval and cumulative-run-time parameters govern the unit's own
  circulating-pump output on terminals 3 and 4; the value wanted is the
  one that runs the pump whenever the compressor runs and for the
  post-run period. The values are to be read off the controller and
  recorded here (Open). [documented: manual Rev 2]
- **Timer** off; the **Wi-Fi** app is not needed. Both can fight an
  external enable.
- **Electric backup** (terminals 5 and 6, 10 A) is not wired; the
  "eheat" start under user parameters stays untouched.

## Modbus later

RS-485 at 2400 baud, address by DIP switch SW2; register 2000 is
on/off, 2003 the heating setpoint. The dry contact stays the enable
even then, so a scada-side stop never depends on the bus. The register
map is `arctic-high-temp-modbus.md`.

## Open

Bench questions on the unit, each answered once and recorded above:

- With the controller OFF, does closing CN33 start the unit?
- After a power cut, does the unit come back ON at the controller or in
  standby? That decides whether a breaker trip at elm needs a visit.
  Test once by pulling the disconnect.
- Which sensor the hysteresis band acts on, inlet or outlet: not in the
  manual. Watch both on the controller's main screen against the
  compressor icon on the first runs.
- The water-pump parameter values as set.
- Whether the 6 min a call took to start on 2026-10-28 04:54 is a
  minimum-off timer, and what its length is.
