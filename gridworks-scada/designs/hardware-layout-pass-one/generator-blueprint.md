# Generator blueprint — the gen spec (spoke)

Status: Accepted · Pass 1 · Updated 2026-06-27 · Linear: OPS-407

> What this is: the spec `sema_gen` emits — the invariant House0 skeleton plus the config axes. The
> `required_topology_nodes` + `required_system_actor_nodes` sets (`house_0_layout.py:541–619`) are the
> design input here (deferred as *axioms* to pass-2, but essential to the gen now). The gen builds from
> the per-domain names hierarchy (`gwsproto/names/` — `core` + `hydronic_spaceheat` + `house0`), NOT
> `H0N`/`H0CN`. Referenced from [`gen-pipeline.md`](gen-pipeline.md).

## The House0 skeleton the gen emits

- **System-actor nodes (invariant, 14):** `s`, `s2`, `power-meter`, `derived-generator`, `ltn`, `la`,
  `lc`, `lc-normal`/`lc-backup`/`lc-scada-blind`, `admin`, `auto`, `pico-cycler`, `hp-boss`.
- **Topology nodes (mostly invariant):** heat-pump (`hp-odu` always; **`hp-idu` is config-dependent** —
  maple is `hp-odu`-only and still House0); pumps (`dist`/`primary`/`store`); pipe temps
  (`dist-swt`/`dist-rwt`/`hp-lwt`/`hp-ewt`/`store-hot`/`store-cold`/`buffer-hot` — **not**
  `buffer-cold`); flows (`dist`/`primary`/`store`); the relay bank
  (`vdc`/`tstat-common`/`charge-discharge`/`hp-failsafe`/`hp-scada-ops`/`thermistor-common`/
  `aquastat-ctrl`/`store-pump-failsafe`/`primary-pump-scada-ops`/`primary-pump-failsafe`); the three
  010V outputers; `buffer` depths.
- **Config-driven parts** (the four axes): `Zones` · `TotalStoreTanks` · sieg (plumbed? controlled?) ·
  per-position flow/temp sourcing. Detailed below.

## Channels — the gen's only two per-channel choices

