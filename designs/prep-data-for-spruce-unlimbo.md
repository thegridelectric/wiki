# Prep data for spruce-unlimbo

Status: Draft · Pass 0 · Updated 2026-09-14 · Linear: OPS-542

**EDD: yes** simulated assets of all three layout families are the
verification; a claim reaches Verified only when a sim run carries its
channels the whole way up — journal, façade, visualizer — against real
services (`experiments/`).

> What this is: the upstream data-side once-over that lands alongside the
> spruce-unlimbo scada launch (OPS-392) so the new layout-sema layouts ingest
> correctly. The scada launch produces the layouts; this design makes the
> data pipeline read them. Kept out of spruce-unlimbo because it is a
> different set of repos with its own verification; the launch hub points
> here by Linear id.

## The three repos that need the pass

The fleet emits, JournalKeeper writes the journal DB, the web-backend reads a
façade over it, the web-frontend visualizes. The once-over is on:

- **gridworks-data** — journal DB ingestion: the readings tables and
  `gridworks.messages` payloads decoded through the codec accept every
  channel the three layout families declare, with no hard-coded channel-name
  strings deciding what lands (the standing team rule: data analysis never
  slows the production system, and hard-coded channel-name strings in data
  services are the named enemy).
- **gridworks-web-backend** — the public read-only façade: the API returns
  the new channels and layout/params shape for all three families.
- **gridworks-web-frontend** — the visualizer: it renders each family without
  per-house specials, including the two that lack a buffer tank / iso valve
  and the one with no water store tanks at all.

JournalKeeper (gjk) is the emit→journal hop in front of these; it is touched
only where a family carries a message type or channel it does not yet
journal.

## No per-house specials

The launch reason this design exists: the three layout families
(`gw.nolan.layout`, `gw.house0.layout` with the sieg loop, `gw.house0.no.sieg`)
must ingest and display by their layout-sema declaration, not by hand-mapped
channel names. A data service that scrapes or hand-maps channel names is the
antipattern; the tell that vocabulary is missing or unused is code that
scrapes instead of looking up. The once-over replaces any such scraping on
the read path with the layout word.

## The experiment (the EDD bar)

Stand up simulated assets of all three families and drive data through the
whole pipeline, asserting:

1. **Channels arrive.** Every channel the layout word declares reaches the
   journal DB — none dropped, none silently renamed.
2. **Hourly data parses.** The hourly rollup the web-backend serves parses
   for each family, with no decode error on a family-specific channel.
3. **The visualizer works.** The web-frontend renders each family's page —
   the channels present, the layout laid out, nothing assuming a tank or
   valve a family lacks.

The harness is a re-runnable reproducer; findings distill into scoped
Verified claims once the sim run is green.

## Sequencing

Downstream of the spruce-unlimbo launch (OPS-392): the layout words and the
per-family gens must exist first (they are the launch item), then this
pipeline reads them. In dev first, per the single-scada-focus rule — both sim
houses green in dev, then the upstream repos to correct layout-sema ingestion
in dev, before any of it fronts production data.

## Open

- Which message types / channels JournalKeeper does not yet journal for the
  no-sieg family, if any.
- Whether the simulated fourth fall layout (OPS-532) is exercised here too.
- The exact web-frontend layout-render seams that still read channel names by
  string rather than the layout word.
