Status: Draft · Pass 0 · Updated 2026-06-07

> What this is: the sub-spec for **metering topology** in the
> Economy Energy Market System. Refines invariant 15 in
> [`primary.md`](primary.md) with the placement-evolution path,
> cost-engineering targets, lower-friction-onboarding consequences,
> and the deliberately-open question of how per-TerminalAsset
> sub-metering is realized for multi-TA homes.

## Three things this domain meters

1. **Master economy meter.** The TaReader-read meter that
   captures the total economy-energy load behind a TaOwner's
   installation. Revenue-grade (ANSI C12). Its interval data
   is the III.6.4(f) AMR submission to ISO-NE; it is what the
   CEP is settled at LMP × Actual against.
2. **Per-TerminalAsset metering.** Required for per-asset market
   participation. When N = 1 TerminalAsset, the master economy
   meter IS the per-TA meter. When N > 1, each TerminalAsset
   needs its own sub-meter so the Cleared Market can bid them
   separately. *How* the sub-metering is realized at N > 1 is
   deliberately not pre-committed — see "Open question" below.
3. **Internal monitoring meters (NOT market-facing).** For
   heat-pump-thermal-storage installations, an extra CT inside
   the panel that distinguishes the heat-pump compressor from
   the resistive backup is typically included for **COP
   accounting** (Coefficient of Performance — system efficiency
   monitoring). This CT is *internal monitoring*, not market
   data; only the master meter feeds the market.

## Master economy meter — v1 commitment

The v1 master economy meter is the **EKM Omnimeter**. This is
committed externally in the 2026-06-05 letter to ISO-NE
([`../../../dera-stand-up/letter-to-iso.20260605.md`](../../../dera-stand-up/letter-to-iso.20260605.md))
as the revenue-grade meter GridWorks will install behind the
Versant bonus meter.

## Placement evolution

The master economy meter's *placement* evolves with the
regulatory landscape:

- **Today (III.6.4(d) parallel metering).** The master economy
  meter installs on a **physically separate service entrance**,
  in parallel to Versant's existing bonus meter (which Versant
  uses for the Rate A-1 TOU economy-energy billing). Two service
  entrances, two meters reading the same economy-energy load,
  one Versant-owned and one TaReader-read. This is the v1
  configuration; it requires Versant to do nothing operationally
  beyond providing the one-time III.6.4(e) class-letter
  confirmation. Cost: ~$1500/home for the parallel service
  drop + Versant bonus meter.
- **Future (once Versant reconstitution arrives).** The master
  economy meter becomes a **sub-meter** behind the main service,
  eliminating Versant's separate bonus meter and the extra drop.
  Saves ~$1500/home in install cost. Reconstitution timeline
  is uncertain (3–10 years).

Architecture works at both stages; reconstitution is a cost-
reduction bonus, not a dependency.

## Lower-friction onboarding (consequence of per-TA metering)

Once a home has the master economy meter (today via parallel
service, future via sub-meter), adding a new TerminalAsset is
a **lower-friction operation** than the legacy alternative:

- Install a sub-meter for the new TerminalAsset.
- TaValidator attests to the three architectural facts (asset
  type, GPS location, meter accuracy — see invariant 8 / actors.md).
- The new TerminalAsset is now a distinct market participant
  via its own LTN.

No change to the utility relationship, no change to the CEP
relationship, no new service drop. This is how the architecture
scales from one heat-pump-TS system to a panel-full of flexible
loads as the home's flexible-load count grows.

## Open question — how to sub-meter multi-TA homes

The architecture deliberately does NOT pre-commit to how per-TA
sub-metering is realized for homes with multiple TerminalAssets.
Options to keep open:

- **Panel-side per-circuit sub-meters.** The Economy Panel
  (or equivalent) carries one sub-meter per dedicated circuit
  inside the panel enclosure. No appliance OEM dependency.
- **Appliance-embedded sub-meters.** Heat-pump / HPWH / EV-charger
  / battery OEMs ship embedded sub-meters as a standard feature.
  Forward-looking cost target: ≤$15 per meter at OEM volume.
  Removes the per-circuit sub-meter cost from the panel BOM but
  depends on OEM adoption.
- **Hybrid approaches.** Panel-side for some loads,
  appliance-embedded for others.

When real v2+ deployments with multiple TerminalAssets behind one
master meter arise, the right approach (and the right protocol
for sub-meter data integration with the TaReader) will be
decided empirically. The architecture's commitment is to *not
pre-commit*.

The cost-engineering target (≤$15 appliance-embedded) is recorded
here as a long-term aspiration, not a v1 architectural commitment.

## COP accounting — the heat-pump-TS-specific CT

Heat-pump-thermal-storage systems have two distinct electrical
loads: the heat pump compressor (COP > 1, depending on conditions)
and the resistive backup elements (COP = 1). For **system-level
efficiency monitoring** — homeowner-facing dashboards, service
diagnostics, contractor evaluation — it is useful to know how
much electricity went to each.

The architecture allows for an **extra CT inside the panel** to
distinguish heat-pump from resistive consumption for this
purpose. This CT is *internal monitoring data*, not market-
facing data. The master economy meter still measures the
aggregate; the market still bids the aggregate; the COP CT
just enables an analytics overlay.

## See also

- Invariant 15 in [`primary.md`](primary.md) — the architectural
  commitment this sub-spec refines.
- [`../../economy-panel/executor/primary.md`](../../economy-panel/executor/primary.md)
  — the open-source residential smart panel architecture, which
  encloses an EKM Omnimeter and (for v2+) provides whichever
  panel-side sub-metering approach gets adopted.
- Invariant 2 in [`primary.md`](primary.md) — the CEP-settlement
  rule that the master economy meter feeds.
