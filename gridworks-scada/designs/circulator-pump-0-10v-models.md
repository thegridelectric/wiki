# Circulator pump 0–10 V models

Status: Draft · Pass 0 · Updated 2026-06-07 · Linear: OPS-27

> What this is: a design for representing different circulator-pump make/models
> and their differing 0–10 V control responses across hardware layouts, the
> admin panel, and the Sema type system. Ported from Linear **OPS-27**.

## Problem

We deploy more than one model of circulator pump, and they **respond
differently to the same 0–10 V control signal** — most importantly in what a
**0 V** signal means. Today the system models pumps only implicitly (via the
0–10 V DAC outputs that drive them) and has **no representation of which pump
model is on which output**, nor of each model's 0–10 V response.

This is **not biting us yet** because we do not currently send 0–10 V as part
of process control — the DAC outputs sit at fixed per-pump defaults
(`dfr.py` `DfrConf`: dist 0.30 V, primary/store 0.50 V). The moment process
control starts *modulating* pump speed via 0–10 V, the model differences
become correctness-critical: the same command would drive two pumps to
different (or opposite) behaviour.

Concrete known difference: the **Bell & Gossett Ecocirc 20-18** "switches out
of 0-10V control when sent a 0 V signal" (i.e. 0 V → its own default curve,
*not* off), already noted in the `MakeModel` enum docstring
(`gridworks-protocol/src/gwproto/enums/make_model.py:70`). A Taco/other pump
may instead treat 0 V as off. Sending "0" without knowing the model is
ambiguous.

## Current state (code, 2026-06-07)

- **MakeModel enum** — canonical in Sema:
  `sema/definitions/enums/spaceheat.make.model/007.yaml`; generated to
  `gridworks-protocol/src/gwproto/enums/make_model.py`. Existing pump entries:
  `BELLGOSSETT__ECOCIRC20_18`, `TACO__0034EPLUS`, `TACO__007E`,
  `ARMSTRONG__COMPASSH`. **No Grundfos entry exists.**
- **0–10 V path** — DFRobot DAC component (`DfrComponentGt`, MakeModel
  `DFROBOT__DFR0971_TIMES2`), driven by `ActorClass.ZeroTenOutputer` via
  `AnalogDispatch` messages. Outputs: `dist_010v`, `primary_010v`,
  `store_010v` (`gw_spaceheat/layout_gen/dfr.py:13-78`). Only a raw voltage is
  sent — **no per-model response applied**.
- **Pump make/model is not carried** anywhere on the pump itself. Pumps aren't
  modeled as their own components with a MakeModel; they're implied by the DAC
  output that drives them (and by failsafe relays in `relay.py`).
- **0–10 V response characteristics live nowhere** — only the B&G docstring
  prose; no enum, CAC field, or config encodes "what 0 V means" per model.
- **Admin panel** — `gridworks-admin` DAC widget
  (`watch/widgets/dac_widget_info.py`) shows the channel's voltage state only;
  no make/model. `layout.lite` (v013) carries no pump make/model field.

## Scope of work (the three threads OPS-27 names)

### 1. Represent pump make/models in layouts
- Add the missing pump models to the `MakeModel` enum — at minimum a
  **Grundfos** entry (model TBD; confirm exact part) — via the Sema word
  process (see Implementation).
- Decide how a pump's MakeModel attaches to a layout. Options (Open):
  - **(a)** Model each pump as its own component (a pump CAC + component)
    referenced by the node that the DAC output drives.
  - **(b)** Carry the pump MakeModel as metadata on the existing 0–10 V output
    node / `DfrConfig` channel.
  - Leaning **(a)** — a pump is a real device with a make/model; option (b)
    overloads the DAC channel. Confirm against how other components are modeled.

### 2. Where the 0–10 V response characteristics live
- Add a representation of **0–10 V response type**, keyed to MakeModel. Candidate
  shapes (Open):
  - **(A)** New Sema enum, e.g. `spaceheat.pump.zero.ten.response`, with values
    like `OffAtZero`, `DefaultCurveAtZero` (B&G Ecocirc), `RampFromZero` —
    associated with each pump MakeModel.
  - **(B)** Fields on a pump ComponentAttributeClass (e.g. `ZeroMeans`,
    min/max curve points) — richer but heavier; needs a CAC version bump.
  - **(C)** A standalone `pump.control.profile` type bundling MakeModel +
    response + curve.
  - **(D)** **Structured-enum metadata on `MakeModel`** — if/when Sema gains
    the proposed *structured enums* capability (enum values carry typed
    metadata that codegen emits; being designed in a separate thread, with
    `market.type.name` as its first user; precedent: Sema's existing enum
    flavours literal-vs-versioned). Each pump `MakeModel` value would carry its
    own `zero_ten_response` (and later curve params) directly, so make/model and
    0 V semantics are a single source of truth with no parallel enum + mapping
    table. **Likely the cleanest long-term home** — make this the preferred
    direction *if* the structured-enums feature lands; (A) is the fallback that
    needs no new Sema capability.
  - Recommendation: pursue **(D)** if structured enums ship on a compatible
    timeline; otherwise **(A)** for the discrete "what does 0 V mean" semantics
    (the immediate correctness need), leaving curve detail to a later
    CAC/profile if modulation needs it.
- Whatever the shape, the `ZeroTenOutputer` / process-control path must consult
  it before emitting 0 V, so "0" resolves to the right physical effect per pump.

### 3. Surface pump info in the admin panel
- Extend `layout.lite` to carry pump MakeModel (+ response type) so operators
  can see what's installed.
- Update the admin DAC widget (`dac_widget_info.py`) to display pump
  name + model alongside the voltage.

## Open questions

- Exact Grundfos model(s) in the field, and their 0 V semantics — needed before
  adding the enum value.
- Layout attachment shape — pump-as-component (a) vs DAC-channel metadata (b).
- Response representation — enum (A) vs CAC fields (B) vs profile type (C) vs
  structured-enum metadata (D). **Cross-thread dependency:** (D) depends on the
  Sema *structured enums* capability (separate design); track its timeline
  before committing to (D) over (A).
- Do we need a full speed/flow **curve** now, or only the discrete 0 V semantics?
  (Driven by whether near-term process control will modulate pump speed.)
- Is a `default` response value safe, or must every pump model be explicit
  (fail-closed) before any 0–10 V modulation ships?

## Implementation notes

- **No code yet.** Per the wiki implementation gate, this design must reach
  `Accepted` (Pass ≥ 1) on every spoke before scada/sema edits matching its
  scope begin.
- **Any Sema change** (new `MakeModel` value, new response enum, CAC field) goes
  through `/make-sema-word` — read `sema/CLAUDE.md` and follow it verbatim;
  enums are additive, TypeName/Version immutable, runtime is regenerated, not
  hand-edited.
- Touch points span three repos: `sema` (enum/type), `gridworks-protocol`
  (regen + CAC mapping `cacs_by_make_model.py`), `gridworks-scada`
  (`layout_gen/`, `ZeroTenOutputer`, `gridworks-admin`).
