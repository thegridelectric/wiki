# Integrate gwbase + sema updates into JournalKeeper

Status: Accepted · Pass 1 · Updated 2026-06-12 · Linear: OPS-386

> What this is: the **hub** of the design to finish moving
> `gridworks-journalkeeper` onto the upgraded **gwbase 0.5.x** (three-tier
> `ServiceSettings`/`ActorBase`) and the updated **sema** restricted-snapshot
> toolchain (OPS-380), now that both upstreams have landed their relevant work.
> Spokes split off this hub as the plan firms up (one per workstream).

**▶ Active spoke: `gwbase-tier-migration.md` (hub item #2). CODE LANDED
(pending commit) —** the gwbase **`ServiceSettings` tap-tier migration** is done
in the working tree: `Settings(GNodeSettings)` → `ServiceSettings`
(`src/gjk/config.py`), first-class `service_alias`, `g_node.json` deleted, no
GNode identity. JK suite green (20 passed) + `Settings()` construction smoke
green. **Remaining: the live-rig re-run** against PyPI base (the only open
done-when — verification, hub item #4), then commit. (Convention: while a design
is active, its active spoke is highlighted here at the top of the hub.)

## Spokes

- `gwbase-tier-migration.md` — hub item #2 (settings → `ServiceSettings`,
  first-class `service_alias`, plain-XDG paths, CI on published base).
- `persisted-type-set.md` — hub item #3 (what JK ingests + stores;
  `gridworks.ack`/`gridworks.ping` + the live-rig-discovered set).

## Context — where we are

This design crystallizes work already in flight this session:

- ✅ **Live-test of the updated JK** — fresh empty local `gw_data` Postgres
  (`gridworks-data` `main` convention: `tsdb` db, non-public `gridworks`
  schema) + the unpublished `gridworks-base` 0.5.x sibling, reading and
  persisting live messages off the **production** rabbit broker.
- ✅ **Regression fix** — `report.event` / `layout.lite` custom-persistor
  signatures migrated to the `time_received` dispatch seam (PR #162,
  `5cd5199`); this had broken the telemetry write path on `dev` since
  2026-06-07. Verified live: `report.event` persists, 0 errors.
- ✅ **sema snapshot-improvement merged** (PR #21, `8293b4e`) — deterministic
  zero-diff builds, the shipped round-trip gate, `samples/`, the example
  mandate on superseded versions, and the `layout.lite` 007→008 ShNodes fix.
- ✅ **gwbase 0.5.2 published to PyPI** — and the **routing-key data-loss bug is
  fixed** (`must-accept-current-ltn-messages`, OPS-388, **done**; distilled into
  `gridworks-base/executor/transport.md` §3.3–§3.6, design file deleted). This
  was the hard prerequisite that gated #2 below — **now cleared.** JK is already
  pinned to `gridworks-base>=0.5.2` (`828d0dc`).
- ✅ **JK `legacy_hack`** (verified 8/8, merge-pending on `jm/legacy-hack-broadcast`)
  — overrides `on_routing_key_parse_error` to recover the LTN's legacy
  `broadcast.*` keys (same prod-data-loss theme; the scada-side fix that stops
  *new* `broadcast.*` shipped as OPS-387). Independent of the snapshot regen,
  but note: for the recovered types to fully decode, the snapshot (#1) must
  cover them (e.g. `flo.next.hour.plans`, `glitch`).

`src/gjk/sema` **is** a restricted sema snapshot, and OPS-380 was motivated by
standing it up — so JK is the natural first consumer of the merged work.

## Plan — what comes next

**1. Regenerate JK's sema snapshot following sema's snapshot-generation rules
— ✅ DONE.** (Folded in the former `upgrade-gjk-sema-snapshot` design,
ex-OPS-379.) `src/gjk/sema` is now a clean restricted-snapshot regen from
current sema `dev` via `scripts/regen_sema_snapshot.sh`
(`sema snapshot prepare` / `build --package-name gjk`, mirrored into
`src/gjk/sema`). The `market.type.name` hand-patches are gone — the market
enums (`market_price_unit`, `market_quantity_unit`) arrive **structurally via
the `bid` / `atn.bid` deps**, no manual seeding, no `ModuleNotFoundError`. The
round-trip gate + `samples/` ship, the vendored `tests/` are dropped, and both
**`atn.bid`** (historical / frozen — old S3 still decodes) and **`bid`**
(current) are seeded and decode; `latest.price` covered; there is no `ltn.bid`.
JK suite green (20 passed). The seed lives at `src/gjk/sema_seed_request.yaml`;
regenerate with `scripts/regen_sema_snapshot.sh`.

**2. gwbase 0.5.x integration into JK — the tier-model migration.** Unblocked:
gwbase 0.5.2 is on PyPI and the routing-key data-loss bug is fixed (OPS-388,
distilled into `gridworks-base/executor/transport.md`). JK is a *tap* whose
actor is already `ActorBase`; only the settings class lags. **Detailed in spoke
`gwbase-tier-migration.md`.** Summary:

- [x] Reparent `Settings` → `ServiceSettings` (drop `GNodeSettings`); remove the
  GNode-only fields (`g_node_alias`, `g_node_id`, `world_instance_alias`). **Done**
  (in working tree, pending commit) — also deletes the tracked `g_node.json`.
- [x] Make `service_alias` first-class (replace the `g_node_alias`/`.env` hack).
  **Done** — defaulted `"d1.journal"`, `GJK_SERVICE_ALIAS`-overridable; `.env` /
  `template.env` `GJK_G_NODE_PATH` scrubbed.
- [x] **Paths — plain XDG from gwbase.** Dropping `GNodeSettings` sheds the
  `g.node.gt.json` file entirely (deleted). `service_name="journalkeeper"` set;
  logs land under `state_dir("journalkeeper")`. `.env` stays at cwd for now
  (the low-stakes sub-decision; not worth a relocation).
- [x] CI — no change needed: `pyproject` already pins `gridworks-base>=0.5.2`
  from PyPI, no sibling-checkout in CI (spoke §5).

**3. JK persisted type-set — `gridworks.ack`, `gridworks.ping`, + more.**
**Detailed in spoke `persisted-type-set.md`.** Both are versionless sema types;
each add = one seed-yaml entry + regen (decode gate) and a one-line
`BASIC_MSG_TYPES` add (ingest + store), driven by the persistor's
`all_known_message_types()`. The "few more" startup/liveness/disconnect types
are discovered from a live LTN+scada rig (this session operates it; see the
spoke).

**4. Close out session loose ends:** the JK test-infra — commit the live-test
runner script (`scripts/point_at_prod_persist.py`, reverting the dev-local
`gridworks-base` repoint) or re-stash it; then tidy active-claims.

## Recommendation / sequencing

**#1 and #2's code are done** (#2 pending commit + the live-rig re-run). Next is
**#3 (persisted type-set)** — fileable in parallel — and **#4** (live-test
re-run against PyPI base, which also closes #2's last done-when, + session
loose ends).

## Open questions / blockers

- **`gridworks.ack` seeding:** it IS a sema type — the only open question is
  whether to add it to JK's seed so it decodes strict (degraded without).
  Likely yes, alongside the `bid` add.
- **`Paths` source:** bump the `gridworks-base` floor once base ships `Paths`
  vs. depend on `gridworks-proactor` for `Paths` only (from #2).

## Process notes

- `Accepted · Pass 1` (OPS-386).
- `wiki/DESIGN_INDEX.md` is currently claimed by another session — leave the
  index update to whoever holds it, or do it when the claim clears.
