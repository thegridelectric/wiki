# Pico-cycler command (spoke)

Status: Draft · Pass 0 · Updated 2026-09-01 · Linear: OPS-392

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

## The work

1. Uniform subtree rule in BOTH `set_command_tree` implementations
   (`scada.py`, `command_node.py`); delete the vdc exemption; fix
   `CommandNode`'s docstring ("all actuators report directly to boss"
   overclaims).
2. Pico-cycler accepts an on/off command from its boss, mapped onto its
   existing FSM (it already bosses vdc-relay through
   `change.relay.state` events).
3. gwadmin grows a pico-cycler control alongside its relay list.
4. Tree-matrix admin rows move to the `admin.pico-cycler.vdc-relay`
   shape (marked xfail until this lands).

## Cost accepted

No raw admin path to vdc-relay when the pico-cycler actor itself is
sick — `relay.py`'s handle check rightly refuses a non-boss commander.

## Open

- The command vocabulary: reuse `change.relay.state` events addressed to
  the pico-cycler, or a cycler-specific event pair (e.g. suspend/resume
  cycling vs open/close relay)? They mean different things — decide at
  build time with Jessica.
