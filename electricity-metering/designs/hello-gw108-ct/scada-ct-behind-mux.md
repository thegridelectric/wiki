# Scada reads a CT behind the mux

Status: Draft · Pass 0 · Updated 2026-11-24

> What this is: the first step of hello-gw108-ct. On the Gw108 Rev C the
> CT ADS1115 (0x48) sits behind channel 4 of the TCA9548A mux (0x70). The
> scada's I2C bus actor selects a mux channel only for the DACs, from the
> device record's `Dacs[].MuxName` and `MuxChannel`. The CT capability word
> `i2c.ct.interface.capability` v000 has the same two fields, the spruce
> layout places its CT ADC behind `DacMux` channel 4, and the scada's twin
> decodes it; the scada does not yet select that channel for a CT read.

## Do this next

The vocabulary is in place: `i2c.ct.interface.capability` has `MuxName`
and `MuxChannel`, the board word's MuxConsistency axiom covers `CtAdc`,
the Rev C record states the CT ADC behind `DacMux` channel 4, and the
scada twin decodes it (sema `081c944`, tlayouts `3adf93f`, scada
`6c2bd833`; spruce runs that pair). Next: the I2C bus actor learns the
CT ADC's mux channel from the record alongside the DAC channels, below.

## Then

- The I2C bus actor (`gridworks-scada/gw_spaceheat/actors/i2c_bus.py`,
  backend selection around line 121) learns the CT ADC's mux channel from
  the record alongside the DAC channels.
- The ADS1115 driver (`gw_spaceheat/drivers/ads1115.py`) reads the CT
  channel through the selected mux channel with the mux select restored
  for the DAC writes that follow.
- Witness: on spruce under the running scada, the scada's own CT1 and CT2
  readings match `ct_waveform.py`'s DC level and RMS within the bench
  noise floor, and the DAC writes keep working through a capture.

## Open

- Whether the shared mux select wants a lock in the bus actor or the
  check-and-repair pattern the starter script uses.
- Whether the layout models each CT input's burden DIP switch (the board's
  470 Ω burden, enabled per input, switch numbering reversed: switch 1 is
  CT4) and checks it against the clamp's output kind: a current-output
  clamp such as the SCT013 needs the burden closed, a voltage-output clamp
  needs it open. The per-channel CT config word that would state it is
  OPS-714's; the board facts are the scada executor `gw108-rev-c-board.md`.
