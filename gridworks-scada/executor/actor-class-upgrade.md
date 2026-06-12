Status: Draft · Pass 0 · Updated 2026-06-12

# Adding an actor class — the ActorClass cascade (recipe + cost)

What this is: the concrete recipe and effort for adding a new `gw1.actor.class`
value to sema, and the cascade it triggers. Written from the 2026-06-12
sim-test-environment work (`SimSensorActor` + `SimRelayActor`). Not a call to
re-architect — new actor classes are rare — but a map so the next one is cheap
and nothing is missed.

## The cascade

A new actor class is one enum value, but `gw1.actor.class` is referenced by
`spaceheat.node.gt`'s `ActorClass`, and `spaceheat.node.gt` is **embedded** by
layouts, capabilities, and command trees. So one value ripples:

`gw1.actor.class` (new version) → `spaceheat.node.gt` (new version, refs the new
enum version) → every type that **embeds** `spaceheat.node.gt` (bump each).

Types that reference nodes by **name** (`data.channel.gt`, `derived.channel.gt`)
do NOT ripple — only embedders do.

## Recipe

1. **Bump `gw1.actor.class`** — new version, append the value(s), register, regen.
   (Enums are additive → new version.)
2. **Bump `spaceheat.node.gt`** — new version referencing the new enum version
   (NOT an in-place edit; published versions are immutable). **Per-type tax:** new
   yaml; trivial upgrade template; **port the axiom implementations** (regen emits
   `NotImplementedError` stubs); bump the hand-written
   `tests/runtime/spaceheat_node_gt/` (latest-version + upgrade assertions); add a
   `vNNN` fixture; add an `examples` block to the now-**superseded** prior version.
3. **Bump each embedder.** Find them: `grep "spaceheat.node.gt:<old>"` in
   `registry.yaml` `direct_dependencies`. (Worked example: `layout.lite`,
   `new.command.tree`, `scada.control.capabilities`, `gw.nolan.layout`.) For each:
   - **Draft version** (`status: "draft"` / `/draft/` url) → edit in place:
     re-point the ref + registry dep (bump `created` if a causal-timestamp error
     fires).
   - **Non-draft (published)** → NEW version (immutability rule). Same tax as
     step 2, plus a **nested node lift** in the upgrade (`node.upgrade()`; for a
     multi-step lift loop `while not isinstance(node, Latest): node = node.upgrade()`).
   - **Do NOT propagate a `oneOf`-of-multiple-node-versions** into a new version —
     the new version takes a single node version. Flag old versions that carry it
     with a non-functional `extended_description` note.
4. **Regen + `pytest` green** after each type.
5. **Update gridworks-journalkeeper.** JK journals these real types off the prod
   broker, so its sema snapshot must add the new versions to decode them (additive
   — old scada keeps emitting old versions, JK knows both). JK does **not** need
   sim-only words (`sim.plant.*`, `change.relay.pin`).

## Cost (worked example, 2026-06-12)

Two actor classes → `gw1.actor.class/012` + `spaceheat.node.gt/302` +
`layout.lite/014` + `new.command.tree/002` + `gw.nolan.layout/000` (draft, in
place); capabilities v002 deferred to admin-for-nolan. Plus an immutability slip
(editing `capabilities/001` in place) that had to be reverted. Rough effort: **a
focused half-day of careful, mechanical sema surgery** — most of it the
per-published-type tax (upgrade + axiom port + test bump + superseded example),
not the actual change. The change is one enum value; the cost is the cascade
discipline.

## Smell (noted, not fixed)

One new actor class forcing a version bump of `spaceheat.node.gt` and every
embedder is real coupling. **Mitigation: new actor classes are rare** — the
cascade is paid infrequently, accepted rather than re-architected. The `oneOf`
unions in old versions are a *separate* anti-pattern (back-dated production
traffic, an early sema-bring-up lenience) — do not propagate them.
