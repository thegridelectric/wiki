# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-marketmaker` code repo**. The matching git commit holds the
WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits.

Newest at the top.

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
