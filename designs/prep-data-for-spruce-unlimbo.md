# Prep data for spruce-unlimbo

Status: Draft · Pass 0 · Updated 2026-10-06 · Linear: OPS-542

**EDD: yes** the day of fleet data from the spruce-unlimbo first data catch
is the verification; a claim reaches Verified only when that data reads the
whole way up (journal, façade, visualizer) by layout lookup alone, against
real services (`experiments/`).

> What this is: the data-side cleanup that follows the spruce-unlimbo launch
> (OPS-392): JournalKeeper, the web-backend and the web-frontend stop
> deciding meaning by channel-name strings and read it from the layout
> word. Kept out of spruce-unlimbo because it is a different set of repos
> with its own verification; the launch's deployment spoke points here by
> Linear id.

## Sequence

1. **The first data catch** (OPS-392, `deployment.md` "The first data
   catch"): `layout.lite/013` published, gjk creating its channels, the
   heat-call guard on gjk, three boxes on `jm/spruce-unlimbo` on the
   production broker for a day, readings landing.
2. **Boxes to `main`, maybe.** After that day the launch decides whether the
   boxes move to `main`. This design does not wait on that call; it needs
   the caught data, not the swap.
3. **This design: the string cleanup**, against the caught data.

## The three repos

The fleet emits, JournalKeeper writes the journal DB, the web-backend reads a
façade over it, the web-frontend visualizes. The cleanup is on:

- **gridworks-journalkeeper** — every place a persistor decides what a
  channel is from its name: the hand-kept `STATE_CHANNELS` map, the
  heat-call synthesis keyed on `*-whitewire-pwr`, and the rest of the
  string matching in the persistors
  (`gridworks-journalkeeper/executor/persistor.md` "Open"). Pseudo-channels
  stay; what changes is that gjk derives them from the layout it receives
  rather than from literals in code.
- **gridworks-web-backend** — the public read-only façade: the API returns
  the channels and layout/params shape for every family from the layout
  word, with no per-house channel-name table.
- **gridworks-web-frontend** — the visualizer: it renders each family from
  the layout, including the families with no buffer tank or iso valve and
  the one with no water store tanks at all.

## No per-house specials

The three layout families (`gw.nolan.layout`, `gw.house0.layout` with the
sieg loop, `gw.house0.no.sieg`) must ingest and display by their
layout-sema declaration, not by hand-mapped channel names (the standing
team rule: data analysis never slows the production system, and hard-coded
channel-name strings in data services are the named enemy). The tell that
vocabulary is missing or unused is code that scrapes instead of looking up.

## The experiment (the EDD bar)

Read the caught day through the whole pipeline, asserting:

1. **Channels arrive.** Every channel each box's layout declares is in the
   journal DB, none dropped and none silently renamed, with no gjk code
   naming a channel.
2. **Hourly data parses.** The hourly rollup the web-backend serves parses
   for each family, with no decode error on a family-specific channel.
3. **The visualizer works.** The web-frontend renders each house's page from
   its layout: the channels present, nothing assuming a tank or valve the
   family lacks.

The harness is a re-runnable reproducer; findings distill into scoped
Verified claims once it is green.

## Open

- Which families the three catch boxes cover; a family not among them needs
  a simulated asset (or a later box) to meet the bar.
- Whether the simulated fourth fall layout (OPS-532) is exercised here too.
- The exact web-frontend and web-backend seams that still read channel
  names by string rather than the layout word.
