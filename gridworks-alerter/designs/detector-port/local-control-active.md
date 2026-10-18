# local-control-active — the house on local control

Status: Draft · Pass 0 · Updated 2026-10-16

> What this is: gwalert's disabled `check_in_atn`
> (`alert_generator.py:1136`, commented out of `main`) as
> `LocalControlActive`: the house has fallen back to local control and
> the LTN is not dispatching it. "Atn" is the legacy name for the LTN.

## gwalert today

Reads relay 5's boss name and compares it with the strings
`ltn.la.relay5` and `auto.lc.n.relay5`. Disabled, so no live behaviour
to match.

## What needs settling before a rule

- Whether this is a page at all. The house running itself is by design
  the fallback when the LTN is away, and at a hundred homes a local
  control fallback after an internet outage is a displayed fact, not a
  3 a.m. page. The candidate page is the LTN side: an LTN that is up and
  not dispatching a house that accepts dispatch.
- What states it: the `gw.house.operating.status` record and the scada's
  top state, both words the alerter can vendor.
- Whether `NoData`'s "ltn silent" clause already covers the case people
  care about.

## Do this next

Decide the three points above with whoever answers the pages; write the
condition and the resolve in this spoke; only then tests and the rule.
