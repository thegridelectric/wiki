# Scratch — Economy Energy Markets

Working notes for the Pass 2 review of legacy materials against the
Pass 1 core spec (`executor/primary.md`, `actors.md`, `value-flow.md`,
`glossary.md`).

Not normative. When a concept survives review, it lands in a spec
spoke with provenance; this file may then drop the row.

## Pass 1 status (2026-06-06)

Done — architectural core seeded. 14 invariants locked in
`executor/primary.md`. Seven actors: Customer, CEP, TaAggregator,
TaReader, LTN, MarketMaker, TaValidator (third-party, never
GridWorks). Three GridWorks-affiliated legal entities at launch
(TaAggregator, TaReader, MarketMaker). CEP exclusivity (both
directions) per III.6.4(f). Cleared Market: every settlement period
the MarketMaker clears LTN per-asset bids against a CEP-defined
profile counterparty bid (`Appliance Profile × Total Cohort Usage`),
2-stage cadence (hourly forecast → daily true-up → monthly). CEP
net wholesale cost = LMP × Profile by structural guarantee.
Appliance Profile exogenous (heat-pump-without-storage, county ×
month). TaOwner always owns TaDeed; TaTradingRights are
clawback-able via SLA. Mission-aligned supply partner required
(MMWEC exemplar; profit-maximizing corporates excluded).
Participation Requirements framework-agnostic (currently
cryptographic). Open-source by default. GNode framing centers the
copper sub-tree (collaborative grid-map vision).

## Pass 2 plan

For each legacy source: read, list the concepts/mechanisms/terms it
contains, decide for each whether it (a) is already captured in the
Pass 1 spec, (b) refines a current spec point, (c) adds a new concept
worth a spoke, (d) is heritage that belongs in `heritage.md`, or
(e) is superseded / not relevant.

Status column: `TODO`, `IN PROGRESS`, `READ`, `DONE` (where DONE means
the row has been triaged and any integration into spec spokes is
complete).

## Source list

### Already read this session (Pass 1) — need triage pass

The TER Initiative PDFs and other materials previously under
`dera-stand-up/old-market-participation-model/` have been moved into
`legacy/old_words/`. Paths below reflect the new location.

| Source | Pass 1 read | Triage status | Notes |
| --- | --- | --- | --- |
| `legacy/old_words/TER Initiative Intro.v1_4-1.pdf` | yes | TODO | Frames the why; brief |
| `legacy/old_words/TER Initiative Section 1 DRAFT.v1_4.pdf` | yes | TODO | TER definition + Five Design Principles + 745 critique + 2222 critique. Key heritage content |
| `legacy/old_words/TER Initiative Section 2 DRAFT.v1_4-3.pdf` | yes (P2B3) | DONE | The 2021 TER Participation Model. Math + worked examples. Direct ancestor of the Cleared Market story (value-flow.md). 20 pages, read via pypdf. Confirmed superseded routing (2021 ISO-pays-Aggregator → 2026 III.6.4(f) + Cleared Market). Drove the telemetry-capability clause, the local-Node-LMP commitment, and the fractal-MarketMaker commitment. |
| `legacy/old_words/Redefining Demand Response.pdf` | yes | TODO | Algorand grant. Stetson Mountain story + chicken-and-egg framing + AMM-OPF vision. Mixed: some heritage, some operational, some out-of-scope blockchain |
| `legacy/g-node-factory/docs/wiki/redefining-demand-response.md` | yes | TODO | Short. Mostly superseded by the PDF |

### Legacy old_words — not yet read

| Source | Pass 1 read | Triage status | Notes / guess |
| --- | --- | --- | --- |
| `legacy/old_words/Algorand Milestone2 Deck.pptx` | no | TODO | Algorand grant milestone deck — overlaps with the PDF |
| `legacy/old_words/GridWorks Milestone 1 Writeup.v2.pdf` | no | TODO | First Algorand milestone writeup. Probably AMM-OPF + GNode infra |
| `legacy/old_words/flo.md` | no | TODO | Unknown. "Flo" might be Flexible Load Orchestrator or similar |
| `legacy/old_words/conductor-topology-node.md` | no | TODO | GNode tree concept |
| `legacy/old_words/g-node-instance.rst` | no | TODO | GNode concept |
| `legacy/old_words/g-node-status.rst` | no | TODO | GNode concept |
| `legacy/old_words/hello-gridworks.rst` | no | TODO | Probably intro |
| `legacy/old_words/hierarchical-state-machines.md` | no | TODO | Implementation detail |
| `legacy/old_words/index.rst` | no | TODO | TOC |
| `legacy/old_words/market-bid.rst` | no | TODO | Market structure heritage |
| `legacy/old_words/market-slot.rst` | no | TODO | Market structure heritage |
| `legacy/old_words/market-type.rst` | no | TODO | Market structure heritage |
| `legacy/old_words/representation-contract.md` | no | TODO | Atomic TNode <-> Terminal Asset binding |
| `legacy/old_words/scada.md` | no | TODO | SCADA layer reference |
| `legacy/old_words/sdk-types.rst` | no | TODO | Implementation detail |
| `legacy/old_words/supervisor.rst` | no | TODO | Implementation detail |
| `legacy/old_words/universe.rst` | no | TODO | Dev/shadow/real universe concept from Algorand grant |
| `legacy/old_words/weather-service.md` | no | TODO | Likely implementation detail |
| `legacy/old_words/maine-heat-pilot.md` | no | TODO | Empty file (0 bytes) |
| `legacy/old_words/multipurpose-sensor.md` | no | TODO | Empty file (0 bytes) |

