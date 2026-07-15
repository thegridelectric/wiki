# Code for three layouts — discrimination + per-layout command tree (spoke)

Status: Accepted · Pass 1 · Updated 2026-06-28 · Linear: OPS-407

> What this is: the evaluation of what `gw_spaceheat` must change to run **three** layouts (house0,
> nolan, simple_sim) — driven by two needs JM named: **(a)** the scada must know *which kind* of layout
> it is running, and **(b)** each layout needs **its own command tree**. The sim is the forcing case
> (it has **no pico-cycler relay** and a single hp-relay), so getting it to boot is what surfaces every
> House0 assumption.

## The command-tree mechanism (as-is)

The "command tree" is the actor hierarchy expressed through each `ShNode.Handle` (dotted handle); a
node's boss is its handle with the last segment stripped. Two layers:

- **Generic / layout-agnostic (stays):** `HardwareLayout.boss_node` / `boss_handle` / `direct_reports`
  / `node_from_handle` (`hardware_layout.py:1062+`) — pure handle arithmetic. The ActorClass→actor
  factory (`actors/__init__.py`, dispatch on `ShNode.ActorClass`) is also layout-agnostic. These are
  the shared substrate and need no per-layout change.
- **House0-specific (must become per-layout):** `Scada.set_command_tree` (`scada.py:1235`) and
  `ShNodeActor.set_command_tree` (`sh_node_actor.py:1220`) **re-root** the tree when control changes
  (leaf_ally / local_control / admin), and they **hardcode House0**: the vdc relay is always re-parented
  under `auto.pico-cycler`; in sieg mode `hp_scada_ops_relay` goes under `hp-boss` and the loop relays
  under `sieg-loop`; everything else under the current boss. All by `H0N.*` names
  (`pico_cycler`, `hp_boss`, `sieg_loop`, `hp_scada_ops_relay`, `hp_loop_*`, `vdc_relay`).

## Where the scada is House0-coupled (the census)

`scada.py.__init__` alone bakes in: `isinstance(hardware_layout, House0Layout)` (hard guard, L115);
`H0N.local_control_normal`; `use_sieg_loop` + `sieg_loop`/`hp_boss`; `required_actuators =
{relay_multiplexer, zero_ten_out_multiplexer}`; the TopState/MainAutoState machines; the pico-cycler
direct-report wakeups (L1036/1048). `sh_node_actor.py` exposes `pico_cycler`, `hp_scada_ops_relay`,
`hp_failsafe_relay`, `store_charge_discharge_relay` as `self.layout.node(H0N.*)`. `house_0_layout.py`
*requires* a pico-cycler when pico actors are present. None of this holds for nolan or simple_sim.

## (a) How the scada knows which layout — discriminate by `TypeName`

The layout is self-describing (sema Principle 3: types declare identity). So the scada **dispatches on
the loaded layout's `TypeName`** (`gw.house0.layout` / `gw.nolan.layout` / `gw1.simple.sim.layout`) to
instantiate the right dc class and the right command-tree builder. Concretely:

- Relax `isinstance(..., House0Layout)` to the **base `HardwareLayout`** + a TypeName dispatch (or a
  capability check — see capability-protocol-and-verify, OPS-394).
- There is **only a `House0Layout` dc class today** (`data_classes/` has `hardware_layout.py`,
  `house_0_layout.py`, `layout_lite_dc.py`). Nolan and simple_sim need dc classes too — subclasses of
  `HardwareLayout` carrying their family accessors + command tree. `sema_to_dc` ([`gen-pipeline.md`](gen-pipeline.md))
  targets the dc class chosen by TypeName.

## (b) A command tree per layout — polymorphism

Make the command tree a **per-layout responsibility**: each layout dc subclass builds its own
(`set_command_tree` becomes a layout method the scada/actor calls, instead of House0 logic inline).

- **House0Layout:** today's logic — pico-cycler(vdc) + (sieg) hp-boss(hp_scada_ops) + sieg-loop(loop
  relays) + rest under boss.
- **SimpleSimLayout:** minimal — **no pico-cycler**, no relay/0-10 multiplexers assumed; the single
  `hp-relay` (and any future sim actuators) report directly to boss. No vdc special case.
