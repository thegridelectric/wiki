# Operator write after the gate

Status: Draft · Pass 0 · Updated 2026-11-04 · Linear: OPS-660

**EDD: no** build-out, verified by the suite and one real `gnr create`
of a throwaway-free row (the next GNode the fleet needs) that succeeds
first try from the documented recipe.

> What this is: the registry's operator write path (`gnr create`) as it
> has to work now that the hw1 broker admits only a client cert, and
> what makes that path legible before someone runs it. The first
> post-gate create, `hw1.flo` on 2026-11-04, took three failed attempts
> before the row went in; each failure was a fact nobody had written
> down.

## What happened

The `hw1.flo` create was run three times before it succeeded:

1. From the laptop with `operator.env` sourced: a pydantic error,
   `snapshot_interval_s` missing. `gnr create` builds
   `RabbitRunSettings`, the running service's settings class, to get a
   broker client, so every field the service needs is demanded of the
   operator too.
2. The same with the field exported: the broker refused the handshake,
   `certificate required`. `operator.env` is from 2026-07-21 and names
   a password URL; the gate (2026-10-07) admits only a client cert, and
   no `gnr create` had been run over hw1 since.
3. On the gnr box as `gnr`, with a freshly minted operator principal
   `hw1.gnr-operator` and its cert paths on the command line: the row
   went in, ack and visibility in under a second.

The recipe that worked is in `gridworks-infra/gnr/instance-README.md`.
This design makes it the only path and makes the failures impossible
rather than documented.

## Shape

1. **The operator CLI reads operator settings.** A small
   `OperatorSettings` (the `rabbit: RabbitBrokerClient` block and
   nothing else, `GNR_` prefix) replaces the `RabbitRunSettings()` call
   in `_run_create`. A missing service field can no longer stop a
   create.
2. **The gate is a precondition, checked first.** Before the node is
   printed and ENTER is asked for, the CLI opens the broker connection;
   a refused handshake exits with one line naming the cause and the
   recipe (no client cert configured; cert refused; broker unreachable).
   Today the connect comes after the Proof prompt, so an operator types
   the secret and then learns the transport is wrong.
3. **One documented path, on the box.** `template.operator.env` stops
   describing the laptop password path. The operator path is the gnr
   box, the `gnr` login, the operator principal's cert, the Proof typed
   at the prompt; the template becomes that recipe, or goes away and
   the README is the one place. The grid-node-registry README's
   operator section says the same in the repo's own words (the repo
   does not cite the wiki or infra).
4. **The ack prints the served record.** The visibility poll already
   fetches the row; printing it gives the operator the exact JSON that
   becomes a service's `g.node.gt.json`, so the next step needs no
   second fetch.

## Open

- Whether the operator principal is one per registry box (today) or one
  per human; the FIS rule is one principal per connecting process, and
  the CLI is one process at a time either way.
- `hw1.flo` and `hw1.time` sit at `Pending`; nothing reads the status
  yet, and the lifecycle section of the executor says when a row goes
  `Active`. Not this design's to settle, noted so it is not forgotten.
