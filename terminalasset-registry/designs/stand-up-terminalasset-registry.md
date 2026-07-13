# Stand up the terminalasset-registry

Status: Draft · Pass 0 · Updated 2026-07-03

**EDD: no** build-out — verified by the suite plus a deployed seed that round-trips
layout + operational-params I/O and provisions a real SCADA from its record; not a
standalone experiment.

> What this is: the path to a **Sema-correct seed database + independent repo** that
> holds every terminal asset's **hardware layout** and **operational-params**, and is
> the durable source of truth that provisioning, the LTN, the web frontend, and
> analytics consume. It is the layout/params sibling of the grid-node-registry — same
> *seed* pattern (see [`../../sema/research/where-meaning-lives-in-gridworks.md`](../../sema/research/where-meaning-lives-in-gridworks.md)),
> deliberately **without** GNR's decentralizable / on-chain requirement. The Sema
> words and the authoring gen come from hardware-layout-pass-one
> ([OPS-407](https://linear.app/gridworks/issue/OPS-407)); this is where the asserted
> facts **live**.

## ▶ Do this now (for the next Claude)

Phase 1 is underway. State as of 2026-07-03:

- ✅ **tlayouts uv scaffold + snapshot infra committed** (`tlayouts` `jm/spruce`, `0cdf17f`):
  `pyproject.toml`, `tlayouts_seed_request.yaml` (gwsproto-mirroring `local_names`),
  `build_tlayouts_snapshot.sh`. The generator runs and computes the closure.
- ✅ **Board-resident relay Sema vocabulary** authored + green (`sema` `jm/sim-vocab`, `fae8d27`
  + `11be3be`): `relay.control.config`, `i2c.relay.component.gt`, `gpio.relay.component.gt`,
  `gw1.device.type/001`.
- ⛔ **The snapshot build is blocked** — its round-trip gate rejects the stale layout
  `examples:` (reshaped in place; `gw.house0.layout` fails 3399 runtime-decode errors).

**The single next move rides [OPS-442](https://linear.app/gridworks/issue/OPS-442)
(example-runtime-validation — Done):** the main sema suite now runtime-decodes every
example, so regenerate the stale layout examples (`gw.house0.layout`, `gw.nolan.layout`,
`gw1.simple.sim.layout`) to the reshaped shapes. That
unblocks `./build_tlayouts_snapshot.sh`. **Then** Phase-1 step 2: port `layout_gen` +
`house0_sema_gen` into `tlayouts` on `sema.runtime.types` (import swaps), emitting the two Sema
JSON artifacts — at which point the *generated* reshaped layouts become the fresh examples
(closing the loop). gwsproto relay types stay deferred to pass-two (see Open).

## Why a separate repo/service (not folded into GNR, not in the scada venv)

- **Not GNR.** The grid-node-registry is being stood up *specifically* to keep its
  authority migratable to a blockchain — hence its `AuthoritySource` seam, signed
  Sema commands, and verifiable proofs. The layout/params record has **no such
  requirement**: it is GridWorks-specific, single-org, and there is no reason to
  decentralize it. Folding it into GNR would tax it with machinery it does not need.
  It *references* GNR facts (a layout is keyed by its TerminalAsset `GNodeId`), but it
  is its own seed.
- **Not the scada venv — and no gwsproto.** Today `layout_gen` lives inside
  `gridworks-scada` and imports `gwsproto`. But the authoring repo only ever **builds
  and serializes sema types**, so it needs **only a vendored sema snapshot** of the
  words it uses (`gw.house0.layout`, `gw.house0.operational.params`, `capture.tuning`,
  the `*.component.gt` vocabulary, `g.node.gt`, channels) — **not gwsproto, not gwproto,
  not the scada runtime.** Confirmed feasible: `sema.runtime.types.*` classes build and
  serialize to PascalCase sema JSON and accept PascalCase kwargs, so porting `layout_gen`
  is mostly import swaps (`gwsproto.named_types` → `sema.runtime.types`). This is the same
  move GNR made (`build_gnr_snapshot.sh` + `*_seed_request.yaml`) and the transition step
  the LTN-brokered app-comms design ([OPS-408](https://linear.app/gridworks/issue/OPS-408))
  needs.

## The authoring/runtime split, concretely (this is the clean part)

The sema layout/component types are the **authoring shape** — params-free by construction:
the bare components (`pico.flow.module.component.gt`, …) carry **no ConfigList**, and the
specialty configs (`electric.meter.channel.config`, …) carry **ChannelName + hardware
binding only, no capture params**. So:

- **tlayouts (sema snapshot) emits two sema JSON artifacts** per home into `output/`:
  `gw.house0.layout.json` (authoring, params-free) and `gw.house0.operational.params.json`
  (the `CaptureTuningList` — where the capture params live). The **default-ops synthesis**
  (sensible per-channel capture tuning by channel/device kind) lives here, so a home gets
  a valid ops artifact for free.
- **gridworks-scada owns `sema_to_dc(layout, ops)`** — reassembles the runtime dc the
  device actors read: splice the capture params onto specialty ConfigList entries by
  `ChannelName`, and **build** each bare component's ConfigList (`CaptureTuning` entries)
  from the ops params + the channel→component binding (`DataChannel.CapturedByNodeName`).
  This yields the gwsproto/runtime shape (approach A) with the assembly-coverage +
  `PollPeriodMs ≥ MinPollPeriodMs` floor checks. **Naming:** both inputs are sema, so this
  is `sema_to_dc(layout, ops)` — *not* `ops_and_sema_to_dc` (which wrongly implies ops
  isn't sema).

So the params-free "static layout" that `sema_to_dc`'s merge needs is simply the sema
`gw.house0.layout` JSON — no separate representation to invent.

## Source of truth — the model (proposed; the params half is still converging)

Separate two things that "authority" blurs:

- **Durable source-of-truth** — the record you rebuild reality *from* (redeploy a dead
  SCADA, feed provisioning/analytics/FLO, audit across time).
- **Runtime authority** — what decides behavior *now* and can refuse.

The decisive constraint is **provisioning/redeploy**: a dead edge cannot be its own
backup, so a complete, current record MUST live upstream. That upstream is this seed.

- **Layout (static topology): upstream-authoritative, GNR-like.** A physical-install
  fact, authored at commissioning/rewiring, keyed by the TerminalAsset `GNodeId`. The
  seed is its source of truth; the SCADA runs a deployed copy; rare changes ride a
  signed-command handler. Nearly the same shelf as GNR — different tables, shared
  identity.
- **Operational-params: durable upstream, runtime-authoritative at the SCADA.** The
  **LTN is the single writer** (OPS-408: web → LTN → SCADA, SLA-preserving); the
  **SCADA is the runtime authority + absolute safety backstop** (its freeze / max-SWT
  floors override any remote command). The **durable** record still lives here — a
  param write updates the seed *and* pushes to the SCADA — because provisioning,
  dashboards, analytics, and FLO all need params without round-tripping every house.

So "authority at the SCADA" is **true for runtime effect and safety, false for the
durable record.** The SCADA owns *what runs*; the seed owns *what is true across time
and the fleet*; the LTN owns *the write path*. (Open: whether params could instead be
edge-authoritative with the upstream as a published projection — see Open.)

## What we reuse from the GNR template (and what we drop)

Reuse (from the grid-node-registry standup,
[OPS-419](https://linear.app/gridworks/issue/OPS-419) — durable forms in
`wiki/grid-node-registry/executor/primary.md`):

- **One service is the sole accessor of the backing store**; everyone else uses a read
  API + a write channel. Keeps the backing store swappable and the meaning explicit.
- **Sema-correct by construction** — rows reference Sema types/versions/identities, so
  facts cannot drift from their declared meaning (the seed pattern).
- **Provisioning reads the registry and (re)deploys the SCADA** from it; convergence by
  authorization, not delivery.
- **A vendored sema snapshot** instead of a live package import.
- **Semantic snapshots** (versioned, checksummed exports) for portability/audit.

Drop (GNR-specific, not needed here):

- The **decentralizable / on-chain** requirement and its verifiable-proof broadcast
  path. Keep a *single* `AuthoritySource`-style seam so the store stays swappable, but
  do **not** build the chain-ready proof machinery. Single-org authority is the target.

## Relationship to other work

- **hardware-layout-pass-one ([OPS-407](https://linear.app/gridworks/issue/OPS-407))** —
  defines the Sema words (`gw.house0.layout`, `capture.tuning`,
  `gw.house0.operational.params`, the component vocabulary) and the gwsproto types +
  `sema_to_dc`. The **authoring gen** (`sema_gen`, `layout_gen`, default-ops) moves **out
  of the scada repo into `tlayouts`** (Phase 1 above); the **`sema_to_dc(layout, ops)`
  projection stays in `gridworks-scada`** (the boot/consumption path). This registry is
  where the *authored instances* the gen produces come to live.
- **ltn-brokered-app-comms ([OPS-408](https://linear.app/gridworks/issue/OPS-408))** —
  the write path for runtime param changes (web → LTN → SCADA). This registry is the
  durable record those writes update.
- **grid-node-registry ([OPS-419](https://linear.app/gridworks/issue/OPS-419))** — the
  identity/topology seed this one references. Open: whether they share one Postgres
  instance (different schemas) or stay separate DBs behind separate services.

## Build order (acceptable-minimum; most steps Open)

**Phase 1 — the authoring repo (start here; the current `tlayouts` repo is the vehicle).**

1. **`tlayouts` → uv project + vendored sema snapshot.** Pull `jm/spruce` into a proper
   uv project (`pyproject.toml`); vendor a sema snapshot (`*_seed_request.yaml` +
   `build_*_snapshot.sh`, mirror GNR) of the layout/ops/component/channel/`g.node.gt`
   words. Leaves the "gw_spaceheat on path + scada venv active" hackiness behind.
2. **Port `layout_gen` onto `sema.runtime.types`.** Move `layout_gen` + `house0_sema_gen`
   into `tlayouts`, swapping `gwsproto.named_types` imports for `sema.runtime.types`
   (PascalCase kwargs unchanged). Output is **two sema JSON artifacts** per home
   (`gw.house0.layout.json`, `gw.house0.operational.params.json`) in `output/` — no dc,
   no gwsproto.
3. **Default-ops synthesis** (in `tlayouts`). Synthesize a valid initial
   `operational-params` from **defaults** (per-channel capture tuning by channel/device
   kind — lift today's hardcoded capture periods into a defaults table).
4. **(scada) `sema_to_dc(layout, ops)`.** In `gridworks-scada`, rework the projection to
   read the two sema artifacts and reassemble the runtime dc (the merge + coverage +
   poll-floor checks). This is pass-one's step 4/5, now correctly scoped.

**Phase 2 — the seed database (later; the registry proper).**

5. **Seed schema.** Sema-correct tables for layout + operational-params, keyed by
   TerminalAsset `GNodeId`; Alembic scaffold. **Open.**
6. **`AuthoritySource` + read API + write handler.** One handler core; a read API for
   provisioning/LTN/web/analytics; the write path (param update from the LTN; layout
   change as a signed command). Single-org, no chain seam. **Open.**
7. **Provisioning integration.** Provisioning reads this seed to deploy/redeploy a SCADA
   with its layout + current ops-params. **Open.**

## Open

- **Params authority: upstream vs edge.** Leaning upstream-durable + SCADA-runtime (§
  Source of truth). The edge-authoritative alternative (SCADA owns params, upstream is a
  published projection) stays open — decide against the resilience / customer-ownership
  product principle.
- **Shared substrate with GNR?** One Postgres (separate schemas) vs separate DBs. The
  layout references GNR identities either way.
- **Repo name.** `terminalasset-registry` chosen provisionally; revisit before the repo
  is real.
- **Linear.** Not yet an issue (Draft sits in Backlog); create the `design`-labeled Ops
  issue when this reaches Accepted (or sooner if useful).
