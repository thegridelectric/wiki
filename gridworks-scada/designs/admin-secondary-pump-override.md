# Admin secondary-pump override (design)

Status: Draft · Pass 0 · Updated 2026-10-21 · Linear: [OPS-613](https://linear.app/gridworks/issue/OPS-613)

**EDD: yes** a spruce window: take admin, override the pump with the
heat pump off, read the relay follow the panel; release, read the relay
back under hp-boss on the watch's state.

> What this is: a way for the admin panel to drive the secondary pump
> directly, as it drives a zone's heat call, by moving the pump relay out
> from under hp-boss in the command tree for the span of the admin
> session. No new relay, no new actor; a tree change under admin only.

## Why

The secondary pump relay is hp-boss's fixed relay. hp-boss runs it on
hp-watch, the heat pump's measured power, in every top state: on while
the unit is sensed running or the watch does not know, off while it is
sensed off. We do not trust the plant's primary pump in either
direction, so the call plays no part. Read on spruce 2026-10-21
(`experiments/2026-10-21-spruce-pump-on-power-window/`).

That rule leaves one thing unreachable from the panel: the pump alone
with the heat pump off. The pump-speed sweep of 2026-09-06 needed
exactly that, and a field session on the secondary loop (a bleed, a
flow check, a pump swap) will again. Today an operator who wants it has
to stop the scada.

## The shape

- **An admin dispatch** names the pump relay and asks for it directly.
  The scada, in Admin, rewrites the tree so `secondary-pump-relay` hangs
  under `admin` (handle `admin.secondary-pump-relay`) instead of under
  `admin.hp-boss`. The fixed sub-tree declaration stays; the override is
  the one documented exception to it, and only Admin may take it.
- **hp-boss** sees the relay is not its own and stops enforcing. Its
  state report says the pump is overridden, so a snapshot reader can
  tell why the relay disagrees with the watch.
- **The panel** sends the relay its ordinary events at the new handle,
  as it does for a zone's scada-ops relay.
- **The return** is every admin exit: release or timeout rebuilds the
  tree, the relay returns under hp-boss, and hp-boss re-enforces from
  the watch's current state at once. Nothing can leave the pump off
  with the unit running, which is the 2026-10-18 failure the fixed
  relay was made for.
- **Capabilities**: the control-capabilities projection tells the panel
  the relay is overridable, so gwa offers it instead of guessing.

## Open

- The dispatch word: a new admin word, or a flag on an existing one.
  Search `sema/definitions/` before deciding.
- Whether hp-boss's report of an overridden pump is a state of
  `HpBossState` or a field beside it.
- The test first: the in-process admin test in
  `tests/actors/test_hp_boss.py` gains the override and the release; the
  live chain in `tests/actors/test_hp_watch_live.py` reads the pump
  ignore power while overridden and follow it again after release.

## Plan

Backlog. Not before the single scada focus (both sim houses green in
dev) unless a field session needs it first.
