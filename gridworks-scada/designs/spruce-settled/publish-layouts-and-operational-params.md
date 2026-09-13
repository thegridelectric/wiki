# Publish the layouts and the operational params (spoke)

Status: Draft · Pass 0 · Updated 2026-09-12 · Linear: OPS-532

> What this is: the after-deploy publishing round. The fleet moves onto
> the new code with the hardware layouts and the operational-params
> words still staging, because those words live in the layout file on
> the box and never cross the production broker (`executor/running.md`
> "Experiment window on a deployed box"); only `layout.lite` publishes
> before launch (`../spruce-unlimbo/finalize-layout-lite-13.md`). Once
> the deployed line has settled the layouts' contents, this spoke
> freezes them, and mints the wire words the mirror contract is missing.

## Do this next

1. **The layout closure and the ops pair.** `gw.house0.layout`,
   `gw.nolan.layout`, the component, device-type, capability and
   config words, the zone words and the operational-params pair go
   staging to published, bottom-up, by the checklist in
   `../spruce-unlimbo/finalize-layout-lite-13.md` "Do this next: the
   publish checklist" (finished-check, `sema promote`, vendored closure
   refresh, sema changelog). Not before the deployed line has run a
   stretch with no in-place edit to any of them.
2. **The twinless wire words.** These cross a broker today with no sema
   word at all; they are the distance from the every-wire-word-has-a-twin
   contract, not a status problem. LTN link: `slow.contract.heartbeat/001`
   (docstring says `ASL:`), `slow.dispatch.contract`,
   `no.new.contract.warning`, `sieg.target.too.low`, `send.snap`,
   `reset.hp.keep.value/001`, `sieg.loop.endpoint.valve.adjustment`,
   `set.lwt.control.params`, `set.target.lwt`, `flo.next.hour.plans`.
   Admin link: `admin.dispatch`, `admin.analog.dispatch`,
   `admin.keep.alive`, `admin.release.control`. Each gets a sema word
   authored from its gwsproto class (flattened, `$ref` composition) and
   the class becomes its twin; `gwsproto_sema_conformance.py` then has
   nothing to exempt.
3. **A release gate in the conformance test.** The status check is by
   hand today: every gwsproto schema pin and every word in the closure
   copy against the registry's status. Once the closure is published,
   the test can require it, so a staging word on the wire fails CI.

## Open

- The LTN publishes `flo.params.house0` and `flo.next.hour.plans` to the
  scada with no matching case in `Scada.process_scada_message`.
- A `Glitch` from the LTN is re-sent straight back to the LTN
  (`scada.py:334`).
- Whether the layout and ops words publish as one wave or the ops pair
  first (it changes more often).
