# heating-system-design — changelog

One entry per commit in the `heating-system-design` code repo; git holds
the *what*, this file the *why*.

Newest at the top.

<!-- pending commit -->
## 2026-10-07 — WIP various memos on distribution water temps (OPS-572, `39f91ef`)

One squashed commit, the repo's second, holding three days of work.

The documents. `mix-or-not.md`: the draft whitepaper on whether store
water is mixed down before distribution and how hot the store needs to
be, with its claims register and the first tested findings (return
temperature by source temperature and heat-call frequency for the five
houses without a mixing valve; the source-to-return drop in steady
circulation). `return-water-temperature-memo.md`: the short standalone
version of that finding. `cold-zone-call-during-steady-heating-memo.md`
and its chart: what an idle zone's call during a steady call does to
the return, the heat pump and the source at beech; the season's 45
calls; the finding that the drop's later movement is the source's, not
the slug's; the upstairs loop sized as about 4 gallons of cold water; a
disclaimers section. `beech-emitter-physics-mystery.md` (begun as
`distribution-flow-and-return-memo.md`): doubling the distribution
flow at beech on January 24 nearly doubled the heat delivered, which
emitter theory forbids at steady state (about 15%, and 38 kBTU/h above
the infinite-flow ceiling); the minute trace says the fast steps
charged the cast iron and the slow step discharged it, and the two
fast steps' excess over theory implies the same thermal mass,
280 BTU/°F; pump power confirms the metered flow doubled. In all four
"source" replaces "supply" for the water sent to distribution, the
`dist-swt` channel's word. The read-through for George: the memo's
opening sentence as a sentence, the mystery's time constant derived
from its own 280 BTU/°F (17 and 8 minutes), the calibration row's two
heats explained, each document naming its workbook, the memo's
chart-only numbers marked as such.

The repo. One folder per document named by its slug: the markdown as
the text of record, the current Word cut `<slug>.v<N>.docx` made with
pandoc, the workbook `<slug>.xlsx` from
`experiments/dist-loop-experiments/sheets.py <slug>` where that
registry has one, `build.sh`, a `build.txt` provenance record
(markdown, docx and xlsx hashes, the experiments commit, the pandoc
version) and `archive/` with earlier cuts. A pre-commit hook refuses a
markdown commit whose Word cut was built from other text, and the 2 MB
file cap. Workbooks are committed here, the deliverable a reader takes
from the folder; in experiments they stay gitignored as a build
product. Cuts: cold-zone memo v2 and return-water memo v2 (the ad hoc
v1 files are the first archive entries), mystery v1, paper v1.
**Why:** these documents are for readers outside the wiki, George
first, who work in Word and Excel: a folder gives them everything, git
keeps the text's history, and the workbook regenerates from data. A
result theory forbids had to be named as such, with the candidate
explanations and the test that would settle it, before it reached them.
