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

## Dormant is the leaf state (examined 2026-09-07)

The claim under test: an actor's Dormant state is the local face of its
ShNode being a leaf in the current command tree. Confirmed for the two
actors that carry a top state, unenforced in one direction, undefined for
the rest.

**Where it holds.** LocalControl (both `local_control/nolan.py` and
`house0/tou_base.py`) and LeafAlly are sent `GoDormant` only in
`Scada.auto_trigger`, and every branch there rewrites the tree first
(`set_command_tree(...)` precedes the `GoDormant`/`WakeUp` sends, all
five transitions). The layout is one in-process object, so the rewrite is
visible to every actor before the message lands. Both LocalControls guard
one direction on arrival: `GoDormant` with `my_actuators()` non-empty
raises ("LocalControl sent GoDormant with live actuators under it!",
`nolan.py:262`, `tou_base.py:483`). LeafAlly has no such guard. Nothing
guards the converse: a Normal LocalControl whose subtree has been taken
raises nothing; only the `FsmEvent` axiom 2 (`FromHandle` must be the
immediate boss of `ToHandle`) rejects its commands one by one, at
construction, in the sender. `Scada.enforce_auto_state_consistency`
(`scada.py:1286`) reconciles states to states (`auto_state` against the
LC top state and the ally state) and never looks at the tree.

**Where it does not apply.** The pico-cycler keeps `vdc-relay` under
admin (the 2026-09-06 hack) and is not sent `GoDormant`; that is
consistent with the claim, since it stays an interior node. hp-boss and
sieg-loop have no top state at all: in a sieg layout they are always
interior nodes (their relays hang under them in every tree), and under
admin they simply answer to admin. hp-boss's only protection is the
`ToHandle` check in `process_fsm_event` (`hp_boss.py:80`), and that check
logs a `bad_boss` glitch and then falls through without returning, so a
mis-addressed command is still executed. sieg-loop's "dormant"
(`sieg_valve_dormant`, `before_keeping_steady`) means the valve is idle,
a different word sharing the spelling; keep the two apart in prose.

**Gaps and bug, recorded** (each becomes a matrix row):

- Gap 1: the leaf ⇒ Dormant direction is enforced only by the two
  LocalControl `GoDormant` handlers (raise on live actuators); LeafAlly
  has no guard at all.
- Gap 2: the Dormant ⇒ leaf direction, and its contrapositive (a Normal
  actor whose subtree was taken), is enforced nowhere; the `FsmEvent`
  axiom rejects each stray command at construction, in the sender, which
  is a per-command accident rather than a guard.
- Bug: `hp_boss.process_fsm_event` (`hp_boss.py:80`) logs a `bad_boss`
  glitch on a mis-addressed command and falls through without returning,
  so the command executes anyway.

**The timing row, restated.** Tree rewrite and state change are not one
step: the rewrite is synchronous in the scada, the state change waits on
the actor's message queue, and a sequence in flight between them
(`NolanLocalControl.command_sequence`, 15 s steps, checks `top_state`
only at the loop head) keeps commanding until the axiom rejects it. The
rejection is correct but it is a per-command accident, not the design.

**What the proposals do and do not change.** The coupling of tree and
state stays as it is: the scada rewrites the tree synchronously, then
tells the actors, and each actor's state follows when its queue gets to
the message. Nothing below reorders that. The change is what an actor
consults before commanding: today it consults its own state (which lags
the tree); under proposal 1 it consults the tree (which is already
current). The lag then stops mattering, and the state becomes a report
of where the actor stands rather than the thing that keeps it honest.

**Proposals** (for the matrix chunk; each is a test row plus, where
named, a guard):

1. Guard in the funnel, not in the handler: `CommandNode.send_state_command`
   (and the `FsmEvent` sends in `hydronic/house0.py`) refuse when the
   target is not in `my_actuators()` / not under `self.node.handle`, with
   one log line, before constructing the event. That makes "a leaf
   commands nothing" a property of every interior actor, LocalControl,
   LeafAlly, hp-boss and the circuit FSMs alike, instead of a raised
   exception in two handlers and an axiom in the sender.
2. The converse guard as a test row, not code: after every transition on
   both fixtures, assert for each actor with a top state that `Dormant`
   ⟺ `my_actuators()` is empty. Add the same assertion to
   `enforce_auto_state_consistency` only if the row finds a real drift;
   the reconciliation loop already runs, so the check is cheap.
3. ✅ `hp_boss.process_fsm_event` returns after the `bad_boss` glitch
   (landed in `30fbac27`); the row here asserts a stale-boss command
   changes no relay.
4. Sequence-interrupt row (the 2026-09-06 finding): start a
   `turn_on_hp` sequence, fire admin wake-up mid-sequence, assert no
   command leaves the LC after the tree rewrite. With proposal 1 the
   assertion is "no `FsmEvent` constructed", not "an axiom rejected one".
5. `set_command_tree` in `scada.py` and `command_node.py` are two copies
   of the same rewrite (the sieg branch and the vdc hack differ). The
   matrix runs against the scada copy; converge on one before the rows
   multiply.
6. Admin cannot reach the heat pump in a sieg layout today: the
   `to_name == "hp-boss"` rewrite in `scada.py:462` re-addresses the
   dispatch to `admin.hp-scada-ops-relay`, but under admin the relay's
   handle is `admin.hp-boss.hp-scada-ops-relay`, so `relay.py:283`
   rejects it. ✅ Fixed in `30fbac27`: admin commands `TurnOn`/`TurnOff`
   to `admin.hp-boss`, hp-boss closes its relay, and the rewrite is gone;
   the matrix row asserts the relay moves.
