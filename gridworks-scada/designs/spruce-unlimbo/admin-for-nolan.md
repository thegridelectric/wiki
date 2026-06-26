# Admin works well for Nolan

Status: Accepted · Pass 1 · Updated 2026-06-10 · Linear: OPS-392

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
5. **Fold in the ActorClass bump (Jessica, 2026-06-12).** The actor-class
   cascade re-pointed `spaceheat.node.gt` to `/302`; capabilities must reach
   `/302` too so capability declarations can carry post-bump nodes. But
   `scada.control.capabilities/001` is **non-draft (immutable)** — an in-place
   edit was attempted and **reverted** per the immutability rule. This v002
   SHALL re-point `RelayNodes`/`DacNodes` to `spaceheat.node.gt/302`. Until v002
   lands, capabilities stays on `/300` (it never carries sim actors, so no
   urgency — the bump rides this planned v002, not a throwaway version).

Sema changes go through `/make-sema-word` (v002 + upgrade template +
registry deltas). **Sieg-loop visibility in admin** (can/should gwa see
SiegLoop state?) is noted and **deferred to sieg-semantic-harmonization
([OPS-400](https://linear.app/gridworks/issue/OPS-400))** — that design already owns the valve-telemetry-not-emitted
gap.

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

- Does admin currently crash, render empty, or partially work against
  `nolan-layout.json`? Nobody has pointed admin at a Nolan scada yet —
  unsurprising while the pico cycler is the only scada-controlled relay.
  First move: point gwa at the dry-run-verified branch scada and look.
- Admin's DAC/0-10V surface on Nolan: present-but-empty or absent?
- Whether learned-setpoint/SetpointPhase display belongs in admin or
  stays a derived-channel/monitoring concern.
