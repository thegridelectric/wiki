# honeysuckle-gen (unsorted item)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: an unsorted item; hub [`primary.md`](primary.md).

**Honeysuckle layout does not generate (found 2026-09-04).**
`tlayouts/honeysuckle_sema_gen.py` sets `power_meter_kind="sim-egauge"`,
which the config's `Literal["sim", "egauge"]` refuses while the
generator code paths handle the value. Honeysuckle is NOT a simulated
home: it is the pi attached to a real gw108 at the Stoneman
microgrid (tailscale `100.118.30.38`), and there is a real eGauge on
site, so its power meter is `egauge` with that eGauge's identity, not
a sim knob. Fix at the next honeysuckle regen; until then the deployed bench
layout is the last good output.
