# Krida retirement (spoke)

Status: Draft · Pass 0 · Updated 2026-09-11 · Linear: OPS-392

> What this is: the scada half of the relay decommission (per-relay thin
> components against a board record; the sema half shipped 2026-07-03),
> and the record of the admin panel and command-reply work that came
> first because the panel shares the one word,
> `scada.control.capabilities`. Rung 1 (the panel on Nolan) and the
> reply path are in; rung 3 (the decommission) is the critical path for
> maple and beech and is why this spoke is first in the hub's list.

## ▶ Do this next: close the spoke

Rung 3 is witnessed (item 2 below). Next, in a fresh session: land the
pending scada commit (eGauge `debug` fix + pico params twins at 100,
suite 520 green), then the close-down: components.md and
control-hierarchy.md to present tense for the one actuation path and
per-relay confirmation, the Open items routed (rung 2 and the refusal
paths to `../../../command-surface.md`; interior-node acks and the
GPIO name branch to a flat Linear issue; the gwsproto multichannel
retirement to `correct-house0.md`; BoardBusList to
`layout-word-axioms.md`), this file deleted and the hub's spoke list
and the six files naming it fixed. Before any new beech window: a
sema-authored beech generator from `tlayouts/gen_beech.py` (the
window pair derived from the House0 fixture ran simulated tank
modules and a foreign hubitat on the real box), and the beech unlimbo
venv rebuilt or pulled past the eGauge fix.

### The RelayEnergizedLevel wave and the rung-3 witness (done)

Rung 3's five items are built on `jm/spruce-unlimbo` (`1a7a41d1`,
2026-09-10 evening, not yet pushed): both House0 fixtures carry a Krida
`scada.board.component.gt`, a `krida` node, an `i2c-bus` node and one
`i2c.relay.component.gt` per relay; `relay.py` has one I2C path; the bus
actor drives a PCF8575 as one port word (`SimPcf8575` in the sim
driver); the multiplexer actor and every reference are gone;
`tests/actors/test_relay_i2c_house0.py` proves all thirteen relays
resolve on both fixtures and vdc-relay energizes low and reports. Suite
516 passed.

The survey found the Krida panel is **active-low** (the multiplexer's
private enums: Energize = 0; power-on all-high is every relay off) while
the gw108 drives high, so the board record gained a required
`RelayEnergizedLevel` (sema, same evening, staging in place; axiom 5
`RelayEnergizedLevelRange`) and the relay actor translates its logical
pin value to the board's level at the write and the readback. The gw108
rev B driver is an NPN low-side switch with a 100k base pull-down
(`signal_relay` module, `gridworks-hardware`), so a floating pin is off
there too; rev C keeps active-high.

Next, in order:

1. ✅ DONE (sema `7d58bd1`, tlayouts `c4c026a`, scada `1a7a41d1`,
   2026-09-10; closure registry byte-equal to the snapshot; kept here
   until canonized into executor) **Land the sema commit, then the
   tlayouts half of the wave** (needs a
   clean sema checkout): add `"RelayEnergizedLevel": 1` after
   `SupportsPinReadback` in
   `src/tlayouts/device_types/gw108.revb-gw1.scada.device.type.gt-000.json`
   and `0` in `scada.krida-…json`, run `scripts/regen_sema_snapshot.sh`,
   tlayouts tests, then copy the snapshot registry into the scada
   closure (`packages/gridworks-scada-protocol/sema_closure/registry.yaml`)
   and run the conformance test. Then the scada commit.
2. ✅ DONE **Witnessed on beech (2026-09-11, Verified · Reviewed
   2026-09-11@1a7a41d1).** `experiments/2026-09-10-beech-krida-witness/`:
   a window scada on the real box, admin took zone1-down (relays 17 and
   18 on the second Krida) and made a heat call; every dispatch acked
   within two seconds and read back; the port word on the bus went
   `0xff` → `0x3f` → `0xff`; the Caleffi box started the dist pump 32 s
   after the call (`dist-flow` 0 → 196–200, return water 155.7 → 161.2 F)
   and stopped it within ten seconds of the release; the deployed scada
   came back with both port words as before. Nine of nine, on the dev
   rung the evening before and again that morning. Pump power was not
   witnessed (the window's eGauge driver produced no reading; a driver
   fault, the box reaches the meter). Side findings, not this rung's:
   the pico-cycler rebooted the vdc-relay every 65 s because the
   fixture's simulated tank picos flatline on a real box, and beech's
   real tank picos post a `TankModuleParams` the current word rejects
   (older firmware).
