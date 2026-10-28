# Procedural interrupts

Status: Draft · Pass 0 · Updated 2026-10-28

What this is: how the pump doctors (procedural, non-transactive
recovery routines) send commands inside the command tree, why the
scada-routed form stopped working, and what that fixes in the
architecture. Verbatim from the 2026-10-28 session explanation; the
executor prose rules (present tense, no legacy, no transition
narrative) are owed a distillation pass.

## Why it worked on legacy

On legacy the doctor never talked to the 0-10 V output. It sent its AnalogDispatch to the scada, with the LTN's alias as FromGNodeAlias. The scada had a branch for that: accept any AnalogDispatch "from my LTN", look up the target by AboutName, compute the boss handle as the parent of the target's handle, and send a fresh dispatch to the target with that FromHandle and the scada itself as the wire source. The code called itself "HUGE HACK". The legacy output then checked the sender by looking up the payload's own FromHandle, so a re-authored dispatch always passed.

So yes, legacy was a hack, and a specific kind: authority laundering. Anyone who could reach the scada could command any 0-10 V output as if they were its boss, because the scada rewrote the claim and the output checked the claim against itself. It worked for a year because the doctors were the only in-process caller and nothing else exercised the hole.

## What broke it, and what the patch leaves

My commit of 2026-09-13 (06dcfc3a, "one sender rule") made every command node check that the wire source and the claimed FromHandle agree, and deleted the scada's rebuild. Its changelog entry says the branch was uncalled. That was wrong: the doctors called it, and I missed them because they addressed `primary_scada` rather than naming the type in scada.py. After that, the scada's dispatcher fell through to its default case, which raises, and the raise happens inside the scada's own message loop, so gwproactor stopped the process. The test I added with 4a7dcc06 stubbed the host's send with a lambda, so the dispatch was never delivered and the mis-addressing was invisible.

Thomas's patch addresses the output directly but leaves the wire source as the host's own node (`lc`, handle `auto.lc`) while the FromHandle is `auto.lc.n`. The output refuses it as `bad_sender`. The crash is gone and the doctor's first step, zeroing the pump, silently does nothing. It also still names the LTN as the dispatch's author.

## Procedural code and the state machines

The command tree is a hierarchy of handles. The scada's top machine (auto, home-alone, admin, dormant) decides who is boss, and `set_command_tree` rewrites every actuator's handle so it reports to the live boss. A command goes down one edge of that tree: an actuator takes a command only from its parent handle, and only when the node that put the message on the wire is that parent. Local control's own machine then picks which of its state nodes is the boss at any moment. That is what `command_node` on the host protocol means: the top of the tree now, which may change mid-flight.

The pump doctors are not states or transitions. They are procedural interrupts: a sequence with awaits that runs beside the machine and borrows its current authority. Three consequences follow for the architecture.

- **A procedure never authors its own identity.** It sends as the current command node, so the sender rule holds by truth rather than by rewriting. Every relay helper on the host already works this way (`heatcall_ctrl_to_scada` and friends take `command_node` and send with it as source). The legacy hack existed because the doctors did not.
- **Authority can move under the procedure.** A state transition during the doctor's waits changes the boss. Today the helpers log "didn't have the rights" and continue, and the restore in `finally` may be sent from a different node than the one that zeroed the output. That is a real gap and this fix does not touch it.
- **The state nodes are not actors.** The `n` node has no communicator. The host's send has a block, itself labelled a hack, that maps the state nodes to the local-control communicator. That is the structural question underneath all of this, and it is pre-existing.

Given that, the correct structure for the doctor's dispatch is the same as for its relay commands: a host method that authors the dispatch from `command_node` and sends it with `command_node` as source, straight to the output. Routing through the scada is exactly the laundering that was removed.

## What I implemented, and is it a hack

A method `set_010_level(dfr_node, volts_times_ten, command_node)` on the House0 hydronic host, beside `set_010_defaults`, which now loops over it. Both doctors call it with `command_node=h.command_node`. The unused `primary_scada` left the protocol and the test double. I would not call it a hack: it is the existing pattern applied to the one caller that had skipped it, and nothing is re-authored. It inherits the pre-existing state-node mapping in the send path, as every relay command does.

The test delivers the doctor's dispatch the way the proactor would, through the scada's router, and asserts three things: the scada's own handler did not raise, the output accepted the zero and acked the command node, and no glitch came from the output. Against the pre-patch doctors it fails on the raise. Against Thomas's patch it fails on `bad_sender`. With the fix the doctor file passes 13 of 13.

## Open

- Authority moving under a running procedure (the second consequence above): what a doctor does when the command node changes between its zero and its restore.
- The state nodes as non-actors: whether `n` and its siblings become communicators or the tree speaks in another form.
- The scada's dispatcher raises on an unexpected payload inside its own message loop, and that raise stops the process. Whether one stray in-process payload should be able to stop the scada.
- Distill this file to the executor prose rules.
