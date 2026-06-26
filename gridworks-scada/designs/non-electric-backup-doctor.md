# Non-electric backup doctor

Status: Draft · Pass 0 · Updated 2026-06-22 · Linear: OPS-215

**EDD: yes** verified by an experiment that simulates a dead boiler (no power /
no temperature response) and asserts the system keeps the heat pump rather than
stranding the house — plus a healthy-boiler run where the probe passes.

> What this is: a procedural diagnostic that verifies the non-electric backup
> heat path (the oil boiler) is actually producing heat, **and** the failsafe
> policy that consumes that signal so local control / LeafAlly never drop the
> heat pump onto a dead boiler.

## Current behavior (verified 2026-06-22)

The HP→boiler handoff is **blind to boiler health**:

- `local_control/tou_base.py`: after `SYSTEM_COLD_MINUTES = 5`,
  `time_to_trigger_system_cold` → `trigger_system_cold_event()` → top-state
  `UsingNonElectricBackup`; `backup_actuator_actions` (L446-460) does
  `hp_failsafe_switch_to_aquastat` + `aquastat_ctrl_switch_to_boiler` — the HP
  comes off SCADA control and the house rides entirely on the boiler.
- **Nothing reads the boiler's output to confirm it is producing heat** (a
  grep for any boiler-working / temp / pwr check in `local_control/` is empty).
  If the boiler is dead, the house is stranded with no heat.
- LeafAlly (`leaf_ally/all_tanks.py`) has its own parallel oil-boiler path
  (`OilBoilerOn` contract; the aquastat failsafe "only go here if scada is
  dead").

## Scope

**Detection — the doctor (was [OPS-215](https://linear.app/gridworks/issue/OPS-215)):** a procedural, non-transactive probe of
backup-heat readiness.

- Trigger on a semi-fixed schedule **and** asynchronously (to re-confirm after a
  temporary failure).
- Emit glitches (warning → critical) on failure; a successful test resets the
  failure counter.
- **Signal selection (Open):** oil-boiler-pwr draw? a tank/SWT temperature rise
  after switching the aquastat to boiler? flow? Clarify.
- Formalize that the boiler runs on a third-party (Johnson Controls) aquastat at
  an unknown, possibly-low setpoint — testing may require intentionally letting
  the buffer get colder than HomeAlone/LeafAlly would normally allow.
- Can it run without interfering with a dispatch contract?

**Policy — don't strand the house (folded from [OPS-258](https://linear.app/gridworks/issue/OPS-258)):** when entering
`UsingNonElectricBackup`, if the boiler is **not confirmed working** (per the
doctor's signal / failure counter), do **not** take the HP off SCADA control —
keep or return to the heat pump. A struggling HP beats a dead boiler when the
buffer is cold.

**Share cleanly between LocalControl (HomeAlone) and LeafAlly (AtomicAlly)** —
both backup paths consume the same readiness signal and policy.

## Open

- Exact health signal + the confirm/timeout window.
- How the policy interacts with onpeak (do we run the HP onpeak when the boiler
  is dead, despite the price?).
- Testing without stranding the house or interfering with a live contract.

## EDD experiment

Simulate a dead boiler (no pwr / no temperature response) and assert the system
keeps the HP rather than stranding; a healthy-boiler run where the probe passes
and resets the failure counter. The re-runnable reproducer behind the eventual
`Verified` stamp.
