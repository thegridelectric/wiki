# Pico-cycler command (spoke)

Status: Draft · Pass 0 · Updated 2026-09-06 · Linear: OPS-392

> What this is: admin keeps the pico-cycler running and asks it for vdc
> relay actions, instead of seizing the relay. Decided 2026-09-01 with
> the interior-subtree rule; executes at the end of the command_node.py
> review section (estimate on OPS-392).

## The rule this rides

**An interior node keeps its subtree; tree rewrites reparent delegates,
never reach through them.** vdc-relay reports to pico-cycler in ALL
states in ALL layouts; under admin the shape is
`admin.pico-cycler.vdc-relay`. This supersedes the hand-coded
vdc-under-pico-cycler-except-admin exemption in `Scada.set_command_tree`
(and makes `CommandNode.set_command_tree`'s flatten-everything branch
structurally safe rather than safe-by-call-site).

Rejected alternative: toggling admin between direct-vdc and hands-off
trees — doubles the special cases, needs a mode flag living outside the
trees, and its direct mode cuts the cycler out, which is the failure
mode this exists to prevent (we repeatedly wanted admin control WITH the
cycler still running).

## Field evidence (2026-09-06, spruce pump-speed sweep)

The window scada's boot power-cycles the picos through vdc-relay
(pico-cycler `TRIGGERING PICO REBOOT`), then the sweep driver takes
admin and the cycler is sent dormant. In run 2 the secondary BTU
meter's pico did not rejoin after the boot-time cycle; the cycler
logged it flatlined twelve minutes later and, dormant, could not cycle
it. Every DAC level echoed and every other channel reported, but the
run carried no `secondary-flow` at all, the one measurement the sweep
exists for. On admin release the cycler woke and cycled the picos on
its own. Nineteen minutes of window lost to the exemption this spoke
removes; the same failure would hit any long admin window.
(`experiments/2026-09-06-spruce-pump-speed-sweep/` run 2.)

## The work

1. Uniform subtree rule in BOTH `set_command_tree` implementations
   (`scada.py`, `command_node.py`); delete the vdc exemption (both
   branches of `Scada.set_command_tree`, `scada.py:1238` and `:1249`,
   pin vdc under `auto.pico-cycler` unless the boss is admin); the
   pico-cycler node's handle is fixed `auto.pico-cycler` by the layout
   gens (`nolan_sema_gen.py:232`, `house0_sema_gen.py:590`), so the
   rewrite must reparent the interior node itself to
   `<boss>.pico-cycler` and vdc to `<boss>.pico-cycler.vdc-relay`, else
   `relay.py`'s immediate-boss check refuses the cycler. Fix
   `CommandNode`'s docstring ("all actuators report directly to boss"
   overclaims).
1a. `AutoGoesDormant` stops sending `GoDormant` to the pico-cycler
   (`scada.py:1016` lists it with leaf-ally and local-control) and
   `AutoWakesUp` stops sending it `WakeUp` (`scada.py:1026`): the
   cycler runs in every top state. Its `Dormant` FSM state stays for
   the boss's explicit off command (item 2).
2. Pico-cycler accepts an on/off command from its boss, mapped onto its
   existing FSM (it already bosses vdc-relay through
   `change.relay.state` events).
3. gwadmin grows a pico-cycler control alongside its relay list.
4. Tree-matrix admin rows move to the `admin.pico-cycler.vdc-relay`
   shape (marked xfail until this lands).

## Cost accepted

No raw admin path to vdc-relay when the pico-cycler actor itself is
sick — `relay.py`'s handle check rightly refuses a non-boss commander.

## Interim hack (on the branch, 2026-09-06)

Until item 2 exists, `Scada.set_command_tree` leaves `vdc-relay` under
`auto.pico-cycler` for every boss, admin included, by a hard-coded name
(`Scada.HACK_VDC_RELAY_NAME`), and `AutoGoesDormant` / `AutoWakesUp`
no longer send the cycler `GoDormant` / `WakeUp`. Admin talks to
neither the cycler nor its relay; the cycler keeps rebooting flatlined
picos through an admin window. Two tests in
`tests/actors/test_command_tree_prefix_closed.py` pin the shape. Items
1 and 1a replace this by reparenting the interior node; delete the
constant and the HACK comments with them.

## ▶ Do this next

Promoted ahead of the command-tree matrix on 2026-09-06 (the field
evidence above). Settle the Open vocabulary question, then items 1
and 1a with the tree-matrix admin rows as the test (`test_scada_cmd_tree`
shape: admin wakes up on both fixtures, assert
`admin.pico-cycler.vdc-relay` and that a flatlined pico is cycled
while admin holds the tree), then 2 and 3.

## Open

- The command vocabulary: reuse `change.relay.state` events addressed to
  the pico-cycler, or a cycler-specific event pair (e.g. suspend/resume
  cycling vs open/close relay)? They mean different things — decide at
  build time with Jessica.
