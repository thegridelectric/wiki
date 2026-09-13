# Finalize `layout.lite/013` (spoke)

Status: Draft · Pass 0 · Updated 2026-09-12 · Linear: OPS-392

> What this is: the spoke that takes `layout.lite/013` from staging to
> published with its closure, so the spruce scada can send it on the
> production broker. This is a before-merge item for the branch: spruce
> stays off rmqbot until the word it sends on link-up is published.

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
- The longer-term intent (`operational-params-cleanup.md` "Retire
  `layout.lite`'s field-projection") is to stop sending a third shape
  and send the raw layout + ops words instead. That is after-merge
  work; this spoke only finalizes the word the box sends today.

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

## Do this next: the publish checklist

1. Read what JournalKeeper and the data repos take from `layout.lite`
   today (which fields, which nested words), so 013 carries exactly
   that and nothing that forces a further reshape before publishing.
2. Decide the closure: publish 013 with the Krida pair in it, or cut a
   014 without them once the sema wave drops them from the House0 word
   (`correct-house0.md` "Open"; scada stopped reading them 2026-09-10).
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
