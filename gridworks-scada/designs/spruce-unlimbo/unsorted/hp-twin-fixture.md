# hp-twin-fixture (unsorted item)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: an unsorted item; hub [`primary.md`](primary.md). Parked
> 2026-09-07: waits on the modbus work and on `hp-boss-cleanup`; the twin
> decisions are in `../sh-node-actor-partition/hp-boss-cleanup.md`.

tlayouts config axis →
`gw.nolan.layout.hp-twin.json` (hp-ctrl-box as HpTwin under hp-boss,
its component the MIM modbus bridge) + a dormant HpTwin stub so both
fixtures boot. hp-boss driver selection keys on the control box's
DeviceType value: a real value selects the modbus driver,
`SimSamsungAE055FEYMCG` the sim twin; sim parts carry no device-type
records.
