# Metering — the transactive measurement and its veracity

Status: Draft · Pass 0 · Updated 2026-06-25

> What this is: an open exploration of how the **transactive measurement** (the energy/power the
> market settles on) is defined in a layout and how its veracity is established. Not yet a ratified
> plan — it frames the trust model, what's settled, and the open shape questions, to be grilled into
> a design before any sema word is cut. Connects to the cryptographic-veracity / distributed-trust
> core vision (`wiki/vision/`).

## The trust model — audit, not prevention

Our software **is** in the measurement path, deliberately. Veracity does not come from making the
source cryptographically unforgeable; it comes from **independent audit**: a trusted validator
randomly spot-meters with their own instruments and **reconciles their data against ours
after-the-fact**. So two jobs, cleanly split:

- **Cryptography = commitment + attribution, not correctness.** The reported transactive stream is
  signed and tamper-evident (append-only / hash-chained), so we can't report one thing and later
  claim another, and the validator knows whose record they are checking. The signature commits us to
  a record; it does not prove the record is true.
- **The spot-check = correctness.** The validator's randomized independent metering + reconciliation
  is what catches divergence. Cheating is detected and deterred (reputation, contract), not prevented.

Inspection and spot-check are two phases of the same trust: the third party's **inspection** certifies
the meter is a known, calibrated device (the baseline honest numbers should match); the randomized
**re-check** is the ongoing verification.

## Energy is primary, and it's metered — not integrated

The settled quantity is **transactive-energy** (kWh), with transactive-power as the instantaneous
companion (control / dispatch / observability). Energy SHALL be read **directly from the meter's
cumulative register**, not computed by integrating our power samples — our integral is degraded by
the async-capture threshold (we only record power past `AsyncCaptureDelta`, dropping sub-threshold
drift and timing), while the meter's accumulator counts every joule in hardware. It also makes
reconciliation **register-against-register** (apples-to-apples), instead of the validator's register
against our integral-of-samples (which bakes our sampling error into the comparison).

This is **new vocabulary**: today we meter power and *derive* `usable-energy` / `required-energy`, but
those are **model** energy (storage state), not **metered** energy. No channel reads the meter's kWh
register at all. This adds metered-energy channels (`transactive-energy`, likely per-CT energy too) on
a cumulative-WattHours telemetry, plus the meter actor learning to query the register.

## The metered object is a mechanism, not a sensor

What gets audited is not one physical device but the **whole summation mechanism**: which CTs, with
what **directional** polarity (export netting against import — *directional*, the ± sense, not the
crypto sense), accumulated to energy. Change which CTs are in the combination, or flip a polarity, and
you have changed the audited quantity — which is exactly why the combination rule has to be first-class
and hard to change: it *defines* what is measured. (This is the principled replacement for the crude,
scattered `InPowerMetering` boolean — see OPS-427.)

Ideally the directional combination happens **inside the inspected meter** (a single net register), so
even the summation lives in audited hardware and transactive-energy is a single directly-metered
channel. When the meter exposes only per-CT registers, our software does the directional combine and
the audit covers that step.

## The invariant that MUST hold — auditor legibility

Whatever the shape, the layout MUST make the audited quantity **unambiguous to the validator**: a
single declaration naming the boundary (the exact CT set + directional rule), bound to the specific
inspected meter, so the validator meters *the same boundary* and compares like-for-like. Ambiguity in
what "transactive" means is ambiguity in the reconciliation. Legibility is the invariant; everything
below is negotiable.

## Open questions

- **Single CT for the whole asset — insist, or strong preference?** The field has separate IDU/ODU
  CTs, so insisting on one CT would exclude real hardware. Lean: **strong preference** for a single net
  register (cleanest trust path), **not** a hard requirement — the MUST is legibility, not
  single-sensor.
- **Channel shape.** The value channel is a `DataChannel` when the meter gives a net register, a
  `DerivedChannel` (directional combine of per-CT energy registers) when it doesn't — both fine in the
  audit model. The first-classness comes from an **axiom** (exactly one transactive-energy, bound to
  the inspected meter, inputs = the declared CTs), not from a special value type. Does it *also* want a
  small **audit-declaration** word that points at the channel + meter + boundary (the thing the
  validator locks onto), distinct from the value channel itself? **Decided → OPS-427:** yes — the small
  audit-declaration word + the singularity/binding axiom (exactly one, bound to the inspected meter,
  inputs = declared CTs) is being built in OPS-427 as the first-class replacement for `InPowerMetering`.
  Its job is *declaration/provenance*, not reimplementing the channel. The deeper mechanics below stay
  open here.
- **How the committed stream attaches** — the append-only / hash-chain mechanism over the reported
  transactive readings (so after-the-fact comparison is against a fixed record). The SCADA's **signing
  identity** for that stream is its provisioned **client cert** (mTLS + FIS, OPS-420), baked into the
  SD-card image at provisioning (imaged once, certs baked in). So this part **rides with OPS-420 + the
  provisioning client-cert path** rather than inventing its own identity layer.

## Sequencing

OPS-427 takes only the **structural, identity-agnostic** part of this exploration: the audit-declaration
word + the singularity/binding axiom (what the transactive quantity is, which meter, which CTs). The
**deep veracity** part — the signed/committed/attributable reported stream, and energy-metered-from-
register — is deferred to **ride with OPS-420 (mTLS + FIS) + the provisioning client-cert path**, since
its signing identity *is* the SCADA's provisioned client cert. Suggested order: **OPS-427 first**, then
the next pass grills this exploration into a design alongside OPS-420.
- **Per-CT energy channels** — do we carry per-CT energy registers as their own channels (useful for
  the analytical breakdown and for the directional combine), or only the net?
- **Energy + power, one word or two** — transactive-energy is primary; how does transactive-power
  relate (same declaration, companion channel)?

## Not in scope here

The per-component analytical breakdown (`heat-pump-power`, resistive, etc.) is a separate, derived,
*non-settled* concern. This exploration is only about the **settled, audited** transactive measurement.
