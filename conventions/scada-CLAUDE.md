# gridworks-scada — Claude protocol

Status: Draft · Pass 0 · Updated 2026-10-26

## Scada is a statue: chip, don't sculpt

In `gridworks-scada` every change is made with the utmost care unless the
human has given a specific green light. Two things combine to make my
default gravity produce errors: an existing and rather unique codebase, and
a set of ideas about how the human wants to change it that I do not fully
understand. On top of those sit mistakes already in the code, including
recent ones made when this care was not taken. So: remove only what
demonstrably does not belong; for each change, state the problem it solves
and how we really want to solve it before touching code; no drive-by
refactors, renames, or "improvements" alongside the change at hand.

Every feature we create or touch gets a test, and a break in `pytest` is
the rope: follow it up, fix what it reaches, and keep climbing rather than
routing around it.

## ⏳ The single scada focus (set 2026-09-01; REMOVE when both sim houses run in dev)

Get a simulated House0 and a simulated spruce working against tests with
genuinely decent coverage, and nothing else. CHALLENGE any scada work that
does not serve this focus, including work Jessica floats. One clear
exception: work that **clears out the pipes**, finding hidden crud on a
path the fleet really runs that we would not otherwise easily find (a
channel nothing sends on, a creator no actor claims, a reading dropped at a
boundary). That work serves the focus without needing to be named by it,
because it finds what tests written from today's understanding do not look
for. It is not to be challenged, and it matters most on the paths that
serve the core mission on the electric grid: metering, energy, the
transactive boundary.

Once green: run both in dev, then bring the four upstream data repos (gjk,
gridworks-data, gridworks-web-backend, gridworks-web-frontend) to correct
layout-sema ingestion IN DEV. No per-house "specials" upstream: the
standing team rule (2024) is that data analysis never slows the production
system, and hard-coded channel-name strings in data services are the named
enemy of that rule.

## Layouts

**Four more layouts arrive rapidly (fall 2026):** one simulated, three
installed in Millinocket this fall. Two of the installs simplify the flow
control manifold (no iso valve, no buffer tank); the third is a cement
store-under-floor with no water tanks at all. Scada code SHALL NOT assume a
buffer tank, an iso valve, or water store tanks exist; "shared" means every
layout we can imagine has it, not both current families.

**⏳ fir, elm and oak are being refactored to House0 layouts with fake
sieg BTUs (REMOVE when `gw.house0.no.sieg` exists).** Each gen gets a
sieg BTU meter on a pico that does not exist, with the meter node and its
sieg channels disabled, and its sieg loop on relays nothing at the house is
wired to; oak is done (`tlayouts/oak_gen.py`). Do not relax the
`SiegManifoldChannels` axiom. The three houses move to a
`gw.house0.no.sieg` word once House0 is close to stable.

**The Nolan iso valve is NOT under hp-boss.** `NolanBufferOnlyTou` owns
`iso-valve-relay`: the boot posture commands it open and nothing closes
it. hp-boss's fixed sub-tree is the call relay and the secondary pump
only. Do not move the iso under hp-boss, and do not add a rule that
closes it: the idle-closed rule (closed with the call open and the heat
pump sensed off) was an experiment against the buffer-top convection
loop that did not solve it, removed 2026-10-22.

## ⏳ Layout words and operational params stay on the box (REMOVE when the layout words are published)

`gw.house0.layout`, `gw.house0.no.sieg`, `gw.nolan.layout` and
`gw.operational.params` are staging words. A deployed scada reads them
from its config folder and NEVER sends them, or any instance of them,
to the production broker: what it says about its layout on the broker is
`layout.lite`, and nothing more. No new message, report, glitch or
snapshot field may embed a staging layout word or the operational
params, and a harness or listener on the production broker never asks a
scada for them. This holds until the words have stabilized against the
installed fleet; then they are published, the scada sends the published
layout word, and `layout.lite` is retired.

## Deployed names and rolling

**A scada finds its files by their deployed names, in dev as on a box.**
Its config folder (`~/.config/gridworks/scada/`) holds
`hardware-layout.json`, `operational-params.json` and `ta-deed.json` side
by side, and the scada resolves them by default. Do NOT point a scada at
a fixture or gen-output file name through `*_PATHS__*` lines in a
`.env` or a template: a source with another name
(`tests/config/gw.nolan.*`, a tlayouts gen output) is renamed at the
copy. On the laptop `experiments/put_layout.sh dev` does the copy; on a
box only `scripts/roll.sh` does, from the committed tlayouts JSON of the
line the house moves to.

**A deployed house moves between scada lines only by `scripts/roll.sh`**
(`<house> check | to <branch> | back`, run from the laptop), which moves
the pi and the house's LTN together and verifies the layout pair both
ways; the how-to is executor `running.md` "Rolling a house between
lines". Spruce runs `actual-spruce` with the tlayouts `actual-spruce`
layout and rolls to `main` with the tlayouts `main`
layout, so its two layouts are reasoned about separately, and `check`
says which line it is on. Do NOT boot a branch scada on a box by any
other path: no second checkout, no env file naming another broker, no
window harness.

## gwsproto rules

- **The scada's sema snapshot is the oracle for the hand-written twins.**
  `packages/gridworks-scada-protocol/sema_snapshot/` is the scada's own
  vendored snapshot: every word it speaks, at the ONE version it speaks,
  seeded by `sema_seed_request.yaml` beside it and regenerated by
  `scripts/regen_sema_snapshot.sh`. The conformance sweep and every
  named-types test check the twins against it. A word that changes in sema
  reaches the scada by regenerating the snapshot in the same wave and
  writing the twin the tests name. The twins stay hand-written until the
  proactor refactor; the spec is executor `gwsproto-conformance.md`.
- **Sema types are flat; gwsproto twins are not.** Sema words do not
  inherit from one another: every field is spelled out, and a word reuses
  another only by `$ref`. The twins share fields through base classes
  (`type_helpers/component_base.py`). When authoring a sema word from a
  twin, flatten the base-class fields in; do not fix the twin inheritance
  now, the proactor port regenerates the twins flat.
- **Serialize with `model_dump(by_alias=True)`.** gwsproto named-types define
  snake_case python fields with `alias_generator=snake_to_camel`; the
  PascalCase wire names are pydantic aliases. Plain `model_dump()` emits
  snake_case, and decode tolerance (`populate_by_name=True`) hides the
  mistake.
- **Sema-type docstrings are `Sema: <schema_url>` and NOTHING else.** No
  value enumerations, no links, no prose; that duplicates the schema, the
  single source of truth.
- **Mirror sema axioms as `check_axiom_<n>` methods**:
  `@model_validator(mode="after")`, numbered to match the sema axiom numbers,
  raising `ValueError` with `"Axiom <n> (<Name>) failed: …"`. Mandatory even
  for value-range constraints: type the field with the matching sema format
  (`NonNegativeInt`, `PositiveInt`, …) + the axiom method. NEVER a
  `Literal[0,1]`-style bound; it silently drops the axiom.

## Periodic mypy sweep of `actors/` (no gate)

After any change that moves methods between actor base classes, and at each
milestone, run `venv/bin/mypy --ignore-missing-imports
--follow-imports=silent actors` from `gw_spaceheat/` and read only the
`has no attribute` lines, filtered against the runtime-injected
`transitions` trigger names. A reader on a plain base of a name that moved
to a tier is the defect this catches (`bd13a371` left two; one stopped the
scada, one silently stalled the sieg valve). Not a CI gate: the trigger
noise and the hand-derived gwsproto make one mostly noise.
