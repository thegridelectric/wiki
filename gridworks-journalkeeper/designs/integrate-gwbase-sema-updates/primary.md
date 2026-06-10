# Integrate gwbase + sema updates into JournalKeeper

Status: Draft · Pass 0 · Updated 2026-06-10 · Linear: OPS-386

> What this is: the **hub** of the design to finish moving
> `gridworks-journalkeeper` onto the upgraded **gwbase 0.5.x** (three-tier
> `ServiceSettings`/`ActorBase`) and the updated **sema** restricted-snapshot
> toolchain (OPS-380), now that both upstreams have landed their relevant work.
> Spokes split off this hub as the plan firms up (one per workstream).

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
— unblocked, high value, recommended first step.** (Folds in the former
`upgrade-gjk-sema-snapshot` design, ex-OPS-379.)
`src/gjk/sema` is a restricted sema snapshot, and OPS-380 was literally built
for it. The regen is **not** a hand-edit: run sema's snapshot build from a seed
request (`seed request → sema snapshot build → round-trip gate + samples`, per
`sema/spec/snapshot.md`). A clean regen pulls in:
- the `layout.lite` 007→008 ShNodes fix (directly relevant — JK persists
  `layout.lite` + `report.event`),
- the round-trip gate + `samples/` (so JK's vendored snapshot self-verifies),
- and drops the vendored `tests/` (snapshots no longer ship generated test
  code — clears the failing `test_property_format.py` and the long-standing
  "drop vendored sema tests from gjk" cleanup).

**The `market.type.name` stopgap disappears automatically.** The current
snapshot carries hand-patches (a hand-seeded `market.type.name` enum + a
patched `property_format.py` import + an `enums/__init__.py` re-export); a
clean regen never reproduces them. Sema's `untangle-market-type-name` work
(structured `market.product`, the versioned market-slot type declaring an axiom
dependency on it, and the `import_root` codegen fix) means the market enum is
pulled into the snapshot **structurally via the `bid`/`atn.bid` type
dependencies** — no manual market seeding, and no `ModuleNotFoundError`.

**Bid coverage:** seed **both** `atn.bid` (historical, frozen — so old S3
messages still decode) **and `bid`** (current). There is **no `ltn.bid`**.
`latest.price` is already in the seed (keep it).

Recommended `src/gjk/sema_seed_request.yaml` (current seed + `bid`; the market
enum is intentionally NOT listed — it arrives via the bid types' deps):

```yaml
initial_targets:
  types:
    report.event:
      versions: ["002","003"]
    layout.lite:
      include_all_versions: true
    glitch:
      include_all_versions: true
    flo.params.house0:
      include_all_versions: true
    gridworks.event.problem:
      include_all_versions: true
    power.watts:
      include_all_versions: true
    heating.forecast:
      include_all_versions: true
    weather.forecast:
      include_all_versions: true
    energy.instruction:
      include_all_versions: true
    new.command.tree:
      include_all_versions: true
    snapshot.spaceheat:
      include_all_versions: true
    scada.params:
      include_all_versions: true
    ticklist.reed.report:
      include_all_versions: true
    ticklist.hall.report:
      include_all_versions: true
    report:
      include_all_versions: true
    atn.bid:            # historical (frozen)
      include_all_versions: true
    bid:                # current
      include_all_versions: true
    latest.price:
      include_all_versions: true
  enums:
    gw1.unit: {}
    gw1.main.auto.state: {}
    gw1.lc.top.state: {}
    gw1.leaf.ally.all.tanks.state: {}
    gw1.leaf.ally.buffer.only.state: {}
    gw1.local.control.all.tanks.state: {}
    gw1.local.control.buffer.only.state: {}
    gw1.local.control.standby.top.state: {}
```

**Done when:** snapshot regenerated per sema's rules from a post-untangle sema,
no hand-patches remain, `pytest tests/` green, and the live/S3 paths decode
`atn.bid`, `bid`, and `latest.price`. Then re-run the live-test to confirm the
refreshed snapshot still reads prod cleanly.

**2. gwbase 0.5.x integration into JK — NOW UNBLOCKED (0.5.2 published,
data-loss bug fixed); the tier-model migration is the remaining work.**
Migrate JK's `Settings` to the new tier model (JK is a *tap* →
`ServiceSettings` + `ActorBase`; drop the GNode-only fields; make
`service_alias` first-class instead of the `.env` hack). **Adopt the XDG
`Paths` convention** in the same pass: today JK inherits the hardcoded
`/etc/gridworks/g_node.json` default (root-only, non-XDG); the target is the
proactor `Paths` pattern (config dir `~/.config/gridworks/journalkeeper/`,
`g_node.json` there, `GJK_PATHS__BASE` / `GJK_PATHS__NAME` env roots for
tests) — the same convention the LTN and scada already use. JK either picks it
up by bumping its `gridworks-base` floor (once base ships `Paths`) or depends
on `gridworks-proactor` just for `Paths`. The code is doable
now, but it **can't merge until `gridworks-base` 0.5.x publishes to PyPI**
(CI has no sibling checkout — same constraint as the gw_data precedent). So
the fork is: **publish gridworks-base 0.5.x first**, or **stage JK on a branch
and wait**. **Hard prerequisite:** gwbase 0.5.x silently DROPS messages whose
routing key uses a proactor short_name in the `to` slot (acks then returns —
data loss, not just a warning); JK must not adopt 0.5.x until this is fixed.
Tracked by a gridworks-base design (`must-accept-current-ltn-messages`).

**3. File the live-test findings** (Ops issues):
- JK `Settings` 3-tier migration (= #2 above).
- gwbase silently dropping short_name-`to` messages — captured as the
  gridworks-base design above; blocks #2.
- `gridworks.ack` is a real sema type, just **absent from JK's restricted
  snapshot** (Gate 1, decode), so it decodes as degraded — a re-vendor / seed
  decision (#1), not a degradation of the type itself.

**4. Close out session loose ends:** the JK test-infra — commit the live-test
runner script (`scripts/point_at_prod_persist.py`, reverting the dev-local
`gridworks-base` repoint) or re-stash it; then tidy active-claims.

## Recommendation / sequencing

Start with **#1 (sema snapshot regen + re-verify)** since it's unblocked and
directly validates the work just merged, then decide the `gridworks-base`
publish question for **#2**. #3 can be filed in parallel; #4 closes the
session.

## Open questions / blockers

- **gridworks-base publish:** does 0.5.x get released to PyPI now (unblocking
  the #2 merge), or do we stage JK and wait? This gates the gwbase half.
- **`gridworks.ack`:** intentional skip vs. promote to a sema type — needs a
  sema-side decision.
- **Snapshot regen mechanics:** confirm JK's seed request / `sema snapshot
  build` invocation that produces `src/gjk/sema` (resolve when #1 starts).

## Process notes

- New design, `Draft · Pass 0`. Registered in Linear at Draft (Backlog).
- `wiki/DESIGN_INDEX.md` is currently claimed by another session — leave the
  index update to whoever holds it, or do it when the claim clears.