3. **GPIO relays onto the config-driven FSM.** `Relay.initialize_fsm`
   still matches node names for `gpio.relay.component.gt`; the
   `EVENT_ENUM_BY_NAME` / `STATE_ENUM_BY_NAME` maps now carry every
   relay vocabulary, so the name branch can go. Separate change.
4. **The real House0 fixture is `sema validate`-invalid for reasons
   older than this rung** (old meter `Exponent`, channel
   `InPowerMetering`, hubitat shapes; 1392 errors before and after the
   surgery). That is `correct-house0-tlayouts.md`'s; the sim fixture
   validates clean.

**Item 4 of the old list (retire the gwsproto multichannel component and
`RelayActorConfig`) is blocked by the closure**, not by scada: the
vendored closure registry carries `i2c.multichannel.dt.relay.component.gt:004`
and `sim.relay.component.gt:000` (whose ConfigList is
`relay.actor.config/003`), the House0 word's Components union lists the
multichannel word, and the conformance test requires their twins. Scada
stops using them in this rung; the twins and `LayoutLite.I2cRelayComponent`
retire in the sema wave that drops them from the House0 word, with the
House0 `BoardResolution` axiom (mirror of Nolan axiom 2).

Then:

- **Interior command nodes handle their relays' acks and nacks.** With
  `ea3365b5` every relay answers its boss on take or refusal; five-v-boss
  listens (`process_cycler_reply`), hp-boss and the pico-cycler do not:
  hp-boss logs a relay's `gw.dispatch.ack` as an unexpected message
  (witnessed on the real house, experiments `42f8382`, boot log
  10:22:33). Each takes the ack as confirmation of the step it waits on
  and the nack as its failure, with a test per node that drives the
  relay's reply through the boss.

Rung 2 is an Open item below.

**Rung 1 witnessed on the real house (2026-09-08, Verified ·
Reviewed 2026-09-08@ea3365b5).** `gwa watch spruce` from the laptop
against a window scada on the spruce gw108
(`experiments/2026-09-08-spruce-admin-panel/`): the twenty relays, the
cycler and hp-boss rows and the DAC rendered; Reboot picos cycled the
vdc-relay twice more after the boot cycle and the real picos re-POSTed
7 to 9 s after each close; the secondary pump and the iso valve were
each driven from their rows and `secondary-flow` followed within a
snapshot; the DAC moved pump speed. One 0x21 expander reset happened
under CloseValve with the pump coil energized and cost no output.
hp-boss was not exercised (the Samsung ignores the call contact).

The reply path is in (2026-09-08): every command node acks on take and
nacks Busy / UnknownEvent / OutOfRange / NotMyBoss, one test per actor
in `tests/actors/test_dispatch_replies.py`; the panel toasts one line
per answered command. The admin-scada command vocabulary (the ack/nack
pair, `analog.dispatch`, the command interface pair and their enums) is
published; `scada.control.capabilities/001` is the one still staging
(`sh-node-actor-partition/staging-words-on-prod.md`).

Two things to know about the panel: rows take state from
`single.machine.state` (snapshot `LatestStateList` plus the live
forward), and every row shows `?` until its node's first state report
arrives. A relay owned by an interior node (`vdc-relay`,
`hp-scada-ops-relay`) shows state with no action; the cycler and
hp-boss rows carry those commands. The rows-versus-vocabularies strain
this leaves (a row with no interface declares no state type) is in
`../../../command-surface.md` "Rows and vocabularies"; it goes with
rung 2.

## Rung 1, landed (2026-09-07)

The smallest change that makes `gwa watch` render and drive a Nolan
scada, with the word shaped once: per command node. No layout-word
edit, no relay.py rework; those are rungs 2 and 3.

1. **Sema.** Staging enum words `turn.hp.on.off`, `hp.boss.state` (no
   `gw1`), `pico.cycler.state`; new types `gw.command.interface/000`
   (ActorName, EventType, StateType, Commands) and
   `gw.command.transition/000` (`{Event, ToState}`).
2. **Word, in place.** `scada.control.capabilities/001` dropped
   `I2cRelayComponent` for `CommandNodes` and `CommandInterfaces`.
   Axiom 4 is the cover rule read off handle prefixes: an interface for
   every relay or command node whose Handle does not extend a command
   node's Handle. Not in the tlayouts closure, so no snapshot wave.
