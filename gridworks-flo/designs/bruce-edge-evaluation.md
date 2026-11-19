# Bruce edge evaluation

Status: Draft · Pass 0 · Updated 2026-11-02 · Linear: OPS-658

**EDD: yes** the bias is measured on the cached oak matrix before any
code moves: for every (state, action, load variant) the predicted
energy minus the chosen grid state's energy, its mean and its sign
split; a fix is verified by the same measurement centring at zero and
by the same `flo.params` giving the same bid twice.

> What this is: how bruce turns one hour of buying electricity into one
> edge of its graph, and whether that edge is honest. The first concern
> is the energy projection: the model's continuous next state is snapped
> to the nearest grid state in a temperature-profile metric, and that
> snap is not centred on energy, so the plan creates or destroys heat at
> every step. Later concerns about the same edge (the cost terms, the
> load variants, the window warnings) queue here under "Open".

## What is there now

An edge is built in two nearest-point snaps, in
`optimal-flexibility/src/bruce/graph_optimizer/assets/heat_pump_water_tank/asset.py`.

1. **Action snap.** Buying a given amount of electricity gives a heat
   output; heat to store is that minus load minus losses. The continuous
   value is snapped to the nearest entry of a discretised heat-to-store
   list (`asset.py:198-204`). A discharge beyond 0.25 kWh rounds toward
   the next more-negative entry rather than the nearest.
2. **State snap.** The model steps the tank forward under that action to
   a continuous predicted state. `closest_state` (`asset.py:382-428`)
   shortlists every grid state within ±0.5 kWh of the predicted energy,
   widening by 0.5 kWh until the list is non-empty, then picks the
   candidate with the smallest sum of per-layer absolute temperature
   differences. Energy difference is the tiebreaker; a hotter top the
   tiebreaker after that.

Commit e2ed8aa on `jm/knit` ("Avoid free energy during small
discharges") adds a direction rule to the state snap: when the action
removes more than 0.25 kWh net, the chosen state must be strictly colder
than the one it came from. The threshold is a module constant that is
part of the transition-matrix cache hash.

The matrix is indexed by (action, state, load variant) with no time
axis. The graph builder looks the same successor up at every one of the
horizon's steps (`graph.py:105-114`). The energy that goes forward is
the chosen grid state's, so whatever the projection added or dropped is
created or destroyed at that step, and the same creation recurs at the
same (state, action) pair every hour it is visited.

## The concern: an uncentred energy projection

The projection error has three properties, and the symptom seen so far
(a chain of small discharges that never cools the store) is the mild
one.

- **It has a direction.** The profile metric chooses on thermocline
  shape, and the final tiebreak prefers a hotter top; both lean
  optimistic about stored energy. The direction rule fixes the sign for
  larger discharges and leaves the magnitude bias, the sub-threshold
  discharges and every charge untouched.
- **It grows as the season gets colder.** The ±0.5 kWh window is small
  against a 120-gallon buffer in a shoulder month and large against a
  design-day discharge. As the load rises the heat pump runs most
  hours, the tank moves far per step, the shortlist is wider, and the
  metric has more room to pick a wrong-energy state. What is a small
  oddity in November's bids is a different plan in January, and the
  three-tank houses move more energy per step than oak's buffer.
- **It compounds through the plan.** The cleared path's store
  trajectory (`StoreWhList`) inherits the projection error over the
  whole horizon, so the terminal cost and the stability penalty are
  evaluated on a store estimate that drifts one way. The bid for this
  hour is the least affected number; the shape of the whole plan is the
  most.

An error that always points one way is the thing to avoid. A centred
error of the same size washes out over a path; a one-directional one
is a drift the plan builds on, and a direction rule that only flips the
sign moves the drift rather than removing it. The error is also
deterministic, which is why the shortest-path search finds and chains
it: a favourable rounding at one (state, action) pair is an
edge the optimiser can take every hour, and the drift over 48 steps is
up to one grid step per hour.

## Measuring it

The first experiment needs no live code. With oak's `flo.params` (one
tank, 120 gal, 9 layers, the 001 tuning) and the cached matrix
`heat_pump_water_tank_268a5f12.matrix.npz`, for every (state, action,
variant): run `next_state` for the predicted continuous state, look the
chosen successor up in the matrix, and take predicted energy minus
chosen energy. Report:

- the mean residual (the drift per hour), overall and split by charge
  versus discharge and by action size;
- the fraction of edges whose chosen energy moves against the action's
  direction (the free-energy edges), with and without the direction
  rule;
- the cumulative residual along oak's last cleared path, which is the
  error in the `StoreWhList` the LTN kept;
- for every edge, the chosen-minus-predicted error in top temperature
  and bottom temperature beside the energy error, and what an
  energy-first pick with the profile metric choosing only the shape
  would have given. The gap between the two columns is the metric's
  cost.

The same script, run after a fix, is the acceptance test: mean residual
at zero within the grid's half-step, no wrong-direction edges, and the
cumulative residual along a path bounded rather than linear.

## The metric

`state_distance` is the L1 norm on the nine layer temperatures. The
layers have equal mass, so a state's energy is a constant times the
plain sum of its layer temperatures, and the energy difference between
two states is the signed sum of the layer differences while the metric
is the sum of their absolute values. The metric is always at least the
energy error, but its minimiser does not minimise the energy error: two
candidates can sit at the same distance from the predicted profile and
differ in energy by up to that whole distance, and the energy tiebreak
only acts on exact float ties. The pick is driven by where the
thermoclines sit; the energy comes out wherever that puts it.

