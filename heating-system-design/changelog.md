# heating-system-design — changelog

One entry per commit in the `heating-system-design` code repo; git holds
the *what*, this file the *why*.

Newest at the top.

<!-- pending commit -->
## 2026-10-07 — the beech emitter physics mystery; cold-zone memo summary and docx (OPS-572)

`distribution-flow-and-return-memo.md` becomes
`beech-emitter-physics-mystery.md`, retitled around its one striking
result, that doubling the distribution flow at beech on
January 24 nearly doubled the heat delivered, with a summary stating
it, a section working through what emitter theory predicts (about
15%, and 38 kBTU/h above the infinite-flow ceiling), and a section on
what the minute trace says: the fast step charged the cast iron, the
slow step after it discharged it, and the supply oscillated through
every fast step; the two fast steps' excess over theory implies the
same thermal mass, 280 BTU/°F, which the cast iron holds. Pump power
confirms the metered flow doubled. In all four documents "source"
replaces "supply" for the water sent to distribution, the
`dist-swt` channel's word.
`cold-zone-call-during-steady-heating-memo.md` opens on its
10-minute finding, sizes the upstairs loop's water, and carries a
disclaimers section; its docx is regenerated from the markdown.
**Why:** a result theory forbids has to be named as such before it
reaches George and Paul, with the candidate explanations and the test
that would settle it.

## 2026-10-07 — WIP various memos on distribution water temps (OPS-572, `8547c5d`)

`cold-zone-call-during-steady-heating-memo.md` and its chart: what an
idle zone's call during a steady call does to the return, the heat
pump and the supply at beech, with the season's 45 calls and the
finding that the drop's later movement is the supply's, not the
slug's. `distribution-flow-and-return-memo.md`: the pump-speed
explorations. **Why:** both are standalone memos for readers outside
the wiki, like the return-temperature memo below.

`mix-or-not.md` at the repo top: the draft whitepaper on whether store
water is mixed down before distribution and how hot the store needs to
be, with its claims register. It carries the first tested findings: the
return temperature from distribution by supply temperature and
heat-call frequency for the five houses without a mixing valve, and the
supply-to-return drop in steady circulation. `return-water-temperature-memo.md` is the
short standalone version of the return temperature finding, for readers
who need only that. **Why:** the paper is for
readers outside the wiki, so it lives in the heating-system-design repo;
the wiki keeps only the work plan.
