# Admin tests against House0 (spoke)

Status: Draft · Pass 0 · Updated 2026-09-10 · Linear: OPS-532

> What this is: admin coverage for the House0 family, the twin of
> `tests/actors/test_admin_on_nolan.py`. Today admin coverage is
> Nolan-only; the House0 admin cases in `tests/test_misc/test_admin.py`
> are commented out and carry House0 incidentals (relay index 18, the
> DFR outputs, state captured through the relay multiplexer).

## Do this next

1. A `test_admin_on_house0.py` on the House0 fixture pair: the
   capabilities projection (every relay, the three 0-10V outputs,
   hp-boss and sieg-loop as command-node rows, the owned relays with no
   interface of their own), one relay dispatch and one analog dispatch
   reaching their actors.
2. Delete the commented-out House0 cases in `test_admin.py` once the
   new file covers them.

## Open

- Whether this waits for the relay decommission (House0 relays through
  per-relay components against the Krida board record) or runs first
  against the multiplexer path as it stands.