- **NolanLayout:** the gw108 tree (its own relays, opto sensing); per the stash handle topology
  (`auto.lc.n.*`, `auto.pico-cycler.vdc-relay-gpio-23`, …).

The generic boss/handle arithmetic stays in the base; only the *assignment of which node parents where*
is per-layout. (Longer term, capability-protocol-and-verify points at a **declarative** command tree the
layout *declares* and the actors apply generically — "one codebase, many plumbings." Polymorphism is the
pragmatic pass-one step; the declarative form is the pass-two/Capability direction.)

## (c) On-disk layout file naming — not a real violation

JM's question: do we break the "name a sema instance `<type-name>.json`" convention by using a fixed
`hardware-layout.json` with the type inside? **Answer: the discriminator is the inner `TypeName`, not
the filename** — so the scada dispatches on `TypeName` regardless of file name. Two clean options, both
fine:

- **Type-named** (`gw.house0.layout.json` / `gw.nolan.layout.json` / `gw1.simple.sim.layout.json`) —
  honors the convention; best for the **canonical example** instances in sema/docs.
- **Fixed runtime path** (`hardware-layout.json`) with `TypeName` inside — pragmatic for the deployed
  scada, a path-loaded artifact; a mild bend justified because TypeName is the real authority. Per-home
  test fixtures (`maple.json`, `beech.json`) keep home names — multiple instances of one type can't all
  be `gw.house0.layout.json`, and that's the recognized fixture exception.

**DECIDED (2026-06-27): keep `hardware-layout.json`** as the deployed runtime file (fixed path,
`TypeName` inside as the discriminator). Name the **canonical example** by type
(`gw1.simple.sim.layout.json`); per-home fixtures keep home names (`maple.json`). The scada dispatches on
`TypeName` regardless of filename. Not a convention violation — the SHALL targets canonical instances;
the runtime file is a content-typed deployment artifact.

## (d) The sim has no pico-cycler relay

Confirmed against the code: House0 `set_command_tree` unconditionally re-parents the vdc relay under
`auto.pico-cycler`, and `house_0_layout.py` requires a pico-cycler when pico actors are present. The
**simple_sim** layout has neither a pico-cycler node nor a vdc/pico relay — only the single `hp-relay`
([`axioms.md`](axioms.md) "gw1.simple.sim.layout — its own word"). So `SimpleSimLayout`'s command tree
omits the pico-cycler special case
entirely, and `required_actuators` for the sim is just its own (the hp-relay), not
`{relay_multiplexer, zero_ten_out_multiplexer}`.

## Pass-one slice vs pass-two

- **Pass-one (enough to boot the sim):** relax the `isinstance(House0Layout)` guard to a TypeName
  dispatch; add a `SimpleSimLayout` dc class with a minimal command tree (no pico-cycler) + minimal
  `required_actuators`; the documented LocalControl fake
  ([`../../executor/testing.md`](../../executor/testing.md) "Current limits"). This is the
  smallest cut that lets `gw1.simple.sim.layout` boot.
- **Pass-two (full generalization):** the `H0N`/`H0CN` names sweep (~61 files) and the ~76 call-site
  sweep onto `self.hydronic.*` (gleanings); the `NolanLayout` dc class; the declarative
  capability-driven command tree (OPS-394). Don't pull these into pass-one.

## Concrete change list (pass-one cut)

1. `scada.py`: `isinstance(House0Layout)` → accept base `HardwareLayout`; dispatch command-tree
   construction + family accessors on `TypeName`. Guard the House0-only `__init__` wiring
   (`use_sieg_loop`, `pico_cycler` wakeups, `required_actuators`) behind "does this layout have it?".
2. `data_classes/`: add `SimpleSimLayout(HardwareLayout)` with its own `set_command_tree` (single
   hp-relay under boss, no pico-cycler) and minimal required-node set.
3. `sh_node_actor.py`: the `H0N.*` relay/pico accessors become layout-aware (present-if-the-layout-has-them),
   not unconditional `self.layout.node(H0N.*)`.
4. `actors/local_control/`: the documented near-no-op fake so the tree starts.
