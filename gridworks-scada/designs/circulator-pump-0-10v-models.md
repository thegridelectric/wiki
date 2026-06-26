# Circulator pump 0–10 V models

Status: Draft · Pass 0 · Updated 2026-06-15 · Linear: OPS-27

> What this is: a design for representing the different circulator-pump models we deploy —
> as **device types** — and their differing 0–10 V control responses across hardware layouts,
> the admin panel, and the Sema type system. Ported from Linear **[OPS-27](https://linear.app/gridworks/issue/OPS-27)**. (Reworked
> 2026-06-15 onto the `DeviceType` model after `MakeModel` was retired.)

## Problem

We deploy more than one model of circulator pump, and they **respond differently to the same
0–10 V control signal** — most importantly in what a **0 V** signal means. Today the system
models pumps only implicitly (via the 0–10 V DAC outputs that drive them) and has **no
representation of which pump is on which output**, nor of each pump's 0–10 V response.

This is **not biting us yet** because we do not currently send 0–10 V as part of process
control — the DAC outputs sit at fixed per-pump defaults (`dfr.py` `DfrConf`: dist 0.30 V,
primary/store 0.50 V). The moment process control starts *modulating* pump speed via 0–10 V,
the model differences become correctness-critical: the same command would drive two pumps to
different (or opposite) behaviour.

Concrete known difference: the **Bell & Gossett Ecocirc 20-18** "switches out of 0-10 V control
when sent a 0 V signal" (i.e. 0 V → its own default curve, *not* off). A Taco/other pump may
instead treat 0 V as off. Sending "0" without knowing the pump is ambiguous — and "what 0 V
means" is precisely the kind of **category-level fact the code must branch on**, which is what a
device type exists to carry.

## Why pump models are device types (the reframe)

These are **classes of pump with different behavior according to the code** — so they are
**different `DeviceType`s** (`gw1.device.type` values), not rows in a retired make/model enum.
This fits the device-type model **better**, two ways:

- **`DeviceType` is a code class, not a manufacturer part number** (`executor/components.md`).
  We name the class the code treats distinctly — B&G-Ecocirc-style "0 V = default curve" vs
  Taco-style "0 V = off" — and mint a `DeviceType` per *distinct behavior*, not per SKU. Pumps
  whose code handling is identical share one device type.
- **The 0–10 V response is category-level data → a specialized `*.device.type.gt` record.** A
  device type earns a specialized record exactly when it carries info the code needs (the
  `ads111x.based.device.type.gt` / `electric.meter.device.type.gt` pattern). A pump's 0 V
  semantics (and later its speed/flow curve) are that data, so a `circulator.pump.device.type.gt`
  record is its natural home — one source of truth, no parallel enum + mapping table. (This
  retires the old "structured-enum metadata on MakeModel" option — the device-type record *is*
  the structured representation.)

## Current state (code, 2026-06-15)

- **Pump models existed as `MakeModel` values** (`BELLGOSSETT__ECOCIRC20_18`, `TACO__0034EPLUS`,
  `TACO__007E`, `ARMSTRONG__COMPASSH`; **no Grundfos**). With `MakeModel` retired (frozen
  `spaceheat.make.model`, `replaced_by: gw1.device.type`), these become `gw1.device.type` values
  for the pump classes. The B&G 0 V-default behavior, today only prose in the old make-model
  docstring, has nowhere structural to live — it moves onto the pump device type.
- **0–10 V path** — DFRobot DAC component (`dfr.component.gt`, `DeviceType` `DfrobotDualAnalogOut`),
  driven by `ActorClass.ZeroTenOutputer` via `AnalogDispatch`. Outputs `dist_010v`, `primary_010v`,
  `store_010v` (`gw_spaceheat/layout_gen/dfr.py`). Only a raw voltage is sent — **no per-pump
  response applied**.
- **The pump is not carried** anywhere on the pump itself — no pump component, no device type;
  it's implied by the DAC output that drives it (and by failsafe relays in `relay.py`).
- **0–10 V response characteristics live nowhere** — no enum, record, or config encodes "what
  0 V means" per pump.
- **Admin panel** — `gridworks-admin` DAC widget (`watch/widgets/dac_widget_info.py`) shows the
  channel's voltage state only; no pump identity. `layout.lite` (v013) carries no pump field.

## Scope of work (the three threads [OPS-27](https://linear.app/gridworks/issue/OPS-27) names)

### 1. Represent pump models as device types in layouts
- Mint a `gw1.device.type` value per distinct pump class (start from the four pump make/models
  above + a **Grundfos** class, model TBD; confirm the field part) via `/make-sema-word`. One
  value per *distinct 0–10 V behavior*, not per SKU.
- Model each pump as its **own component** carrying its `DeviceType`, referenced by the node the
  DAC output drives. (This is the old option (a); option (b) — pump metadata on the DAC channel —
  is dropped: it overloaded the DAC channel and predates pumps having their own device type.)

### 2. Where the 0–10 V response lives — a specialized pump device-type record
- Add a **`circulator.pump.device.type.gt`** specialized record (the
  `ads111x.based.device.type.gt` pattern), keyed by the pump's `DeviceType`, carrying its 0–10 V
  response. The immediate correctness need is the discrete **"what does 0 V mean"** semantic — a
  small enum field (e.g. `ZeroMeans`: `Off`, `DefaultCurve`, `RampFromZero`); the speed/flow
  **curve** params can be added to the record later if modulation needs them.
- The `ZeroTenOutputer` / process-control path must **consult the pump's device-type record**
  before emitting 0 V, so "0" resolves to the right physical effect per pump.

### 3. Surface pump info in the admin panel
- Extend `layout.lite` to carry the pump `DeviceType` (+ response) so operators can see what's
  installed.
- Update the admin DAC widget (`dac_widget_info.py`) to display pump name + device type alongside
  the voltage.

## Open questions

- Exact Grundfos model(s) in the field and their 0 V semantics — needed before minting the device
  type (and to decide whether it's a *distinct* behavior class or shares one).
- Granularity of the device-type split — one `DeviceType` per distinct 0 V behavior is the bar;
  confirm which of the four current pumps actually differ in code handling vs share a class.
- Do we need a full speed/flow **curve** now, or only the discrete 0 V semantics? (Driven by
  whether near-term process control will modulate pump speed.) The curve, when needed, is more
  fields on `circulator.pump.device.type.gt`.
- Is a `default` response safe, or must every pump device type be explicit (fail-closed) before
  any 0–10 V modulation ships?

## Implementation notes

- **No code yet.** Per the wiki implementation gate, this design must reach `Accepted` (Pass ≥ 1)
  on every spoke before scada/sema edits matching its scope begin.
- **Any Sema change** (new `gw1.device.type` pump values, the `circulator.pump.device.type.gt`
  record, the `ZeroMeans` enum) goes through `/make-sema-word` — read `sema/CLAUDE.md` and follow
  it verbatim; enums are additive, TypeName/Version immutable, runtime regenerated not hand-edited.
- Touch points span the repos: `sema` (the pump device types + specialized record + response enum),
  `gridworks-scada` (`layout_gen/`, the pump component + `ZeroTenOutputer` consult, `gridworks-admin`).
