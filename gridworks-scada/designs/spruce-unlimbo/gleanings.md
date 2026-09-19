# Gleanings — notes parked off the build path (spoke)

Status: Draft · Pass 0 · Updated 2026-09-18 · Linear: OPS-392

> What this is: observations made while working the spruce un-limbo spokes
> that are not on any spoke's build path. Each is kept until it is acted
> on, moved to `executor/`, or dropped at close-down.

## The gwsproto mirror check — what it sees and what it misses (2026-09-18)

gwsproto twins are written by hand, and `gwsproto_sema_conformance.py`
checks them after the fact in two directions. Forward, every gwsproto
type, enum and format is held against the sibling `sema/` checkout
(version against sema's latest, the sema example decoded and re-dumped,
enum value sets, format examples). In reverse, every word in
`sema_closure/registry.yaml`, a copy of the tlayouts snapshot registry,
must have a twin at the closure's version. The copy is the registry
index only, names and versions with no schemas, and a Stop hook blocks
while it differs from the tlayouts snapshot.

- The reverse check sees names and version numbers and nothing else. A
  staging word edited in place looks unchanged to it. When the three pico
  component words gained a required `PicoBoardVariant`, only the forward
  dump comparison noticed, and only on two of the three: the tank twin
  allows extra fields, so its re-dump matched while the twin lacked a
  field sema requires.
- The two directions read different sources: the reverse check reads a
  snapshot cut at one sema commit, the forward check reads whatever the
  sema checkout holds that day. The test skips when no sema checkout is
  beside the repo, so CI never runs it. The scada's own rule is that a
  consumer vendors a snapshot and tests against the copy; this check
  does not.
- The Stop hook enforces the copy, not conformance. Blocking at the end
  of a turn pushes a session to copy the registry before the twins exist
  and leave the test red.
- Drift the sweep passed during the 2026-09-18 catch-up, each found by
  reading the word: `layout.lite` 013 renamed a field and the twin kept
  the old name (the word has no example, so nothing was decoded); the
  `gw.hydronic` twin enforced a lower bound of 1 on `TotalStoreTanks`
  after sema dropped it, and left `ZoneCallCircuits` optional where sema
  requires it (axiom bodies and `required` are not compared); both layout
  twins' component unions held three kinds sema had removed and lacked two
  it had added (union membership is not compared).
- About 53 gwsproto types have sema words outside the layout closure
  (reports, params, snapshots) and get the forward check only. A new
  sema message word the scada should speak is caught by nothing.
- Hand mirroring is the root, and the proactor port replaces it. Until
  then the natural fix is a real vendored snapshot, schemas included,
  from a scada seed request covering everything the scada speaks, with
  the twins tested against that copy: offline, runnable in CI, and able
  to see in-place edits. Not started; it does not serve getting the two
  sim houses running. The sema launch (OPS-538) already carries consumer
  conformance and the snapshot drift check, and is the time to make an
  interim improvement here.

At close-down of this design, the mechanism as it then stands is written
into `executor/`.
