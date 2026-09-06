# Layout-word axioms sitting (spoke)

Status: Draft · Pass 0 · Updated 2026-09-02 · Linear: OPS-392

> What this is: the agreed reshape of `gw.house0.layout/000` and
> `gw.nolan.layout/000` axioms (both staging — in-place edits), plus the
> fixture/generator moves that let them land. Decisions with Jessica
> 2026-09-01; word-gate summary posted and confirmed this session.

## Axiom architecture (per word, mirroring the names tiers)

1. **`CoreShNodesExistenceAndActorClass`** — identical wording across
   all layout words: `s` PrimaryScada, `s2` SecondaryScada,
   `power-meter` PowerMeter, `ltn`/`admin`/`auto` NoActor, `la`
   LeafAlly, `lc` LocalControl, `derived-generator` DerivedGenerator;
   exact-match (no additional node with these names). Shape from the
   Nolan stash; contents from the live fixtures.
2. **`CommandNodesExistenceAndActorClass`** — the command skeleton:
   `n` NoActor (handle `auto.lc.n`), `pico-cycler` PicoCycler,
   `hp-boss` HpBoss (hp-boss in EVERY layout — the reporting rule
   requires it; landed in BOTH words 2026-09-01, Nolan via its
   axiom-5 pair mapping + fixture regen with the hp-boss node).
   House0 adds `backup`, `scada-blind` (House0-only LC states) and
   `sieg-loop` SiegLoop (unconditional — the word means has-sieg).
   pico-cycler moved out of Nolan's RequiredActors and into RequiredCommandNodes. Statement name
   lists are one-per-line `→` mapping style throughout.
3. **`RequiredSensing`** — channel-based, kind-agnostic (Nolan axiom 7
   pattern). Known gaps to fix: **House0 is missing `dist-flow` and
   `store-flow`; Nolan is missing the four resistive-element power
   channels** (post-rename: `buffer-top-elt-pwr`, `buffer-bottom-elt-pwr`,
   `tank1-top-elt-pwr`, `tank1-bottom-elt-pwr`).
4. **`SiegManifoldChannels`** (House0 only) — UNCONDITIONAL, grown to
   the beech-observed surface: `sieg-cold`, `sieg-flow`, `sieg-flow-hz`
   + the valve-observation relay channels `hp-loop-on-off-relay`,
   `hp-loop-keep-send-relay`.
5. **`CommandableHeatPump`** (both words, conditional, biconditional) —
   a. optional `Hydronic.HpCommandNodeName` present ⇒ names an existing
   `hp-odu` or `hp-ctrl-box` with a ComponentId, ActorClass `HpTwin`,
   effective handle parent `hp-boss`; b. any `HpTwin`-classed node
   SHALL be the declared node (at most one per layout, zero when
   undeclared). Undeclared = NoActor + dormant hp-boss (spruce stays
   undeclared until the MIM is wired).
6. **`RequiredActuators`** (Nolan landed `e625ff6`, clause c for
   `secondary-010v` landed sema `d6f59e7`; House0 as axiom 10) — Nolan's
   RequiredRelays generalizes: the unconditionally-certain tree leaves,
   relays + 0-10V outputs (Nolan: `secondary-010v`, ActorClass
   ZeroTenOutputer, ComponentId an `i2c.dac.output.component.gt`;
   House0: the three `*-010v` nodes, Name + ActorClass only until the
   krida shift gives them per-output components — `dac-output.md`
   "Decided 2026-09-04"). The maybe-actuator heat pump never appears
   here — only via axiom 5.
7. **`RequiredHeatpumpEquipment`** (Nolan landed `e625ff6`; House0 as
   axiom 11, this round: `hp-odu` + `hp-idu`) — the heat-pump parts with components,
   NoActor: hp-odu and hp-ctrl-box move here OUT of
   RequiredCommandNodes (they are equipment, not tree structure). The
   board is NOT required (a layout does not determine its board); the
   rest of the plant inventory goes without saying. `hp-idu` names an
   indoor unit that does the refrigerant-to-water exchange (Ecodan
   hydrobox, LG hydro kit: no glycol, no plate exchanger); `hp-ctrl-box`
   stays the monobloc's box.
