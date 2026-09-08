# Krida retirement, admin for Nolan, and the command interface (spoke)

Status: Draft · Pass 0 · Updated 2026-09-08 · Linear: OPS-392

> What this is: one spoke, combined 2026-09-07 from three that shared one
> word, `scada.control.capabilities`: the scada half of the relay
> decommission (per-relay thin components against a board record; sema
> half shipped 2026-07-03), the admin UI as a first-class way to see and
> hand-operate a Nolan-layout house, and how actors share what commands
> they take. Estimate on OPS-392; runs next after pico-cycler-command.
> The combined slug is still `krida-retirement`; rename is a separate
> decision.

## Why now

The gwadmin TUI shows no relays and no DACs for a Nolan layout
(watched 2026-09-07 on the dev-broker sim): on link-up the client asks
for `scada.control.capabilities`, `Scada.control_capabilities` looks up
`H0N.relay_multiplexer` unguarded, Nolan has no such node, and the
reply is never built (logged as `Trouble with SendLayout`, the
neighbouring branch's label; every pico-cycler dev-broker run carried
it unread). The word requires the Krida component and gwadmin reads
every relay's config from its `ConfigList`. Admin is how a human runs
a house during bring-up, and Nolan houses are installed this fall, so
the panel comes first and in the smallest change that makes it work.
The relay decommission is also what House0 sim-green (the single scada
focus) is blocked on: commanding a House0 relay reaches `relay.py`'s
dead Krida multiplexer round-trip. Rung 3 dissolves that.

## ▶ Do this next: the NotMyBoss nack (sema first), then the witness

The 2026-09-08 dev-broker session moved four things under rung 1 and
they are in (`adbd1d6f`, `e0029d3d`, `c8555abe`): the cycler and
command-node rows follow `machine.states` live rather than the 30 s
snapshot; the table groups an owned relay under its owner; every
command node acks on take and nacks Busy / UnknownEvent / OutOfRange,
and the panel toasts one line per answered command; the button label is
the event alone. On the panel a Reboot picos click shows RelayOpening
at once, PicosRebooting 5 s later, PicosLive about 20 s after that on
the sim.

Next move, in order:

1. **The NotMyBoss nack, sema first.** The staging word
   `gw.dispatch.nack` is edited in place: drop axiom 1, reword
   `ToHandle` as the refused command's FromHandle (the decision and the
   per-file read are in `pico-cycler-command.md` "Acknowledgement
   decided", the bullet "`gw.dispatch.nack` axiom 1 cannot hold"). A
   sema turn with the word gate: read `sema/spec/primary.md` and the
   type registry and authoring spokes, post the summary, wait. Then the
   gwsproto mirror drops `check_axiom_1` and its rejecting test, and
   the four actors' handle-mismatch paths send the nack through
   `command_reply.nack`.
2. Rung 2 on its own estimate row.

**Rung 1 witnessed on the real house (2026-09-08, Verified ·
Reviewed 2026-09-08@c8555abe).** `gwa watch spruce` from the laptop
against a window scada on the spruce gw108
(`experiments/2026-09-08-spruce-admin-panel/`): the twenty relays, the
cycler and hp-boss rows and the DAC rendered; Reboot picos cycled the
vdc-relay twice more after the boot cycle and the real picos re-POSTed
7 to 9 s after each close; the secondary pump and the iso valve were
each driven from their rows and `secondary-flow` followed within a
snapshot; the DAC moved pump speed. One 0x21 expander reset happened
under CloseValve with the pump coil energized and cost no output.
hp-boss was not exercised (the Samsung ignores the call contact). The
tank picos' params POST is rejected until gridworks-pico PR #15 ships
the 200 fields; readings still arrive.

Two things to know: the panel's rows take state from
`single.machine.state` (snapshot `LatestStateList` plus the live
forward, which covers `machine.states` senders too), and every row
shows `?` until its node's first state report arrives. A relay owned by
an interior node (`vdc-relay`, `hp-scada-ops-relay`) shows state with
no action; the cycler and hp-boss rows carry those commands.

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

