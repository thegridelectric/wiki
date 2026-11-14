# Changelog

A reverse-chronological log of WHY we made each change **in the
`gridworks-price-forecast` code repo**. The matching code-repo commit
holds the WHAT (the diff). Each entry's date and one-line title mirror
that commit.

Newest at the top.

## 2026-11-13 — One price per hour in the forecast (`666b858`, jm/price-components, OPS-666)

**Why.** The FLO optimizes against the sum of the price lists and makes
no decision on how the price divides, so `gw.price.forecast` became one
price list in sema and the service follows.

- The snapshot spells the list `PriceX1000List`, sema's name for it,
  and takes `gw.market.product.name` 001 (`rt60gate1`). The service, the
  scada's LTN and the LTN port deploy in one cutover, after the words are
  promoted.
- An hour's forecast price is the day-ahead LMP plus the delivery
  price. The fetch reads ISO-NE's total LMP again; the tariff alias
  setting is gone with the field.
- The ISO-NE posting a document was built from, and how many of its
  hours are ISO-NE's own, are kept in a file beside the document. No
  word states a forecast's basis yet; the record names the basis word
  that would retire it. The watcher reads the posting from that file to
  tell whether ISO-NE has posted again.
- A kept file the snapshot cannot decode is ignored and rebuilt. The
  dev run found the actor dying at boot on a kept file in the earlier
  shape, because the snapshot's decode error is not a `ValueError`. A
  test reproduces it.

## 2026-11-12 — Serve and broadcast gw.price.forecast, one per ISO-NE posting (`0d52fcf`, jm/price-components, OPS-666)

**Why.** The stopgap service rebuilt its forecast on every hour's first
request and minted a new id each time, so nothing could say which
forecast a FLO ran on, and nothing was journaled. The visualizer's price
panel needs the forecast in force at a past hour, which means each
forecast has to exist once, with a stable id, on the bus.

- The service asks ISO-NE's `/info` what has been posted, every five
  minutes from 12:30 Eastern until tomorrow's prices appear and hourly
  otherwise, and builds one forecast document per posting.
- A document is 72 hours; the HTTP view is its next 48 hours under the
  same id, so every value an LTN pulls is in the broadcast document.
- The service is a gwbase GNode actor (`gwpf rabbit`) that broadcasts
  each new document on the radio channel named for the market. The read
  API serves the kept document and never calls ISO-NE.
- The word is `gw.price.forecast`, vendored from sema staging; the
  stopgap word is gone from the repo. The forecast states the price in
  its wholesale and delivery parts.
- The A-1 delivery table is at the Seventeenth Revision (effective
  2026-07-01), with a note naming the missing tariff word.
- The default alias is `d1.price`, a service directly under its
  universe root.

## 2026-10-20 — stopgap price forecast service (`41b51a1`)

**What:** the first code in the repo: a read-only FastAPI serving
`gw.stopgap.price.forecast` for the next 48 hours. Energy is ISO-NE
day-ahead hourly LMP for Keene Rd, with hours past the last published
day repeated by hour of day; delivery is the Versant A-1 total-delivery
table by period, winter and non-winter, with the tariff's holidays. The
last good forecast is kept on disk and served with its past hours
trimmed when ISO-NE cannot be reached. Two routes serve the same word:
the house-pattern `/<hyphenated alias>/latest-forecast` and the legacy
path the LTN has hard-coded. Vendored sema snapshot, ci.sh, the systemd
unit and shell aliases for the forecast box.

**Why:** the price service the LTN FLOs read went with the PriceDb box
and its code survives nowhere, so every hourly FLO has been skipping for
want of a forecast. This is the smallest service that restores it in the
repo and on the box the real service (OPS-437) grows into, with no
database and no LTN change. OPS-610.
