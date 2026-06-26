# Channel-config overhaul (thin board components)

Status: Accepted · Pass 1 · Updated 2026-06-25 · Linear: OPS-427

**EDD: no** build-out/refactor; verified by the fleet layout round-trip (`sema_gen` + the
dc round-trip green for every home), not a standalone experiment.

> What this is: settle the `channel.config` and board-resident-component shape **while the
> component versions are still unpublished** (mid cac→device-id migration), so the change is an
> in-place edit rather than a future new-version migration. One principle: a channel's *identity*
> comes from its `TelemetryName`; a board-resident component is a *thin pointer* to its board; a
> channel's *routing* comes from the consuming `DerivedChannel.InputChannelNames`. Stop scattering
> identity/routing as flags on components.

## Why now

The components carrying these fields got **new, still-unpublished versions** in the cac→device-id
work. Per immutability (tracks push-to-origin), an unpublished version is **mutable in place** — so
fixing the shape now costs an in-place edit; once published, each becomes a new-version migration
with the full regen tax. Ripping the bandaid while things are already in the air avoids a second
disruptive pass.

## Scope

1. **gw108 opto component → board pointer.** `gw108.gpio.sensor.component.gt`: drop `GpioPin`, add
   **`GpioInputName`** (`pascal.case`, the board's `NativeGpioInput` Name; the `BcmPin` resolves via
   the node's `BoardComponentId → board.NativeGpioInputs[GpioInputName]`). Drop **`SenseMode`** (the
   actor only supports `Polling` and raises otherwise — `gpio_sensor.py:43`; `EdgeDetect` is
   unimplemented). Drop **`SendToDerived`** (see item 3). `DeviceType` becomes a coarse
   `Gw108GpioSensor` value. Add a layout cross-consistency axiom: every opto component's
   `GpioInputName ∈ its board's NativeGpioInputs`. Then `emit_gw108_opto()` in `house0_sema_gen`
   (per opto zone: board device-type + thin opto component `GpioInputName=f"Zone{i}Whitewire"` +
   opto node + `opto-input` DataChannel). This is also what unblocks the gen's `heat_call_source="opto"`
   branch (already wired; its source emitter is this).

2. **`channel.config` drops `Unit` + `Exponent`.** They duplicate the channel's identity, which the
   `TelemetryName` already carries (`TelemetryName` even encodes scaling — `GpmTimes100`,
   `AirTempFTimes1000`, so `Exponent` is redundant too). **Step-0 finding (already verified):**
   `ChannelRegistry.unit()` (`data_classes/hardware_layout.py:71-76`) already resolves a channel's
   unit from `ch.TelemetryName`, **not** from `channel.config.Unit` — so the control/derived path
   needs no new TelemetryName→unit projection. The only remaining consumer to check is the
   **drivers** (does any driver use `channel.config.Exponent` to scale a raw device reading? — that
   is Exponent's one legit job; relocate it if so). Applies across **every** `*.channel.config`.

3. **Kill the source-side routing flags.** `SendToDerived` (consumed at `gpio_sensor.py:47,145`,
   `i2c_thermistor_reader.py:437`) and `InPowerMetering` are both source-side copies of information
   the consuming derived/aggregate channel already owns. The `DerivedChannel.InputChannelNames`
   declares what feeds the derived-generator; `transactive-power.InputChannelNames` declares what is
   metered. So compute the routing from `InputChannelNames` and drop both flags. (Pairs with the
   `transactive-power` decision — see Context above.)

   **`InPowerMetering` lives on two foundational, *published* types**, so this part is genuine
   **version bumps**, not the cheap in-place edits of items 1–2:
   - **`spaceheat.node.gt/303`** — drop `InPowerMetering`; its axiom (`InPowerMetering ⟹
     NameplatePowerW`) goes with it.
   - **`data.channel.gt/003`** — drop `InPowerMetering`; its axiom (`InPowerMetering ⟹ PowerW`) goes
     with it.
   Both are used by every layout, so the bump ripples through the runtime regen and **all** fixtures —
   the fleet round-trip (gate below) is what catches a missed site. This is the most expensive slice;
   gate it on the `transactive-power` decision first.

4. **Transactive audit declaration** — the first-class replacement for `InPowerMetering`'s role. A
   small new sema word (the *audit declaration*) the layout carries **exactly once**, naming: the
   transactive measurement (energy primary), the **inspected meter** it is bound to, and its
   **declared CT inputs** (the boundary). Plus a layout axiom: **exactly one** transactive declaration;
   it resolves to an inspected meter; its inputs resolve to existing channels (the declared CTs).
   *How* the meter binding is expressed (component ref / HwUid / …) is the executing agent's call.
   This is what makes the audited quantity first-class, singular, and auditor-legible — the structural
   job `InPowerMetering` crudely did. The **deeper veracity mechanics** (energy metered from the meter's
   register vs our integral, the committed/signed reported stream, single-CT preference, directional
   combination) stay open in the metering exploration (`explorations/metering.md`) — this slice only
   establishes the declaration word + the singularity/binding axiom.

## Gate

Not "done" until `sema_gen` + the dc round-trip are green for **all** fleet homes — the regen
touches every `channel.config`, so the round-trip is where a missed call-site shows up.

## Context (read these first)

This is a slice of the **hardware-layout-pass-one** design ([OPS-407](https://linear.app/gridworks/issue/OPS-407)). Two pieces of its background
are load-bearing here, so read them before executing:

- **The board-resident-component model** — `executor/hardware-layout.md` "I²C and board-resident
  components": the board (`gw1.scada.device.type.gt`) is the single source of physical truth, and a
  device on it is a thin reference *by Name* (the pin/address lives on the board, resolved via the
  node's `BoardComponentId`). Item 1 applies that model to native GPIO. That section also describes
  the coarse board-resident `gw1.device.type` values (`Gw108Adc` / `Gw108I2cRelay`) minted with the
  I²C actor-layer work; `Gw108GpioSensor` (item 1) is the GPIO sibling, minted the same way.
- **The `transactive-power` decision** — discussed in the hardware-layout-pass-one power-meter
  thread. The proposal item 3 assumes: replace the per-ShNode `InPowerMetering` boolean with a
  layout-declared `transactive-power` DerivedChannel whose `InputChannelNames` is the authoritative
  list of metered channels, **computed by the power-meter actor** (not `derived_generator`, so
  `power.watts` latency is unchanged). It is canonize-worthy on its own.

## Open


- **Driver check for `Exponent`** — item 2 drops `channel.config.Exponent`; verify no driver relies
  on it to scale a raw device reading before removing it (relocate to the channel/telemetry if so).
