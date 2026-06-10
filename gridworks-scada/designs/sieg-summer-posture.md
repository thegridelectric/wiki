# Sieg summer posture (design — basic stub)

Status: Draft · Pass 0 · Updated 2026-06-10 · Linear: OPS-395

> What this is: in summer/Standby, the sieg valve should default **OPEN** —
> the reverse of heating-season behavior, where the simple sieg code keeps
> the loop CLOSED whenever the heat pump is off. Basic stub; the physical
> rationale and mechanism are the design work.

## Verified code anchors (2026-06-10)

- SiegLoop's awareness of the world is **HpBoss state messages only**
  (`process_message`: ActuatorsReady + SingleMachineState from HpBoss).
  Nothing tells it the *system* is asleep — no GoDormant path, no
  SystemMode. "Park the sieg loop" (capability design principle 5, OPS-394)
  lands here.
- Valve motion is SiegLoop's own relay pair (`hp_loop_on_off` = moving,
  `hp_loop_keep_send` = direction); Standby correctly no longer touches
  them.
- Heating-season HP-off behavior keeps the loop closed (Jessica, sieg
  author).

## Pressing first action

Maple is in Standby **now** (post-incident). Check its current valve
position (admin/visualizer). If it is sitting closed for the summer,
prioritize: **when local control is Standby, the sieg loop defaults open.**

## Open

- The why, written down (Jessica's hydraulic rationale for open-in-summer).
- Mechanism: how SiegLoop learns season/system posture — SystemMode
  awareness? a "park open/closed" capability on the surface (OPS-394)
  invoked by Standby? HpBoss TurnOff carrying posture?
- Interaction with the July fan-coil cooling path (Nolan AC; maple if it
  cools): does valve position affect cooling flow anywhere?
- Fleet sweep: which homes are sieg-plumbed ("what about beech??").
- Return-position contract with sieg-valve-exercise (its sweeps must end at
  the posture position).
