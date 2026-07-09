# spaceheat-naming-vocabulary — encode the node/channel naming vocabulary in sema

Status: Draft · Pass 0 · Updated 2026-07-04 · Linear: OPS-444

**EDD: no** vocabulary build-out; verified by the sema suite + snapshot regen in each consumer (the
generators and validators that derive names from the words), not a standalone experiment.

> What this is: the spaceheat node/channel naming vocabulary — which names exist, how the
> parameterized families derive, and the event/state/device-type value sets — becomes sema
> vocabulary, so every consumer (tlayouts gen, gwsproto, gridworks-terminalasset, layout axioms)
> derives it from a snapshot instead of holding its own constants copy.

## Why now

The layout gen moved to tlayouts on the sema snapshot (2026-07-04), which forced three constants
mirrors into existence in one day:

- `tlayouts/src/tlayouts/names/` — a copy of `gwsproto/names` (core / house0 / hydronic_spaceheat /
  nolan / simple_sim node+channel names), imports rewritten. The OFI in its README points here.
- The relay event/state vocabularies as string literals in the gen's `_RELAY_KINDS`
  (`change.store.flow.relay`, `heat.pump.control`, `aquastat.control.state`, …) — gwsproto holds
  these as python enums; sema types the `relay.actor.config` fields as `left.right.dot` +
  `non.empty.string`, with axioms 1–2 enforcing membership only for the two vocabularies that ARE
  sema words (`change.relay.state`, `relay.closed.or.open`).
- A `DeviceType` string-constants class in the ported gen mirroring the `gw1.device.type` values.

gridworks-terminalasset needs the same names almost immediately (the sim harness side), which would
make a third names copy. A change to the naming vocabulary currently touches every copy, and drift
is only caught downstream as a layout diff.

Names are boundary semantics in sema's own sense (spec Principle 4): actors find channels by name,
layout axioms bind zone names to channel names, handles encode the control hierarchy. Meaning that
affects cross-system behavior should be declared in the vocabulary, not held in per-repo constants.

## What already exists

- **Shape formats:** `spaceheat.name`, `handle.name`, `left.right.dot` — the legal shapes are done.
- **`gw1.device.type`** is already a sema word (registry); the gen's constants class mirrors it
  pending snapshot arrival in tlayouts.
- **`change.relay.state`, `relay.closed.or.open`** are sema enum words; `relay.actor.config`
  axioms 1–2 enforce membership when the config declares those event/state types.

## The encoding, by stratum

1. **Closed invariant sets → versioned (additive) enums.** The core node names (`s`, `admin`,
   `auto`, `ltn`, `la`, `lc`, `derived-generator`, …), hydronic node names (`hp-odu`, `buffer`,
   `store-pump`, the relay names), and invariant channel names — layered the way `gwsproto/names`
   layers (core / hydronic-spaceheat / house0), so a consumer pulls only the layers it composes.
   Layout axioms that today carry the name lists in prose (e.g. house0 EssentialNodesExistence)
   reference enum membership instead.
2. **Parameterized families → a naming word whose fields are the pattern templates.** Zone
   (`zone{i}-{zone}`, `…-whitewire-pwr`, `…-heat-call`, `…-failsafe-relay-state`), tank
   (`tank{i}-depth{d}`, `-micro-v`), and flow (`{pos}-flow`, `{pos}-flow-hz`) derivations become
   data — template strings in a versioned type (working name `spaceheat.naming/000`) with one
   canonical instance. Generators in any language expand the templates; the pattern-carrying axioms
   (house0 axiom 3 ZoneHeatCallChannel, axiom 4) point at the word instead of restating patterns.
3. **Relay event/state vocabularies → enum words.** The six missing pairs
   (`change.store.flow.relay`/`store.flow.relay`, `change.heat.pump.control`/`heat.pump.control`,
   `change.aquastat.control`/`aquastat.control.state`, `change.primary.pump.control`/
   `primary.pump.control`, `change.keep.send`/`hp.loop.keep.send`, `change.heatcall.source`/
   `heatcall.source`), extending the `relay.actor.config` membership axioms to cover them.
4. **Handle hierarchy templates** (`auto.lc.n.hp-boss`, the per-relay handles) — the deepest
   semantics in the layout, scoped **consciously as its own decision**, not swept in: the handle
   templates are really the control-hierarchy contract and may deserve their own word or a later
   version.

## Enum strictness (proposed resolution)

Keep the single system-wide enum semantic: all sema enums coerce out-of-vocab values to the default.
Coerce-to-default is what makes versioned enums safely additive across independently deployed
systems — an old consumer meeting a new value degrades predictably instead of failing to decode. A
reject-variant of the enum kind would fork the concept (every consumer must know which kind it
holds) and re-couple deployments. Strictness stays a property of the consuming contract or context:

- a type that must hard-reject declares an **axiom** (the `relay.actor.config` pattern);
- authoring/CI contexts get a **strict mode in validation tooling** (flag any value that would
  coerce) — no wire-semantics change.

The name enums here are referenced by axioms and generators, not used as decode-coercing field
types, so the coercion default does not bite.

## Consumers and payoff

- **tlayouts:** the names arrive via the ordinary snapshot round; the `names/` mirror, the
  `_RELAY_KINDS` string literals, and the `DeviceType` constants class are deleted. Thin combinator
  code (expanding zone/tank patterns) stays code; the vocabulary it expands is sema.
- **gwsproto:** the `names/` package and relay/device-type enums are checked against the sema words
  by the gwsproto↔sema conformance sweep (`packages/gridworks-scada-protocol/gwsproto_sema_conformance.py`) — names
  drift between repos becomes mechanically detectable.
- **gridworks-terminalasset:** consumes the same words from its own snapshot instead of a third
  copy. This is the dependency that pulls the design forward (referenced from the
  simulated-test-environment design).
- **Layout axioms:** membership and pattern rules become mechanical instead of prose.

## Open

- Word layering and names: one `spaceheat.naming` word vs per-layer words mirroring the python
  package layout; exact enum names (`core.node.name` vs `spaceheat.core.node.name`).
- Template syntax for the naming word's pattern fields (and whether an axiom validates template
  well-formedness).
- Handle templates in or out of the first version (stratum 4 above).
- Whether the strict-validation tooling mode lands with this design or separately.
- Sequencing against hardware-layout-pass-one: the mirrors are live and correct today, so this can
  land after the pass-one core ships; the terminalasset need may pull it earlier.
