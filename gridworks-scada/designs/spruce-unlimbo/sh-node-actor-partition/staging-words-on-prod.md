# Staging words on the production broker (spoke)

Status: Draft · Pass 0 · Updated 2026-09-08 · Linear: OPS-392

> What this is: the analysis that lets the `jm/spruce` code run on spruce
> against the production broker while MOST layout and params words stay
> staging. The rule was "staging means dev brokers only"; it is loosened
> for now (`executor/running.md` "Experiment window on a deployed box"),
> and this spoke draws the line the loosened rule needs: which words the
> broker rule actually reaches.

## Where the branch stands (2026-09-06)

`jm/spruce-unlimbo` pins 95 non-published words: 74 in the layout closure
across five dependency layers, plus 21 wire words (`layout.lite/013` among
them, `report.event/004` still draft), and 52 gwsproto names with no sema
word at all. The check is by hand: every gwsproto schema pin and every
word in the closure copy (`packages/gridworks-scada-protocol/sema_closure/
registry.yaml`) against the registry's status; `gwsproto_sema_conformance.py`
has no release-gate flag.

## The analysis (more than a list)

1. **Wire versus layout-file.** Split the 95 by what crosses the wire to
   hw1-1 versus what only lives in the layout file on the box. Only wire
   words matter to the broker; the closure words they `$ref` get dragged
   in by dependency, and the rest can stay staging.
2. **Which are finished.** Publishing is immutability. A word still being
   edited in place on the branch (the `scada.control.
   capabilities/001` edit, the dac words) settles first, or it gets a new
   version straight after promotion.
3. **The 52 twinless gwsproto names.** They do not block the broker but
   they are the mirror-test defect the every-wire-word-has-a-twin contract
   names; count them as the honest distance from that contract.
4. **What the consumers decode.** Published words on the broker are half
   of it; JournalKeeper and the data repos on hw1-1 have to ingest what
   spruce emits in the new vocabulary. List what each decodes today and
   what changes.
5. **`scada.control.capabilities/001` is the one admin-scada word still
   staging** (2026-09-08; the other eleven are published, see below).
   Its closure holds `spaceheat.node.gt/302` and `gw1.actor.class/013`,
   so publishing it freezes those layout-closure words too. It also
   carries the cover of the command tree, which the per-node command
   interface (`../../../../command-surface.md` "Open") may reshape.
   Decide after rung 2 whether it publishes as `001` or as a `002`
   shaped by that work; until then the admin panel decodes a staging
   word from production scadas.

## First wire case: `SendLayout` on a Nolan scada

The LTN requests the layout with `SendLayout`; the scada answers with a
`layout.lite` payload carrying every ShNode, every data channel, the
tank, flow and relay-multiplexer components, and House0 ops fields
(SeasonalStorageMode, BufferShortCycling, TotalStoreTanks). On a Nolan
layout the builder crashes (`Trouble with SendLayout: 'NoneType' object
has no attribute 'component'`, bench run 4, 2026-09-05; `scada.py`
`layout_lite`). The crash is the small part: a fixed builder answers
every request on hw1-1 with `layout.lite/013`, a staging word that drags
the whole layout closure over the production broker in a House0-shaped
payload. So the fix is decided by the split above, not in isolation: a
Nolan scada either sends no layout until the word is reshaped and
published, or sends a published word whose closure is published too.

## Published 2026-09-08: the admin-scada command vocabulary

Eleven words went staging to published on 2026-09-08 because they
cross between production instances from that afternoon: enums
`gw.scada.cmd.refusal.reason/000`, `hp.boss.state/000`,
`pico.cycler.event/000`, `pico.cycler.state/000`, `reboot.picos`,
`turn.hp.on.off`; types `analog.dispatch/000`,
`gw.command.transition/000`, `gw.dispatch.ack/000`,
`gw.dispatch.nack/000`, `gw.command.interface/000`.
`scada.control.capabilities/001` stays staging: its closure holds
`spaceheat.node.gt/302` and, under it, `gw1.actor.class/013`, both
layout-closure words, and publishing freezes them (a later field
change becomes `303`, a new actor class `014`). Whether those two are
finished is item 2 of the analysis; the decision on this word is item 5.

## The split (2026-09-08)

Every gwsproto payload the scada sends or decodes on the LTN and admin
links, read off the actors' send sites (`scada.py`, `ltn/ltn.py`, the
four command nodes, `api_flow_module.py`, `derived_generator.py`) and
checked against the registry after the 2026-09-08 promotions. Every
word the scada emits on either link is published or has no word at all;
`layout.lite/013` stays staging and is not sent.

