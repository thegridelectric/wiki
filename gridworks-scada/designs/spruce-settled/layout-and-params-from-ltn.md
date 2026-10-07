# Layout and operational params from the LTN (spoke)

Status: Draft · Pass 0 · Updated 2026-10-06 · Linear: OPS-532

> What this is: what the LTN sends a running scada to change its
> operational params or its layout, and what the scada does on
> receiving it. The LTN is the one way new params reach a scada
> (OPS-408); this spoke is the scada's end of that. The check a scada
> runs on its own files at boot is OPS-392's and is the same check this
> path runs before it writes.

## What holds today

The scada reads `operational-params.json` once, at boot
(`actors/scada_data.py` `load_operational_params`). A change to the
params is authored in tlayouts, copied to the box with
`experiments/put_layout.sh` and picked up at a scada restart, each step
by hand from a laptop. The effort of that path is the reason params on
a box go stale, more than any missing check. The scada also writes the
file itself when it latches `ServiceContractBroken`
(`executor/local-control.md` "The dispatch refusal"), so the file on the box is not always the file
that was authored, and a person clears the latch by restarting the
scada on a file that accepts dispatch again.

Two checks hold the box file and the tlayouts source together until the
LTN path exists (OPS-408):
`put_layout.sh` stops on a difference before it pushes, and the
session-start drift check reports each house whose two copies differ.

The scada's report of the params it runs is `gw.house.operating.status`,
sent once after startup and again when a field changes. A cleared latch
is that record carrying `AcceptsDispatch` true. The scada raises no
glitch for a clear; an alerting service that fired on the refusal
resolves its `gw.alert` from the same record.

## What the message has to do

- **Carry operational params as the ops word,** not as one-off wire
  words addressed at a handle. A controller's gains, a posture and the
  dispatch refusal all arrive the same way.
- **Clear the cold latch without a restart.** A params update with
  `AcceptsDispatch` true is how a person, through the LTN, says the
  house is back in service.
- **Not clear the latch by accident.** A whole-instance push made for
  an unrelated change, built from a copy older than the latch, carries a
  stale `AcceptsDispatch: true`. The pushed instance has to start from
  the scada's last reported operating status, or the scada has to be
  able to tell a deliberate clear from a carried-over value. A revision
  on the instance (below) is one way: the scada refuses a push built
  from a revision older than the one it runs.
- **Leave the box able to boot alone.** What the scada adopts it also
  writes to `operational-params.json`, so a restart with no LTN in
  reach comes up on the params it last ran.

## The receive path

One word carries a proof and one or both of a layout and an operational
params instance. The scada runs these checks in order and writes
nothing until all pass:

1. The sender is the scada's LTN.
2. The proof holds: a signed hash showing the LTN is who it says it is,
   signed against its TaTradingRights. Stubbed until the signing exists.
3. Each carried word has the TypeName and Version of the file the scada
   already holds. A scada does not change layout family by message.
4. Each carried word validates.
5. The layout and the params the scada would hold after the write are a
   consistent pair, a carried word taken with the held one where only
   one arrives. The first pair rule, built for boot as
   `check_backup_when_cold` in `sema_to_dc.py`: `UsesBackupWhenCold`
   true in the params requires a `Hydronic.Backup` with `InService`
   true in the layout, an element backup at a Nolan layout.
6. The files are replaced atomically.

Steps 3 to 5 are what a scada runs on its own two files at boot, so the
boot check and this path share one function.

## Open decisions

- **Writing two files as one.** Two renames are not one: a stop between
  them leaves a pair that was never checked together. Either the pair
  lives in one folder swapped by a single rename, which changes how a
  scada finds its files by their deployed names, or the boot check is
  the backstop and a scada that boots on a mismatched pair falls back
  to the pair before it.
- **A new layout and the running scada.** Actors are built from the
  layout at boot, so an adopted layout takes a restart. Whether the
  scada restarts itself after the write or waits to be restarted.
- **One word or two:** one word with both members optional and an axiom
  that at least one is present, or a word each for layout and params
  sharing the proof.
- **How the scada reports a refusal:** a glitch naming the failed
  check, with no reply that needs an ack.

- **Whole instance or partial update.** The LTN publishes a whole new
  `gw.operational.params` instance the scada adopts atomically, or the
  ops word gains a versioned partial update.
- **What a running scada does on adoption:** which fields take effect
  live (a posture change, `Standby`, a running controller's gains) and
  which need the restart they need today.
- **Whether a params instance carries a revision of its own.** Neither
  a layout nor a params instance has one today, so a push cannot say
  what it was built from and a site-visit record has nothing to point
  at. The scada bumps it on its own latch write. Authoring and
  revisions upstream of the box belong with the terminal-asset registry
  (OPS-471).
- **How the scada answers:** the operating status already reports the
  six fields it copies from the params; whether that is the whole
  acknowledgement.
- **Which params axioms the scada re-checks** against its layout on a
  live adoption (the relay lists that stop the scada at load today).

## Do this next

Settle whole-instance against partial update, with the cold-latch clear
as the first case to carry through both.