7a. **`ComponentBinding`** (Nolan landed `e625ff6`; Nolan word; House0's waits for
   the krida retirement) — every Component SHALL be referenced by
   exactly one ShNode. The node's Name is the component's human-meaning
   identity within the house; ComponentId stays as the replaceable
   instance uuid under it (a swapped part keeps the name, gets a fresh
   id). Generator-side the rule is already enforced: the id-map keys
   ComponentIds by referencing-node Name (legacy type-keys only for
   pre-node reference artifacts and House0's krida trio), and
   ComponentBinding tests guard both fixtures (House0's skipped until
   the retirement).
7b. **DAC output words** (words landed `912660c`; the fixture swap rides
   the actor rebuild, 1b — see
   `dac-output.md`): new `i2c.dac.output.component.gt` +
   `dac.output.config` (+ `sim.dac.output.component.gt`); the writer
   trio (`i2c.dac.writer.component.gt`, `i2c.dac.channel.config`,
   `sim.dac.writer.component.gt`) orphaned in place with `replaced_by`
   and out of both layout words' Components unions and the tlayouts seed
   (sema `d6f59e7`).
   Replaces the earlier idea of adding `ChannelName` to
   `i2c.dac.channel.config`.
8. **new.command.tree/002 axiom 2 `ActuatorLeaves`** (wording settled
   2026-09-02): a leaf is a dotted-handle node that is the parent prefix
   of no other; an actuator is ActorClass Relay / ZeroTenOutputer /
   HpTwin; a command node is ActorClass LocalControl / LeafAlly /
   PicoCycler / HpBoss / SiegLoop, or a NoActor node whose handle parent
   is the LocalControl node (the state-machine set: n, backup,
   scada-blind, without naming House0 in a cross-layout word). a. every
   actuator SHALL be a leaf; b. every leaf SHALL be an actuator or a
   command node. (Clause (c) — non-actuator leaves are Dormant
   command nodes — is code+matrix territory, not wire-checkable.) Full
   rationale + the twin architecture and the single `HpTwin`
   ActorClass: `hp-boss-cleanup.md`.

## Simulated devices are a vocabulary (settled 2026-09-02)

`gw1.sim.device.type` is disjoint from `gw1.device.type`: a component's
open DeviceType string belongs to exactly one, so scada tells simulated
from real by membership (`SimDeviceType`), never by a name prefix. A sim
value exists only when a sim actor speaks the real device's protocol
(`SimSamsungAE055FEYMCG` for the control box hp-boss practises modbus
against); a device nothing talks to is non-descript (`SimHpOdu`). Sim
parts carry no device-type records. Axiom numbering stays integer +
name; the cross-layout mirror key is the axiom NAME. One file per
type, definitions and runtime.

## Dropped / superseded

- House0 `SiegActorConsistency` — sieg-loop and hp-boss are now
  unconditional command nodes; its clause b (forbidding sieg-loop when
  UseSiegLoop false) was the HAS/USING conflation.
- Nolan `RequiredBoardActors` — bakes a Gw108 into the family; layouts
  do not determine sensing/actuation hardware. Successor: the
  component-conditional bus-actor↔board bijection, required in ALL
  non-sim layout words, landing with the board/krida actor wiring.
- House0 `Hydronic.SiegLoopPlumbed` — invariant-true for a word that
  means has-sieg (spec const rule: invariants aren't data fields).
- `Hydronic.UseSiegLoop` — migrates to `gw.house0.operational.params`
  (USING is operational; hp-boss/sieg-loop dormant when unused). Code
  ripple: `set_command_tree` reads it from ops, not the layout. Both
  fields live on the shared `gw.hydronic/000` (staging, with axiom 1
  SiegLoopControlImpliesPlumbed), so the move edits that word in place
  and the Nolan fixture and mirror ride along.

## Fixture / generator moves

- **`gw.house0` fixture represents beech** (the sieg family, real
  shape): hand-author the sieg surface in (sieg-loop node, sieg-cold /
  sieg-flow / sieg-flow-hz, dist-flow / store-flow), the LG nameplate
  parts, and the Honeywell-via-Hubitat zone circuit — sanctioned interim
  while the House0 sema generator is blocked. Under `sema validate` the
  fixture predates its component words' config shape (electric meter,
  web server, hubitat, poller; three channels still carry
  InPowerMetering); the generator fold-in closes that.
- **Sim House0 is its own fixture** (built 2026-09-02): `house0_sim_sema_gen.py`
  emits `gw.house0.sim.*` — a Nolan-type zone circuit (MechanicalDial,
  Learned, whitewire on the sim meter power channel, a sim temperature
  sensor for the zone), sim sensors behind every flow position and the
  sieg cold side, sim hp parts `SimHpOdu` + `SimHpIdu`, no Hubitat. Real
  nameplates (LG for beech, Mitsubishi for maple) belong on the real-shaped
  fixtures and their `hp.device.type.gt` records, authored from the Drive
  nameplate photos.
- **tlayouts `gen_elm` / `gen_fir` / `gen_oak` repoint to a
  `gw.house0.no.sieg` stub that does not exist yet** — making the third
  family's need concrete in code; the word itself is NOT authored now
  (see the layouts spoke).
- Nolan regen wave carries: hp-boss node returns + tank1-elt renames +
  the elt-pwr channel renames.

## Hardware decoupling (contemplated 2026-09-02)

Layouts DO NOT determine sensing/actuation hardware — the axiom side
already says so (RequiredBoardActors dropped; sensing kind-agnostic;
relay axioms are Name+ActorClass only). The generators still entangle
family with hardware: `NolanSemaGen` IS the gw108 emitters,
`House0SemaGen` IS krida/DFR/TSnap/hubitat. Target shape (marries the
SHARED-actors / SPECIFIC-hardware split):

- A family generator owns the PLANT: the hardware-neutral roster (relay
  names + control semantics, sensing surface, zones, hydronic facts) —
  what the layout word requires.
- `src/tlayouts/hardware/` modules own realization: each knows how to
  emit components for a roster entry (a named relay with a control
  config; a thermistor channel; a dac output) against its board record.
- The config carries hardware AXES with per-family DEFAULTS (gw108-revb
  boards, pico btus/tank modules) — a default choice, never hardwired.

**The proof is `gen_alt_nolan.py`**: the Nolan PLANT on House0-style
hardware (krida relays, DFR dacs, TSnap ADS). Same `gw.nolan.layout`
word, same roster, different Components/DeviceTypes — the word's axioms
already permit it. It cannot fully exist until the krida retirement:
pre-retirement krida relays are one multichannel component with
positional RelayIdx configs, post-retirement they are thin per-relay
components against a board record — the SAME shape as gw108. The
retirement is what makes "which board" a one-axis swap; the alt-nolan
gen is the N=2 stress test that keeps the interface honest.

First increment (landing now with the board node): the board becomes a
config axis — `board_node_name` + `board_record_file` with gw108-revb
defaults — instead of an imported constant.

## Sequencing (each its own commit)

1. Nolan word edits + Nolan sim-pair regen (tlayouts) + gwsproto
   mirrors + code repoints; suite green.
2. House0 word edits + fixture sieg surgery + gwsproto mirrors; suite
   green.
3. UseSiegLoop layout→ops move (word + code + fixtures together).
4. HpCommandNodeName + CommandableHeatPump (no fixture impact; mirrors
   only) — elm's Arctic (installing now) is the first consumer.
