# Changelog

A reverse-chronological log of WHY we made each change **in the
`gridworks-price-forecast` code repo**. The matching code-repo commit
holds the WHAT (the diff). Each entry's date and one-line title mirror
that commit.

Newest at the top.

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
