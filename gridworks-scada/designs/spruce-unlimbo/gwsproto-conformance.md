# gwsproto conformance: the scada's own snapshot as the oracle (spoke)

Status: Accepted · Pass 1 · Updated 2026-10-14 · Linear: OPS-392

> What this is: the structure that keeps the hand-written gwsproto twins
> conformant with the sema authority until the proactor refactor
> replaces them with generated code. The scada vendors its own sema
> snapshot and every test that builds a gwsproto instance checks it
> against the snapshot's class.

## ▶ Do this next

**Contract refusal resumes.** The suite's 28 failures and 5 collection
errors at `b3ba95f4` (`AcceptsDispatch` read off a word that no longer
has it, `DispatchRefusalReason.Standby` in five test files, heartbeats
from the LTN carrying `WattHoursUsed`) are its first rope.

Axiom refusal is sema's to prove, by mutation through a test-side helper
in sema's own suite (`sema/tests/runtime/refusal.py`); snapshots ship
data, not test code, so the scada keeps its own oracle. The scada's
snapshot is regenerated against sema `064300f`, the oracle's snapshot leg
matches the axiom number as a whole number, and the per-type positive
round-trips that repeated the sample check are gone (8 of 64; the rest
round-trip a different instance, assert more, or cover a word with no
sample).

## Why the twins drift

gwsproto types, enums and formats are written by hand as twins of sema
words. Today's conformance test walks the sibling sema checkout for the
twin's canonical examples and compares enum value sets, and reads a
hand-copied tlayouts closure registry for the reverse direction. Three
gaps let drift through: an axiom is checked only as far as a positive
example happens to exercise it; a field the examples never omit or
include is never compared; and the reverse check covers the layout
closure only, not the message words the scada and LTN exchange.

## The structure

The scada has a seed beside gwsproto,
`packages/gridworks-scada-protocol/sema_seed_request.yaml`, that names
every gwsproto twin with a sema word as a target, at the version the
scada speaks: a word the picos still post below sema's latest is seeded
at that version, so the snapshot never names a version the scada does
not decode and version drift is a seed or twin mistake, never recorded
debt. The dependency closure brings the rest.
`scripts/regen_sema_snapshot.sh` is the sema template instance; the
snapshot is `sema_snapshot/sema` in the same package, committed, so a
diff shows the vocabulary a scada release speaks. It is a staging
snapshot and a test oracle only, never shipped or run on a broker.

The snapshot is the oracle, in three checks:

1. **Shape.** For every gwsproto twin: a snapshot class at its pinned
   version (none is a failure); same set of serialized field names; same
   required set; same `check_axiom_<n>` numbers as the definition lists.
   A word in the snapshot with no twin is a failure, with a burn-down
   allowlist. A twin with no sema word stays on the `NO_WORD` allowlist.
   Every allowlist entry records the exact drift, keyed `type/version`
   with the field lists or both versions, so a listed word that drifts in
   any other way fails: an allowlist of bare type names would pass any
   drift at all.
2. **Samples.** Every snapshot sample decodes through the twin and
   re-dumps byte-equal, as the forward check does today, but from the
   snapshot rather than the sema checkout.
3. **Every test instance.** `tests/named_types/sema_oracle.py`:
   `assert_conforms(instance)` dumps a gwsproto instance by alias,
   decodes it through the snapshot codec and requires an identical
   re-encode; `assert_refused(cls, payload, match)` requires the twin
   and the snapshot both to refuse, and the snapshot's refusal to name
   the same axiom by number or name (the two runtimes word their
   messages differently, so axiom identity is compared, not text). A
   twin with no sema word has no snapshot leg. A test of the twin alone,
   such as refusing another version's wire shape, stays on
   `pytest.raises`. The snapshot's axiom bodies are the sema runtime's
   own, so this is `sema validate` as a local test rather than a hand
   step, against the vendored copy as the consumer rule requires.

The tlayouts closure copy and its Stop hook are retired: the layout
words are inside the scada closure, so check 1 covers them. The
GridWorks_CLAUDE maxim names the scada snapshot.

## Decisions taken

- The snapshot lives beside gwsproto in the protocol package, not in a
  new `src/gwscada/`; the code is under `gw_spaceheat/`.
- The snapshot is committed. A missing snapshot fails the tests rather
  than skipping, and no checkout needs a sibling sema to run them.
- `--allow-staged`: the contract and layout words are staging, so the
  snapshot is a staging snapshot. It is a test oracle and never runs on
  a broker, so the dev-only rule is met.
- The scada speaks one version of each pico params word, the one the
  picos in the field post (tank.module.params 200, flow.hall.params 101,
  async.btu.params 100), and seeds it at that version even where sema
  has a later one. No twin takes `FirmwareCommit` until the picos post
  it; the scada moves to the version that requires it with the fleet.

## The build

1. ✅ Seed, regen script, first regen.
2. ✅ Conformance sweep and test rewritten against the snapshot; the
   axiom-coverage test reads it too.
3. ✅ `sema_oracle.py`; every single-statement `pytest.raises` around a
   `model_validate` became `assert_refused`, every dump-equality assert
   gained `assert_conforms` (88 and 5 sites).
4. ✅ `sema_closure/`, the Stop hook and its settings entry removed; the
   maxim, the package README and the wiki passages rewritten.

## Open

- Whether check 3 should also run on instances the actors build at
  runtime in the sim-house tests, by a codec hook in test mode. Later.
- A clause check in the oracle (the snapshot's refusal names the same
  clause label the test does). Two prerequisites: sema's axiom bodies
  name the clause in every labeled word (the spec says a labeled refusal
  SHOULD; 7 of the 13 labeled words in the scada snapshot do not yet),
  and the twins do the same, message text only.
- 12 snapshot words have no sample because their latest version carries
  no example, so check 2 never round-trips those twins; their per-type
  positive tests are the only coverage. Either the examples are added in
  sema or the gap is accepted and named.
- `price.quantity.unitless`: the twin speaks 100, the snapshot seeds 001.
- 15 bare `pytest.raises` around a `model_validate` remain in
  `tests/named_types/`, three of them plain axiom refusals in
  `test_command_interface.py`; either twin-only by intent or a miss from
  build step 3.
