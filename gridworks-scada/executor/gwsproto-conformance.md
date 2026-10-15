Status: Accepted · Pass 1 · Updated 2026-10-15

# gwsproto conformance — the scada's own sema snapshot is the oracle

What this is: how the hand-written gwsproto twins are kept conformant with
the sema words they mirror until the proactor refactor generates them. The
scada vendors its own sema snapshot and every named-types test checks its
instance against the snapshot class.

## The twins and the snapshot

A **twin** is a hand-written gwsproto class (a pydantic named type, a
`SemaEnum`, a property format) that mirrors one sema word. The twin is
what the scada runs. The **snapshot** is sema's generated copy of the same
words, `packages/gridworks-scada-protocol/sema_snapshot/sema`, committed
beside gwsproto so a diff shows the vocabulary a scada release speaks. It
is a staging snapshot (`--allow-staged`: the contract and layout words are
staging) and a test oracle only, never shipped or run on a broker.

`sema_seed_request.yaml` in the same package names every twin's word at
**one version**, the one the scada speaks (`versions: ["NNN"]`), and the
dependency closure brings the rest. A word the picos post below sema's
latest is seeded at that version (tank.module.params 200, flow.hall.params
101, async.btu.params 100), so the snapshot never names a version the
scada does not decode: version drift is a seed or twin mistake, never
recorded debt, and a word the snapshot reaches at two versions is a
sema-side dependent bound off the pin. `scripts/regen_sema_snapshot.sh`
regenerates from a sibling sema checkout; a missing snapshot fails the
tests rather than skipping.

## The three checks

1. **Shape** (`gwsproto_sema_conformance.py`, run by
   `tests/named_types/test_gwsproto_sema_conformance.py`). For every twin:
   a snapshot class at the pinned version; the same serialized field
   names; the same required set; the same `check_axiom_<n>` numbers; for
   enums the same value set and the same `default`. Every snapshot word
   has a twin. The allowlists are the checked-in record of known gaps, and
   each entry states the exact drift so a listed word that drifts in any
   other way fails: `NO_WORD_*` is gwsproto vocabulary with no sema word
   yet; `SNAPSHOT_UNMIRRORED_*` is a snapshot word no actor reads yet;
   every `KNOWN_*` drift set is empty and stays empty.
2. **Samples.** Every snapshot sample decodes through the twin and
   re-dumps byte-equal.
3. **Every test instance** (`tests/named_types/sema_oracle.py`).
   `assert_conforms(instance)` dumps a twin instance by alias, decodes it
   through the snapshot codec and requires an identical re-encode.
   `assert_refused(cls, payload, match)` requires the twin and the
   snapshot both to refuse, and the snapshot's refusal to name the same
   axiom by number or name; the two runtimes word their messages
   differently, so axiom identity is compared, not text. A twin with no
   sema word has no snapshot leg. A test of the twin alone, such as
   refusing another version's wire shape, stays on `pytest.raises` with a
   comment saying so.

The command-line report (`uv run python gwsproto_sema_conformance.py` from
the package) prints every section with no allowlist applied; the pytest
run is the gate.

## Every enum has a default

Every gwsproto enum declares a `default()` that is one of its own values
(`test_every_enum_has_a_default`); an enum with a sema word uses the
word's `default`. The default is sema's forward-compatibility fallback: an
unknown value on the wire decodes to it (`GwStrEnum._missing_`), never
refused. There is no exception to this rule. Where two vocabularies share
a field (`AnyDeviceType`, the real and the simulated device types), the
field resolves a name by exact membership in one of them and refuses a
name outside both, so the fallback never masks a stale name there.

## Named gaps

- 31 snapshot words have no sample at their pinned version, so check 2
  never round-trips those twins; their per-type positive tests are the
  only coverage. Accepted.
- `relay.energization.state` reaches the closure through a layout word
  and no actor reads it; it is the one unmirrored enum.
- Two tests refuse another version's wire shape on the twin alone
  (async.btu.params, tank.module.params), by intent.
- A twin takes a pico params word's next version only when the fleet's
  picos post it; no twin takes `FirmwareCommit` until then.

## Open

- Check 3 on instances the actors build at runtime in the sim-house
  tests, by a codec hook in test mode.
- A clause check in the oracle (the snapshot's refusal names the same
  clause label the test does); sema's axiom bodies name the clause in
  only some labeled words.