- **Interior command nodes do not handle their relays' acks.** With
  `c8555abe` every relay acks its boss on take; on the auto path at boot
  (LocalControl telling hp-boss TurnOff) hp-boss logged the relay's
  `gw.dispatch.ack` as an unexpected message (spruce window 2026-09-08,
  `experiments/2026-09-08-spruce-admin-panel/`). hp-boss and the
  pico-cycler need an ack/nack handler for the relays they own, or the
  relay must ack only a non-interior boss; decide with the NotMyBoss
  nack, which is the same reply path.
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

## Why admin comes first

Status: Accepted · Pass 1 · Updated 2026-09-05

- **Admin is the capability vocabulary — and comes FIRST.** Per the
  capability-protocol-and-verify design ([OPS-394](https://linear.app/gridworks/issue/OPS-394)), the actor capability
  surface is calibrated to what the admin can do. This spoke is therefore
  a **prerequisite** of the capability-protocol work, not a sibling
  (Jessica, 2026-06-10): getting admin working against Nolan *discovers*
  the field-proven vocabulary; the capability protocol then carries that
  vocabulary into **intra-scada dispatch** (control states speaking
  through `ShNodeActor`).
- **Bring-up reality:** every spruce milestone (i2c relays, AC via fan
  coils, resistive backup) gets exercised by a human through admin
  before it's trusted to local control.

## Capabilities heritage and the muddles to fix

Status: Accepted · Pass 1 · Updated 2026-09-05

**Heritage — why the type exists** (Jessica, 2026-06-10, told): to
**decouple the admin's relay knowledge from `layout.lite`** — every time
Thomas changed flo params, layout.lite's version moved and the gwa
textual app broke until upgraded. Capabilities is the stable,
control-focused projection the admin can depend on. That purpose is
sound and survives every fix below.

**State of the type** (verified 2026-06-10): sema already holds
**v001 as canon** (`sema/definitions/types/scada.control.capabilities/001.yaml`)
— canonical `spaceheat.node.gt/300` / `data.channel.gt/001` refs and
four axioms (ActorClassConsistency, HandleTerminalMatchesName,
AboutNodesAreControlNodes, I2cRelayComponent↔RelayNodes consistency).
The deleted `jm/scada-control` branch was the scada-side
*implementation* of this v001, not a proposal.

**The muddles to fix (Jessica, 2026-06-10) — drive a v002:**

1. **v000 axioms lived outside the sema spec** — written over bespoke
   non-sema mini-types (`ControlNode`/`ControlChannel`). v001 fixed the
   substrate; the lesson stands: axioms only over sema-registered
   attributes.
2. **CapturedByNodeName vs AboutNodeName confusion** — the admin's use
   of ControlChannels never decided which it meant; we were likely
   lucky they coincided for the channels in play. The v002 work MUST
   first trace what gwa actually reads
   (`gwadmin/watch/clients/relay_client.py` and friends) and then say
   explicitly which name the contract carries and why.
3. **House0 hardware baked into the type** — v001 still *requires*
   `I2cRelayComponent` (`i2c.multichannel.dt.relay.component.gt`); a
   Nolan house has `gw108.vdc.relay.component.gt`. v002 needs the
   hub's three-axis treatment (capability · binding · hardware) —
   likely per-node actuation-hardware references rather than one
   top-level Krida component.
4. **v001 usage inside admin is muddled** generally — the evaluation of
   how gwa consumes the message is in scope here, not just the type
   shape.
5. **Registry state (2026-09-05):** `scada.control.capabilities` is at
   `001`, status `staging`, refs `spaceheat.node.gt/302` and
   `data.channel.gt/003`; there is no `002` (the earlier note claiming
   one was squashed away 2026-08-13). Staging means the fix is an
   in-place edit of `001`, never a new version.

Sema changes go through sema word-authoring (v002 + upgrade template +
registry deltas). **Sieg-loop visibility in admin** (can/should gwa see
SiegLoop state?) is noted and **deferred to sieg-semantic-harmonization
([OPS-400](https://linear.app/gridworks/issue/OPS-400))** — that design already owns the valve-telemetry-not-emitted
gap.

## What the admin tool needs from a scada (read 2026-09-05)

Status: Accepted · Pass 1 · Updated 2026-09-05

Read of `packages/gridworks-admin` (`cli.py`, `config.py`,
`watch/clients/admin_client.py`, `dac_client.py`, `relay_client.py`,
`watch/relay_app.py`, the widgets) against the admin executor's
capabilities contract. Facts first, then the House0 assumptions.

**Consumed.** On link-up the client requests `scada.control.capabilities`
(`SendControlCapabilities`, re-requested every 60 s until it arrives),
then `snapshot.spaceheat` (`SendSnap`). It never reads `layout.lite`.
Per controllable node it keys everything off ONE name, the node's
`Name`: the dispatch address is `admin.<Name>`; the state channel is the
`ControlChannels` entry whose `AboutNodeName` equals it (the
`CapturedByNodeName` question in the executor is settled by the code:
admin never reads it); relay event and state vocabulary comes from the
config entry whose `ActorName` equals it. State arrives from the
snapshot's `LatestReadingList` and from the `single.reading` messages
the scada forwards to the admin link for every relay and 0-10V channel
(`Scada._forward_single_reading`), keyed channel name -> node.

**Sent.** `AdminDispatch` wrapping an `FsmEvent` (`FromHandle admin`,
`ToHandle admin.<Name>`, `EventType` and `EventName` from the relay
config), `AdminAnalogDispatch` wrapping `AnalogDispatch` (`ToHandle
admin.<Name>`, `Value` volts x10, 0-100), `AdminKeepAlive`,
`AdminReleaseControl`; every message `Src admin`, `Dst <scada alias>`.
`experiments/2026-09-05-dac-output-bench/bench_dispatch.py` is this
client driving one DAC and is the seed for the Nolan client test.

**Per node the tool needs exactly five things:** the dispatch address,
the subject (about) node, the state channel name, the event and state
vocabulary (relays only), and, display only, a board position (already
optional). Nothing else in the word is read.

**House0 assumptions to remove, in the package:**

- `RelayWatchClient._get_relay_configs` reads relay configs from
  `I2cRelayComponent.ConfigList` (the Krida board, a required field of
  the word). Nolan relays each carry one `relay.control.config` on a
  board-resident component; House0's `relay.actor.config` carries the
  same nine fields plus `RelayIdx`.
- `RelayWatchClient._send_set_command` rewrites `hp-scada-ops-relay` to
  `admin.hp-boss` speaking `TurnHpOnOff`, and `Scada.process_admin_dispatch`
  rewrites it straight back to a relay event on `hp-scada-ops-relay`.
  The pair exists because under House0's sieg tree the relay's handle is
  `admin.hp-boss.hp-scada-ops-relay`, so a direct `admin.<Name>` fails the
  immediate-boss check. On Nolan the relay sits directly under the boss.
- `DACWatchClient.set_dac` takes the table's DISPLAY name and appends
  `-010v`; the row key is already the node name, so the app should pass
  that.
- `RelaysApp` and the House0 rows in `test_admin.py`'s commented tests.

**The word edit this needs (staging `001`, in place; not started, needs
Jessica):** replace `I2cRelayComponent` with a list of
`relay.control.config/000`, one per `RelayNodes` entry, and rewrite
axiom 4 over it (ActorName set equals RelayNodes names; each ChannelName
equals the ControlChannels entry about that actor). The scada projects
House0's `relay.actor.config` into it by dropping `RelayIdx` until the
krida shift. The hp-boss rewrite pair then goes, with admin addressing
the relay's actual handle from `RelayNodes` rather than composing
`admin.<Name>`. `tests/actors/test_admin_on_nolan.py::
test_control_capabilities_on_nolan` is the failing test that the edit
turns green.

## Rung 2: the command interface

### What a command interface is today

Three parts. Vocabulary: an event enum, named by `EventType` in
`fsm.event`, with `EventName` constrained to it. Authority: the command
tree (`FromHandle` is the immediate boss of `ToHandle`). Feedback: a state
enum reported through `single.machine.state`, plus `fsm.full.report` per
command for actuators.

### How it is declared, three ways

- Relays: in the layout word, per node. `relay.control.config` carries
  `EventType` + the two events and `StateType` + the two states.
- hp-boss, pico-cycler, LocalControl, LeafAlly: hard-coded in Python.
  `CommandNode.send_state_command` maps `ActorClass.HpBoss` to
  `TurnHpOnOff` by hand; the admin client addresses hp-boss because it was
  written knowing to.
- Admin's `scada.control.capabilities` is actuator-shaped (relay nodes,
  DAC nodes, control channels, a Krida component); it cannot say "hp-boss
  takes turn.hp.on.off".

### Sema coverage is split

State enums mostly have words (`gw1.main.auto.state`, the local-control
and leaf-ally states, `zone.call.circuit.state`). Command enums mostly do
not: `turn.hp.on.off`, `pico.cycler.event`, every local-control and
leaf-ally `*.event`, `top.event`, `change.heat.pump.control`, the aquastat
and store-flow vocabularies. The gwsproto docstrings cite sema URLs that
resolve to nothing; `gw1.hp.boss.state` still carries the gw1 prefix.
States crossed a wire so they got words; commands stayed in-process until
admin started sending them. The `fsm.event` axiom EventNameBelongsToEventType
cannot be checked for an enum the registry does not hold.

### Proposal

Static capability in the layout, dynamic authority in the tree, both in
sema.

1. A per-node command interface in the layout word: `EventType` and
   `StateType` as enum references on every node that takes commands
   (`relay.control.config`'s vocabulary fields generalized to interior
   nodes; actuator configs keep their wiring facts).
2. `send_state_command` looks the vocabulary up on the node; the
   ActorClass switch goes (it is the hand-map the sema maxim names as the
   tell).
3. The admin capabilities projection becomes "every node with a command
   interface, with its vocabulary"; the Krida component field retires with
   it (krida-retirement).
4. The missing command enums become registered sema words, staging; the
   gw1 prefix rides snapshot-drop-gw1.

hp-boss's own interface (`turn.hp.on.off` in, `hp.boss.state` out) stays
fixed across strategies; the channel axis in `hp-twin.md` "Strategies" is the interface of the node hp-boss commands
(`change.relay.state` today, a heat-pump command enum for the twin).

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

## Known gaps (verified 2026-06-10 unless noted)

Status: Accepted · Pass 1 · Updated 2026-09-05
- **Admin tests are House0-only.** `tests/test_misc/test_admin.py`
  relay/DAC tests explicitly override to the House0 layout (relay
  index 18, DFRs); there is no Nolan-layout admin coverage at all.
- **Admin relay client** (`gwadmin/watch/clients/relay_client.py`) was
  touched by the mined `jm/scada-control` sketch — its assumptions
  about relay enumeration likely follow the House0 relay-bank shape
  (`House0RelayIdx`); needs a read against the Nolan layout (vdc relay
  on GPIO, no relay1–18 bank). *Inferred — verify.*
- What a Nolan admin **should show** is partly different in kind: opto
  heat-call states, learned setpoints + SetpointPhase per zone, gw-temp
  channels — observation surfaces House0 admin doesn't have.

## Definition of done

Status: Accepted · Pass 1 · Updated 2026-09-05

1. Admin connects to a Nolan-layout scada and renders its actual
   actuators and channels (no crash on missing multiplexer/DFRs).
2. A human can operate the Nolan actuators that exist through admin.
   Today that is exactly one relay — **the pico cycler is the only
   Nolan relay under scada control** (Jessica, 2026-06-10) — so it is
   the first target; the AC/fan-coil path joins when chunk E lands.
3. `test_admin.py` gains Nolan-layout cases alongside the House0
   overrides (the both-layouts test pattern from the merge gate).
4. The capabilities-type hardware-shape question is resolved jointly
   with [OPS-394](https://linear.app/gridworks/issue/OPS-394) (likely: per-node actuation component reference, not a
   single top-level I2cRelayComponent).

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
