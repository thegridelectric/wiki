# Finalize `layout.lite/013` (spoke)

Status: Draft · Pass 0 · Updated 2026-10-04 · Linear: OPS-392

> What this is: the spoke that takes `layout.lite/013` from staging to
> published with its closure, so the spruce scada can send it on the
> production broker. This is a before-merge item for the branch: spruce
> stays off rmqbot until the word it sends on link-up is published.
> Two segments: the first publishes the word the box sends today, enough
> for the fleet to run under local control; the second, once the maple
> and spruce LTNs run, is the spruce-settled `ltns-ready.md` spoke.

**To fold in: state machines and their states.** `layout.lite` and the
layout words both need to carry the state machines the scada runs, each
with its state enum (word and version) and so its possible states, so
that JournalKeeper has a programmatic way to track them rather than
hand-kept machine names. The machine-state enums
(`gw1.nolan.lc.buffer.only.state`, `spruce.hack.hp.state`, and the
rest) reach the journal as `SingleMachineState` values, and no layout
names them. `spruce.hack.hp.state` is seeded into the tlayouts snapshot
and the gwsproto closure mirror as the first of them.

## Two segments

**Segment 1, basic functioning under local control.** The publish
checklist below, on 013 as it is (or 014 without the Krida pair, the
first Open item). The LTN's needs are not designed here: the word keeps
carrying what the LTN reads today (`SeasonalStorageMode`,
`BufferShortCycling`, `TotalStoreTanks`, `Ha1Params`) and the fix is
only that a Nolan layout no longer crashes the builder.

