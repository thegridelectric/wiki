# Admin works well for Nolan

Status: Accepted · Pass 1 · Updated 2026-09-05 · Linear: OPS-392

> What this is: spruce-unlimbo spoke — make the gridworks-admin UI a
> first-class way to see and hand-operate a Nolan-layout house, as it is
> for House0. Admin is how a human runs a house during bring-up; the
> July-15 AC commitment will be operated by hand before any control
> state does it.

## Why this is its own spoke

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

## The `scada.control.capabilities` upgrade (targeted, lives here)

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

## Known gaps (verified 2026-06-10 unless noted)
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

## Definition of done (first cut)

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

## Open

- **The governance-dial altitude (2026-08-11):** a second admin mode
  where the circuit machines stay awake and admin issues
  `SetGovernance` per circuit (`StatRules | Off |
  Thermostatic(+setpoint)`) — safety by construction (raw relay admin
  can express the cold-water mistake; governance admin cannot), and
  the journal records intent, not pin flips. Raw relay mode remains
  for bring-up. Model:
  `zone-relays-and-thermostat-model.md` "Admin: two altitudes".
- Does admin currently crash, render empty, or partially work against
  `nolan-layout.json`? Nobody has pointed admin at a Nolan scada yet —
  unsurprising while the pico cycler is the only scada-controlled relay.
  First move: point gwa at the dry-run-verified branch scada and look.
- Admin's DAC/0-10V surface on Nolan: present-but-empty or absent?
- Whether learned-setpoint/SetpointPhase display belongs in admin or
  stays a derived-channel/monitoring concern.
