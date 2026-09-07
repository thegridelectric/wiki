# Krida retirement → board-generic relays (spoke)

Status: Draft · Pass 0 · Updated 2026-09-01 · Linear: OPS-392

> What this is: execute the scada half of the relay decommission whose
> sema half shipped 2026-07-03 (`relay.control.config/000` replaces
> `relay.actor.config` — `replaced_by` stamped; board-generic thin
> per-relay components `i2c.relay.component.gt` / `gpio.relay.component.gt`
> resolve RelayName/GpioName against the board record, the single source
> of physical address). Estimate on OPS-392; runs at the end of the
> command_node.py review section, after the tree matrix.

## Why now

House0 sim-green (the single scada focus) is blocked on it: commanding a
House0 relay reaches `relay.py`'s dead Krida multiplexer round-trip.
There is no route to the merge gate's "both cases work" that doesn't
either do this or revive the multiplexer against the recorded direction.
It also dissolves `actuator_config`'s false cast (one config shape, no
dispatch) and decouples family from board: a House0 with a Gw108 board
becomes a pure layout fact.

## Already landed (the ground this builds on)

- **The sema vocabulary is complete — no sema round needed.**
  `relay.control.config/000` + thin components (sema `fae8d27`,
  2026-07-03); the board capability words reshaped 2026-07-09
  (`i2c.relay.capability`, `i2c.expander`: per-relay expander-relative
  position, board carries addressing — fixed `I2cAddress` for gw108,
  `AllowedI2cAddressList` for krida DIP switches; deployment's chosen
  address on the component's `I2cAddressList`, index-aligned).
- **`KridaDoubleRelayBoard16` has its `gw1.scada.device.type.gt`
  record** (`gwsproto/data_classes/device_types/scada_krida.py`): the
  two-board GridWorks panel is ONE device; basement markings
  `Relay1`–`Relay32` are the RelayNames; the first-bank inversion
  (marking 1 → pin 7, …, 8 → pin 0) is declared pin data. The mux
  already resolves pins from this record (scada `ba6c6e65`), and the
  tlayouts gen emits it into each House0 layout's `DeviceTypes`
  (tlayouts `d75cae0`).
- **Functional relay ShNode names** landed pass-one (scada `4182d88c`,
  2026-07-09; krida board position in `RelayIdx` — which the new
  per-relay components replace with `RelayName` against the board).
- The nolan/gw108 case already runs this model end-to-end
  (`i2c.relay.component.gt` + `relay.py` resolving `RelayName` against
  the board) — House0 is the migration, not the invention.

## The work

1. **House0 fixture pair regenerated** with per-relay
   `i2c.relay.component.gt` (RelayName against the board's `I2cRelays`
   map — the Krida board record must carry that map, mirroring the
   Gw108 pattern). Unblocks the House0 tlayouts generator TODO (it
   still points at the deleted `house0-layout.json`).
2. **`relay.py` reworked to one actuation path** — resolve RelayName
   against the board, write via `I2cBus`; delete the dead multiplexer
   round-trip (`_actuate_and_defer_report`) and `relay_multiplexer`
   lookups.
3. **Remove `i2c_relay_multiplexer` actor + `i2c_relay_board`**; the
   multiplexer node leaves the layout in the same regen;
   `H0N.relay_multiplexer` retires in tandem.
4. **Retire gwsproto `I2cMultichannelDtRelayComponent` +
   `RelayActorConfig`**; `actuator_config` gets the honest single
   config shape.
5. **`I2cBus` reply-to** (prerequisite for item 2's "write via
   I2cBus"): the bus actor replies `I2cResult` to the REQUESTER via
   `Header.Src` (today it goes to `primary_scada`), so a relay
   confirms its own actuation by `TriggerId`.

**The House0 010v nodes migrate to per-output components here.** Two
0-10V mechanisms exist and only the gw108 one has code: the DFR modules
are driven through the `zero-ten-multiplexer` node holding one
`dfr.component.gt` with all three outputs in its ConfigList. Per-output
components there need the outputer to resolve its own module and the
multiplexer actor retired, the same shape as the relay side, so the
per-output word (vendor-free name, `zero.ten.output.component.gt`
proposed, linking field `ModuleComponentId`), the parent rename off the
vendor name, the fixture surgery, House0 axiom 10's ComponentId clause
and House0's ComponentBinding all land in this shift together (decided
2026-09-04). Not needed for the command-tree matrix: House0's shape
already puts the nodes in the tree.

## BoardBusList / layout-wide BusList (added 2026-09-02)

The bus list today lives on `gw1.scada.device.type.gt` as `BusList` —
a board-scoped fact with a layout-scoped job. Direction: rename the
device-type field **`BoardBusList`**, add a **`BusList` directly to the
layout words**, and an axiom that the layout's BusList lines up with
the union of its board device-types' BoardBusLists. This is also where
the bus-actor↔board bijection (required conditionally in ALL non-sim
words) gets its footing: bus actors pair with layout BusList entries.
Belongs in this chunk because the board record and its consumers are
already being reworked here.

## Krida board node (added 2026-09-02)

The gw108 board gets its equipment ShNode now (`gw108`, NoActor,
ComponentId → the board record — the board joins the node world like
hp-odu). The krida board's node deliberately WAITS for this chunk: the
House0 board story is rebuilt here anyway, so its node + record shape
land with the migration, not before. Also landing here: the hardware
realization interface the alt-nolan thought experiment defines (see the
hardware-decoupling section of `layout-word-axioms.md`) converges only
after this chunk — post-retirement, EVERY relay is a thin component
against a board record, so "which board" becomes one config axis.

## Gate

Suite green on both fixtures + `sema validate` on the regenerated
House0 pair. EDD bar (bench/box boot) before the fleet regen ever uses
any of it — real House0 boxes stay on their deployed artifacts until
the coordinated dev-wave regen.
