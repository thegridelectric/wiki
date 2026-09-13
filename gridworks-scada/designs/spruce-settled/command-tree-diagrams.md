# Command-tree diagrams (spoke)

Status: Draft · Pass 0 · Updated 2026-09-13 · Linear: OPS-532

> What this is: the graphic diagrams the control-hierarchy executor asks
> for (`../../executor/control-hierarchy.md` "five-v-boss: the 5 V hold",
> the WORK IN PROGRESS note): the command tree under each root (admin,
> local-control, leaf-ally) for each layout family, with the five-v-boss
> subtree in PicoCycler and in FiveVOff, and the hold's two reparents as
> before/after pictures.

## Two kinds of picture

The executor wants two different hierarchies drawn, and they come from
different sources.

- **State machines.** Fourteen actors declare a `transitions` Machine as
  a list of trigger/source/dest dicts (`actors/scada.py:96`,
  `actors/sieg_loop.py:106`, `actors/local_control/house0/tou_base.py:47`
  and the rest); HpBoss and FiveVBoss are hand-rolled if/elif. Nesting is
  prose only. Some transition sets are built by comprehension (GoDormant
  from every state, wildcard sources), so the true set is known only
  after the class is instantiated. These diagrams are generated: a script
  imports each actor class, builds its machine, reads the transition list
  back from the library, and emits one Mermaid `stateDiagram` per machine
  into the executor page, with the parent state drawn as an overlay from
  the documented nesting. Tweak a machine, rerun, the picture follows. No
  scada code changes; nothing hand-drawn.
- **Command trees.** A different hierarchy: handle-prefix rewrites done
  in Python at each authority change (`actors/command_node.py:75`
  `set_command_tree`, with the five-v and sieg special cases). Not
  derivable from the machine definitions, so these are drawn off
  `new.command.tree` as published by a running sim, as before.

Form: Mermaid in the executor page for both.

## Later: machine definitions as a sema word

States are mostly registry enums already (`gw1.main.auto.state`,
`gw1.lc.top.state`, `pico.cycler.state`, ...) with gaps: Scada's top
states and PicoCycler's states are hardcoded strings, and the sieg valve
and control enums live only in `actors/sieg_loop.py`. Triggers are bare
string literals nowhere checked, and no word encodes a transition. After
the sema launch, a machine-definition word (states and events by `$ref`
to the enums, a transition list, a parent-state ref for the nesting)
lets scada declare each machine from the registry, a conformance test
check the trigger strings, and the generator above read the registry
instead of Python. The same rows serve report-all-machine-states. A
machine definition is rows and refs by nature, which is the shape the
effortless rulebook ingests from YAML, so this is where that integration
starts if it starts anywhere. Not before the launch.

## Do this next

1. Write the state-machine generator (experiments folder) and put its
   Mermaid output in the executor page; Nolan and House0 machines first.
2. Draw the Nolan command trees off `new.command.tree` from a running
   sim, then House0 with and without the sieg loop.
3. Replace the WORK IN PROGRESS note with the pictures.
