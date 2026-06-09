# Design: First-pass evaluation of the existing gridworks-marketmaker repo

Status: Draft · Pass 0 · Updated 2026-06-08

> **Extremely rough.** A first-pass triage of the existing `gridworks-marketmaker`
> code as we prepare to launch the MarketMaker. Not a plan yet — a frame for the
> evaluation. Companion intent:
> [`../explorations/launch-intentions.md`](../explorations/launch-intentions.md).

## Why this matters

The existing code has **never run in production**, but it is not throwaway:

- It captures core learning from the **VCharge** days, when we ran several
  **thousand** systems in **co-optimized market participation**.
- It ran as a key part of the large **Algorand simulation** (~2 years ago).

So the repo is a reservoir of hard-won market-participation design — worth
evaluating deliberately before deciding what to keep, rebuild, or discard for
the launch MarketMaker.

## What a first pass should answer (Open)

- **What's actually in there** — the market clearing loop, bid/offer handling,
  co-optimization logic, the simulation harness, data classes/types.
- **What encodes real learning** vs. scaffolding — which parts are the VCharge /
  Algorand-sim distillate worth carrying forward.
- **What's stale** — legacy type/enum codegen (XSLT pipeline), `atn.*` naming,
  assumptions that no longer hold under the current GNode / Sema model.
- **Fit to launch intentions** — does it match the committed direction (maker as
  authoritative market advertiser; semantics in types + axioms; uniform
  `bid`/`latest.price`; 5-min slots)? See launch-intentions.
- **Keep / rebuild / discard** — a rough disposition per area, feeding the real
  rebuild plan later.

## Status

Rough stub. To be fleshed out as the evaluation runs; not yet a ratified change
plan. (Per the implementation gate, no code work until promoted to Accepted.)
