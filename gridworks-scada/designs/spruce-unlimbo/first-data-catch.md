# First data catch (spoke)

Status: Draft · Pass 0 · Updated 2026-10-09 · Linear: OPS-392

> What this is: the spoke that connects `jm/spruce-unlimbo` to the
> production broker: the gates, the one JournalKeeper release the connect
> needs, and the day of fleet data that proves every declared channel
> reaches the journal. The swap to `main` and rollback stay in
> `deployment.md`; the string cleanup across the data repos that follows
> the catch is [OPS-542](https://linear.app/gridworks/issue/OPS-542).

## The catch

Three boxes run `jm/spruce-unlimbo` on the production broker for a day,
one per layout family where a family has a box ready. Each pulls the
branch and restarts; every channel its layout declares reaches
`readings`, none dropped and none renamed
(`experiments/spot-check-recipe.md`). After the day, the launch decides
whether the boxes move to `main` (`deployment.md` "The swap") or stay on
the branch.

## Gates

- `layout.lite/013` is published with its closure
  (`finalize-layout-lite-13.md`): a scada cannot send on the production
  broker until the word it sends on link-up is published.
- The LTNs run against the new scada code so reports are acked and the
  LTNs do not crash (`ltns-ready.md`).
- The JournalKeeper release below is merged and deployed on gjk.

## The JournalKeeper release

One gjk release carries the three changes the connect needs:

- **Vendor `layout.lite/013`** and widen the snapshot pin; the
  `LayoutLitePersistor` creates the new layouts' channels in
  `reading_channels`. gjk pins the published-only snapshot today
  (`wiki/gridworks-journalkeeper/changelog.md` 2026-08 "Widen the pin when
  013+ promote"), so this waits on the promote.
- **Journal `gw.scada.commit`** (OPS-7): the scada announces its commit at
  boot right after `layout.lite`, and both reach the journal in one
  release.
- **The heat-call guard.** For a house whose layout declares no
  `*-heat-call` channel, gjk synthesizes a `heat-call` pseudo-channel from
  each `*-whitewire-pwr` reading. A layout that declares heat-call as a
  DerivedChannel, with the scada publishing the readings itself, meets two
  hazards in that path:
  1. `get_pseudo_channels` guards only `data_channels`, so a derived
     heat-call channel gets a duplicate channel row (the shared sync map
     drops the name before the pseudo pass).
  2. The synthesis write path has no guard, so real and synthetic
     heat-call readings interleave.
  The fix: the creation guard covers `data_channels ∪ derived_channels`,
  and synthesis runs per message only when the report carries whitewire
  readings and no heat-call readings. Historical backfills keep their
  synthesized heat-call, a box that reports heat-call itself passes
  through untouched, and no flag day is needed. Per-site wattage
  thresholds eventually ride the layout's DerivedChannel declaration
  rather than a dict in the persistor (OPS-542).

Each change goes in with its test first, in gjk's suite.

## Do this next

Wait on the two upstream spokes; meanwhile write the gjk heat-call guard
with its tests on a `jm/` branch, since it does not depend on the
promote.

## Open

- Which three boxes run the catch.
- Whether the catch runs on passwords or on cert plus FIS; the per-box
  flip is a `deployment.md` "Done when" item, and a password-side box is
  outside FIS's lease logic.
