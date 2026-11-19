# Graph as arrays

Status: Draft · Pass 0 · Updated 2026-11-02 · Linear: OPS-655

**EDD: yes** the same `flo.params` through bruce before and after, on
the laptop with the cached nine-sensor matrix: peak RSS and wall time
measured, bid curve and paths identical.

> What this is: bruce's graph held as arrays over the state space
> instead of node and edge objects, which cuts the build's peak memory
> from gigabytes to tens of megabytes and removes the pickled trimmed
> graph. For Thomas and Olly on the FLO box
> ([OPS-655](https://linear.app/gridworks/issue/OPS-655/graph-as-arrays)).
> The transition matrix's manifest, its generation command and the cached
> back half of the graph are
> [OPS-656](https://linear.app/gridworks/issue/OPS-656/flo-matrix-manifest-generation-command-cached-back-half-of-the-graph).

## What is there now

Paths are in `optimal-flexibility/src/bruce/graph_optimizer/`.

The graph (`graph.py`) is time-layered over the state space:
`Node(state, time_step, mode)` objects with a `pathcost`, a `next_node`
and a `shortest_path_elec` list; `Edge(tail, head, cost, action,
elec_used_kwh)` objects in a dict of lists per node; a backward pass
that takes `min` over each node's edges in Python; and, for every node
at step 1, a walk along its best path collecting the electricity of
each edge into that node's list. The trimmed graph pickled for the bid
is the step-0 and step-1 nodes with those lists. The transition matrix
(`transitions_matrix.py`) is the one input already in array form: for
each (action, state) the index of the state one step later.

Measured on OPS-514 for a three-tank house: 1.56 M nodes, 2.96 M edges,
1.85 GB at peak, 43 s, to reach a 59 MB trimmed graph and a sub-second
solve. The size is the object representation: a node, its edges, its
list and the dict entries cost about a kilobyte each, and the per-node
electricity lists repeat the same path tails tens of thousands of
times.

## The design

The graph is a dynamic program over a fixed state space and a fixed
step grid, so it needs no node or edge objects. Per step `t`:

- `cost[t]`, shape (actions, states): the asset's cost of taking each
  action in each state at that step, computed as arrays over the state
  space for each action rather than per (state, action) call.
- `allowed[t]`, the same shape, boolean: the action is available in
  that state and the transition it produces is allowed.
- `next_state_index`, the matrix, indexed by (action, state) or
  (action, state, variant).

The backward pass is `pathcost[t] = min over actions of cost[t] +
pathcost[t+1][next_state_index]` with `allowed` masking, and
`best_action[t]` the argmin, both shape (steps, states): `float32` and
`int16`. The path from any state at step 1 is read by following
`next_state_index[best_action[t, s], s]` forward, so the per-node
electricity lists are replaced by one walk at bid time for the states
the bid touches. The mode axis (`node.mode`) is a third index on the
state side or a second state table, decided when the asset's mode rules
are written out as arrays.

What the work is: writing the asset's per-(state, action, step)
callbacks (`get_available_actions`, `allow_transition`, `cost`,
`elec_used_kwh`, `transition_variant`) as functions over the whole state
space for one action, and the stability penalty the same way. The
optimizer's answer does not change; the representation does. Memory
falls from gigabytes to the arrays above (for the three-tank house,
tens of megabytes, roughly a 95 percent cut), the build from tens of
seconds to the time of the vectorized cost, and the trimmed-graph pickle
is no longer needed.

## Plan

1. Fixture and baseline: the oak `flo.params` from the journal, the
   cached nine-sensor matrix, peak RSS and wall time recorded, bid curve
   and paths saved.
2. Arrays: one asset callback at a time, each checked against the
   object graph on the fixture, until the backward pass runs on arrays
   and the object graph is deleted.
3. The measurement again; the design distills into the FLO executor
   (`bruce-flo.md`) and closes.

## Open

- The mode axis: a state-side index or a second table.