### Legacy g-node-factory wiki — not yet read

| Source | Pass 1 read | Triage status | Notes / guess |
| --- | --- | --- | --- |
| `legacy/g-node-factory/docs/wiki/lexicon.md` | yes (P2B2) | DONE | **EMPTY FILE.** The real heritage lexicon is `legacy/gridworks/docs/lexicon.rst` — but that's just a Sphinx TOC listing 40+ term-file refs, no substantive content in the index itself. To read the heritage glossary as content, read the individual per-term files (each its own future-batch decision). |
| `legacy/g-node-factory/docs/wiki/market-maker.md` | yes (P2B1) | DONE | **EMPTY FILE.** The real ancestor content is elsewhere; no MarketMaker doc survived in the g-node-factory wiki. Look in `legacy/old_words/market-bid.rst` / `market-slot.rst` / `market-type.rst` for any MarketMaker mechanics. |
| `legacy/g-node-factory/docs/wiki/transactive-energy-resource.md` | no | TODO | TER heritage def |
| `legacy/g-node-factory/docs/wiki/transactive-device.md` | no | TODO | Device-level concept |
| `legacy/g-node-factory/docs/wiki/atomic-transactive-node.md` | no | TODO | Atomic TNode concept |
| `legacy/g-node-factory/docs/wiki/atomic-metering-node.md` | yes (P2B2) | DONE | **EMPTY FILE.** Real source: `legacy/gridworks/docs/atomic-metering-node.md` (7 lines). Concept: "larval AtomicTNode" — a metering GNode that exists as parent of TerminalAsset at creation, becomes an AtomicTNode once it owns TaTradingRights. HERITAGE (current LTN is the AtomicTNode equivalent; the larval/parent split is superseded by the LTN-at-meter-location + metering-topology pattern in `primary.md`). |
| `legacy/g-node-factory/docs/wiki/ta-deed.md` | yes (P2B1) | DONE | 28-line stub. TaDeed = NFT establishing TerminalAsset ownership. Algorand-specific impl (2-sig 3-owner multi). Validator attestation scope listed. Real source is `legacy/gridworks/docs/ta-deed.rst`. |
| `legacy/g-node-factory/docs/wiki/ta-deed-consideration.md` | no | TODO | TA-Deed design notes |
| `legacy/g-node-factory/docs/wiki/ta-validator.md` | yes (P2B1) | DONE | **EMPTY FILE.** Real source is `legacy/gridworks/docs/ta-validator.rst`. |
| `legacy/g-node-factory/docs/wiki/ta-validator-certificate.md` | no | TODO | TA-Validator cert details |
| `legacy/g-node-factory/docs/wiki/discovery-certificate.md` | no | TODO | Certificate scheme |
| `legacy/g-node-factory/docs/wiki/validator-certificate.md` | no | TODO | Validator cert details |
| `legacy/g-node-factory/docs/wiki/ta-daemon.md` | no | TODO | Implementation detail |
| `legacy/g-node-factory/docs/wiki/terminal-asset.md` | no | TODO | Asset-level concept |
| `legacy/g-node-factory/docs/wiki/copper-spanning-tree.md` | no | TODO | Grid topology concept |
| `legacy/g-node-factory/docs/wiki/g-node-alias.md` | no | TODO | GNode naming |
| `legacy/g-node-factory/docs/wiki/g-node-role.md` | no | TODO | GNode roles |
| `legacy/g-node-factory/docs/wiki/why-topology-is-critical.md` | no | TODO | Topology heritage |
| `legacy/g-node-factory/docs/wiki/initial-design-considerations.md` | no | TODO | Heritage |
| `legacy/g-node-factory/docs/wiki/design-specifications.md` | no | TODO | Heritage |
| `legacy/g-node-factory/docs/wiki/gnf-system-architecture.md` | no | TODO | GNode-factory architecture |
| `legacy/g-node-factory/docs/wiki/hybrid-demo.md` | no | TODO | Demo notes |
| `legacy/g-node-factory/docs/wiki/milestone-1.md` | no | TODO | Algorand milestone |
| `legacy/g-node-factory/docs/wiki/milestone-2.md` | no | TODO | Algorand milestone |
| `legacy/g-node-factory/docs/wiki/office-hours.md` | no | TODO | Notes |

