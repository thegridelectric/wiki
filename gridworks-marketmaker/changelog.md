# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-marketmaker` code repo**. The matching git commit holds the
WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits.


## <!-- pending commit --> 2026-11-15 — The slot's price is its first 5-minute interval, published when ISO-NE posts it (jm/price-at-slot-open, OPS-666)

**Why.** The maker fetched ISO-NE's current 5-minute LMP 20 s before
the hour and published it at the top of the hour, so every slot's
wholesale price was the previous hour's :55 interval. A check of
2026-11-15 against ISO-NE's posted prices for Keene Rd showed exactly
that: each published wholesale part equalled the :55 sample, and the
first hour missed ISO-NE's hourly real-time LMP by 20 USD/MWh because
the hour opened with a spike the :55 sample came before. The market's
real-time hourly price is defined as the hour's first 5-minute price,
the interval that begins as the slot opens. ISO-NE posts an interval
about 25 s after it begins (measured 2026-11-15 at the 09:45 and 09:50
boundaries: 23.5 s both times, by polling `fiveminutelmp/current` once
a second), so the gate now asks on every tick (1 s) from the top of the
hour until the current interval is the slot's own and publishes on it; `fetch_deadline_s` (240 s) without it
publishes stale with the critical glitch as before. `fetch_lead_s` is
gone. The README names the A-1 tariff sheet it copies.

## <!-- pending commit --> 2026-11-15 — README to the repo pattern; module docstrings to the documentation convention (jm/readme-executor, OPS-617)

**Why:** the executor's Domain Summary is copied verbatim from the
README, so the README comes first: a summary for a person with no code
words, box names or paths, then what the maker speaks and how it runs,
install last. Docstrings stop narrating literals the executor's
Boundaries rows now own (the tariff table, the routing key) and state
each module's purpose for a reader who has not read the code.

## 2026-11-15 — upgrade to 0.7.3 gwbase (`b393fa0`, merge of jm/log-tz, PR #81)

**Why:** gwbase 0.7.3 renders log timestamps in a configured zone
(`log_tz`), and the maker's hour is the market's hour; `template.env`
sets `GWMM_LOG_TZ=America/New_York` so a log line and a slot name read
on the same clock.

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