(1) **DataChannel vs DerivedChannel**, and (2) **which node captures it** (a DataChannel's
`CapturedByNodeName` or a DerivedChannel's `CreatedByNodeName`). From maple (75 Data + 16 Derived),
DataChannels group cleanly by capturer:

| CapturedByNode | DataChannels it reports |
|---|---|
| `power-meter` (eGauge) | every `*-pwr` (hp-odu/idu, dist/primary/store-pump, oil-boiler, per-zone whitewire-pwr) |
| `analog-temp` (ADS111x TSnap) | pipe temps (dist-swt/rwt, hp-lwt/ewt, buffer-hot/cold-pipe), `oat`, zone gw-temp |
| `relay-multiplexer` | every relay-state channel (`*-relayN`) |
| `zero-ten-multiplexer` | `dist/primary/store-010v` |
| `buffer` / `tank{i}` (pico tank) | per-depth `*-device` + `*-micro-v` raw channels |
| `dist-flow` / `sieg-send` (pico flow) | `*-flow` + `*-flow-hz` |
| `store-btu` / `sieg-btu` (BTU meter) | `store-hot/cold-pipe` + `store-flow`; `sieg-cold/flow/hot` |
| `zone{i}-…-stat` (Hubitat poller) | per-zone `-set` / `-state` / `-temp` |

DerivedChannels are all `CreatedByNode = derived-generator` **except** `hp-keep-seconds-x-10`
(`sieg-loop`, sieg-only). Strategies: tank/buffer per-depth calibration is `affine` (depth1/3) /
`identity` (depth2); `primary-flow` is `sum` (derived config only); `required-energy`/`usable-energy`
are `system-model`. So the few real data-vs-derived questions live at `primary-flow`, the calibrated
`*-depth{n}` (Derived) vs raw `*-depth{n}-device`/`micro-v` (Data off the tank module), and the sieg
`hp-keep-seconds-x-10`.

## Per-zone bundle — uniform (REVISIT in pass-2)

To move fast, every zone carries the same bundle, no per-zone variation:

1. a **Hubitat thermostat poller** reporting `zone{i}-{label}-temp` / `-set`; plus the **sick** `-state`
   channel (kept — see below);
2. **`zone{i}-{label}-whitewire-pwr`** — a DataChannel captured by `power-meter`;
3. **`zone{i}-{label}-heat-call`** — a DerivedChannel (Strategy `heat-call`, created by
   `derived-generator`) computed **from** whitewire-pwr, **not** the Hubitat.

*Why heat-call is derived, not Hubitat-reported.* The Hubitat's `thermostatOperatingState` heat-call
reporting has been **very inaccurate**. The replacement — heat-call derived from whitewire power —
crystallized in Spruce/Nolan, the first site with no Hubitats, which forced deriving it directly. The
derivation already exists in scada: `actors/derived_generator.py` `handle_heat_call` (the `"heat-call"`
Strategy). What's missing is that **no production layout declares a `heat-call` derived channel yet** —
which is exactly the house0 Axiom 3 gap all six fixtures hit. Wiring a per-zone `heat-call` derived
channel closes it and unifies House0 + Nolan on one mechanism.

*Decision on the Hubitat `state` channel (2026-06-16): KEEP it, flag it sick.* Rather than rip out the
`thermostatOperatingState` polling and break dashboard consumers, keep `zone-state` but docstring it in
`ZoneChannelNames` as **sick / unstable — do not trust for heat-call**, while `heat-call` (derived) is
the trustworthy signal. It is **currently still required** (held for back-compat); the direction is to
retire it to known-optional once whitewire-derived heat-call is relied on everywhere. The clean
cross-family modeling ("Hubitat present but NOT the heat-call source" vs Nolan's no-Hubitat) is the
**open puzzle deferred to pass-2**.

## Where "optional" lives — three categories

A layout always tolerates arbitrary experimental / hand-made nodes + channels beyond what the code
reasons about. So channels fall into three kinds:

1. **Required** — the code needs it; a `gw.house0.layout` **sema axiom** demands it.
2. **Optional** — the code knows it, knows it's optional, uses it if present, tolerates absence.
   Example: `buffer-cold-pipe` (missing on some homes for plumbing reasons). A **positive, enumerated**
   category, not merely "not required."
3. **Experimental / hand-made extras** — channels the operational code does not know about. Always
   allowed, never reasoned about; the layout type stays open to them.

Authority splits by question:
- **What is REQUIRED → sema.** The `gw.house0.layout` axioms are the binding contract.
- **What OPTIONAL nodes/channels the code knows about → `gwsproto/names/`.** Being *in* names/ is what
  makes a channel known-optional (vs an experimental extra). The use-it-if-present behavior lives in the
  operational code (the dc loader's `optional_channels` is today's code-side list).
- **Experimental extras → named by no one, required by no one** — the test is simply "is it in names/?"

A conditional axiom MAY still constrain a *known* channel *when present* (e.g. "if `primary-flow` is a
sum DerivedChannel, …"). That is sema constraining the contract, not enumerating optionals.

## Principle — require the semantic aggregate, not the hardware decomposition (the heat-pump case)

`hp-idu` is the cleanest known-optional node: 2-part heat pumps have it, 1-part (maple) don't, and the
layout should NOT encode "is this a 1- or 2-part heat pump?" Instead **require** a derived
**`heat-pump-power`** channel = Σ (all HP-unit power channels), Strategy `sum`, created by
`derived-generator`. `hp-odu`/`hp-odu-pwr` are required; **`hp-idu`/`hp-idu-pwr` become known-optional
in names/**. The summands are the `heat-pump-power` derived channel's `InputChannelNames`
(`[hp-odu-pwr]` or `[hp-odu-pwr, hp-idu-pwr]`) — same pattern as `primary-flow`: require the aggregate,
let the summands be config, tie them with an axiom. (This also fixes the over-strict
`required_topology_nodes`, which wrongly lists `hp_idu` as required.)

## Per-position flow/temperature sourcing — a config axis

At each flow position (`dist` · `primary` · `store` · `sieg`) the flow rate and the two pipe
temperatures come from one of two device kinds:

- **BTU meter** (`layout_gen/btu.py` `add_btu` → `PicoBtuMeterComponentGt`, `ApiBtuMeter`): one device
  bundles **flow + hot temp + cold temp** (+ optional CT), all DataChannels captured by the BTU node.
  Used at `store`/`sieg` in maple.
- **Flow meter** (`layout_gen/flow.py` `add_flow` → `PicoFlowModuleComponentGt`, `ApiFlowModule`,
  Hall/Reed): **flow only** (`*-flow` + `*-flow-hz`); the pipe temps for that position come from the
  **`analog-temp`** TSnap instead. Used at `dist` in maple.

So per position the config picks: BTU-meter | flow-meter + analog-temps | derived (the `primary` sum
case) | absent — the same shape as `PrimaryFlowSource` generalized to every position. The gen takes a
per-position selector and emits the right component + nodes + channels.

## Bottom line

**The gen = emit the invariant skeleton + the four config axes, using the names hierarchy.** Examining
the required sets is also how we catch over-specification (the `hp-idu` case): an entry a real House0
home omits is config-driven, not invariant.