| Word | Version | Status | Link | Finished? |
| --- | --- | --- | --- | --- |
| `layout.lite` | 013 | staging | LTN, scada→ltn, on link-up and as the `SendLayout` reply | No. House0-shaped and the builder crashes on Nolan ("First wire case" below). Its closure drags seven staging words: `gw1.actuation.authority/000`, `gw1.service.mode/000`, `pico.tank.module.component.gt/012`, `sim.pico.tank.module.component.gt/001`, `pico.flow.module.component.gt/001`, and the Krida pair `i2c.multichannel.dt.relay.component.gt/004` + `relay.actor.config/003` that the House0 word wave retires (`../correct-house0.md` "Open"). |
| `new.command.tree` | 002 | published 2026-09-08 | LTN, scada→ltn, every tree change (`scada.py:1241`) | Yes. Axiom 2 names actor classes, so a new actuator or command-node class is a 003; accepted. |
| `report.event` | 004 | published 2026-09-08 | LTN, scada→ltn, every report (`scada.py:1375`) | Yes. Was a draft on the wire: `003` plus three envelope axioms (MessageId = Report.Id, TimeCreatedMs = Report.MessageCreatedMs, Src = Report.FromGNodeAlias), met by construction in `send_report`. |

**Published on the wire already.** LTN: `glitch`, `snapshot.spaceheat/003`,
`power.watts`, `scada.params/005`, `ticklist.reed.report`,
`ticklist.hall.report`, `heating.forecast`, `weather.forecast`,
`report/003` with `channel.readings/002`, `machine.states`,
`fsm.full.report/001`; ltn→scada `analog.dispatch`, `send.layout/001`,
`flo.params.house0/007`, `bid`. Admin: `scada.control.capabilities/001`
with `gw.command.interface/000`, `single.reading`, `single.machine.state`,
`gw.dispatch.ack`, `gw.dispatch.nack`, `send.control.capabilities`,
`fsm.event`.

**On the wire with no word (item 3, the twinless count).** LTN:
`slow.contract.heartbeat/001` (docstring says `ASL:`), `slow.dispatch.contract`,
`no.new.contract.warning`, `sieg.target.too.low`, `send.snap`,
`reset.hp.keep.value/001`, `sieg.loop.endpoint.valve.adjustment`,
`set.lwt.control.params`, `set.target.lwt`, `flo.next.hour.plans`. Admin:
`admin.dispatch`, `admin.analog.dispatch`, `admin.keep.alive`,
`admin.release.control`. These are the words the mirror contract is
missing, not a status problem.

**Layout file only, stays staging.** The rest of the non-published
closure (`gw.house0.layout`, `gw.nolan.layout`, the component, device-type,
capability and config words, the operational-params pair, the zone
words) never crosses a broker; it lives in the layout file on the box.

**LAN or in-process, no broker.** `tank.module.params/200` (pico HTTP
post), the `i2c.*` bus messages, `setpoint.belief`,
`zone.circuit.governance.cmd`.

Two oddities from the read, not this spoke's: the LTN publishes
`flo.params.house0` and `flo.next.hour.plans` to the scada with no
matching case in `Scada.process_scada_message`; and a `Glitch` from the
LTN is re-sent straight back to the LTN (`scada.py:334`).

## Prerequisites

A scada-claiming session, the registry (`sema/definitions/`) read beside
the branch's closure copy, and `sema/spec` promotion rules read first
(`governance.md` "Promotion", `registry/structure.md` "Status Field").
Both the unlimbo epic and the JournalKeeper ingestion work depend on this;
it may become its own flat issue.

## ▶ Do this next

Decided 2026-09-08: spruce stays off rmqbot, and the scada keeps sending
`layout.lite`. The journal on hw1-1 reads the layout to interpret the
data channels, so a scada that sends none emits readings nothing
downstream can name; a staging layout word on the production broker is
the rule the split exists to keep, so the gate to connecting is
`layout.lite` published with its closure. Item 4 of the analysis is now
the next move: read what JournalKeeper and the data repos take from
`layout.lite` today (which fields, which nested words) so the reshaped
word carries exactly that, then decide whether the reshape waits for
the sema wave that takes the Krida pair out of the closure
(`../correct-house0.md` "Open") or a 014 goes first without them.