3. **Scada projection.** `Scada.control_capabilities` builds the cover
   from the layout's live handles: relays from their own config (thin
   component on Nolan, Krida config list on House0), hp-boss and the
   pico-cycler from `Scada.COMMAND_NODE_INTERFACES`. Relay and
   command-node `single.machine.state` is forwarded to the admin link.
4. **gwadmin: one table.** Rows from `CommandInterfaces`; state is the
   node's state name; the cycler and hp-boss are rows with their own
   vocabulary. The hp-boss rewrite pair, `relay_idx`, the reboot button
   and its `p` binding are gone; the DAC send uses the row key.
5. **Tests.** `test_control_capabilities_on_nolan` green with the two
   interior rows and the two owned relays; the cycler and dispatch-reply
   tests drive the row's command; rejecting tests per axiom in
   `tests/named_types`.

Rung 1 estimate: 6h (4–9). Rungs 2 and 3 are estimated on their own
rows when they start.

## Open after rung 1

- **Relays under sieg-loop (House0 with the loop in use).** A node that
  commands actuators is a command node, so sieg-loop belongs in
  `CommandNodes` even though it takes no event command today; rung 1
  leaves it out, lists the two loop relays under it with interfaces the
  cover axiom requires, and an admin dispatch to them is refused by the
  immediate-boss check. Not needed for Nolan; sieg-loop's entry and its
  vocabulary belong to sieg-semantic-harmonization (OPS-400).
- **`Scada.COMMAND_NODE_INTERFACES`** is the hand-map rung 2 retires:
  the hp-boss and pico-cycler vocabularies live there until the layout
  word carries a per-node command interface.
- The gridworks-admin executor's "capabilities contract" Open item (the
  Krida field) is resolved by this rung and wants its rewrite; that
  domain is edited under its own claim.

## Decisions (2026-09-07)

- **The per-node entry is a new word, `gw.command.interface`**, not
  `relay.control.config` reused: that word requires WiringConfig and has
  a relay's two-event shape. Its `{Event, ToState}` pair is the named
  type `gw.command.transition`, because the sema spec forbids axioms
  reaching into inline objects.
- **No ChannelName on the interface.** Admin finds a node's state channel
  as the `ControlChannels` entry about that node; a copy on the interface
  would only be a field to keep in agreement.
- **Axiom 4 is the cover rule, from the handles.** The scada executor
  ("capabilities = the cover") says an interior node keeps its subtree
  and the operator commands the heat pump through hp-boss, never the
  relay. So the interface set equals the nodes whose Handle is
  `<root>.<Name>`, read off `RelayNodes` and the new `CommandNodes`;
  `vdc-relay` and `hp-scada-ops-relay` keep their state rows and are
  commanded through the cycler and hp-boss. DacNodes take an analog
  value and carry no interface.
- **The capabilities list is per command node, not per relay**
  (option 1, chosen over a relays-only first cut that would reshape the
  word twice). Rung 1 carries the pico-cycler and hp-boss entries and
  the enum words they need.
