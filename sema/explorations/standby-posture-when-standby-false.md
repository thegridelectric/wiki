# Concern: `StandbyPosture` says something when `Standby` is false

Status: Draft · Pass 0 · Updated 2026-11-18

> What this is: an open question on `gw.house.operating.status`, raised
> from the LTN launch (OPS-654), for the next pass on that word.

`gw.house.operating.status` always has a `StandbyPosture`, so a house
with `Standby` false reports `NoHeatingOrCooling` and every reader has
to know to ignore the posture whenever `Standby` is false. The status
should say only what is in force.

Two shapes fix it: the posture becomes optional and is absent when
`Standby` is false, or an axiom states that `StandbyPosture` is present
exactly when `Standby` is true. Either is a version bump on the word,
so it waits for the next change the word needs anyway.
