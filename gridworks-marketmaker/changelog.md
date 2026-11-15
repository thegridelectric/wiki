# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-marketmaker` code repo**. The matching git commit holds the
WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits.


## 2026-11-14 — latest.price 001: the price in its parts, delivery at latest Versant A1 (`db25c3f`, squash of jm/latest-price-001, PR #80, OPS-666)

**Why:** the price the LTN faces is the sum of parts that settle with
different counterparties, and `latest.price` 000 gave no way to recover
them. The maker now publishes `latest.price` 001: the ISO-NE five-minute
LMP's energy, congestion and loss components as three `WholesaleEnergy`
/ `WholesaleCongestion` / `WholesaleLoss` parts, the Versant A-1
delivery price as the `Delivery` part with `TariffAlias`
`versant.a1.home.eco.bonus`, and the price as their exact integer sum.
Prices travel as integers times 1000 from the ISO-NE parse onward, so
the sum axiom holds by construction. The A-1 table moves to the
Seventeenth Revision (effective 2026-07-01), the same numbers the
price-forecast service uses, so a realized price and its forecast agree
on delivery. The stale-fetch fallback republishes the last wholesale
parts with the hour's delivery price, as before. `gwmm show` prints the
parts.

## 2026-11-04 — The maker declares GwGNodeClass.MarketMaker; ci.sh is the one gate (`4f02d29`, PR #79 `28e45fa`)

gridworks-base 0.7.1 makes `GridworksActor` take its class from
`gw.g.node.class`, check the identity file against it at boot and derive
its transport class from it. The maker passes `GwGNodeClass.MarketMaker`
and nothing else about its class, and pins the new gwbase; the
enum is imported from gwbase's snapshot, not seeded here. The gate
follows sema and gjk: `ci.sh` owns the steps and exports the dev broker
URL when a broker answers on 5672, so the broker test runs locally as in
CI; the workflow is checkout, uv and `./ci.sh` with the dev-rabbit
service; `ruff check` runs with `--no-fix`.

## 2026-10-22 — The maker publishes only at the top of the hour (`4ab796e`, OPS-615)

A maker that boots mid-slot no longer publishes for the open slot; its
first publish is the next top of the hour. The LTN clears against a
price only when its bid is in, at the top of the hour, and holds its
running contract across a restart from `slow_dispatch_contract.json`,
so a mid-hour price has no reader. The dev run showed the boot publish
as a second `latest.price` for the 11:00 slot with a different LMP than
a top-of-hour publish would have had; one price per slot is the rule
the stopgap keeps.

## 2026-10-22 — launch stopgap marketmaker 2026-2027 season (`3e28a96`, OPS-615)

The repo is gutted and rebuilt on gwbase 0.6 and uv, as the launch
design locked. What remains is one gwbase actor with the MarketMaker
transport class that publishes `latest.price` for the Keene `rt60gate5`
slot at the top of every hour, as the broadcast
`rjb.<maker-alias>.mm.latest-price`: ISO-NE's current 5-minute LMP at
Keene Rd plus the Versant A-1 delivery price for the hour. When ISO-NE
does not answer, it publishes the last price and raises a Critical
glitch. Bids are received and dropped. The first-pass simulation code
that never ran, its XSLT code generation, poetry and docs are gone; the
old repo is in git history as design intent.
