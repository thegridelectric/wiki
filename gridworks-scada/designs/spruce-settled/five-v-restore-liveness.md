# 5 V restore and the pico liveness clock (spoke)

Status: Draft · Pass 0 · Updated 2026-09-10 · Linear: OPS-532

> What this is: the extra 5 V cycle a TurnOn can cause. When five-v-boss
> restores the 5 V after a hold, the tank actors' liveness clocks have run
> through the hold, so the first loop tick after the cycler wakes reports
> `PicoMissing` for picos that are only still booting, and the cycler
> runs a full reboot cycle before their first posts. On the sim it is
> harmless; on the real board it is one real power cycle per turn-on.

## What the code does

- `PicoLiveness` (`actors/pico_liveness.py`) is one rule for the three
  HTTP-fed actors: missing after 2.5 expected post periods of silence.
  That closed the short case (a slow first post no longer reads as
  missing).
- The tank actor feeds the vdc relay's state only to its **sim** source
  (`api_tank_module.py` `feed_sim_relay_state`); its own liveness clock
  is not touched by a relay close, so after a hold longer than 2.5
  capture periods `liveness.missing` is already true when the cycler
  wakes.
- The cycler's own "PicoMissing is expected for the next minute" window
  applies after its own open (`confirm_opened`), not after five-v-boss's
  close, and `WakeUp` puts it straight in `PicosLive`, where
  `PicoMissing` opens the relay.

## Do this next

1. Witness it: on the sim pair, hold the 5 V off for longer than
   2.5 capture periods, TurnOn, and count relay cycles before the first
   post; then the same on honeysuckle.
2. Fix at the actor: on a vdc-relay close, the three pico-fed actors
   restart their liveness clock (`liveness.heard(now)`), so the missing
   threshold is measured from power-on, not from the last post before
   the hold. One test per actor.

## Open

- Whether the cycler should also refuse `PicoMissing` for one flatline
  window after `WakeUp`, as it does after its own open.
