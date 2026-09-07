# pump-device-type (unsorted item)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: an unsorted item; hub [`primary.md`](primary.md).

**Pumps need a type in the layout (2026-09-05).** Nothing in a layout
says what each pump IS: make and model, and with it the control kind
(0-10 V, PWM, on/off, fixed-speed) and the curve the control code
needs. Spruce's secondary pump is a Grundfos UPMS 20-78 F driven by
the DAC output; the dist and store pumps are not identified anywhere
either. A device-type record per pump model (the pattern the heat
pump parts use: a node with a component whose DeviceType names the
record) is the likely shape; the speed-versus-output curve from
`experiments/2026-09-06-spruce-pump-speed-sweep/` is the first fact such
a record would carry.
