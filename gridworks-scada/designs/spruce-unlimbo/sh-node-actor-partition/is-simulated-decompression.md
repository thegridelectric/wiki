# is-simulated-decompression (rope chunk)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: a chunk of the `sh_node_actor` partition rope; estimate 1.5h.
> Hub: [`primary.md`](primary.md).

The 2026-09-05 pass
(scada `59284cc5`) took hardware backend selection and the fake
control inputs off the bit; what is left needs vocabulary. Provoked by
this partition, so it lives here; if this spoke keeps growing it
becomes a folder.
- **Sema:** the first-pass `TaDeed` type, the `ValidationState` enum
  (`UnValidated`, `ValidatedRealAssetAndGps`,
  `ValidatedRealAssetIncorrectGps`, `ValidatedSimulatedAsset`), and
  the scada-to-LTN contract-rejection word (offered ContractId + the
  scada's `ValidationState` as cause). Word-gate ritual per word, in a
  sema-claiming session; gwsproto mirrors with rejecting tests.
  Meanings and the transport-plane consequences are recorded under
  OPS-420 ("TaDeed and the validation plane") and in the deeds
  exploration.
- **Scada:** read the deed into a `ValidationState` (`UnValidated`
  with no deed); the placeholder `tadeed.json` becomes an instance of
  the word. **Refuse every LTN contract offer while `UnValidated`**,
  sending the rejection word, tested on the in-process LTN↔SCADA rig
  (`test_auto_state.py`'s shape: `Created` offered, handler stays
  empty, auto state stays LocalControl, LTN receives the rejection).
  The Krida and DFR multiplexers move to a layout fact until their
  sim twin words exist. `is_simulated` itself stays for its sim-time
  job (simulated-test-environment `sim-time.md`).
