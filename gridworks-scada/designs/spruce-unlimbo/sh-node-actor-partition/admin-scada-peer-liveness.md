# admin-scada-peer-liveness (rope chunk)

Status: Draft · Pass 0 · Updated 2026-09-09 · Linear: OPS-392

> What this is: a chunk of the `sh_node_actor` partition rope, now
> reduced to one quick fix. Hub: [`primary.md`](primary.md).

The admin liveness and takeover work this chunk used to hold (a dead
admin link noticed by neither side, `heartbeat.a` both ways, one admin
at a time) moved to its own design under the admin domain
([OPS-529](https://linear.app/gridworks/issue/OPS-529)). What stays on
the rope is the scada-side bug found while reading that path:

**`process_admin_dispatch` executes what it says it ignores.**
`gw_spaceheat/actors/scada.py`, the `if from_node != self.admin:`
branch logs "Ignoring AdminDispatch from … Expected admin!" and then
falls through to wake Admin, renew the timeout and dispatch the event
anyway. The `return` is missing. Same shape to check in
`process_admin_analog_dispatch`.

Quick: one `return` per handler plus a test that a dispatch from a
non-admin node is refused and leaves TopState untouched. Well under an
hour; chip, don't sculpt.
