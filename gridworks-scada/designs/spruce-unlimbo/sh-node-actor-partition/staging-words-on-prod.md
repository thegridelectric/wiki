# Staging words on the production broker (spoke)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

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
   edited in place on the branch (the krida-retirement `scada.control.
   capabilities/001` edit, the dac words) settles first, or it gets a new
   version straight after promotion.
3. **The 52 twinless gwsproto names.** They do not block the broker but
   they are the mirror-test defect the every-wire-word-has-a-twin contract
   names; count them as the honest distance from that contract.
4. **What the consumers decode.** Published words on the broker are half
   of it; JournalKeeper and the data repos on hw1-1 have to ingest what
   spruce emits in the new vocabulary. List what each decodes today and
   what changes.

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

## Prerequisites

A scada-claiming session, the registry (`sema/definitions/`) read beside
the branch's closure copy, and `sema/spec` promotion rules read first
(`governance.md` "Promotion", `registry/structure.md` "Status Field").
Both the unlimbo epic and the JournalKeeper ingestion work depend on this;
it may become its own flat issue.

## ▶ Do this next

Produce the wire/layout-file split (item 1) as a table in this spoke:
word, version, status, wire or file, finished or still moving.
