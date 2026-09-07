# command-tree-matrix (rope chunk)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: a chunk of the `sh_node_actor` partition rope; estimate 3h; `actors/command_node.py`, 207 L.
> Hub: [`primary.md`](primary.md).

tree
navigation, `set_command_tree`, the `build_command_tree` funnel,
relay-command mechanics (`send_state_command`, `energize`,
`de_energize`, `actuator_config`). Test candidates:
`the_boss_of`/`my_actuators` truth table; `set_command_tree`
prefix-guard + sieg/non-sieg handle rewrites; funnel publishes an
axiom-valid tree (NewCommandTree now validates). **The state-transition
tree matrix (the big one, believed to catch real bugs):** today's only
coverage calls `scada.set_command_tree` DIRECTLY (3 bosses × 2
fixtures); nothing tests the trees the actual STATE TRANSITIONS
produce. Drive each transition on both fixtures: admin wakes up / times
out / releases; ally suit-up and hand-back; every LC top-event (incl.
`set_limited_command_tree`'s backup and scada-blind paths, House0
only); sieg vs non-sieg. Capture every published tree, and assert each
constructs (axiom 1 fires on orphan prefixes) AND matches the expected
handle shape for that state. Jessica believes some of these are wrong
today; the failures are the deliverable. **Row found 2026-09-06**
(rehearsing the sweep driver against the sim Nolan scada): a
transition landing mid-sequence. `NolanLocalControl.command_sequence`
paces its steps 15 s apart and never re-checks `top_state`, so after
admin woke the scada (TopGoDormant at 08:15:38.956) the LC's in-flight
`turn_on_hp` still sent CloseRelay to the secondary pump at 08:15:53,
caught only by the relay's rights check (`Tried to command CloseRelay
… didn't have the rights: FromHandle auto.lc.n must be immediate boss
of ToHandle admin.secondary-pump-relay`). Dormant means commands
nothing; the matrix drives the admin wake-up DURING a sequence and
asserts no command leaves the LC after the transition. The same
rehearsal witnessed admin driving all four Nolan relays (pump, iso,
store pump, hp call) plus the DAC through the rewritten tree, the shape
the "admin wakes up" row asserts.
