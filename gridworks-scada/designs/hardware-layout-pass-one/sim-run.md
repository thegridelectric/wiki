# Minimal House0 sim-run — the safety net (active spoke)

Status: Accepted · Pass 1 · Updated 2026-06-27 · Linear: OPS-407

> What this is: the cheapest high-value move in pass one. Before the layout rewrite touches ~76
> call-sites, stand up a test we don't have today — the scada **boots a House0 layout and runs every
> device code path** with self-faking device actors (no broker, no plant). Build it against the
> **existing** fixtures first, so it is a regression net the rewrite verifies *through*. The richer
> coherent plant stays sim-test-environment work ([OPS-40](https://linear.app/gridworks/issue/OPS-40)).

## Why this is first

We have no good way to test the existing scada code — only real hardware (slow, one house at a time)
or partial unit tests. Pass one rewrites how layouts are built (sema-authored, `sema_to_dc`) and will
move ~76 call-sites onto `self.hydronic.*`. Doing that blind is the risk. A House0-replicating sim-run
makes the change **behaviorally verifiable**: if the scada boots House0 and every device actor's code
path executes without crashing, the rewrite is safe to be un-fussy about static fixture equality.

So the order is: **net first, rewrite under it.** Build the boot against today's fixtures (proves it
works on known-good layouts), then re-run it after each rewrite step.

## Scope — minimal, not the coherent plant

Borrow the sim-test-env **self-faking-actors** model (the cheap precursor to the plant): the real
device actors (`ApiTankModule` / `ApiBtuMeter` / `ApiFlowModule`, the poller) self-generate fictitious
input on a timer — no plant process, no broker — so a simplified sim House0 exercises the device code
paths. Durable harness facts live in [`../../executor/testing.md`](../../executor/testing.md)
("The harness", `ScadaLiveTest`); this spoke scopes only the **House0-boot** slice.

**The sim layout — `gw1.simple.sim.layout` (decided 2026-06-27).** The simulated stand-in for House0 is
authored as its **own word, `gw1.simple.sim.layout`** — **NOT** shoehorned into `gw.house0.layout`. It
replicates House0's device code paths for testing without claiming to be a House0 layout, so
`gw.house0.layout` keeps its real shape (buffer required). Shape: **no buffer tank, a single storage
tank**, **relays (and what they do) left out** initially — the smallest hydronic shape that still runs
the temperature / flow / power device paths. Build most of it now; layer the relay paths in after the
boot works.

**In scope (pass one):**
- The simplified sim House0 layout loads and the scada actor tree starts.
- Each non-relay device actor runs its read/derive path on self-faked input without crashing.
- A single witnessed "House0 booted + ran N device cycles" assertion — the behavioral gate.

**Out of scope (stays OPS-40):** the coherent `sim.plant.flux` plant, broker transport, sim-time
coordinator stepping, the multi-house hybrid rig, chaos/poison levers; and (initially) the relay
actuation paths.

## LocalControl + "turn on the heat pump" — a documented fake first

The *meaningful* test of control is "can LocalControl turn on the heat pump." In the real code that is a
**relay actuation**: `actors/hp_boss.py` closes `hp-scada-ops-relay` (House0 relay6) to turn the heat
pump on (and opens it to turn off); `actors/sh_node_actor.py` exposes the relay accessors
(`hp_scada_ops_relay`, `hp_failsafe_relay`, `store_charge_discharge_relay`); `actors/local_control/` is
the coordinating actor. So a real control test needs the relay path — which the minimal boot defers.

**Decided (2026-06-27) — fake-first.** Rather than wire the full relay-actuation path now, **add a fake
into LocalControl that does very little (or nothing)** — just enough to start the actor tree and let us
iterate — **with a docstring saying exactly that** (a sim placeholder; the real relay-actuation control
lands by iteration). This honors "err simpler, leave a question": the boot is unblocked, and the
heat-pump-control behavior is grown incrementally against a running rig rather than built up-front.

**Deferred to iteration (not boot blockers):** the relay actuation path; the LocalControl→`hp_boss`→
`hp-scada-ops-relay` "turn on the heat pump" capability; and the **layout axiom names** that bind it —
e.g. a House0 axiom guaranteeing the heat-pump-control relays exist with the right `WiringConfig`,
mirroring nolan's `VdcRelaySemantics` / `ElementRelaySemantics` / zone failsafe-ops relay-semantics
axioms (the stub-existence pattern, [`axioms.md`](axioms.md)). Decide those names when the relay path
is iterated in, not for the boot.

## Open / next move

- **Re-orient (do this next):** inventory what the scada needs to boot a `gw1.simple.sim.layout`
  in-process with self-faking device actors — the actor factory seam, which device actors need a
  self-fake branch, where the LocalControl fake slots in, and whether `ScadaLiveTest` already gets us
  most of the way. Produce the smallest "boots + runs N cycles" script.
- Coordinate with sim-test-environment's `self-faking-actors` work so the two don't duplicate the seam
  — the minimal slice here should be a subset that the fuller spoke later subsumes.
