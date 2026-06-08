# Aris Hydronics collaboration

Status: Draft · Pass 0 · Updated 2026-06-07

> What this is: an open exploration of the Aris Hydronics / Jonathon Woolley
> collaboration — the relationship, what's exciting about it, and the open
> business-model question of whether Aris becomes the Aggregator. The hopes are
> Jessica's, in her words; the grounding and the research questions are mine.
> Companion: [`home-assistant-ltn.md`](home-assistant-ltn.md).

## The relationship (Jessica's words)

> My friend and colleague Jonathon Woolley is in a chief-scientist-type role for
> Aris Hydronics. He is designing SCADA for their systems, including installation
> of R290 heat pumps in a multi-family apartment complex in Vermont. He is very
> excited about introducing thermal storage to the Aris systems (which focus on
> vertical integration), and we are hoping together that Aris might be one of the
> first companies to step fully into the ecosystem I am dreaming about.
>
> Jonathon is super excited about making his SCADA systems for Aris using Home
> Assistant. I am not really certain this is a great idea, but perhaps it will
> work well. And I want to support him.

## Why this matters

Aris is a candidate **first mover** into the GridWorks ecosystem — a real
company, vertically integrated, already installing the kind of asset (R290 heat
pumps) that thermal storage makes transactive. If Aris steps in, it validates the
ecosystem thesis with a partner rather than a demo. The relationship is also
warm and trust-based (Jonathon is a friend and colleague), which is the right
soil for a first mover. Two distinct supports are in play: *support Jonathon's
HA direction* (whether or not HA proves ideal), and *use HA as GridWorks' own
first step into that open-source ecosystem* — see
[`home-assistant-ltn.md`](home-assistant-ltn.md).

## The open question: does Aris become the Aggregator?

This is the crux, and it has a real tension inside it (Jessica's framing):

- **She wants Aris to be the Aggregator** — because she knows **Robert wants the
  service-level agreement** (i.e. Robert wants to own the SLA / the direct
  relationship with the asset and customer).
- **But Robert does *not* want to be responsible for energy markets and
  trading** — he wants "somebody who does that for him."

So the question is whether these can both be true: **Aris holds the Aggregator /
SLA / customer relationship, while the market-participation-and-trading function
is performed by someone else** (plausibly GridWorks or another
ecosystem party). In GridWorks terms this is a clean separation — the party that
owns the asset/customer relationship need not be the party running the
MarketMaker / optimizing LTN participation. If that separation holds
contractually and technically, Aris-as-Aggregator and Robert-delegates-the-
markets are compatible, not contradictory. Whether it actually holds — for Aris
specifically, and on terms Robert finds comfortable — is the thing to research,
not assume. (What we build may not fit them; treat the fit as a hypothesis.)

## Research questions

- **Aris business model.** What does vertical integration mean for Aris
  concretely — what do they sell, how do they earn, and what is their existing
  relationship to the asset and the customer? Where would a transactive /
  storage layer sit in that model?
- **The Aggregator split.** Define "Aggregator" precisely in GridWorks terms
  (SLA + asset relationship) vs the industry "DER aggregator" sense, and confirm
  whether the market/trading function can be cleanly delegated away from the SLA
  holder — contractually (Representation Contract shape) and technically (which
  GNode roles Aris would vs would not run).
- **Robert's actual position.** Validate the two stated desires (own the SLA; do
  not own market/trading responsibility) directly, since the whole structure
  turns on them.
- **Home Assistant ecosystem.** Whether HA is a sound substrate for Aris's SCADA
  — covered in [`home-assistant-ltn.md`](home-assistant-ltn.md).