### Older TA-Deed / TA-Validator source

| Source | Pass 1 read | Triage status | Notes |
| --- | --- | --- | --- |
| `legacy/gridworks/docs/ta-deed.rst` | yes (P2B1) | DONE | Real ancestor. 105 lines. "Link of trust" framing; TaValidator scope localized to MarketMaker sub-tree; Algorand impl details. |
| `legacy/gridworks/docs/ta-validator.rst` | yes (P2B1) | DONE | Real ancestor. 68 lines. "Anyone can become a TaValidator" via certification. M&V service providers as candidate profile. |


## Triage decision categories

Triage is **labeling only**, not integration. Each concept gets
exactly one label. Disciplined defaults: when the current spec is
*silent* on a question, the legacy answer is HERITAGE, not CAPTURED.
We are **not** looking to over-specify HOW; we are looking for **gems**
that make the spec work better or sharper.

- **CAPTURED** — concept is already in the Pass 1 spec, *explicitly*,
  with a current-spec commitment that lines up. Silence is not
  capture. Cite the spec location; no work to do.
- **SUPERSEDED** — concept has been *explicitly* replaced by a Pass
  1 decision. Document the supersession in `heritage.md`.
- **OUT OF SCOPE** — concept is real but not in the current
  architecture's scope (e.g., AMM-OPF semantics, financial assurance
  mechanism, blockchain implementation choice). Flag for future
  consideration; do not import.
- **HERITAGE** — concept is part of the GridWorks lineage but is
  not an active commitment of the current spec. Includes legacy
  answers to questions on which the current spec is silent.
  Document in `heritage.md`.
- **GEM** — concept is a structural sharpener: makes a currently
  implicit commitment explicit, names a relationship the current
  spec gestures at but doesn't pin down, or surfaces a load-bearing
  invariant we missed. **Gems require user confirmation before
  integration.**
- **BORDERLINE GEM** — possibly a gem, possibly noise. Surface to
  the user for a yes/no call.

**Anti-pattern (flagged):** over-specifying HOW. Verification
protocols, implementation mechanisms, candidate-profile lists, and
similar are *not* gems — they belong (if anywhere) in candidate
research, operational playbooks, or implementation specs, not in the
architectural spec.

## Workflow

Three phases. Do not cross phases without surfacing.

**Phase 1 — Label.** For each source:
1. Read it; extract concepts/terms/mechanisms.
2. Apply exactly one triage label to each (CAPTURED / SUPERSEDED /
   OUT OF SCOPE / HERITAGE / GEM / BORDERLINE GEM).
3. Record the triage in this file (per-batch memo).
4. Mark the source row DONE.

**Phase 2 — Surface to user.** Once the batch is labeled:
1. Present the GEM and BORDERLINE GEM rows to the user.
2. Ask: which are gems? Which are noise? Which are over-specifying
   HOW that I should reject?
3. Wait for the user's call. **Do not edit the spec spokes during
   this phase.**

**Phase 3 — Integrate.** Only after Phase 2:
1. For each confirmed gem, decide with the user whether it lands as
   a sentence in an existing spoke, a new architectural invariant,
   or a new spoke.
2. Integrate. Cite this file as provenance.
3. For HERITAGE / SUPERSEDED items from the batch, append to
   `heritage.md`.

When all source rows are DONE and Phase 3 has run, this scratch can
be archived — the durable content has moved into the spec spokes
and `heritage.md`.

## High-priority reads (do these first)

1. `legacy/g-node-factory/docs/wiki/market-maker.md` — direct ancestor
2. `legacy/g-node-factory/docs/wiki/ta-deed.md` and
   `legacy/g-node-factory/docs/wiki/ta-validator.md` — direct ancestors
3. `legacy/g-node-factory/docs/wiki/lexicon.md` — heritage glossary
4. `legacy/g-node-factory/docs/wiki/atomic-metering-node.md` — possible
   ancestor of Meter Reader
5. `legacy/old_words/flo.md` — unknown but small, quick to assess

