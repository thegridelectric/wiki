# liveness-projection — one record per scada saying whether it is live

Status: Draft · Pass 0 · Updated 2026-09-15 · Linear: OPS-546

**EDD: yes** the projection is verified by running its maintainer against
the live hw1 broker stream beside the houses' known state for a week; a
record reaches Verified when every transition it shows (live, silent,
Standby, MonitorOnly) matches what an operator saw.

> What this is: the design for a sema-typed projection of scada liveness,
> one record per scada, maintained from the broker stream, that answers
> "which houses are expected to report" for the alerter, the web page, the
> LTNs and the scada-health signals alike. Shared-dependency work: it is
> depended on by the broker alerter (OPS-545), scada-health diagnostics
> (OPS-317), and the umpire (OPS-501), and by any reader that today keeps
> its own tracking heuristic. Cross-cutting because the authority question
> spans marketmaker, scada and fleet-index.

## Why

Every consumer that needs to know whether a house is live re-derives it.
gwalert derives the house list from the rows a query returns, so a house
with no reading in the window is silently absent from every check (elm,
off for the summer, never pages). The web page has its own notion. The
LTN link has a transport keepalive with no silence deadline at the
contract tier. OPS-317 emits `ally.inactive` and `ally.active` and persists
a signal set in JournalKeeper but leaves the back-office surface open. One
record, maintained once, is what all of these read.

## What one record carries

The field list the consumers already agree on; the design settles names,
formats and the word's place in the registry:

- which scada (its GNode alias),
- when it was last heard, and which layer heard it (a report on the
  broker, a link-level ping, a contract heartbeat),
- the system mode from its last `layout.lite` (Standby and MonitorOnly
  are fields, not exceptions),
- whether it is considered live, and since when.

Membership in the projection is what "tracked" means. A no-data alert is a
rule read off the record; a tracking heuristic inside any one consumer is
the antipattern this retires.

## Settle in the design, not by default

- **Which record is the authority the projection derives from.** Three
  docs disagree: the fleet-index exploration says FIS is the authority on
  liveness; the umpire (OPS-501) holds contract liveness and says gw_data
  is a projection, not an authority; OPS-317 keeps JournalKeeper as the
  referee. The projection is a reader's view; it must name what it reads.
- **The word's name.** "Projection" in sema today means unit→quantity
  mapping (the three `*.quantity.projection` types); in OPS-501 and the
  registry projection design it means a consumer-written materialized
  view. This is the second sense. Name it so the two are not confused.
- **Where the maintainer runs.** A gwbase actor of its own on the hw1
  broker, or a duty of an existing service. The alerter will hold a copy in
  its sqlite store either way; the question is who writes the record of
  record.
- **The sema spec is change-controlled.** The word is a discussion before
  it is a file.

## Prior art on liveness

Liveness is already layered in the wiki; the projection consumes these
layers, it does not add a beat. Cited by issue or spec path; quotes are
searchable.

- **Transport keepalive, scada↔LTN link.**
  `wiki/gridworks-scada/executor/scada-ltn-link-state.md` "How a link stays
  alive": "a `gridworks.ping`, about once a minute. The child responds with
  a `gridworks.ack`". Same doc, "Broker-access liveness — a second, worse
  gap": a half-open socket left a scada "comms-dead for ~15 minutes while
  looking healthy" (interim fix OPS-304). The contract-tier heartbeat "has
  no silence deadline" there.
- **The liveness commitment is scada↔LTN, signed and chained**, not
  cloud↔LTN: `wiki/gridworks-scada/explorations/liveness-and-sla.md`
  "Two heartbeat layers — keep them separate": "A heartbeat demonstrating
  **liveness** must run **SCADA ↔ LTN**, not cloud ↔ LTN". OPS-428
  decouples broker liveness from peer liveness ("Hex keepalive =
  application-level proof of full receipt"). OPS-435 makes "the heartbeat
  live" part of the LTN's EDD bar.
- **Supervisor tier** is `heartbeat.a` only, one trust domain:
  `wiki/gridworks-base/executor/actors.md` "heartbeat / sim-timestep
  rhythm": "`heartbeat.a` **from `my_super_alias`** — auto-ponged".
- **Scada-health signals, OPS-317**: the nearest thing to a liveness
  record. It emits "fire-and-forget `ally.inactive` / `ally.active`" and
  persists a durable liveness signal set in JournalKeeper, with the
  back-office surface left Open ("admin panel? a derived channel?"). This
  is the design the projection completes.
- **Who is the authority on liveness** is undecided across three docs:
  `wiki/gridworks-fleet-index-service/explorations/g-node-instance-and-liveness.md`
  ("FIS is the authority on liveness"); OPS-501, the umpire, holds
  contract liveness and says "gw_data is a projection, not an authority";
  OPS-317 keeps JournalKeeper as the referee.
- **Inconsistency to resolve elsewhere:** the local-admin-session design
  (gridworks-admin) proposes a new `heartbeat.a/001` spanning admin↔scada
  and LTN↔scada, while the scada research findings (F-008) and the sema
  changelog of 2026-05-21 deleted `heartbeat.a/001` and scoped
  `heartbeat.a/000` to supervisor liveness in one trust domain. Not this
  design's to settle, but the projection must not depend on the deleted
  word.

## Consumers, and what each does until the word exists

- **Broker alerter (OPS-545).** Seeds its expected-house set from the
  `layout.lite` messages it has stored, and reads "no `report.event` in ten
  minutes" off its own queue. Adopts the projection as the house set when
  the word is published; the swap is one lookup.
- **Scada-health diagnostics (OPS-317).** Its emitted signals become one
  input layer to the record; its persisted set in JournalKeeper is a
  candidate authority.
- **Web page.** Reads the record from the journal once JournalKeeper
  journals it like any other word.

## Do this next

Start from OPS-317 rather than from scratch: read that design's "Emit" and
"Persist" sections and `scada-ltn-link-state.md` "How a link stays alive",
then run `/grill-me` on two questions: which record is the authority the
projection derives from (FIS, the umpire, or JournalKeeper's persisted
set), and what one liveness record carries (last heard, which layer heard
it, mode from the last `layout.lite`, live flag). Then take the word to the
sema spec discussion, named so it is not mistaken for the unit→quantity
projections. The alerter does not wait for this; it adopts the word when
published.
