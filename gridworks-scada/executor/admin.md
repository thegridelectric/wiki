Status: Draft · Pass 0 · Updated 2026-09-13

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
  operator holds the house. An `AdminDispatch` or
  `AdminAnalogDispatch` is unwrapped and delivered in-process to the
  node its `ToHandle` names, header source `admin`, payload untouched:
  the admin client authors `FromHandle admin` and `ToHandle` the node's
  handle under admin, so the node's two authority checks
  (control-hierarchy "Command interfaces and replies") read the admin
  client's own claim. Admin is the only party outside the scada that
  commands an actuator; the LTN has no path to a relay or a 0-10V
  output except through the leaf ally's place in the tree.

Everything else — trust model, prod-broker migration, client form
factors, audit — is in the gridworks-admin executor.
