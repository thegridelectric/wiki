# Design: namespace reservation

Status: Draft · Pass 0 · Updated 2026-10-07 · Linear: OPS-573

**EDD: no** build-out of registry machinery, verified by the registry
test suite plus one publish attempt against a reserved segment the
publisher does not own.

> What this is: let an owner apply to reserve the first segment of word
> names (`gw`, `acme`) so the registry checks it at publish time, turning
> today's recommended grouping pattern into a rule where an owner asks
> for one.

## The problem

A word's name is unique because it is registered, not because of its
first segment. The spec hub recommends the first segment as a grouping:
usually the owning organization (`gw.*`), sometimes the system the words
describe (`hubitat.*`, `i2c.*`, both GridWorks-owned). Nothing stops a
second publisher from registering `gw.something`, and nothing records
that `gw` is GridWorks'. With one registry and one publishing
organization this costs nothing today. The hub's "Vocabulary Scope and
Adoption" describes a registry several organizations publish into, and
there the pattern needs a check behind it.

## The change

- **An application record** naming the segment, the owner (an
  organization identity the registry already knows, or a new one), and
  who granted it; kept in the registry beside `registry.yaml`.
- **A publish-time check**: a word whose first segment is reserved
  publishes only when its publisher is the owner. Unreserved segments
  stay open; reservation is opt-in.
- **Existing words**: GridWorks reserves `gw`; the non-`gw` segments it
  owns today (`hubitat`, `i2c`, `g`, `sim`, `fsm`, `ticklist`,
  `electric`, `gridworks`, `gw1`) are reserved to it or listed as
  exempt grandfathers. Which is decided when this is taken.
- **The hub paragraph** gains one sentence saying a segment MAY be
  reserved and how, written when the machinery ships and not before.

## Open

- Who grants: the registry maintainer by hand, or any current owner for
  a segment nobody holds.
- Whether a reservation covers only the first segment or a dotted
  prefix of any depth.
- Not scheduled. Nothing in the 2026–27 gates needs it.
