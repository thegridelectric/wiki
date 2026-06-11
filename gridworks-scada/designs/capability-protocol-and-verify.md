# Capability protocol + verify (design)

Status: Draft · Pass 0 · Updated 2026-06-10 · Linear: OPS-394

> What this is: encode the scada actor's functional abilities as an explicit
> protocol in `ShNodeActor` methods — the only language control states may
> speak — plus the verification layer that makes intent observable. Born
> from the maple standby post-mortem (OPS-393): Standby expressed "keep
> everything off" at relay level, the sieg loop moved HP authority into
> HpBoss, and nobody told HpBoss "off."

## Principles

1. **`ShNodeActor` methods ARE the protocol.** Control states express intent
   only through the actor capability surface (`turn_off_HP`,
   `*_switch_to_scada`, …) — with **surface area calibrated to what the
   admin can do** (admin is the field-proven vocabulary of what a human
   needs to be able to do to a house). If a state needs a capability admin
   doesn't have, that's a design conversation, not a new relay incantation.
2. **Layouts bind capabilities.** Each hardware variant (House0 relays,
   sieg's HpBoss sequencing, Nolan's opto/white-wire world) implements what
   a capability means on its plumbing. Raw-relay idiom in local-control
   states is retired.
3. **Sema at the wire only.** The capability calls are in-process; Sema's
   jurisdiction is serialized JSON crossing system boundaries. So
   `scada.control.capabilities` (Sema) mirrors only the boundary-crossing
   subset (admin remote commands today; dispatch contracts someday). One
   capability vocabulary, two carriers, kept in correspondence — neither
   forced into the other. (Jessica, 2026-06-10: "not sure we want to force
   this into sema" — settled as wire-only unless revisited.)
4. **The hierarchy of command stays; refusals become loud.** The command
   tree (one authority per actuator, structural handoff between regimes) is
   load-bearing — mandatory once dispatch contracts are binding. Maple
   confirmed the mechanism (verified 2026-06-10): under sieg the tree hands
   `hp_scada_ops_relay` to hp_boss and both loop relays to sieg_loop
   (`scada.py` command-tree wiring), so old Standby's energizes from
   normal_node were **rights-rejected, silently logged no-ops** — the tree
   correctly refused; nobody heard. Mend: a refusal comes back to the
   issuing state as an error event (and plausibly an alert channel). An
   order refused and an order swallowed are opposite things.
5. **Standby's intent-set under sieg is `{HpBoss: off, SiegLoop: dormant,
   failsafe/aquastat: scada}`.** Open (Jessica/Thomas, sieg authorship):
   does HpBoss TurnOff (or Standby entry) currently park the sieg loop —
   valve idle, PID quiet, `hp_loop_keep_send` in a deliberate summer state?
   If nothing tells SiegLoop the system is asleep, that's the maple shape
   one layer down: an authority nobody told. "Park the sieg loop" likely
   belongs on the capability surface explicitly.
6. **Audit the tree at state entry.** When a state takes command, verify it
   holds rights to every capability it might need — fail loudly at entry,
   not at 07:03 on-peak weeks later.
7. **Closed-loop verify.** A state whose intent is "HP off" watches the hp
   power channels and raises a local alert on sustained draw — the house
   notices before the on-peak monitor does. Physics auditing declared
   intent.
8. **Layout-variant test matrix.** Each local-control state ×
   {House0, House0Sieg, …Nolan} asserting final capability-level intent —
   the missing test that would have caught maple; the regression net for
   every layout to come. Likely rides the simulated-test-environment
   harness (OPS-40) rather than a new one.

## Scope

- Audit all local-control states for residual raw-relay idiom (Standby was
  fixed by #566/#567; confirm the others are fully capability-clean).
- Single shared source for the per-state relay sets (currently duplicated
  across state files).
- Refusal-escalation + entry-audit mechanics in `ShNodeActor` / command
  tree.
- The closed-loop "intent vs observed power" watcher.
- The test matrix.
- Open: exact capability list (calibrate against admin surface); how
  `scada.control.capabilities` declarations are produced from layouts;
  relationship to OPS-368 (SystemMode visibility); **which other sites are
  sieg-plumbed** (Jessica: "what about beech??") — the fleet sweep of
  use_sieg_loop belongs in this design's first verification pass.

## Mined input — the `jm/scada-control` sketch

Mined 2026-06-10 from the 3-commit WIP branch `jm/scada-control`
(2026-05-07, deleted after mining). Two different standings:

**Implementation of settled canon (not a proposal):**
`scada.control.capabilities` **v001 already exists in sema**
(`sema/definitions/types/scada.control.capabilities/001.yaml`, verified
2026-06-10) — canonical `spaceheat.node.gt/300` / `data.channel.gt/001`
refs (so capability declarations carry **Handles**: command-tree
position, not just existence) and four axioms: ActorClassConsistency ·
HandleTerminalMatchesName · AboutNodesAreControlNodes ·
I2cRelayComponent↔RelayNodes consistency. The sketch was the scada-side
implementation of that v001. The **targeted v002 update** (the
CapturedByNodeName/AboutNodeName muddle, the required House0 Krida
component blocking Nolan, the gwa-usage evaluation) lives in the
spruce-unlimbo design's admin-for-nolan spoke — not here.

**Heritage code moves (ideas tried, not yet ratified):**

- **De-hardcode admin dispatch:** `Scada._process_admin_dispatch` on dev
  carries a hard-coded hp-boss→relay6 translation; the sketch replaces
  it with generic `layout.node_by_handle(event.ToHandle)` routing — the
  admin speaks handles, no per-actuator special cases. Directly serves
  principle 1 (surface calibrated to admin) and principle 4 (one
  authority per actuator, structural).
- **`node_by_handle` made strict:** from Optional-returning lookup over
  explicit `.Handle`s to a KeyError-raising lookup over the *effective*
  handle (`Handle or Name`) — every node addressable, unknown handles
  fail loudly. The "refusals become loud" principle applied to
  addressing.

## Relationship to other work

**Sequencing (Jessica, 2026-06-10): admin-first.** This design is about
**intra-scada dispatch** — control states speaking through the
`ShNodeActor` capability surface. The spruce-unlimbo design's
admin-for-nolan spoke is a **prerequisite**: getting admin working
against a Nolan house *discovers* the field-proven capability vocabulary
(admin is the calibration standard per principle 1); this design then
carries that vocabulary into the control states. The
`scada.control.capabilities` v002 work rides admin-for-nolan, not here.

Nolan local control (spruce-unlimbo Chunk D) is **written against this
protocol from day one** — this design and the spruce work co-evolve, but
the capability list should stabilize before Chunk D hardens.
Implementation gate applies: this design reaches Accepted · Pass ≥ 1
before its code lands.
