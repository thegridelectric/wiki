# Sieg command tree (spoke)

Status: Draft · Pass 0 · Updated 2026-09-13 · Linear: OPS-392

> What this is: the Siegenthaler loop's place in the command tree and
> its command surface, admin included, worked out before the fall
> layouts arrive. Opened because the partition left `SiegLoop` reading
> House0 choreography (`change_to_hp_keep_more`, `sieg_valve_active`,
> `hp_boss`, `total_hp_pwr_w`) that moved to `hydronic/house0.py`; the
> interim is `SiegLoop` on `House0Hydronic`, and this spoke is where
> that interim ends.

## Why not leave it on House0Hydronic

Two more layouts go to the field this fall and one of them has a
Siegenthaler loop without the House0 hydronic set (no buffer, no iso
valve). The loop's choreography is then not House0's; it belongs to
whatever has a sieg valve. The partition's tiers stack plant judgment
on the command-tree mechanics (`HydronicNode` extends `CommandNode`),
which fits interior nodes and fits the loop only by accident.

## The question

What does the sieg loop take from above and report below, and what may
admin do to it directly? Today hp-boss is its boss and the valve moves
are relay commands sent under hp-boss's handle. The likely shape is a
sieg tier (a helper or mixin holding the valve choreography and the
hp-power read) inherited by the loop and by any family's hydronic file
that has the loop; whether admin commands the valve through hp-boss or
gets its own handle is the design decision.

The original loop, the one that ran the 2025–26 season, is kept for
troubleshooting at scada `c55fe9eb` (`gw_spaceheat/actors/sieg_loop.py`
at that commit); `sieg_loop.py` carries the pointer.

## What the LTN used to send the loop

Three dev senders on the LTN (deleted 2026-09-13) were the
troubleshooting surface for the loop during the 2025–26 season. They
authored `FromHandle ltn`, `ToHandle ltn.leaf-ally`, a handle the tree
never produces, and no code called them; the scada-side receivers
remain (`scada.py` `process_reset_hp_keep_value`,
`process_sieg_loop_endpoint_valve_adjustment`). Kept here as the
command surface the loop has needed from outside, for the design of
the sieg tier:

- **Reset the keep value** (`reset.hp.keep.value`,
  `HpKeepSecondsTimes10`): tell the loop where the valve actually is,
  in seconds of keep, after a hand move or a lost count.
- **Send harder** (`sieg.loop.endpoint.valve.adjustment`,
  `HpKeepPercent 0`, `Seconds`): drive the valve toward FullySend for
  the given seconds.
- **Keep harder** (same word, `HpKeepPercent 100`, `Seconds`): drive
  it toward FullyKeep for the given seconds.

Whoever ends up as the loop's boss (hp-boss or an admin handle) needs
these three moves in its vocabulary; the endpoint word is the odd one
in that it commands a duration rather than a state.

## Open

- Whether the sieg tier is a mixin under `hydronic/` or a helper the
  loop owns.
- Admin's command surface for the valve: through hp-boss or direct.
- The seasonal reset: who resets to FullySend at season end.
- The loop's two enums (`SiegValveState`, `SiegControlState`, and their
  events) are defined inline in `sieg_loop.py` with no registry word;
  every other actor's states are sema enums. The sieg tier should close
  that gap when it forms, so the machine pictures and the state report
  read the loop like the rest.

## Do this next

Wait for the fall layout words to settle (`fall-layouts.md`), then
grill the command surface with the sim House0 and the sieg-loop fall
layout side by side, with the loop's two generated state-machine
diagrams and the House0 command tree with the loop (OPS-532) on the
table.
