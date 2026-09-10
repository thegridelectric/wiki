# is-simulated-decompression (rope chunk)

Status: Draft · Pass 0 · Updated 2026-09-09 · Linear: OPS-392

> What this is: a chunk of the `sh_node_actor` partition rope; estimate 1.5h.
> Hub: [`primary.md`](primary.md).

The 2026-09-05 pass (scada `59284cc5`) took hardware backend selection and
the fake control inputs off the `is_simulated` bit. This chunk takes the
trading question off it: whether a scada may enter an LTN contract is a
fact a TaValidator attests, read from a real word, not the existence of a
placeholder file. Provoked by this partition, so it lives here.

## Built (2026-09-09)

- **Sema** (`12a608f` on dev, staging): `ta.validation.state` (enum,
  `UnValidated` default, `ValidatedRealAssetAndGps`,
  `ValidatedRealAssetIncorrectGps`, `ValidatedSimulatedAsset`); `ta.deed`
  v000 (TaId, TaAlias, ValidationState, ValidatorAlias, IssuedS; axiom 1:
  a simulated-asset deed never carries a `w` alias, with its runtime
  template and rejecting test); `slow.contract.rejection` v000
  (FromGNodeAlias, ContractId, ValidationState, MessageCreatedMs). Suite
  567 passed. The signature over the deed and the owner principal wait on
  the deeds exploration's open signing convention and principal word.
- **Scada** (`4bb46035` on `jm/spruce-unlimbo`): gwsproto twins with tests, payloads
  `sema validate` clean. `ScadaAppInterface.validation_state` reads the
  deed at `settings.paths.tadeed` (default `ta-deed.json` beside the
  layout); `is_simulated` answers only from
  `has_simulated_component()`. An `UnValidated` scada answers a `Created`
  offer with the rejection and starts nothing
  (`process_slow_contract_heartbeat`); the LTN drops its pending
  contract on receipt (`LtnContractHandler.process_slow_contract_rejection`).
  Krida and DFR multiplexers read the layout fact. Test config carries a
  `ValidatedSimulatedAsset` deed for the nolan layout, copied beside the
  layout by conftest; `test_contract_rejection.py` deletes it and
  witnesses the refusal on the in-process LTN rig. Suite 502 passed / 4
  skipped.

## ▶ Do this next

The dev-broker witness: a scada
booted on honeysuckle with no deed file, an LTN offer, the rejection
visible in the LTN log; that run is what moves this chunk to Verified.
