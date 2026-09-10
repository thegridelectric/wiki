Status: Draft · Pass 0 · Updated 2026-09-10

# Admin (pointer)

What this is: a pointer — admin has its **own wiki domain**:
[`../../gridworks-admin/`](../../gridworks-admin/executor/primary.md).
This stub exists because the admin *code* lives inside this repo
(`gridworks-scada/packages/gridworks-admin/`, the `gwa` CLI), which
makes the scada executor the natural-but-wrong place to look.

Scada-side facts (the seam, not the domain):

- The scada publishes **`scada.control.capabilities`** (`001`, staging)
  over the `admin` link: the capability cover of its live command tree,
  one `gw.command.interface` per relay or command node the operator may
  address, built from the layout's handles
  (`gw_spaceheat/actors/scada.py:1692`). The word and what the client
  reads from it: gridworks-admin executor "The capabilities contract";
  the pattern it follows: [`../../command-surface.md`](../../command-surface.md).
- Relay and command-node `single.machine.state` is forwarded to the
  admin link (`scada.py:1556`), as are relay and 0-10V `single.reading`.
- The admin handlers live in `scada.py` (`AdminDispatch` /
  `AdminAnalogDispatch` / `AdminKeepAlive` / `AdminReleaseControl`);
  TopState `Auto → Admin` suspends hierarchical control while an
  operator holds the house. An `AdminDispatch` is re-addressed to the
  node its `ToHandle` names and delivered as that node's own command;
  the node answers admin as it would any boss (control-hierarchy
  "Command replies").

Everything else — trust model, prod-broker migration, client form
factors, audit — is in the gridworks-admin executor.