## Parallel track — `gridworks-marketmaker/` repo evaluation

The `gridworks-marketmaker` repo at the GridWorks umbrella root is the
existing GridWorks Market Maker codebase, last touched in the Algorand
grant era (2022–2023). It needs evaluation before any wiki/spec
content claims an implementation.

**Repo state (snapshot taken 2026-06-06):**

- Poetry build (not uv). Needs migration.
- Dependency on `gridworks ^0.1.2` — predates gwbase. Will need a
  rebase onto the current `gridworks-base` / gwbase + sema stack.
- Pre-Alpha classifier.
- Algorand-era certificate references (TaDeed, TaTradingRights) in
  README — anchored on the 2022 architecture.
- Package: `src/gwmm/`. Has CodeGenerationTools, docs/, tests/,
  input_data/, output_data/, `millinocket_api.sh`,
  `millinocket_mm.py` — Millinocket-flavored stubs were already in
  place when the work paused.

**Evaluation tasks:**

| Task | Status | Notes |
| --- | --- | --- |
| Read `gridworks-marketmaker/README.md` end-to-end | TODO | Get the design intent the README captures |
| Read `gridworks-marketmaker/docs/` end-to-end | TODO | Architecture docs |
| Inventory `src/gwmm/` modules | TODO | What concepts are implemented, what are stubs |
| Read `millinocket_mm.py` + `millinocket_api.sh` | TODO | Existing Millinocket stubs — historical reference |
| Identify what is still good with minor adaptation | TODO | Likely: hierarchical naming, market-slot/market-type/market-bid concepts, ex-ante gate-closing, message protocols |
| Identify what needs full replacement | TODO | Likely: gridworks ^0.1.2 dependency stack, Algorand-specific transaction code, anything anchored on the AMM-OPF semantics rather than the Cleared Market clearing model |
| Identify what to delete outright | TODO | Likely: Pre-Alpha test scaffolding that no longer parses, codegen against old type definitions |
| Map repo concepts to the Economy Energy Markets spec spokes | TODO | Where does each repo concept land in the new spec? `market-maker.md`, `cleared-market.md`, etc. |
| Decide migration target: gwbase + sema + new MM design | TODO | High-level migration plan |

**Pre-decisions to inform the eval:** see `executor/primary.md`
for current architectural commitments. Key context for the eval:
fractal multi-market MarketMaker (not AMM-OPF); three
GridWorks-affiliated legal entities (TaAggregator, TaReader,
Market Maker); open-source by default.

**Output of the eval:** seeds `wiki/gridworks-marketmaker/executor/primary.md`
as a Draft Pass 0 acceptable-minimum hub, with a clear statement of
"what's still in the repo from 2022, what's been replaced or
deprecated, what we plan to add" — the standard
GridWorks wiki executor-spec pattern.

This track runs in parallel with the legacy intake above. The repo
eval should NOT block the legacy triage; both can advance
independently.

## Quick directory snapshot — `gridworks-marketmaker/` top level

```
CODE_OF_CONDUCT.md
CONTRIBUTING.md
CodeGenerationTools/
LICENSE
README.md
codecov.yml
docs/
for_docker/
input_data/
millinocket_api.sh
millinocket_mm.py
noxfile.py
output_data/
poetry.lock
pyproject.toml          (Poetry; depends on gridworks ^0.1.2)
src/gwmm/
tests/
```

## Notes on out-of-scope material to handle gracefully

The Algorand grant and GNode work include substantial vision for
AMM-OPF (Automated Market Maker Optimal Power Flow) — a much more
ambitious grid-balancing architecture than the current Cleared
Market clearing approach. Triage approach: AMM-OPF goes into
`heritage.md` with a clear statement that the current architecture
clears participant bids in a Cleared Market and does NOT attempt
OPF semantics; AMM-OPF remains a long-term direction.

The blockchain (Algorand) commitment in the 2022 grant is similarly
not present in the current architecture as a core dependency. It
may resurface in `market-maker.md` (Open) as a record-keeping /
audit-trail commitment, but is not a top-level architectural
requirement.

## Open questions surfaced by Pass 1 that may benefit from legacy review

- Day-Ahead vs Real-Time settlement cadence inside the Cleared Market
  (cleared-market.md Open)
- The admin margin number (cleared-market.md / value-flow.md Open)
- The customer rebate share (cleared-market.md / value-flow.md Open)
- The Appliance Profile methodology certification (would benefit from
  any prior GridWorks thinking on baseline accuracy)
- The Meter Reader spin-off mechanics — what infrastructure / API
  surface should it have? (meter-reader.md placeholder)
- The Market Maker's record-keeping commitments (blockchain or no?)