Downstream, three numbers matter: energy, the top temperature (the rswt
penalty and whether the load is served) and the bottom temperature
(what the heat pump sees, so lift and COP). An equal-weight L1 over the
layers is wrong-weighted for all three: it trades a 5 F error in the top
layer for 4 F spread across five middle layers. No norm on the layer
vector matches energy except the signed sum, and L2 would make a
thermocline off by one layer dominate more, not less. Once energy is pinned
first, the shape metric matters much less and the L1 may be adequate.
An earth-mover's distance between profiles (heat as a distribution over
height, adjacent-layer moves cheap) is a candidate to test with the
same script; it is a suggestion without a citation, not a settled
choice.

## The edge invariant

Three properties of every edge, each checkable over the whole
transition matrix without running a plan:

1. **Direction.** For every (state, action, variant), the successor's
   energy is below the state's when the action's heat to store is
   negative and above it when positive. No edge creates heat on a
   discharge or loses it on a charge.
2. **Centred.** Predicted energy minus successor energy, over all
   edges, has a mean within a small fraction of the grid's energy
   spacing, overall and within each action-size bin. Under
   interpolation the expectation is exact by construction and the test
   checks the weights; under dither it checks the pattern.
3. **Bounded along paths.** The cumulative residual along any path
   stays within a few grid steps rather than growing with the horizon.
   Tested on oak's cleared paths and on random walks over the matrix.

And the plan stays repeatable: the same `flo.params` gives the same bid,
because the ack is a binding contract. A random draw at build time
breaks that, which is how an earlier randomised version of the same
problem failed.

## Candidate fixes

All of these change the state snap only. The action snap chooses a
different discrete action and the physics is then stepped exactly for
it, so it creates no energy; it limits the bid's resolution and stays as
it is. The one asymmetry in it from commit e2ed8aa (a discharge beyond
0.25 kWh rounds toward more discharge) is unnecessary once the state
snap respects direction and goes in the same change.

1. **Energy first, shape second.** Project the predicted state onto the
   two grid energies that bracket it, on the correct side for the
   action's direction, and let the profile metric choose the shape among
   the states at that energy. The direction is right by construction and
   the residual is at most one bracket gap. On its own this does not
   centre the error: a discharge then always reaches a state a little
   colder than the physics says, so the per-step residual keeps one sign
   and still compounds, in the safe direction. The 0.25 kWh and 0.5 kWh
   constants disappear or are derived from the grid's energy spacing,
   which depends on NumLayers, gallons and the temperature step.
2. **Interpolate between the brackets.** The standard construction for
   a discretised dynamic program (Kushner and Dupuis, *Numerical Methods
   for Stochastic Control Problems in Continuous Time*, the Markov chain
   approximation method; citations to verify before relying) requires
   local consistency: the discrete successor's expected energy equals
   the continuous prediction. Split the transition between the two
   brackets with weights equal to the fractional distance and take the
   weighted sum of their cost-to-go. Centred by construction,
   deterministic, repeatable, no constant. It needs a backward pass
   over the state space rather than a single-successor graph, which is
   what OPS-655 builds; the two designs converge here.
3. **Deterministic dither within the bracket**, the fallback while the
   graph stays node-and-edge and each edge needs one successor. Round up
   or down between the brackets by a hash of (state, action, time step)
   mapped to [0, 1), compared with the fractional distance. The pattern
   is fixed, so the plan is repeatable and the matrix stays cacheable
   (it stores both brackets and the fraction; the graph builder applies
   the hash). The roundings along a path alternate, their sum stays
   bounded, and the favourable ones no longer line up hour after hour.

Fix 1 gives the sign; fix 2 or 3 the centring. Exact
successors are not available: the grid is finite and the physics does
not map it to itself (losses scale with the state, the load draws the
layers unevenly, the thermoclines move by non-grid amounts), so
quantising the actions to the grid aligns only the energy and the shape
still snaps.

## Plan

1. Write the residual script in the bruce checkout against oak's params
   and the 268a5f12 matrix; record the numbers here.
2. Agree on the edge invariant above (direction, centred,
   bounded along paths) as a property test in bruce's suite that runs
   over a whole transition matrix.
3. Implement fix 1 with fix 3 on a bruce branch, or fix 2 if the array
   pass from OPS-655 is in by then; rerun the script; compare
   oak's bid and path before and after on the same `flo.params`, and
   the same `flo.params` twice for repeatability.
4. Regenerate the matrix for the fleet shapes and place them on the ltn
   box before the roll.

## Open

- The charge side: a charge that snaps down is a free loss. The
  optimiser does not seek it, but it biases the value of charging and so
  the bid.
- Whether the threshold constant should have been a `flo.tuning.bruce`
  field, given it shapes the cached matrix; it leaves with fix 1.
- Later edge concerns, in the order they come up: the load-bucket
  variants and what they do to a discharge edge; the "No state within
  ±N kWh" warning path, which today widens the window silently; the
  cost terms (rswt, short-cycle, stability) evaluated on a chosen rather
  than predicted state.
