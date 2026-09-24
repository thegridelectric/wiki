# Launching transactive air-to-water heat pumps in the US

Status: Draft · Pass 0 · Updated 2026-09-23

What this is: the hub for the roadmap that takes GridWorks from a
handful of dispatched thermal-store homes to a US market where
air-to-water heat pumps with large stores are installed, dispatched and
paid for as a matter of course. It holds the workstreams and the
reference material they rest on; the technology specs stay in their own
domains and are pointed to from here.

## Why this hub exists

Electrifying hydronic heat with a heat pump is a well-understood trade
in the UK and Europe. What makes it a load the grid wants rather than a
load the grid fears is the transactive layer: a large store charged on
a price signal and drawn down on the house's own schedule, with the
purchase of energy decoupled from the delivery of comfort. Nobody has
launched that at scale. Launching it needs more than the dispatch
software: installers who are comfortable with low-flow-temperature,
store-charged hydronics; manufacturers whose equipment fits it; a
business model a utility can run; and a public body of material that
makes all three feel ordinary.

The model for that last piece is Heat Geek (UK): seven years of free,
physics-first practitioner content that became a training business, an
installer network and a homeowner offer. Our answer keeps the shared
ground (heat loss, emitter sizing, weather compensation) and adds the
store, the delivered-heat service level and dispatch. The differences
are stated plainly so a reader who knows the UK pattern sees exactly
what is new. Where Heat Geek's content is proprietary and exists to sell
subscriptions, ours is open on purpose; the value sits in dispatch and
in the operating service (`vision/adoption.md`).

## Workstreams

Each becomes its own spoke as it gains substance; until then the line
here is the whole of it.

- **Education and reference site.** The open, one-voice body of design
  guidance: shared hydronic fundamentals plus the transactive-store
  fork, in the public `awhp-launch` repo (CC BY-SA 4.0 for content).
  Built rapidly with LLM help from the existing education slides and
  the `heating-system-design/` domain. Open.
- **Installer partners.** Who installs, how they are trained, and what
  the first production manifolds (May 2027) ask of them. Ridgeline under
  the Efficiency Maine 100-home pilot is the first case. Open.
- **Manufacturers.** Heat pumps, stores and manifolds that fit the
  pattern; the Chiltrix conversation is the current thread. Open.
- **Utility business model.** Municipal light plants and cooperatives
  as the first buyers: master-meter purchase, own rates, rebate-check
  settlement as VCharge ran it. The InnovateMass application is the
  live instance (private prospect material, not linked from here). Open.

## Research

- [`research/heat-geek/business-model.md`](research/heat-geek/business-model.md)
  — Heat Geek's corporate history, funding, revenue lines, scale and
  content strategy, with sources.
- [`research/heat-geek/price-and-accounts.md`](research/heat-geek/price-and-accounts.md)
  — install prices against the BUS median, monitored SCOP, and the
  FY2025 accounts: the contracting entity earns the spread, the
  platform burns it.
- [`research/fleet-peak-avoidance.md`](research/fleet-peak-avoidance.md)
  — two Maine seasons of fleet data against high-price hours and ISO-NE
  monthly peaks, the caveats, and pseudo-code for the experiment.
- `research/heat-geek/` also holds Heat Geek's own articles, saved by
  hand from a browser as "Webpage, Complete" (the site blocks automated
  fetches). Each is a matched set named by the article's own byline date:
  `<date>-heatgeek-<slug>.html`, its `_files/` asset folder (so the page
  opens locally), and a `.txt` rendering so a claim can carry a searchable
  quote. These copies are Heat Geek's copyright and are gitignored: the
  wiki is a public repository, and a saved copy is for private reference
  only. Cite by URL plus a short quote. Saved so far:
  - `2018-11-11-heatgeek-weather-compensation-or-load-compensation`
  - `2021-07-05-heatgeek-why-not-to-use-low-loss-headers`
- What is and is not deployed abroad, with downloaded sources, lives in
  the private prospects material and is not linked from here.

## Glossary

- **AWHP** — air-to-water heat pump; hydronic, as opposed to
  air-to-air.
- **Weather compensation** — setting the flow temperature from outdoor
  temperature so the emitters continuously match the building's heat
  loss; the UK design default.
- **Transactive store** — a thermal store large enough that when the
  heat pump runs is decided by price and grid need, not by the house's
  instantaneous demand.
