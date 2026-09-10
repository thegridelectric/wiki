# Finalize `layout.lite/013` (spoke)

Status: Draft · Pass 0 · Updated 2026-09-10 · Linear: OPS-392

> What this is: the spoke that takes `layout.lite/013` from staging to
> published with its closure, so the spruce scada can send it on the
> production broker. This is a before-merge item for the branch: spruce
> stays off rmqbot until the word it sends on link-up is published.

## Where it stands

- `layout.lite/013` is staging in sema (created 2026-09-08); gwsproto
  pins `013` (`packages/gridworks-scada-protocol/src/gwsproto/named_types/layout_lite.py:47`).
- The builder is House0-shaped and crashes on the Nolan layout
  (`sh-node-actor-partition/staging-words-on-prod.md` "First wire case").
- Publishing 013 drags seven staging words into the published closure:
  `gw1.actuation.authority/000`, `gw1.service.mode/000`,
  `pico.tank.module.component.gt/012`, `sim.pico.tank.module.component.gt/001`,
  `pico.flow.module.component.gt/001`, and the Krida pair
  `i2c.multichannel.dt.relay.component.gt/004` + `relay.actor.config/003`.
- The longer-term intent (`operational-params-cleanup.md` "Retire
  `layout.lite`'s field-projection") is to stop sending a third shape
  and send the raw layout + ops words instead. That is after-merge
  work; this spoke only finalizes the word the box sends today.

## Do this next

1. Read what JournalKeeper and the data repos take from `layout.lite`
   today (which fields, which nested words), so 013 carries exactly
   that and nothing that forces a further reshape before publishing.
2. Decide the closure: publish 013 with the Krida pair in it, or cut a
   014 without them after krida-retirement rung 3 takes them out.
3. Fix the builder for the Nolan layout; boot on the bench and on the
   box and confirm the emitted instance validates (`sema validate`).
4. Promote bottom-up (`sema promote`), refresh the vendored closure
   copy in gwsproto, and record the promotion in the sema changelog.

## Open

- Whether `014` goes first (no Krida pair) or `013` publishes as is.
