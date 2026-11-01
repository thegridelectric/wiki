# Changelog

A reverse-chronological log of WHY we made each commit **in the
admin code repo** (TBD — admin currently lives in
`gridworks-scada/packages/gridworks-admin/`; will likely extract to
its own repo when the broker substrate flips from local-mosquitto
to a dedicated admin broker). The matching git commit holds the
WHAT (the diff). Each entry's date and one-line title mirror the
corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-10-29 — gridworks-admin 1.3.1 pins gridworks-scada-protocol>=1.3.0 (`a9343909`, main via PR #597 `78a06838`, OPS-613)

**What:** the admin package's pin on the scada protocol package moves
to 1.3.0, the release with `scada.control.capabilities` 003.

**Why:** a 1.3.0 panel installed against an older protocol package
decodes a capabilities word without `AdminMayTake`; the pin makes the
pair install together.

## 2026-10-29 — gwadmin 1.3.0: the secondary pump row offers the relay pair (`c7b3ae8f`, main via `0a59e6ca`, OPS-613)

**What:** version 1.3.0 of `gridworks-admin`, built on the scada
snapshot at `scada.control.capabilities` 003. No row-logic change: the
pump's flagged interface gives its row CloseRelay and OpenRelay, and
the scada takes the relay from hp-boss on the first one.

**Why:** the operator asks for the circulator on its own row, with
hp-boss `HpOff` as the scada's gate, rather than the panel knowing
which relay is takeable.