**Segment 2, after the LTNs work.** Lives in
`../spruce-settled/ltns-ready.md`: what each LTN takes from the scada,
the `flo.params` versions, and whether `layout.lite` is reshaped or
replaced. **When segment 1 closes:** distill the publish outcome into
the executor, then move anything still open in this spoke (the closure
decision's leftovers, the `gw.nolan.layout` promote note) into
`ltns-ready.md` "What the LTN takes from the scada", and delete this
file. The scoreboard row covers segment 1; ltns-ready is estimated when
it opens.

## Where it stands

- `layout.lite/013` is staging in sema (created 2026-09-08); gwsproto
  pins `013` (`packages/gridworks-scada-protocol/src/gwsproto/named_types/layout_lite.py:47`).
- The builder is House0-shaped and crashes on the Nolan layout ("The
  first wire case" below).
- Publishing 013 drags seven staging words into the published closure:
  `gw1.actuation.authority/000`, `gw1.service.mode/000`,
  `pico.tank.module.component.gt/012`, `sim.pico.tank.module.component.gt/001`,
  `pico.flow.module.component.gt/001`, and the Krida pair
  `i2c.multichannel.dt.relay.component.gt/004` + `relay.actor.config/003`.
- The longer-term intent is to stop sending a third shape and send the
  raw layout + ops words instead
  (`../spruce-settled/publish-layouts-and-operational-params.md`). That
  is segment 2's question; segment 1 only finalizes the word the box
  sends today.

## What `layout.lite` is standing in for

`layout.lite` serves two temporary roles, and finalizing it is the moment
to prepare for what replaces each.

1. **Proof of liveness.** The scada's answer to `SendLayout` on link-up is
   how the LTN knows the scada is there. That role is changing out very
   shortly and should not shape the word.
2. **A stand-in for the actual layout and operational params.** The LTN
   learns scada parameters only through this word (`KeepBufferFull` at
   `actors/ltn/ltn.py:774`), because it holds neither the layout word nor
   the ops word. The direction is the other way round: the LTN provides
   the scada with both its operational params and its layout, drawn from
   their authority, the terminal-asset registry (the layout and
   operational-params sibling of the grid-node registry,
   [OPS-471](https://linear.app/gridworks/issue/OPS-471)). What the scada sends up is then likely a
   confirmation that the layout and ops it runs are the correct ones,
   checked against that authority, not the source of them.

So segment 1 carries design work as well as the publish: what the
authority holds, how the LTN hands a scada its layout and ops, and what
the scada sends up so the two can be checked against each other. The
adoption question (whole instance or partial update, restart or not) is
in `../spruce-settled/publish-layouts-and-operational-params.md`
"Parameters coming down from the LTN".

**The LTN's timezone and on-peak hours are the first case.** The scada
side reads its timezone from `ops.Tariff.TimezoneStr`. The LTN cannot: its
three readers (`actors/ltn/ltn.py:474`, `actors/ltn/contract_handler.py:58`,
and the LTN settings default `actors/ltn/config.py:44`) and its inline
on-peak table (`actors/ltn/contract_handler.py:275`, weekdays 7 to 11 and
16 to 19) stay on LTN settings until the LTN holds the ops word. A
`Tariff` field on `layout.lite` is not the fix; it would extend the
stand-in role this section retires.

## The first wire case

The LTN requests the layout with `SendLayout`; the scada answers with a
`layout.lite` payload carrying every ShNode, every data channel, the
tank, flow and relay components, and House0 ops fields
(SeasonalStorageMode, BufferShortCycling, TotalStoreTanks). On a Nolan
layout the builder crashes (`Trouble with SendLayout: 'NoneType' object
has no attribute 'component'`, bench run 4, 2026-09-05; `scada.py`
`layout_lite`). The crash is the small part: a fixed builder answers
every request on hw1-1 with `layout.lite/013`, a staging word that drags
the whole layout closure over the production broker in a House0-shaped
payload. The broker rule reaches only the words that cross the wire
(`executor/running.md` "Experiment window on a deployed box"), and this
is the one wire word still staging; the layout and ops words behind it
stay staging through the fleet move. So a Nolan scada either sends no
layout until the word is published, or sends a published word whose
closure is published too. Decided 2026-09-08: spruce stays off rmqbot
and keeps sending `layout.lite`, because the journal on hw1-1 reads the
layout to interpret the data channels; publishing 013 with its closure
is the gate to connecting.

## Do this next: the publish checklist (segment 1)

1. Read what JournalKeeper and the data repos take from `layout.lite`
   today (which fields, which nested words), so 013 carries exactly
   that and nothing that forces a further reshape before publishing.
2. Decide the closure: publish 013 with the Krida pair in it, or cut a
   014 without them once the sema wave drops them from the House0 word
   (scada stopped reading them 2026-09-10).
3. Fix the builder for the Nolan layout; boot on the bench and on the
   box and confirm the emitted instance validates (`sema validate`).
4. Publishing is immutability: confirm every word in the closure is
   finished (no in-place edit still planned on the branch), or it gets
   a new version straight after promotion.
5. Read `sema/spec` `governance.md` "Promotion" and
   `registry/structure.md` "Status Field"; promote bottom-up with
   `sema promote`, the read-receipt being the list of words promoted.
6. Refresh the vendored closure copy in gwsproto
   (`packages/gridworks-scada-protocol/sema_closure/registry.yaml`)
   and run the conformance test.
7. Record the promotion in the sema changelog.

## Open

- Whether `014` goes first (no Krida pair) or `013` publishes as is.
- Delete the unused Krida pair from gwsproto when the word stops carrying
  it. `layout.lite`'s `I2cRelayComponent` field is the last reader of
  `I2cMultichannelDtRelayComponentGt` and `RelayActorConfig`
  (`named_types/layout_lite.py:44`); no scada code fills the field and
  both layout words' component unions have dropped the type. When the
  field goes (or is retyped), delete the two twins, the
  `I2cMultichannelDtRelayComponent` dataclass, their exports, and
  `tests/named_types/test_i2c_multichannel_dt_relay_component_gt.py` and
  `test_relay_actor_config.py` in the same change.
- `gw.nolan.layout` closes with the same epic-end promote: registry
  status finalized, regenerate, validate against the real layouts. The
  promote holds until the House0 word runs on all the House0 homes
  (`../spruce-settled/thermostat-and-zone-control.md` "Sequencing").
