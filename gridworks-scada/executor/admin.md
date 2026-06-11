Status: Draft · Pass 0 · Updated 2026-06-10

# Admin (pointer)

What this is: a pointer — admin has its **own wiki domain**:
[`../../gridworks-admin/`](../../gridworks-admin/executor/primary.md).
This stub exists because the admin *code* lives inside this repo
(`gridworks-scada/packages/gridworks-admin/`, the `gwa` CLI), which
makes the scada executor the natural-but-wrong place to look.

Scada-side facts (the seam, not the domain):

- The scada publishes **`scada.control.capabilities`** (sema canon at
  v001) over the `admin` link — the stable control-surface projection
  that decouples the admin client from `layout.lite` version churn.
- The admin handlers live in `gw_spaceheat/actors/scada.py`
  (`AdminDispatch` / `AdminAnalogDispatch` / `AdminKeepAlive` /
  `AdminReleaseControl`); TopState `Auto → Admin` suspends hierarchical
  control while an operator holds the house.

Everything else — trust model, prod-broker migration, client form
factors, audit — is in the gridworks-admin executor.