- **One table in the panel.** The command interface word grows to
  cover interior command nodes, but the TUI keeps a single relay table
  and lists the pico-cycler and hp-boss IN it, as rows beside the
  relays, each with its own vocabulary (`reboot.picos`,
  `turn.hp.on.off`) and state. No separate command-node widget; the
  Reboot picos button becomes that row's action. The operator sees one
  list of "things I can command" whatever kind of node executes it,
  which is what the capabilities cover is (`executor/
  control-hierarchy.md` "Set of command trees = control regimes;
  capabilities = the cover"). A bit of hard-coding on the UI side to
  bunch rows in that table (an interior node next to the relays it
  owns, by name) is fine; it is presentation, and the word stays a
  flat per-node list.

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

## Rung 3: the relay decommission (the original krida-retirement work)

This is what keeps House0 from running the way Nolan does. Both House0
fixtures still carry one Krida `i2c.multichannel.dt.relay.component.gt`
and the `relay-multiplexer` node; the `i2c_relay_multiplexer` actor still
exists; `relay.py` has two actuation paths, and the Krida one
(`_krida_actuate`) sends a pin event to the multiplexer and never gets a
report back, so a House0 relay's boss sees no confirmation. `conftest.py`
runs the live pair on the Nolan layout only. The ordered plan is the
"Do this next" above.

Findings from the 2026-09-10 survey that shaped it:

- **The two boards' expanders speak different bus protocols.** gw108 is
  TCA9555 (addressed output, input and configuration registers); the
  Krida panel is PCF8575 (one quasi-bidirectional port, written and read
  as a word, no configuration register). `relay.py`'s I2C path, the bus
  actor's expander init and guard, and `SimTca9555` were all written for
  the TCA9555. Hence `ExpanderType` on the board record.
- **The bus actor picks fake silicon from the board record only** (never
  a runtime flag), so the House0 sim fixture needs a simulated Krida
  value in `gw1.sim.device.type`. Both House0 fixtures run actors in the
  suite (`test_hp_boss` runs all three pairs).
- **Krida addresses are field-chosen.** The record's expanders carry
  `AllowedI2cAddressList` and no `I2cAddress`; the chosen pair lives on
  the board component's `I2cAddressList`, index-aligned. The relay and
  bus actors read only the fixed address today.
- **The regenerated Nolan fixture differs from the scada copy** by the
  2026-09-09 spruce changes (secondary-pump rename, the fancoil, floor1
  and pipes1 modules), so the scada fixtures are hand-patched for now;
  syncing them with the generator is `correct-house0-tlayouts.md`'s.

✅ DONE **`I2cBus` reply-to**: the bus actor replies `I2cResult` to the
requester via `Header.Src` (`actors/i2c_bus.py`), so a relay can confirm
its own actuation by `TriggerId`.

The 0-10V per-output shift and the tlayouts regen of the House0 pair are
spokes of their own (`house0-zero-ten-outputs.md`,
`correct-house0-tlayouts.md`); rung 3 is relay-only.

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

## Known gaps

- **Admin coverage is Nolan-only.** `tests/actors/test_admin_on_nolan.py`
  and `test_admin_reboots_picos.py` cover the Nolan pair; the House0
  admin cases in `tests/test_misc/test_admin.py` are commented out and
  carry House0 incidentals. The House0 twin is spruce-settled's
  ([OPS-532](https://linear.app/gridworks/issue/OPS-532)).
- What a Nolan admin **should show** is partly different in kind: opto
  heat-call states, learned setpoints + SetpointPhase per zone, gw-temp
  channels; observation surfaces House0 admin doesn't have.

## Definition of done

Rung 3's five items, the House0 fixture pair regenerated and validating
(`sema validate`), and the suite green on both fixtures with House0
relays commanded through the same one actuation path as Nolan's.

## Gate

Suite green on both fixtures + `sema validate` on the regenerated
House0 pair. EDD bar (bench/box boot) before the fleet regen ever uses
any of it — real House0 boxes stay on their deployed artifacts until
the coordinated dev-wave regen.

## Open

- **The governance-dial altitude (2026-08-11):** a second admin mode
  where the circuit machines stay awake and admin issues
  `SetGovernance` per circuit (`StatRules | Off |
  Thermostatic(+setpoint)`) — safety by construction (raw relay admin
  can express the cold-water mistake; governance admin cannot), and
  the journal records intent, not pin flips. Raw relay mode remains
  for bring-up. Model:
  `zone-relays-and-thermostat-model.md` "Admin: two altitudes".
- Whether learned-setpoint/SetpointPhase display belongs in admin or
  stays a derived-channel/monitoring concern.

- Does the interface live on the ShNode word or in a sibling list keyed by
  node name? The node word is shared with every consumer; a sibling list
  is a layout-word-only change.
- Whether `new.command.tree` should carry the interface (it already
  carries the nodes) or stay authority-only.
- **Rung 2, the per-node command interface in the layout word.**
  Deferred, not decided against. hp-boss and the pico-cycler declare
  their vocabulary in `Scada.COMMAND_NODE_INTERFACES` and
  `CommandNode.send_state_command` maps the HpBoss actor class to
  `TurnHpOnOff` by hand; relays declare theirs in the layout word
  (`relay.control.config`). Whether the layout word carries an interface
  per node, so capabilities become a pure projection of the tree and the
  hand-map goes, waits for a second consumer of the surface
  (`../../../command-surface.md` "Open").
- **Command enums still without sema words:** `top.event`,
  `change.heat.pump.control`, every LocalControl and LeafAlly event
  enum; the LC and ally state words still carry the `gw1` prefix. The
  admin-surface enums got theirs on 2026-09-08.
- **Two undecided refusal paths.** NotAControlNode has no speaker: only
  the scada's routing knows a dispatch target is not a command node
  (`process_admin_dispatch` finds no communicator and drops it
  silently). hp-boss's `FromHandle` mismatch only logs. Both are
  refusals with no nack; decide who speaks and whether the admin sees
  them, with the command-interface work.
