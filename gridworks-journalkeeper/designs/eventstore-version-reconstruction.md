# eventstore version reconstruction

Status: Draft · Pass 0 · Updated 2026-08-25 · Linear: OPS-498

**EDD: yes** the scan of real archived payloads *is* the verification; a
reconstructed version reaches Verified only when the actual eventstore records
for its date range decode against the authored sema word.

> ### ▶ Walk-back complete at the population start: **2024-10-13**
> The walk-back ran **backward** from the JK data floor (2026-01-09) in one- to
> three-week windows and reached 2024-09-16 (earliest filename in
> `scratch/ops-498-walkback/logs/`, the one authority on the cursor). Every
> accepted `(type, version)` found from 2024-10-13 to the floor decodes with
> the vendored codec (two pair-scoped rejections aside, see "Deferred /
> rejected"). **Database population starts 2024-10-13**, the first full day of
> the `report.event` era (wire-born 2024-10-12 18:10 UTC). Below it the readings
> ride `gt.sh.status` v110 — the pre-channel telemetry model, proactor-wrapped,
> not JK-accepted — back to the archive's first key on **2022-08-20**; that era
> is a separate decision, not part of this walk-back. Remaining work is the
> queued JK wiring and the forward bulk load ("Open / next").

What this is: making the sema registry decode **every version of every type
JournalKeeper loads** that the S3 event store carries, so JK can (a) keep
decoding everything already in the journal DB and (b) back-fill the archive
below its current data floor (2026-01-09), walking backward version by
version. The scope is all JK-accepted message types, not one type.
`gjk.version_scan` walks the store
and, for each `(type_name, version)` pair it finds, decodes one real sample
through the current codec and says what (if anything) is wrong. Two failures
are possible, with different fixes:

- **need-version** — the codec has no such `(type, version)`. Author it as a
  new published sema word from the wire evidence.
- **translation mismatch** — the codec *has* that version but a real payload
  fails to decode. The sema definition mistranslates the wire; fix the
  definition, do not add a version.

`layout.lite` is the first and worst case — it predates sema, its schema
lived as a gwsproto/gwproto pydantic model that mutated without registry
discipline — so its walkback (v006 downward) is the pilot for the loop below.
Every other type the scan flags gets the same treatment. Companion to the JK
S3 backfill.

## Walk-back marker — start here, continue back

Production JournalKeeper holds data from **2026-01-09** onward (earliest
`messages.timestamp` / `readings.timestamp` in the prod DB; earliest
`layout.lite` there is v007). That is the floor: everything Jan 9 2026 →
present is already loaded, and the reconstruction walks **backward** from it,
one version at a time, back-filling what JK does not yet carry, down to the
**population start, 2024-10-13** (see "Where the old types live"). The
walk-back terminated when the window scans reached that start with every
accepted version decoding; the S3 archive continues below it (to 2022-08-20)
in the `gt.sh.status` era, outside this design's scope.

> **Scan cursor — read it from the log tree, never infer it.** The one
> authority on how far the walk-back has gone is
> `scratch/ops-498-walkback/logs/` (see that tree's README): one `.log` per
> completed full-scan window, and **the earliest filename IS the frontier** —
> the next window to scan ends the day before that file's start date. Do NOT
> create a new logs/ or samples/ folder anywhere else in `scratch/`; every
> scan window's log and samples land in that one tree. Do NOT derive the
> cursor from code history or from the date a type version was first
> introduced (e.g. jumping back to `layout.lite`'s intro): that skips the
> intervening weeks and misses OTHER accepted types that changed in between.
> The cursor advances ONLY when a completed window scan lands its log there.
>
> **Recording new progress — always here.** Every additional window you scan
> is recorded by writing its `<start>_<end>.log` (and `--save-samples` output)
> into `scratch/ops-498-walkback/logs/` and appending to `_progress.log` —
> that IS how the frontier moves. Nowhere else records walk-back position: not
> this design, not the changelog, not Linear. The log tree is the source of
> truth; the single frontier snapshot for readers is the callout at the top of
> this file and nowhere else.
>
> **Authored floor: `layout.lite:004`** — authored down to its wire life (~Feb–Dec
> 2025) via **code archaeology + targeted per-date sampling**, NOT the full scan.
> So layout.lite / ha1.params / pico.tank are reconstructed across that span, but
> OTHER accepted types in Feb–Nov 2025 are NOT yet scan-verified. v004's true
> first wire day is unpinned (earliest confirmed 2025-02-15; sits after code intro
> `0821e88e` 2025-01-20 + deploy lag, above the v003 boundary). Done in sema (landed on dev `bb8062d`):
> `layout.lite:004` + its missing sub-types `ha1.params:002`/`:003` and
> `pico.tank.module.component.gt:000`/`:010` (all union-flattened from real wire);
> plus the `pico.flow.module.component.gt:000` SAIER MISM fix (separate commit).
> Prior batch (`fda1d2b`): `layout.lite:006`/`:005`, `atn.bid:001`, `pqu:000`.
> **2025-04-14 batch** (sema `2481f11`, gjk snapshot `b9b3e80`):
> `scada.params:002` (NewParams/OldParams `oneOf` over `ha1.params` 001/002/003),
> `flo.params.house0:002` (two-band single-`InitialThermocline`), and
> `ha1.params:001` (pre-`LoadOverestimationPercent`). `created` stamps set to
> code-intro dates under the wire-consistency rule, with `ha1.params:002`/`:003`
> back-dated below `scada.params:002`.
> **⚠ This batch was authored from single samples and did NOT walk the full
> `git log`** (the failure the "Code archaeology" gate now guards against).
> `flo.params.house0:002` was wrong and has since been corrected to its true
> three-shape deploy-lag union (see its findings block below).
> **`scada.params:002` and `ha1.params:001` were re-checked against the full
> wire and are CORRECT as authored:** `ha1.params:001` had no intra-version
> shape change (stable 10 fields), and `scada.params:002`'s top-level shape is
> stable with its nested `ha1.params` version already modeled as
> `oneOf[001/002/003]` — the wire carries only ha1 001 and 003 nested (both
> bumped to 004 in the same commit `9f6c81fd`, so scada.params:002 can never
> wrap ha1 ≥004). EDD: real scada.params:002 payloads with nested ha1 001/003
> decode + round-trip. Low-risk residual: a scada.params:002 wrapping ha1:004
> would need an impossible partial deploy; no scada.params was emitted in the
> Dec 2025 sampling window.
>
> **v004's top-level shape is stable its whole life** (Feb 8 – Dec 8 2025, = v005's
> 16 keys); only two sub-types migrated under it (deploy-lag unions). v004's code
> intro `0821e88e` 2025-01-20 caps v003's top.
>
> **Resume by scanning below the logs/ frontier** — continue backward one
> window at a time toward the ~2024-09 archive start. Each window lands its log
> in `scratch/ops-498-walkback/logs/`.
>
> **Queued, not walk-back (separate topic branch):** (1) remove the forbidden
> `minItems` constraint on `atn.bid:002` `PqPairs`, replacing it with a
> non-empty axiom (check whether `price.quantity.unitless:001` carries one
> too), + a guardrail test sweeping type/enum schemas for forbidden primitive
> constraints; (2) JK wiring (step 6) for `005`/`004` / `atn.bid:001` / `pqu:000`
> and the new sub-types.

The forward range (Jan 9 2026 → present) needs no walk-back: it is already in
GJK, and the populated DB is its own wire↔sema match proof.

**Walk-back rhythm (scan a week → report → author → resume).** Scan backward
one week at a time. A week that surfaces nothing new (only already-authored
versions) just advances the cursor. The moment a week surfaces a type that
`need`s a version, **stop and report every type currently needed** — then
switch to the sema authoring track before scanning further back. Author the
**shallowest unauthored version per type** first (each version clones the
nearest newer one, so v005 precedes v004; `atn.bid` v001 sits directly below
its v002 floor). Deeper versions of the same type wait their turn. Only after
the reported batch is authored, verified, and wired does the week-by-week scan
resume. This keeps the registry always authored top-down from the floor, never
with a gap.

## Ground rules

- **Source of truth is the actual field record in S3.** Git explains *why* a
  shape changed; the emitted payloads decide what the sema definition accepts.
- **Wire beats registry, but never silently.** The sweep MAY show that a
  `(type, version)` the registry already declares does not match what is on
  the wire for that version (a `MISM` row, or a walkback sample that
  contradicts a published word). The archived messages are the authority —
  they are what was emitted. But every such discrepancy MUST be flagged and
  worked through with the human before any registry edit: what the wire
  shows, what the word says, which houses/dates, and the proposed fix
  (in-place correction under the pre-June-2026 allowance, or a new version).
  Never fold a discrepancy fix into a walkback authoring change.
- **Read the shipped line only** — the code that produced the archive, not
  renovation branches (sema 012 top-level shape aside, 013's
  `ActuationAuthority`/`ServiceMode` never reached the field). Which repo
  that is depends on the date — see "Where the old types live".
- **Any type published to S3 is authored `published`**, never staging.
- **ALL VERSIONS OF `layout.lite` AT OR BELOW v012 MUST BE PUBLISHED.** These
  are the versions the field actually emitted and the S3 archive carries;
  every one is immutable published vocabulary. Only v013 (the renovation
  version, never shipped) is `staging`. So back-filling a version ≤ v012
  below the lineage is required, not merely allowed — the fact that the
  word's `latest_version` (013) is staging does NOT block it: the
  never-version-a-staging-word rule targets *extending* a staging line, not
  inserting historical published versions beneath it (v006 was back-filled
  this same way).
- **Backdate `created` stamps as needed** (permitted descriptive correction):
  a back-filled version's stamp must sit below the floor version's and above
  its dependencies' — which cascades into dependency subtrees (enums
  especially). Record every move in the Timestamp ledger below.
- Identity is the channel/node **Id**, never the Name — names migrate across
  categories and versions (v007's `buffer-depth1` derived channel is a new Id;
  the v006 data channel of that name became `buffer-depth1-device`).

## Where the old types live

The archive spans two homes for the type definitions:

| Wire period | Definitions in | Notes |
| --- | --- | --- |
| 2022-08-20 → 2024-10-12 | `gridworks-protocol` (`gwproto`) | the `gt.sh.status` v110 era: readings keyed by node alias + telemetry name, proactor-wrapped; not JK-accepted, below the population start |
| 2024-10-13 → ~Sept 2025 | `gridworks-protocol` (`gwproto`) | the `report.event` era; the only home; tags `v1.2.x`–`v1.3.x` |
| ~Sept 2025 → Jan 2026 | either | `gwsproto` created 2025-09-17 (`gridworks-scada` `bdff8560`, PR #368) under `packages/gridworks-scada-protocol/`; new/changed types land there while scada still imports the rest from `gwproto` (last gwproto tag `v1.3.3`, 2025-12-04) |
| Jan 2026 → present | `gwsproto` | import migration `gwproto ⇒ gwsproto` 2026-01-03 (`f299f606`) |

So for most of the span — and for most types — the code history to read is
**`gridworks-protocol` `dev`**, not scada. Pin the repo before the
archaeology step: `git log -S 'Literal["NNN"]'` across both, and trust the
one whose commit dates sit inside the wire bracket.

## Code archaeology before authoring

### The Birth Ledger Gate (hard checklist — do this FIRST, every version)

Types are born in **`gridworks-protocol` (`gwproto`)** and *later move* to
`gridworks-scada`. The scada commit that adds a type is usually a **move, not a
birth** — anchoring on it gives a code date that is *later* than the wire, and
every "deploy divergence" hand-wave in this design's history was that mistake.
Before authoring version `NNN` of a type, produce its **birth ledger**:

1. **Cross-repo birth.** `git -C <repo> log --all -S 'Literal["NNN"]' --
   '**/<model>.py'` in **BOTH gwproto and scada.** The **earliest** hit across
   both repos is the true code birth (hash + date). Never use the scada
   move-in date as the birth.
2. **Full-life diff.** `git log -p` (or `-S` per field) on the model from that
   birth to the `NNN+1` intro, in whichever repo(s) hold that span — including
   the gwproto span *before* any scada move. List every commit that changed the
   wire-visible shape (field add/remove/optional/retype) with **no version
   bump**. `SynthChannels` was added to `layout.lite:002` mid-life by gwproto
   `a280f96` with no bump; anchoring on the scada move (`56de3baa`, a week late)
   hid it and produced a MISM.
3. **Wire first-seen.** From the scan logs / a probe, the first S3 date the
   version appears. Sample the union of shapes **from this date forward**, not
   from the code-intro date.
4. **THE INVARIANT — the wire can never predate the code birth.** If
   wire-first-seen is *earlier* than your code birth, you have the wrong (too
   late) birth: STOP and redo step 1 across both repos. This is the tripwire
   that catches a move-date mistake mechanically.

**Enforcement one-liner (ask before any authoring):** *"Show me the birth
ledger: earliest `Literal["NNN"]` in gwproto AND scada, every no-bump shape
change across its life, the wire first-seen — and confirm wire-first-seen is
not earlier than the code birth."* An answer that cannot name the gwproto
search, or where wire precedes code, means the gate was skipped.

**MANDATORY GATE — a version is not ready to author until EVERY commit
(gwproto AND scada) that touched the model across that version's whole life has
been read.** This is not optional diligence; it is the definition of
"authored". The developers
of that era (2024–2025) did not always follow sema protocol: a pydantic model
could change shape — a field added, made optional, renamed, re-typed —
**without a version bump**, so one `Version` string carries several shapes on
the wire. Modeling a single sampled payload (or trusting the scan's `ok`,
which decodes only one sample per pair — see "All types" below) produces a
word that decodes the shape you happened to sample and silently fails the
others. `flo.params.house0:002` was first back-filled that way — one late
sample — and missed two earlier wire shapes (`DischargingDdDeltaTF`, and the
pre-`FloAlias`/`FloGitCommit` base); the union was only recovered by walking
the full `git log`. Treat the code-history walk as the gate that defines the
shape set, and the wire as the authority on which of those shapes actually
shipped. Before authoring any back-filled version:

1. **Enumerate every commit that touched the type within the version's
   life** in the owning repo: `git log --follow -p <path>` from the commit
   introducing `Literal["NNN"]` to the one introducing `NNN+1`, plus every
   enum / sub-type file it references (those mutate independently and are
   not versioned by the parent).
2. **Diff each commit for a wire-visible change** — field set, optionality,
   type, enum values, validator behavior that affects what was emitted.
   Refactors, docstrings and import moves are noise (`f299f606` is the
   model example).
3. **Map each shape onto the wire bracket** using deploy lag: a code change
   reaches S3 only when a house redeployed, so different houses can emit
   different shapes of the same version for weeks. Sample S3 on both sides
   of each shape change, per house, to confirm which shapes were actually
   emitted.
4. **Express the result as one word version.** One shape → a plain schema.
   Several emitted shapes under one `Version` → a **union** (`oneOf` of
   the shapes, or per-field optional/union where shapes differ only
   locally) so that one published word decodes every archived payload
   carrying that version string. The union's prose says which shape ran
   when. A shape the code shows but the wire never carried is not
   modelled.
5. Record the findings in the version's "findings" block (as for v006) so
   the next reader does not redo the dig.

## All types, not just `layout.lite`

The already-loaded range (Jan 9 2026 → present) needs no scan: those messages
are in GJK, and they got there by decoding through the codec on the way in —
the populated DB **is** the wire↔sema match proof for that range. The scan is
only for the pre-floor range the walk-back reconstructs.

The check rides the walk-back. `gjk.version_scan` over each backward window
reports **every** `(type, version)` present in that window, not only
`layout.lite`: it reads `Payload.Version` straight off the JSON (no codec),
bisects each `(type, house)` stream to pin version boundaries cheaply, then
decodes one sample per pair and classifies it `ok`, `need` (author a
version), or `MISM` (fix the definition).

**`ok` is a one-sample verdict — it cannot see intra-version shape drift.**
The scan decodes exactly one payload per `(type, version)` per window, so a
version that silently changed shape mid-life (a field added or dropped with no
version bump) reads `ok` whenever the sampled payload happens to match, while
other payloads of that same version fail. So `ok` means "at least one payload
decodes", never "this version is fully modeled". Trust in a back-filled
version comes only from the mandatory code-history walk (see "Code archaeology
before authoring") plus per-house wire sampling across the version's full
bracket — never from a green scan row. Types JK does not accept are counted
and ignored — the `acc` column comes from the persistor's own registry, so
scope tracks JK code, not a hand-kept list. `--save-samples` writes the wire
evidence per pair. So every walk-back step surfaces any *other* accepted type
that also needs a version in that window; those join the work list, each run
through the same per-version loop.

## The per-version loop

For each `need` pair the sweep uncovers (for `layout.lite`: v005 next, then
v004, v003, …):

1. **Wire-confirm the schema.** Sample real payloads across the version's
   range (multiple houses, spanning any code migrations): top-level field
   presence + nested sub-type keys + each sub-type's `Version`. Fields not in
   100% of payloads become optional; a shape that mutates within one version
   needs a union.
2. **Bracket its dates.** Code range from the owning repo's `dev` history
   (`git log --follow -S 'Literal["NNN"]'` — see "Where the old types
   live"); wire range from S3 (deploy lag trails the code bump).
   `gjk.version_scan` gives the per-week inventory cheaply.
3. **Code archaeology** (section above): every wire-visible code change
   inside the bracket, mapped to what the houses actually emitted. Output:
   one shape, or the set of shapes that the word must union.
4. **Author the sema version** below the current floor: clone the nearest
   newer version, apply the wire-confirmed deltas (union where step 3
   found several shapes), pin sub-type `$ref`s to the wire-observed
   versions. Registry entry `published`; fix `created`
   ordering (ledger). Run `scripts/regenerate_runtime.py`; port axiom
   implementations (copy from the adjacent version where axioms are
   unchanged); write the upgrade template — `UpgradeRequiresContext` if the
   next version's fields aren't derivable from the message alone. Hash-pin
   (`python -m sema.tools.published_hashes`), rebuild indexes
   (`scripts/build_indexes.sh`), suite green.
5. **Verify against reality** (the EDD bar): a real archived payload decodes,
   passes axioms, round-trips at own version (`sema validate` reports
   OK-at-own-version on context refusal).
6. **Wire JK:** add the version to `src/gjk/sema_seed_request.yaml`, regen
   the snapshot, add `persist_vNNN`, append the class to
   `SYNTH_ERA_LAYOUTS` if it carries SynthChannels. Verify with a capped
   import of a real message.

## All-types scoreboard

Accepted types the walk-back has flagged `need`/`MISM` below the Jan-9 floor.
The loaded range (Jan 9 2026 → present) is proven by GJK itself and is not
listed. Filled from `version_scan` output as the walk-back scans each backward
window; a type appears here only once a pre-floor window surfaces a failing
pair for it.

| Type | Window | Pre-floor versions → status | Open |
| --- | --- | --- | --- |
| `layout.lite` | Dec 2025 ← | 006 ✅; 005 ✅; 004 ✅ `bb8062d`; 003 ✅; 002 ✅ (SynthChannels optional — MISM fixed); 001 ✅ (no i2c/synth, ha1:000); 000, … → need | 001 next-below is 000 |
| `flo.params.house0` | Dec 2024 – Apr 2025 ← | 002 ✅ (3-shape union, corrected); 001 ✅ (4-shape union); 000 ✅ (earliest 35-key shape) | JK-wire pending |
| `snapshot.spaceheat` | Nov 2024 – Feb 2025 | 002 ✅ (LatestStateList = machine.states:000) | JK-wire pending |
| `i2c.multichannel.dt.relay.component.gt` | Dec 2024 (sub-type of layout.lite:002) | 001 ✅ (ConfigList = relay.actor.config:001) | JK-wire pending |
| `relay.actor.config` | Dec 2024 (sub-type of i2c:001) | 001 ✅ (no StateType/DeEnergized/EnergizedState — EDD caught StateType) | JK-wire pending |
| `ha1.params` | Nov 2024 – Dec 2025 (sub-type of layout.lite / scada.params) | 003 ✅, 002 ✅ `bb8062d`, 001 ✅, 000 ✅ (leaf; 001 = 000 + `MaxEwtF`; 002 = +`LoadOverestimationPercent`; 003 = +`StratBossDist010`) | JK-wire pending |
| `scada.params` | Nov 2024 – Dec 2025 | 002 ✅ (ha1 001\|002\|003 union); 001 ✅ (ha1:000); 000 ✅ (free-form param-setter, no NewParams/OldParams) | JK-wire pending |
| `pico.tank.module.component.gt` | Oct 2024 – Dec 2025 (sub-type of layout.lite ≤004) | 010 ✅, 000 ✅ sema `bb8062d` (SCADA ComponentGt shape; union-flattened; axioms 1-2, not 3) | JK-wire pending |
| `atn.bid` | Dec 18 2024 – Dec 11 2025 (full v001 life) | 001 ✅ sema (union of pqu 000\|001); v002 summary→delta | JK-wire pending |
| `price.quantity.unitless` | Dec 2024 ← (sub-type of atn.bid) | 000 ✅ sema (hidden; renamed to 001 ~Oct 2025) | JK-wire pending |
| `pico.flow.module.component.gt` | ≤004 (MISM, not need) | 000 `FlowMeterType` ref `make.model:003`→`007` (SAIER on wire); fixed in-place `--rewrite` | resolved (whole layout.lite line) |

## `layout.lite` scoreboard

Wire ranges from S3 sampling (hw1); sema/JK columns = done state.

| Ver | Wire range (S3) | Top-level shape vs neighbor | sema | JK persist |
| --- | --- | --- | --- | --- |
| 003 | Jan 1 – Jan 21 2025 (code `81ea92e1` 2025-01-01 → v004 `0821e88e` 2025-01-20) | = v004 top-level, but `Ha1Params` oneOf[001\|002] and `TankModuleComponents` single tank 000; axioms 1,2 | ✅ | — |
| 002 | Dec 10 2024 – Jan 1 2025 (code `56de3baa` 2024-12-10 → v003 `81ea92e1` 2025-01-01) | = v003 top-level, but `Ha1Params` single 001 and `I2cRelayComponent` oneOf[i2c 001\|002]; axioms 1,2 | ✅ | — |
| 004 | Feb 8 2025 ← Dec 8 2025 (top-level shape stable = v005's 16 keys its whole life) | = v005, but `Ha1Params` oneOf[002\|003] and `TankModuleComponents` oneOf[tank 000\|010] (deploy-lag unions); axioms 1,2 | ✅ `bb8062d` | — |
| 005 | Dec 8 17:33 – Dec 12 20:26 2025 (overlaps 004, 006) | 006 + `FromGNodeInstanceId` − `CriticalZoneList`; axioms 1,2 (not 3) | ✅ (branch) | — |
| 006 | Dec 12 2025 – Jan 6 2026 (first wire 12-12 03:18) | v007 − `DerivedChannels`/`TMap` + `SynthChannels` | ✅ `73659f2` | ✅ `4aef3df` |
| 007–011 | Jan – ≥Feb 2026 (007/008 mid-Jan; 009 late Jan–Feb; 010/011 late Feb) | tracks dev; 010/011 = `Ha1Params`-only bumps | pre-existing | pre-existing |
| 012 | (not yet confirmed on wire) | = 011 top-level | pre-existing | pre-existing |
| 013 | never shipped (renovation) | diverges | staging | n/a |

Versions ≤005 also carry SynthChannels (v004 confirmed on wire); v001
(Dec 2024) has **no** SynthChannels field at all — expect more shape
variety walking back.

## Timestamp ledger (sema `created` back-dating)

**Grounded** = real code-commit or first-S3 date. **Consistent** = plausible
placeholder satisfying the ordering rule only — provisional; move earlier if
an older version's back-fill needs it. Moving a stamp earlier never breaks
referrers (they need only `created ≥` deps); the cascade runs downward.

| Word:version | `created` set | Basis | Grounded? |
| --- | --- | --- | --- |
| `layout.lite:006` | 2025-12-10 | dev intro `cb72c61d` 2025-12-10; wire from ~12-12 | **grounded** |
| `layout.lite:005` | 2025-12-09T12:00 | wire first-seen Dec 8 17:33, but dep floor (`spaceheat.node.gt:200`, `synth.channel.gt:000` at 2025-12-09) forces ≥ Dec 9; capped < v006 (Dec 10) | consistent (dep floor > wire) |
| `price.quantity.unitless:000` | 2024-12-05T19:25 | code-add of AtnBid+PQU (`9d514f4` 2024-12-05); wire from Dec 18 2024; no deps | grounded |
| `atn.bid:001` | 2025-11-01T00:00 | wire birth Dec 18 2024, but union dep `price.quantity.unitless:001` (2025-10-30, the rename) floors it; capped < v002 (2026-05-13) | consistent (union dep > wire) |
| `spaceheat.node.gt:200` | 2024-12-07 (was 2025-12-09) | back-dated below `layout.lite:003` (2025-01-01); wire since ≥2024-12; deps are formats | consistent |
| `synth.channel.gt:000` | 2024-12-07 (was 2025-12-09) | back-dated below `layout.lite:003`; ≥ dep `spaceheat.telemetry.name:007` (2024-12-06) | consistent |
| `data.channel.gt:001` | 2024-12-07 (was 2025-09-24) | back-dated below `layout.lite:003`; ≥ dep `spaceheat.telemetry.name:006` (2024-12-05) | consistent |
| `spaceheat.telemetry.name:007` | 2024-12-06 (was 2025-12-08) | enum, birth unobservable; back-dated below `synth.channel.gt:000`, above `006` | consistent |
| `spaceheat.telemetry.name:006` | 2024-12-05 (was 2025-09-24) | enum, birth unobservable; back-dated below `data.channel.gt:001` | consistent |
| `ha1.params:003` | 2025-02-13T06:25:00Z | dev `StratBossDist010` add `51716e73` 2025-02-13; leaf (no deps); capped < `004` (2025-12-04) | **grounded** |
| `ha1.params:002` | 2025-02-01T00:00:00Z | wire ≥ Feb 2025 (fir); leaf (no deps); lowest tracked, capped < `003` | consistent (wire floor) |
| `pico.tank.module.component.gt:010` | 2025-06-28T12:00:00Z | dev v010 intro `486e7c5` 2025-06-28; deps floor far below; capped < `011` (2025-12-05) | **grounded** |
| `pico.tank.module.component.gt:000` | 2024-10-21T23:20:00Z | dep floor `temp.calc.method:000` (2024-10-21T23:19) + the `TempCalcMethod`-add commit `dc5d134` same day; true code birth 2024-10-18 | consistent (dep floor > code birth) |
| `spaceheat.make.model:007` | 2024-10-20T00:00:00Z (was 2026-01-03) | MISM fix: back-dated below referrer `pico.flow.module.component.gt:000` (2024-10-23) so it can pin `:007` (carries `SAIER__SENHZG1WA`, on wire since Feb 2025); window `003` (2024-10-18) < `007` < `008` (2026-06-12) | consistent (value predates enum's formal version) |
| `flo.params.house0:001` | 2025-01-18T00:00:00Z | code intro `4283520b` 2025-01-18; deps floor far below (`market.price.unit:000` 2024-12-05); capped < `002` (2025-02-11) | **grounded** |
| `layout.lite:003` | 2025-01-01T00:00:00Z | code intro `81ea92e1` 2025-01-01; forced the deps cascade above (spaceheat.node.gt / synth.channel.gt / data.channel.gt / telemetry 006-007 back-dated below it); capped < `004` (2025-12-09) | **grounded** |
| `snapshot.spaceheat:002` | 2024-11-13T00:00:00Z | code intro `6111d13` (gwproto) 2024-11-13; deps `machine.states:000` (2024-11-09), `single.reading:000` (back-dated); capped < `003` (2026-03-30) | **grounded** |
| `single.reading:000` | 2024-11-08T00:00:00Z (was 2026-03-30) | back-dated below `snapshot.spaceheat:002`; deps are 2024-09 formats | consistent |
| `flo.params.house0:000` | 2024-12-18T00:00:00Z | code intro `90b7b16a` 2024-12-18; deps floor `market.price.unit:000` (2024-12-05); capped < `001` (2025-01-18) | **grounded** |
| `layout.lite:002` | 2024-12-10T00:00:00Z | code intro `56de3baa` 2024-12-10; forced the i2c/relay.actor.config cascade below it; capped < `003` (2025-01-01) | **grounded** |
| `relay.actor.config:001` | 2024-12-03T00:00:00Z | code intro `85d75cf` 2024-12-03; deps 2024-09 formats/enums (incl. back-dated `non.empty.string`); capped < `002` | **grounded** |
| `i2c.multichannel.dt.relay.component.gt:001` | 2024-12-03T13:00:00Z | code intro `85d75cf`; ≥ dep `relay.actor.config:001` (2024-12-03T00:00); capped < `002` | **grounded** |
| `relay.actor.config:002` | 2024-12-08 (was 2024-12-31) | back-dated below `layout.lite:002` / `i2c:002`; ≥ its deps | consistent |
| `i2c.multichannel.dt.relay.component.gt:002` | 2024-12-09 (was 2024-12-31) | back-dated below `layout.lite:002`; ≥ dep `relay.actor.config:002` (2024-12-08) | consistent |
| `non.empty.string` (format) | 2024-09-02 (was 2024-12-31) | back-dated below `relay.actor.config:001`; format, no deps | consistent |
| `ha1.params:000` | 2024-11-15T00:00:00Z | code intro (gwproto) 2024-11-15; leaf (formats only); capped < `001` (2024-12-03) | **grounded** |
| `scada.params:000` | 2024-11-15T00:00:00Z | code intro `08341d4` 2024-11-15; format deps only; capped < `001` | **grounded** |
| `scada.params:001` | 2024-11-28T00:00:00Z | code intro `a660509` 2024-11-28; ≥ dep `ha1.params:000` (2024-11-15); capped < `002` (2024-12-10) | **grounded** |
| `layout.lite:001` | 2024-11-28T00:00:00Z | code intro `a660509` 2024-11-28; forced node:200/dc:001/telemetry:006 back-dates below it; capped < `002` (2024-12-10) | **grounded** |
| `spaceheat.node.gt:200` | 2024-11-25 (was 2024-12-07) | further back-dated below `layout.lite:001`; deps are formats | consistent |
| `data.channel.gt:001` | 2024-11-25 (was 2024-12-07) | further back-dated below `layout.lite:001`; ≥ dep `spaceheat.telemetry.name:006` (2024-11-24) | consistent |
| `spaceheat.telemetry.name:006` | 2024-11-24 (was 2024-12-05) | further back-dated below `data.channel.gt:001` | consistent |

Likely next to need back-dating (walking to v005/v004/v003):
`spaceheat.telemetry.name:006`, `data.channel.gt`, `ha1.params`, `pico.*`,
`i2c.*` lines — check each against the target version's floor.

## atn.bid v001 findings (distilled)

- Top-level shape stable across v001's whole life (Dec 18 2024 – Dec 11 2025):
  the small field set (= v002). The larger `atn_bid_001.py` shape in the code
  was **dead code** — it appears in no wire window.
- The trap was one level down: the `PqPairs` **sub-type version migrated
  within** v001. `price.quantity.unitless` went 000 (`PriceTimes1000`/
  `QuantityTimes1000`, Dec 2024 – Apr 2025) → 001 (`PriceX1000`/
  `QuantityX1000`, ~Oct 2025) with **no bump to atn.bid**. So v001 must union
  both (`oneOf[pqu:000, pqu:001]`), and pqu:000 had to be authored (it was
  missing from the registry). Sampling one payload would have modeled only
  one shape; the EDD decode of all windows caught it.
- v001→v002 upgrade normalizes any pqu:000 pairs to pqu:001 (nested-upgrade
  discipline); v002 pins pqu:001 only (its wire life is Jan 2026+, all 001).
- Lesson: a stable top-level shape does not imply stable sub-types. Check each
  sub-type's `Version` across the full range, not just the top-level fields.

## flo.params.house0 v002 findings (distilled)

- **Version 002 silently carried three top-level shapes** over its wire life
  (scada `dev`, no version bump): (A) `+DischargingDdDeltaTF`, no
  `FloAlias`/`FloGitCommit` (the "Hinge" model, `2611c10e` 2025-02-25); (B) a
  brief transition with all three (25–26 Mar 2025); (C) `+FloAlias`/
  `FloGitCommit`, no `DischargingDdDeltaTF` (Winter.Oak, `69824dea` 2025-03-25
  onward). All four keene houses confirm the timeline; all three share a common
  base, so the three fields are each **optional** — no `oneOf`, just optionality
  (`additionalProperties: true` already).
- **The first back-fill modeled only shape C** (`FloAlias`/`FloGitCommit`
  required, no `DischargingDdDeltaTF`) — it sampled one late payload and never
  walked the `git log`, so shapes A and B failed decode. Corrected **in place**
  (published-hash `--rewrite`, human-sanctioned; nothing served yet) to the
  optional-field union. EDD: real A/B/C payloads all decode at own version and
  round-trip; suite green.
- **Version tags and code `Version` literals diverge on the wire.** The same
  `+DischargingDdDeltaTF` shape appears under both `Version="001"` (to 2025-03-24)
  and `Version="002"` — the FLO params emitter (private `gridworks-innovations`
  build) stamped a `Version` not tracking the scada model's literal.
- **v001 authored (four-shape deploy-lag union).** Full-life wire sampling
  (Jan 20 – Mar 24 2025, all four keene houses) plus the `git log` walk found
  v001 grew fields without a bump: birth shape (2025-01-20) lacked
  `BufferAvailableKwh`/`HouseAvailableKwh`/`InitialBottomTempF`/
  `DischargingDdDeltaTF`; Buffer/House added 2025-01-20; `InitialBottomTempF`
  stable 2025-02-11; `DischargingDdDeltaTF` (Hinge) 2025-02-25. Those four are
  optional; `FloAlias`/`FloGitCommit` never appear (v002 only). `created`
  2025-01-18 (code intro `4283520b`); `001->002` upgrade `requires_context`
  (v002 makes Buffer/House/InitBottom required). EDD: all four real shapes
  decode at own version + round-trip, upgrade refuses; suite green (491).
- Lesson (now a design gate): author only after reading **every** scada commit
  across the version's life; a green `version_scan` row is one sample, not a
  full-shape proof.

## v006 findings (distilled)

- Schema stable its whole life (one intro commit `cb72c61d`; gwproto⇒gwsproto
  migration `f299f606` was import-only). 30 wire payloads across the window,
  5 houses: all 14 top-level fields in 30/30; only nested optional is
  `ShNodes[].Strategy`.
- Sub-type pins (wire-confirmed): `spaceheat.node.gt:200`,
  `data.channel.gt:001`, `synth.channel.gt:000`,
  `pico.tank.module.component.gt:011`, `pico.flow.module.component.gt:000`,
  `ha1.params:004`, `i2c.multichannel.dt.relay.component.gt:002`.
- 006→007 redesigned the derived layer: only 2 of 14 synth Ids survive as
  DerivedChannels (`required-energy`, `usable-energy` — also the only 2 that
  ever appear in report.event readings). Hence the upgrade is
  `UpgradeRequiresContext`, and JK keeps v006 as v006.
- Data-channel Ids are 76/76 stable across the transition; **no data Id is
  ever reused as a derived Id** (candidate future axiom: data channels ≠
  derived/synth channels).
- JK channel policy: data + pseudo + `REPORTED_SYNTH_CHANNELS`
  (`required-energy`, `usable-energy`, as `synth.channel.gt`); the 12
  unreported synth intermediates get no rows. At the 007 transition the
  standard mismatch step retires synth rows and creates derived ones.

## Working state

- Scan workspace: `scratch/ops-498-walkback/` (under the umbrella dir) —
  `logs/` (the frontier authority, per the marker section), `samples/` per
  window, `probes/` for targeted digs, `analysis/` for archaeology scripts.
  Its README carries the folder rules.
- Dev DB: container `gw-data-pg`, `localhost:5433/tsdb`, schema `gridworks`
  at gridworks-data main head; role `gw_journalkeeper`/`changeme`. All
  session writes are local-only.
- Capped-import wrapper (reads all, persists one per (type, version)):
  `~/.claude/projects/-Users-jessica-GridWorks/scratch/s3_import_devcap.py`
  (uncommitted by design; run from the JK repo root with `GJK_DB_URL`
  pointing at the dev DB).

## Open / next

- **Done (sema, dev `bb8062d`):** `layout.lite:004` + `ha1.params:002`/`:003` +
  `pico.tank.module.component.gt:000`/`:010` — authored from real wire evidence,
  EDD-verified (17 real v004 layouts spanning both union branches + 85 real tank
  objects decode + axioms + own-version round-trip; `004→005` is
  `UpgradeRequiresContext`). Plus a follow-on commit fixing the
  `pico.flow.module.component.gt:000` SAIER MISM (see below).
- **Done (sema, dev `fda1d2b`):** `layout.lite:005`, `atn.bid:001`,
  `price.quantity.unitless:000`.
- **MISM resolved (sema, follow-on commit):** `pico.flow.module.component.gt:000`
  `FlowMeterType` referenced `spaceheat.make.model:003`, which lacks
  `SAIER__SENHZG1WA` (on wire since Feb 2025) → silent coercion to
  `UnknownMake__UnknownModel`. Repointed to `make.model:007` + back-dated `007`
  (in-place correction, `published_hashes --rewrite`). Affected the whole
  layout.lite line (v004/v005/v006 all pin pico.flow:000).
- **Scan complete** (2024-09-16 → 2026-01-09, no window gaps): every
  accepted need surfaced is authored and vendored — `layout.lite` 001–005,
  `scada.params` 000–002, `ha1.params` 000, `flo.params.house0` 000–002,
  `atn.bid` 001, `snapshot.spaceheat` 001–002, `report` 001, `report.event`
  000, plus the nested sub-types.
- **Persistor wiring ✅ (built, pending commit) — loading is the next track.** Dispatch is
  `custom_persistor_lookup[type].persist_v<NNN>`; a missing method falls back
  to `persist_message_default` (message row only, no readings). Import range
  per type: 2024-10-13 → that type's earliest DB row (report.event & co.
  2026-01-09; scada.params 2026-03-03; ticklist.hall 2026-04-13;
  snapshot.spaceheat 2026-07-10). The map, from the persistor code against the
  vendored classes and the S3 inventory:
  - `report.event` — v002/v003 ✓; **v000 needed** (26,358 msgs, 2024-10-12 →
    11-12). Its `report:001` has no `StateList` (`FsmActionList` instead), so
    `collect_channel_state_readings` must skip on `Report001`; channel readings
    and zone heat-call readings work unchanged.
  - `layout.lite` — v006–v012 ✓; **v001–v005 needed** (90 / 507 / 374 / 4161 /
    50 msgs). All are synth-era (`SYNTH_ERA_LAYOUTS` + `ModernLayout` widen);
    v001 has no `SynthChannels` field and v002's is optional — guard the sync.
  - `flo.params.house0` — **only `persist_v007` exists**. Wire versions in the
    import window: v000 (71), v001 (3588), v002 (1614), v003 (5767), v004
    (4881); and the DB already holds v004/v005/v006 (Jan 9 → Mar 2 2026,
    ~3,100 msgs) persisted by the default path, i.e. **without** the
    `buffer-available-kwh` / `lmp` / `total` pseudo-readings. **Decision: a
    small replay script**, not an S3 re-import — select those `messages` rows,
    decode each stored `payload` through the codec, and run it through
    `persist_message` (the `messages` insert is `on_conflict_do_nothing` on
    `(timestamp, id)`, so only `add_readings` does new work). Runs in the
    loading session, after the persistors land. `add_readings` needs: v000 has no
    `BufferAvailableKwh` at all, v001 has it optional; `LmpForecast` /
    `DistPriceForecast` optional in every version (already guarded).
  - Default-path types need no per-version method; their id/created_at field
    maps hold for every vendored version: `snapshot.spaceheat` 001–002
    (`SnapshotTimeUnixMs`), `scada.params` 000–002 (`UnixTimeMs`, `MessageId`),
    bare `report` 001 (obsolete map), `atn.bid` 001 (basic), and
    `energy.instruction`, `glitch`, `gridworks.event.problem 001`,
    `heating.forecast`, `latest.price`, `new.command.tree`, `power.watts`,
    `ticklist.*`, `weather.forecast` (single version each).
  - Built: `persist_v000` (report.event), `persist_v001–005` (layout.lite,
    with `SynthEraLayout`/`DerivedEraLayout` aliases so the sync methods
    type-narrow), `persist_v000–006` (flo.params.house0). Verified: ruff,
    pyright clean, suite green, and every version's real wire sample
    dispatches to its method. NOT yet exercised: the `additional_db_operations`
    (channel sync / readings insert) against a database — the loading session
    runs those first against the dev DB (`gw-data-pg`) before prod.
  - Readings only land for channel names active in `reading_channels` for the
    house at persist time — see bulk-load sequencing below; no `layout.lite`
    exists on the wire before 2024-12-01, so Oct–Nov 2024 report readings
    depend on channels created by later layouts.
- **Queued (separate branch):** forbidden-`minItems` fix + guardrail sweep
  test.
- **Bulk-load sequencing (decision pending):** channel sync's
  deactivate-absent step assumes forward time order — an older layout
  imported after a newer one retires the newer era's channels. Proposal:
  discovery walks backwards, but the eventual bulk load runs forwards, after
  all versions in the span are authored; then no code change is needed.
- Sema is change-controlled — the read-receipt gate precedes any registry
  edit.

## Loading track (2026-08-25 review)

Findings from tracing the read side (`gridworks-web-backend`) and the JK
write path before the bulk load.

- **Back-filled rows render as-is.** `readings` has no persisted-at column
  (`gridworks-data/src/gw_data/db/models/reading.py:22-53`); plots and CSV
  select on `readings.timestamp` only (`api/v2/routers/synced_readings_bundle.py:126-152`,
  `api/v2/routers/readings_csv.py:231-240`), no join to `messages`, no
  `deactivated_date` filter. The S3 import sets `messages.persisted_at` from
  the S3 key time and `timestamp = created_at` (`s3_message_importer.py:76-81`,
  `sema_message_persistor.py:176-194`), so back-filled messages look like
  messages JK wrote at the time, and the plot's late-persistence shading
  (`synced_readings_bundle.py:302-310`) stays honest.
- **Hazard A — channel sync is last-writer, not time-aware.**
  `layout_lite_persistor.py` deactivated every active channel absent from
  the layout being processed (and on unit mismatch). A 2024 layout loaded
  into prod would have deactivated a house's live channels; live
  `report.event` readings then drop silently until the next live layout
  re-creates them under new ids. **Fix (built):** a layout older than the
  newest `layout.lite` in `messages` for the TA syncs add-only — nothing
  active is touched; everything it carries that is not active in the same
  definition becomes an **era row**, retired at the earliest newer layout's
  time (`ReadingChannelSyncProcess.add_era_row`).
- **Channel definitions change under one name.** Confirmed from wire for
  beech: `buffer-depth1` (and every `tank{i}-depth{j}`) is a
  `WaterTempCTimes1000` data channel in layouts v001–v006 (Nov 2024 → Dec
  2025) and a `FahrenheitX100` derived channel from 2026 (values `23120`
  vs `5921`). The front end scales by `reading_channels.unit`
  (`synced_readings_bundle.py:133`), so readings must attach to the row
  with their era's unit. **Built:** `reading_channel_eras.channel_ids_at`
  — per name, the row with the earliest `deactivated_date` after the
  report time, else the active row; `ReportEventPersistor` looks channels
  up that way. Rows carry no start date, so an era is identified by its end
  only; coherent as long as layouts load forward in time.
- **Load order: layouts first, then everything else, both forward.** Pass 1
  imports `layout.lite` over the whole span so every era row exists before
  any report is read (Oct–Nov 2024 reports predate the first wire layout
  and still find the Nov 2024 era rows); pass 2 imports the rest.
- **`gridworks.event.problem` is not back-filled at all.** Its pre-2026
  archive is dominated by a device-fault flap (2.9M rows in three weeks of
  Dec 2024 – Jan 2025, see Gleanings), it feeds no readings, and the
  history since Jan 2026 is enough. `scripts/s3_bulk_load.sh` (JK repo) skips it in every pass;
  the run summaries record what was listed and not loaded.
- **Load-time MISMs (found 2026-08-25 by the prod pass 1).** The walk-back
  scan decoded one sample per `(type, version)` per window; the load decodes
  everything and found two within-version shapes: `ha1.params:000` with
  `MaxEwtF` (label not bumped, Dec 3 2024) and `relay.actor.config:002`
  without `StateType` (Dec 31 – Jan 1). Both corrected in place in sema.
  **Rejected, not a mismatch:** 142 `layout.lite:004` messages (Jan 25 –
  Feb 4 2025) whose `temp-sense-disconnect-relay16` config is NormallyOpen
  with NormallyClosed event/state semantics; axiom 4 rejects them and
  stays. Neighbouring layouts on those days carry the same channels, so
  nothing is lost; the run summaries count them under `PARSE_FAIL`.
- **Idempotency is per-type, and needs both halves of the key.** `messages`
  is keyed `(timestamp, id)`; a message dedupes across the rabbit and S3
  paths only when the persistor takes both from the payload. Both:
  `report.event`, `layout.lite`, `scada.params`, `gridworks.event.problem`,
  the `gw.weather.*.gt` records. Created-at only (same timestamp, a
  path-dependent `uuid5(alias|type|persisted_ms)` id): `snapshot.spaceheat`,
  `glitch`, `energy.instruction`, `new.command.tree`, `ticklist.*`,
  `heating.forecast`, `gw.weather.forecast`, `flo.params.house0`,
  `weather.forecast`. Neither: `power.watts`, `atn.bid`, `latest.price`,
  weather cmd/ack/observation. Anything outside the first group would get
  a second row if the import overlapped the live era, so each type's range
  ends strictly before its earliest live row — the floors captured once
  before any back-fill (`FLOORS=<file>`), never re-derived from a DB that
  already holds back-filled rows. Making overlap safe for every word means a
  `MessageId` (and a created-at where missing) on each: a follow-on sema
  change, not part of this load.
- **Hazard B — hourly derivatives do not self-heal.** The `readings_1hr`
  continuous-aggregate policy and the `cached_hourly_data` refresh cover only
  the last two days (`gridworks-data/.../create_policy_view_readings_1hr.sql`,
  `create_proc_refresh_cached_hourly_data.sql`). After the load: manual
  `refresh_continuous_aggregate` over the range, then a delete-then-insert
  rebuild of `cached_hourly_data` (`refresh_all_cached_hourly_data.py` appends
  and would double `hp_kwh_el`).
- **`power.watts` is loaded like everything else.** It carries no created-at,
  so its `messages.timestamp = persisted_at` = the S3 key time; that makes the
  back-filled rows comparable against timestamped power readings, which is
  why they are kept. No readings are derived from it.
- **Monitoring for missed MISMs.** Extend the importer summary: dropped
  readings per `(TA, channel)` (today a silent `continue`), enum coercions
  (sha256 fallback at `report_event_persistor.py:107-116` and default-coercion
  detected against the raw payload), per-day `(TA, type, version)` totals to a
  JSONL log for a post-load SQL reconciliation (S3 count vs `messages`;
  `report.event` days with zero readings).
- **Where it runs, and how fast.** Throw-away EC2 in us-east-1 (S3 `gwdev`
  region) with an S3-read instance role; the boto client takes the region
  from settings. Measured from the laptop on 300 messages: S3 GET 100 ms
  sequential / 11.6 ms with 8 prefetch workers, decode 0.5 ms, DB persist
  9.5 ms with one commit per message (three or four round trips for a
  `report.event`). The importer prefetches GETs (`--workers`) and persists
  in one transaction per batch (`--batch-size`, default 500) with channel
  rows cached per session, so on the box the DB cost is essentially the
  readings insert.
- **EDD harness: `experiments/ops498-load/`** (`edd_dev_run.sh`). Seeds
  the dev DB (`gw-data-pg`) with prod's `reading_channels` and newest
  layout per house — the shape the prod load meets — then runs pass 1 and
  pass 2 over windows crossing every era (Oct 2024, Dec 1–3 2024, Dec 2024,
  Feb 2025, Dec 2025 — the layout-only window is Dec 1–3 2024, v001's wire birth) and checks: active channel set exactly unchanged;
  `buffer-depth1` era rows end at each house's newest layout; every
  (TA, day) with reports has readings; buffer readings sit in their era;
  the front end's CSV query verbatim and the bundle query return the
  earliest day with the era's unit; `readings_1hr` empty until the manual
  refresh; no degraded / failed / enum-fallback messages. In-code tests
  (`tests/test_channel_eras_backfill.py`, real TimescaleDB, real beech
  samples) cover the sync both orders and the era routing.
- Order: code + tests → dev-DB EDD run → push → pilot prod week → bulk forward
  load per type to its earliest DB row → cagg/hourly rebuild → flo.params
  v004–006 replay.

## Deferred / rejected: proactor event / ping / ack vocabulary

Parked, not part of the current walk-back. These proactor comm-infrastructure
types appear on the wire but are handled separately, on their own track — and
adding them to the sema registry does **not** imply loading them into GJK.
Until that work starts, `gjk.version_scan` **ignores** them via an explicit
`IGNORED_TYPE_NAMES` set — the unknowns listed individually, not by prefix, so
an authored sibling like `gridworks.event.problem` stays visible — and they do
not clutter the walk-back's `need` output.

**Rejected (never authored, never loaded):** a pre-versioning shape of
`gridworks.event.problem` — no `Version` field, nanosecond `TimeNS` timestamp
(the raw proactor `EventBase` shape) — appears in the earliest archive (21 msgs
Feb 2025, one `ng`-universe house). It is ancient and will never be used; only
the versioned `gridworks.event.problem` (the reports) and the channels matter.
So the `(gridworks.event.problem, <no-version>)` pair is rejected via
`version_scan`'s `REJECTED_TYPE_VERSIONS` set — surfaced as `rej`, kept out of
the `need` list — while the versioned `001` stays visible and loadable. This is
a pair-scoped reject (one version of an in-scope type), distinct from
`IGNORED_TYPE_NAMES` (whole types).

**Also rejected:** `(snapshot.spaceheat, 000)` — 11 msgs, 2024-09-30 →
2024-10-06, three houses (one in the `d1` dev universe). The pre-channel shape:
a nested `telemetry.snapshot.spaceheat` keyed by `AboutNodeAliasList` +
`TelemetryNameList`, with 8-hex enum symbols on one house and dashed node
aliases on another. It sits below the 2024-10-13 population start and would
need a new word plus pre-format enum and alias vocabulary for one week of
readings that `gt.sh.status` carries anyway.

The family lives in `gridworks-protocol` `gwproto/messages/event.py` and
pretends `EventBase` inheritance; per the sema flat-word rule each type is
authored flat (base fields spelled out, no base `$ref`). `gridworks.ping` and
`gridworks.ack` already exist as versionless words — their scan `need` is
snapshot staleness (the words are in the registry, not yet in JK's vendored
codec snapshot), not missing vocabulary.

| Type | In sema? |
| --- | --- |
| `gridworks.event.problem` | ✅ versioned `001` exists (loaded, decodes); `<no-version>` `TimeNS` shape REJECTED |
| `gridworks.event.comm.mqtt.connect` | author |
| `gridworks.event.comm.mqtt.connect.failed` | author |
| `gridworks.event.comm.mqtt.disconnect` | author |
| `gridworks.event.comm.mqtt.fully.subscribed` | author |
| `gridworks.event.comm.peer.active` | author |
| `gridworks.event.comm.response.timeout` | author |
| `gridworks.event.startup` | author |
| `gridworks.event.shutdown` | author |
| `gridworks.event.proactor.dbg` | author |
| `gridworks.event.relay.report` | author |
| `gridworks.event.relay.report.received` | author |
| `gridworks.event.admin.command.set.relay` | author |
| `gridworks.ping` | ✅ exists (versionless); rebuild into snapshot |
| `gridworks.ack` | ✅ exists (versionless); rebuild into snapshot |

Test-fixture typenames (`gridworks.event.bar`/`.baz`/`.some.data`) are not
real and are not authored.

## Gleanings (walk-back observations worth a code review)

Incidental findings surfaced while scanning the archive — each is a candidate
for a focused code review of the emitting system, not part of the version
reconstruction itself.

- **`gridworks.event.problem` flapping (Dec 2024 – Jan 2025).** The huge volume
  was `gridworks.event.problem`: 2,931,834 messages in one ~3-week window
  (Dec 30 2024 – Jan 18 2025, 4 houses) — ~140k/day, ~24/minute/house. A
  "problem" event fires when the SCADA's proactor catches a driver fault, and
  the sample payloads show what it was: DNS/connect failures — `<gaierror>
  [Errno -2] Name or service not known`, `Cannot connect to host
  weymouth.local:80` — i.e. a device (an EGauge meter, a thermostat) that
  couldn't be reached, re-emitting the same warning on every failed poll with
  no rate-limiting or dedup. So one or more houses had a persistently
  unreachable device spamming problem events every couple seconds. That is
  exactly why S3 listing for that window took 21 minutes — millions of tiny
  objects to page through. (A nice argument for the flaps → skip-the-acks /
  rate-limit-your-error-events instinct.) **Review:** confirm the proactor now
  rate-limits / dedups repeated driver-fault problem events, and sweep for any
  other flapping emitters on the same pattern.


-  **dupe issue**
    - the same (timestamp, id) — id from the payload's MessageId, timestamp from the payload's own created time — so the messages insert is a no-op. The per-type extra work is
    also safe: a live-era layout re-synced from S3 is not older than the newest layout, so it runs in normal mode against the same channel set (no change); report readings
    collide on (channel_id, timestamp) and are dropped. Overlap is harmless.
    - Types without a natural id (power.watts, snapshot.spaceheat, atn.bid, ticklist.*, energy.instruction, latest.price, heating.forecast, glitch, new.command.tree): the id is
    uuid5(from_alias | type | persisted_ms), and persisted_ms is JK's receipt time on the rabbit path but the ear's S3 key time on the import path — different by the ear's
    write latency — so the same message gets a second row with a different id (and, for the ones with no created-at, a different timestamp too). Overlap duplicates. No
    readings are derived from these, so it's a messages-table duplicate only, but a duplicate.

### Words the S3 importer refuses (no created time in the payload)

A `messages` row dedupes across the rabbit and S3 paths only when both
halves of its `(timestamp, id)` key come from the payload, which needs a
created time. These words have none, so the importer refuses them (the live
path still journals them). Decision pending on which get a new version with
a created time.

| type | has id? | in the back-fill range? |
|---|---|---|
| `power.watts` | no | yes — 2024-10 onward; the real loss |
| `atn.bid` | no | yes — Dec 2024 onward, small volume |
| `latest.price` | no | yes, if any on the wire pre-2026 |
| `gw.weather.observation` | no | no (Aug 2026) |
| `gw.weather.cmd.ack` / `cmd.nack` / `create.cmd` | no | no (Aug 2026) |
| `gw.weather.channel.gt` | yes | no (Aug 2026) |
| `gw.weather.forecast.channel.gt` | yes | no (Aug 2026) |
| `gw.weather.location.gt` | yes | no (Aug 2026) |
| `gw.weather.forecast.bundle.gt` | yes | no (Aug 2026) |

### Id-only dedupe: a separate identity table (proposal)

Today a `messages` row dedupes across the rabbit and S3 paths only when the
payload carries a created time — the `(timestamp, id)` primary key needs both
halves to come from the payload, and the id is derived from the created time
when the payload has none. We will want messages that carry a `MessageId` but
no timestamp and are still journaled exactly once (commands, acks, one-shot
records). The blocker is structural: `messages` is a Timescale hypertable
partitioned on `timestamp`, and a hypertable's unique constraints must include
the partition column — so "unique on `id` alone" cannot live on `messages`.

Three mechanisms considered:

- **Pre-insert lookup** (`SELECT id ... WHERE id = ANY(...)` before insert,
  plain index on `messages.id`). Best-effort only: the time-unbounded lookup
  probes every chunk and slows as the table grows, and it is racy — the live
  keeper and an importer can both miss and both insert, and the PK will not
  catch them when their timestamps differ.
- **Fold the id into the timestamp.** Nothing to fold: a message with an id
  and no created time shares no time value between the two paths, so this only
  works by bucketing time, which corrupts the column's meaning. Rejected.
- **A separate identity table** (recommended). A small ordinary table owned by
  gridworks-data, `gridworks.message_ids (id uuid primary key, timestamp
  timestamptz not null)`. In the same transaction that writes `messages`, the
  persistor does `INSERT INTO message_ids ... ON CONFLICT DO NOTHING
  RETURNING id`; only the ids that come back are new, so their `messages` row
  and readings/channel work proceed and the rest are skipped as already
  journaled. Properties: a real uniqueness guarantee, not best-effort (two
  concurrent writers cannot both win); independent of timestamps, so a word
  with a `MessageId` and no created time dedupes exactly like `layout.lite`;
  cheap (one 16-byte row + index per message, ~2.5M for this back-fill); done
  in the batch path with one `executemany ... RETURNING`, no extra round trip
  per message; and it doubles as the answer to "have we already persisted X?".
  One-time backfill: `INSERT INTO message_ids SELECT id, timestamp FROM
  messages ON CONFLICT DO NOTHING`.

The vocabulary rule this enables: a word that must be journaled exactly once
carries a `MessageId`; a created time is still what places the row in time but
is no longer required for identity. Scope touches both JK
(`SemaMessagePersistor`, ~40 lines; the importer's refusal loosens from
"created time required" to "id or created time") and gridworks-data (the table
+ migration), so it earns its own flat Linear issue. Nothing in the current
back-fill depends on it — the recorded floors keep the paths from
overlapping — so it lands after the load, not mid-run.

### Scope cut (2026-08-26): cap at the production floor, skip snapshots

Two corrections after the load's shape became clear:

- **Every type stops at 2026-01-08**, the day before the production
  JournalKeeper floor — a single hard cap, not the per-type "day before
  this type's earliest live row." The per-type rule pulled
  `snapshot.spaceheat` to 2026-07-09 (its first live row is 2026-07-10:
  snapshots were not journaled live until July 2026), so it tried to fill
  the whole Jan–Jul 2026 production gap. Filling that gap is a separate
  decision, not this historical back-fill.
- **`snapshot.spaceheat` is not back-filled at all.** It generates no
  readings (default persist path, message row only — the channel
  time-series comes from `report.event`), and it is ~90% of the daily
  eventstore volume. Skipping it takes the load from ~10–15M messages to
  ~1–1.5M with no loss to plots or CSVs. The Jan–Jul 2026 snapshot gap (and
  the smaller `scada.params` Jan–Mar and `ticklist.hall.report` Jan–Apr
  gaps) are left for a separate, explicit "backfill un-journaled early-2026
  telemetry?" decision.

Run command (committed importer entrypoint, per span):
`python -m gjk.s3_message_importer --start <s> --end 2026-01-08
--message-types '~layout.lite,gridworks.event.problem,snapshot.spaceheat'
--alias-prefix hw1. --workers 8 --batch-size 500`.

## Actively doing — the live back-fill run (2026-08-26)

> Live operational snapshot of the run in flight, not durable spec — it
> changes as spans finish and writer counts are tuned. Distil or move to the
> `experiments/ops498-load/` harness once the load completes; the same
> content is mirrored there.

**Box.** Throw-away EC2 `ops498-loader` (`i-005da05cec87777a9`) in
**us-east-1**, **c7i.4xlarge — 16 vCPU / 30 GB** (resized up from t3.medium
once DB-write concurrency, not CPU, proved the ceiling — see "Writer count").
Instance role grants S3 read on `gwdev`; login `ubuntu` with the
`gridworks-main` key. The prod-writer `GJK_DB_URL` lives only in
`~/.env-loader` (mode 600), never in the checkout. Public IP changes on
stop/start (currently 44.203.82.96). Checkout `~/gridworks-journalkeeper` on
`main`.

**What is loaded / skipped.** Every JK-accepted type EXCEPT: `layout.lite`
(done in an earlier layouts-first pass so channel eras exist before reports),
`gridworks.event.problem` (device-fault flap, unwanted), `snapshot.spaceheat`
(generates no readings, ~90% of eventstore volume — skipped by decision), and
the receipt-time-keyed types the importer refuses (`power.watts`, `atn.bid`,
`latest.price`, the `gw.weather.*` cmd/obs/records). **Hard cap at
2026-01-08** (day before the production JournalKeeper floor); nothing on or
after 2026-01-09 is touched.

**Partitioning.** 2024-10-13 → 2026-01-08 (453 days) is split into **12
contiguous, non-overlapping spans**, one importer process per span, all
running in parallel. Verified contiguous (each span starts the day after the
previous ends; sum == 453 days). Later, heavier periods (more houses) get
narrower spans:

| # | start | end |  | # | start | end |
|---|---|---|---|---|---|---|
| 1 | 2024-10-13 | 2024-12-15 | | 7 | 2025-06-11 | 2025-07-15 |
| 2 | 2024-12-16 | 2025-01-20 | | 8 | 2025-07-16 | 2025-08-20 |
| 3 | 2025-01-21 | 2025-02-25 | | 9 | 2025-08-21 | 2025-09-25 |
| 4 | 2025-02-26 | 2025-03-31 | | 10 | 2025-09-26 | 2025-10-31 |
| 5 | 2025-04-01 | 2025-05-05 | | 11 | 2025-11-01 | 2025-12-05 |
| 6 | 2025-05-06 | 2025-06-10 | | 12 | 2025-12-06 | 2026-01-08 |

**Run it yourself** (on the box, from `~/gridworks-journalkeeper`):

```bash
set -a; . ~/.env-loader; set +a               # GJK_DB_URL (prod writer)
EX='~layout.lite,gridworks.event.problem,snapshot.spaceheat'
i=0
for span in \
 "2024-10-13 2024-12-15" "2024-12-16 2025-01-20" "2025-01-21 2025-02-25" \
 "2025-02-26 2025-03-31" "2025-04-01 2025-05-05" "2025-05-06 2025-06-10" \
 "2025-06-11 2025-07-15" "2025-07-16 2025-08-20" "2025-08-21 2025-09-25" \
 "2025-09-26 2025-10-31" "2025-11-01 2025-12-05" "2025-12-06 2026-01-08"; do
  set -- $span; i=$((i+1)); R=$HOME/runs/prod-20260826v$i; mkdir -p $R
  nohup uv run python -m gjk.s3_message_importer --start $1 --end $2 \
    --message-types "$EX" --alias-prefix hw1. --workers 8 --batch-size 500 \
    --summary-json $R/sum.json > $R/import.log 2>&1 &
done
```

One span on its own:

```bash
uv run python -m gjk.s3_message_importer --start 2025-06-11 --end 2025-07-15 \
  --message-types '~layout.lite,gridworks.event.problem,snapshot.spaceheat' \
  --alias-prefix hw1. --workers 8 --batch-size 500
```

(`--workers` = concurrent S3 GET prefetch threads; `--batch-size` = rows per
DB transaction; `--alias-prefix hw1.` keeps dev-universe `d1.` houses out.)
The committed driver `scripts/s3_bulk_load.sh` wraps this with weekly
chunking and per-type floors, but is bypassed here because excluding
`snapshot.spaceheat` + the hard 2026-01-08 cap were run-specific decisions
passed as flags rather than a driver edit (a box runs committed code; flags
are fine, file edits are not).

**Writer count (the real ceiling is DB write-concurrency, not CPU or S3).**
8 = 0 lock-waits, ~17 msg/s; 12 = ~4 lock-waits, `select 1` ~0.10s; 16 = ~5
lock-waits, `select 1` up to 0.19s; 24 = lock-up (12+ lock-waits, queries
stuck 200s+, throughput collapse — do not exceed). **Running at 12.** Watch
`select count(*) from pg_stat_activity where wait_event_type='Lock'`. The load
is idempotent (uuid5 id from the payload's created time + on-conflict-do-
nothing on both `messages` and `readings`), so any restart re-scans and
dedupes safely.

**Completion / no-missing-days check** (on the box at the end): the union of
`Completed messages for <day>` across all `runs/prod-20260826v*/import.log`
must equal the 453-day set 2024-10-13..2026-01-08; each span also ends with a
`RUN SUMMARY`. Any missing day = a crashed span to relaunch.

**Post-load cleanup (queued):** delete the ~330k `snapshot.spaceheat` rows a
few early runs loaded before the skip decision (`< 2026-01-09`), batched, once
the load is done.
